#!/bin/bash

# Notion AppImage builder - Shortened version
set -e

# Setup logging with absolute path
LOG_FILE="$(pwd)/build_$(date +%Y%m%d_%H%M%S).log"
BUILD_DIR="build"
> "$LOG_FILE"

log() { 
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

die() { 
    log "❌ ERROR: $1"
    exit 1
}

create_fallback_icon() {
    # Create a minimal 256x256 PNG icon using base64
    cat << 'ICON_EOF' | base64 -d > icon.png
iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAYAAABccqhmAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAOxAAADsQBlSsOGwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAATESURBVHic7d3BbtNAFEbhk8YtIgWpCwQCsWDBjr5/X4AdCxYsWCBeBBYsqJC6gKqt1cTuYuJO7Dk+35f+9ty5Y+dk7kw8Ho8nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOBlGYZhWJZlWdd1XTfb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29s
ICON_EOF
    log "✅ Created fallback icon (256x256)"
}

run_cmd() {
    log "🔄 $1"
    if ! eval "$2" >> "$LOG_FILE" 2>&1; then
        log "❌ Failed: $1"
        tail -5 "$LOG_FILE" | sed 's/^/   /' | tee -a "$LOG_FILE"
        die "Command failed"
    fi
    log "✅ $1"
}

main() {
    log "🚀 Starting Notion AppImage build..."
    
    # Check prerequisites
    for cmd in node 7z curl npx; do
        command -v "$cmd" >/dev/null || die "$cmd not found"
    done
    
    NODE_VER=$(node --version | cut -dv -f2 | cut -d. -f1)
    [[ $NODE_VER -ge 14 ]] || die "Node.js 14+ required (found v$NODE_VER)"
    log "✅ Prerequisites OK - Node.js $(node --version)"
    
    # Setup build directory
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Download and extract
    log "📥 Downloading Notion..."
    curl -Lf https://www.notion.so/desktop/windows/download -o installer
    
    log "📦 Extracting files..."
    7z e installer '$PLUGINSDIR/app-64.7z' -y >> "$LOG_FILE" 2>&1
    7z e app-64.7z resources/app.asar -y >> "$LOG_FILE" 2>&1
    
    # Create missing native module structure before extraction
    log "🏗️ Creating native module directories..."
    mkdir -p app.asar.unpacked/node_modules/{better-sqlite3,native-progress-bar,node-mac-utils}/build/Release
    
    # Create dummy files that asar expects
    touch app.asar.unpacked/node_modules/better-sqlite3/build/Release/{better_sqlite3.node,test_extension.node}
    touch app.asar.unpacked/node_modules/native-progress-bar/build/Release/progress_bar.node
    touch app.asar.unpacked/node_modules/node-mac-utils/build/Release/{mac_utils.node,win_utils.node}
    
    # Now extract the asar (will skip missing files)
    npx --yes @electron/asar extract app.asar app >> "$LOG_FILE" 2>&1
    
    cd app
    
    # Get versions
    NOTION_VER=$(node -pe "require('./package.json').version" 2>/dev/null || echo "$(date +%Y.%m.%d)")
    ELECTRON_VER="33.2.0"  # Use stable version that works well
    SQLITE_VER="11.8.1"
    
    log "📋 Versions: Notion=$NOTION_VER, Electron=$ELECTRON_VER, SQLite=$SQLITE_VER"
    
    # Build better-sqlite3
    cd ..
    log "🔨 Building better-sqlite3..."
    npm pack better-sqlite3@$SQLITE_VER >> "$LOG_FILE" 2>&1
    tar -xf better-sqlite3-*.tgz
    
    cd package
    npm install --prefer-offline --no-audit >> "$LOG_FILE" 2>&1
    npx node-gyp rebuild --target="$ELECTRON_VER" --arch=x64 --dist-url=https://electronjs.org/headers >> "$LOG_FILE" 2>&1
    
    # Copy built module
    if [[ -f "build/Release/better_sqlite3.node" ]]; then
        mkdir -p ../app/node_modules/better-sqlite3/build/Release/
        cp build/Release/better_sqlite3.node ../app/node_modules/better-sqlite3/build/Release/
        # Also copy to unpacked location for AppImage
        mkdir -p ../app.asar.unpacked/node_modules/better-sqlite3/build/Release/
        cp build/Release/better_sqlite3.node ../app.asar.unpacked/node_modules/better-sqlite3/build/Release/
        log "✅ Native module copied"
    else
        die "Failed to build better_sqlite3.node"
    fi
    
    cd ../app
    
    # Install electron locally for electron-builder
    log "📦 Installing Electron..."
    npm init -y >> "$LOG_FILE" 2>&1
    npm install --save-dev electron@$ELECTRON_VER >> "$LOG_FILE" 2>&1
    
    # Create minimal package.json
    cat > package.json << EOF
{
  "name": "notion",
  "version": "$NOTION_VER",
  "description": "Notion Desktop App",
  "author": "Notion Labs, Inc.",
  "main": ".webpack/main/index.js",
  "dependencies": { "better-sqlite3": "$SQLITE_VER" },
  "devDependencies": { "electron": "$ELECTRON_VER" },
  "build": {
    "appId": "notion.id",
    "productName": "Notion",
    "electronVersion": "$ELECTRON_VER",
    "files": ["**/*"],
    "extraResources": [
      {
        "from": "../app.asar.unpacked/",
        "to": "app.asar.unpacked/",
        "filter": ["**/*.node"]
      }
    ],
    "linux": { "target": "AppImage", "category": "Office" }
  }
}
EOF
    
    # Apply patches if main file exists
    if [[ -f ".webpack/main/index.js" ]]; then
        log "🔧 Applying patches..."
        sed -i 's/"win32"===process.platform/(true)/g' .webpack/main/index.js
        sed -i 's/_.Store.getState().app.preferences?.isAutoUpdaterDisabled/(true)/g' .webpack/main/index.js
    fi
    
    # Create 256x256 icon
    log "🎨 Creating icon..."
    if command -v convert >/dev/null 2>&1; then
        # Use ImageMagick to create a proper 256x256 icon
        convert -size 256x256 xc:'#2c2c2c' -fill white -pointsize 32 -gravity center -annotate +0+0 'Notion' icon.png 2>/dev/null || create_fallback_icon
    else
        create_fallback_icon
    fi
    
    # Build AppImage
    run_cmd "Building AppImage" "npx --yes electron-builder --linux AppImage --config.npmRebuild=false"
    
    log "🎉 Build completed! Check dist/ folder"
    log "📊 Full log saved to: $LOG_FILE"
}

trap 'die "Script interrupted"' INT TERM
main "$@"
