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
    }

    -- Normal mode
    vim.g.mapleader = " "
    keymaps.set({"n"}, "H", workbench.previousEditor)
    keymaps.set({"n"}, "L", workbench.nextEditor)
    keymaps.set({"n"}, "<leader>s", file.save)

    -- Insert mode
    keymaps.set('i', "jk", "<Esc>")
else
    require("options")
    require("keymaps")
    require("config.bootstrap")()
    require("lazy").setup("plugins")
end
