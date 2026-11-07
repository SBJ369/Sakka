-- games/features/eggs/field_egg_finder.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

return function(ctx)
    local M = {}
    local Remotes
    local LocalPlayer = Players.LocalPlayer
    local Assets
    local Directory

    -- Exact mapping from the game's Rarity.Configs
    local RANK_TO_STRING = {
        [1] = "Common",
        [2] = "Uncommon",   -- (and SuperRare)
        [3] = "Rare",
        [4] = "Epic",
        [5] = "Legendary",
        [6] = "Mythic",     -- (and Rainbow, BrainrotGod)
        [7] = "Cosmic",
        [8] = "Secret",
        [9] = "Eternal",    -- (and Limited)
        [10] = "Divine",    -- (and Transcendent)
        [11] = "Titan",
        [12] = "LightDark",
    }

    local function getRemotes()
        if Remotes then return Remotes end
        local ok, r = pcall(require, ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
        if ok and r then Remotes = r end
        return Remotes
    end

    local function getDirectory()
        if Directory then return Directory end
        local ok, a = pcall(require, ReplicatedStorage:WaitForChild("Data"):WaitForChild("Assets"))
        if ok and a and a.Directory then
            Assets = a
            Directory = a.Directory
        end
        return Directory
    end

    function M:GetRecords()
        local R = getRemotes()
        if not R then return {}, 0 end
        local ok, snap = pcall(function()
            return R.EggWorld.AskFieldEggSnapshot:InvokeServer()
        end)
        if not ok or type(snap) ~= "table" then return {}, 0 end
        return snap.Records or {}, snap.ServerTime or 0
    end

    function M:GetMyPosition()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        return hrp and hrp.Position or nil
    end

    local function eggPosition(record)
        local bottom = record.BottomCFrame
        if typeof(bottom) ~= "CFrame" then return nil end
        local bounds = record.BoundsSize
        local lift = (typeof(bounds) == "Vector3" and bounds.Y * 0.5) or 0.5
        return bottom.Position + Vector3.new(0, lift, 0)
    end

    -- Safely gets the rarity string by checking Rank -> VisualOdds fallback
    local function getEggRarity(record)
        local dir = getDirectory()
        if dir and dir[record.AssetCategory] then
            local data = dir[record.AssetCategory]
            
            -- 1. Try the Rank field directly
            local rank = data.Rank
            if rank and RANK_TO_STRING[rank] then
                return RANK_TO_STRING[rank]
            end
            
            -- 2. If no rank, try to estimate from VisualOdds
            local odds = data.VisualOdds or 1
            if odds >= 1000000000 then return "LightDark"
            elseif odds >= 250000000 then return "Titan"
            elseif odds >= 50000000 then return "Divine"
            elseif odds >= 10000000 then return "Eternal"
            elseif odds >= 2000000 then return "Secret"
            elseif odds >= 500000 then return "Cosmic"
            elseif odds >= 100000 then return "Mythic"
            elseif odds >= 20000 then return "Legendary"
            elseif odds >= 5000 then return "Epic"
            elseif odds >= 1000 then return "Rare"
            elseif odds >= 250 then return "Uncommon"
            else return "Common" end
        end
        return "Common"
    end

    local function passesFilters(record, opts)
        if opts.slotOnly ~= false and record.State ~= "Slot" then return false end
        if opts.areaId and record.AreaId ~= opts.areaId then return false end
        if opts.areaPriority then
            local found = false
            for _, a in ipairs(opts.areaPriority) do
                if record.AreaId == a then found = true break end
            end
            if not found then return false end
        end
        if opts.noParasite and record.HasParasite then return false end
        if opts.mutations then
            local hit = false
            for _, m in ipairs(opts.mutations) do
                if record.BaseMutation == m then hit = true break end
            end
            if not hit then return false end
        end
        if opts.categories then
            local hit = false
            for _, c in ipairs(opts.categories) do
                if record.AssetCategory == c then hit = true break end
            end
            if not hit then return false end
        end

        -- Rarity EXACT MATCH Check
        if opts.rarities and #opts.rarities > 0 then
            local tier = getEggRarity(record)
            local match = false
            for _, selectedTier in ipairs(opts.rarities) do
                if selectedTier == tier then
                    match = true
                    break
                end
            end
            if not match then return false end
        end

        return true
    end

    function M:Nearest(opts)
        opts = opts or {}
        local records = self:GetRecords()
        if #records == 0 then return nil end
        local me = self:GetMyPosition()
        if not me then return nil end

        local function buildResult(record, pos, dist)
            return {
                uid         = record.Uid,
                record      = record,
                position    = pos,
                distance    = dist,
                areaId      = record.AreaId,
                nestId      = record.NestId,
                category    = record.AssetCategory,
                mutation    = record.BaseMutation,
                hasParasite = record.HasParasite,
                rarity      = getEggRarity(record),
            }
        end

        -- If areaPriority is set, iterate priorities in order
        if opts.areaPriority and #opts.areaPriority > 0 then
            for _, priorityArea in ipairs(opts.areaPriority) do
                local bestR, bestD, bestPos
                for _, record in ipairs(records) do
                    if record.AreaId == priorityArea and passesFilters(record, opts) then
                        local pos = eggPosition(record)
                        if pos then
                            local d = (pos - me).Magnitude
                            if (not bestD or d < bestD)
                               and (not opts.maxDist or d <= opts.maxDist) then
                                bestR, bestD, bestPos = record, d, pos
                            end
                        end
                    end
                end
                if bestR then
                    return buildResult(bestR, bestPos, bestD)
                end
            end
            return nil
        end

        -- Single-pass: find nearest or rarest
        local bestR, bestD, bestPos
        local bestOdds = -1

        for _, record in ipairs(records) do
            if passesFilters(record, opts) then
                local pos = eggPosition(record)
                if pos then
                    local d = (pos - me).Magnitude
                    local validDist = (not opts.maxDist or d <= opts.maxDist)
                    
                    if validDist then
                        if opts.priority == "Rarest" then
                            local odds = 1
                            local dir = getDirectory()
                            if dir and dir[record.AssetCategory] then
                                odds = dir[record.AssetCategory].VisualOdds or 1
                            end
                            if odds > bestOdds then
                                bestR, bestD, bestPos, bestOdds = record, d, pos, odds
                            end
                        else
                            if (not bestD or d < bestD) then
                                bestR, bestD, bestPos = record, d, pos
                            end
                        end
                    end
                end
            end
        end

        if not bestR then return nil end
        return buildResult(bestR, bestPos, bestD)
    end

    function M:DistanceTo(uid)
        local records = self:GetRecords()
        for _, record in ipairs(records) do
            if record.Uid == uid then
                local pos = eggPosition(record)
                if not pos then return nil end
                local me = self:GetMyPosition()
                if not me then return nil end
                return (pos - me).Magnitude, pos
            end
        end
        return nil
    end

    return M
end
