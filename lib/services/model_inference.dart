/// Model Inference Service - XGBoost JSON Parser
/// Converted from: services/model_inference.py
/// 
/// Loads XGBoost models exported as JSON and runs inference.
/// Uses native Dart tree parsing for on-device prediction.
/// 
/// Model Structure:
///     assets/models/{SYMBOL}_pkg/
///         ├── features.json       (Feature metadata)
///         ├── model_4H.json       (4-hour model)
///         ├── model_2D.json       (2-day model)
///         └── model_5D.json       (5-day model)

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';

/// Single decision tree from XGBoost model
class XGBoostTree {
  final List<int> leftChildren;
  final List<int> rightChildren;
  final List<int> splitIndices;
  final List<double> splitConditions;
  final List<double> baseWeights;
  final List<bool> isLeaf;

  XGBoostTree({
    required this.leftChildren,
    required this.rightChildren,
    required this.splitIndices,
    required this.splitConditions,
    required this.baseWeights,
  }) : isLeaf = leftChildren.map((left) => left == -1).toList();

  /// Robust double parser handling strings and arrays
  static double safeFloat(dynamic val) {
    if (val is int) return val.toDouble();
    if (val is double) return val;
    if (val is String) {
      final cleaned = val.replaceAll(RegExp("[\\[\\]'\" ]"), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    if (val is List && val.isNotEmpty) {
      return safeFloat(val[0]);
    }
    return 0.0;
  }

  /// Parse tree from XGBoost JSON format
  factory XGBoostTree.fromJson(Map<String, dynamic> treeJson) {
    final leftChildren = List<int>.from(treeJson['left_children']);
    final rightChildren = List<int>.from(treeJson['right_children']);
    final splitIndices = List<int>.from(treeJson['split_indices']);
    final splitConditions = (treeJson['split_conditions'] as List)
        .map((x) => safeFloat(x))
        .toList();
    final baseWeights = (treeJson['base_weights'] as List)
        .map((x) => safeFloat(x))
        .toList();

    return XGBoostTree(
      leftChildren: leftChildren,
      rightChildren: rightChildren,
      splitIndices: splitIndices,
      splitConditions: splitConditions,
      baseWeights: baseWeights,
    );
  }

  /// Traverse tree to get prediction
  double predict(List<double> features) {
    int node = 0;

    while (!isLeaf[node]) {
      final featIdx = splitIndices[node];
      final threshold = splitConditions[node];

      if (featIdx >= features.length) {
        return baseWeights[node];
      }

      if (features[featIdx] < threshold) {
        node = leftChildren[node];
      } else {
        node = rightChildren[node];
      }

      if (node < 0 || node >= isLeaf.length) {
        break;
      }
    }

    return baseWeights[node];
  }
}

/// XGBoost model loaded from JSON
class XGBoostModel {
  final List<XGBoostTree> trees;
  final double baseScore;

  XGBoostModel({
    required this.trees,
    this.baseScore = 0.5,
  });

  /// Parse model from XGBoost JSON format
  factory XGBoostModel.fromJson(Map<String, dynamic> modelJson) {
    final learner = modelJson['learner'] ?? modelJson;
    final modelParam = learner['learner_model_param'] ?? {};
    final baseScore = XGBoostTree.safeFloat(modelParam['base_score'] ?? '0.5');

    final treeData = learner['gradient_booster']?['model']?['trees'] ?? [];
    final trees = (treeData as List)
        .map((t) => XGBoostTree.fromJson(t as Map<String, dynamic>))
        .toList();

    return XGBoostModel(trees: trees, baseScore: baseScore);
  }

  /// Get raw prediction (sum of tree outputs)
  double predictRaw(List<double> features) {
    double total = baseScore;
    for (final tree in trees) {
      total += tree.predict(features);
    }
    return total;
  }

  /// Get probability via sigmoid transformation
  double predictProba(List<double> features) {
    final raw = predictRaw(features);
    return 1.0 / (1.0 + math.exp(-raw));
  }
}

/// Manages XGBoost model loading and inference
class ModelInference {
  static const List<String> horizons = ['4H', '2D', '5D'];

  String modelsDir;
  final Map<String, XGBoostModel> _models = {};
  final Map<String, List<String>> _featureNames = {};

  ModelInference({this.modelsDir = 'assets/models'});

  /// Get the package directory path for a symbol
  String _getModelPkgPath(String symbol) {
    // Try both underscore and dot variants
    final variants = [
      symbol.replaceAll('.', '_'),
      symbol,
    ];

    for (var variant in variants) {
      final base = '$modelsDir/${variant}_pkg';
      final mobile = '$modelsDir/${variant}_mobile_pkg';
      
      if (Directory(base).existsSync()) return base;
      if (Directory(mobile).existsSync()) return mobile;
    }

    // Fallback to underscore version
    return '$modelsDir/${symbol.replaceAll('.', '_')}_pkg';
  }

  /// Helper to print the directory tree for debugging
  void debugPrintDirectoryTree() {
    print('📂 [DEBUG] Directory Tree of: $modelsDir');
    final dir = Directory(modelsDir);
    if (!dir.existsSync()) {
      print('❌ [DEBUG] modelsDir does not exist');
      return;
    }
    
    _printDir(dir, '');
  }

  void _printDir(Directory dir, String indent) {
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (entity is Directory) {
          print('$indent📁 $name');
          _printDir(entity, '$indent  ');
        } else {
          print('$indent📄 $name');
        }
      }
    } catch (e) {
      print('$indent❌ Error listing: $e');
    }
  }

  /// Load all horizon models (4H, 2D, 5D) for a symbol
  Future<Map<String, bool>> loadModels(String symbol) async {
    // Debug print tree on first load per session if needed
    if (_models.isEmpty) debugPrintDirectoryTree();

    final pkgPath = _getModelPkgPath(symbol);
    print('📂 [LOAD] Attempting to load models from: $pkgPath');
    
    final pkgDir = Directory(pkgPath);
    if (!pkgDir.existsSync()) {
      print('❌ [LOAD] Package directory does not exist: $pkgPath');
      // Debug: List what IS in the parent directory
      final parentDir = pkgDir.parent;
      if (parentDir.existsSync()) {
        print('📂 [LOAD] Contents of ${parentDir.path}:');
        try {
          final entities = parentDir.listSync();
          for (final entity in entities) {
             print('  - ${entity.path.split(Platform.pathSeparator).last}');
          }
        } catch (e) {
          print('  Error listing parent dir: $e');
        }
      }
    } else {
        print('📂 [LOAD] Package exists. Contents:');
         try {
          final entities = pkgDir.listSync();
          for (final entity in entities) {
             print('  - ${entity.path.split(Platform.pathSeparator).last}');
          }
        } catch (e) {
          print('  Error listing pkg dir: $e');
        }
    }
    
    final results = <String, bool>{};

    // List all files in the directory once for case-insensitive matching
    final filesInDir = <String, File>{};
    if (pkgDir.existsSync()) {
      try {
        final entities = pkgDir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            final filename = entity.path.split(Platform.pathSeparator).last.toLowerCase();
            filesInDir[filename] = entity;
          }
        }
      } catch (e) {
        print('Error listing files: $e');
      }
    }

    for (final horizon in horizons) {
      final key = '${symbol}_$horizon';
      final expectedName = 'model_$horizon.json'.toLowerCase();
      
      final modelFile = filesInDir[expectedName];

      if (modelFile != null) {
        try {
          print('📂 [LOAD] Loading model: ${modelFile.path}');
          final content = await modelFile.readAsString();
          final modelJson = jsonDecode(content) as Map<String, dynamic>;
          _models[key] = XGBoostModel.fromJson(modelJson);
          print('✅ [LOAD] Successfully loaded: $symbol $horizon');
          results[horizon] = true;
        } catch (e) {
          print('❌ [LOAD] Failed to load $symbol $horizon: $e');
          results[horizon] = false;
        }
      } else {
         // Fallback: try checking if it exists directly anyway, just in case
         final directFile = File('$pkgPath/model_$horizon.json');
         if (await directFile.exists()) {
             try {
                print('📂 [LOAD] Loading model (direct fallback): ${directFile.path}');
                final content = await directFile.readAsString();
                final modelJson = jsonDecode(content) as Map<String, dynamic>;
                _models[key] = XGBoostModel.fromJson(modelJson);
                results[horizon] = true;
             } catch (e) {
                print('❌ [LOAD] Direct fallback failed: $e');
                results[horizon] = false;
             }
         } else {
             results[horizon] = false;
         }
      }
    }

    // Load feature metadata (also case-insensitive)
    final featuresFile = filesInDir['features.json'];
    if (featuresFile != null) {
      try {
        final content = await featuresFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        _featureNames[symbol] = List<String>.from(
          data['inputs'] ?? data['names'] ?? [],
        );
        print('✅ [LOAD] Loaded features metadata for $symbol');
      } catch (_) {}
    } else {
       // Fallback for features.json
       final directFeatures = File('$pkgPath/features.json');
       if (await directFeatures.exists()) {
           try {
               final content = await directFeatures.readAsString();
               final data = jsonDecode(content) as Map<String, dynamic>;
               _featureNames[symbol] = List<String>.from(data['inputs'] ?? data['names'] ?? []);
           } catch (_) {}
       }
    }

    return results;
  }

  /// Run inference for a symbol
  Map<String, double> predict(String symbol, Map<String, double> features) {
    print('🔍 [PREDICT] Symbol: $symbol');
    print('🔍 [PREDICT] Input features: $features');
    
    // Determine feature order from metadata or fallback
    final featureOrder = _featureNames[symbol] ??
        ['Vol_Z', 'Elasticity', 'day_of_week', 'hour_of_day'];
    
    print('🔍 [PREDICT] Feature order: $featureOrder');

    // Create feature vector
    final featureList = featureOrder
        .map((f) => features[f] ?? 0.0)
        .toList();
    
    print('🔍 [PREDICT] Feature vector: $featureList');

    final results = <String, double>{};
    for (final horizon in horizons) {
      final key = '${symbol}_$horizon';
      final model = _models[key];

      if (model == null) {
        print('⚠️ [PREDICT] Model not loaded for $symbol $horizon');
        results[horizon] = 0.0;
      } else {
        final prob = model.predictProba(featureList);
        // Convert to percentage (0-100%)
        results[horizon] = (prob * 100).roundToDouble();
        print('✅ [PREDICT] $symbol $horizon: ${results[horizon]}%');
      }
    }
    
    print('🔍 [PREDICT] Final results: $results');
    return results;
  }

  /// Check if any models are loaded for a symbol
  bool hasModels(String symbol) {
    for (final horizon in horizons) {
      if (_models.containsKey('${symbol}_$horizon')) {
        return true;
      }
    }
    return false;
  }

  /// Get detailed status of models for a symbol
  Future<Map<String, String>> getModelStatus(String symbol) async {
    final pkgPath = _getModelPkgPath(symbol);
    final status = <String, String>{};
    final pkgDir = Directory(pkgPath);

    // Scan for files case-insensitively
    final filesInDir = <String>{};
    if (await pkgDir.exists()) {
      try {
        await for (final entity in pkgDir.list()) {
          if (entity is File) {
             filesInDir.add(entity.path.split(Platform.pathSeparator).last.toLowerCase());
          }
        }
      } catch (_) {}
    }

    for (final horizon in horizons) {
      final key = '${symbol}_$horizon';
      final expectedName = 'model_$horizon.json'.toLowerCase();
      
      if (_models.containsKey(key)) {
        status[horizon] = 'loaded';
      } else if (filesInDir.contains(expectedName)) {
        status[horizon] = 'available';
      } else {
        status[horizon] = 'missing';
      }
    }

    return status;
  }

  /// List all symbols that have model packages available
  Future<List<String>> listAvailableSymbols() async {
    final symbols = <String>[];
    final dir = Directory(modelsDir);

    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (name.endsWith('_pkg')) {
            // Convert back to symbol format
            final symbol = name.substring(0, name.length - 4).replaceAll('_', '.');
            symbols.add(symbol);
          }
        }
      }
    }

    return symbols;
  }

  /// Delete all models for a symbol
  Future<bool> deleteModelPackage(String symbol) async {
    // Clear from memory first
    for (final horizon in horizons) {
      _models.remove('${symbol}_$horizon');
    }
    _featureNames.remove(symbol);

    final dir = Directory(modelsDir);
    if (!await dir.exists()) return false;

    var deletionSuccess = false;

    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.endsWith('_pkg')) {
          final derivedSymbol = name.substring(0, name.length - 4).replaceAll('_', '.');
          if (derivedSymbol == symbol) {
            try {
              await entity.delete(recursive: true);
              print('🗑️ Deleted model package: ${entity.path}');
              deletionSuccess = true;
            } catch (e) {
              print('❌ Failed to delete ${entity.path}: $e');
            }
          }
        }
      }
    }

    return deletionSuccess;
  }

  /// Run test inference with dummy data for diagnostics
  Future<Map<String, dynamic>> testInference(String symbol) async {
    final loadResult = await loadModels(symbol);
    if (loadResult.values.every((v) => !v)) {
      return {'status': 'failed', 'error': 'Could not load models'};
    }

    // Dummy features (approximate average values)
    final dummyFeatures = {
      'Vol_Z': 0.5,
      'Elasticity': 0.02,
      'day_of_week': 2.0,
      'hour_of_day': 10.0,
    };

    try {
      final results = predict(symbol, dummyFeatures);
      return {
        'status': 'success',
        'results': results,
        'models': await getModelStatus(symbol),
      };
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }

  /// Delete all model folders and clear memory
  Future<void> clearAllModels() async {
    _models.clear();
    _featureNames.clear();
    
    final dir = Directory(modelsDir);
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
        print('🗑️ Cleared all models from disk');
      } catch (e) {
        print('❌ Failed to clear models: $e');
      }
    }
  }

  /// Clear all cached models from memory
  void clearModels() {
    _models.clear();
    _featureNames.clear();
  }
}
