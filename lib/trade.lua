-- Two-party trade state machine. Pure: the caller checks balances and moves the goods.
-- Any change to an offer clears both accept flags, so nobody confirms something they have not seen.
local M = {}

function M.new(a, b)
	return {
		parties = { a, b },
		offers = { [a] = { items = {}, coins = 0 }, [b] = { items = {}, coins = 0 } },
		accepted = { [a] = false, [b] = false },
		confirmed = { [a] = false, [b] = false },
	}
end

function M.other(t, who)
	if t.parties[1] == who then
		return t.parties[2]
	end
	return t.parties[1]
end

function M.has_party(t, who)
	return t.offers[who] ~= nil
end

local function reset(t)
	for _, p in ipairs(t.parties) do
		t.accepted[p] = false
		t.confirmed[p] = false
	end
end

-- Sets how many of `item` `who` offers (0 removes it).
function M.set_item(t, who, item, count)
	local offer = t.offers[who]
	if not offer or count < 0 then
		return false
	end
	offer.items[item] = count > 0 and count or nil
	reset(t)
	return true
end

function M.set_coins(t, who, coins)
	local offer = t.offers[who]
	if not offer or coins < 0 then
		return false
	end
	offer.coins = coins
	reset(t)
	return true
end

function M.accept(t, who)
	if not t.offers[who] then
		return false
	end
	t.accepted[who] = true
	return true
end

function M.both_accepted(t)
	return t.accepted[t.parties[1]] and t.accepted[t.parties[2]]
end

-- Confirm only counts once both have accepted.
function M.confirm(t, who)
	if not M.both_accepted(t) or not t.offers[who] then
		return false
	end
	t.confirmed[who] = true
	return true
end

function M.ready(t)
	return t.confirmed[t.parties[1]] and t.confirmed[t.parties[2]]
end

-- Offers as a sorted list for display: { { item, count }, ... }
function M.item_list(t, who)
	local list = {}
	for item, count in pairs(t.offers[who].items) do
		list[#list + 1] = { item = item, count = count }
	end
	table.sort(list, function(p, q)
		return p.item < q.item
	end)
	return list
end

return M
