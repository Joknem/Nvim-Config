  -- rainbow bracket --
  return {
    'HiPhish/rainbow-delimiters.nvim',
    lazy = true,
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      local rainbow_delimiters = require('rainbow-delimiters')
      vim.g.rainbow_delimiters = {
        condition = function(bufnr)
          -- Completion menus and other UI buffers do not need rainbow highlighting.
          if vim.bo[bufnr].buftype ~= '' then return false end
          -- Missing parsers may return nil or throw, depending on Neovim's version.
          local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
          return ok and parser ~= nil
        end,
        strategy = {
          [''] = rainbow_delimiters.strategy['global'],
          vim = rainbow_delimiters.strategy['local'],
        },
        query = {
          [''] = 'rainbow-delimiters',
          lua = 'rainbow-blocks',
        },
        highlight = {
          'RainbowDelimiterBlue',
          'RainbowDelimiterYellow',
          'RainbowDelimiterCyan',
          'RainbowDelimiterViolet',
          'RainbowDelimiterRed',
          'RainbowDelimiterOrange',
          'RainbowDelimiterGreen',
        },
      }
    end
  }
