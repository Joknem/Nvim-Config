-- Machine-local choices are written only after a successful install.
local M = {}
local selection = vim.env.NVIM_LSP_LANGUAGES
if selection == 'none' then selection = '' end
if selection == nil then
    local path = vim.fn.stdpath('data') .. '/lsp-languages'
    selection = vim.fn.filereadable(path) == 1 and table.concat(vim.fn.readfile(path), ',') or ''
end
local servers = { c = 'clangd', python = 'pyright', lua = 'lua_ls', rust = 'rust_analyzer', typescript = 'ts_ls' }
M.servers = {}
M.languages = {}
for language in selection:gmatch('[^,]+') do
    local server = assert(servers[language], '未知 LSP 语言配置：' .. language)
    M.servers[server] = true
    M.languages[#M.languages + 1] = language
end
M.enabled = next(M.servers) ~= nil
return M
