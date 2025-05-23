# Notion AppImage

**Unofficial Repackage - Use at Your Own Discretion**

Acknowledgments: Developed by [@kidonng](https://github.com/kidonng/notion-appimage), with script enhancements by [Claude Sonnet 4](https://claude.ai).

## Build Instructions

### Prerequisites
- Node.js 14+ & npm
- 7zip
- curl
- ImageMagick (optional, for icon processing)
- Standard Unix utilities

**Recommendation**: Use the latest Node.js version on a local system for optimal results.

### Installation Steps

#### Package Installation by Distribution

**Ubuntu/Debian-based systems:**
```bash
sudo apt update
sudo apt install -y nodejs npm p7zip-full curl imagemagick build-essential
```

**Fedora/Red Hat-based systems:**  
```bash
sudo dnf install -y nodejs npm p7zip curl ImageMagick make gcc gcc-c++
```

**Arch Linux-based systems:**
```bash
sudo pacman -S nodejs npm p7zip curl imagemagick base-devel
```

#### Node.js Version Check
Verify Node.js version (must be 14+):
```bash
node --version
```

If your Node.js version is too old, install the latest LTS version:

**Ubuntu/Debian:**
```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**Fedora:**
```bash
curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
sudo dnf install -y nodejs
```

### Building the AppImage

1. **Clone or download** this repository
2. **Add your custom icon** (optional): Place your icon at `assets/icon.png` for a custom app icon
3. **Run the build script**:
   ```bash
   chmod +x build.sh
   ./build.sh
   ```

The resulting `.appimage` file will be located in `build/app/dist/`.

### Verification
Check all dependencies are installed:
```bash
for cmd in node npm npx curl 7z convert; do
    command -v "$cmd" >/dev/null && echo "✅ $cmd" || echo "❌ $cmd missing"
done
```

### Alternative Installation
Alternatively, obtain the prebuilt application from GitHub Releases and deploy using an AppImage launcher.

## Custom Icon
To use a custom icon instead of the default Notion icon:
1. Place your PNG icon file at `assets/icon.png` 
2. The build script will automatically use it and resize to 256x256 if needed
3. If no custom icon is found, a fallback icon will be generated

## System Requirements
- **Architecture**: x64 (64-bit)
- **Disk space**: ~2GB free space for build process  
- **RAM**: 4GB+ recommended for compilation
- **Node.js**: Version 14 or higher

## Troubleshooting
- If build fails, check the generated log file: `build_YYYYMMDD_HHMMSS.log`
- Ensure all prerequisites are installed and Node.js version is 14+
- For permission issues, make sure `build.sh` is executable: `chmod +x build.sh`
