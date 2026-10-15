return function(lib, window, Manager, loadModule)
	local function placeholder(name)
		return function()
			lib:Notify({ Title = "Not Implemented", Content = name .. " has no game logic yet.", Duration = 3 })
		end
	end

	local ORDER_NOTE = "Select in order: first = most important, last = least important"

	local tab = window:CreateTab("Dungeon")

	tab:AddSection("Cards")
	tab:AddToggle({
		Text = "Auto Pick Card",
		Default = false,
		Callback = placeholder("Auto Pick Card"),
	})
	tab:AddMultiDropdown({
		Title = "Cards Not To Pick",
		Note = ORDER_NOTE,
		Options = { "-- add card options here --" },
		Default = {},
		Callback = placeholder("Cards Not To Pick"),
	})
	tab:AddMultiDropdown({
		Title = "Cards Always To Pick",
		Note = ORDER_NOTE,
		Options = { "-- add card options here --" },
		Default = {},
		Callback = placeholder("Cards Always To Pick"),
	})
	tab:AddMultiDropdown({
		Title = "Stat Card Priority",
		Note = ORDER_NOTE,
		Options = {
			"Damage", "HP", "Cooldown Reduction", "Block Points",
			"Stamina Regen", "Damage Reduction",
		},
		Default = {},
		Callback = placeholder("Stat Card Priority"),
	})

	tab:AddSection("Action")
	tab:AddToggle({
		Text = "Auto Start Dungeon",
		Default = false,
		Callback = placeholder("Auto Start Dungeon"),
	})
	tab:AddToggle({
		Text = "Auto Repeat Dungeon",
		Default = false,
		Callback = placeholder("Auto Repeat Dungeon"),
	})
	tab:AddTextInput({
		Text = "Auto End Dungeon At Floor",
		Placeholder = "e.g. 10",
		Callback = placeholder("Auto End Dungeon At Floor"),
	})

	tab:AddSection("Loot")
	local function exchangePair(title, label)
		local t = tab:AddToggle({
			Text = title,
			Default = false,
			Callback = placeholder(title),
		})
		tab:AddTextInput({
			Text = label .. " - How Many Times",
			Placeholder = "e.g. 10",
			DependsOn = t,
			Callback = placeholder(label .. " - How Many Times"),
		})
		return t
	end

	exchangePair("Auto Open Dungeon Chest", "Open Chest")
	exchangePair("Auto Exchange Wen", "Wen")
	exchangePair("Auto Exchange Mythic Ore", "Mythic Ore")
	exchangePair("Auto Exchange Refinement Ore", "Refinement Ore")
	exchangePair("Auto Exchange EXP", "EXP")
end
