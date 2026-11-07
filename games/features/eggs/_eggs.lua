return function(lib, window, Manager, loadModule)
    local tab = window:CreateTab("Farming")

    local Finder = loadModule("features/eggs/field_egg_finder.lua")({ lib = lib })

    local options = {
        fieldFilter      = "Any",
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
        Note = "Walks to nearest egg, carries it back to the safe zone. No speed or teleport.",
        Callback = function(on)
            if Manager._suppress then return end
            Manager.Toggle("auto_get_egg", on)
        end,
    })

    -- label -> finder areaId (aliases for display differences)
    local AREAS = {
        { label = "Any",                value = "Any" },
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

    tab:AddDropdown({
        Text = "Field Filter",
        Options = labels,
        Default = "Any",
        DependsOn = masterToggle,
        Note = "Only pick eggs from this field. Any = closest everywhere.",
        Callback = function(option)
            for _, entry in ipairs(AREAS) do
                if entry.label == option then
                    options.fieldFilter = entry.value
                    return
                end
            end
            options.fieldFilter = "Any"
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

    tab:AddMultiDropdown({
        Title = "Only These Mutations",
        Note = "Leave empty to allow any egg. If set, ONLY eggs with these mutations will be picked up.",
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
