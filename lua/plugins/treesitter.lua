return {
    "nvim-treesitter/nvim-treesitter",
    branch = "master", -- legacy configs API, paired with the locked 0.12.5 baseline
    lazy = false,
    build = ":TSUpdate",
    config = function()
      -- Match parsers to this plugin's queries, ahead of stale site/parser copies.
      local configs = require("nvim-treesitter.configs")
      vim.opt.rtp:prepend(vim.fs.dirname(configs.get_parser_install_dir()))
      configs.setup({
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
