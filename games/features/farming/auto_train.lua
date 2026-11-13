-- games/features/farming/auto_train.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(ctx)
    local lib = ctx and ctx.lib
    local options = ctx and ctx.options
    local LocalPlayer = Players.LocalPlayer
    local M = {}

    local running = false
    local conn

    local PlotState = require(ReplicatedStorage.Client.PlotState)

    local function log(msg)
        if lib and lib.Notify then
            pcall(function() lib:Notify({ Title = "Auto Train", Content = tostring(msg), Duration = 3 }) end)
        end
        warn("[autotrain] " .. tostring(msg))
    end

    function M:Start()
        if running then return end
        running = true

        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        
        if not hrp or not hum then
            log("Failed to find Humanoid/HRP")
            running = false
            return
        end

        local plot = PlotState.ResolvePlot()
        local tb = plot and plot.PlotFolder and plot.PlotFolder:FindFirstChild("TreadmillBottom")
        if not tb then
            log("Could not find your treadmill.")
            running = false
            return
        end

        local target = tb.Position
        local mounted = false

        print("[autotrain] started walking via RenderStepped")

        -- THIS is what the diag script did. Move must be fired on RenderStepped.
        conn = RunService.RenderStepped:Connect(function()
            if not running then return end

            if options and options.isBusy then
                mounted = false
                pcall(function() hum:Move(Vector3.zero) end)
                return
            end

            local p = hrp.Position
            local delta = target - p
            local horiz = Vector3.new(delta.X, 0, delta.Z)
            local d = horiz.Magnitude

            if d <= 3 then
                if not mounted then
                    mounted = true
                    print("[autotrain] Mounted belt.")
                end
                pcall(function() hum:Move(Vector3.zero) end)
            else
                mounted = false
                if d < 15 then
                    pcall(function() hum:Move(horiz.Unit * (d / 15)) end)
                else
                    pcall(function() hum:Move(horiz.Unit) end)
                end
            end
        end)

        log("started")
    end

    function M:Stop()
        running = false
        if conn then
            pcall(function() conn:Disconnect() end)
            conn = nil
        end

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:Move(Vector3.zero) end)
            pcall(function() hum.Jump = true end)
        end
        log("stopped (jumped off)")
    end

    return M
end
