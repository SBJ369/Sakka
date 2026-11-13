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

    -- Mount band: start walking when outside OUTER, stop when inside INNER.
    -- Hysteresis prevents the ping-pong that was re-issuing Move after mounting.
    local OUTER_RADIUS = 6
    local INNER_RADIUS = 3.5

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

    local function xzDist(a, b)
        local dx = a.X - b.X
        local dz = a.Z - b.Z
        return math.sqrt(dx * dx + dz * dz)
    end

    local function loop()
        local treadmillPos = Env:GetMyTreadmill()
        if not treadmillPos then
            log("Could not find your treadmill.")
            running = false
            return
        end

        print("[autotrain] Loop started.")
        local mounted = false

        while running do
            -- Refresh treadmill position in case the player rejoined / plot changed
            treadmillPos = Env:GetMyTreadmill() or treadmillPos

            if options and options.isBusy then
                -- Hierarchy lock held: pause, release mount, stand still
                mounted = false
                local hum = humanoid()
                if hum then hum:Move(Vector3.zero) end
                task.wait(0.2)
            else
                local p = pos()
                local hum = humanoid()

                if p and hum then
                    local d = xzDist(p, treadmillPos)

                    if mounted and d <= OUTER_RADIUS then
                        -- Already mounted, still inside the band: do NOT call Move.
                        -- Standing still lets the belt physics keep us in place.
                    elseif not mounted and d <= INNER_RADIUS then
                        -- First time arriving: stop, mark mounted
                        hum:Move(Vector3.zero)
                        mounted = true
                        print("[autotrain] Mounted belt.")
                    else
                        -- Outside band: walk toward treadmill
                        mounted = false
                        local delta = treadmillPos - p
                        local horiz = Vector3.new(delta.X, 0, delta.Z)
                        if horiz.Magnitude > 0.1 then
                            if d < 15 then
                                hum:Move(horiz.Unit * (d / 15))
                            else
                                hum:Move(horiz.Unit)
                            end
                        else
                            hum:Move(Vector3.zero)
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

        -- Single, authoritative jump-off. Background controller no longer does this.
        local hum = humanoid()
        if hum then
            pcall(function() hum:Move(Vector3.zero) end)
            pcall(function() hum.Jump = true end)
        end
        log("stopped (jumped off)")
    end

    return M
end
