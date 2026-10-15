local currentPlaceId = game.PlaceId


local baseUrl = "https://raw.githubusercontent.com/SBJ369/Sakka/main/"

local targetScript = "games/universal.lua"

print("Sakka Hub: Loading script for PlaceId: " .. tostring(currentPlaceId))

local success, err = pcall(function()
    loadstring(game:HttpGet(baseUrl .. targetScript))()
end)

if not success then
    warn("Sakka Hub Failed to Load: " .. tostring(err))
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Sakka Hub Error",
        Text = "Failed to load from GitHub. Check console (F9).",
        Duration = 5
    })
end
