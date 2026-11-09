-- games/features/farming/auto_train.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

return function(ctx)
    local lib = ctx and ctx.lib
    local Env = ctx and ctx.Env
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

    -- Walk to the treadmill smoothly
    local function walkTo(targetPos)
        local hum = humanoid()
        if not hum or not targetPos then return end

        local done = false
        local conn = RunService.RenderStepped:Connect(function()
            if done or not running then return end
            local p = pos()
            if not p then return end

            local delta = targetPos - p
            local horiz = Vector3.new(delta.X, 0, delta.Z)
            local dist = horiz.Magnitude

            -- Hard stop when very close
            if dist <= 2 then
                hum:Move(Vector3.zero)
                done = true
                if conn then conn:Disconnect() end
                return
            end

            -- Decelerate when close
            if dist < 15 then
                hum:Move(horiz.Unit * (dist / 15))
            else
                hum:Move(horiz.Unit)
            end
        end)
    end

    local function loop()
        local treadmillPos = Env:GetMyTreadmill()
        if not treadmillPos then
            log("Could not find your treadmill.")
            running = false
            return
        end

        log("Walking to treadmill...")
        walkTo(treadmillPos)

        -- Wait until we arrive (or timeout)
        local t0 = os.clock()
        while running and os.clock() - t0 < 30 do
            local p = pos()
            if p and (p - treadmillPos).Magnitude < 5 then
                break
            end
            task.wait(0.5)
        end

        if not running then return end
        log("On treadmill. Training...")
        
        -- Keep the character anchored to the exact treadmill spot
        -- so it doesn't slide off due to physics
        while running do
            local hum = humanoid()
            local p = pos()
            if hum and p then
                local delta = treadmillPos - p
                local horiz = Vector3.new(delta.X, 0, delta.Z)
                -- If we drift off the treadmill, move back to the center
                if horiz.Magnitude > 1 then
                    hum:Move(horiz.Unit)
                else
                    hum:Move(Vector3.zero)
                end
            end
            task.wait(0.1)
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
        
        -- JUMP to leave the treadmill
        local hum = humanoid()
        if hum then
            hum:Move(Vector3.zero)
            task.wait(0.1)
            hum.Jump = true
        end
        log("stopped (jumped off)")
    end

    return M
end
