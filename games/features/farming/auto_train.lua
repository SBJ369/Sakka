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

        print("[autotrain] Loop started.")
        local hasMounted = false

        while running do
            -- We ONLY move if NO other system is busy.
            if options and options.isBusy then
                -- Someone else is working. Reset mount state so we re-walk when free.
                hasMounted = false
                local hum = humanoid()
                if hum then hum:Move(Vector3.zero) end
                task.wait(1)
            else
                local p = pos()
                local hum = humanoid()
                
                if p and hum then
                    local dist = (p - treadmillPos).Magnitude
                    
                    if dist > 4 then
                        hasMounted = false
                        -- Walk to treadmill
                        local delta = treadmillPos - p
                        local horiz = Vector3.new(delta.X, 0, delta.Z)
                        if dist < 15 then
                            hum:Move(horiz.Unit * (dist / 15))
                        else
                            hum:Move(horiz.Unit)
                        end
                    else
                        -- We are on the belt.
                        if not hasMounted then
                            hasMounted = true
                            print("[autotrain] Mounted belt.")
                        end
                        -- Do nothing. The game's physics will keep us here.
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
