return {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        require("onedark").load()
    end
  -- "rose-pine/neovim", 
  -- name = "rose-pine",
  -- init = function()
  --     vim.cmd('colorscheme rose-pine-moon')
  -- end
  --
  --
}
