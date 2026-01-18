/// XGBoost JSON Model Inference Service
/// Protocol: Antigravity - Mobile Module
///
/// Loads and runs inference on XGBoost models exported from the PC app.
/// Uses native JSON tree parsing for on-device prediction.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

class ModelInference {
  final Map<String, XGBoostModel> _models = {};
  final String _modelsPath;

  ModelInference(this._modelsPath);

  /// Load models for a specific symbol
  Future<bool> loadModels(String symbol) async {
    try {
      for (final horizon in ['4H', '2D', '5D']) {
        final filePath = '$_modelsPath/${symbol}_$horizon.json';
        final file = File(filePath);

        if (!await file.exists()) {
          print('⚠️ Model not found: $filePath');
          return false;
        }

        final content = await file.readAsString();
        final modelJson = jsonDecode(content);
        _models['${symbol}_$horizon'] = XGBoostModel.fromJson(modelJson);
      }
      return true;
    } catch (e) {
      print('❌ Error loading models for $symbol: $e');
      return false;
    }
  }

  /// Run inference for a symbol
  /// Returns [prob_4H, prob_2D, prob_5D]
  List<double> predict(String symbol, List<double> features) {
    final results = <double>[];

    for (final horizon in ['4H', '2D', '5D']) {
      final model = _models['${symbol}_$horizon'];
      if (model == null) {
        results.add(0.0);
        continue;
      }

      final rawPred = model.predict(features);
      // Apply sigmoid for probability
      final prob = 1.0 / (1.0 + exp(-rawPred));
      results.add(prob);
    }

    return results;
  }

  /// Check if models are loaded for a symbol
  bool hasModels(String symbol) {
    return _models.containsKey('${symbol}_4H') &&
        _models.containsKey('${symbol}_2D') &&
        _models.containsKey('${symbol}_5D');
  }

  /// Clear cached models
  void clearModels() {
    _models.clear();
  }
}

/// Simplified XGBoost model parser for JSON format
class XGBoostModel {
  final List<XGBoostTree> trees;
  final double baseScore;

  XGBoostModel({required this.trees, this.baseScore = 0.5});

  factory XGBoostModel.fromJson(Map<String, dynamic> json) {
    final learner = json['learner'] ?? json;
    final modelParam = learner['learner_model_param'] ?? {};
    final baseScore =
        double.tryParse(modelParam['base_score']?.toString() ?? '0.5') ?? 0.5;

    final treeData = learner['gradient_booster']?['model']?['trees'] ?? [];
    final trees = <XGBoostTree>[];

    for (final treeJson in treeData) {
      trees.add(XGBoostTree.fromJson(treeJson));
    }

    return XGBoostModel(trees: trees, baseScore: baseScore);
  }

  double predict(List<double> features) {
    double sum = baseScore;
    for (final tree in trees) {
      sum += tree.predict(features);
    }
    return sum;
  }
}

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
    required this.isLeaf,
  });

  factory XGBoostTree.fromJson(Map<String, dynamic> json) {
    final left = (json['left_children'] as List).cast<int>();
    final right = (json['right_children'] as List).cast<int>();
    final indices = (json['split_indices'] as List).cast<int>();
    final conditions = (json['split_conditions'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final weights = (json['base_weights'] as List)
        .map((e) => (e as num).toDouble())
        .toList();

    final leafFlags = <bool>[];
    for (int i = 0; i < left.length; i++) {
      leafFlags.add(left[i] == -1);
    }

    return XGBoostTree(
      leftChildren: left,
      rightChildren: right,
      splitIndices: indices,
      splitConditions: conditions,
      baseWeights: weights,
      isLeaf: leafFlags,
    );
  }

  double predict(List<double> features) {
    int node = 0;

    while (!isLeaf[node]) {
      final featureIdx = splitIndices[node];
      final threshold = splitConditions[node];

      if (featureIdx >= features.length) {
        return baseWeights[node];
      }

      if (features[featureIdx] < threshold) {
        node = leftChildren[node];
      } else {
        node = rightChildren[node];
      }

      if (node < 0 || node >= isLeaf.length) break;
    }

    return baseWeights[node];
  }
}
