-- games/features/farming/auto_equip.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(ctx)
    local lib = ctx and ctx.lib
    local M = {}

    local Remotes
    local function loadDeps()
        if Remotes then return true end
        local ok, r = pcall(require, ReplicatedStorage.Shared.Remotes)
        if ok and r then Remotes = r end
        return ok
    end

    local running = false
    local thread

    local function log(msg)
        if lib and lib.Notify then
            pcall(function() lib:Notify({ Title = "Auto Equip", Content = tostring(msg), Duration = 3 }) end)
        end
        warn("[autoequip] " .. tostring(msg))
    end

    local function loop()
        if not loadDeps() then
            log("Failed to load Remotes.")
            return
        end

        local fails = 0
        while running do
            -- Call the remote directly
            local ok, success, err = pcall(function()
                return Remotes.Haul.WearBest:InvokeServer()
            end)

            if ok then
                if success == true then
                    fails = 0
                else
                    -- Usually means the 5-second server debounce was hit
                    fails = fails + 1
                end
            else
                fails = fails + 1
                if fails == 1 then
                    log("Remote call failed, retrying...")
                end
            end
            
            -- Wait 5 seconds to respect the server debounce
            task.wait(5)
        end
    end

    function M:Start()
        if running then return end
        running = true
        thread = task.spawn(loop)
        log("started")
    end

    function M:Stop()
        running = false
        if thread then
            pcall(task.cancel, thread)
            thread = nil
        end
        log("stopped")
    end

    return M
end
