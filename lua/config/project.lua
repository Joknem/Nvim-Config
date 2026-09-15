local M = {}
local cache = {}
vim.api.nvim_create_autocmd({ 'DirChanged', 'BufFilePost', 'BufWritePost' }, {
    group = vim.api.nvim_create_augroup('UserProjectRoot', { clear = true }),
    callback = function() cache = {} end,
})

function M.root(buf)
    buf = buf or 0
    local terminal = vim.b[buf].snacks_terminal
    if terminal and terminal.cwd then return terminal.cwd end
    local cwd = vim.fn.getcwd()
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype ~= '' or name == '' then return cwd end
    local key = cwd .. '\n' .. name
    if cache[key] then return cache[key] end
    local dir = vim.fn.isdirectory(name) == 1 and name or vim.fs.dirname(name)
    local marker = vim.fs.find('.git', { path = dir, upward = true })[1]
        or vim.fs.find({ 'pyproject.toml', 'CMakeLists.txt', 'package.json',
            'Cargo.toml', 'go.mod', 'Makefile', '.project', 'tsconfig.json', 'jsconfig.json' },
            { path = dir, upward = true })[1]
    cache[key] = marker and vim.fs.dirname(marker) or dir
    return cache[key]
end

function M.filename()
    local name = vim.api.nvim_buf_get_name(0)
    if name == '' then return '[未命名]' end
    if vim.bo.buftype == 'terminal' then return '终端' end
    local root = M.root():gsub('/$', '') .. '/'
    local label = name:sub(1, #root) == root and name:sub(#root + 1) or vim.fn.fnamemodify(name, ':t')
    if vim.bo.modified then label = label .. ' [+]' end
    if vim.bo.readonly then label = label .. ' [只读]' end
    return label
end

return M
