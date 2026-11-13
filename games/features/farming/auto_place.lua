-- games/features/farming/auto_place.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

return function(ctx)
    local lib = ctx and ctx.lib
    local Env = ctx and ctx.Env
    local options = ctx and ctx.options
    local LocalPlayer = Players.LocalPlayer
    local M = {}

    local running = false
    local thread

    local Remotes, EggState, PlotState, Bases, Save
    local function loadDeps()
        if Remotes then return true end
        local ok = pcall(function()
            Remotes = require(ReplicatedStorage.Shared.Remotes)
            EggState = require(ReplicatedStorage.Client.EggState)
            PlotState = require(ReplicatedStorage.Client.PlotState)
            Bases = require(ReplicatedStorage.Data.Bases)
            Save = require(ReplicatedStorage.Shared.Save)
        end)
        return ok
    end

    local function log(msg)
        if lib and lib.Notify then
            pcall(function() lib:Notify({ Title = "Auto Place", Content = tostring(msg), Duration = 3 }) end)
        end
        warn("[autoplace] " .. tostring(msg))
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

    local function startArea()
        local world = Workspace:FindFirstChild("World")
        local areas = world and world:FindFirstChild("Areas")
        return areas and areas:FindFirstChild("StartArea")
    end

    local function checkTreadmill()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = { char }
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local result = workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), rayParams)

        if result and result.Instance then
            local name = result.Instance.Name:lower()
            if name:find("tread") or name:find("belt") then
                hum.Jump = true
                task.wait(0.5)
            end
        end
    end

    local function walkTo(targetPos, distThreshold)
        local hum = humanoid()
        if not hum or not targetPos then return false end

        local reached = false
        local conn = RunService.RenderStepped:Connect(function()
            if not running or reached then return end
            local p = pos()
            if not p then return end

            local delta = targetPos - p
            local horiz = Vector3.new(delta.X, 0, delta.Z)
            local dist = horiz.Magnitude

            if dist <= (distThreshold or 5) then
                hum:Move(Vector3.zero)
                reached = true
                if conn then conn:Disconnect() end
                return
            end

            if dist < 15 then
                hum:Move(horiz.Unit * (dist / 15))
            else
                hum:Move(horiz.Unit)
            end
        end)

        local t0 = os.clock()
        while running and not reached and (os.clock() - t0) < 30 do
            task.wait(0.1)
        end

        if conn then conn:Disconnect() end
        if hum then hum:Move(Vector3.zero) end
        return reached
    end

    -- Dynamic grid location relative to the center part
    local function getGridLocalPosition(index, step)
        local x, z = 0, 0
        local dx, dz = 0, -1
        for i = 1, index do
            if x == z or (x < 0 and x == -z) or (x > 0 and x == 1 - z) then
                local temp = dx
                dx = -dz
                dz = temp
            end
            x = x + dx
            z = z + dz
        end
        return Vector3.new(x * step, 2, z * step)
    end

    local function loop()
        if not loadDeps() then return end
        print("[autoplace] Loop started.")
        
        local failedPlacements = 0

        while running do
            if options and options.isBusy then
                task.wait(1)
                continue
            end

            local plot = PlotState.ResolvePlot()
            if plot then
                local mySave = Save.Await(LocalPlayer)
                local owners = EggState.ReadOwnedEggs()

                local unplaced = {}
                local occupied = {}

                for _, owner in ipairs(owners) do
                    if owner.OwnerUserId == LocalPlayer.UserId then
                        for uid, record in pairs(owner.Records) do
                            if not record.Placement then
                                table.insert(unplaced, { uid = uid, record = record })
                            else
                                -- Save exact local position of already placed eggs
                                if record.Placement.LocalCFrame then
                                    table.insert(occupied, record.Placement.LocalCFrame.Position)
                                end
                            end
                        end
                    end
                end

                local level = mySave and mySave.BaseUpgradeLevel or 0
                local cap = Bases.GetAssetEquipCapacity(level) or 10
                local spaceLeft = cap - #occupied

                if #unplaced > 0 and spaceLeft > 0 then
                    -- Auto Egg Priority: If Auto Egg is active and there are eggs, back off.
                    if options.autoEggEnabled and options.hasAvailableEggs then
                        task.wait(1)
                        continue
                    end
                    
                    if options.isBusy then
                        task.wait(1)
                        continue
                    end

                    options.isBusy = true
                    task.wait(0.2) -- Let other scripts yield

                    checkTreadmill()
                    log("Taking over to place eggs...")

                    local sa = startArea()
                    local pNow = pos()
                    if sa and pNow then
                        local inSafeZone = pNow.Z > sa.Position.Z
                        if not inSafeZone then
                            walkTo(Vector3.new(pNow.X, pNow.Y, sa.Position.Z + 10), 5)
                        end
                    end

                    local centerPos = plot.CenterPoint.Position
                    if walkTo(centerPos, 10) then
                        for _, item in ipairs(unplaced) do
                            if not running or spaceLeft <= 0 then break end
                            
                            local bounds = item.record.BoundsSize
                            local sizeX = bounds and bounds.X or 2
                            local sizeZ = bounds and bounds.Z or 2
                            local step = math.max(sizeX, sizeZ) + 1.5

                            local success = false
                            local attempts = 0
                            local maxAttempts = 50
                            local currentGridIndex = 0

                            while not success and attempts < maxAttempts do
                                local targetLocalPos = getGridLocalPosition(currentGridIndex, step)
                                currentGridIndex = currentGridIndex + 1
                                
                                local free = true
                                for _, occPos in ipairs(occupied) do
                                    local horiz = Vector3.new(targetLocalPos.X - occPos.X, 0, targetLocalPos.Z - occPos.Z)
                                    if horiz.Magnitude < step then
                                        free = false
                                        break
                                    end
                                end

                                if free then
                                    local targetWorld = plot.CenterPoint.CFrame * CFrame.new(targetLocalPos)
                                    local localCFrame = plot.CenterPoint.CFrame:ToObjectSpace(targetWorld)

                                    local ok, res = pcall(function()
                                        return Remotes.EggWorld.AskPlaceEgg:InvokeServer({ Uid = item.uid, LocalCFrame = localCFrame })
                                    end)
                                    
                                    if ok and res then
                                        success = true
                                        table.insert(occupied, targetLocalPos)
                                        spaceLeft = spaceLeft - 1
                                        failedPlacements = 0
                                        break
                                    else
                                        table.insert(occupied, targetLocalPos) -- Server rejected, skip this spot
                                    end
                                end
                                attempts = attempts + 1
                            end

                            if not success then
                                failedPlacements = failedPlacements + 1
                                log("Could not find a valid spot for egg.")
                            end
                            
                            task.wait(0.5)
                        end
                    end

                    options.isBusy = false
                    
                    if failedPlacements >= 3 then
                        log("Too many failed placements. Plot might be full. Waiting 30s...")
                        task.wait(30)
                        failedPlacements = 0
                    end
                end
            end
            task.wait(1)
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
        log("stopped")
    end

    return M
end
