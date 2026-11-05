return function(lib, window, Manager, loadModule)
    local tab = window:CreateTab("Farming")

    local Finder = loadModule("features/eggs/field_egg_finder.lua")({ lib = lib })

    local options = {
        fieldFilter     = "Any",
        skipParasite    = false,
        allowedMutations = {},
    }

    local Carry = loadModule("features/eggs/carry_loop.lua")({
        lib = lib,
        Finder = Finder,
        options = options,
    })

    tab:AddSection("Auto Egg")

    local masterToggle = tab:AddToggle({
        Text = "Auto Get Egg",
        Default = false,
        Note = "Walks to nearest egg, carries it back to pen. No speed or teleport.",
        Callback = function(on)
            if Manager._suppress then return end
            Manager.Toggle("auto_get_egg", on)
        end,
    })

    local AREAS = {
        "Any",
        "Forest", "Lake", "Snow", "Volcano", "Jungle",
        "Desert", "Prehistoric", "Cosmic", "Cherry Blossom",
        "Abyss Ocean", "Titan Temple", "Light Dark", "Enchanted Forest",
    }

    tab:AddDropdown({
        Text = "Field Filter",
        Options = AREAS,
        Default = "Any",
        DependsOn = masterToggle,
        Note = "Only pick eggs from this field. Any = closest everywhere.",
        Callback = function(option)
            options.fieldFilter = option
        end,
    })

    tab:AddDropdown({
        Text = "Egg Priority",
        Options = { "Nearest" },
        Default = "Nearest",
        DependsOn = masterToggle,
        Note = "Rarest / Highest Value coming later.",
        Callback = function(_) end,
    })

    tab:AddToggle({
        Text = "Skip Parasite Eggs",
        Default = false,
        DependsOn = masterToggle,
        Callback = function(on)
            options.skipParasite = on
        end,
    })

    tab:AddMultiDropdown({
        Title = "Only These Mutations",
        Note = "Leave empty to allow any. Non-mutated eggs are always allowed.",
        Options = { "Silver", "Golden" },
        Default = {},
        DependsOn = masterToggle,
        Callback = function(selected)
            options.allowedMutations = selected or {}
        end,
    })

    tab:AddSection("Status")
    tab:AddLabel("Console shows live [autoegg] log lines.")

    --== manager registration ==--

    Manager.Register("auto_get_egg", {
        toggle    = masterToggle,
        onEnable  = function() Carry:Start() end,
        onDisable = function() Carry:Stop() end,
    })
end
