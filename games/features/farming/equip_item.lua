local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer

return function(ctx)
	local lib = ctx.lib
	local M = {}

	local SignalEvent = ReplicatedStorage
		:WaitForChild("Communication")
		:WaitForChild("ServerAndClient")
		:WaitForChild("Signals")
		:WaitForChild("SignalEvent")
		:WaitForChild("Event")

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


	local function buildWeaponList()
		local list = {}

		local ok, inv = pcall(getInventoryFolder)
		if not ok or not inv then
			return { { name = "Simple Combat", index = 1 } }
		end

		for _, child in ipairs(inv:GetChildren()) do
			local indexValue = child:FindFirstChildOfClass("Id")
			if indexValue then
				local displayName = (child.Name == "Combat") and "Simple Combat" or child.Name
				table.insert(list, { name = displayName, index = indexValue.Value })
			end
		end

		return list
	end
	
	-- Returns just the names for the dropdown
	function M:GetWeaponList()
		local list = buildWeaponList()
		local names = {}
		for _, entry in ipairs(list) do
			table.insert(names, entry.name)
		end
		return names
	end

	-- Returns the inventory index for a given display name
	local function getIndex(name)
		local list = buildWeaponList()
		for _, entry in ipairs(list) do
			if entry.name == name then return entry.index end
		end
		return nil
	end

	-- Returns the currently active hotbar slot number (1-5) based on Items_ConfigServer
	-- Equipped.Value holds the slot number that is pulled out, 0 = nothing pulled out
	local function getPulledOutSlot()
		local config = LocalPlayer:FindFirstChild("Items_ConfigServer")
		if not config then return 0 end
		local eq = config:FindFirstChild("Equipped")
		return eq and eq.Value or 0
	end

	local SLOT_TO_NUMBER = { One = 1, Two = 2, Three = 3, Four = 4, Five = 5 }

	function M:Equip(name, slotName)
		local idx = getIndex(name)
		if not idx then
			lib:Notify({ Title = "Equip Weapon", Content = "Not found in inventory: " .. tostring(name), Duration = 3 })
			return
		end

		slotName = slotName or "One"
		local slotNumber = SLOT_TO_NUMBER[slotName] or 1

		-- If something is currently pulled out, put it away first
		local pulledSlot = getPulledOutSlot()
		if pulledSlot ~= 0 then
			pcall(function() SignalEvent:FireServer("Item_Equip", 0) end)
			task.wait(0.15)
		end

		-- Slot the item into the hotbar slot (0 first to clear, then the real index)
		pcall(function() SignalEvent:FireServer("Toolbar_Equip", slotName, 0) end)
		task.wait(0.1)
		pcall(function() SignalEvent:FireServer("Toolbar_Equip", slotName, idx) end)
		task.wait(0.15)

		-- Pull it out from the correct slot number
		pcall(function() SignalEvent:FireServer("Item_Equip", slotNumber) end)
	end

	return M
end
