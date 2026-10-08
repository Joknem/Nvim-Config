-- Run without user configuration so a broken runtime cannot pass via plugins.
local ok, err = xpcall(function()
    local hl = vim.fn.has('nvim-0.11') == 1 and require('vim.hl') or require('vim.highlight')
    assert(type(hl.on_yank) == 'function', 'missing yank highlighter')
    require('vim.treesitter')
    require('vim.lsp')
    require('vim.diagnostic')
end, debug.traceback)
if not ok then
    io.stderr:write('Neovim runtime 检查失败：' .. tostring(err) .. '\n')
    vim.cmd('cquit 1')
end
