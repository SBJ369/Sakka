-- games/features/eggs/environment.lua
-- Centralized map locator. Caches static points and dynamically resolves the player's plot.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(ctx)
    local M = {}
    local LocalPlayer = Players.LocalPlayer
    local PlotState = require(ReplicatedStorage.Client.PlotState)

    -- Static Coordinates (Hardcoded from diagnostic)
    M.STATIC = {
        FuseMachine = Vector3.new(542.4, 73.1, -452.4),
        TrailShop   = Vector3.new(531.2, 67.8, -307.1),
        SellStand   = Vector3.new(532.5, 70.6, -428.9),
    }

    -- Cache for the player's dynamic plot data
    local myPlotCache = nil
    local lastPlotFolder = nil

    -- Returns the PlotState table for the local player
    function M:GetMyPlot()
        local plot = PlotState.ResolvePlot()
        if not plot then return nil end

        -- If the plot changed (e.g. server hop), clear cache
        if plot.PlotFolder ~= lastPlotFolder then
            myPlotCache = nil
            lastPlotFolder = plot.PlotFolder
        end

        return plot
    end

    -- Returns the exact Vector3 of the player's plot center
    function M:GetMyPlotCenter()
        local plot = self:GetMyPlot()
        if plot and plot.CenterPoint then
            return plot.CenterPoint.Position
        end
        return nil
    end

    -- Returns the exact Vector3 of the player's treadmill
    function M:GetMyTreadmill()
        local plot = self:GetMyPlot()
        if not plot or not plot.PlotFolder then return nil end

        if myPlotCache and myPlotCache.Treadmill then
            return myPlotCache.Treadmill
        end

        local treadmillModel = plot.PlotFolder:FindFirstChild("TreadmillUpgrade")
        if not treadmillModel then return nil end

        -- Find a BasePart to use as the center
        local basePart = treadmillModel.PrimaryPart
        if not basePart then
            for _, v in ipairs(treadmillModel:GetDescendants()) do
                if v:IsA("BasePart") then
                    basePart = v
                    break
                end
            end
        end

        if basePart then
            myPlotCache = myPlotCache or {}
            myPlotCache.Treadmill = basePart.Position
            return basePart.Position
        end

        return nil
    end

    -- Returns a dictionary of all static points
    function M:GetStaticPoints()
        return M.STATIC
    end

    -- Returns a specific static point by name
    function M:GetStatic(name)
        return M.STATIC[name]
    end

    return M
end
