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

    -- Helper to find a safe grid position (3x3 matrix)
    local function getGridPosition(centerPart, index)
        local step = 3.5
        local row = math.floor(index / 3)
        local col = index % 3
        
        -- center the grid
        local x = (col - 1) * step
        local z = (row - 1) * step
        
        return centerPart.CFrame * CFrame.new(x, 2, z)
    end

    local function loop()
        if not loadDeps() then return end
        print("[autoplace] Loop started.")

        local idleTimer = 0

        while running do
            if options and options.isBusy then
                idleTimer = 0
                task.wait(1)
                continue
            end

            local plot = PlotState.ResolvePlot()
            if plot then
                local mySave = Save.Await(LocalPlayer)
                local owners = EggState.ReadOwnedEggs()

                local unplaced = {}
                local placedCount = 0

                for _, owner in ipairs(owners) do
                    if owner.OwnerUserId == LocalPlayer.UserId then
                        for uid, record in pairs(owner.Records) do
                            if not record.Placement then
                                table.insert(unplaced, { uid = uid, record = record })
                            else
                                placedCount = placedCount + 1
                            end
                        end
                    end
                end

                local level = mySave and mySave.BaseUpgradeLevel or 0
                local cap = Bases.GetAssetEquipCapacity(level) or 10
                local spaceLeft = cap - placedCount

                if #unplaced > 0 and spaceLeft > 0 then
                    idleTimer = idleTimer + 1

                    if idleTimer >= 4 then
                        if options.isBusy then
                            idleTimer = 0
                            task.wait(1)
                            continue
                        end

                        options.isBusy = true
                        checkTreadmill()
                        log("Taking over to place eggs...")

                        local sa = startArea()
                        local pNow = pos()
                        if sa and pNow then
                            local inSafeZone = pNow.Z > sa.Position.Z
                            if not inSafeZone then
                                log("Walking to safe zone first...")
                                walkTo(Vector3.new(pNow.X, pNow.Y, sa.Position.Z + 10), 5)
                            end
                        end

                        local centerPos = plot.CenterPoint.Position
                        log("Walking to plot...")
                        if walkTo(centerPos, 10) then
                            for _, item in ipairs(unplaced) do
                                if not running or spaceLeft <= 0 then break end
                                
                                local targetCFrame = getGridPosition(plot.CenterPoint, placedCount)
                                local localCFrame = plot.CenterPoint.CFrame:ToObjectSpace(targetCFrame)

                                pcall(function()
                                    Remotes.EggWorld.AskPlaceEgg:InvokeServer({ Uid = item.uid, LocalCFrame = localCFrame })
                                end)
                                
                                placedCount = placedCount + 1
                                spaceLeft = spaceLeft - 1
                                task.wait(0.8) -- Slightly longer wait so server registers
                            end
                        end

                        idleTimer = 0
                        options.isBusy = false
                    end
                else
                    idleTimer = 0
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
