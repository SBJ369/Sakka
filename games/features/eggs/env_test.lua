-- games/features/eggs/env_test.lua
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

return function(ctx)
    local lib = ctx.lib
    local Env = ctx.Env
    local LocalPlayer = Players.LocalPlayer
    local M = {}

    local isWalking = false

    local function pos()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        return hrp and hrp.Position
    end

    local function humanoid()
        local char = LocalPlayer.Character
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    local function walkTo(targetPos, label)
        if isWalking then
            lib:Notify({ Title = "Env Test", Content = "Already walking!", Duration = 3 })
            return
        end
        
        if not targetPos then
            lib:Notify({ Title = "Env Test", Content = "Target not found: " .. label, Duration = 3 })
            return
        end

        isWalking = true
        lib:Notify({ Title = "Env Test", Content = "Walking to " .. label, Duration = 2 })
        print("[env_test] Walking to " .. label .. " at " .. tostring(targetPos))

        local hum = humanoid()
        if not hum then isWalking = false return end

        local done = false
        local conn = RunService.RenderStepped:Connect(function()
            if done then return end
            local p = pos()
            if not p then
                hum:Move(Vector3.zero)
                done = true
                return
            end
            
            local delta = targetPos - p
            local horiz = Vector3.new(delta.X, 0, delta.Z)
            local dist = horiz.Magnitude

            -- If very close, hard stop
            if dist <= 3 then
                hum:Move(Vector3.zero)
                done = true
                isWalking = false
                lib:Notify({ Title = "Env Test", Content = "Arrived at " .. label, Duration = 3 })
                print("[env_test] Arrived at " .. label)
                if conn then conn:Disconnect() end
                return
            end
            
            -- Deceleration zone: if within 15 studs, scale down movement speed
            if dist < 15 then
                -- Normalize direction and multiply by (dist / 15) to slow down
                local slowDir = horiz.Unit * (dist / 15)
                hum:Move(slowDir)
            else
                hum:Move(horiz.Unit)
            end
        end)

        task.delay(45, function()
            if not done then
                done = true
                isWalking = false
                if hum then hum:Move(Vector3.zero) end
                if conn then conn:Disconnect() end
                lib:Notify({ Title = "Env Test", Content = "Timed out walking to " .. label, Duration = 3 })
            end
        end)
    end

    function M:Stop()
        if isWalking then
            local hum = humanoid()
            if hum then hum:Move(Vector3.zero) end
            isWalking = false
        end
    end

    function M:WalkToFuse() walkTo(Env:GetStatic("FuseMachine"), "Fuse Machine") end
    function M:WalkToShop() walkTo(Env:GetStatic("TrailShop"), "Trail Shop") end
    function M:WalkToSell() walkTo(Env:GetStatic("SellStand"), "Sell Stand") end
    function M:WalkToTreadmill() walkTo(Env:GetMyTreadmill(), "My Treadmill") end
    function M:WalkToPlot() walkTo(Env:GetMyPlotCenter(), "My Plot Center") end
    function M:WalkToUpgrade() walkTo(Env:GetMyPlotUpgrade(), "My Plot Upgrade") end

    return M
end
