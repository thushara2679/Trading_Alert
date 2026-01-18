
import PyInstaller.__main__
import os
import shutil

def build_exe():
    print("🚀 Starting Build Process for Trading Alerts...")

    # Define build options
    options = [
        'stock_trainer.py',           # Entry point
        '--name=TradingAlerts',       # Name of the executable
        '--onefile',                  # Create a single executable file
        '--noconsole',                # Do not show a console window
        '--clean',                    # Clean PyInstaller cache and remove temporary files before building
        '--collect-all=xgboost',      # Explicitly collect all xgboost data and binaries
        # Explicit exclusions can be added here if valid imports are found, 
        # but PyInstaller mainly follows imports. 
        # We can try to explicitly exclude known mobile modules if they were imported conditionally.
        # '--exclude-module=mobile_app', 
    ]

    # Run PyInstaller
    try:
        PyInstaller.__main__.run(options)
        print("✅ Build completed successfully.")
        
        # Verify exclusion
        dist_path = os.path.join(os.getcwd(), 'dist', 'TradingAlerts.exe')
        if os.path.exists(dist_path):
            print(f"📦 Executable created at: {dist_path}")
            size_mb = os.path.getsize(dist_path) / (1024 * 1024)
            print(f"📄 Size: {size_mb:.2f} MB")
        else:
            print("❌ Error: Executable not found in dist/.")

    except Exception as e:
        print(f"❌ Build failed: {e}")

if __name__ == "__main__":
    # Ensure we are in the project root
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    # Check if PyInstaller is installed
    try:
        import PyInstaller
    except ImportError:
        print("⚠️ PyInstaller not found. Installing...")
        os.system('pip install pyinstaller')

    build_exe()
