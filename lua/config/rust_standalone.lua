local M = {}
local directories = {}

-- Describe loose files explicitly instead of asking rust-analyzer to discover Cargo projects.
function M.start(config, bufnr, filename)
    local dir = vim.fs.dirname(filename)
    local state = directories[dir]
    if not state then
        state = { files = {}, pending = {} }
        directories[dir] = state
    end
    state.files[filename] = true
    state.pending[bufnr] = filename

    local function attach()
        local crates = {}
        for file in pairs(state.files) do
            crates[#crates + 1] = { root_module = file, edition = '2021', deps = {} }
        end
        table.sort(crates, function(a, b) return a.root_module < b.root_module end)
        local opts = vim.deepcopy(config.settings['rust-analyzer'])
        opts.linkedProjects = { {
            crates = crates,
            sysroot = state.sysroot,
            sysroot_src = state.sysroot .. '/lib/rustlib/src/rust/library',
        } }
        opts.checkOnSave = false
        opts.cachePriming = { enable = false }
        opts.numThreads = 2
        opts.cargo = { buildScripts = { enable = false } }
        opts.procMacro = { enable = false }
        config.root_dir = dir
        config.init_options = opts
        config.settings = { ['rust-analyzer'] = opts }
        config.flags = { debounce_text_changes = 200 }

        local client = state.client_id and vim.lsp.get_client_by_id(state.client_id)
        if client and not client:is_stopped() then
            if not vim.deep_equal(client.config.settings, config.settings) then
                client.config.settings = vim.deepcopy(config.settings)
                client.settings = vim.deepcopy(config.settings)
                if client.initialized then
                    client.notify('workspace/didChangeConfiguration', { settings = config.settings })
                end
            end
        else
            state.client_id = nil
        end
        for buf, file in pairs(state.pending) do
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == file then
                if state.client_id then
                    vim.lsp.buf_attach_client(buf, state.client_id)
                else
                    state.client_id = vim.lsp.start(config, {
                        bufnr = buf,
                        reuse_client = function() return false end,
                    })
                end
            end
        end
        state.pending = {}
    end

    if state.sysroot then return attach() end
    if state.loading then return end
    state.loading = true
    -- Toolchain discovery must not block typing, and is shared by files in this directory.
    vim.system({ 'rustc', '--print', 'sysroot' }, { cwd = dir, text = true, timeout = 10000 }, function(result)
        vim.schedule(function()
            state.loading = false
            if result.code ~= 0 or vim.trim(result.stdout or '') == '' then
                state.pending = {}
                vim.notify('无法读取 Rust 工具链：' .. (result.stderr or ''), vim.log.levels.ERROR)
                return
            end
            state.sysroot = vim.trim(result.stdout)
            attach()
        end)
    end)
end

return M
