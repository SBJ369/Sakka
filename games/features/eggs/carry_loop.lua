-- games/features/eggs/carry_loop.lua
-- Auto-carry cycle. 
-- 1. Walks to the Z-coordinate of StartArea (keeping current X) to funnel through the entrance.
-- 2. Walks to the targeted egg in the field.
-- 3. Carries it back to StartArea center.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

return function(ctx)
    local lib = ctx and ctx.lib
    local Finder = ctx and ctx.Finder
    local options = ctx and ctx.options or {}

    local M = {}
    local LocalPlayer = Players.LocalPlayer
    local Remotes, EggState, AreaEggSlotIdentity

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
        end)
        if not ok then log("loadDeps: " .. tostring(err)) end
        return ok
    end

    M.CARRY_RANGE        = 10
    M.WALK_TIMEOUT       = 120
    M.CARRY_FIRE_TIMEOUT = 5
    M.RETURN_TIMEOUT     = 45
    M.DROP_TIMEOUT       = 8
    M.MAX_FAILS          = 3
    M.STALE_EVENT_WINDOW = 0.2
    M.SOFT_WAIT          = 3

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

    local function startArea()
        local world = Workspace:FindFirstChild("World")
        local areas = world and world:FindFirstChild("Areas")
        return areas and areas:FindFirstChild("StartArea")
    end

    local function filterFingerprint()
        local f = options.fields or {}
        local parts = {}
        for _, v in ipairs(f) do table.insert(parts, v) end
        local m = options.allowedMutations or {}
        for _, v in ipairs(m) do table.insert(parts, "|m:" .. v) end
        return table.concat(parts, ",")
    end

    local function filterChanged(fp)
        return filterFingerprint() ~= fp
    end

    local function walkTo(target, stopDist, timeout, fp)
        stopDist = stopDist or 4
        timeout = timeout or M.WALK_TIMEOUT
        local hum = humanoid()
        if not hum then return false, "no_humanoid" end

        local done = false
        local reached = false
        local aborted = false
        local t0 = os.clock()

        local conn
        conn = RunService.RenderStepped:Connect(function()
            if done then return end
            if not running then
                pcall(function() hum:Move(Vector3.zero) end)
                done = true
                aborted = true
                return
            end
            if fp and filterChanged(fp) then
                pcall(function() hum:Move(Vector3.zero) end)
                done = true
                aborted = true
                return
            end
            if os.clock() - t0 > timeout then
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
        if aborted then return false, "aborted" end
        return reached
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

    local function buildFinderOpts()
        local opts = { maxDist = 6000 }
        local fields = options.fields or {}
        if #fields == 1 then
            opts.areaId = fields[1]
        elseif #fields > 1 then
            opts.areaPriority = fields
        end
        if options.allowedMutations and #options.allowedMutations > 0 then
            opts.mutations = options.allowedMutations
        end
        return opts
    end

    local function carryOnce()
        if not options.fields or #options.fields == 0 then
            return false, "no fields selected", "soft"
        end

        local fp = filterFingerprint()

        -- 1. Find an egg first. If none exist, wait in the safe zone.
        local egg = Finder:Nearest(buildFinderOpts())
        if not egg then 
            return false, "no egg matching filters (waiting for respawn)", "soft" 
        end

        -- 2. Walk to the funnel entrance (Z-coordinate of StartArea, keeping current X).
        -- This prevents hitting the side walls and avoids detouring if already in the field.
        local sa = startArea()
        if not sa then return false, "no StartArea found", "hard" end
        
        local p = pos()
        local entranceTarget = Vector3.new(p.X, p.Y, sa.Position.Z)
        local distToEntrance = (p - entranceTarget).Magnitude
        
        -- Only walk to entrance if we are not already within the Z-band of StartArea
        if distToEntrance > 15 then
            local okEntrance = walkTo(entranceTarget, 5, 30, fp)
            if not okEntrance then return false, "walk to funnel entrance timed out", "hard" end
        end

        -- 3. Walk to the actual egg in the field
        local ok, why = walkTo(egg.position, M.CARRY_RANGE, M.WALK_TIMEOUT, fp)
        if why == "aborted" then return false, "filter changed", "soft" end
        if not ok then return false, "walk to egg timed out", "hard" end

        local dist = Finder:DistanceTo(egg.uid)
        if not dist or dist > M.CARRY_RANGE + 3 then
            return false, "lost range to egg", "soft"
        end

        local slotKey
        if AreaEggSlotIdentity.LooksLikeFirstAreaUid(egg.uid) then
            slotKey = AreaEggSlotIdentity.SlotKey(egg.areaId, egg.nestId)
        end

        -- 4. Fire the remote
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
            local e = tostring(err or "")
            if e:find("Already carrying") or e:find("First area egg unavailable") then
                return false, "carry rejected: " .. e, "soft"
            end
            return false, "carry rejected: " .. e, "hard"
        end

        if not waitFor(function() return carryStarted end, M.CARRY_FIRE_TIMEOUT) then
            if connStart then pcall(function() connStart:Disconnect() end) end
            return false, "carry never started", "hard"
        end
        if connStart then pcall(function() connStart:Disconnect() end) end

        -- 5. Walk to the StartArea to deliver (Target the exact center of StartArea)
        local humReturn = humanoid()
        if not humReturn then return false, "no humanoid for return", "hard" end

        local pickupTime = os.clock()
        local carryEnded = false
        local connEvent = Remotes.EggWorld.FieldEggCarry.OnClientEvent:Connect(function(state)
            if state and state.IsCarrying == false
               and (os.clock() - pickupTime) > M.STALE_EVENT_WINDOW then
                carryEnded = true
            end
        end)

        local reachedSafe = false
        local returnAborted = false
        local connReturn
        
        connReturn = RunService.RenderStepped:Connect(function()
            if carryEnded then
                pcall(function() humReturn:Move(Vector3.zero) end)
                if connReturn then pcall(function() connReturn:Disconnect() end) end
                connReturn = nil
                return
            end
            if not running or filterChanged(fp) then
                pcall(function() humReturn:Move(Vector3.zero) end)
                returnAborted = true
                if connReturn then pcall(function() connReturn:Disconnect() end) end
                connReturn = nil
                return
            end
            
            local sa = startArea()
            local p = pos()
            if not sa or not p then return end

            -- For delivery, we must go to the exact center of StartArea
            local targetPos = sa.Position
            local delta = targetPos - p
            local horiz = Vector3.new(delta.X, 0, delta.Z)
            
            if horiz.Magnitude <= 3 then
                pcall(function() humReturn:Move(Vector3.zero) end)
                reachedSafe = true
            else
                pcall(function() humReturn:Move(horiz.Unit) end)
            end
        end)

        local tStartReturn = os.clock()
        while not carryEnded and not returnAborted
              and (os.clock() - tStartReturn) < M.RETURN_TIMEOUT do
            if not running then break end
            task.wait(0.1)
        end
        if connReturn then pcall(function() connReturn:Disconnect() end) end
        if humReturn then pcall(function() humReturn:Move(Vector3.zero) end) end

        if returnAborted then
            if connEvent then pcall(function() connEvent:Disconnect() end) end
            return false, "filter changed mid-return", "soft"
        end

        if not carryEnded then
            local tWait = os.clock()
            while not carryEnded and (os.clock() - tWait) < M.DROP_TIMEOUT do
                if not running then break end
                task.wait(0.1)
            end
        end

        if connEvent then pcall(function() connEvent:Disconnect() end) end

        local csNow = EggState.ReadCarryState()
        
        if not carryEnded then
            if reachedSafe and csNow and not csNow.IsCarrying then
                return true, nil
            end
            return false, "server never confirmed carry-end", "hard"
        end
        if csNow and csNow.IsCarrying then
            return false, "server ended carry but client shows carrying", "hard"
        end
        
        return true, nil
    end

    local function loop()
        local fails = 0
        local lastSoftReason = nil
        while running do
            local okCall, result, reason, kind = pcall(carryOnce)
            if not running then break end

            if not okCall then
                log("error: " .. tostring(result))
                fails = fails + 1
                lastSoftReason = nil
            elseif result == true then
                log("delivered")
                fails = 0
                lastSoftReason = nil
                task.wait(0.8)
            elseif kind == "soft" then
                if reason ~= lastSoftReason then
                    log("waiting: " .. tostring(reason))
                    lastSoftReason = reason
                end
                task.wait(M.SOFT_WAIT)
            else
                log("fail: " .. tostring(reason or "unknown"))
                fails = fails + 1
                lastSoftReason = nil
                task.wait(0.6)
            end

            if fails >= M.MAX_FAILS then
                log("stopping after " .. fails .. " failures")
                running = false
                break
            end
            if kind ~= "soft" then task.wait(0.4) end
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
