-- games/features/farming/auto_place.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

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

    local function loop()
        if not loadDeps() then return end
        print("[autoplace] Loop started.")

        while running do
            local plot = PlotState.ResolvePlot()
            if plot then
                local mySave = Save.Await(LocalPlayer)
                -- Check if we have unplaced eggs
                local unplaced = {}
                local owners = EggState.ReadOwnedEggs()
                for _, owner in ipairs(owners) do
                    if owner.OwnerUserId == LocalPlayer.UserId then
                        for uid, record in pairs(owner.Records) do
                            if not record.Placement then
                                table.insert(unplaced, { uid = uid, record = record })
                            end
                        end
                    end
                end

                if #unplaced > 0 then
                    -- Get plot capacity
                    local level = mySave and mySave.BaseUpgradeLevel or 0
                    local cap = Bases.GetAssetEquipCapacity(level) or 10
                    
                    -- Count currently placed
                    local placedCount = 0
                    for _, owner in ipairs(owners) do
                        if owner.OwnerUserId == LocalPlayer.UserId then
                            for uid, record in pairs(owner.Records) do
                                if record.Placement then
                                    placedCount = placedCount + 1
                                end
                            end
                        end
                    end

                    local spaceLeft = cap - placedCount
                    if spaceLeft > 0 then
                        -- We have space. Start placing.
                        for _, item in ipairs(unplaced) do
                            if not running then break end
                            if spaceLeft <= 0 then break end

                            -- Generate a grid offset based on the number currently placed
                            local index = placedCount
                            local row = math.floor(index / 3)
                            local col = index % 3
                            
                            -- Offset from CenterPoint (3 studs apart)
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
                                task.wait(0.5) -- wait for server validation
                            end
                        end
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
