return {
    'MeanderingProgrammer/render-markdown.nvim',
    name = "markdown.nvim", -- retain the existing installation and lockfile identity
    ft = { "markdown" },
    main = "render-markdown",
    opts = {},
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
}
