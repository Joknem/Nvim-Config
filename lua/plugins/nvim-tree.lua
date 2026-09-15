return {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        git = {
          enable = false,
        },
      })
    end,
    keys = {
      { "<leader>t", ":NvimTreeToggle<CR>", desc = "Toggle Nvimtree state" },
    },
}
