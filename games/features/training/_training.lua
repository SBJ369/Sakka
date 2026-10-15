return function(lib, window, Manager, loadModule)
	local function placeholder(name)
		return function()
			lib:Notify({ Title = "Not Implemented", Content = name .. " has no game logic yet.", Duration = 3 })
		end
	end

	local ORDER_NOTE = "Select in order: first = most important, last = least important"

	local tab = window:CreateTab("Training")

	tab:AddSection("Dojo Drills")
	tab:AddToggle({ Text = "Auto Push Ups",             Default = false, Callback = placeholder("Auto Push Ups") })
	tab:AddToggle({ Text = "Auto Meditation",           Default = false, Callback = placeholder("Auto Meditation") })
	tab:AddToggle({ Text = "Auto Squats",               Default = false, Callback = placeholder("Auto Squats") })
	tab:AddToggle({ Text = "Auto Boulder Split",        Default = false, Callback = placeholder("Auto Boulder Split") })
	tab:AddToggle({ Text = "Auto Boulder Push",         Default = false, Callback = placeholder("Auto Boulder Push") })
	tab:AddToggle({ Text = "Instant Training Complete", Default = false, Callback = placeholder("Instant Training Complete") })

	tab:AddSection("Auto Skill Tree")
	tab:AddLabel("Skill Points Balance: 0")
	local autoSkill = tab:AddToggle({
		Text = "Auto Allocate Skill Points On Level Up",
		Default = false,
		Callback = placeholder("Auto Allocate Skill Points On Level Up"),
	})
	tab:AddMultiDropdown({
		Title = "Allocation Priority",
		Note = ORDER_NOTE,
		Options = {
			"Max Stamina", "Health Regen Speed", "Stamina Regen Speed",
			"Max Health", "Additional Damage", "Block Regen",
			"Block Points", "Clan Skills", "Weapon Skills",
			"BDA / Breathing Style Skills",
		},
		Default = {},
		DependsOn = autoSkill,
		Callback = placeholder("Allocation Priority"),
	})
	tab:AddButton({
		Text = "Allocate All Available Skill Points",
		Callback = placeholder("Allocate All Skill Points"),
	})
end
