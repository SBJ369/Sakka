-- games/features/farming/auto_hatch.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

return function(ctx)
    local lib = ctx and ctx.lib
    local LocalPlayer = Players.LocalPlayer
    local M = {}

    local running = false
    local thread

    local Remotes, EggState
    local function loadDeps()
        if Remotes then return true end
        local ok, r = pcall(function()
            Remotes = require(ReplicatedStorage.Shared.Remotes)
            EggState = require(ReplicatedStorage.Client.EggState)
        end)
        if not ok then
            if lib then lib:Notify({ Title = "Auto Hatch", Content = "Failed to load modules.", Duration = 3 }) end
            warn("[autohatch] Failed to load dependencies:", r)
        end
        return ok
    end

    local function log(msg)
        if lib and lib.Notify then
            pcall(function() lib:Notify({ Title = "Auto Hatch", Content = tostring(msg), Duration = 3 }) end)
        end
        warn("[autohatch] " .. tostring(msg))
    end

    local function loop()
        if not loadDeps() then return end
        print("[autohatch] Loop started.")

        while running do
            local owners = EggState.ReadOwnedEggs()
            local hatchedAny = false
            
            if owners and #owners > 0 then
                for _, owner in ipairs(owners) do
                    if owner.OwnerUserId == LocalPlayer.UserId then
                        for uid, record in pairs(owner.Records) do
                            if not running then break end
                            
                            if record.Placement and EggState.IsReadyToHatch(uid) then
                                print("[autohatch] Found ready egg: " .. tostring(uid))
                                log("Hatching egg: " .. tostring(uid))
                                
                                local ok, success, err = pcall(function()
                                    return Remotes.EggWorld.AskHatch:InvokeServer(uid)
                                end)
                                
                                if ok and success then
                                    task.wait(1.0) -- Wait for server to register the hatch state
                                    
                                    local ok2, success2, err2 = pcall(function()
                                        return Remotes.EggWorld.AskFinishHatch:InvokeServer(uid)
                                    end)
                                    
                                    if ok2 and success2 then
                                        print("[autohatch] Successfully hatched " .. tostring(uid))
                                        hatchedAny = true
                                    else
                                        print("[autohatch] FinishHatch failed:", err2)
                                    end
                                else
                                    print("[autohatch] AskHatch failed:", err)
                                end
                            end
                        end
                    end
                end
            end
            
            -- If we hatched something, scan immediately. Otherwise wait 2 seconds.
            task.wait(hatchedAny and 0.5 or 2)
        end
        print("[autohatch] Loop stopped.")
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
