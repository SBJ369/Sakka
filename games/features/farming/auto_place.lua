-- games/features/farming/auto_place.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

return function(ctx)
    local lib = ctx and ctx.lib
    local Env = ctx and ctx.Env
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

    -- Smooth walking function
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

            -- Decelerate when close
            if dist < 15 then
                hum:Move(horiz.Unit * (dist / 15))
            else
                hum:Move(horiz.Unit)
            end
        end)

        -- Wait up to 30 seconds to arrive
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

        while running do
            local plot = PlotState.ResolvePlot()
            if plot then
                local mySave = Save.Await(LocalPlayer)
                local owners = EggState.ReadOwnedEggs()
                
                -- 1. Count unplaced eggs and current capacity
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

                -- 2. If we have eggs to place and room for them, walk to plot
                if #unplaced > 0 and spaceLeft > 0 then
                    log("Walking to plot to place eggs...")
                    local centerPos = plot.CenterPoint.Position
                    
                    if walkTo(centerPos, 10) then
                        -- We are at the plot, start placing
                        for _, item in ipairs(unplaced) do
                            if not running or spaceLeft <= 0 then break end

                            -- Generate a grid position
                            local index = placedCount
                            local row = math.floor(index / 3)
                            local col = index % 3
                            
                            local offsetX = (col - 1) * 3
                            local offsetZ = (row - 2) * 3
                            
                            local worldPos = plot.CenterPoint.Position + Vector3.new(offsetX, 2, offsetZ)
                            local localCFrame = plot.CenterPoint.CFrame:ToObjectSpace(CFrame.new(worldPos))

                            local ok, success, err = pcall(function()
                                return Remotes.EggWorld.AskPlaceEgg:InvokeServer({
                                    Uid = item.uid,
                                    LocalCFrame = localCFrame
                                })
                            end)
                            
                            if ok and success then
                                placedCount = placedCount + 1
                                spaceLeft = spaceLeft - 1
                                task.wait(0.5) -- Wait for server to sync
                            else
                                print("[autoplace] Failed to place:", err)
                            end
                        end
                    else
                        print("[autoplace] Failed to reach plot.")
                    end
                end
            end
            task.wait(2) -- Scan every 2 seconds
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
