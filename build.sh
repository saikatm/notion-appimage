#!/bin/bash

# Create and enter the build directory
mkdir build
pushd build

# Download the Notion Windows installer
curl --location https://www.notion.so/desktop/windows/download --output installer

# Extract app-64.7z from the installer
7z e installer \$PLUGINSDIR/app-64.7z

# Extract all contents of app-64.7z with directory structure
7z x app-64.7z -o.

# Extract app.asar into the app directory
npx --yes @electron/asar extract resources/app.asar app

# Get the Electron version from package.json
electron=$(node --print "require('./app/package.json').devDependencies['electron']")

# Rebuild all native modules for the target Electron version
pushd app
npx electron-rebuild --version "$electron"
popd

# Enter the app directory for final adjustments
pushd app

# Replace the official icon (not recognized by electron-builder)
rm icon.ico
cp ../../assets/icon.png .

# Patch platform detection and disable auto-updates
sed --in-place '
    s/"win32"===process.platform/(true)/g
    s/_.Store.getState().app.preferences?.isAutoUpdaterDisabled/(true)/g
' .webpack/main/index.js

# Build the AppImage without rebuilding native dependencies (already handled)
npx --yes electron-builder --linux appimage --config.npmRebuild=false

popd

# Exit the build directory
popd