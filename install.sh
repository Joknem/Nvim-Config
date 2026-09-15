#!/usr/bin/env bash
# macOS (Homebrew), Debian/Ubuntu and their WSL installations.
set -Eeuo pipefail

VERSION_EXPLICIT=0
[[ -z "${NVIM_VERSION:-}" ]] || VERSION_EXPLICIT=1
NVIM_VERSION="${NVIM_VERSION:-0.11.5}"
INSTALL_METHOD=auto
BUILD_JOBS=2
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}"
BIN_DIR="$HOME/.local/bin"
TARGET="$CONFIG_ROOT/nvim"
SKIP_SYSTEM=0
WITH_LSP=0
MODE=install
WORK_DIR=""

usage() {
    cat <<'HELP'
用法：./install.sh [选项]

  --version X.Y.Z  选择 Neovim 发布版本（默认 0.11.5，也可传 v0.11.5）
  --method METHOD 安装方式：auto（默认）、binary、source、system
                  auto：复用同版本，否则尝试二进制；不可用时从源码编译
                  binary：只使用官方二进制；source：从指定版本源码构建
                  system：使用 PATH 中已有的 Neovim（包括自己编译的版本）
  --jobs N        源码构建并发数，默认 2，适合内存有限的机器
  --with-lsp      安装 C/C++、Python、Lua、Rust、TypeScript 语言服务器（复用已有命令）
  --skip-system   跳过 apt/Homebrew；仍检查所需依赖
  --check         只检查所选安装方式的依赖及 Neovim 版本
  --dry-run       只显示安装计划，不下载、不修改文件
  -h, --help      显示帮助

示例：
  ./install.sh --version 0.11.5 --method source --jobs 2
  ./install.sh --version 0.11.4 --method binary
  ./install.sh --method system --skip-system

自动装包支持 macOS、Debian/Ubuntu（含 WSL）。其他 Linux 可备好依赖后 --skip-system。
二进制支持 x86_64/arm64；其他架构可尝试 source，具体以该版本上游支持为准。
当前配置要求 >= 0.10.0，完整验证基线为 0.11.5；其他版本仍需通过插件启动检查。
版本选择只接受明确的 X.Y.Z 发布版本，不接受 latest/nightly 或任意 Git 分支。
源码构建仍需网络下载源码和第三方依赖；产物装在用户目录，不需要 sudo make install。
使用 XDG 目录和 ~/.local/bin；--with-lsp 安装语言服务器，不自动修改 shell 配置或安装字体。
配置通过软链接部署，安装后请保留脚本所在的整个目录。
HELP
}
log() { printf '[nvim] %s\n' "$*"; }
die() { printf '[nvim] 错误：%s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
cleanup() { if [[ -n "$WORK_DIR" ]]; then rm -rf -- "$WORK_DIR"; fi; }
trap cleanup EXIT
trap 'printf "[nvim] 安装失败（第 %s 行），修复错误后可重新运行。\n" "$LINENO" >&2' ERR

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version|--method|--jobs)
            [[ $# -ge 2 ]] || die "$1 缺少参数"
            case "$1" in
                --version) NVIM_VERSION="$2"; VERSION_EXPLICIT=1 ;;
                --method) INSTALL_METHOD="$2" ;;
                --jobs) BUILD_JOBS="$2" ;;
            esac
            shift 2 ;;
        --with-lsp) WITH_LSP=1; shift ;;
        --skip-system) SKIP_SYSTEM=1; shift ;;
        --check) MODE=check; shift ;;
        --dry-run) MODE=plan; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "未知参数：$1" ;;
    esac
done
NVIM_VERSION="${NVIM_VERSION#v}"
[[ "$NVIM_VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || die '版本必须是 X.Y.Z，例如 0.11.5'
[[ "$BUILD_JOBS" =~ ^[1-9][0-9]*$ ]] || die '--jobs 必须是正整数'
case "$INSTALL_METHOD" in auto|binary|source|system) ;; *) die '--method 必须为 auto/binary/source/system' ;; esac
version_of() {
    local output
    output="$("$1" --version 2>/dev/null)" || return 1
    printf '%s\n' "$output" | sed -n '1s/^NVIM v\([0-9]*\.[0-9]*\.[0-9]*\)$/\1/p'
}
check_compatibility() {
    local major minor rest
    major="${NVIM_VERSION%%.*}"; rest="${NVIM_VERSION#*.}"; minor="${rest%%.*}"
    [[ "$major" -gt 0 || "$minor" -ge 10 ]] || die '当前配置使用的 API 要求 Neovim >= 0.10.0；更旧版本需要先调整配置和插件锁文件'
    if [[ "$NVIM_VERSION" != 0.11.5 ]]; then
        log "选择版本 ${NVIM_VERSION}；完整验证基线为 0.11.5，安装结束会检查配置兼容性"
    fi
}

[[ -f "$SOURCE_DIR/init.lua" && -f "$SOURCE_DIR/lazy-lock.json" && -f "$SOURCE_DIR/scripts/install.lua" ]] || die "请从完整的配置目录运行此脚本"
for xdg_path in "$CONFIG_ROOT" "$DATA_ROOT" "$STATE_ROOT" "$CACHE_ROOT"; do
    [[ "$xdg_path" = /* ]] || die "XDG 路径必须是绝对路径"
done
[[ -z "${NVIM_APPNAME:-}" || "$NVIM_APPNAME" == nvim ]] || die "请先取消 NVIM_APPNAME；此脚本部署标准 nvim 配置"
OS="$(uname -s)"
case "$(uname -m)" in
    x86_64|amd64) ARCH=x86_64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *) ARCH="$(uname -m)" ;;
esac
case "$OS" in
    Darwin) PLATFORM=macos ;;
    Linux)
        PLATFORM=linux
        [[ -r /etc/os-release ]] || die "无法识别 Linux 发行版"
        # shellcheck disable=SC1091
        . /etc/os-release
        case " ${ID:-} ${ID_LIKE:-} " in
            *debian*|*ubuntu*) ;;
            *) [[ "$SKIP_SYSTEM" == 1 || "$MODE" != install ]] || die "自动安装仅支持 Debian/Ubuntu；其他 Linux 请准备依赖后使用 --skip-system" ;;
        esac
        ;;
    *) die "不支持 ${OS}；Windows 请在 WSL 中运行" ;;
esac

# Do not rely on GUI applications injecting tools into PATH.
SYSTEM_NVIM="$(command -v nvim || true)"
export PATH="$BIN_DIR:$PATH"
if [[ "$OS" == Darwin ]] && ! have brew; then
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$candidate" ]]; then
            export PATH="$(dirname "$candidate"):$PATH"
            break
        fi
    done
fi

# Homebrew's gettext is keg-only; expose its build tools to this process.
if [[ "$OS" == Darwin ]] && have brew; then
    gettext_prefix="$(brew --prefix gettext 2>/dev/null || true)"
    if [[ -n "$gettext_prefix" ]]; then export PATH="$gettext_prefix/bin:$PATH"; fi
fi

if [[ "$INSTALL_METHOD" == system ]]; then
    [[ -n "$SYSTEM_NVIM" ]] || die '--method system 要求 PATH 中已有 nvim'
    detected="$(version_of "$SYSTEM_NVIM")"
    [[ -n "$detected" ]] || die '无法识别已有 Neovim 的正式发布版本'
    if [[ "$VERSION_EXPLICIT" == 1 ]]; then
        [[ "$detected" == "$NVIM_VERSION" ]] || die "已有版本 $detected 与指定版本 $NVIM_VERSION 不一致"
    else NVIM_VERSION="$detected"; fi
fi
check_compatibility

check_dependencies() {
    local missing=0 tool
    for tool in git curl tar gzip cc make rg; do
        if have "$tool"; then log "$tool: $(command -v "$tool")";
        else log "缺少：$tool"; missing=1; fi
    done
    if [[ "$INSTALL_METHOD" == auto || "$INSTALL_METHOD" == binary ]]; then
        have jq || { log '缺少：jq（读取官方发布信息及 SHA-256）'; missing=1; }
    fi
    if [[ "$INSTALL_METHOD" == auto || "$INSTALL_METHOD" == source ]]; then
        for tool in cmake c++ unzip msgfmt; do
            have "$tool" || { log "缺少源码构建依赖：$tool"; missing=1; }
        done
    fi
    if have fd || have fdfind; then log 'fd/fdfind: OK'; else log '缺少：fd（Debian 包名 fd-find）'; missing=1; fi
    if have sha256sum || have shasum; then log 'SHA-256 校验工具: OK'; else log '缺少：sha256sum 或 shasum'; missing=1; fi
    if [[ "$OS" == Linux ]]; then
        if [[ -n "${WAYLAND_DISPLAY:-}" ]] && ! have wl-copy; then log '缺少 Wayland 剪贴板：wl-clipboard'; missing=1; fi
        if [[ -n "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]] && ! have xclip && ! have xsel; then log '缺少 X11 剪贴板：xclip'; missing=1; fi
    fi
    if [[ "$WITH_LSP" == 1 ]]; then
        have clangd || { log '缺少：clangd'; missing=1; }
        if ! have node || ! have npm; then
            have node && have npm || { log '缺少：Node.js >= 20/npm（Pyright/TypeScript）'; missing=1; }
        fi
        if have node; then
            node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 20 ? 0 : 1)' || { log '需要升级 Node.js 至 >= 20'; missing=1; }
        fi
        log 'LSP：复用已有服务器；缺失时安装 LuaLS、Pyright、TypeScript、rustup/Rust 工具链及 rust-analyzer/rust-src' 
    fi
    return "$missing"
}

if [[ "$MODE" == plan ]]; then
    log "平台：$PLATFORM / ${ARCH}；Neovim：${NVIM_VERSION}；方式：${INSTALL_METHOD}；构建并发：$BUILD_JOBS"
    log "配置：$SOURCE_DIR -> ${TARGET}（已有配置自动备份）"
    log "安装目录：$DATA_ROOT/nvim-tools/nvim-$NVIM_VERSION-$PLATFORM-$ARCH-{binary,source}"
    log "命令入口：$BIN_DIR/nvim"
    log "系统依赖安装：$([[ "$SKIP_SYSTEM" == 1 ]] && echo 跳过 || echo 启用)"
    log '依赖：Git、curl、tar/gzip、C 编译器、make、ripgrep、fd；Linux 剪贴板工具'
    [[ "$INSTALL_METHOD" != auto && "$INSTALL_METHOD" != source ]] || log '源码构建额外依赖：C++ 编译器、CMake、unzip、gettext；自动下载并编译上游依赖'
    [[ "$INSTALL_METHOD" != auto && "$INSTALL_METHOD" != binary ]] || log '二进制校验额外依赖：jq'
    [[ "$WITH_LSP" != 1 ]] || log 'LSP：clangd、Node.js >= 20/npm、Pyright、LuaLS、TypeScript；rustup/Rust 工具链、rust-analyzer、rust-src'
    log '插件按 lazy-lock.json 恢复；解析器按 lua/config/parsers.lua 同步安装并验证'
    exit 0
fi
if [[ "$MODE" == check ]]; then
    result=0
    check_dependencies || result=1
    check_nvim="$(command -v nvim || true)"
    [[ "$INSTALL_METHOD" != system ]] || check_nvim="$SYSTEM_NVIM"
    if [[ -n "$check_nvim" && "$(version_of "$check_nvim")" == "$NVIM_VERSION" ]]; then
        log "Neovim $NVIM_VERSION: OK"
    else
        log "需要 Neovim ${NVIM_VERSION}（普通安装会自动准备）"; result=1
    fi
    exit "$result"
fi

# Prevent recursively moving the source directory into its own backup.
if [[ -d "$TARGET" && ! "$SOURCE_DIR" -ef "$TARGET" ]]; then
    target_real="$(cd "$TARGET" && pwd -P)"
    case "$SOURCE_DIR/" in "$target_real/"*) die "配置源目录不能位于待替换的配置目录内部" ;; esac
fi
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/nvim-install.XXXXXXXX")"

if [[ "$SKIP_SYSTEM" == 0 ]]; then
    if [[ "$OS" == Darwin ]]; then
        if ! xcode-select -p >/dev/null 2>&1; then
            die "请先运行 xcode-select --install 安装命令行工具，然后重试"
        fi
        if ! have brew; then
            curl --fail --location --retry 3 --connect-timeout 20 --max-time 300 \
                https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$WORK_DIR/homebrew.sh"
            /bin/bash "$WORK_DIR/homebrew.sh"
            for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
                if [[ -x "$candidate" ]]; then export PATH="$(dirname "$candidate"):$PATH"; break; fi
            done
        fi
        have brew || die "Homebrew 安装后仍不可用"
        packages=()
        requested=(git curl ripgrep fd)
        if [[ "$WITH_LSP" == 1 ]]; then
            if ! have node || ! have npm; then requested+=(node); fi
            have clangd || requested+=(llvm)
        fi
        if [[ "$INSTALL_METHOD" == auto || "$INSTALL_METHOD" == binary ]]; then requested+=(jq); fi
        if [[ "$INSTALL_METHOD" == auto || "$INSTALL_METHOD" == source ]]; then requested+=(cmake gettext unzip); fi
        for package in "${requested[@]}"; do
            brew list --formula "$package" >/dev/null 2>&1 || packages+=("$package")
        done
        if [[ ${#packages[@]} -gt 0 ]]; then brew install "${packages[@]}"; fi
    else
        have apt-get || die "找不到 apt-get，请使用 --skip-system 并自行准备依赖"
        elevate=()
        if [[ "$EUID" != 0 ]]; then have sudo || die "安装系统包需要 sudo"; elevate=(sudo); fi
        "${elevate[@]}" apt-get update
        requested=(ca-certificates git curl tar gzip coreutils build-essential ripgrep fd-find xclip wl-clipboard)
        if [[ "$INSTALL_METHOD" == auto || "$INSTALL_METHOD" == binary ]]; then requested+=(jq); fi
        if [[ "$INSTALL_METHOD" == auto || "$INSTALL_METHOD" == source ]]; then requested+=(cmake gettext unzip); fi
        if [[ "$WITH_LSP" == 1 ]]; then
            have clangd || requested+=(clangd)
            if ! have node || ! have npm; then requested+=(nodejs npm); fi
        fi
        "${elevate[@]}" apt-get install -y --no-install-recommends "${requested[@]}"
    fi
fi
# Homebrew's gettext is keg-only; expose its build tools to this process.
if [[ "$OS" == Darwin ]] && have brew; then
    gettext_prefix="$(brew --prefix gettext 2>/dev/null || true)"
    if [[ -n "$gettext_prefix" ]]; then export PATH="$gettext_prefix/bin:$PATH"; fi
fi

if [[ "$WITH_LSP" == 1 && "$OS" == Darwin ]] && ! have clangd && have brew; then
    llvm_prefix="$(brew --prefix llvm 2>/dev/null || true)"
    [[ -z "$llvm_prefix" ]] || export PATH="$llvm_prefix/bin:$PATH"
fi
check_dependencies || die "依赖检查未通过"
if [[ "$WITH_LSP" == 1 ]]; then bash "$SOURCE_DIR/scripts/install-lsp.sh"; fi

fetch() {
    curl --fail --silent --show-error --location --retry 3 --connect-timeout 20 --max-time 600 "$1" -o "$2"
}
install_binary() {
    [[ "$ARCH" == x86_64 || "$ARCH" == arm64 ]] || return 1
    local asset digest actual extracted legacy
    asset="nvim-$PLATFORM-$ARCH.tar.gz"
    fetch "https://api.github.com/repos/neovim/neovim/releases/tags/v$NVIM_VERSION" "$WORK_DIR/release.json" || return 1
    if ! jq -e --arg asset "$asset" '.assets | any(.name == $asset)' "$WORK_DIR/release.json" >/dev/null; then
        legacy=""
        case "$PLATFORM-$ARCH" in
            linux-x86_64) legacy=nvim-linux64.tar.gz ;;
            macos-x86_64) legacy=nvim-macos-x86_64.tar.gz ;;
        esac
        [[ -n "$legacy" ]] || return 1
        jq -e --arg asset "$legacy" '.assets | any(.name == $asset)' "$WORK_DIR/release.json" >/dev/null || return 1
        asset="$legacy"
    fi
    digest="$(jq -er --arg asset "$asset" '.assets[] | select(.name == $asset) | .digest // empty' "$WORK_DIR/release.json")" || digest=""
    if [[ -z "$digest" ]]; then
        # Older releases publish checksums in the release notes instead of the asset digest field.
        digest="$(jq -er --arg asset "$asset" '
            .body // "" | split("\n")[] | gsub("\r"; "") |
            capture("^(?<sum>[0-9a-fA-F]{64})[[:space:]]+(?<file>[^[:space:]]+)$") |
            select(.file == $asset) | "sha256:" + .sum
        ' "$WORK_DIR/release.json")" || return 1
    fi
    [[ "$digest" =~ ^sha256:[0-9a-fA-F]{64}$ ]] || return 1
    fetch "https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/$asset" "$WORK_DIR/$asset" || return 1
    if have sha256sum; then actual="$(sha256sum "$WORK_DIR/$asset")" || return 1;
    else actual="$(shasum -a 256 "$WORK_DIR/$asset")" || return 1; fi
    [[ "${actual%% *}" == "${digest#sha256:}" ]] || die 'Neovim 下载文件 SHA-256 不匹配，停止安装'
    tar -xzf "$WORK_DIR/$asset" -C "$WORK_DIR" || return 1
    extracted="$WORK_DIR/${asset%.tar.gz}"
    [[ "$(version_of "$extracted/bin/nvim")" == "$NVIM_VERSION" ]] || return 1
    INSTALL_DIR="$DATA_ROOT/nvim-tools/nvim-$NVIM_VERSION-$PLATFORM-$ARCH-binary"
    publish_install "$extracted"
}
publish_install() {
    mkdir -p "$(dirname "$INSTALL_DIR")" || return 1
    if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]]; then
        mv "$INSTALL_DIR" "$INSTALL_DIR.backup.$(date +%Y%m%d%H%M%S).$$" || return 1
    fi
    mv "$1" "$INSTALL_DIR" || return 1
    NVIM_BIN="$INSTALL_DIR/bin/nvim"
}
build_source() {
    local source stage
    source="$WORK_DIR/neovim-source"
    INSTALL_DIR="$DATA_ROOT/nvim-tools/nvim-$NVIM_VERSION-$PLATFORM-$ARCH-source"
    log "从 v$NVIM_VERSION 源码构建，最多 $BUILD_JOBS 个并行任务"
    git clone --depth 1 --branch "v$NVIM_VERSION" --single-branch https://github.com/neovim/neovim.git "$source"
    log "源码提交：$(git -C "$source" rev-parse HEAD)"
    # Use Makefiles explicitly so parallelism is controlled for both dependencies and Neovim.
    cmake -S "$source/cmake.deps" -B "$source/.deps" -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE=Release
    cmake --build "$source/.deps" --parallel "$BUILD_JOBS"
    cmake -S "$source" -B "$source/build" -G 'Unix Makefiles' \
        -DCMAKE_BUILD_TYPE=Release "-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR"
    cmake --build "$source/build" --parallel "$BUILD_JOBS"
    # Stage installation so a failed build cannot replace the current executable.
    stage="$WORK_DIR/stage"
    DESTDIR="$stage" cmake --install "$source/build"
    [[ "$(version_of "$stage$INSTALL_DIR/bin/nvim")" == "$NVIM_VERSION" ]] || die '编译产物版本校验失败'
    publish_install "$stage$INSTALL_DIR"
}

NVIM_BIN=""
if [[ "$INSTALL_METHOD" == system ]]; then
    NVIM_BIN="$SYSTEM_NVIM"
elif [[ "$INSTALL_METHOD" == auto ]] && have nvim && [[ "$(version_of "$(command -v nvim)")" == "$NVIM_VERSION" ]]; then
    NVIM_BIN="$(command -v nvim)"
else
    methods="$INSTALL_METHOD"
    [[ "$INSTALL_METHOD" != auto ]] || methods='binary source'
    for method in $methods; do
        candidate="$DATA_ROOT/nvim-tools/nvim-$NVIM_VERSION-$PLATFORM-$ARCH-$method/bin/nvim"
        if [[ -x "$candidate" && "$(version_of "$candidate")" == "$NVIM_VERSION" ]]; then NVIM_BIN="$candidate"; break; fi
    done
    if [[ -z "$NVIM_BIN" ]]; then
        case "$INSTALL_METHOD" in
            source) build_source ;;
            binary) install_binary || die '该版本没有可校验、可运行的官方二进制；请使用 --method source' ;;
            auto)
                if ! install_binary; then
                    log '官方二进制不可用（版本/架构/下载/运行兼容性），切换为源码构建'
                    build_source
                fi
                ;;
        esac
    fi
fi

mkdir -p "$BIN_DIR"
if [[ ! "$NVIM_BIN" -ef "$BIN_DIR/nvim" ]]; then
    if [[ -e "$BIN_DIR/nvim" || -L "$BIN_DIR/nvim" ]]; then
        backup="$BIN_DIR/nvim.backup.$(date +%Y%m%d%H%M%S).$$"
        mv "$BIN_DIR/nvim" "$backup"; log "旧命令入口已备份：$backup"
    fi
    ln -s "$NVIM_BIN" "$BIN_DIR/nvim"
fi

mkdir -p "$CONFIG_ROOT"
if [[ ! "$SOURCE_DIR" -ef "$TARGET" ]]; then
    if [[ -e "$TARGET" || -L "$TARGET" ]]; then
        backup="$TARGET.backup.$(date +%Y%m%d%H%M%S).$$"
        mv "$TARGET" "$backup"; log "原配置已备份：$backup"
    fi
    ln -s "$SOURCE_DIR" "$TARGET"
fi
# Preserve old sessions without deleting or overwriting the user's originals.
SESSION_DIR="$STATE_ROOT/nvim/sessions"
if [[ -d "$SOURCE_DIR/session" ]]; then
    mkdir -p "$SESSION_DIR"
    for session in "$SOURCE_DIR"/session/*.vim; do
        [[ -f "$session" ]] || continue
        destination="$SESSION_DIR/$(basename "$session")"
        [[ -e "$destination" ]] || cp "$session" "$destination"
    done
fi

export NVIM_INSTALLING=1
unset NVIM_INSTALL_STAGE
log '恢复锁定插件（不升级、不清理其他插件）'
"$NVIM_BIN" --headless -u NONE -i NONE -n -l "$SOURCE_DIR/scripts/install.lua" plugins
log '同步安装并验证解析器'
"$NVIM_BIN" --headless -u NONE -i NONE -n -l "$SOURCE_DIR/scripts/install.lua" parsers
log '验证完整配置启动'
NVIM_INSTALL_STAGE=verify "$NVIM_BIN" --headless -i NONE -n -u "$TARGET/init.lua" \
    "+lua dofile(vim.fn.stdpath('config') .. '/scripts/install.lua')" +qa
log '安装完成。请在 shell 启动文件中确保 ~/.local/bin 位于 PATH 前部：'
printf '  export PATH="$HOME/.local/bin:$PATH"\n'
log '图标需要终端使用 Nerd Font；SSH 无图形环境的剪贴板需终端支持。使用 --with-lsp 可安装 C/C++、Python、Lua、Rust、TypeScript 语言服务器。'
