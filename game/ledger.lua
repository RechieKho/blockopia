-- Append-only audit log of every coin and item transfer. Moderators read it with !ledger.
-- Entries are kept in a ring of `balance.ledger_keep` db keys.
local store = require("game.store")
local balance = require("data.balance")

local M = {}

local head -- number of entries ever written

local function load_head()
	if not head then
		head = math.floor(store.get("ledger:head") or 0)
	end
end

-- kind: "mint" | "burn" | "break" | "trade" | "vend" | "store" | "admin"
-- fields: from, to (subjects or labels), coins, items = { { name, count } }, note
function M.log(kind, fields)
	load_head()
	head = head + 1
	local entry = { n = head, t = store.now(), kind = kind }
	for k, v in pairs(fields or {}) do
		entry[k] = v
	end
	store.set("ledger:" .. (head % balance.ledger_keep), entry)
	store.set("ledger:head", head)
	if kind == "mint" or kind == "burn" then
		local eco = store.get("meta:economy") or { minted = 0, burned = 0 }
		local key = kind == "mint" and "minted" or "burned"
		eco[key] = (eco[key] or 0) + (entry.coins or 0)
		store.set("meta:economy", eco)
	end
	return entry
end

-- Newest first, at most `count` entries.
function M.recent(count)
	load_head()
	local out = {}
	local first = math.max(1, head - balance.ledger_keep + 1)
	for n = head, first, -1 do
		if #out >= count then
			break
		end
		local e = store.get("ledger:" .. (n % balance.ledger_keep))
		if e and math.floor(e.n) == n then
			out[#out + 1] = e
		end
	end
	return out
end

function M.economy()
	return store.get("meta:economy") or { minted = 0, burned = 0 }
end

function M.format(e)
	local parts = { string.format("#%d %s", e.n, e.kind) }
	if e.from then
		parts[#parts + 1] = "from " .. tostring(e.from)
	end
	if e.to then
		parts[#parts + 1] = "to " .. tostring(e.to)
	end
	if e.coins and e.coins ~= 0 then
		parts[#parts + 1] = string.format("%d coins", e.coins)
	end
	for _, it in ipairs(e.items or {}) do
		parts[#parts + 1] = string.format("%dx %s", it[2], it[1])
	end
	if e.note then
		parts[#parts + 1] = "(" .. e.note .. ")"
	end
	return table.concat(parts, " ")
end

return M
