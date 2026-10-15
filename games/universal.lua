local SakkaUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/SBJ369/SakkaUI-library/refs/heads/main/SakkaUI.lua"))()

--== services ==--
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer

local lib = SakkaUI.new()

--== helpers ==--
local function executorName()
	local ok, name = pcall(function()
		if identifyexecutor then return identifyexecutor() end
	end)
	if ok and name then return tostring(name) end
	return "Unknown"
end

local function deviceName()
	local touch = UserInputService.TouchEnabled
	local mouse = UserInputService.MouseEnabled
	if touch and mouse then return "PC (Touch)" end
	if touch then return "Mobile" end
	if mouse then return "PC" end
	return "Unknown"
end

local execCount = 1
pcall(function()
	getgenv().SakkaExecutions = (getgenv().SakkaExecutions or 0) + 1
	execCount = getgenv().SakkaExecutions
end)

--== window ==--
local window = lib:CreateWindow({
	Title = "Sakka",
	Font = Enum.Font.PermanentMarker,
	TextSize = 24,
	-- KeySystem = true, Key = "SAKKA-2026", KeyLink = "https://...",
})

window:LoadLocalAvatar()
window:SetCharacterInfo({
	Client = executorName(),
	KeyType = "Free",
	TimeLeft = deviceName(),
	Executions = execCount,
})

--== module loader ==--
local BASE = "https://raw.githubusercontent.com/SBJ369/Sakka/refs/heads/main/games/"
local moduleCache = {}

local function loadModule(path)
	if moduleCache[path] then return moduleCache[path] end
	local ok, src = pcall(function() return game:HttpGet(BASE .. path) end)
	if not ok or type(src) ~= "string" then
		lib:Notify({ Title = "Load Error", Content = path .. ": fetch failed", Duration = 6 })
		return nil
	end
	local fn, err = loadstring(src)
	if not fn then
		lib:Notify({ Title = "Load Error", Content = path .. ": " .. tostring(err), Duration = 6 })
		return nil
	end
	local ok2, result = pcall(fn)
	if not ok2 then
		lib:Notify({ Title = "Load Error", Content = path .. ": " .. tostring(result), Duration = 6 })
		return nil
	end
	moduleCache[path] = result
	return result
end

local Manager = loadModule("shared/manager.lua")

--== tabs ==--
local tabs = {
	"features/information/_information.lua",
	"features/farming/_farming.lua",
	"features/dungeon/_dungeon.lua",
	"features/player/_player.lua",
	"features/training/_training.lua",
}
for _, path in ipairs(tabs) do
	local mod = loadModule(path)
	if mod then
		local ok, err = pcall(mod, lib, window, Manager, loadModule)
		if not ok then
			lib:Notify({ Title = "Tab Error", Content = path .. ": " .. tostring(err), Duration = 6 })
		end
	end
end

lib:Notify({ Title = "Sakka Hub", Content = "Loaded. Press RightControl to toggle.", Duration = 4 })
