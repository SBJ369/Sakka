-- games/features/farming/auto_sell.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

return function(ctx)
    local lib = ctx and ctx.lib
    local M = {}

    local Remotes, Save, AssetItems
    local LocalPlayer = Players.LocalPlayer

    local function loadDeps()
        if Remotes then return true end
        local ok, r = pcall(function()
            Remotes = require(ReplicatedStorage.Shared.Remotes)
            Save = require(ReplicatedStorage.Shared.Save)
            AssetItems = require(ReplicatedStorage.Shared.Util.AssetItems)
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

    -- DEBUG function to see what Decode returns
    local function dumpPetData(petData)
        local ok, decoded = pcall(function() return AssetItems.Decode(petData) end)
        if ok and decoded then
            print("=== DECODED PET DATA ===")
            for k, v in pairs(decoded) do
                print("  ", k, "=", tostring(v))
            end
        else
            warn("[autosell] Decode failed:", decoded)
        end
    end

    local function getPetStats(petData)
        local ok, decoded = pcall(function()
            return AssetItems.Decode(petData)
        end)
        if not ok or not decoded then return 0, 0 end
        
        -- We will adjust these exact keys based on the dump output
        local weight = decoded.Weight or decoded.Mass or decoded.Size or 0
        local value = decoded.Rate or decoded.Income or decoded.Value or 0
        
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
        local first = true
        for uid, data in pairs(mySave.Inventory) do
            if first then
                dumpPetData(data) -- Prints the data to console!
                first = false
            end

            local weight = getPetStats(data)
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
        local first = true
        for uid, data in pairs(mySave.Inventory) do
            if first then
                dumpPetData(data) -- Prints the data to console!
                first = false
            end

            local _, value = getPetStats(data)
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
