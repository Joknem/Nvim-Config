  return {
    "akinsho/bufferline.nvim",
    version = "*",
    lazy = false,
    dependencies = "nvim-tree/nvim-web-devicons",
    keys = {
      { "<S-h>", "<cmd>BufferLineCyclePrev<CR>", desc = "Previous buffer", silent = true },
      { "<S-l>", "<cmd>BufferLineCycleNext<CR>", desc = "Next buffer", silent = true },
      { "<leader>bd", function() require('snacks').bufdelete() end, desc = "关闭文件并保留分屏", silent = true },
    },
    config = function()
      require("bufferline").setup({
        options = {
          separator_style = 'thin',
          always_show_bufferline = true,
          show_close_icon = false,
          offsets = { { filetype = 'NvimTree', text = '文件', text_align = 'center',
              highlight = 'Directory', separator = true } },
          close_command = function(buf) require('snacks').bufdelete(buf) end,
          right_mouse_command = function(buf) require('snacks').bufdelete(buf) end,
        },
      })
    end,
  }
