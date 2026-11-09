-- games/features/farming/auto_hatch.lua
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

return function(ctx)
    local lib = ctx and ctx.lib
    local M = {}

    local running = false
    local thread

    local function log(msg)
        if lib and lib.Notify then
            pcall(function() lib:Notify({ Title = "Auto Hatch", Content = tostring(msg), Duration = 3 }) end)
        end
        warn("[autohatch] " .. tostring(msg))
    end

    local function clickButton(btn)
        if btn and btn:IsA("GuiButton") then
            pcall(function() btn:Activated() end)
            pcall(function() btn.MouseButton1Click:Fire() end)
            return true
        end
        return false
    end

    local function loop()
        while running do
            local growingEggsGui = PlayerGui:FindFirstChild("GrowingEggs")
            
            if growingEggsGui then
                local frame = growingEggsGui:FindFirstChild("Frame")
                if frame then
                    -- Look for the "Open" buttons in the egg list
                    local clickedAny = false
                    for _, v in ipairs(frame:GetDescendants()) do
                        -- Check if it's a button and its name implies opening/hatching
                        if v:IsA("GuiButton") and (v.Name == "Open" or v.Name == "Hatch" or v.Name:lower():find("open")) then
                            -- Ensure it's visible (meaning the egg is ready) and clickable
                            if v.Visible and v.Active then
                                clickButton(v)
                                clickedAny = true
                            end
                        end
                    end

                    -- If we clicked something, wait a moment before scanning again
                    if clickedAny then
                        task.wait(0.5) 
                    end
                end
            end
            
            -- Scan every second
            task.wait(1) 
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
