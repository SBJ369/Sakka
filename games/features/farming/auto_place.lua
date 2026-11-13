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

    local function loop()
        if not loadDeps() then return end
        print("[autoplace] Loop started.")

        -- Create a massive 11x11 grid (121 slots) sorted by distance from center
        local slots = {}
        local step = 3.0 -- tight spacing
        for x = -5, 5 do
            for z = -5, 5 do
                table.insert(slots, Vector3.new(x * step, 2, z * step))
            end
        end
        table.sort(slots, function(a, b) return a.Magnitude < b.Magnitude end)

        while running do
            if options and options.isBusy then
                task.wait(1)
                continue
            end

            if options.eggActive and options.hasAvailableEggs then
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
                                if record.Placement.LocalCFrame then
                                    table.insert(occupied, {
                                        pos = record.Placement.LocalCFrame.Position,
                                        size = record.BoundsSize or Vector3.new(2,2,2)
                                    })
                                end
                            end
                        end
                    end
                end

                -- Add fixed structures like Treadmill to prevent clipping
                local function addStructure(name, size)
                    local part = plot.PlotFolder:FindFirstChild(name)
                    if part and part:IsA("BasePart") then
                        local localPos = plot.CenterPoint.CFrame:PointToObjectSpace(part.Position)
                        table.insert(occupied, { pos = localPos, size = size })
                    end
                end
                addStructure("TreadmillBottom", Vector3.new(9, 2, 14))
                addStructure("PlotSign", Vector3.new(4, 4, 4))
                addStructure("SpawnPoint", Vector3.new(4, 4, 4))
                
                local plotUp = plot.PlotFolder:FindFirstChild("PlotUpgrade")
                if plotUp and plotUp.PrimaryPart then
                    local localPos = plot.CenterPoint.CFrame:PointToObjectSpace(plotUp.PrimaryPart.Position)
                    table.insert(occupied, { pos = localPos, size = Vector3.new(4,4,4) })
                end
                local treadUp = plot.PlotFolder:FindFirstChild("TreadmillUpgrade")
                if treadUp and treadUp.PrimaryPart then
                    local localPos = plot.CenterPoint.CFrame:PointToObjectSpace(treadUp.PrimaryPart.Position)
                    table.insert(occupied, { pos = localPos, size = Vector3.new(4,4,4) })
                end

                local level = mySave and mySave.BaseUpgradeLevel or 0
                local cap = Bases.GetAssetEquipCapacity(level) or 10
                local spaceLeft = cap - #occupied

                if #unplaced > 0 and spaceLeft > 0 then
                    if options.isBusy then
                        task.wait(1)
                        continue
                    end

                    options.isBusy = true
                    task.wait(0.2) 

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

                            local newSize = item.record.BoundsSize or Vector3.new(2,2,2)
                            local newRadius = math.max(newSize.X, newSize.Z) * 0.5
                            local placed = false

                            for _, slot in ipairs(slots) do
                                local free = true
                                for _, occ in ipairs(occupied) do
                                    local occRadius = math.max(occ.size.X, occ.size.Z) * 0.5
                                    local dx = slot.X - occ.pos.X
                                    local dz = slot.Z - occ.pos.Z
                                    if math.sqrt(dx*dx + dz*dz) < (newRadius + occRadius) then
                                        free = false
                                        break
                                    end
                                end

                                if free then
                                    local localCFrame = CFrame.new(slot)
                                    local ok, res = pcall(function()
                                        return Remotes.EggWorld.AskPlaceEgg:InvokeServer({ Uid = item.uid, LocalCFrame = localCFrame })
                                    end)

                                    if ok and res then
                                        -- Success, add to occupied and move to next egg
                                        table.insert(occupied, { pos = slot, size = newSize })
                                        spaceLeft = spaceLeft - 1
                                        placed = true
                                        break
                                    else
                                        -- Server rejected (clipping), mark this specific spot as blocked forever
                                        table.insert(occupied, { pos = slot, size = newSize })
                                    end
                                end
                            end

                            if not placed then
                                log("Could not find valid space for egg.")
                            end
                            task.wait(0.5)
                        end
                    end

                    options.isBusy = false
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
