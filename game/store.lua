-- Persistence on top of vb.db (written immediately, no key listing) plus the game clock.
--
-- vb.db cannot list keys, so anything that needs enumerating keeps an index key. Position-keyed
-- things (shrubs, vending machines) live in a Collection: records grouped into buckets of
-- `bucket_size` x `bucket_size` columns, one db key per bucket, and an index key listing buckets.
local util = require("lib.util")
local balance = require("data.balance")

local M = {}

-- JSON has one number type, so the engine hands integers back as floats (3.0). Turn whole
-- numbers back into integers so they print as "3" and work as table keys and string.format("%d").
local function intify(v)
	if type(v) == "number" then
		return math.tointeger(v) or v
	elseif type(v) == "table" then
		for k, x in pairs(v) do
			v[k] = intify(x)
		end
	end
	return v
end

function M.get(key)
	return intify(vb.db.get(key))
end

function M.set(key, value)
	vb.db.set(key, value)
end

function M.delete(key)
	vb.db.delete(key)
end

-- Game clock: seconds of server uptime ever played, advanced by the tick event and saved
-- periodically. The engine exposes no wall clock to packs, so shrubs do not grow while the
-- server is off.
local clock, unsaved, loaded = 0, 0, false

local function load_clock()
	if not loaded then
		local meta = M.get("meta:clock") or {}
		clock = meta.game_seconds or 0
		loaded = true
	end
end

function M.now()
	load_clock()
	return clock
end

function M.save_clock()
	load_clock()
	vb.db.set("meta:clock", { schema_version = 1, game_seconds = clock })
	unsaved = 0
end

function M.advance(dt)
	load_clock()
	clock = clock + dt
	unsaved = unsaved + dt
	if unsaved >= balance.game_clock_save_seconds then
		M.save_clock()
	end
end

-- Collection of records keyed by block position.
local Collection = {}
Collection.__index = Collection

function M.collection(name, bucket_size)
	return setmetatable({ name = name, size = bucket_size, buckets = {}, loaded = false }, Collection)
end

function Collection:bucket_key(x, z)
	return math.floor(x / self.size) .. "," .. math.floor(z / self.size)
end

function Collection:ensure()
	if self.loaded then
		return
	end
	self.loaded = true
	local index = M.get("idx:" .. self.name) or {}
	for _, bk in ipairs(index) do
		self.buckets[bk] = M.get(self.name .. ":" .. bk) or {}
	end
end

function Collection:save_bucket(bk)
	vb.db.set(self.name .. ":" .. bk, self.buckets[bk])
end

function Collection:get(x, y, z)
	self:ensure()
	local b = self.buckets[self:bucket_key(x, z)]
	return b and b[util.pos_key(x, y, z)]
end

function Collection:set(x, y, z, rec)
	self:ensure()
	local bk = self:bucket_key(x, z)
	local b = self.buckets[bk]
	if not b then
		b = {}
		self.buckets[bk] = b
		vb.db.set("idx:" .. self.name, util.sorted_keys(self.buckets))
	end
	b[util.pos_key(x, y, z)] = rec
	self:save_bucket(bk)
end

-- Call after mutating a record in place.
function Collection:touch(x, z)
	self:save_bucket(self:bucket_key(x, z))
end

function Collection:remove(x, y, z)
	self:ensure()
	local bk = self:bucket_key(x, z)
	local b = self.buckets[bk]
	if b and b[util.pos_key(x, y, z)] then
		b[util.pos_key(x, y, z)] = nil
		self:save_bucket(bk)
	end
end

-- Visits every record in buckets that touch the square of `radius` around (px, pz).
-- fn(x, y, z, rec); safe against fn removing records.
function Collection:each_near(px, pz, radius, fn)
	self:ensure()
	local bx1, bx2 = math.floor((px - radius) / self.size), math.floor((px + radius) / self.size)
	local bz1, bz2 = math.floor((pz - radius) / self.size), math.floor((pz + radius) / self.size)
	for bx = bx1, bx2 do
		for bz = bz1, bz2 do
			local b = self.buckets[bx .. "," .. bz]
			if b then
				local keys = {}
				for key in pairs(b) do
					keys[#keys + 1] = key
				end
				for _, key in ipairs(keys) do
					local rec = b[key]
					if rec then
						local x, y, z = util.parse_pos_key(key)
						fn(x, y, z, rec)
					end
				end
			end
		end
	end
end

function Collection:count()
	self:ensure()
	local n = 0
	for _, b in pairs(self.buckets) do
		for _ in pairs(b) do
			n = n + 1
		end
	end
	return n
end

return M
