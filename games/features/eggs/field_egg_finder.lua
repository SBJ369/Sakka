-- games/features/eggs/field_egg_finder.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

return function(ctx)
    local M = {}
    local Remotes
    local LocalPlayer = Players.LocalPlayer

    local function getRemotes()
        if Remotes then return Remotes end
        local ok, r = pcall(require, ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
        if ok and r then Remotes = r end
        return Remotes
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
            }
        end

        -- if areaPriority is set, iterate priorities in order and return
        -- the nearest matching egg from the first priority that has any
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

        -- single-pass nearest
        local bestR, bestD, bestPos
        for _, record in ipairs(records) do
            if passesFilters(record, opts) then
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
