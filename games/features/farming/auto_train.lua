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

    local STOP_DIST = 3

    local PlotState = require(ReplicatedStorage.Client.PlotState)

    local function log(msg)
        if lib and lib.Notify then
            pcall(function() lib:Notify({ Title = "Auto Train", Content = tostring(msg), Duration = 3 }) end)
        end
        warn("[autotrain] " .. tostring(msg))
    end

    local function getTreadmillPos()
        local plot = PlotState.ResolvePlot()
        if not plot or not plot.PlotFolder then return nil end
        local tb = plot.PlotFolder:FindFirstChild("TreadmillBottom")
        if not tb or not tb:IsA("BasePart") then return nil end
        return tb.Position
    end

    local function getHRP()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function getHumanoid()
        local char = LocalPlayer.Character
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    local function loop()
        print("[autotrain] Loop started.")
        local mounted = false

        while running do
            if options and options.isBusy then
                mounted = false
                local hum = getHumanoid()
                if hum then hum:Move(Vector3.zero) end
                task.wait(0.2)
            else
                local target = getTreadmillPos()
                local hrp = getHRP()
                local hum = getHumanoid()

                if target and hrp and hum then
                    local p = hrp.Position
                    local delta = target - p
                    local horiz = Vector3.new(delta.X, 0, delta.Z)
                    local d = horiz.Magnitude

                    if d <= STOP_DIST then
                        if not mounted then
                            mounted = true
                            print("[autotrain] Mounted belt.")
                        end
                        hum:Move(Vector3.zero)
                    else
                        mounted = false
                        if d < 15 then
                            hum:Move(horiz.Unit * (d / 15))
                        else
                            hum:Move(horiz.Unit)
                        end
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
        local hum = getHumanoid()
        if hum then
            pcall(function() hum:Move(Vector3.zero) end)
            pcall(function() hum.Jump = true end)
        end
        log("stopped (jumped off)")
    end

    return M
end
