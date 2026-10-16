local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer

return function(ctx)
	local state = ctx.state
	local M = {}
	local conn
	local running = false
	local loopThread = nil

	local SignalEvent = ReplicatedStorage
		:WaitForChild("Communication")
		:WaitForChild("ServerAndClient")
		:WaitForChild("Signals")
		:WaitForChild("SignalEvent")
		:WaitForChild("Event")

	local COMBO_TIMINGS = { 0.13, 0, 0, 0, 0.15 }
	local COMBO_DELAY   = 0.15
	local COMBO_COOLDOWN = 1.2 

	local function getRegionFolders()
		local regions = workspace.Humanoids.Regions
		local folders = {}
		for _, region in ipairs(regions:GetChildren()) do
			local active = region:FindFirstChild("ActiveNpcs")
			if active then
				table.insert(folders, active)
			end
		end
		return folders
	end

	local function getClosestInRange(myHRP, radius)
		local closest = nil
		local shortestDist = radius

		for _, activeNpcs in ipairs(getRegionFolders()) do
			for _, container in ipairs(activeNpcs:GetChildren()) do
				local humanoid = container:FindFirstChildOfClass("Humanoid")
				if not humanoid then
					for _, child in ipairs(container:GetChildren()) do
						humanoid = child:FindFirstChildOfClass("Humanoid")
						if humanoid then break end
					end
				end

				if humanoid and humanoid.Health > 0 then
					local hrp = humanoid.Parent:FindFirstChild("HumanoidRootPart")
					if hrp then
						local dist = (hrp.Position - myHRP.Position).Magnitude
						if dist < shortestDist then
							shortestDist = dist
							closest = hrp
						end
					end
				end
			end
		end

		return closest
	end


	local function fireCombo()
		for i = 1, 5 do
			if not running then return end
			pcall(function()
				SignalEvent:FireServer("Combat_Service", "Combat", i, false, COMBO_TIMINGS[i], false)
			end)
			task.wait(COMBO_DELAY)
		end
	end

	local function auraLoop()
		while running do
			local char  = LocalPlayer.Character
			local myHRP = char and char:FindFirstChild("HumanoidRootPart")
			local radius = state.killAuraRadius or 0

			if myHRP and radius > 0 then
				local targetHRP = getClosestInRange(myHRP, radius)
				if targetHRP then
					local origin = myHRP.CFrame
					local offset = (myHRP.Position - targetHRP.Position).Unit * 4
					myHRP.CFrame = targetHRP.CFrame + offset

					fireCombo()

					if running then
						myHRP.CFrame = origin
					end
				end
			end

			if running then
				task.wait(COMBO_COOLDOWN)
			end
		end
	end

	function M:Start()
		if running then return end
		running = true
		loopThread = task.spawn(auraLoop)
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
