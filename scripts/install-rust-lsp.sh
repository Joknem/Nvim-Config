#!/usr/bin/env bash
set -Eeuo pipefail
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
WORK=""
trap 'if [[ -n "$WORK" ]]; then rm -rf -- "$WORK"; fi' EXIT
if ! command -v rustup >/dev/null 2>&1; then
    # Respect an existing non-rustup installation; do not replace its toolchain.
    if command -v rustc >/dev/null 2>&1; then
        sysroot="$(rustc --print sysroot)"
        if command -v cargo >/dev/null 2>&1 && rust-analyzer --version >/dev/null 2>&1 \
            && [[ -d "$sysroot/lib/rustlib/src/rust/library" ]]; then
            echo '[nvim] 复用已有 Rust 工具链、rust-analyzer 和标准库源码'
            exit 0
        fi
        echo '已有非 rustup 管理的 Rust：请补齐 cargo、rust-analyzer 和标准库源码，或自行迁移至 rustup 后重试。' >&2
        exit 1
    fi
    WORK="$(mktemp -d "${TMPDIR:-/tmp}/nvim-rust-install.XXXXXXXX")"
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --connect-timeout 20 --max-time 300 \
        https://sh.rustup.rs -o "$WORK/rustup-init.sh"
    sh "$WORK/rustup-init.sh" -y --no-modify-path --profile minimal --default-toolchain stable \
        --component rust-analyzer --component rust-src
else
    active="$(rustup show active-toolchain 2>/dev/null || true)"
    if [[ -z "$active" ]]; then
        rustup toolchain install stable --profile minimal --component rust-analyzer --component rust-src
        rustup default stable
    else
        toolchain="${active%% *}"
        rustup component add --toolchain "$toolchain" rust-analyzer rust-src
    fi
fi
rust-analyzer --version
cargo --version
echo '[nvim] Rust LSP 已就绪；Neovim 会自动把 Cargo bin 目录加入自身 PATH'
