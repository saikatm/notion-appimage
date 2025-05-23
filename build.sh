#!/bin/bash

# Notion AppImage builder - Optimized version
set -e

LOG_FILE="$(pwd)/build_$(date +%Y%m%d_%H%M%S).log"
BUILD_DIR="build"
> "$LOG_FILE"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
die() { log "❌ ERROR: $1"; exit 1; }

run_cmd() {
    log "🔄 $1"
    eval "$2" >> "$LOG_FILE" 2>&1 || {
        log "❌ Failed: $1"
        tail -3 "$LOG_FILE" | sed 's/^/   /' 
        die "Command failed"
    }
    log "✅ $1"
}

setup_icon() {
    local icon_paths=("../assets/icon.png" "../../assets/icon.png" "./assets/icon.png")
    
    for path in "${icon_paths[@]}"; do
        if [[ -f "$path" ]]; then
            cp "$path" icon.png
            log "✅ Using icon from $path"
            command -v convert >/dev/null && convert icon.png -resize 256x256 icon.png 2>/dev/null
            return 0
        fi
    done
    
    # Fallback: create simple icon
    cat << 'EOF' | base64 -d > icon.png || die "Failed to create fallback icon"
iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAYAAABccqhmAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAOxAAADsQBlSsOGwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAATESURBVHic7d3BbtNAFEbhk8YtIgWpCwQCsWDBjr5/X4AdCxYsWCBeBBYsqJC6gKqt1cTuYuJO7Dk+35f+9ty5Y+dk7kw8Ho8nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOBlGYZhWJZlWdd1XTfb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb29vb2
EOF
    log "✅ Created fallback icon"
}

main() {
    log "🚀 Starting Notion AppImage build..."
    
    # Check prerequisites
    local missing_deps=()
    for cmd in node 7z curl npx; do
        command -v "$cmd" >/dev/null || missing_deps+=("$cmd")
    done
    [[ ${#missing_deps[@]} -eq 0 ]] || die "Missing dependencies: ${missing_deps[*]}"
    
    local node_ver=$(node --version | cut -dv -f2 | cut -d. -f1)
    [[ $node_ver -ge 14 ]] || die "Node.js 14+ required (found v$node_ver)"
    
    log "✅ Prerequisites OK - Node.js $(node --version)"
    
    # Setup build directory
    rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
    
    # Download and extract
    run_cmd "Downloading Notion" "curl -Lf https://www.notion.so/desktop/windows/download -o installer"
    run_cmd "Extracting installer" "7z e installer '\$PLUGINSDIR/app-64.7z' -y"
    run_cmd "Extracting app.asar" "7z e app-64.7z resources/app.asar -y"
    
    # Setup native modules structure
    log "🏗️ Setting up native modules..."
    local modules=("better-sqlite3" "native-progress-bar" "node-mac-utils")
    for module in "${modules[@]}"; do
        mkdir -p "app.asar.unpacked/node_modules/$module/build/Release"
    done
    
    # Create dummy native files
    touch app.asar.unpacked/node_modules/better-sqlite3/build/Release/{better_sqlite3,test_extension}.node
    touch app.asar.unpacked/node_modules/native-progress-bar/build/Release/progress_bar.node
    touch app.asar.unpacked/node_modules/node-mac-utils/build/Release/{mac_utils,win_utils}.node
    
    run_cmd "Extracting asar" "npx --yes @electron/asar extract app.asar app"
    cd app
    
    # Get versions
    local notion_ver=$(node -pe "require('./package.json').version" 2>/dev/null || date +%Y.%m.%d)
    local electron_ver="33.2.0"
    local sqlite_ver="11.8.1"
    
    log "📋 Versions: Notion=$notion_ver, Electron=$electron_ver, SQLite=$sqlite_ver"
    
    # Build SQLite module
    cd .. && log "🔨 Building better-sqlite3..."
    run_cmd "Downloading SQLite package" "npm pack better-sqlite3@$sqlite_ver"
    run_cmd "Extracting package" "tar -xf better-sqlite3-*.tgz"
    
    cd package
    run_cmd "Installing dependencies" "npm install --prefer-offline --no-audit"
    run_cmd "Building native module" "npx node-gyp rebuild --target=$electron_ver --arch=x64 --dist-url=https://electronjs.org/headers"
    
    # Copy built module
    [[ -f "build/Release/better_sqlite3.node" ]] || die "Failed to build better_sqlite3.node"
    
    local targets=("../app/node_modules/better-sqlite3/build/Release" "../app.asar.unpacked/node_modules/better-sqlite3/build/Release")
    for target in "${targets[@]}"; do
        mkdir -p "$target" && cp build/Release/better_sqlite3.node "$target/"
    done
    log "✅ Native module installed"
    
    cd ../app
    
    # Setup Electron and package.json
    run_cmd "Installing Electron" "npm init -y && npm install --save-dev electron@$electron_ver"
    
    # Create package.json
    cat > package.json << EOF
{
  "name": "notion",
  "version": "$notion_ver",
  "description": "Notion Desktop App",
  "author": "Notion Labs, Inc.",
  "main": ".webpack/main/index.js",
  "dependencies": { "better-sqlite3": "$sqlite_ver" },
  "devDependencies": { "electron": "$electron_ver" },
  "build": {
    "appId": "notion.id",
    "productName": "Notion",
    "electronVersion": "$electron_ver",
    "files": ["**/*"],
    "extraResources": [{ "from": "../app.asar.unpacked/", "to": "app.asar.unpacked/", "filter": ["**/*.node"] }],
    "linux": { "target": "AppImage", "category": "Office" }
  }
}
EOF
    
    # Apply patches
    if [[ -f ".webpack/main/index.js" ]]; then
        log "🔧 Applying patches..."
        sed -i -e 's/"win32"===process.platform/(true)/g' \
               -e 's/_.Store.getState().app.preferences?.isAutoUpdaterDisabled/(true)/g' \
               .webpack/main/index.js
    fi
    
    # Setup icon and build
    setup_icon
    run_cmd "Building AppImage" "npx --yes electron-builder --linux AppImage --config.npmRebuild=false"
    
    log "🎉 Build completed! AppImage saved in dist/"
    log "📊 Full log: $LOG_FILE"
}

trap 'die "Build interrupted"' INT TERM
main "$@"
