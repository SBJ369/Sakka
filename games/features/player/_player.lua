return function(lib, window, Manager, loadModule)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local LocalPlayer = Players.LocalPlayer

	local tab = window:CreateTab("Player")

	local pstate = {
		speed = 16,
		jumpPower = 50,
		jumpEnabled = false,
		noclip = false,
	}
	local noclipConn = nil

	local function getHumanoid()
		local char = LocalPlayer.Character
		return char and char:FindFirstChildOfClass("Humanoid") or nil
	end

	local function applyJump()
		local hum = getHumanoid()
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = pstate.jumpEnabled and pstate.jumpPower or 50
		end
	end

	local function applyNoclip()
		local char = LocalPlayer.Character
		if not char then return end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = not pstate.noclip
			end
		end
	end

	local function refreshMovement()
		local hum = getHumanoid()
		if hum then hum.WalkSpeed = pstate.speed end
		applyJump()
		applyNoclip()
	end

	local function setNoclip(on)
		pstate.noclip = on
		if on then
			applyNoclip()
			if noclipConn then noclipConn:Disconnect() end
			noclipConn = RunService.Stepped:Connect(applyNoclip)
		else
			if noclipConn then noclipConn:Disconnect() noclipConn = nil end
			applyNoclip()
		end
	end

	LocalPlayer.CharacterAdded:Connect(function()
		task.wait(1)
		refreshMovement()
	end)

	tab:AddSection("Movement")
	tab:AddToggle({
		Text = "Noclip",
		Default = false,
		Callback = function(on) setNoclip(on) end,
	})
	local highJump = tab:AddToggle({
		Text = "High Jump",
		Default = false,
		Callback = function(on) pstate.jumpEnabled = on; applyJump() end,
	})
	tab:AddSlider({
		Text = "High Jump Height",
		Min = 50, Max = 500, Default = 100, Suffix = " studs",
		DependsOn = highJump,
		Callback = function(v) pstate.jumpPower = v; applyJump() end,
	})
	tab:AddSlider({
		Text = "Unlimited FOV",
		Min = 70, Max = 200, Default = 70,
		Callback = function(v)
			if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = v end
		end,
	})
	tab:AddSlider({
		Text = "Movement Speed",
		Min = 16, Max = 500, Default = 16,
		Callback = function(v)
			pstate.speed = v
			local hum = getHumanoid()
			if hum then hum.WalkSpeed = v end
		end,
	})
end
