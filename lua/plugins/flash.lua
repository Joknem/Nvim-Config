return {
  "folke/flash.nvim",
  lazy = true,
  opts = {},
  keys = {
      {
          "<leader><leader>f",
          mode = 'n',
          function()
              require('flash').jump()
          end,
          desc = 'Flash',
      },
  },
}
