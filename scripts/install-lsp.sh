#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/nvim-tools/lsp"
have() { command -v "$1" >/dev/null 2>&1; }
have clangd || { echo '缺少 clangd，请通过系统包管理器安装 clangd（macOS 可安装 Xcode Command Line Tools）。' >&2; exit 1; }
# A compatible, pinned TypeScript server avoids changing Node requirements on every install.
have node && have npm || { echo 'Pyright/TypeScript LSP 需要 Node.js >= 20 和 npm。' >&2; exit 1; }
node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 20 ? 0 : 1)' || {
    echo '需要 Node.js >= 20，请先更新 Node.js 再运行安装。' >&2; exit 1;
}
mkdir -p "$ROOT"
packages=()
if ! have pyright-langserver && [[ ! -x "$ROOT/node_modules/.bin/pyright-langserver" ]]; then
    packages+=(pyright@1.1.408)
fi
if ! have typescript-language-server || ! have tsserver; then
    if [[ ! -x "$ROOT/node_modules/.bin/typescript-language-server" || ! -x "$ROOT/node_modules/.bin/tsserver" ]]; then
        packages+=(typescript-language-server@5.1.3 typescript@5.9.3)
    fi
fi
if [[ ${#packages[@]} -gt 0 ]]; then
    npm install --prefix "$ROOT" --no-audit --no-fund "${packages[@]}"
fi
bash "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/install-rust-lsp.sh"
if have lua-language-server || [[ -x "$ROOT/lua-language-server/bin/lua-language-server" ]]; then
    echo '[nvim] 复用已有 Lua 语言服务器'
    exit 0
fi
# Official LuaLS 3.19.1 release assets; verify before extracting or executing.
case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) platform=darwin-arm64; digest=0bc077f4447f076b4c92c14e9fd303f5b569eda2ec74b4dca2b55f75fae2e90c ;;
    Darwin-x86_64) platform=darwin-x64; digest=eb373c159cbe556711d7cd316315de2dce969bfd54b31edb7eb9cab2937f2cca ;;
    Linux-aarch64|Linux-arm64) platform=linux-arm64; digest=abd2572e8fc929dc838a81ffb8473c5bce0bf39bfe8edb4b120b3b623176ce83 ;;
    Linux-x86_64) platform=linux-x64; digest=e9235d2d72ef55bc41cf8c99cda2ed64777682024b4bb81f5dea425060c5cbb8 ;;
    *) echo '当前架构请自行安装 lua-language-server 并加入 PATH，然后重新运行。' >&2; exit 1 ;;
esac
mkdir -p "$ROOT"
WORK="$(mktemp -d "$ROOT/.install.XXXXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT
curl --fail --location --retry 3 --connect-timeout 20 --max-time 600 \
    "https://github.com/LuaLS/lua-language-server/releases/download/3.19.1/lua-language-server-3.19.1-$platform.tar.gz" -o "$WORK/luals.tar.gz"
if have sha256sum; then actual="$(sha256sum "$WORK/luals.tar.gz")";
else actual="$(shasum -a 256 "$WORK/luals.tar.gz")"; fi
[[ "${actual%% *}" == "$digest" ]] || { echo 'LuaLS SHA-256 校验失败' >&2; exit 1; }
mkdir "$WORK/server"
tar -xzf "$WORK/luals.tar.gz" -C "$WORK/server"
"$WORK/server/bin/lua-language-server" --version
if [[ -e "$ROOT/lua-language-server" || -L "$ROOT/lua-language-server" ]]; then
    mv "$ROOT/lua-language-server" "$ROOT/lua-language-server.backup.$(date +%Y%m%d%H%M%S).$$"
fi
mv "$WORK/server" "$ROOT/lua-language-server"
echo '[nvim] LSP 服务器安装完成'
