#!/bin/bash
set -e  # Exit on error

# Create build directory if it doesn't exist
mkdir -p build
cd build

echo "Downloading Notion installer..."
curl --location https://www.notion.so/desktop/windows/download --output installer

echo "Extracting app files..."
7z e installer \$PLUGINSDIR/app-64.7z
7z e app-64.7z resources/app.asar

# Create directories for unpacked files
mkdir -p app.asar.unpacked/node_modules/better-sqlite3/build/Release
mkdir -p app.asar.unpacked/node_modules/native-progress-bar/build/Release
mkdir -p app.asar.unpacked/node_modules/node-mac-window/build/Release

# Create empty dummy files to satisfy the extraction
touch app.asar.unpacked/node_modules/better-sqlite3/build/Release/better_sqlite3.node
touch app.asar.unpacked/node_modules/better-sqlite3/build/Release/test_extension.node
touch app.asar.unpacked/node_modules/native-progress-bar/build/Release/progress_bar.node
touch app.asar.unpacked/node_modules/node-mac-window/build/Release/mac_window.node

echo "Extracting app.asar..."
npx --yes @electron/asar extract app.asar app

# Get dependency versions from package.json
cd app
echo "Reading dependency versions..."
if [ -f "package.json" ]; then
  # Try to get versions safely
  sqlite=$(node --print "try { require('./package.json').dependencies['better-sqlite3'] } catch(e) { 'unknown' }")
  electron=$(node --print "try { require('./package.json').devDependencies['electron'] } catch(e) { 'unknown' }")
  
  # If versions are unknown, try to get them from any package.json present
  if [ "$sqlite" == "unknown" ] || [ "$electron" == "unknown" ]; then
    echo "Searching for dependency versions in node_modules..."
    find . -name "package.json" -exec grep -l "better-sqlite3\|electron" {} \; | head -1 | xargs cat > /tmp/pkg.json
    sqlite=$(node --print "try { require('/tmp/pkg.json').dependencies['better-sqlite3'] || '7.4.3' } catch(e) { '7.4.3' }")
    electron=$(node --print "try { require('/tmp/pkg.json').devDependencies['electron'] || '25.8.0' } catch(e) { '25.8.0' }")
  fi
else
  # Default versions if package.json doesn't exist
  echo "No package.json found, using default versions"
  sqlite="7.4.3"
  electron="25.8.0"
fi

echo "Using sqlite version: $sqlite, electron version: $electron"

# Create directories for native modules
mkdir -p node_modules/better-sqlite3/build/Release
cd ..

echo "Downloading better-sqlite3..."
npm pack better-sqlite3@$sqlite
tar --extract --file better-sqlite3-*.tgz

echo "Rebuilding better-sqlite3..."
cd package

# Patch binding.gyp to use C++17 instead of C++20
echo "Patching binding.gyp to fix C++ standard version..."
if [ -f "binding.gyp" ]; then
  sed -i 's/"-std=gnu++20"/"-std=gnu++17"/g' binding.gyp
  sed -i 's/"-std=c++20"/"-std=c++17"/g' binding.gyp
fi

npm install

# Another patch for CXXFLAGS in better_sqlite3.target.mk if needed
if [ -f "build/better_sqlite3.target.mk" ]; then
  echo "Patching build/better_sqlite3.target.mk..."
  sed -i 's/-std=gnu++20/-std=gnu++17/g' build/better_sqlite3.target.mk
  sed -i 's/-std=c++20/-std=c++17/g' build/better_sqlite3.target.mk
fi

echo "Running node-gyp rebuild..."
npx node-gyp rebuild --target=$electron --arch=x64 --dist-url=https://electronjs.org/headers

echo "Copying built module..."
cp build/Release/better_sqlite3.node ../app/node_modules/better-sqlite3/build/Release/
cd ..

cd app

# Create or update package.json with required fields
echo "Creating package.json for electron-builder..."
cat > package.json << EOF
{
  "name": "notion",
  "version": "1.0.0",
  "description": "Notion AppImage",
  "main": ".webpack/main/index.js",
  "author": "Notion",
  "license": "UNLICENSED",
  "dependencies": {
    "better-sqlite3": "$sqlite"
  },
  "devDependencies": {
    "electron": "$electron"
  },
  "build": {
    "appId": "notion.id",
    "productName": "Notion",
    "files": [
      "**/*",
      "!**/node_modules/*/{CHANGELOG.md,README.md,README,readme.md,readme}",
      "!**/node_modules/*/{test,__tests__,tests,powered-test,example,examples}",
      "!**/node_modules/*.d.ts",
      "!**/node_modules/.bin"
    ],
    "extraResources": [
      {
        "from": "node_modules/better-sqlite3/build/Release/",
        "to": "app.asar.unpacked/node_modules/better-sqlite3/build/Release/",
        "filter": ["*.node"]
      }
    ],
    "linux": {
      "target": "AppImage",
      "category": "Office"
    }
  }
}
EOF

# Check if .webpack/main/index.js exists before modifying
if [ -f ".webpack/main/index.js" ]; then
  echo "Patching platform detection and auto update..."
  sed -i '
    s/"win32"===process.platform/(true)/g
    s/_.Store.getState().app.preferences?.isAutoUpdaterDisabled/(true)/g
  ' .webpack/main/index.js
else
  echo "Warning: .webpack/main/index.js not found, skipping patches"
fi

# Create a dummy icon.png if needed
mkdir -p ../../assets
if [ ! -f "../../assets/icon.png" ]; then
  echo "Creating a dummy icon.png..."
  convert -size 256x256 xc:white -fill black -draw "text 30,125 'Notion'" ../../assets/icon.png 2>/dev/null || echo "Warning: Could not create icon (ImageMagick not installed), using blank file"
  if [ ! -f "../../assets/icon.png" ]; then
    # If convert fails, create an empty file
    touch ../../assets/icon.png
  fi
fi
cp ../../assets/icon.png .

echo "Running electron-builder..."
npx --yes electron-builder --linux AppImage --config.npmRebuild=false