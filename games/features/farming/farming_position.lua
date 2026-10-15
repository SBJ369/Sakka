local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return function(ctx)
	local state = ctx.state
	local M = {}
	local conn

	local targetFolders = {
		Bandit                      = workspace.Humanoids.Regions["Windy Peak"].ActiveNpcs,
		Zuko                        = workspace.Humanoids.Regions["Windy Peak"].ActiveNpcs,
		["Mother Bear"]             = workspace.Humanoids.Regions["Bamboo Grove"].ActiveNpcs,
		Kaiden                      = workspace.Humanoids.Regions["Bamboo Grove"].ActiveNpcs,
		Fujiko                      = workspace.Humanoids.Regions["Final Selection Plains"].ActiveNpcs,
		
		["Grove Raider"]            = workspace.Humanoids.Regions.Temporary.ActiveNpcs,
		["Raid Captain"]            = workspace.Humanoids.Regions.Temporary.ActiveNpcs,
		Yeti                        = { folder = workspace.Humanoids.Regions.Temporary.ActiveNpcs, modelName = "Yeti Demon" },
		
		Obari                       = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Zentaro                     = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Sumari                      = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Yahari                      = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Giyen                       = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Reaper                      = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		["Reaper Trainee Kuzan"]    = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Datai                       = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Gyutai                      = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Saneri                      = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Shinora                     = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Rengu                       = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Nezura                      = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Gyorei                      = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Tengai                      = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Domae                       = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Akazo                       = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		Enru                        = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		["Water Trainee Sabito"]    = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		["Serpent Trainee"]         = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		["Insect Trainee"]          = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		["Flame Trainee"]           = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		["Soryu Trainee Goki"]      = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		["Sound Trainee"]           = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		["Stone Trainee"]           = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		["Tai Chi Trainee Suzume"]  = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		["Thunder Trainee"]         = workspace.Humanoids.Regions.Misc.ActiveNpcs,
		["Wind Trainee"]            = workspace.Humanoids.Regions.Misc.ActiveNpcs,
	}

	-- Prioritized Searcher: checks targets in selected order
	local function getTargetHRP()
		local targets = state.targetList or (state.currentTargetName and { state.currentTargetName }) or {}
		if #targets == 0 then return nil end

		local char = LocalPlayer.Character
		local myHRP = char and char:FindFirstChild("HumanoidRootPart")
		if not myHRP then return nil end

		-- Loop through selected targets in order of priority (first = highest priority)
		for _, targetName in ipairs(targets) do
			local targetData = targetFolders[targetName]
			if targetData then
				local parentFolder = type(targetData) == "table" and targetData.folder or targetData
				local actualModelName = type(targetData) == "table" and targetData.modelName or targetName

				if parentFolder then
					local closestHRP = nil
					local shortestDist = math.huge

					for _, child in ipairs(parentFolder:GetChildren()) do
						if child.Name == actualModelName or child.Name == targetName then
							local model = child:FindFirstChild(actualModelName) or child:FindFirstChild(targetName) or child
							local humanoid = model and model:FindFirstChildOfClass("Humanoid")
							local hrp = model and model:FindFirstChild("HumanoidRootPart")

							-- Check that the NPC exists and is alive
							if hrp and (not humanoid or humanoid.Health > 0) then
								local dist = (hrp.Position - myHRP.Position).Magnitude
								if dist < shortestDist then
									shortestDist = dist
									closestHRP = hrp
								end
							end
						end
					end

					-- If we found a living target for this priority level, return it immediately!
					if closestHRP then
						return closestHRP
					end
				end
			end
		end

		return nil
	end

	function M:Start()
		if conn then return end

		conn = RunService.Heartbeat:Connect(function()
			local char = LocalPlayer.Character
			local myHRP = char and char:FindFirstChild("HumanoidRootPart")
			if not myHRP then return end

			local targetHRP = getTargetHRP()
			if not targetHRP then return end

			local dist = state.distance or 10
			local verticalOffset = (state.position == "Below") and -dist or dist

			local hoverPosition = targetHRP.Position + Vector3.new(0, verticalOffset, 0)
			local targetPosition = targetHRP.Position

			myHRP.CFrame = CFrame.lookAt(hoverPosition, targetPosition)
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
