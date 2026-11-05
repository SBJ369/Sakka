-- games/features/eggs/carry_loop.lua
-- Full auto-carry cycle. Uses RunService.RenderStepped to assert Humanoid:Move.
-- Walk-home target is the plot respawn CFrame (inside pen area).
-- Uses raw FieldEggCarry event as authoritative carry start/end signal.
-- Listener is connected BEFORE firing AskFieldEggCarry to avoid missing
-- the event during the InvokeServer yield.
-- Stale-event filter is 0.2s (was 0.5s) and falls back to client-state
-- verification when reachedSafe + insidePen + cs=false align.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

return function(ctx)
    local lib = ctx and ctx.lib
    local Finder = ctx and ctx.Finder

    local M = {}
    local LocalPlayer = Players.LocalPlayer
    local Remotes, EggState, AreaEggSlotIdentity, PlotState

    local function log(msg)
        if lib and lib.Notify then
            pcall(function() lib:Notify({ Title = "Auto Egg", Content = tostring(msg), Duration = 3 }) end)
        end
        warn("[autoegg] " .. tostring(msg))
    end

    local function loadDeps()
        if Remotes then return true end
        local ok, err = pcall(function()
            Remotes = require(ReplicatedStorage.Shared.Remotes)
            EggState = require(ReplicatedStorage.Client.EggState)
            AreaEggSlotIdentity = require(ReplicatedStorage.Shared.Util.AreaEggSlotIdentity)
            PlotState = require(ReplicatedStorage.Client.PlotState)
        end)
        if not ok then log("loadDeps: " .. tostring(err)) end
        return ok
    end

    M.CARRY_RANGE        = 10
    M.WALK_TIMEOUT       = 30
    M.CARRY_FIRE_TIMEOUT = 5
    M.RETURN_TIMEOUT     = 45
    M.DROP_TIMEOUT       = 8
    M.MAX_FAILS          = 3
    M.STALE_EVENT_WINDOW = 0.2

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

    local function separationLine()
        local world = Workspace:FindFirstChild("World")
        local areas = world and world:FindFirstChild("Areas")
        return areas and areas:FindFirstChild("SeparationLine")
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

    local function isInsidePen()
        local p = pos()
        if not p then return false end
        local ok, inside = pcall(function() return PlotState.ContainsLocalPoint(p) end)
        return ok and inside == true
    end

    local function safeZoneTarget()
        local p = pos()
        if not p then return nil end
        local ok, plot = pcall(function() return PlotState.ResolvePlot() end)
        if ok and plot and plot.RespawnPointCFrame then
            return plot.RespawnPointCFrame.Position
        end
        local line = separationLine()
        if not line then return nil end
        return Vector3.new(p.X, p.Y, line.Position.Z + 8)
    end

    local function fieldTarget()
        local p = pos()
        local line = separationLine()
        if not p or not line then return nil end
        return Vector3.new(p.X, p.Y, line.Position.Z - 10)
    end

    local function walkTo(target, stopDist, timeout)
        stopDist = stopDist or 4
        timeout = timeout or M.WALK_TIMEOUT
        local hum = humanoid()
        if not hum then return false end

        local done = false
        local reached = false
        local t0 = os.clock()

        local conn
        conn = RunService.RenderStepped:Connect(function()
            if done then return end
            if not running or os.clock() - t0 > timeout then
                pcall(function() hum:Move(Vector3.zero) end)
                done = true
                return
            end
            local p = pos()
            if not p then
                pcall(function() hum:Move(Vector3.zero) end)
                done = true
                return
            end
            local delta = target - p
            local horiz = Vector3.new(delta.X, 0, delta.Z)
            if horiz.Magnitude <= stopDist then
                pcall(function() hum:Move(Vector3.zero) end)
                reached = true
                done = true
                return
            end
            pcall(function() hum:Move(horiz.Unit) end)
        end)

        local tStart = os.clock()
        while not done and (os.clock() - tStart) < (timeout + 2) do
            if not running then break end
            task.wait(0.05)
        end
        if conn then pcall(function() conn:Disconnect() end) end
        pcall(function() hum:Move(Vector3.zero) end)
        return reached
    end

    local function distanceToUid(uid)
        return Finder:DistanceTo(uid)
    end

    local function waitFor(pred, timeout)
        local t0 = os.clock()
        while os.clock() - t0 < timeout do
            if not running then return false end
            if pred() then return true end
            task.wait(0.1)
        end
        return false
    end

    local function carryOnce()
        -- 1. ensure we're on field side
        if not isFieldSide() then
            local ft = fieldTarget()
            if not ft then return false, "no field target" end
            if not walkTo(ft, 5, 20) then return false, "walk to field timed out" end
            if not isFieldSide() then
                local p, l = pos(), separationLine()
                return false, ("not in field (z=%.1f line=%.1f)"):format(p.Z, l.Position.Z)
            end
        end

        -- 2. find nearest egg
        local egg = Finder:Nearest({ maxDist = 600 })
        if not egg then return false, "no egg" end

        -- 3. walk to egg
        if not walkTo(egg.position, M.CARRY_RANGE, M.WALK_TIMEOUT) then
            return false, "walk to egg timed out"
        end

        local dist = distanceToUid(egg.uid)
        if not dist or dist > M.CARRY_RANGE + 3 then
            return false, "lost range to egg"
        end

        -- 4. compute slot key
        local slotKey
        if AreaEggSlotIdentity.LooksLikeFirstAreaUid(egg.uid) then
            slotKey = AreaEggSlotIdentity.SlotKey(egg.areaId, egg.nestId)
        end

        -- 5. CONNECT LISTENER FIRST, then fire
        local carryStarted = false
        local connStart = Remotes.EggWorld.FieldEggCarry.OnClientEvent:Connect(function(state)
            if state and state.IsCarrying == true then
                carryStarted = true
            end
        end)

        local fired, err = Remotes.EggWorld.AskFieldEggCarry:InvokeServer({
            Uid = egg.uid,
            FirstAreaSlotKey = slotKey,
        })
        if not fired then
            if connStart then pcall(function() connStart:Disconnect() end) end
            return false, "carry rejected: " .. tostring(err)
        end

        if not waitFor(function() return carryStarted end, M.CARRY_FIRE_TIMEOUT) then
            if connStart then pcall(function() connStart:Disconnect() end) end
            return false, "carry never started"
        end
        if connStart then pcall(function() connStart:Disconnect() end) end

        -- 6. walk home — with stale-event filter on carry-end listener
        local humReturn = humanoid()
        if not humReturn then return false, "no humanoid for return" end

        local pickupTime = os.clock()
        local carryEnded = false
        local connEvent = Remotes.EggWorld.FieldEggCarry.OnClientEvent:Connect(function(state)
            if state and state.IsCarrying == false
               and (os.clock() - pickupTime) > M.STALE_EVENT_WINDOW then
                carryEnded = true
            end
        end)

        local reachedSafe = false
        local connReturn
        connReturn = RunService.RenderStepped:Connect(function()
            if carryEnded then
                pcall(function() humReturn:Move(Vector3.zero) end)
                if connReturn then pcall(function() connReturn:Disconnect() end) end
                connReturn = nil
                return
            end
            local safe = safeZoneTarget()
            local p = pos()
            if not safe or not p then return end
            local delta = safe - p
            local horiz = Vector3.new(delta.X, 0, delta.Z)
            if horiz.Magnitude <= 4 then
                pcall(function() humReturn:Move(Vector3.zero) end)
                reachedSafe = true
                if connReturn then pcall(function() connReturn:Disconnect() end) end
                connReturn = nil
                return
            end
            pcall(function() humReturn:Move(horiz.Unit) end)
        end)

        local tStartReturn = os.clock()
        while not carryEnded and not reachedSafe and (os.clock() - tStartReturn) < M.RETURN_TIMEOUT do
            if not running then break end
            task.wait(0.1)
        end
        if connReturn then pcall(function() connReturn:Disconnect() end) end
        if humReturn then pcall(function() humReturn:Move(Vector3.zero) end) end

        if reachedSafe and not carryEnded then
            local tWait = os.clock()
            while not carryEnded and (os.clock() - tWait) < M.DROP_TIMEOUT do
                if not running then break end
                task.wait(0.1)
            end
        end

        if connEvent then pcall(function() connEvent:Disconnect() end) end

        local csNow = EggState.ReadCarryState()
        local insidePen = isInsidePen()
        log(("return: reachedSafe=%s carryEnded=%s insidePen=%s cs=%s"):format(
            tostring(reachedSafe), tostring(carryEnded), tostring(insidePen),
            tostring(csNow and csNow.IsCarrying)))

        if not carryEnded then
            -- fallback: reached safe target, inside pen, client shows not carrying
            if reachedSafe and insidePen and csNow and not csNow.IsCarrying then
                log("delivered (fallback: reachedSafe + insidePen + cs=false)")
                return true, nil
            end
            return false, ("server never confirmed carry-end (reachedSafe=%s insidePen=%s cs=%s)"):format(
                tostring(reachedSafe), tostring(insidePen), tostring(csNow and csNow.IsCarrying))
        end
        if csNow and csNow.IsCarrying then
            return false, "server ended carry but client shows carrying"
        end

        return true, nil
    end

    local function loop()
        local fails = 0
        while running do
            local okCall, result, reason = pcall(carryOnce)
            if not running then break end
            if not okCall then
                log("error: " .. tostring(result))
                fails = fails + 1
            elseif result == true then
                log("delivered")
                fails = 0
                task.wait(0.8)
            else
                log("fail: " .. tostring(reason or "unknown"))
                fails = fails + 1
                task.wait(0.6)
            end
            if fails >= M.MAX_FAILS then
                log("stopping after " .. fails .. " failures")
                running = false
                break
            end
            task.wait(0.4)
        end
    end

    function M:Start()
        if running then log("already running") return end
        if not loadDeps() then return end
        if not Finder then log("no Finder") return end
        running = true
        thread = task.spawn(loop)
        log("started")
    end

    function M:Stop()
        running = false
        local hum = humanoid()
        if hum then pcall(function() hum:Move(Vector3.zero) end) end
        if thread then
            pcall(task.cancel, thread)
            thread = nil
        end
        log("stopped")
    end

    getgenv()._ForceStopAutoEgg = function()
        running = false
        if thread then pcall(task.cancel, thread) thread = nil end
        local hum = humanoid()
        if hum then pcall(function() hum:Move(Vector3.zero) end) end
        warn("[autoegg] force-stopped")
    end

    return M
end
