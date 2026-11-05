-- games/features/eggs/carry_loop.lua
-- Full auto-carry cycle. Safe: only fires AskFieldEggCarry when within
-- the server's own reach threshold (~12 studs) and only while past the
-- SeparationLine. Never modifies WalkSpeed or rig cframes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

return function(ctx)
    local lib = ctx.lib
    local Finder = ctx.Finder  -- injected from _eggs.lua

    local M = {}

    local LocalPlayer = Players.LocalPlayer
    local Remotes, EggState, AreaEggSlotIdentity, GuardAreaGeometry, PlotState

    local function loadDeps()
        if Remotes then return true end
        local ok = pcall(function()
            Remotes = require(ReplicatedStorage.Shared.Remotes)
            EggState = require(ReplicatedStorage.Client.EggState)
            AreaEggSlotIdentity = require(ReplicatedStorage.Shared.Util.AreaEggSlotIdentity)
            GuardAreaGeometry = require(ReplicatedStorage.Shared.Util.GuardAreaGeometry)
            PlotState = require(ReplicatedStorage.Client.PlotState)
        end)
        return ok
    end

    -- tuning
    M.CARRY_RANGE      = 10     -- walk this close before firing AskFieldEggCarry
    M.WALK_TIMEOUT     = 30     -- seconds to reach an egg before giving up that attempt
    M.CARRY_FIRE_TIMEOUT = 5    -- seconds for IsCarrying to flip true
    M.RETURN_TIMEOUT   = 60     -- seconds to walk home
    M.DROP_TIMEOUT     = 10     -- seconds for IsCarrying to flip false
    M.MAX_FAILS        = 3      -- consecutive failures before abort

    local running = false
    local thread

    --== helpers ==--

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

    local function isPastLine()
        local p = pos()
        if not p then return false end
        local ok, sep = pcall(function()
            return Workspace.World.Areas.SeparationLine
        end)
        if not ok or not sep then return false end
        return GuardAreaGeometry.IsPastLine(sep, p)
    end

    -- returns a world position on the safe-zone side of the line, near current X
    local function safeZoneTarget()
        local p = pos()
        if not p then return nil end
        local sep = Workspace.World.Areas.SeparationLine
        local zLine = sep.Position.Z
        -- try both candidate sides; whichever IsPastLine says is false is the safe side
        local testA = Vector3.new(p.X, p.Y, zLine + 15)
        local testB = Vector3.new(p.X, p.Y, zLine - 15)
        if not GuardAreaGeometry.IsPastLine(sep, testA) then
            return testA
        elseif not GuardAreaGeometry.IsPastLine(sep, testB) then
            return testB
        end
        return nil
    end

    -- fire-and-poll: wait until predicate returns truthy or timeout
    local function waitFor(pred, timeout)
        local t0 = os.clock()
        while os.clock() - t0 < timeout do
            if pred() then return true end
            task.wait(0.1)
        end
        return false
    end

    -- walk toward target with Humanoid:MoveTo, poll distance
    -- returns true if within stopDist, false on timeout or missing humanoid
    local function walkTo(target, stopDist, timeout)
        stopDist = stopDist or 4
        timeout = timeout or M.WALK_TIMEOUT
        local hum = humanoid()
        local p = pos()
        if not hum or not p then return false end

        local t0 = os.clock()
        while os.clock() - t0 < timeout do
            if not running then return false end
            local pp = pos()
            if not pp then return false end
            local d = (pp - target).Magnitude
            if d <= stopDist then
                hum:MoveTo(pp)  -- stop
                return true
            end
            hum:MoveTo(target)
            task.wait(0.15)
        end
        hum:MoveTo(pos() or target)  -- stop
        return false
    end

    -- poll distance to a specific uid (via Finder)
    local function distanceToUid(uid)
        return Finder:DistanceTo(uid)
    end

    --== the loop body ==--

    local function carryOnce()
        if not isPastLine() then
            -- not in the field yet — walk past the line first
            local p = pos()
            if not p then return false, "no character" end
            local sep = Workspace.World.Areas.SeparationLine
            -- need a point on the FIELD side: the one that returns true
            local fieldPoint
            local zLine = sep.Position.Z
            local a = Vector3.new(p.X, p.Y, zLine + 20)
            local b = Vector3.new(p.X, p.Y, zLine - 20)
            if GuardAreaGeometry.IsPastLine(sep, a) then fieldPoint = a
            elseif GuardAreaGeometry.IsPastLine(sep, b) then fieldPoint = b
            else return false, "cannot find field side" end
            walkTo(fieldPoint, 5, 20)
            if not isPastLine() then return false, "failed to enter gameplay area" end
        end

        local egg = Finder:Nearest({ maxDist = 600 })
        if not egg then return false, "no egg" end

        -- walk to within CARRY_RANGE of the egg
        local ok = walkTo(egg.position, M.CARRY_RANGE, M.WALK_TIMEOUT)
        if not ok then return false, "walk to egg timed out" end

        -- verify still in range
        local dist = distanceToUid(egg.uid)
        if not dist or dist > M.CARRY_RANGE + 3 then
            return false, "lost range to egg"
        end

        -- compute key if first-area
        local slotKey
        if AreaEggSlotIdentity.LooksLikeFirstAreaUid(egg.uid) then
            slotKey = AreaEggSlotIdentity.SlotKey(egg.areaId, egg.nestId)
        else
            slotKey = nil
        end

        local fired, err = Remotes.EggWorld.AskFieldEggCarry:InvokeServer({
            Uid = egg.uid,
            FirstAreaSlotKey = slotKey,
        })
        if not fired then return false, "carry rejected: " .. tostring(err) end

        -- wait for IsCarrying == true
        local started = waitFor(function()
            local cs = EggState.ReadCarryState()
            return cs and cs.IsCarrying == true
        end, M.CARRY_FIRE_TIMEOUT)
        if not started then return false, "carry state never started" end

        -- walk back to safe zone
        local safePos = safeZoneTarget()
        if not safePos then return false, "cannot find safe-zone target" end
        local returned = walkTo(safePos, 3, M.RETURN_TIMEOUT)
        if not returned then return false, "walk home timed out" end

        -- wait for IsCarrying == false (server drops it automatically)
        local dropped = waitFor(function()
            local cs = EggState.ReadCarryState()
            return cs and cs.IsCarrying == false
        end, M.DROP_TIMEOUT)
        if not dropped then return false, "carry never ended" end

        return true, nil
    end

    local function loop()
        local fails = 0
        while running do
            local ok, why = carryOnce()
            if ok then
                fails = 0
                if lib then lib:Notify({ Title = "Auto Egg", Content = "Delivered.", Duration = 2 }) end
                task.wait(0.8)  -- small gap before next egg
            else
                fails = fails + 1
                if lib then lib:Notify({ Title = "Auto Egg", Content = "Retry " .. fails .. ": " .. tostring(why), Duration = 2 }) end
                if fails >= M.MAX_FAILS then
                    running = false
                    if lib then lib:Notify({ Title = "Auto Egg", Content = "Stopping after " .. fails .. " failures.", Duration = 4 }) end
                    break
                end
                task.wait(1.5)
            end
        end
    end

    function M:Start()
        if running then return end
        if not loadDeps() then
            if lib then lib:Notify({ Title = "Auto Egg", Content = "Failed to load dependencies.", Duration = 4 }) end
            return
        end
        running = true
        thread = task.spawn(loop)
    end

    function M:Stop()
        running = false
        if thread then
            pcall(task.cancel, thread)
            thread = nil
        end
        local hum = humanoid()
        if hum then hum:MoveTo(pos() or hum.Parent.Position) end
    end

    getgenv()._TEST_AutoEggStart = function() M:Start() end
    getgenv()._TEST_AutoEggStop  = function() M:Stop()  end
  
    return M
end
