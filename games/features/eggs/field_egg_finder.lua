-- games/features/eggs/field_egg_finder.lua
-- Read-only field egg discovery. Never fires a remote.
-- Records come from Remotes.EggWorld.AskFieldEggSnapshot.
-- All positions are derived from record.BottomCFrame + half of BoundsSize.Y.

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

    -- opts (all optional):
    --   areaId       string   -- exact match, e.g. "Forest"
    --   maxDist      number
    --   noParasite   boolean
    --   mutations    {string} -- matches BaseMutation; nil-mutation eggs are skipped
    --   categories   {string} -- matches AssetCategory
    --   slotOnly     boolean  -- default true; requires State == "Slot"
    function M:Nearest(opts)
        opts = opts or {}
        local slotOnly = opts.slotOnly ~= false
        local records = self:GetRecords()
        if #records == 0 then return nil end
        local me = self:GetMyPosition()
        if not me then return nil end

        local best, bestDist, bestPos
        for _, record in ipairs(records) do
            local ok = true
            if slotOnly and record.State ~= "Slot" then ok = false end
            if ok and opts.areaId and record.AreaId ~= opts.areaId then ok = false end
            if ok and opts.noParasite and record.HasParasite then ok = false end
            if ok and opts.mutations then
                local hit = false
                for _, m in ipairs(opts.mutations) do
                    if record.BaseMutation == m then hit = true break end
                end
                if not hit then ok = false end
            end
            if ok and opts.categories then
                local hit = false
                for _, c in ipairs(opts.categories) do
                    if record.AssetCategory == c then hit = true break end
                end
                if not hit then ok = false end
            end

            if ok then
                local pos = eggPosition(record)
                if pos then
                    local d = (pos - me).Magnitude
                    if (not bestDist or d < bestDist) and (not opts.maxDist or d <= opts.maxDist) then
                        best, bestDist, bestPos = record, d, pos
                    end
                end
            end
        end

        if not best then return nil end
        return {
            uid         = best.Uid,
            record      = best,
            position    = bestPos,
            distance    = bestDist,
            areaId      = best.AreaId,
            nestId      = best.NestId,
            category    = best.AssetCategory,
            mutation    = best.BaseMutation,   -- may be nil
            hasParasite = best.HasParasite,
        }
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
