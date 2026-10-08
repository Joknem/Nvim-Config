if vim.g.vscode then
    local keymaps = vim.keymap
    local file = {
      new = function()
        vim.fn.VSCodeNotify("workbench.explorer.fileView.focus")
        vim.fn.VSCodeNotify("explorer.newFile")
      end,

      save = function()
        vim.fn.VSCodeNotify("workbench.action.files.save")
      end,

      saveAll = function()
        vim.fn.VSCodeNotify("workbench.action.files.saveAll")
      end,

      format = function()
        vim.fn.VSCodeNotify("editor.action.formatDocument")
      end,

      showInExplorer = function()
        vim.fn.VSCodeNotify("workbench.files.action.showActiveFileInExplorer")
      end,

      rename = function()
        vim.fn.VSCodeNotify("workbench.files.action.showActiveFileInExplorer")
        vim.fn.VSCodeNotify("renameFile")
      end
    }

    local workbench = {
        showCommands = function()
            vim.fn.VSCodeNotify("workbench.action.showCommands")
        end,
        previousEditor = function()
            vim.fn.VSCodeNotify("workbench.action.previousEditor")
        end,
        nextEditor = function()
            vim.fn.VSCodeNotify("workbench.action.nextEditor")
        end,
        goForward = function()
            vim.fn.VSCodeNotify("workbench.action.navigateForward")
        end,
        goBack = function()
            vim.fn.VSCodeNotify("workbench.action.navigateBack")
        end,
    }

    -- Normal mode
    vim.g.mapleader = " "
    vim.opt.number=true
    vim.opt.relativenumber=true
    keymaps.set({"n"}, "H", workbench.previousEditor)
    keymaps.set({"n"}, "L", workbench.nextEditor)
    keymaps.set({"n"}, "<leader>s", file.save)
    keymaps.set({"n"}, "<leader>[", workbench.goBack)
    keymaps.set({"n"}, "<leader>]", workbench.goForward)
    vim.api.nvim_set_keymap('n', "<leader>-", "<C-w>s", { noremap = false})
    vim.api.nvim_set_keymap('n', "<leader>\\", "<C-w>v", { noremap = false})
    vim.api.nvim_set_keymap('n', '<leader>nh', ':nohlsearch<CR>', { noremap = false})
    vim.api.nvim_set_keymap('n', '<leader>h', '<C-w>h', { noremap = false})
    vim.api.nvim_set_keymap('n', '<leader>j', '<C-w>j', { noremap = false})
    vim.api.nvim_set_keymap('n', '<leader>k', '<C-w>k', { noremap = false})
    vim.api.nvim_set_keymap('n', '<leader>l', '<C-w>l', { noremap = false})

    -- Insert mode
    keymaps.set('i', "jk", "<Esc>")
    require("config.yank").setup()

else
    require("options")
    require("keymaps")
    require("config.bootstrap")()
    require("lazy").setup("plugins")
end
