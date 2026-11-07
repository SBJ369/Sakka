return function(lib, window, Manager, loadModule)
    local tab = window:CreateTab("Farming")

    -- Load the modules
    local Finder = loadModule("features/eggs/field_egg_finder.lua")({ lib = lib })
    local Env    = loadModule("features/eggs/environment.lua")({ lib = lib })
    local EnvTest = loadModule("features/eggs/env_test.lua")({ lib = lib, Env = Env })

    local options = {
        fields           = {},
        allowedMutations = {},
        rarities         = {},
        priority         = "Nearest",
    }

    local Carry = loadModule("features/eggs/carry_loop.lua")({
        lib = lib,
        Finder = Finder,
        options = options,
    })

    tab:AddSection("Environment Test")
    
    tab:AddButton({
        Text = "Go to Fuse Machine",
        Callback = function() EnvTest:WalkToFuse() end,
    })
    
    tab:AddButton({
        Text = "Go to Trail Shop",
        Callback = function() EnvTest:WalkToShop() end,
    })
    
    tab:AddButton({
        Text = "Go to Sell Stand",
        Callback = function() EnvTest:WalkToSell() end,
    })
    
    tab:AddButton({
        Text = "Go to My Treadmill",
        Callback = function() EnvTest:WalkToTreadmill() end,
    })
    
    tab:AddButton({
        Text = "Go to My Plot Center",
        Callback = function() EnvTest:WalkToPlot() end,
    })
    
    tab:AddButton({
        Text = "Stop Walking",
        Callback = function() EnvTest:Stop() end,
    })

    tab:AddButton({
        Text = "Go to My Plot Upgrade",
        Callback = function() EnvTest:WalkToUpgrade() end,
    })

    tab:AddSection("Auto Egg")

    local masterToggle = tab:AddToggle({
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
        DependsOn = masterToggle,
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
            warn("[_eggs] fields updated: " .. (#mapped == 0 and "(none)" or table.concat(mapped, ", ")))
        end,
    })

    tab:AddMultiDropdown({
        Title = "Rarities",
        Note = "Select a rarity to only pick eggs of this rarity or higher.",
        Options = { 
            "Common", 
            "Uncommon", 
            "Rare", 
            "Epic", 
            "Legendary", 
            "Mythic", 
            "Cosmic", 
            "Secret", 
            "Eternal", 
            "Divine" 
        },
        Default = {},
        DependsOn = masterToggle,
        Callback = function(selected)
            options.rarities = type(selected) == "table" and selected or {}
        end,
    })

    tab:AddMultiDropdown({
        Title = "Only These Mutations",
        Note = "Leave empty to allow any egg.",
        Options = { "Silver", "Golden" },
        Default = {},
        DependsOn = masterToggle,
        Callback = function(selected)
            options.allowedMutations = type(selected) == "table" and selected or {}
            warn("[_eggs] mutations updated: " .. (#options.allowedMutations == 0 and "(any)" or table.concat(options.allowedMutations, ", ")))
        end,
    })

    tab:AddSection("Status")
    tab:AddLabel("Console shows live [autoegg] log lines.")

    Manager.Register("auto_get_egg", {
        toggle    = masterToggle,
        onEnable  = function() Carry:Start() end,
        onDisable = function() Carry:Stop() end,
    })
end
