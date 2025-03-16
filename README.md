# Notion AppImage

**THIS IS AN UNOFFICIAL REPACK, USE AT YOUR OWN RISK**

Credit goes to [@kidonng](https://github.com/kidonng/notion-appimage) for making the repo and [Claude 3.7 sonet](https://claude.ai) for fixing the old script.

## Build

Prepare dependencies:

- 7zip
- Node.js & npm
- Standard Unix tools

## Advice: use the latest version of node & use local machine (not github codespaces)

`sudo apt update && sudo apt install -y p7zip-full nodejs npm build-essential`

`curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash`
`export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"`

`nvm install 16`

`nvm use 16`

Then run [`build.sh`](build.sh). the .appimage can be found @ `/notion-appimage/build/app/dist`

download prebuilt app via GitHub releases, use appimage launcher then launch.
