-- Run with nvim --headless -u NONE -i NONE -n -l tests/lsp-selection.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local data = vim.fn.tempname()
vim.fn.mkdir(data, 'p')
local original_stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind) return kind == 'data' and data or original_stdpath(kind) end
local function load(selection)
    vim.env.NVIM_LSP_LANGUAGES = selection
    package.loaded['config.lsp_selection'] = nil
    return require('config.lsp_selection')
end
assert(not load(nil).enabled, 'fresh machines must default to no LSP')
vim.fn.writefile({ 'python,lua' }, data .. '/lsp-languages')
assert(load(nil).servers.pyright and load(nil).servers.lua_ls, 'saved selection must load')
assert(not load('none').enabled, 'explicit none selection must override saved choice')
assert(load('rust').servers.rust_analyzer and not load('rust').servers.pyright)
assert(dofile('lua/plugins/blink.lua').enabled, 'selected language must enable Blink')
load('none')
assert(not dofile('lua/plugins/blink.lua').enabled, 'base profile must exclude Blink')
package.loaded['blink.cmp'] = { get_lsp_capabilities = vim.lsp.protocol.make_client_capabilities }
local starts = {}
vim.lsp.start = function(config) starts[#starts + 1] = config.name end
-- Avoid depending on installed server binaries; this test verifies routing.
vim.fn.executable = function() return 1 end
load('python,lua')
require('config.lsp').setup()
for _, ft in ipairs({ 'c', 'python', 'lua', 'rust', 'typescript' }) do
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, data .. '/test.' .. ft)
    vim.bo[buf].filetype = ft
    vim.api.nvim_buf_delete(buf, { force = true })
end
assert(vim.deep_equal(starts, { 'pyright', 'lua_ls' }), vim.inspect(starts))
vim.fn.delete(data, 'rf')
print('LSP selection, persistence, Blink gating and server routing: OK')
