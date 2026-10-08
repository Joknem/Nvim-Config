local M = {}

function M.setup()
    vim.api.nvim_create_autocmd('TextYankPost', {
        group = vim.api.nvim_create_augroup('UserYankHighlight', { clear = true }),
        callback = function()
            local hl = vim.fn.has('nvim-0.11') == 1 and vim.hl or vim.highlight
            hl.on_yank({ timeout = 500 })
        end,
    })
end

return M
