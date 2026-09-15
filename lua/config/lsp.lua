local M = {}

-- Native vim.lsp.start works on both Neovim 0.10 and 0.11.
function M.setup()
    local tool_root = vim.fn.stdpath('data'):gsub('/nvim$', '') .. '/nvim-tools/lsp'
    local cargo_bin = (vim.env.CARGO_HOME or (vim.env.HOME .. '/.cargo')) .. '/bin'
    if vim.fn.isdirectory(cargo_bin) == 1 then
        -- Make rustup's cargo/rustc proxies available to rust-analyzer and terminals.
        vim.env.PATH = cargo_bin .. ':' .. vim.env.PATH
    end
    local servers = {
        clangd = {
            filetypes = { 'c', 'cpp' },
            cmd = { 'clangd', '--background-index', '--function-arg-placeholders=0' },
            fallback = vim.fn.has('mac') == 1 and (vim.uv.os_uname().machine == 'arm64'
                and '/opt/homebrew/opt/llvm/bin/clangd' or '/usr/local/opt/llvm/bin/clangd') or nil,
            markers = { 'compile_commands.json', 'compile_flags.txt', '.clangd', '.git' },
        },
        pyright = {
            filetypes = { 'python' },
            cmd = { 'pyright-langserver', '--stdio' },
            fallback = tool_root .. '/node_modules/.bin/pyright-langserver',
            markers = { 'pyrightconfig.json', 'pyproject.toml', 'setup.py', '.git' },
        },
        lua_ls = {
            filetypes = { 'lua' },
            cmd = { 'lua-language-server' },
            fallback = tool_root .. '/lua-language-server/bin/lua-language-server',
            markers = { '.luarc.json', '.luarc.jsonc', '.git' },
        },
        rust_analyzer = {
            filetypes = { 'rust' },
            cmd = { 'rust-analyzer' },
            fallback = cargo_bin .. '/rust-analyzer',
            markers = { 'Cargo.toml', 'rust-project.json' },
            settings = { ['rust-analyzer'] = {
                completion = { autoimport = { enable = false }, callable = { snippets = 'none' } },
            } },
        },
        ts_ls = {
            filetypes = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' },
            cmd = { 'typescript-language-server', '--stdio' },
            fallback = tool_root .. '/node_modules/.bin/typescript-language-server',
            markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
            init_options = { preferences = {
                includeCompletionsForModuleExports = false,
                includeCompletionsForImportStatements = false,
            } },
        },
    }
    local capabilities = require('blink.cmp').get_lsp_capabilities()
    capabilities.textDocument.completion.completionItem.snippetSupport = false
    local group = vim.api.nvim_create_augroup('UserLsp', { clear = true })
    local warned = {}
    vim.api.nvim_create_autocmd('FileType', {
        group = group,
        callback = function(event)
            if vim.bo[event.buf].buftype ~= '' then return end
            local filename = vim.api.nvim_buf_get_name(event.buf)
            if filename == '' then return end
            for name, server in pairs(servers) do
                if vim.tbl_contains(server.filetypes, vim.bo[event.buf].filetype) then
                    local cmd = vim.deepcopy(server.cmd)
                    if name == 'ts_ls' and vim.fn.executable('tsserver') ~= 1
                        and vim.fn.executable(server.fallback) == 1 then
                        cmd[1] = server.fallback
                    end
                    if vim.fn.executable(cmd[1]) ~= 1 then
                        if server.fallback and vim.fn.executable(server.fallback) == 1 then
                            cmd[1] = server.fallback
                        else
                            if not warned[name] then
                                warned[name] = true
                                vim.notify('缺少 ' .. cmd[1] .. '，请运行 install.sh --with-lsp 安装语言服务器', vim.log.levels.WARN)
                            end
                            return
                        end
                    end
                    local dir = vim.fs.dirname(filename)
                    local marker = vim.fs.find(server.markers, { path = dir, upward = true })[1]
                    local root = marker and vim.fs.dirname(marker) or dir
                    local settings = name == 'pyright' and { python = { analysis = {
                        -- Keep suggestions in scope; do not offer symbols that need a new import.
                        autoImportCompletions = false,
                        autoSearchPaths = true, useLibraryCodeForTypes = true, diagnosticMode = 'openFilesOnly',
                    } } } or vim.deepcopy(server.settings)
                    if name == 'lua_ls' then
                        settings = { Lua = { completion = { callSnippet = 'Disable', workspaceWord = false } } }
                        local config_dir = vim.uv.fs_realpath(vim.fn.stdpath('config')) or vim.fn.stdpath('config')
                        local real_file = vim.uv.fs_realpath(filename) or filename
                        if real_file:sub(1, #config_dir + 1) == config_dir .. '/' then
                            root = config_dir
                            settings.Lua.runtime = { version = 'LuaJIT' }
                            settings.Lua.diagnostics = { globals = { 'vim' } }
                            settings.Lua.workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } }
                        end
                    end
                    local init_options = vim.deepcopy(server.init_options)
                    local start_opts = { bufnr = event.buf }
                    if name == 'rust_analyzer' then
                        if not marker then
                            require('config.rust_standalone').start({
                                name = name, cmd = cmd,
                                capabilities = vim.deepcopy(capabilities), settings = settings,
                            }, event.buf, filename)
                            return
                        end
                        init_options = vim.deepcopy(settings['rust-analyzer'])
                        -- A Cargo project must not reuse a standalone client in the same directory.
                        start_opts.reuse_client = function(client, config)
                            return client.name == config.name and client.config.root_dir == config.root_dir
                                and not (client.config.init_options or {}).linkedProjects
                        end
                    end
                    vim.lsp.start({ name = name, cmd = cmd, root_dir = root,
                        init_options = init_options,
                        capabilities = vim.deepcopy(capabilities), settings = settings }, start_opts)
                end
            end
        end,
    })
    vim.api.nvim_create_autocmd('LspAttach', {
        group = group,
        callback = function(event)
            local function map(key, action, desc)
                vim.keymap.set('n', key, action, { buffer = event.buf, desc = 'LSP: ' .. desc })
            end
            map('gd', vim.lsp.buf.definition, '跳转定义')
            map('K', function()
                local float_buf = vim.diagnostic.open_float(nil, {
                    scope = 'cursor',
                    border = 'rounded',
                    source = 'if_many',
                    severity_sort = true,
                })
                if not float_buf then vim.lsp.buf.hover({ border = 'rounded' }) end
            end, '查看当前位置诊断或文档')
            map('gpr', '<cmd>Telescope lsp_references<CR>', '查看引用')
            map('<leader>rn', vim.lsp.buf.rename, '重命名')
            map('<leader>ca', vim.lsp.buf.code_action, '代码操作')
        end,
    })
end

return M
