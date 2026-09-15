-- Run with: nvim --headless -u NONE -i NONE -n -l scripts/install.lua plugins|parsers
-- All operations use the deployed configuration and the current XDG directories.
local temporary_lock
local function read_json(path)
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
end
local function git(...)
    local result = vim.system({ "git", ... }, { text = true }):wait()
    assert(result.code == 0, result.stderr or result.stdout)
    return vim.trim(result.stdout)
end
local function main()
    local root = vim.fn.stdpath("config")
    vim.opt.rtp:prepend(root)
    local lockpath = root .. "/lazy-lock.json"
    local expected = read_json(lockpath)
    local stage = vim.env.NVIM_INSTALL_STAGE or arg[1]
    assert(stage == "plugins" or stage == "parsers" or stage == "verify", "用法：install.lua plugins|parsers")
    if stage == "verify" then
        vim.wait(100, function() return false end)
        -- Silent, intentionally ignored Vim errors may leave v:errmsg set (e.g. netrw cleanup).
        -- Inspect reported startup errors instead of treating that stale value as a failure.
        local messages = vim.api.nvim_exec2("messages", { output = true }).output
        assert(not messages:match("E%d+:") and not messages:match("Failed to")
            and not messages:match("Error detected"), messages)
        assert(package.loaded["lazy"] and package.loaded["nvim-treesitter.configs"], "核心配置未成功加载")
        print("完整配置启动验证通过。")
        return
    end
    if stage == "plugins" then
        require("config.bootstrap")()
        local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
        local lazy_commit = assert(expected["lazy.nvim"]).commit
        if git("-C", lazypath, "rev-parse", "HEAD") ~= lazy_commit then
            assert(git("-C", lazypath, "status", "--porcelain") == "", "lazy.nvim 有本地改动，无法恢复锁定版本")
            git("-C", lazypath, "fetch", "origin", lazy_commit)
            git("-C", lazypath, "checkout", "--detach", lazy_commit)
        end
        -- Install before running any plugin configuration, including in an empty data directory.
        local function installation_spec(spec)
            if type(spec) == "string" then return spec end
            local copy = vim.deepcopy(spec)
            if type(copy[1]) == "string" or copy.url or copy.dir then
                copy.lazy = true
                copy.init, copy.config, copy.opts = nil, nil, nil
                copy.event, copy.ft, copy.cmd, copy.keys = nil, nil, nil, nil
                -- Treesitter is built synchronously in a separate process after all checkouts finish.
                if copy[1] == "nvim-treesitter/nvim-treesitter" then copy.build = false end
                if copy.dependencies then
                    if type(copy.dependencies) == "table" then
                        copy.dependencies = vim.tbl_map(installation_spec, copy.dependencies)
                    end
                end
                return copy
            end
            return vim.tbl_map(installation_spec, copy)
        end
        local specs = {}
        for _, file in ipairs(vim.fn.glob(root .. "/lua/plugins/*.lua", false, true)) do
            table.insert(specs, installation_spec(dofile(file)))
        end
        temporary_lock = vim.fn.tempname()
        local function reset_lock()
            vim.fn.writefile(vim.fn.readfile(lockpath), temporary_lock)
            local lock = package.loaded["lazy.manage.lock"]
            if lock then lock._loaded = false end
        end
        reset_lock()
        vim.go.loadplugins = true -- -u NONE / -l disable normal plugin loading
        require("lazy").setup({
            spec = specs,
            lockfile = temporary_lock,
            install = { missing = false },
            checker = { enabled = false },
            change_detection = { enabled = false },
        })
        local config = require("lazy.core.config")
        for name in pairs(config.plugins) do
            assert(expected[name], "锁文件缺少插件 " .. name .. "；请先在主机验证并提交锁文件")
        end
        local function check_tasks()
            for name, plugin in pairs(config.plugins) do
                for _, task in ipairs(plugin._.tasks or {}) do
                    assert(not task:has_errors(), name .. ": " .. task:output())
                end
            end
        end
        require("lazy").install({ wait = true, show = false, lockfile = true })
        check_tasks()
        -- Lazy install writes its lockfile; restore must use the original committed revisions.
        reset_lock()
        require("lazy").restore({ wait = true, show = false })
        check_tasks()
        for name, plugin in pairs(config.plugins) do
            assert(git("-C", plugin.dir, "rev-parse", "HEAD") == expected[name].commit,
                "插件版本校验失败：" .. name)
        end
        print("插件安装完成，所有提交与源锁文件一致；源锁文件未修改。")
    else
        local path = vim.fn.stdpath("data") .. "/lazy/nvim-treesitter"
        assert(git("-C", path, "rev-parse", "HEAD") == expected["nvim-treesitter"].commit,
            "请先恢复锁定的 Treesitter 插件")
        vim.opt.rtp:prepend(path)
        local configs = require("nvim-treesitter.configs")
        configs.setup({ ensure_installed = {}, auto_install = false })
        local languages = require("config.parsers")
        require("nvim-treesitter.install").update({ with_sync = true })(languages)
        local parser_lock = read_json(path .. "/lockfile.json")
        local parsers = require("nvim-treesitter.parsers").get_parser_configs()
        for _, language in ipairs(languages) do
            local revision = parsers[language].install_info.revision or assert(parser_lock[language]).revision
            local revision_file = configs.get_parser_info_dir() .. "/" .. language .. ".revision"
            assert(vim.fn.filereadable(revision_file) == 1
                and vim.fn.readfile(revision_file)[1] == revision, "解析器版本校验失败：" .. language)
            -- Use the installed parser explicitly, rather than accidentally accepting a bundled parser.
            local parser_file = configs.get_parser_install_dir() .. "/" .. language .. ".so"
            assert(vim.treesitter.language.add(language, { path = parser_file }), "无法加载解析器：" .. language)
            vim.treesitter.get_string_parser("", language):parse()
        end
        print("所有 " .. #languages .. " 个解析器版本与动态库加载验证通过。")
    end
end
local ok, err = xpcall(main, debug.traceback)
if temporary_lock then vim.fn.delete(temporary_lock) end
if not ok then
    io.stderr:write(tostring(err) .. "\n")
    vim.cmd("cquit 1")
end
