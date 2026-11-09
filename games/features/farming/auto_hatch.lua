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

        while running do
            -- 1. Get all owned eggs
            local ownedEggs = EggState.ReadOwnedEggs()
            
            if ownedEggs and #ownedEggs > 0 then
                for _, record in ipairs(ownedEggs) do
                    if not running then break end
                    
                    -- 2. Check if the egg is placed and grown enough to hatch
                    if record.Placement and EggState.IsReadyToHatch(record.Uid) then
                        log("Hatching egg: " .. tostring(record.Uid))
                        
                        -- 3. Fire the Hatch remote
                        local ok, success, err = pcall(function()
                            return Remotes.EggWorld.AskHatch:InvokeServer(record.Uid)
                        end)
                        
                        if ok and success then
                            task.wait(0.5) -- Wait for the hatch animation
                            
                            -- 4. Fire the FinishHatch remote to claim the pet
                            pcall(function()
                                Remotes.EggWorld.AskFinishHatch:InvokeServer(record.Uid)
                            end)
                            
                            task.wait(1) -- Wait before processing the next egg
                        else
                            warn("[autohatch] Failed to hatch " .. tostring(record.Uid) .. ": " .. tostring(err))
                        end
                    end
                end
            end
            
            -- Scan every 2 seconds
            task.wait(2)
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
