#!/bin/bash
set -e  # Exit on error

# Check Node.js version
NODE_VERSION=$(node --version | cut -d 'v' -f 2)
MAJOR_VERSION=$(echo $NODE_VERSION | cut -d '.' -f 1)

echo "Detected Node.js version: $NODE_VERSION"
if [ "$MAJOR_VERSION" -lt "14" ]; then
  echo "Warning: Your Node.js version is too old. This script requires Node.js 14 or higher."
  echo "Attempting to use nvm to switch to a compatible version..."
  
  # Try to use nvm if available
  if [ -f "$HOME/.nvm/nvm.sh" ]; then
    source "$HOME/.nvm/nvm.sh"
    nvm install 18 || nvm use 18 || echo "Failed to switch Node.js version. Please install Node.js 14+ and try again."
    echo "Now using Node.js $(node --version)"
  else
    echo "nvm not found. Please install Node.js 14+ manually before continuing."
    exit 1
  fi
fi

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
  # Try to get versions safely, without using modern JS features
  sqlite=$(node --print "try { require('./package.json').dependencies['better-sqlite3'] } catch(e) { 'unknown' }")
  electron=$(node --print "try { require('./package.json').devDependencies['electron'] } catch(e) { 'unknown' }")
  
  # If versions are unknown, try alternatives
  if [ "$sqlite" == "unknown" ] || [ "$electron" == "unknown" ]; then
    echo "Searching for dependency versions in node_modules..."
    # Default values
    sqlite="7.4.3"
    electron="25.8.0"
    
    # Try to find in files
    if [ -f "package.json" ]; then
      BETTER_SQLITE=$(grep -o '"better-sqlite3": "[^"]*"' package.json | cut -d'"' -f4)
      if [ ! -z "$BETTER_SQLITE" ]; then
        sqlite=$BETTER_SQLITE
      fi
      
      ELECTRON=$(grep -o '"electron": "[^"]*"' package.json | cut -d'"' -f4)
      if [ ! -z "$ELECTRON" ]; then
        electron=$ELECTRON
      fi
    fi
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
# Force using an older version of node-gyp compatible with older Node.js
echo "Installing compatible node-gyp..."
npm install -g node-gyp@8.4.1

# Force using an older version of better-sqlite3 that is compatible with older Node.js
if [ "$MAJOR_VERSION" -lt "14" ]; then
  echo "Using better-sqlite3 version compatible with Node.js 12..."
  sqlite="7.6.0"  # Last version known to work with Node.js 12
fi

npm pack better-sqlite3@$sqlite
tar --extract --file better-sqlite3-*.tgz

echo "Rebuilding better-sqlite3..."
cd package

# Ensure we're using a compatible version of node-gyp
# Create .npmrc file to force specific node-gyp version
echo "node-gyp=node-gyp@8.4.1" > .npmrc

npm install --no-package-lock

echo "Running node-gyp rebuild..."
# Use explicit path to the compatible node-gyp
npx node-gyp@8.4.1 rebuild --target=$electron --arch=x64 --dist-url=https://electronjs.org/headers

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
# Use npx to run electron-builder with explicit version
npx --yes electron-builder@23.6.0 --linux AppImage --config.npmRebuild=false
