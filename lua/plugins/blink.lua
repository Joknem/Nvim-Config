return {
    'saghen/blink.cmp',
    enabled = require('config.lsp_selection').enabled,
    tag = 'v1.10.2',
    lazy = false,
    opts = {
        keymap = {
            preset = 'none',
            ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
            ['<Tab>'] = { 'select_next', 'fallback' },
            ['<S-Tab>'] = { 'select_prev', 'fallback' },
            ['<CR>'] = { 'select_and_accept', 'fallback' },
            ['<C-e>'] = { 'hide', 'fallback' },
        },
        sources = {
            default = { 'lsp' },
            providers = {
                lsp = { fallbacks = {} },
                buffer = { enabled = false },
                path = { enabled = false },
                snippets = { enabled = false },
            },
        },
        completion = {
            menu = { border = 'rounded' },
            list = { selection = { preselect = false, auto_insert = false } },
            accept = { auto_brackets = { enabled = false } },
            documentation = { auto_show = false, window = { border = 'rounded' } },
            ghost_text = { enabled = false },
        },
        cmdline = { enabled = false },
        term = { enabled = false },
        signature = { enabled = false },
        fuzzy = { implementation = 'lua' },
    },
    config = function(_, opts)
        require('blink.cmp').setup(opts)
        require('config.lsp').setup()
    end,
}
