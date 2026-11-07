return function(lib, window, Manager, loadModule)
    local tab = window:CreateTab("Pets")

    local AutoEquip = loadModule("features/pets/auto_equip.lua")({ lib = lib })

    tab:AddSection("Auto Equip")

    local equipToggle = tab:AddToggle({
        Text = "Auto Equip Best Pets",
        Default = false,
        Note = "Calls the server remote to equip best pets every 5 seconds.",
        Callback = function(on)
            if Manager._suppress then return end
            Manager.Toggle("auto_equip_best", on)
        end,
    })

    Manager.Register("auto_equip_best", {
        toggle    = equipToggle,
        onEnable  = function() AutoEquip:Start() end,
        onDisable = function() AutoEquip:Stop() end,
    })
end
