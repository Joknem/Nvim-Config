local option = vim.opt
-- Only use the system clipboard when a provider is installed.
for _, provider in ipairs({ 'wl-copy', 'xclip', 'xsel', 'pbcopy', 'win32yank' }) do
    if vim.fn.executable(provider) == 1 then
        option.clipboard = "unnamedplus"
        break
    end
end
option.completeopt = {"menu", "menuone", "noselect"}
option.mouse = 'a'

-- Tab
option.tabstop = 4 --number of visual spaces per TAB
option.softtabstop = 4 -- number of spacesin tab when editing
option.shiftwidth = 4 -- insert 4 spaces on a tab
option.expandtab = true -- tabs are spaces, mainly because of python

-- UI config
option.number = true
option.relativenumber = true
option.splitbelow = true
option.splitright = true
option.laststatus = 3
option.scrolloff = 5
option.sidescrolloff = 5
option.autochdir = false
option.undofile = true
option.sessionoptions = { "buffers", "curdir", "tabpages", "winsize" }
option.termguicolors = true
option.cursorline = true
option.signcolumn = "yes"

-- Searching
option.incsearch = true
option.ignorecase=true
option.smartcase = true

require("config.yank").setup()
