return function(lib, window, Manager, loadModule)
    local tab = window:CreateTab("Farming")

    local Finder = loadModule("features/eggs/field_egg_finder.lua")({ lib = lib })

    local options = {
        fields           = {},   -- ordered list of area ids (priority order)
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
        Note = "Select at least one field below, then toggle this on.",
        Callback = function(on)
            if Manager._suppress then return end
            if on and #options.fields == 0 then
                lib:Notify({ Title = "Auto Egg", Content = "Select at least one field first.", Duration = 3 })
                -- bounce the toggle back off
                if masterToggle then
                    Manager._suppress = true
                    pcall(function() masterToggle:Set(false) end)
                    Manager._suppress = false
                end
                return
            end
            Manager.Toggle("auto_get_egg", on)
        end,
    })

    -- label -> finder areaId (aliases for display differences)
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

    -- ordered selection: track the order fields were picked, drop on deselect
    local orderedSelections = {}
    local function rebuildOrdered(newSet)
        local newOrdered = {}
        -- keep prior order for anything still selected
        for _, v in ipairs(orderedSelections) do
            if newSet[v] then
                table.insert(newOrdered, v)
            end
        end
        -- append any newly-selected not already in ordered
        for _, v in ipairs(newSet) do
            local found = false
            for _, existing in ipairs(newOrdered) do
                if existing == v then found = true break end
            end
            if not found then
                table.insert(newOrdered, v)
            end
        end
        orderedSelections = newOrdered
        -- convert labels -> area ids
        local mapped = {}
        for _, lbl in ipairs(orderedSelections) do
            for _, entry in ipairs(AREAS) do
                if entry.label == lbl then
                    table.insert(mapped, entry.value)
                    break
                end
            end
        end
        options.fields = mapped
    end

    tab:AddMultiDropdown({
        Title = "Fields (select in priority order)",
        Note = "First = most important, last = least important.",
        Options = labels,
        Default = {},
        DependsOn = masterToggle,
        Callback = function(selected)
            -- selected may arrive as a set or an array — normalize
            local set = {}
            if type(selected) == "table" then
                for k, v in pairs(selected) do
                    if type(k) == "number" then
                        set[v] = true
                    elseif v == true then
                        set[k] = true
                    end
                end
            end
            rebuildOrdered(set)
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
            local list = {}
            if type(selected) == "table" then
                for k, v in pairs(selected) do
                    if type(k) == "number" then table.insert(list, v)
                    elseif v == true then table.insert(list, k) end
                end
            end
            options.allowedMutations = list
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
