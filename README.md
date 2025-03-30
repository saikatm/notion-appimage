# Notion AppImage

**Unofficial Repackage - Use at Your Own Discretion**

Acknowledgments: Developed by [@kidonng](https://github.com/kidonng/notion-appimage), with script enhancements by [Claude 3.7 Sonnet](https://claude.ai).

## Build Instructions

### Prerequisites
- 7zip
- Node.js & npm
- Standard Unix utilities

**Recommendation**: Utilize the latest Node.js version on a local system for optimal results.

### Installation Steps
Detect your Linux distribution and use the appropriate package manager:

- **Ubuntu-based systems**:
```bash
sudo apt update && sudo apt install -y p7zip-full nodejs npm build-essential
```

- **Fedora-based systems**:
```bash
sudo dnf install -y p7zip nodejs npm make gcc gcc-c++
```

Execute `build.sh`. The resulting `.appimage` file will be located in `/notion-appimage/build/app/dist`.

Alternatively, obtain the prebuilt application from GitHub Releases and deploy using an AppImage launcher.