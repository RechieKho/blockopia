-- A small fake of the Voxel Browser server API, enough to load the whole pack and drive it in
-- tests. It mimics the engine rules the pack depends on (load order, event vetoes, inventories,
-- JSON round trips that turn integers into floats). It is NOT the engine: see README "Testing".
local M = {}
local real_print = print

local function floatify(v)
	if type(v) == "number" then
		return v + 0.0
	elseif type(v) == "table" then
		local out = {}
		for k, x in pairs(v) do
			out[k] = floatify(x)
		end
		return out
	end
	return v
end

local function key3(x, y, z)
	return x .. "," .. y .. "," .. z
end

-- ---- players ---------------------------------------------------------------------------

local Player = {}
Player.__index = Player

function Player:get_name()
	return self.name
end
function Player:get_pos()
	return { x = self.x, y = self.y, z = self.z }
end
function Player:get_login()
	return self.login
end
function Player:send_message(text)
	self.messages[#self.messages + 1] = text
end
function Player:open_ui(name, ctx)
	self.ui = { name = name, ctx = ctx }
	self.ui_log[#self.ui_log + 1] = self.ui
end
function Player:get_inventory()
	local out = {}
	for i, s in ipairs(self.slots) do
		out[i] = { item = s.item, count = s.count }
	end
	return out
end
function Player:give(stack)
	local left = stack.count
	for _, s in ipairs(self.slots) do
		if s.item == stack.item and s.count < 200 and left > 0 then
			local add = math.min(200 - s.count, left)
			s.count, left = s.count + add, left - add
		end
	end
	while left > 0 do
		local add = math.min(200, left)
		self.slots[#self.slots + 1] = { item = stack.item, count = add }
		left = left - add
	end
end
function Player:take(stack)
	local have = 0
	for _, s in ipairs(self.slots) do
		if s.item == stack.item then
			have = have + s.count
		end
	end
	if have < stack.count then
		return false
	end
	local need = stack.count
	for i = #self.slots, 1, -1 do
		local s = self.slots[i]
		if s.item == stack.item and need > 0 then
			local rem = math.min(s.count, need)
			s.count, need = s.count - rem, need - rem
			if s.count == 0 then
				table.remove(self.slots, i)
			end
		end
	end
	return true
end
function Player:get_selected_slot()
	return self.selected
end
function Player:get_held_item()
	local s = self.slots[self.selected]
	return s and { item = s.item, count = s.count } or nil
end
function Player:get_health()
	return { current = self.health, max = 20 }
end
function Player:damage(amount, cause)
	self.health = self.health - amount
	if self.health <= 0 then
		M.respawn(self, cause)
	end
end
function Player:place_block(x, y, z, id)
	if not M.fire("block_place", self, { x = x, y = y, z = z }) then
		return false
	end
	M.world[key3(x, y, z)] = id
	local def = M.block_by_id[id]
	if def and def.on_place then
		def.on_place({ pos = { x = x, y = y, z = z }, player = self })
	end
	return true
end
function Player:break_block(x, y, z)
	local k = key3(x, y, z)
	local id = M.world[k]
	if not id or id == 0 then
		return false
	end
	if not M.fire("block_break", self, { x = x, y = y, z = z }) then
		return false
	end
	M.world[k] = nil
	local def = M.block_by_id[id]
	if def and def.on_break then
		def.on_break({ pos = { x = x, y = y, z = z }, player = self })
	end
	return true
end
function Player:punch(dmg)
	local aim = M.aim
	if not aim then
		return { hit_block = false }
	end
	local x, y, z = aim.x, aim.y, aim.z
	local id = M.world[key3(x, y, z)] or 0
	if id == 0 then
		return { hit_block = false }
	end
	local def = M.block_by_id[id]
	local max = def and def.max_damage or 0
	local k = key3(x, y, z)
	M.damage[k] = (M.damage[k] or 0) + (dmg or 1)
	if max > 0 and M.damage[k] < max then
		return { hit_block = true, broken = false, punches = M.damage[k] }
	end
	if not M.fire("block_break", self, { x = x, y = y, z = z }) then
		return { hit_block = true, broken = false }
	end
	M.damage[k] = nil
	M.world[k] = nil
	if def and def.on_break then
		def.on_break({ pos = { x = x, y = y, z = z }, player = self })
	end
	return { hit_block = true, broken = true }
end

function M.respawn(player, cause)
	local decision = M.fire_decision("player_death", player, cause, 0)
	player.health = (decision and decision.heal) or 20
	if decision and decision.pos then
		player.x, player.y, player.z = decision.pos.x, decision.pos.y, decision.pos.z
	else
		player.x, player.y, player.z = 0, 80, 0
	end
	player.deaths = (player.deaths or 0) + 1
end

-- ---- events ----------------------------------------------------------------------------

function M.fire(event, ...)
	local result = true
	for _, h in ipairs(M.handlers[event] or {}) do
		if h(...) == false then
			result = false
		end
	end
	return result
end

function M.fire_decision(event, ...)
	for _, h in ipairs(M.handlers[event] or {}) do
		local r = h(...)
		if type(r) == "table" then
			return r
		end
	end
	return nil
end

-- File names in a directory. tests/run.py provides __listdir (lupa blocks io.popen); plain Lua
-- falls back to `ls`.
function M.listdir(dir)
	if __listdir then
		local out = {}
		for _, name in ipairs(__listdir(dir)) do
			out[#out + 1] = name
		end
		return out
	end
	local names = {}
	local p = io.popen('ls "' .. dir .. '" 2>/dev/null')
	for line in p:lines() do
		names[#names + 1] = line
	end
	p:close()
	return names
end

-- ---- loading ---------------------------------------------------------------------------

-- opts.db / opts.storage carry saved state across a "restart"; opts.set_pos adds Player:set_pos.
function M.load(opts)
	opts = opts or {}
	for name in pairs(package.loaded) do
		if name:match("^game%.") or name:match("^lib%.") or name:match("^data%.") then
			package.loaded[name] = nil
		end
	end
	M.handlers, M.timers, M.world, M.damage, M.drops, M.players = {}, {}, {}, {}, {}, {}
	M.blocks, M.block_by_id, M.aim, M.next_id = {}, {}, nil, 1
	M.db = opts.db or {}
	M.storage = opts.storage and floatify(opts.storage) or {}
	M.pipeline, M.keybinds = nil, {}
	M.auth_required = opts.auth_required or false
	if opts.set_pos then
		Player.set_pos = function(self, x, y, z)
			self.x, self.y, self.z = x, y, z
		end
	else
		Player.set_pos = nil
	end

	vb = {
		storage = M.storage,
		db = {
			get = function(k)
				local v = M.db[k]
				if v == nil then
					return nil
				end
				return floatify(v)
			end,
			set = function(k, v)
				M.db[k] = floatify(v)
			end,
			delete = function(k)
				M.db[k] = nil
			end,
		},
		auth = {
			required = function()
				return M.auth_required
			end,
		},
		register_block = function(def)
			local existing = M.blocks[def.name]
			if existing then
				return existing.id
			end
			local id = M.next_id
			M.next_id = id + 1
			def.id = id
			M.blocks[def.name] = def
			M.block_by_id[id] = def
			return id
		end,
		register_biome = function() end,
		register_keybind = function(name)
			M.keybinds[name] = true
		end,
		register_entity = function() end,
		on = function(event, fn)
			M.handlers[event] = M.handlers[event] or {}
			table.insert(M.handlers[event], fn)
		end,
		after = function(seconds, fn)
			table.insert(M.timers, { left = seconds, every = nil, fn = fn })
		end,
		every = function(seconds, fn)
			table.insert(M.timers, { left = seconds, every = seconds, fn = fn })
		end,
		combat = { set_params = function() end },
		action = {
			set_params = function() end,
			get_params = function()
				return { reach = 6 }
			end,
		},
		physics = {
			get_params = function()
				return { eye_height = 1.6 }
			end,
		},
		config = {
			get = function(k)
				return k == "tick_rate" and 20 or nil
			end,
		},
		noise = {
			constant = function(v)
				return { constant = v }
			end,
		},
		worldgen = {
			set_pipeline = function(def)
				M.pipeline = def
			end,
		},
		world = {
			get_block = function(x, y, z)
				return M.world[key3(x, y, z)] or 0
			end,
			set_block = function(x, y, z, id)
				if id == 0 then
					M.world[key3(x, y, z)] = nil
				else
					M.world[key3(x, y, z)] = id
				end
			end,
			raycast = function()
				if not M.aim then
					return nil
				end
				local a = M.aim
				return { hit = true, x = a.x, y = a.y, z = a.z, nx = a.nx or 0, ny = a.ny or 0, nz = a.nz or 0 }
			end,
			spawn_item_drop = function(pos, item, count)
				M.drops[#M.drops + 1] = { pos = pos, item = item, count = count }
			end,
		},
	}
	print = function() end

	local function run(path)
		local f = assert(loadfile(path))
		return f()
	end
	local function list(dir)
		local names = M.listdir(dir)
		local files = {}
		for _, line in ipairs(names) do
			if line:match("%.lua$") then
				files[#files + 1] = dir .. "/" .. line
			end
		end
		table.sort(files)
		return files
	end
	local ok, err = pcall(function()
		for _, f in ipairs(list("blocks")) do
			run(f)
		end
		for _, f in ipairs(list("entities")) do
			run(f)
		end
		for _, f in ipairs(list("biomes")) do
			run(f)
		end
		for _, f in ipairs(list(".")) do
			local base = f:match("([^/]+)$")
			if base ~= "init.lua" and base ~= "auth.lua" then
				run(f)
			end
		end
		run("init.lua")
	end)
	print = real_print
	if not ok then
		error(err, 0)
	end
	-- tests aim by setting M.aim instead of building geometry for the pack's own ray march
	package.loaded["game.actions"].pick = function()
		if not M.aim then
			return nil
		end
		return { x = M.aim.x, y = M.aim.y, z = M.aim.z, nx = M.aim.nx, ny = M.aim.ny, nz = M.aim.nz }
	end
	return vb
end

-- ---- driving ---------------------------------------------------------------------------

function M.id(name)
	return M.blocks[name].id
end

-- Joins a player (pre-join event) and sends their first input so they become ready.
function M.join(name, login)
	local ok = M.fire("player_join", name, login)
	if ok == false then
		return nil
	end
	local p = setmetatable({
		name = name, login = login, x = 0.5, y = 64, z = 0.5, health = 20, slots = {}, selected = 1,
		messages = {}, ui_log = {}, ui = nil,
	}, Player)
	M.players[name] = p
	M.input(p, {})
	return p
end

function M.leave(p)
	M.fire("player_leave", p)
	M.players[p.name] = nil
end

-- opts: primary / secondary / menu booleans
function M.input(p, opts)
	local input = {
		move = { x = 0, y = 0, z = 0 }, yaw = 0, pitch = 0,
		buttons = { primary = opts.primary or false, secondary = opts.secondary or false },
		keybinds = { ["base:inventory"] = opts.menu or false },
	}
	M.fire("player_input", p, input)
end

-- One click (press then release).
function M.click(p, which)
	M.input(p, { [which] = true })
	M.input(p, {})
end

function M.select(p, item_name, count)
	local id = M.id(item_name)
	for i, s in ipairs(p.slots) do
		if s.item == id then
			p.selected = i
			return
		end
	end
	error("player " .. p.name .. " has no " .. item_name)
end

function M.count(p, item_name)
	local id = M.id(item_name)
	local n = 0
	for _, s in ipairs(p.slots) do
		if s.item == id then
			n = n + s.count
		end
	end
	return n
end

function M.advance(seconds, step)
	step = step or 0.5
	local t = 0
	while t < seconds do
		local dt = math.min(step, seconds - t)
		t = t + dt
		M.fire("tick", dt)
		for _, timer in ipairs(M.timers) do
			timer.left = timer.left - dt
			if timer.left <= 0 then
				if timer.every then
					timer.left = timer.left + timer.every
					timer.fn()
				elseif not timer.done then
					timer.done = true
					timer.fn()
				end
			end
		end
	end
end

function M.ui_event(p, kind, value, ui_name)
	M.fire("ui_event", p, ui_name or (p.ui and p.ui.name) or "?", "w", kind, value)
end

function M.chat(p, text)
	return M.fire("chat", p, text)
end

function M.flat_ground(y, half)
	local rock = M.id("bp:rock")
	for x = -half, half do
		for z = -half, half do
			M.world[key3(x, y, z)] = rock
		end
	end
end

return M
