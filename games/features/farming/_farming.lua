return function(lib, window, Manager, loadModule)
    local tab = window:CreateTab("Farming")

    -- Load core modules
    local Finder = loadModule("features/farming/field_egg_finder.lua")({ lib = lib })
    local Env    = loadModule("features/farming/environment.lua")({ lib = lib })
    
    -- Load feature modules
    local AutoEquip = loadModule("features/farming/auto_equip.lua")({ lib = lib })

    local options = {
        fields           = {},
        allowedMutations = {},
        rarities         = {},
        priority         = "Nearest",
        isBusy           = false, -- Used for Hierarchy Lock
    }

    local Carry = loadModule("features/farming/carry_loop.lua")({
        lib = lib,
        Finder = Finder,
        options = options,
    })

    local AutoPlace = loadModule("features/farming/auto_place.lua")({ 
        lib = lib, 
        Env = Env, 
        options = options 
    })

    -- Background Treadmill Escape (Checks every 1s)
    task.spawn(function()
        while true do
            task.wait(1)
            local trainToggleOn = Manager.features["auto_train"] and Manager.features["auto_train"].enabled
            local char = game.Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            
            if hrp and hum and not trainToggleOn then
                -- Check if we are standing on a treadmill part
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = { char }
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                local result = workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), rayParams)
                
                if result and result.Instance and (result.Instance.Name:lower():find("tread") or result.Instance.Name:lower():find("belt")) then
                    -- We are on a treadmill, but auto train is off. Jump!
                    hum.Jump = true
                end
            end
        end
    end)

    -- ==========================================
    -- SECTION: Auto Egg
    -- ==========================================
    tab:AddSection("Auto Egg")

    local eggToggle = tab:AddToggle({
        Text = "Auto Get Egg",
        Default = false,
        Note = "Select at least one field below. Loop waits until you do.",
        Callback = function(on)
            if Manager._suppress then return end
            Manager.Toggle("auto_get_egg", on)
        end,
    })

    local AREAS = {
        { label = "Forest",             value = "Forest" },
        { label = "Lake",               value = "Lake" },
        { label = "Desert",             value = "Desert" },
        { label = "Jungle",             value = "Jungle" },
        { label = "Snow",               value = "Snow" },
        { label = "Volcano",            value = "Volcano" },
        { label = "Abyss Ocean",        value = "Abyss Ocean" },
        { label = "Prehistoric",        value = "Prehistoric" },
        { label = "Cosmic",             value = "Cosmic" },
        { label = "Cherry Blossom",     value = "Cherry Blossom" },
        { label = "Titan Temple",       value = "Titan Temple" },
        { label = "Angels And Demons",  value = "Light Dark" },
        { label = "Enchanted Forest",   value = "Enchanted Forest" },
        { label = "Alien Planet",       value = "Alien" },
    }

    local labels = {}
    for _, entry in ipairs(AREAS) do
        table.insert(labels, entry.label)
    end

    tab:AddMultiDropdown({
        Title = "Fields (select in priority order)",
        Note = "First = most important, last = least important.",
        Options = labels,
        Default = {},
        DependsOn = eggToggle,
        Callback = function(selected)
            local mapped = {}
            if type(selected) == "table" then
                for _, label in ipairs(selected) do
                    for _, entry in ipairs(AREAS) do
                        if entry.label == label then
                            table.insert(mapped, entry.value)
                            break
                        end
                    end
                end
            end
            options.fields = mapped
        end,
    })

    tab:AddDropdown({
        Text = "Egg Priority",
        Options = { "Nearest", "Rarest" },
        Default = "Nearest",
        DependsOn = eggToggle,
        Note = "Rarest = hunts for the highest odds egg in the selected field.",
        Callback = function(option)
            options.priority = option
        end,
    })

    tab:AddMultiDropdown({
        Title = "Rarities",
        Note = "Leave empty to allow any rarity. If set, ONLY these tiers will be picked.",
        Options = { 
            "Common", "Uncommon", "Rare", "Epic", "Legendary", 
            "Mythic", "Cosmic", "Secret", "Eternal", "Divine" 
        },
        Default = {},
        DependsOn = eggToggle,
        Callback = function(selected)
            options.rarities = type(selected) == "table" and selected or {}
        end,
    })

    tab:AddMultiDropdown({
        Title = "Only These Mutations",
        Note = "Leave empty to allow any egg. If set, ONLY eggs with these mutations will be picked up.",
        Options = { "Silver", "Golden" },
        Default = {},
        DependsOn = eggToggle,
        Callback = function(selected)
            options.allowedMutations = type(selected) == "table" and selected or {}
        end,
    })

    local hatchToggle = tab:AddToggle({
        Text = "Auto Hatch Eggs",
        Default = false,
        Note = "Automatically opens eggs from the Growing Eggs menu when they are ready.",
        Callback = function(on)
            if Manager._suppress then return end
            Manager.Toggle("auto_hatch", on)
        end,
    })

    local placeToggle = tab:AddToggle({
        Text = "Auto Place Eggs",
        Default = false,
        Note = "Automatically walks to your plot and places unplaced eggs when idle.",
        Callback = function(on)
            if Manager._suppress then return end
            Manager.Toggle("auto_place_eggs", on)
        end,
    })

    -- ==========================================
    -- SECTION: Pets
    -- ==========================================
    tab:AddSection("Pets")

    local equipToggle = tab:AddToggle({
        Text = "Auto Equip Best Pets",
        Default = false,
        Note = "Calls the server remote to equip best pets every 5 seconds.",
        Callback = function(on)
            if Manager._suppress then return end
            Manager.Toggle("auto_equip_best", on)
        end,
    })

    tab:AddButton({
        Text = "Sell All Pets",
        Callback = function()
            local ok, Remotes = pcall(require, game.ReplicatedStorage.Shared.Remotes)
            if ok and Remotes then
                Remotes.PetSatchel.SellEveryPet:FireServer()
                lib:Notify({ Title = "Auto Sell", Content = "Triggered Sell All Pets.", Duration = 3 })
            else
                lib:Notify({ Title = "Error", Content = "Failed to load Remotes.", Duration = 3 })
            end
        end,
    })

    -- ==========================================
    -- SECTION: Speed
    -- ==========================================
    tab:AddSection("Speed")

    local AutoTrain = loadModule("features/farming/auto_train.lua")({ lib = lib, Env = Env })

    local trainToggle = tab:AddToggle({
        Text = "Auto Train (Treadmill)",
        Default = false,
        Note = "Walks to your treadmill and stands on it. Jumps off when disabled.",
        Callback = function(on)
            if Manager._suppress then return end
            Manager.Toggle("auto_train", on)
        end,
    })

    -- ==========================================
    -- MANAGER REGISTRATION
    -- ==========================================

    Manager.Register("auto_get_egg", {
        toggle    = eggToggle,
        onEnable  = function() Carry:Start() end,
        onDisable = function() Carry:Stop() end,
    })

    Manager.Register("auto_hatch", {
        toggle    = hatchToggle,
        onEnable  = function() loadModule("features/farming/auto_hatch.lua")({ lib = lib }):Start() end,
        onDisable = function() loadModule("features/farming/auto_hatch.lua")({ lib = lib }):Stop() end,
    })

    Manager.Register("auto_place_eggs", {
        toggle    = placeToggle,
        onEnable  = function() AutoPlace:Start() end,
        onDisable = function() AutoPlace:Stop() end,
    })

    Manager.Register("auto_equip_best", {
        toggle    = equipToggle,
        onEnable  = function() AutoEquip:Start() end,
        onDisable = function() AutoEquip:Stop() end,
    })

    Manager.Register("auto_train", {
        toggle    = trainToggle,
        onEnable  = function() AutoTrain:Start() end,
        onDisable = function() AutoTrain:Stop() end,
    })
end
