return function()
    local path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not vim.uv.fs_stat(path) then
        assert(vim.fn.executable("git") == 1, "缺少 Git，请先运行 install.sh")
        local lockpath = vim.fn.stdpath("config") .. "/lazy-lock.json"
        local lock = vim.json.decode(table.concat(vim.fn.readfile(lockpath), "\n"))
        local commit = assert(lock["lazy.nvim"], "锁文件缺少 lazy.nvim").commit
        local staging = path .. ".install-" .. vim.fn.getpid()
        local output = vim.fn.system({ "git", "clone", "--filter=blob:none",
            "https://github.com/folke/lazy.nvim.git", staging })
        if vim.v.shell_error ~= 0 then
            vim.fn.delete(staging, "rf")
            error("安装 lazy.nvim 失败；请检查网络/Git 后重试：\n" .. output)
        end
        output = vim.fn.system({ "git", "-C", staging, "checkout", "--detach", commit })
        if vim.v.shell_error ~= 0 then
            vim.fn.delete(staging, "rf")
            error("无法检出锁定的 lazy.nvim 版本：\n" .. output)
        end
        local ok, err = vim.uv.fs_rename(staging, path)
        if not ok then
            vim.fn.delete(staging, "rf")
            error("无法完成 lazy.nvim 安装：" .. tostring(err))
        end
    end
    vim.opt.rtp:prepend(path)
end
