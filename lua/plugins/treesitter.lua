return {
    "nvim-treesitter/nvim-treesitter",
    branch = "master", -- legacy configs API, paired with Neovim 0.11.5
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = vim.env.NVIM_INSTALLING == "1" and {} or require("config.parsers"),
        sync_install = false,
        auto_install = false, -- do not download parsers for unrelated filetypes
        highlight = {
          enable = true,
        },
        incremental_selection = {
          enable = true,
          keymaps = {
            node_incremental = "v",
            node_decremental = "<BS>",
          },
        },
      })
    end,
}
