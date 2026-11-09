-- games/features/farming/auto_sell.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

return function(ctx)
    local lib = ctx and ctx.lib
    local M = {}

    local Remotes, Save, AssetItems, AssetEarnings, Assets
    local LocalPlayer = Players.LocalPlayer

    local function loadDeps()
        if Remotes then return true end
        local ok, r = pcall(function()
            Remotes = require(ReplicatedStorage.Shared.Remotes)
            Save = require(ReplicatedStorage.Shared.Save)
            AssetItems = require(ReplicatedStorage.Shared.Util.AssetItems)
            AssetEarnings = require(ReplicatedStorage.Shared.Util.AssetEarnings)
            Assets = require(ReplicatedStorage.Data.Assets)
        end)
        if not ok then
            if lib then lib:Notify({ Title = "Auto Sell", Content = "Failed to load modules.", Duration = 3 }) end
        end
        return ok
    end

    local function log(msg)
        if lib and lib.Notify then
            pcall(function() lib:Notify({ Title = "Auto Sell", Content = tostring(msg), Duration = 3 }) end)
        end
        warn("[autosell] " .. tostring(msg))
    end

    -- Correct way to calculate Weight and Value using the game's own functions
    local function getPetStats(petData, saveData)
        local ok, decoded = pcall(function()
            return AssetItems.Decode(petData)
        end)
        if not ok or not decoded then return 0, 0 end
        
        -- 1. Calculate Rate/Value per second
        local value = 0
        pcall(function()
            value = AssetEarnings.LiveRatePerSecond(decoded, saveData.Gamepasses, saveData.Products, LocalPlayer)
        end)

        -- 2. Calculate Weight based on the scale and base asset weight
        local weight = 0
        pcall(function()
            local assetData = Assets.Directory[decoded.Category]
            if assetData then
                local baseWeight = assetData.ModelWeight or 1
                -- Assuming weight scales with the model scale (e.g. 1.5x scale = 1.5x weight)
                weight = baseWeight * (decoded.Scale or 1)
            end
        end)
        
        return weight, value
    end

    function M:SellAll()
        if not loadDeps() then return end
        log("Selling all pets...")
        pcall(function() Remotes.PetSatchel.SellEveryPet:FireServer() end)
    end

    function M:SellUnderWeight(maxWeight)
        if not loadDeps() then return end
        local mySave = Save.Await(LocalPlayer)
        if not mySave or not mySave.Inventory then return end

        local toSell = {}
        for uid, data in pairs(mySave.Inventory) do
            local weight = getPetStats(data, mySave)
            if weight > 0 and weight <= maxWeight then
                table.insert(toSell, uid)
            end
        end

        if #toSell > 0 then
            log(string.format("Selling %d pets under %s kg...", #toSell, tostring(maxWeight)))
            pcall(function() Remotes.PetSatchel.SellSelection:FireServer(toSell) end)
        else
            log("No pets found under " .. tostring(maxWeight) .. " kg.")
        end
    end

    function M:SellUnderValue(maxValue)
        if not loadDeps() then return end
        local mySave = Save.Await(LocalPlayer)
        if not mySave or not mySave.Inventory then return end

        local toSell = {}
        for uid, data in pairs(mySave.Inventory) do
            local _, value = getPetStats(data, mySave)
            if value > 0 and value <= maxValue then
                table.insert(toSell, uid)
            end
        end

        if #toSell > 0 then
            log(string.format("Selling %d pets under $%s/s...", #toSell, tostring(maxValue)))
            pcall(function() Remotes.PetSatchel.SellSelection:FireServer(toSell) end)
        else
            log("No pets found under $" .. tostring(maxValue) .. "/s.")
        end
    end

    return M
end
