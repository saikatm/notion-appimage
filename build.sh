#!/bin/bash

# Create build directory
mkdir -p build
pushd build

# Download the Notion installer
curl --location https://www.notion.so/desktop/windows/download --output installer

# Extract app-64.7z from the installer
7z e installer \$PLUGINSDIR/app-64.7z

# Extract the entire resources directory from app-64.7z (preserves structure)
7z x app-64.7z resources/

# Extract app.asar to app directory, including unpacked files
npx --yes @electron/asar extract resources/app.asar app

# Get Electron version (assumes devDependencies exists; adjust if needed)
electron=$(node --print "require('./app/package.json').devDependencies['electron']")

# Download the latest better-sqlite3 instead of relying on a specific version
npm pack better-sqlite3
tar --extract --file better-sqlite3-*.tgz

# Rebuild better-sqlite3 for the target Electron version
pushd package
npm install
npx node-gyp rebuild --target=$electron --arch=x64 --dist-url=https://electronjs.org/headers
cp build/Release/better_sqlite3.node ../app/node_modules/better-sqlite3/build/Release
popd

# Enter the app directory for building
pushd app

# Replace the icon (ensure ../../assets/icon.png exists)
rm -f icon.ico
cp ../../assets/icon.png .

# Patch the JavaScript code
sed --in-place '
    s/"win32"===process.platform/(true)/g
    s/_.Store.getState().app.preferences?.isAutoUpdaterDisabled/(true)/g
' .webpack/main/index.js

# Build the AppImage without rebuilding native dependencies
npx --yes electron-builder --linux appimage --config.npmRebuild=false

popd

popd