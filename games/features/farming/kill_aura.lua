local RunService    = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players       = game:GetService("Players")
local LocalPlayer   = Players.LocalPlayer

return function(ctx)
	local state = ctx.state
	local M = {}
	local conn

	local SignalEvent = ReplicatedStorage
		:WaitForChild("Communication")
		:WaitForChild("ServerAndClient")
		:WaitForChild("Signals")
		:WaitForChild("SignalEvent")
		:WaitForChild("Event")

	local function getRegionFolders()
		local regions = workspace.Humanoids.Regions
		local folders = {}
		for _, region in ipairs(regions:GetChildren()) do
			local active = region:FindFirstChild("ActiveNpcs")
			if active then
				table.insert(folders, active)
			end
		end
		local temp = regions:FindFirstChild("Temporary")
		if temp then
			local active = temp:FindFirstChild("ActiveNpcs")
			if active and not table.find(folders, active) then
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
					or (container:FindFirstChildWhichIsA("Model") 
						and container:FindFirstChildWhichIsA("Model"):FindFirstChildOfClass("Humanoid"))
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
							closest = humanoid
						end
					end
				end
			end
		end

		return closest
	end

	local function fireCombo()
		local timings = { 0.13, 0, 0, 0, 0.15 }
		for i = 1, 5 do
			pcall(function()
				SignalEvent:FireServer("Combat_Service", "Combat", i, false, timings[i], false)
			end)
			task.wait(0.15)
		end
	end

	function M:Start()
		if conn then return end

		conn = RunService.Heartbeat:Connect(function()
			local char = LocalPlayer.Character
			local myHRP = char and char:FindFirstChild("HumanoidRootPart")
			if not myHRP then return end

			local radius = state.killAuraRadius or 0
			if radius <= 0 then return end

			local target = getClosestInRange(myHRP, radius)
			if target then
				task.spawn(fireCombo)
			end
		end)
	end

	function M:Stop()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end

	return M
end
