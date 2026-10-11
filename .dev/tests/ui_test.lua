-- Renders every client screen with the contexts the server really sends (taken from the mock
-- engine) inside a fake client UI VM, and checks the widget tables are well formed.
local M = require("tests.mock_engine")

local VALID = { label = true, panel = true, button = true, textbox = true, list = true, rect = true, text = true, icon = true }
local NEEDS_SIZE = { rect = true, button = true, textbox = true, list = true, panel = true, icon = true }

local function check_widgets(name, layout)
	truthy(type(layout) == "table" and type(layout.widgets) == "table", name .. ": no widgets table")
	local seen = {}
	for i, w in ipairs(layout.widgets) do
		local where = string.format("%s widget %d (%s)", name, i, tostring(w.id))
		truthy(type(w.id) == "string" and w.id ~= "", where .. ": id")
		falsy(seen[w.id], where .. ": duplicate id")
		seen[w.id] = true
		truthy(VALID[w.type], where .. ": type " .. tostring(w.type))
		truthy(type(w.x) == "number" and type(w.y) == "number", where .. ": position")
		truthy(w.x == w.x and w.y == w.y, where .. ": NaN position")
		if NEEDS_SIZE[w.type] then
			truthy(type(w.w) == "number" and type(w.h) == "number" and w.w >= 0 and w.h >= 0, where .. ": size")
		end
		if w.type == "text" or w.type == "button" or w.type == "label" then
			truthy(type(w.text) == "string", where .. ": text")
		end
		if w.type == "icon" then
			truthy(math.type(w.item) == "integer", where .. ": icon item")
		end
		for _, key in ipairs({ "color", "border" }) do
			if w[key] then
				truthy(#w[key] >= 3 and #w[key] <= 4, where .. ": " .. key)
				for _, c in ipairs(w[key]) do
					truthy(type(c) == "number" and c >= 0 and c <= 255, where .. ": " .. key .. " channel")
				end
			end
		end
		if w.font_size then
			truthy(math.type(w.font_size) == "integer" and w.font_size > 0, where .. ": font_size")
		end
		if w.on_click then
			truthy(type(w.on_click) == "function")
		end
	end
	return layout
end

-- A fake client UI VM: loads ui/*.lua in the same order as the client (sorted) with only `ui` and
-- `client` (no `vb`), exactly like the real one.
local function ui_vm(opts)
	opts = opts or {}
	local vm_state = {}
	local screens, hud = {}, nil
	local sent = {}
	local env = {
		math = math, string = string, table = table, tostring = tostring, tonumber = tonumber,
		ipairs = ipairs, pairs = pairs, type = type, next = next, select = select, print = print,
	}
	env.ui = {
		define = function(name, fn)
			screens[name] = fn
		end,
		define_hud = function(fn)
			hud = fn
		end,
		send_event = function(kind, value)
			sent[#sent + 1] = { kind = kind, value = value }
		end,
		close = function(opts)
			sent[#sent + 1] = { kind = "close" }
			vm_state.closed_with = opts or {}
		end,
	}
	env.client = {
		screen_size = function()
			return { width = opts.width or 1280, height = opts.height or 720 }
		end,
		time = function()
			return 1.0
		end,
		inventory = function()
			return opts.inventory or {}
		end,
		selected_slot = function()
			return 1
		end,
		chat_log = function()
			return opts.chat or {}
		end,
		chat_open = function()
			return opts.chat_open or false
		end,
		break_progress = function()
			return opts.progress
		end,
		health = function()
			return { current = 14, max = 20 }
		end,
		players = function()
			return {}
		end,
		player_name = function()
			return "alice"
		end,
	}
	env._G = env
	local files = M.listdir("ui")
	table.sort(files)
	for _, f in ipairs(files) do
		if f:match("%.lua$") then
			local src = assert(io.open("ui/" .. f)):read("a")
			assert(load(src, "@ui/" .. f, "t", env))()
		end
	end
	vm_state.screens, vm_state.hud, vm_state.sent, vm_state.env = screens, function() return hud end, sent, env
	return vm_state
end

local function render(vm, name, ctx)
	local state = ctx
	local layout = vm.screens[name](state)
	return check_widgets(name, layout), state
end

local function find(layout, id)
	for _, w in ipairs(layout.widgets) do
		if w.id == id then
			return w
		end
	end
end

local function dev(name)
	return M.join(name, nil)
end

local function setup()
	M.load()
	M.flat_ground(63, 40)
end

test("every screen the server opens renders into valid widgets", function()
	setup()
	local vm = ui_vm()
	local a, b = dev("alice"), dev("bob")
	local seen = {}
	local function capture(p)
		local ui = p.ui
		seen[ui.name] = true
		render(vm, ui.name, ui.ctx)
		return ui
	end

	M.input(a, { menu = true })
	capture(a)
	M.chat(a, "!warp")
	capture(a)
	M.chat(a, "!warp somewhere")
	M.chat(a, "!warp other")
	M.chat(a, "!warp")
	capture(a)
	M.chat(a, "!store")
	capture(a)
	M.chat(a, "!almanac")
	capture(a)
	-- lock, vending
	a:give({ item = M.id("bp:lock_big"), count = 1 })
	a:give({ item = M.id("bp:vending"), count = 1 })
	M.select(a, "bp:lock_big")
	M.aim = { x = 20, y = 63, z = 20, nx = 0, ny = 1, nz = 0 }
	M.click(a, "secondary")
	M.select(a, "bp:vending")
	M.aim = { x = 22, y = 63, z = 22, nx = 0, ny = 1, nz = 0 }
	M.click(a, "secondary")
	M.select(a, "bp:wrench")
	M.aim = { x = 20, y = 64, z = 20 }
	M.click(a, "secondary")
	M.ui_event(a, "lock_add", { role = "admin", name = "bob" })
	M.ui_event(a, "lock_add", { role = "builder", name = "alice" })
	capture(a)
	M.aim = { x = 22, y = 64, z = 22 }
	M.click(a, "secondary")
	capture(a)
	M.click(b, "secondary")
	M.select(b, "bp:wrench")
	M.click(b, "secondary")
	capture(b)
	-- trade
	M.chat(a, "!trade bob")
	M.chat(b, "!trade accept")
	M.ui_event(a, "trade_item", { item = M.id("bp:dirt"), delta = 3 })
	M.ui_event(b, "trade_coins", { delta = 20 })
	M.ui_event(a, "trade_accept", {})
	M.ui_event(b, "trade_accept", {})
	capture(a)
	capture(b)
	M.ui_event(a, "trade_cancel", {})
	capture(b)
	for _, name in ipairs({ "bp:menu", "bp:warp", "bp:store", "bp:almanac", "bp:lock", "bp:vending", "bp:trade", "bp:notice" }) do
		truthy(seen[name], "screen never opened: " .. name)
	end
end)

test("screens survive small windows, large windows and missing fields", function()
	setup()
	for _, size in ipairs({ { 320, 200 }, { 1280, 720 }, { 3840, 2160 } }) do
		local vm = ui_vm({ width = size[1], height = size[2] })
		for name in pairs(vm.screens) do
			render(vm, name, {})
		end
	end
end)

test("buttons send the events the server routes", function()
	setup()
	local vm = ui_vm()
	local layout = render(vm, "bp:store", { coins = 500, items = { { id = "lock_small", name = "Small Lock", price = 50 } } })
	find(layout, "buy_1").on_click()
	eq(vm.sent[1].kind, "shop_buy")
	eq(vm.sent[1].value.id, "lock_small")
	-- too poor: no event
	local poor = render(vm, "bp:store", { coins = 1, items = { { id = "lock_small", name = "Small Lock", price = 50 } } })
	find(poor, "buy_1").on_click()
	eq(#vm.sent, 1)
	layout = render(vm, "bp:menu", { coins = 1, name = "a", world = "w" })
	find(layout, "open_store").on_click()
	eq(vm.sent[2].kind, "menu_open")
	eq(vm.sent[2].value.screen, "store")
	-- every event kind the screens can send is one the server knows how to route
	local routed = { lock = true, vend = true, trade = true, shop = true, menu = true }
	local state = {
		tier = "Big Lock", owner = "a", size = 48, max_size = 48, adjustable = true, can_edit = true, public = false,
		admins = { "x" }, builders = { "y" }, id = 1, x1 = 0, x2 = 1, z1 = 0, z2 = 1,
	}
	for _, name in ipairs({ "bp:lock", "bp:vending", "bp:trade", "bp:warp" }) do
		local ctx = name == "bp:lock" and state or name == "bp:vending" and { is_owner = true, price = 2, bundle = 1, qty = 1, stock = 3, till = 4 }
			or name == "bp:trade" and { partner = "z", inventory = { { item = 4, name = "Dirt", have = 3, offered = 0 } }, mine = {}, theirs = {}, my_accepted = true, their_accepted = true }
			or { recent = { "ABC" }, name = "XYZ" }
		local l = render(vm, name, ctx)
		for _, w in ipairs(l.widgets) do
			if w.type == "button" and w.id ~= "close" then
				local before = #vm.sent
				w.on_click()
				for i = before + 1, #vm.sent do
					local prefix = vm.sent[i].kind:match("^(%a+)_")
					truthy(vm.sent[i].kind == "close" or (prefix and routed[prefix]), "unrouted event " .. vm.sent[i].kind .. " from " .. name .. "/" .. w.id)
				end
			end
		end
	end
end)

test("the hud shows coins from the hidden server line and hides that line from chat", function()
	setup()
	local vm = ui_vm({
		chat = { "hello there", "@@bp|coins=1234|world=FARM|owner=bob", "<bob> hi" },
		inventory = { { item = M.id("bp:dirt"), count = 5, name = "bp:dirt" }, { item = 0, count = 0, name = "" } },
		progress = 0.5,
	})
	local state = {}
	local layout = check_widgets("hud", vm.hud()(state))
	eq(find(layout, "coins").text, "1234 coins")
	truthy(find(layout, "world").text:find("FARM", 1, true))
	truthy(find(layout, "world").text:find("bob", 1, true))
	for _, w in ipairs(layout.widgets) do
		if w.type == "text" then
			falsy(w.text:find("@@bp", 1, true), "marker leaked into " .. w.id)
		end
	end
	truthy(find(layout, "icon_1"))
	truthy(find(layout, "break_fill"))
	-- when the line scrolls out of the chat log, the last known values stay
	vm.env.client.chat_log = function()
		return { "just chat" }
	end
	layout = check_widgets("hud", vm.hud()(state))
	eq(find(layout, "coins").text, "1234 coins")
end)

test("the server's hud line parses the way the hud expects", function()
	setup()
	local hud = require("game.hud")
	local line = hud.line({ coins = 7 }, "A|B=C", "o=w")
	truthy(line:find("coins=7", 1, true))
	local fields = {}
	for k, v in line:sub(#hud.MARKER + 1):gmatch("([%w_]+)=([^|]*)") do
		fields[k] = v
	end
	eq(fields.coins, "7")
	eq(fields.world, "A_B_C")
	eq(fields.owner, "o_w")
end)

test("the hud tells the server when the chat box opens and closes", function()
	setup()
	local opts = {}
	local vm = ui_vm(opts)
	local state = {}
	vm.hud()(state)
	eq(#vm.sent, 1)
	eq(vm.sent[1].kind, "hud_chat")
	eq(vm.sent[1].value.open, false)
	vm.hud()(state)
	eq(#vm.sent, 1, "nothing sent while the state is unchanged")
	opts.chat_open = true
	vm.hud()(state)
	eq(vm.sent[2].kind, "hud_chat")
	eq(vm.sent[2].value.open, true)
	opts.chat_open = false
	vm.hud()(state)
	eq(vm.sent[3].value.open, false)
end)

test("the loading screen closes itself and recaptures the mouse when the warp is done", function()
	setup()
	local vm = ui_vm()
	local layout = render(vm, "bp:loading", { world = "FARM" })
	truthy(find(layout, "text").text:find("FARM", 1, true))
	eq(#vm.sent, 0)
	layout = render(vm, "bp:loading", { done = true })
	eq(#layout.widgets, 0)
	eq(vm.sent[#vm.sent].kind, "close")
	eq(vm.closed_with.capture_mouse, true)
end)

test("close buttons hand the mouse back to the game", function()
	setup()
	local vm = ui_vm()
	for _, name in ipairs({ "bp:menu", "bp:store", "bp:almanac", "bp:warp", "bp:notice" }) do
		local layout = render(vm, name, { items = {}, recent = {}, species = {}, recipes = {} })
		local button = find(layout, "close") or find(layout, "ok")
		vm.closed_with = nil
		button.on_click()
		eq(vm.closed_with and vm.closed_with.capture_mouse, true, name)
	end
end)
