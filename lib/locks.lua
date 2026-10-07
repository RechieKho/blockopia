-- Lock regions: square areas centred on the lock block, covering every height. Pure.
local M = {}

local BUCKET = 1024

-- Area of a lock of `size` centred on (x, z): inclusive corners.
function M.box_of(x, z, size)
	local half = size // 2
	return { x1 = x - half, z1 = z - half, x2 = x - half + size - 1, z2 = z - half + size - 1 }
end

function M.contains(box, x, z)
	return x >= box.x1 and x <= box.x2 and z >= box.z1 and z <= box.z2
end

function M.overlaps(a, b)
	return a.x1 <= b.x2 and b.x1 <= a.x2 and a.z1 <= b.z2 and b.z1 <= a.z2
end

function M.encloses(outer, inner)
	return outer.x1 <= inner.x1 and outer.x2 >= inner.x2 and outer.z1 <= inner.z1 and outer.z2 >= inner.z2
end

local function buckets_of(box)
	local out = {}
	for bx = box.x1 // BUCKET, box.x2 // BUCKET do
		for bz = box.z1 // BUCKET, box.z2 // BUCKET do
			out[#out + 1] = bx .. "," .. bz
		end
	end
	return out
end

-- Spatial index. A lock is { id, owner, x, y, z, size, box, ... }.
local Index = {}
Index.__index = Index

function M.new_index()
	return setmetatable({ buckets = {}, by_id = {} }, Index)
end

function Index:add(lock)
	lock.box = M.box_of(lock.x, lock.z, lock.size)
	self.by_id[lock.id] = lock
	for _, key in ipairs(buckets_of(lock.box)) do
		local b = self.buckets[key]
		if not b then
			b = {}
			self.buckets[key] = b
		end
		b[lock.id] = true
	end
end

function Index:remove(id)
	local lock = self.by_id[id]
	if not lock then
		return
	end
	for _, key in ipairs(buckets_of(lock.box)) do
		local b = self.buckets[key]
		if b then
			b[id] = nil
		end
	end
	self.by_id[id] = nil
end

-- Locks covering the point, innermost (smallest) first.
function Index:at(x, z)
	local b = self.buckets[(x // BUCKET) .. "," .. (z // BUCKET)]
	local found = {}
	if b then
		for id in pairs(b) do
			local lock = self.by_id[id]
			if M.contains(lock.box, x, z) then
				found[#found + 1] = lock
			end
		end
	end
	table.sort(found, function(p, q)
		if p.size ~= q.size then
			return p.size < q.size
		end
		return p.id < q.id
	end)
	return found
end

-- Locks whose area overlaps `box`, skipping the lock with id `ignore_id`.
function Index:overlapping(box, ignore_id)
	local seen, found = {}, {}
	for _, key in ipairs(buckets_of(box)) do
		local b = self.buckets[key]
		if b then
			for id in pairs(b) do
				if id ~= ignore_id and not seen[id] then
					seen[id] = true
					local lock = self.by_id[id]
					if M.overlaps(lock.box, box) then
						found[#found + 1] = lock
					end
				end
			end
		end
	end
	table.sort(found, function(p, q)
		return p.id < q.id
	end)
	return found
end

local function list_has(list, subject)
	for _, s in ipairs(list or {}) do
		if s == subject then
			return true
		end
	end
	return false
end

function M.is_owner_or_admin(lock, subject)
	return lock.owner == subject or list_has(lock.admins, subject)
end

-- May `subject` build (break/place/plant/harvest) at (x, z)?
-- Unclaimed land is free. Owners and admins of ANY lock covering the point may build, so a grand
-- lock owner keeps control of locks inside it; otherwise the innermost lock decides.
function Index:can_build(subject, x, z)
	local covering = self:at(x, z)
	if #covering == 0 then
		return true
	end
	for _, lock in ipairs(covering) do
		if M.is_owner_or_admin(lock, subject) then
			return true
		end
	end
	local inner = covering[1]
	return list_has(inner.builders, subject) or inner.public == true
end

-- May `subject` place a new lock with area `box`? (`ignore_id` skips a lock being resized.)
-- Returns true, or false and a reason.
function Index:can_place(subject, x, z, box, ignore_id)
	local covering = self:at(x, z)
	if ignore_id then
		for i = #covering, 1, -1 do
			if covering[i].id == ignore_id then
				table.remove(covering, i)
			end
		end
	end
	if #covering > 0 then
		local ok = false
		for _, lock in ipairs(covering) do
			if M.is_owner_or_admin(lock, subject) then
				ok = true
			end
		end
		if not ok then
			return false, "this land is locked by someone else"
		end
	end
	for _, other in ipairs(self:overlapping(box, ignore_id)) do
		local mine = M.is_owner_or_admin(other, subject)
		if not mine and not M.encloses(other.box, box) then
			return false, "that area overlaps a lock owned by someone else"
		end
		if not mine then
			return false, "this land is locked by someone else"
		end
	end
	return true
end

-- Locks inside `lock`'s area owned by other people (blocks removing it).
function Index:foreign_inside(lock)
	local found = {}
	for _, other in ipairs(self:overlapping(lock.box, lock.id)) do
		if other.owner ~= lock.owner and M.encloses(lock.box, other.box) then
			found[#found + 1] = other
		end
	end
	return found
end

return M
