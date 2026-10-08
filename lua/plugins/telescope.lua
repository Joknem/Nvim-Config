local function project_picker(name)
    return function()
        if vim.fn.executable("rg") ~= 1 then
            vim.notify("Telescope 搜索需要 ripgrep（rg）。请运行 install.sh 安装依赖，然后重启终端。", vim.log.levels.ERROR)
            return
        end
        local opts = { cwd = require('config.project').root() }
        if name == "grep_string" or name == "live_grep" then
            -- Pass an explicit path so rg always searches files, never inherited stdin.
            opts.search_dirs = { "." }
        end
        require("telescope.builtin")[name](opts)
    end
end

return {
    "nvim-telescope/telescope.nvim",
    tag = "v0.2.2",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
        { "<leader>p", project_picker("find_files"), desc = "Find project files" },
        { "<leader>P", project_picker("live_grep"), desc = "Search project contents" },
        { "<leader>rs", "<cmd>Telescope resume<CR>", desc = "Resume search" },
        { "<C-q>", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
        { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Search open buffers" },
        { "<leader>fw", project_picker("grep_string"), desc = "Search word in project" },
        { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search current buffer" },
    },
    opts = {
        defaults = {
            sorting_strategy = "ascending",
            layout_strategy = "flex",
            borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
            layout_config = {
                width = 0.9,
                height = 0.85,
                flex = { flip_columns = 120 },
                vertical = { preview_height = 0.45 },
                horizontal = {
                    prompt_position = "top",
                    preview_width = 0.55,
                },
            },
            path_display = { "truncate" },
        },
        pickers = {
            find_files = {
                -- Include dotfiles but keep ignore rules; exclude Git's internal files.
                find_command = { "rg", "--files", "--hidden", "--glob", "!.git", "--color", "never" },
            },
            live_grep = {
                additional_args = { "--hidden", "--glob", "!.git" },
            },
            grep_string = {
                additional_args = { "--hidden", "--glob", "!.git" },
            },
        },
    },
}
