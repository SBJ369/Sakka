local Manager = {}
Manager.features = {}
Manager._suppress = false   -- set true while we programmatically flip a toggle

-- Register a feature. Call this BEFORE registering anything that depends on it.
-- def = {
--   deps      = { "other_feature", ... },   -- optional
--   toggle    = <the toggle object>,        -- optional, used to mirror state in the UI
--   onEnable  = function() end,             -- optional
--   onDisable = function() end,             -- optional
-- }
function Manager.Register(name, def)
	if Manager.features[name] then
		warn("[Manager] duplicate feature registration: " .. name)
	end
	Manager.features[name] = {
		enabled   = false,
		refs      = 0,
		manual    = false,
		deps      = def.deps or {},
		onEnable  = def.onEnable,
		onDisable = def.onDisable,
		toggle    = def.toggle,
	}
end

-- Internal: recursive enable/disable, cascading through deps.
local function apply(name, on)
	local f = Manager.features[name]
	if not f then return end
	if f.enabled == on then return end
	f.enabled = on

	if on then
		for _, dep in ipairs(f.deps) do
			local d = Manager.features[dep]
			if d then
				d.refs += 1
				apply(dep, true)
			else
				warn("[Manager] missing dependency: " .. dep)
			end
		end
		if f.onEnable then
			local ok, err = pcall(f.onEnable)
			if not ok then warn("[Manager] onEnable(" .. name .. "): " .. tostring(err)) end
		end
	else
		if f.onDisable then
			local ok, err = pcall(f.onDisable)
			if not ok then warn("[Manager] onDisable(" .. name .. "): " .. tostring(err)) end
		end
		for _, dep in ipairs(f.deps) do
			local d = Manager.features[dep]
			if d then
				d.refs = math.max(0, d.refs - 1)
				if d.refs == 0 and not d.manual then
					apply(dep, false)
				end
			end
		end
	end

	-- Mirror the state onto the toggle, guarded against callback loops.
	if f.toggle then
		Manager._suppress = true
		pcall(function() f.toggle:Set(on) end)
		Manager._suppress = false
	end
end

-- Called by every toggle callback.
function Manager.Toggle(name, on)
	local f = Manager.features[name]
	if not f then
		warn("[Manager] unknown feature: " .. name)
		return
	end

	if on then
		f.manual = true
		apply(name, true)
	else
		f.manual = false
		if f.refs == 0 then
			apply(name, false)
		elseif f.toggle then
			-- Something else still needs this — snap the toggle back on.
			Manager._suppress = true
			pcall(function() f.toggle:Set(true) end)
			Manager._suppress = false
		end
	end
end

return Manager
