-- games/features/farming/auto_train.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

return function(ctx)
    local lib = ctx and ctx.lib
    local Env = ctx and ctx.Env
    local options = ctx and ctx.options
    local LocalPlayer = Players.LocalPlayer
    local M = {}

    local running = false
    local thread

    local function log(msg)
        if lib and lib.Notify then
            pcall(function() lib:Notify({ Title = "Auto Train", Content = tostring(msg), Duration = 3 }) end)
        end
        warn("[autotrain] " .. tostring(msg))
    end

    local function hrp()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function humanoid()
        local char = LocalPlayer.Character
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    local function pos()
        local p = hrp()
        return p and p.Position
    end

    local function loop()
        local treadmillPos = Env:GetMyTreadmill()
        if not treadmillPos then
            log("Could not find your treadmill.")
            running = false
            return
        end

        print("[autotrain] Loop started. Treadmill at:", treadmillPos)

        while running do
            local isBusy = options and options.isBusy
            
            if isBusy then
                print("[autotrain] Busy - waiting")
                local hum = humanoid()
                if hum then hum:Move(Vector3.zero) end
                task.wait(1)
            else
                local p = pos()
                local hum = humanoid()
                
                if p and hum then
                    local delta = treadmillPos - p
                    local horiz = Vector3.new(delta.X, 0, delta.Z)
                    local dist = horiz.Magnitude

                    -- Print every 1 second so we don't spam the console
                    if math.random() < 0.05 then 
                        print(string.format("[autotrain] Dist to treadmill: %.1f", dist))
                    end

                    if dist > 5 then
                        if dist < 15 then
                            -- Deceleration math
                            local moveDir = horiz.Unit * (dist / 15)
                            hum:Move(moveDir)
                        else
                            hum:Move(horiz.Unit)
                        end
                    else
                        hum:Move(Vector3.zero)
                    end
                end
                task.wait(0.1)
            end
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
        
        local hum = humanoid()
        if hum then
            hum:Move(Vector3.zero)
            hum.Jump = true
        end
        log("stopped (jumped off)")
    end

    return M
end
