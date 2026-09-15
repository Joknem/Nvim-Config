local function terminal()
    local snacks = require('snacks')
    -- Hide the active terminal directly, even if its shell has changed directory.
    for _, term in ipairs(snacks.terminal.list()) do
        if term.buf == vim.api.nvim_get_current_buf() then term:hide(); return end
    end
    snacks.terminal.toggle(nil, { cwd = require('config.project').root() })
end

return {
    'folke/snacks.nvim',
    tag = 'v2.30.0',
    lazy = false,
    priority = 900,
    opts = {
        indent = {
            enabled = true,
            animate = { enabled = false },
            scope = { enabled = true },
        },
        terminal = {
            enabled = true,
            win = {
                position = 'bottom', height = 0.3,
                -- Let zsh/interactive programs receive Esc, including double-Esc for sudo.
                keys = { term_normal = false },
            },
        },
    },
    keys = {
        { '<leader>ft', terminal, desc = '打开/隐藏终端' },
        { '<C-/>', terminal, mode = { 'n', 't' }, desc = '打开/隐藏终端' },
        { '<C-_>', terminal, mode = { 'n', 't' }, desc = '打开/隐藏终端' },
    },
}
