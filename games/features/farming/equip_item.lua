local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

return function(ctx)
	local lib = ctx.lib
	local M = {}

	local SignalEvent = ReplicatedStorage
		:WaitForChild("Communication")
		:WaitForChild("ServerAndClient")
		:WaitForChild("Signals")
		:WaitForChild("SignalEvent")
		:WaitForChild("Event")

	local SLOT_NAMES = { "One", "Two", "Three", "Four", "Five" }

	-- build whitelist from game's own item registry
	local function buildWhitelist()
		local whitelist = {}
		local weaponCategories = { "Katana", "Weapons", "Style" }
		for _, cat in ipairs(weaponCategories) do
			local folder = ReplicatedStorage.Items:FindFirstChild(cat)
			if folder then
				for _, item in ipairs(folder:GetDescendants()) do
					whitelist[item.Name] = true
				end
			end
		end
		-- from Misc, only Clan Skills counts — Crow is not a weapon
		local misc = ReplicatedStorage.Items:FindFirstChild("Misc")
		if misc then
			local clan = misc:FindFirstChild("Clan Skills")
			if clan then whitelist["Clan Skills"] = true end
		end
		return whitelist
	end

	local function getInventoryFolder()
		return ReplicatedStorage
			:WaitForChild("Player_Service")
			:WaitForChild("Data")
			:WaitForChild(LocalPlayer.Name)
			:WaitForChild("slots")
			:WaitForChild("Slot1")
			:WaitForChild("Inventory")
			:WaitForChild("Inventory")
	end

	-- returns ordered list: Simple Combat always first, then inventory weapons in order
	local function getWeaponList()
		local list = { "Simple Combat" }
		local whitelist = buildWhitelist()
		local ok, inv = pcall(getInventoryFolder)
		if ok and inv then
			for _, child in ipairs(inv:GetChildren()) do
				if whitelist[child.Name] then
					table.insert(list, child.Name)
				end
			end
		end
		return list
	end

	-- index in the combined list = what the server expects as 3rd arg
	local function getWeaponIndex(name, list)
		for i, n in ipairs(list) do
			if n == name then return i end
		end
		return nil
	end

	function M:GetWeaponList()
		return getWeaponList()
	end

	function M:Equip(name, slotName)
		local list = getWeaponList()
		local idx = getWeaponIndex(name, list)
		if not idx then
			lib:Notify({ Title = "Equip Weapon", Content = "Not found: " .. name, Duration = 3 })
			return
		end

		slotName = slotName or "One"

		-- put back if something is currently pulled out
		local ok, equippedConfig = pcall(function()
			return LocalPlayer
				:WaitForChild("Items_ConfigServer")
				:WaitForChild("Equipped")
		end)
		if ok and equippedConfig and equippedConfig.Value == 1 then
			pcall(function() SignalEvent:FireServer("Item_Equip", 0) end)
			task.wait(0.1)
		end

		-- slot into selected hotbar slot
		pcall(function() SignalEvent:FireServer("Toolbar_Equip", slotName, idx) end)
		task.wait(0.1)

		-- pull it out
		pcall(function() SignalEvent:FireServer("Item_Equip", 1) end)
	end

	return M
end
