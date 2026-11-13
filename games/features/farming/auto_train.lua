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
    local thread

    local PlotState = require(ReplicatedStorage.Client.PlotState)

    local function log(msg)
        if lib and lib.Notify then
            pcall(function() lib:Notify({ Title = "Auto Train", Content = tostring(msg), Duration = 3 }) end)
        end
        warn("[autotrain] " .. tostring(msg))
    end

    local function loop()
        -- grab once, exactly like the diag script that proved it works
        local char = LocalPlayer.Character
        if not char then
            char = LocalPlayer.CharacterAdded:Wait()
        end
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")

        local plot = PlotState.ResolvePlot()
        local tb = plot and plot.PlotFolder and plot.PlotFolder:FindFirstChild("TreadmillBottom")
        if not tb then
            log("Could not find your treadmill.")
            running = false
            return
        end

        local target = tb.Position
        print(string.format("[autotrain] starting walk to %s from %s",
            tostring(target), tostring(hrp.Position)))

        local mounted = false

        while running do
            if options and options.isBusy then
                mounted = false
                pcall(function() hum:Move(Vector3.zero) end)
                task.wait(0.2)
            else
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
                task.wait(0.1)
            end
        end

        print("[autotrain] Loop stopped.")
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
