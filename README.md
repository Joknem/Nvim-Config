# Neovim 配置与快捷键

这份文档是本目录配置的使用手册。修改插件、快捷键、依赖或默认行为时，同步更新对应章节；实际启用内容以 `init.lua` 和 `lua/` 下的配置为准。

当前验证基线：Neovim **0.12.5**。安装脚本允许选择 **0.10.0 及以上**正式版本；其他版本需通过安装结束时的启动检查。

## 目录

- [安装与依赖](#安装与依赖)
- [配置文件与插件](#配置文件与插件)
- [快捷键速查](#快捷键速查)
- [界面与目录规则](#界面与目录规则)
- [LSP 与补全](#lsp-与补全)
- [检查与排障](#检查与排障)
- [维护约定](#维护约定)

## 安装与依赖

在本目录执行：

```bash
# 基础安装：Neovim、编辑插件和语法高亮；不安装/启用 LSP 与补全
./install.sh

# 只安装并启用 Python、Rust 的 LSP 和 Blink 补全
./install.sh --lsp python,rust

# 安装全部支持的语言服务器和 Blink 补全
./install.sh --with-lsp

# 自选版本并从源码编译
./install.sh --version 0.12.5 --method source --jobs 2 --with-lsp

# 复用 PATH 中已有的 Neovim
./install.sh --method system --with-lsp

# 预览安装计划／检查依赖
./install.sh --with-lsp --dry-run
./install.sh --method system --with-lsp --check

# 只补齐语言服务器（已有基础依赖时）
bash scripts/install-lsp.sh python,rust
```

| 选项 | 含义 |
| --- | --- |
| `--version X.Y.Z` | 指定正式发布版本，默认 0.12.5；也接受 `v` 前缀 |
| `--method auto` | 默认：复用同版本，否则尝试官方二进制，不可用时编译源码 |
| `--method binary` | 只使用可校验、可运行的官方二进制 |
| `--method source` | 从所选版本源码构建 |
| `--method system` | 使用原 PATH 中的 Neovim；同时指定版本时检查是否一致 |
| `--jobs N` | 源码构建并发数，默认 2 |
| `--lsp LANGS` | 按逗号分隔选择语言，可重复或使用 `--lsp=LANGS`；默认 `none` |
| `--with-lsp` | 等同 `--lsp all`，启用全部支持的 LSP 与 Blink 补全 |
| `--skip-system` | 跳过 apt/Homebrew，仍检查依赖；不等于离线安装 |
| `--dry-run` | 只显示计划 |
| `--check` | 检查安装前置依赖及 Neovim 版本，不等于完整 LSP 功能测试 |

自动安装系统包支持 macOS/Homebrew、Debian/Ubuntu（含 WSL）。其他 Linux 需先准备依赖。配置通过软链接部署，已有目标会备份；安装后保留整个源目录。脚本不自动修改 shell 启动文件。

新机器先克隆本仓库，在仓库目录运行 `./install.sh`；需要代码补全时使用例如 `./install.sh --lsp python,rust`。将以下内容加入 shell 启动文件（zsh 为 `~/.zshrc`，bash 为 `~/.bashrc`），重新打开终端后用 `command -v nvim` 确认使用 `~/.local/bin/nvim`：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

安装前会检查 Neovim 的核心 runtime 模块；`auto` 不复用检查失败的安装，`system` 则报错要求整套重装。插件按 `lazy-lock.json` 显式切换提交，有本地修改时停止。

配置会优先加载锁定的 Treesitter 插件目录中的解析器，避免旧的 `site/parser` 文件覆盖新版本。安装会同步配置列表及 runtimepath 上已有解析器，包含 regex 等嵌入语言；安装结束时验证实际加载的解析器与查询规则是否匹配。无法同步的额外解析器会使安装失败，不会静默跳过。

### 按语言选择 LSP

| 参数中的语言 | 安装并启用的服务器 | 额外运行依赖 |
| --- | --- | --- |
| `c`、`cpp`、`c++` | clangd，同时支持 C/C++ | clangd |
| `python`、`py` | Pyright | Node.js >= 20、npm |
| `lua` | LuaLS | 对应平台的 LuaLS 二进制 |
| `rust`、`rs` | rust-analyzer | Rust 工具链、Cargo、rust-src |
| `typescript`、`ts`、`javascript`、`js` | typescript-language-server，同时支持 JS/TS、JSX/TSX | Node.js >= 20、npm、TypeScript |
| `all` | 上述全部服务器 | 上述全部依赖 |
| `none`（默认） | 不安装/启用 LSP 或 Blink | 无 LSP 专用依赖 |

例如 `./install.sh --lsp cpp --lsp python` 等同 `./install.sh --lsp c,python`。只有 Python/JS/TS 需要 Node.js/npm；只选 Lua 或 Rust 不会要求它们或 clangd。

每次安装用本次参数**替换**本机启用列表；例如从 Python 切换到 Python+Rust，需传 `--lsp python,rust`。不带 `--lsp` 重新安装会关闭 LSP 和 Blink，但不删除已下载的插件、服务器或工具链。语法高亮解析器独立安装，不受 LSP 选择影响。

选择保存在 `${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lsp-languages`，安装验证通过后才更新，不写入 Git 仓库；新机器需重新选择。没有该文件时默认关闭，包括从旧版配置更新后首次使用；运行一次带语言参数的安装即可启用。`scripts/install-lsp.sh LANGS` 只补齐服务器，不改变启用列表或安装 Blink，完整设置请用 `install.sh --lsp LANGS`。

### 外部依赖

| 用途 | 依赖 |
| --- | --- |
| 下载、安装插件 | Git、curl、tar、gzip、SHA-256 工具 |
| 搜索 | ripgrep（命令 `rg`）；脚本也安装 fd（Debian/Ubuntu 命令可为 `fdfind`） |
| 编译 Treesitter 解析器 | C 编译器、make |
| Neovim 二进制安装 | jq，用于读取官方发布信息与校验值 |
| Neovim 源码构建 | C/C++ 编译器、make、CMake、unzip、gettext |
| 图标显示 | 终端选择 Nerd Font；不是 Neovim 插件 |
| Linux 剪贴板 | Wayland 使用 wl-clipboard，X11 使用 xclip/xsel；远程环境另需终端支持 |
| Python、TypeScript LSP | Node.js >= 20、npm |
| C/C++ LSP | clangd |
| Lua LSP | lua-language-server |
| Rust LSP | rustup/Rust 工具链、Cargo、rust-analyzer、rust-src |

`rg`、`fd`、语言服务器都是外部程序，不是编辑器插件。blink 使用 Lua 匹配器，自身不需要 Rust；Rust 工具链用于 Rust 开发。

服务器优先复用已有安装。缺失时脚本安装 Pyright 1.1.408、typescript-language-server 5.1.3、TypeScript 5.9.3、LuaLS 3.19.1；Rust 新安装使用 stable 工具链，已有 rustup 安装则补齐当前工具链的组件。

用户安装的 LSP 位于 `${XDG_DATA_HOME:-$HOME/.local/share}/nvim-tools/lsp`。Rust 通常位于 `~/.cargo`、`~/.rustup`；Neovim 自动把 Cargo 的 bin 目录加入自身 PATH。外部终端使用 Rust 时，可执行：

```bash
source "$HOME/.cargo/env"
```

## 配置文件与插件

### 配置入口

| 文件 | 职责 |
| --- | --- |
| [init.lua](init.lua) | 普通 Neovim／VS Code 嵌入模式入口 |
| [lua/options.lua](lua/options.lua) | 缩进、行号、窗口、搜索、剪贴板、持久撤销 |
| [lua/keymaps.lua](lua/keymaps.lua) | 保存、窗口导航、调整大小等通用快捷键 |
| [lua/config/bootstrap.lua](lua/config/bootstrap.lua) | 引导安装 lazy.nvim |
| [lua/config/project.lua](lua/config/project.lua) | 搜索、终端、状态栏共享的项目目录逻辑 |
| [lua/config/lsp.lua](lua/config/lsp.lua) | 语言服务器启动与 LSP 快捷键 |
| [lua/config/lsp_selection.lua](lua/config/lsp_selection.lua) | 读取本机语言选择，控制 LSP 与 Blink 启用 |
| [lua/config/rust_standalone.lua](lua/config/rust_standalone.lua) | 独立 Rust 文件的轻量加载与服务复用 |
| [lua/config/parsers.lua](lua/config/parsers.lua) | 编辑器与安装脚本共用的语法解析器列表 |
| [lazy-lock.json](lazy-lock.json) | 插件提交锁定；存在条目不代表插件已启用 |
| [install.sh](install.sh) | Neovim 版本选择、依赖与配置部署 |
| [scripts/install.lua](scripts/install.lua) | 锁定插件恢复、解析器安装与启动验证 |
| [scripts/install-lsp.sh](scripts/install-lsp.sh) | 语言服务器安装入口 |
| [scripts/install-rust-lsp.sh](scripts/install-rust-lsp.sh) | Rust 工具链与 LSP 组件安装 |

### 已启用插件

| 插件 | 用途与当前设置 | 配置 |
| --- | --- | --- |
| lazy.nvim | 插件管理，按锁文件复现版本 | [bootstrap.lua](lua/config/bootstrap.lua)、[init.lua](init.lua) |
| onedark.nvim | OneDark 配色 | [theme.lua](lua/plugins/theme.lua) |
| bufferline.nvim | 顶部文件标签、H/L 切换、关闭文件保留分屏 | [bufferline.lua](lua/plugins/bufferline.lua) |
| lualine.nvim | 底部全局状态栏、项目相对路径、诊断数量 | [lualine.lua](lua/plugins/lualine.lua) |
| nvim-web-devicons | 文件类型图标 | [web-devicons.lua](lua/plugins/web-devicons.lua) |
| nvim-tree.lua | 文件树；Git 标记当前关闭 | [nvim-tree.lua](lua/plugins/nvim-tree.lua) |
| telescope.nvim | 文件、文本、Buffer、历史文件搜索；宽窄屏自适应 | [telescope.lua](lua/plugins/telescope.lua) |
| plenary.nvim | Telescope 的工具库依赖 | [telescope.lua](lua/plugins/telescope.lua) |
| nvim-treesitter | 语法高亮、按语法节点扩大选择；锁定旧 master 分支 API | [treesitter.lua](lua/plugins/treesitter.lua) |
| rainbow-delimiters.nvim | 配对括号分层着色；跳过补全菜单等界面缓冲区及没有解析器的文件 | [rainbow.lua](lua/plugins/rainbow.lua) |
| nvim-autopairs | 输入括号、引号时自动配对 | [autopairs.lua](lua/plugins/autopairs.lua) |
| flash.nvim | 屏幕内标签跳转 | [flash.lua](lua/plugins/flash.lua) |
| persistence.nvim | 保存、选择、恢复编辑会话 | [persistence.lua](lua/plugins/persistence.lua) |
| render-markdown.nvim | Markdown 编辑区渲染；Lazy 中保留名称 `markdown.nvim` | [render-markdown.lua](lua/plugins/render-markdown.lua) |
| blink.cmp（选定 LSP 语言时启用） | 仅 LSP 补全，Lua 匹配器，圆角菜单 | [blink.lua](lua/plugins/blink.lua) |
| snacks.nvim | 缩进线、当前代码块提示、底部终端；调用 bufdelete 保留布局 | [snacks.lua](lua/plugins/snacks.lua)、[bufferline.lua](lua/plugins/bufferline.lua) |

`lsp_bak.lua` 和 `dashboard.lua` 返回空表，不启用其中的旧配置。当前没有启用 Ranger、格式化插件、Trouble、which-key、AI 补全或额外代码片段来源。

## 快捷键速查

- `<leader>` 是**空格**。例如 `空格 f w` 表示依次按空格、f、w。
- `H`、`L`、`K`、`P` 表示大写，即 Shift 加对应字母。
- `Ctrl+…` 表示同时按下。
- 除单独注明外，下表均为**普通模式**快捷键；插入模式先按 Esc 或快速输入 `jk`。

### 基础操作与窗口

| 按键 | 功能 |
| --- | --- |
| `空格 s` | 保存当前文件 |
| `空格 g u n` | 强制退出当前窗口（`:quit!`）；可能丢弃未保存修改 |
| `空格 n h` | 清除搜索高亮 |
| `空格 [` / `空格 ]` | 跳转记录后退／前进 |
| `jk`（插入模式） | 返回普通模式 |
| `空格 -` | 上下分屏，新窗口在下方 |
| `空格 \` | 左右分屏，新窗口在右方 |
| `空格 h/j/k/l` | 切换到左／下／上／右窗口 |
| `Command+Option+h/j/k/l`（macOS） | 普通、插入、终端输入模式下直接切换左／下／上／右窗口 |
| `Ctrl+Alt+h/j/k/l`（Windows/Linux/WSL，也可在 macOS 使用） | 同上；终端输入模式自动退出后切窗口 |
| `空格 x` | 关闭当前窗口 |
| `空格 =` | 均分窗口大小 |
| `Ctrl+↑` / `Ctrl+↓` | 高度增加／减少 2 行 |
| `Ctrl+←` / `Ctrl+→` | 宽度减少／增加 4 列 |
| `H` / `L` | 切换到上一个／下一个文件 Buffer |
| `空格 b d` | 关闭当前文件，保留分屏布局；未保存时提示处理 |

分屏最初显示同一个文件；在其中一侧搜索并打开其他文件即可对照编辑。顶部标签主要代表 **Buffer（打开的文件）**，并非 Neovim 原生 tabpage。

### 搜索：Telescope

| 按键 | 功能 |
| --- | --- |
| `空格 p` | 搜索项目文件名 |
| `空格 P` | 搜索项目文本内容（live_grep） |
| `空格 f b` | 搜索已打开的 Buffer |
| `空格 f w` | 搜索光标下的单词（grep_string） |
| `空格 /` | 在当前文件内模糊搜索整行 |
| `空格 r s` | 恢复上一次搜索窗口 |
| `Ctrl+q` | 最近打开过的文件 |

`空格 f w` 先用光标下的词查找，随后输入内容是在已有结果里过滤。要搜索另一个词，使用 `空格 P`。

搜索窗口内常用的 **Telescope 默认键位**：

| 按键 | 功能 |
| --- | --- |
| `Ctrl+n` / `Ctrl+p` | 下一项／上一项 |
| `Enter` | 打开选中结果 |
| `Ctrl+v` / `Ctrl+x` | 左右／上下分屏打开 |
| `Ctrl+t` | 在原生新标签页打开 |
| `Ctrl+c` | 插入模式下关闭搜索窗口 |
| `Esc` | 从插入模式进入普通模式，再按 Esc 关闭 |
| `Tab` / `Shift+Tab` | 标记或取消多选并移动；与 blink 补全菜单的 Tab 不同 |

### 文件树：nvim-tree

`空格 t` 打开／关闭文件树。以下是**文件树窗口内的插件默认键位**：

| 按键 | 功能 |
| --- | --- |
| `Enter` | 打开文件／展开目录 |
| `Ctrl+v` / `Ctrl+x` | 左右／上下分屏打开文件 |
| `a` | 新建文件或目录 |
| `r` | 重命名 |
| `d` | 删除文件或目录，不只是关闭 Buffer |
| `c` / `x` / `p` | 复制／剪切／粘贴 |
| `R` | 刷新文件树 |
| `g?` | 查看文件树完整键位帮助 |

### LSP 与补全

以下普通模式键位在语言服务器连接后生效：

| 按键 | 功能 |
| --- | --- |
| `gd` | 跳转定义 |
| `K`（Shift+K） | 优先显示光标处诊断；没有诊断时显示文档 |
| `gpr` | 使用 Telescope 查看引用 |
| `空格 r n` | 重命名符号 |
| `空格 c a` | 代码操作 |

启用 LSP 后，插入模式的 **blink 补全菜单**：

| 按键 | 功能 |
| --- | --- |
| `Tab` / `Shift+Tab` | 下一项／上一项 |
| `Enter` | 确认选中项；未选择时确认第一项 |
| `Ctrl+e` | 关闭补全窗口 |
| `Ctrl+空格` | 手动触发补全；菜单已打开时显示／隐藏文档 |

补全菜单未打开时，Tab、Shift+Tab、Enter 回退到原有映射或原生行为。菜单不自动选中、不预先插入候选文字，但菜单打开时直接按 Enter 会接受第一项。

### 终端、会话与跳转

| 按键 | 模式／范围 | 功能 |
| --- | --- | --- |
| `空格 f t` | 普通模式 | 打开／隐藏当前项目终端 |
| `Ctrl+/` | 普通模式、终端输入模式 | 打开／隐藏终端；同时配置了等价编码 `Ctrl+_` |
| `Ctrl+\` 后按 `Ctrl+n` | 终端输入模式 | 进入终端普通模式；随后 `空格 k` 切到上方编辑器 |
| `q` | Snacks 终端普通模式，插件默认 | 隐藏终端 |
| `空格 q s` | 普通模式 | 恢复当前目录会话 |
| `空格 q S` | 普通模式 | 选择会话 |
| `空格 a` | 普通模式 | 恢复最近一次会话 |
| `空格 q d` | 普通模式 | 停止当前会话的自动保存 |
| `空格 空格 f` | 普通模式 | Flash 跳转：输入查找字符，再按目标标签 |
| `v` | 可视模式，支持的 Treesitter Buffer | 扩大到上一级语法节点 |
| `Backspace` | 可视模式，支持的 Treesitter Buffer | 缩小语法节点选择 |

普通模式的 `v` 仍然进入可视选择；可视模式再次按 `v` 已被 Treesitter 改成扩大选择，退出选择使用 Esc。

已关闭 Snacks 默认的双 Esc 映射，Esc 完整交给 shell／终端程序，避免与 zsh sudo 插件冲突。终端输入模式下不映射 Ctrl+h/j/k/l，保留 shell 的原有按键行为。

快速来回切换：macOS 用 `Command+Option+k` 从底部终端到上方编辑器，`Command+Option+j` 回到下方终端；Windows/Linux/WSL 对应 `Ctrl+Alt+k/j`。Snacks 终端恢复焦点时默认进入输入模式。不要与只按 Ctrl+h/j/k/l 混淆。

Command 组合键依赖终端转发，Neovim 中记作 `<D-A-h>` 等。Ghostty 支持扩展键盘协议；若组合键被系统或终端拦截，需在终端端解除绑定或配置转发，单独修改 Neovim 无法接收被拦截的按键。VS Code 嵌入模式仍使用宿主编辑器自己的窗口快捷键。

终端隐藏后进程和 shell 当前目录保留。输入 `exit` 退出 shell。会话保存的是编辑布局等状态，不会在退出 Neovim 后继续保留终端进程。

### 常用 Neovim 原生操作（非自定义映射）

| 操作 | 功能 |
| --- | --- |
| `Ctrl+w` 后按 `o` | 只保留当前窗口 |
| `Ctrl+w` 后按 `=` | 均分窗口 |
| `Ctrl+\` 后按 `Ctrl+n` | 从终端输入模式返回普通模式 |
| `:split 文件名` / `:vsplit 文件名` | 分屏打开指定文件 |
| `:cd 路径` / `:lcd 路径` | 改变全局／当前窗口工作目录 |
| `:pwd` | 查看当前工作目录 |
| `:help` | 打开内置帮助 |

macOS 或终端可能拦截 Ctrl+方向键、Ctrl+空格、Ctrl+/；需要在终端／系统快捷键设置中放行。窗口大小也可使用 `:resize +2`、`:vertical resize +4` 调整。

## 界面与目录规则

- OneDark 主题；全局状态栏显示模式、分支、诊断、项目相对路径、文件类型与位置。
- 显示绝对行号和相对行号，4 空格缩进，开启鼠标和持久撤销。
- 分屏向右／向下打开；上下、左右滚动余量各 5。
- blink、诊断／悬浮文档、Telescope 使用圆角边框。
- Telescope 占宽度约 90%、高度约 85%；按 120 列阈值切换横向／纵向布局。
- 缩进线与当前代码块提示开启，缩进动画关闭。
- 终端从底部打开，高度约 30%。

### 搜索与终端共用项目根目录

实现：[lua/config/project.lua](lua/config/project.lua)。

1. 从当前文件所在目录向上查找 `.git`，支持 Git worktree 的 `.git` 文件。
2. 没有 Git 根目录时，查找 `pyproject.toml`、`CMakeLists.txt`、`package.json`、`Cargo.toml`、`go.mod`、`Makefile`、`.project`、`tsconfig.json`、`jsconfig.json`。
3. 独立文件使用所在目录；未命名或特殊 Buffer 使用当前工作目录；Snacks 终端使用创建时的目录。

Telescope 包含隐藏文件，遵守 ripgrep 的忽略规则，排除 `.git` 内容。终端按项目目录复用；在 shell 中 `cd` 不改变 Neovim 的项目识别规则。`autochdir=false`，切换文件不会自动执行 `:cd`；显式 `:cd` 也不会覆盖命名文件的项目根目录识别。

LSP 的根目录按语言单独识别，不强制使用上述 Git 优先规则。会话由 persistence 按其目录逻辑管理，也不等同于这个项目根目录函数。

## LSP 与补全

默认关闭。安装时指定 `--lsp` 后，仅为选中的语言通过原生 `vim.lsp.start` 启动服务，同时启用 Blink 补全；无需额外安装 nvim-lspconfig、Mason 或旧的 nvim-cmp 栈。

| 语言 | 服务 | 主要配置 |
| --- | --- | --- |
| C/C++ | clangd | 后台索引；关闭函数参数占位符 |
| Python | Pyright | 关闭自动导入补全，诊断范围为打开的文件 |
| Lua | LuaLS | 编辑本 Neovim 配置时提供 `vim` 全局和运行时库信息 |
| Rust | rust-analyzer | Cargo 项目正常加载；独立文件使用下述专用逻辑 |
| TypeScript/JavaScript、TSX/JSX | typescript-language-server | 关闭自动导入候选 |

补全仅启用 LSP 来源，同时关闭其 Buffer 回退；没有 Buffer 单词、独立路径、代码片段、AI 来源，没有 blink 命令行／终端补全。语言服务器自己仍可能提供路径、关键字等候选。关闭灰色预览、自动文档弹窗和自动参数提示；Tab、Enter 不用于跳转代码片段。

没有配置保存时格式化。autopairs 的括号配对、Treesitter 的语法高亮与补全来源是不同功能。

### 独立 Rust 文件

没有 Cargo.toml 或 rust-project.json 时：

- 异步查询 rustc 工具链路径，用内存中的项目描述加载文件，不在用户目录生成 Cargo.toml。
- 同目录文件共用一个 rust-analyzer；按 Rust 2021 edition 分析。
- 保留标准库信息，关闭后台缓存预热、Cargo 保存检查、构建脚本和过程宏，使用 2 个工作线程。
- 首次加载标准库、增加新文件可能仍有等待；不提供完整 Cargo 编译诊断或 Cargo 依赖管理。

需要第三方 crate、项目级检查、不同 edition 或完整构建行为时，使用真实 Cargo 项目。

### VS Code 嵌入模式

当 `vim.g.vscode` 为真时，`init.lua` 不加载本套插件、LSP 和 options，仅配置空格 Leader、`H/L` 切换编辑器、`空格 s` 保存、插入模式 `jk` 退出。其余界面和语言功能由宿主编辑器管理。

## 检查与排障

| 操作 | 用途 |
| --- | --- |
| `:Lazy` | 查看启用插件和加载情况 |
| `:checkhealth` | 检查环境；只关注实际启用功能的相关项 |
| `:messages` | 查看报错历史 |
| `:lua print(vim.inspect(vim.lsp.get_clients({bufnr=0})))` | 查看当前文件连接的 LSP |
| `:lua print(vim.lsp.get_log_path())` | 查看 LSP 日志文件位置 |
| `:lua print(vim.fn.exepath('rg'))` | 检查搜索实际使用哪个 rg |
| `:lua print(require('config.project').root())` | 查看搜索／终端识别的项目目录 |
| `:verbose nmap K` | 检查 K 的实际映射来源 |
| `:verbose imap <Tab>` | 检查插入模式 Tab 的映射来源 |
| `:Telescope keymaps` | 搜索当前映射，无需额外按键提示插件 |

常见情况：

- **搜索没结果**：确认 `rg` 存在、项目目录正确，以及目标未被忽略；`空格 fw` 不能用于重新搜索任意新词。
- **补全没结果**：检查文件类型、语言服务器是否连接及可执行程序是否存在。
- **Rust 找不到工作区／卡顿**：退出旧 Neovim 后重开以加载新配置；检查是否使用独立文件配置及是否缺少 rust-src。
- **图标乱码**：让终端使用 Nerd Font。
- **修改配置没生效**：重启 Neovim；修改服务器配置后已有 LSP 进程不会自动套用全部变化。

会话默认放在 Neovim state 目录的 `sessions/` 下，通常为 `~/.local/state/nvim/sessions/`。旧 `session/` 目录中的文件属于历史会话；安装脚本只复制缺失项，不覆盖新会话。

## 维护约定

后续修改本项目时：

1. 改插件：同步“已启用插件”表；新增启用项必须有对应锁文件条目。
2. 改按键：同步所属快捷键表，注明模式、覆盖的默认行为和无候选时的回退。
3. 改服务器、安装版本或依赖：同步安装与 LSP 章节，检查脚本是否能在新机器补齐依赖。
4. 改项目识别：一起核对搜索、终端和状态栏，不把会话根目录、LSP 根目录混为一谈。
5. 插件升级需验证现有 Neovim 版本和 Treesitter API；不要仅因锁文件中存在条目就把它写成已启用插件。
6. 临时测试代码、测试项目和日志在检查结束后清理。

快捷键表覆盖本配置的自定义操作及常用插件默认键位；完整原生键位查询 `:help`，完整插件默认键位查询对应插件帮助。

### 安装参数回归测试

无需联网或安装语言服务器，使用 Python 3 与 Neovim 执行：

```bash
python3 -m unittest discover -s tests -v
```

覆盖默认关闭、参数别名与非法参数、按语言安装依赖、本机选择读取，以及仅启动所选语言服务器。
