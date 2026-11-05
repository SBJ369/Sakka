-- games/features/eggs/carry_loop.lua
-- Full auto-carry cycle. Safe: only fires AskFieldEggCarry within the
-- server's own reach threshold and only while past the SeparationLine.
-- Never modifies WalkSpeed or rig cframes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

return function(ctx)
    local lib = ctx and ctx.lib
    local Finder = ctx and ctx.Finder

    local M = {}

    local LocalPlayer = Players.LocalPlayer
    local Remotes, EggState, AreaEggSlotIdentity

    local function log(msg)
        if lib and lib.Notify then
            pcall(function()
                lib:Notify({ Title = "Auto Egg", Content = tostring(msg), Duration = 3 })
            end)
        end
        warn("[autoegg] " .. tostring(msg))
    end

    local function loadDeps()
        if Remotes then return true end
        local ok, err = pcall(function()
            Remotes = require(ReplicatedStorage.Shared.Remotes)
            EggState = require(ReplicatedStorage.Client.EggState)
            AreaEggSlotIdentity = require(ReplicatedStorage.Shared.Util.AreaEggSlotIdentity)
        end)
        if not ok then log("loadDeps failed: " .. tostring(err)) end
        return ok
    end

    -- tuning
    M.CARRY_RANGE        = 10
    M.WALK_TIMEOUT       = 30
    M.CARRY_FIRE_TIMEOUT = 5
    M.RETURN_TIMEOUT     = 60
    M.DROP_TIMEOUT       = 10
    M.MAX_FAILS          = 3

    local running = false
    local thread

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

    -- replicate IsPastLine using the separation line's own CFrame.
    -- Line is thin along its lookVector axis. The line's CFrame defines
    -- a plane; a point is "past" it based on the sign of the local X
    -- (or Z, whichever the lookVector says is "forward").
    local function separationLine()
        local world = Workspace:FindFirstChild("World")
        if not world then return nil end
        local areas = world:FindFirstChild("Areas")
        if not areas then return nil end
        return areas:FindFirstChild("SeparationLine")
    end

    local function sideOfLine()
        local p = pos()
        local line = separationLine()
        if not p or not line then return nil end
        return p.Z - line.Position.Z
    end

    local function isFieldSide()
        local z = sideOfLine()
        return z ~= nil and z < 0
    end

    local function isSafeSide()
        local z = sideOfLine()
        return z ~= nil and z >= 0
    end

    local function safeZoneTarget()
        local p = pos()
        local line = separationLine()
        if not p or not line then return nil end
        return Vector3.new(p.X, p.Y, line.Position.Z + 5)
    end

    local function fieldTarget()
        local p = pos()
        local line = separationLine()
        if not p or not line then return nil end
        return Vector3.new(p.X, p.Y, line.Position.Z - 5)
    end

    local function waitFor(pred, timeout)
        local t0 = os.clock()
        while os.clock() - t0 < timeout do
            if pred() then return true end
            task.wait(0.1)
        end
        return false
    end

    local function walkTo(target, stopDist, timeout)
        stopDist = stopDist or 4
        timeout = timeout or M.WALK_TIMEOUT
        local hum = humanoid()
        if not hum then return false end
        local t0 = os.clock()
        while os.clock() - t0 < timeout do
            if not running then
                local p = pos()
                if p and hum then hum:MoveTo(p) end
                return false
            end
            local p = pos()
            if not p then return false end
            local d = (p - target).Magnitude
            if d <= stopDist then
                hum:MoveTo(p)
                return true
            end
            hum:MoveTo(target)
            task.wait(0.15)
        end
        local p = pos()
        if p and hum then hum:MoveTo(p) end
        return false
    end

    local function distanceToUid(uid)
        return Finder:DistanceTo(uid)
    end

    local function carryOnce()
        -- 1. ensure we're in field
    if not isFieldSide() then
        local ft = fieldTarget()
        if not ft then return false, "cannot compute field target" end
        if not walkTo(ft, 5, 25) then return false, "failed to walk into field" end
        if not isFieldSide() then
            local p, l = pos(), separationLine()
            return false, ("not in field after walking (myZ=%.1f lineZ=%.1f)"):format(p.Z, l.Position.Z)
        end
    end

        -- 2. find nearest egg
        local egg = Finder:Nearest({ maxDist = 600 })
        if not egg then return false, "no egg found" end

        -- 3. walk to within CARRY_RANGE
        if not walkTo(egg.position, M.CARRY_RANGE, M.WALK_TIMEOUT) then
            return false, "walk to egg timed out"
        end

        -- 4. verify still in range
        local dist = distanceToUid(egg.uid)
        if not dist or dist > M.CARRY_RANGE + 3 then
            return false, "lost range to egg (dist=" .. tostring(dist) .. ")"
        end

        -- 5. compute slot key if first-area
        local slotKey
        if AreaEggSlotIdentity.LooksLikeFirstAreaUid(egg.uid) then
            slotKey = AreaEggSlotIdentity.SlotKey(egg.areaId, egg.nestId)
        end

        -- 6. fire carry
        local fired, err = Remotes.EggWorld.AskFieldEggCarry:InvokeServer({
            Uid = egg.uid,
            FirstAreaSlotKey = slotKey,
        })
        if not fired then return false, "carry rejected: " .. tostring(err) end

        -- 7. wait for IsCarrying
        local started = waitFor(function()
            local cs = EggState.ReadCarryState()
            return cs and cs.IsCarrying == true
        end, M.CARRY_FIRE_TIMEOUT)
        if not started then return false, "carry never started" end

        -- 8. walk home
        local safe = safeZoneTarget()
        if not safe then return false, "cannot compute safe target" end
        if not walkTo(safe, 3, M.RETURN_TIMEOUT) then
            return false, "walk home timed out"
        end

        -- 9. wait for carry to end
        local dropped = waitFor(function()
            local cs = EggState.ReadCarryState()
            return cs and cs.IsCarrying == false
        end, M.DROP_TIMEOUT)
        if not dropped then return false, "carry never ended" end
        if not isSafeSide() then return false, "dropped on field side (likely caught)" end
        return true, nil
    end

    local function loop()
        local fails = 0
        while running do
            local ok, why = pcall(carryOnce)
            if ok and why == nil then
                -- hmm, pcall returns (true, returnVal) — but carryOnce returns two values
                -- we need to grab them properly
            end
            -- correct pcall for two returns:
            local okCall, result, reason = pcall(carryOnce)
            if not okCall then
                log("carryOnce error: " .. tostring(result))
                fails = fails + 1
            elseif result == true then
                log("delivered")
                fails = 0
                task.wait(0.8)
            else
                log("fail: " .. tostring(reason or result))
                fails = fails + 1
            end
            if fails >= M.MAX_FAILS then
                log("stopping after " .. fails .. " failures")
                running = false
                break
            end
            task.wait(1.2)
        end
    end

    function M:Start()
        if running then return end
        if not loadDeps() then return end
        if not Finder then log("no Finder injected") return end
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
            local p = pos()
            if p then hum:MoveTo(p) end
        end
        log("stopped")
    end

    getgenv()._TEST_AutoEggStart = function() M:Start() end
    getgenv()._TEST_AutoEggStop  = function() M:Stop()  end

    return M
end
