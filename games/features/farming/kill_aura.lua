-- games/features/farming/kill_aura.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer

return function(ctx)
	local M = {}
	local running    = false
	local loopThread = nil

	local SignalEvent = ReplicatedStorage
		:WaitForChild("Communication")
		:WaitForChild("ServerAndClient")
		:WaitForChild("Signals")
		:WaitForChild("SignalEvent")
		:WaitForChild("Event")

	local COMBO_TIMINGS  = { 0.13, 0, 0, 0, 0.15 }
	local COMBO_DELAY    = 0.15
	local COMBO_COOLDOWN = 1.2

	local function fireCombo()
		for i = 1, 5 do
			if not running then return end
			pcall(function()
				SignalEvent:FireServer("Combat_Service", "Combat", i, false, COMBO_TIMINGS[i], false)
			end)
			task.wait(COMBO_DELAY)
		end
	end

	local function attackLoop()
		while running do
			local char = LocalPlayer.Character
			local hum  = char and char:FindFirstChildOfClass("Humanoid")

			if hum and hum.Health > 0 then
				-- check if weapon/combat is pulled out before firing
				local equippedConfig = LocalPlayer:FindFirstChild("Items_ConfigServer")
				local isPulledOut = equippedConfig
					and equippedConfig:FindFirstChild("Equipped")
					and equippedConfig.Equipped.Value == 1

				if isPulledOut then
					fireCombo()
				end
			end

			if running then
				task.wait(COMBO_COOLDOWN)
			end
		end
	end

	function M:Start()
		if running then return end
		running    = true
		loopThread = task.spawn(attackLoop)
	end

	function M:Stop()
		running = false
		if loopThread then
			pcall(function() task.cancel(loopThread) end)
			loopThread = nil
		end
	end

	return M
end
