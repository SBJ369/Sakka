return function(lib, window, Manager, loadModule)
    local tab = window:CreateTab("Farming")

    local Finder = loadModule("features/eggs/field_egg_finder.lua")({ lib = lib })

    local options = {
        fields           = {},
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
