return function(lib, window, Manager, loadModule)
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	local tab = window:CreateTab("Information")
	window:BuildProfileCard(tab.LeftColumn)

	tab:AddSection("Info", "Right")
	tab:AddLabel("Greetings, " .. LocalPlayer.DisplayName .. "!")
	tab:AddButton({
		Text = "Discord",
		Callback = function()
			lib:Notify({ Title = "Discord", Content = "Link coming soon.", Duration = 3 })
		end,
	})
end
