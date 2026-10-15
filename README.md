# Sakka

## 1. Repo layout

```
games/
  shared/
    manager.lua          -- dependency manager (no UI, used by every tab)
  features/
    farming/
      _farming.lua       -- the Farming tab: UI only
      farming_position.lua   -- a feature module (added when you build it)
      auto_farm_bosses.lua
    dungeon/
      _dungeon.lua
    player/
      _player.lua
    information/
      _information.lua
    training/
      _training.lua
  universal.lua          -- init shell: builds the window, loads every tab
loader.lua               -- entry point, fetched by the executor
README.md
```

Rules:
- **One folder per tab.** Folder name = tab name, lowercase.
- **The tab file is `_`-prefixed** so it sorts to the top of its folder.
- **Feature modules live beside the tab file** that uses them.
- **Anything shared between tabs lives in `shared/`.**

---

## 2. How loading works

1. `loader.lua` runs in the executor and `loadstring`s `games/universal.lua`.
2. `universal.lua` builds the window (`lib:CreateWindow`), sets up `loadModule`, loads the manager, then loops over the `tabs` list.
3. For each tab path, `universal.lua` loads it and calls it as `mod(lib, window, Manager)`.

Nothing loads a tab file directly — it is always `universal.lua` that calls it. And no tab file loads another tab file.

### The `tabs` list

In `universal.lua`:

```lua
local tabs = {
    "features/information/_information.lua",
    "features/farming/_farming.lua",
    "features/dungeon/_dungeon.lua",
    "features/player/_player.lua",
    "features/training/_training.lua",
}
```

- **Order matters.** Tabs load top-to-bottom. A feature registered in an earlier tab exists for a later tab to depend on. If you reorder this list, you may break a cross-tab dependency.
- **Paths are exact.** GitHub raw URLs are case-sensitive — `farming` ≠ `Farming`. One typo and the tab silently fails to load (you'll see a "Load Error" notification naming the path).

---

## 3. Creating a tab

A tab file is a function that receives `(lib, window, Manager)` and returns nothing. Always take all three parameters, even if the tab doesn't use `Manager` yet — it costs nothing and saves an edit later.

```lua
return function(lib, window, Manager)
    local tab = window:CreateTab("Farming")

    -- ... add sections and elements here ...

    -- ... register features with the Manager here (see §6) ...
end
```

Steps to add a brand-new tab:
1. Create `games/features/<name>/_<name>.lua` with the skeleton above.
2. Add the path to the `tabs` list in `universal.lua`.
3. Fill in elements and (optionally) register features.

---

## 4. UI elements

All elements are created on the `tab` object and take a **table** of options — except `AddSection` and `AddLabel`, which take plain arguments.

> The parameters below are the ones used in this repo. For the full set (themes, colours, flags, etc.), check `SakkaUI.lua` directly.

### `tab:AddSection(title, side?)`

```lua
tab:AddSection("Movement")
tab:AddSection("Info", "Right")   -- place in the right column
```

A visual divider with a heading. Everything after it belongs to that section until the next one.

### `tab:AddToggle(options)`

An on/off switch. Returns the toggle object (needed for `DependsOn` and the Manager).

```lua
local myToggle = tab:AddToggle({
    Text = "Noclip",
    Default = false,
    Callback = function(on)
        -- on is true when switched on, false when switched off
    end,
})
```

| Key | Required | Meaning |
|---|---|---|
| `Text` | yes | Label shown next to the switch |
| `Default` | no | Starting state (`true`/`false`) |
| `Callback` | yes | Function called with the new state |
| `DependsOn` | no | A toggle object — this element only shows when that toggle is on |

### `tab:AddSlider(options)`

```lua
tab:AddSlider({
    Text = "Movement Speed",
    Min = 16, Max = 500, Default = 16,
    Suffix = " studs",
    Note = "Higher is faster.",
    Callback = function(value)
        -- value is the number
    end,
})
```

| Key | Required | Meaning |
|---|---|---|
| `Text` | yes | Label |
| `Min` / `Max` | yes | Numeric range |
| `Default` | no | Starting value (must be inside Min..Max) |
| `Suffix` | no | Text shown after the number |
| `Note` | no | Small helper text under the label |
| `Callback` | yes | Function called with the number |
| `DependsOn` | no | Toggle object |

### `tab:AddDropdown(options)`

Single-select dropdown. Callback receives the chosen option **string**.

```lua
tab:AddDropdown({
    Text = "Farming position",
    Options = { "Above", "Below" },
    Default = "Above",
    Callback = function(option)
        -- option is "Above" or "Below"
    end,
})
```

| Key | Required | Meaning |
|---|---|---|
| `Text` | yes | Label |
| `Options` | yes | Array of strings |
| `Default` | no | Starting option (must be one of `Options`) |
| `Callback` | yes | Function called with the option string |
| `DependsOn` | no | Toggle object |

You can repopulate options at runtime:
```lua
myDropdown:Refresh({ "A", "B", "C" })   -- replace the option list
myDropdown:Set("B", false)              -- select "B"; second arg = fire callback?
```

### `tab:AddMultiDropdown(options)`

Multi-select version. Callback receives a **table** of selected strings.

```lua
tab:AddMultiDropdown({
    Title = "Boss Selection",
    Note = "Select in order: first = most important, last = least important",
    Options = { "Zuko", "Giyu", "Sanemi" },
    Default = {},
    Callback = function(selected)
        -- selected is a table, e.g. { "Zuko", "Sanemi" }
    end,
})
```

| Key | Required | Meaning |
|---|---|---|
| `Title` | yes | Label **(note: `Title`, not `Text`)** |
| `Options` | yes | Array of strings |
| `Default` | no | Table of pre-selected options (`{}` = none) |
| `Note` | no | Helper text |
| `Callback` | yes | Function called with the selected table |
| `DependsOn` | no | Toggle object |

### `tab:AddTextInput(options)`

Free-text field. Callback receives the string.

```lua
tab:AddTextInput({
    Text = "Auto End Dungeon At Floor",
    Placeholder = "e.g. 10",
    DependsOn = someToggle,
    Callback = function(text)
        -- text is the typed string
    end,
})
```

| Key | Required | Meaning |
|---|---|---|
| `Text` | yes | Label |
| `Placeholder` | no | Greyed hint text |
| `Callback` | yes | Function called with the string |
| `DependsOn` | no | Toggle object |

### `tab:AddButton(options)`

A clickable button. No state — just an action.

```lua
tab:AddButton({
    Text = "Discord",
    Callback = function()
        -- runs on every click
    end,
})
```

### `tab:AddLabel(text)`

Plain static text. Takes a **string**, not a table.

```lua
tab:AddLabel("Greetings, " .. LocalPlayer.DisplayName .. "!")
```

### `lib:Notify(options)`

Pop a notification. Works anywhere `lib` is in scope.

```lua
lib:Notify({
    Title = "Not Implemented",
    Content = "This has no game logic yet.",
    Duration = 3,
})
```

---

## 5. The placeholder pattern

Every element that has no logic yet uses `placeholder`. Define it once at the top of the tab:

```lua
local function placeholder(name)
    return function()
        lib:Notify({ Title = "Not Implemented", Content = name .. " has no game logic yet.", Duration = 3 })
    end
end
```

Then use it wherever you'd otherwise write an empty callback:

```lua
tab:AddToggle({
    Text = "Auto Farm Bosses",
    Default = false,
    Callback = placeholder("Auto Farm Bosses"),
})
```

When you build the real logic, replace `placeholder("...")` with a function — but if the feature is managed, replace it with the Manager call instead (see §6).

---

## 6. The dependency manager

`games/shared/manager.lua` keeps track of every feature and which other features it needs. It does **not** contain any game logic and you never edit it when adding a feature — you only *call* it.

### The two calls

**`Manager.Register(name, definition)`** — announce a feature to the manager. It does not create the logic; it files a description of a feature that already exists. Must run **at the end of the tab function**, after the toggles exist and after anything it depends on is registered.

```lua
Manager.Register("farming_position", {
    toggle    = posToggle,          -- the toggle object that represents this feature
    onEnable  = function() end,     -- called when the feature turns ON
    onDisable = function() end,     -- called when the feature turns OFF
    deps      = { },                -- names of features this one needs
})
```

**`Manager.Toggle(name, on)`** — called from a toggle's callback. This is what actually flips the feature and its dependencies.

```lua
posToggle = tab:AddToggle({
    Text = "Farming Position",
    Default = false,
    Callback = function(on)
        if Manager._suppress then return end
        Manager.Toggle("farming_position", on)
    end,
})
```

### The `_suppress` guard

Every callback that talks to the Manager **must** start with:

```lua
if Manager._suppress then return end
```

The manager flips toggles programmatically (to mirror state when a dependency turns on or off). That programmatic flip can fire the callback again — which would re-enter the manager and loop forever. `_suppress` is set to `true` during those programmatic flips, so the callback bails out. Cost is one line; skip it and you get infinite recursion.

### Dependencies

List them in `deps` by **name**, not file path. The manager looks the name up in its own list, so the dependency just has to be registered before the dependent:

```lua
Manager.Register("auto_farm_bosses", {
    toggle    = bossToggle,
    deps      = { "farming_position" },   -- ← the whole relationship, one line
    onEnable  = function() end,
    onDisable = function() end,
})
```

Behaviour: turning on `auto_farm_bosses` also turns on `farming_position`. Turning `auto_farm_bosses` off will only turn `farming_position` off if **nothing else** still needs it. That last rule is the entire point of the manager — you don't have to hand-check "is anything else using this?"

### Registration order

Dependencies **must** be registered before their dependents. Same file, top-to-bottom:

```lua
-- 1. register the dependency
Manager.Register("farming_position", { ... })

-- 2. then register the thing that needs it
Manager.Register("auto_farm_bosses", {
    deps = { "farming_position" },
    ...
})
```

If you register in the wrong order you get `[Manager] missing dependency: farming_position` in the console and the cascade silently won't fire.

### Cross-tab dependencies

Same rules, no extra wiring. A feature in `_dungeon.lua` can depend on a feature registered in `_farming.lua` by naming it in `deps` — as long as `_farming.lua` is loaded before `_dungeon.lua` in the `tabs` list. That's already true with the current order.

```lua
-- inside _dungeon.lua
Manager.Register("auto_pick_card", {
    toggle = cardToggle,
    deps   = { "farming_position" },   -- registered by the Farming tab
    ...
})
```

The manager only knows **names**. It doesn't care which file registered a name — only that the name exists by the time something depends on it.

---

## 7. Feature modules

When an element's logic grows past a couple of lines, move it into its own file beside the tab file.

```lua
-- games/features/farming/farming_position.lua
return function(ctx)
    local M = {}
    local conn

    function M:Start()
        -- connect Heartbeat/Stepped, spawn loops, etc.
    end

    function M:Stop()
        if conn then conn:Disconnect() conn = nil end
    end

    return M
end
```

Load it at the top of the tab, once:

```lua
-- inside _farming.lua
local farmPos = loadModule("features/farming/farming_position.lua")({ state = farmState })
```

Then point the manager at its methods:

```lua
Manager.Register("farming_position", {
    toggle    = posToggle,
    onEnable  = farmPos.Start,
    onDisable = farmPos.Stop,
})
```

`loadModule` **caches by path** — the second time any file asks for the same path, it gets the *same* module instance. So two tabs that both need `farming_position` can each `loadModule` it and share one copy. No duplication, no re-fetch.

Rules:
- Only split out a feature **once you're actually implementing it**. Don't create empty files as placeholders.
- A module owns its own state and exposes methods. Don't reach into another tab's internals.
- `onDisable` must disconnect everything `onEnable` connected. Leaked connections are the number-one bug in a hub like this.

---

## 8. Conventions

**Filenames** — all lowercase, underscores as separators (`farming_position.lua`, not `farming-position.lua`). Hyphens are legal but read as a different convention; stick to underscores.

**Tab files** — `_`-prefixed (`_farming.lua`) so they sort to the top of their folder in the GitHub file list. The underscore is purely cosmetic.

**Folder names** — match the tab name exactly (`features/farming/` ↔ `CreateTab("Farming")`).

**Paths** — always written relative to `games/` and always case-consistent with the repo. Copy them from the GitHub URL if you're unsure.

**One file, one job** — the tab file builds UI and wires callbacks. Feature modules hold logic. Never put feature logic directly in the tab file once it passes trivial size.

---

## 9. Gotchas

- **`MultiDropdown` uses `Title`, not `Text`.** Every other element uses `Text`. Getting this wrong means the label is blank.
- **Registration order.** Dependencies before dependents, always.
- **`_suppress` guard.** Every Manager-calling toggle callback needs it, or the manager loops.
- **`loadModule` caching = shared instances.** Handy for cross-tab sharing, but it also means two files that `loadModule` the same path are manipulating the same object. Keep state ownership clean.
- **`tabs` list reordering changes load order,** which can break a cross-tab dependency. Add new tabs at the bottom unless you have a reason.
- **Case-sensitive paths.** A `Farming` vs `farming` mismatch in one string breaks only that file, with a notification naming the bad path.
- **`Default` is the starting value, not a live setter.** It applies at creation only. If you rebuild a tab, elements come back at their `Default`, not at what the user last chose.
- **`pcall` your element logic where possible.** A single error in a callback can kill the whole feature — wrapping lets one thing fail without taking down the tab.

---

## 10. Worked example: adding one managed feature

Goal: a "Farming Position" feature that "Auto Farm Bosses" needs.

```lua
return function(lib, window, Manager)
    local tab = window:CreateTab("Farming")
    local farmState = { position = "Above", distance = 10 }

    -- 1. declare toggle vars early so later callbacks can see them
    local posToggle, bossToggle

    tab:AddSection("General")

    -- 2. create the dependency first
    posToggle = tab:AddToggle({
        Text = "Farming Position",
        Default = false,
        Callback = function(on)
            if Manager._suppress then return end
            Manager.Toggle("farming_position", on)
        end,
    })
    tab:AddDropdown({
        Text = "Farming position",
        Options = { "Above", "Below" },
        Default = "Above",
        Callback = function(option) farmState.position = option end,
    })

    -- 3. create the dependent
    bossToggle = tab:AddToggle({
        Text = "Auto Farm Bosses",
        Default = false,
        Callback = function(on)
            if Manager._suppress then return end
            Manager.Toggle("auto_farm_bosses", on)
        end,
    })

    -- 4. register — dependency first, dependent second
    Manager.Register("farming_position", {
        toggle    = posToggle,
        onEnable  = function() end,   -- swap for real logic later
        onDisable = function() end,
    })

    Manager.Register("auto_farm_bosses", {
        toggle    = bossToggle,
        deps      = { "farming_position" },
        onEnable  = function() end,
        onDisable = function() end,
    })
end
```

To add a new dependency later, you only change the `deps` list of the dependent and add a `Register` for the new dependency above it. Nothing else moves.
