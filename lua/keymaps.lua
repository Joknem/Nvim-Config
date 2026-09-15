local opts = {
    noremap = true,
    silent = true
}
local keymaps = vim.keymap
-- Normal mode
vim.g.mapleader = " "
keymaps.set('n', "<leader>-", "<C-w>s")
keymaps.set('n', "<leader>\\", "<C-w>v")
keymaps.set('n', "<leader>x", "<C-w>q")
keymaps.set('n', '<leader>h', "<C-w>h")
keymaps.set('n', '<leader>l', "<C-w>l")
keymaps.set('n', '<leader>k', "<C-w>k")
keymaps.set('n', '<leader>j', "<C-w>j")
-- Command+Option on macOS; Ctrl+Alt on Windows/Linux (including WSL).
-- Keep the shell's unmodified Esc and Ctrl+h/j/k/l bindings intact.
for direction, label in pairs({ h = '左', j = '下', k = '上', l = '右' }) do
    for _, modifiers in ipairs({ 'D-A-', 'C-A-' }) do
        local key = '<' .. modifiers .. direction .. '>'
        keymaps.set({ 'n', 'i' }, key, '<Cmd>wincmd ' .. direction .. '<CR>',
            { desc = '切换到' .. label .. '方窗口', silent = true })
        keymaps.set('t', key, '<C-\\><C-n><Cmd>wincmd ' .. direction .. '<CR>',
            { desc = '从终端切换到' .. label .. '方窗口', silent = true })
    end
end
keymaps.set('n', '<leader>=', '<C-w>=', { desc = '均分窗口大小' })
keymaps.set('n', '<C-Up>', '<cmd>resize +2<CR>', { desc = '增加窗口高度', silent = true })
keymaps.set('n', '<C-Down>', '<cmd>resize -2<CR>', { desc = '减少窗口高度', silent = true })
keymaps.set('n', '<C-Left>', '<cmd>vertical resize -4<CR>', { desc = '减少窗口宽度', silent = true })
keymaps.set('n', '<C-Right>', '<cmd>vertical resize +4<CR>', { desc = '增加窗口宽度', silent = true })
keymaps.set('n', '<leader>[', '<C-o>', opts)
keymaps.set('n', '<leader>]', '<C-i>', opts)
keymaps.set('n', '<leader>s', '<cmd>write<CR>', opts)
keymaps.set('n', '<leader>gun', '<cmd>quit!<CR>', opts)
keymaps.set('n', '<leader>nh', '<cmd>nohlsearch<CR>', opts)

-- Insert mode
keymaps.set('i', "jk", "<Esc>")
