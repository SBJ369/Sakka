-- games/features/eggs/environment.lua
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(ctx)
    local M = {}
    local LocalPlayer = Players.LocalPlayer
    local PlotState = require(ReplicatedStorage.Client.PlotState)

    M.STATIC = {
        FuseMachine = Vector3.new(542.4, 73.1, -452.4),
        TrailShop   = Vector3.new(531.2, 67.8, -307.1),
        SellStand   = Vector3.new(532.5, 70.6, -428.9),
    }

    local myPlotCache = nil
    local lastPlotFolder = nil

    function M:GetMyPlot()
        local plot = PlotState.ResolvePlot()
        if not plot then return nil end
        if plot.PlotFolder ~= lastPlotFolder then
            myPlotCache = nil
            lastPlotFolder = plot.PlotFolder
        end
        return plot
    end

    function M:GetMyPlotCenter()
        local plot = self:GetMyPlot()
        if plot and plot.CenterPoint then
            return plot.CenterPoint.Position
        end
        return nil
    end

    function M:GetMyTreadmill()
        local plot = self:GetMyPlot()
        if not plot or not plot.PlotFolder then return nil end
        local treadBottom = plot.PlotFolder:FindFirstChild("TreadmillBottom")
        if treadBottom and treadBottom:IsA("BasePart") then
            return treadBottom.Position
        end
        return nil
    end

        local treadBottom = plot.PlotFolder:FindFirstChild("TreadmillBottom")
        if treadBottom and treadBottom:IsA("BasePart") then
            myPlotCache = myPlotCache or {}
            myPlotCache.Treadmill = treadBottom.Position
            return treadBottom.Position
        end
        return nil
    end

    -- Get the Treadmill Upgrade Board (TreadmillUpgrade)
    function M:GetMyTreadmillUpgrade()
        local plot = self:GetMyPlot()
        if not plot or not plot.PlotFolder then return nil end

        if myPlotCache and myPlotCache.TreadmillUpgrade then
            return myPlotCache.TreadmillUpgrade
        end

        local upgradeModel = plot.PlotFolder:FindFirstChild("TreadmillUpgrade")
        if not upgradeModel then return nil end

        local basePart = upgradeModel.PrimaryPart
        if not basePart then
            for _, v in ipairs(upgradeModel:GetDescendants()) do
                if v:IsA("BasePart") then
                    basePart = v
                    break
                end
            end
        end

        if basePart then
            myPlotCache = myPlotCache or {}
            myPlotCache.TreadmillUpgrade = basePart.Position
            return basePart.Position
        end
        return nil
    end

    -- Get the Plot Upgrade Board (PlotUpgrade)
    function M:GetMyPlotUpgrade()
        local plot = self:GetMyPlot()
        if not plot or not plot.PlotFolder then return nil end

        if myPlotCache and myPlotCache.PlotUpgrade then
            return myPlotCache.PlotUpgrade
        end

        local upgradeModel = plot.PlotFolder:FindFirstChild("PlotUpgrade")
        if not upgradeModel then return nil end

        local basePart = upgradeModel.PrimaryPart
        if not basePart then
            for _, v in ipairs(upgradeModel:GetDescendants()) do
                if v:IsA("BasePart") then
                    basePart = v
                    break
                end
            end
        end

        if basePart then
            myPlotCache = myPlotCache or {}
            myPlotCache.PlotUpgrade = basePart.Position
            return basePart.Position
        end
        return nil
    end

    function M:GetStaticPoints() return M.STATIC end
    function M:GetStatic(name) return M.STATIC[name] end

    return M
end
