-- Vending machine arithmetic. Pure. A machine sells whole bundles: `bundle` items for `price` coins.
-- ("5 coins per item" is bundle 1, price 5; "1 coin per 10 items" is bundle 10, price 1.)
local M = {}

-- machine = { item, stock, bundle, price, till }. Returns cost, or nil and a reason.
function M.quote(machine, bundles)
	if not machine.item or machine.item == 0 then
		return nil, "this machine is not set up yet"
	end
	if bundles < 1 or bundles ~= math.floor(bundles) then
		return nil, "choose at least one bundle"
	end
	if bundles * machine.bundle > machine.stock then
		return nil, "not enough stock"
	end
	return bundles * machine.price
end

-- Applies a purchase. Returns the number of items sold, or nil and a reason; nothing changes on failure.
function M.sell(machine, bundles, buyer_coins)
	local cost, why = M.quote(machine, bundles)
	if not cost then
		return nil, why
	end
	if buyer_coins < cost then
		return nil, "you need " .. cost .. " coins"
	end
	local items = bundles * machine.bundle
	machine.stock = machine.stock - items
	machine.till = machine.till + cost
	return items, cost
end

function M.validate_terms(bundle, price, max_price)
	if type(bundle) ~= "number" or bundle < 1 or bundle > 200 or bundle ~= math.floor(bundle) then
		return false, "bundle size must be 1-200"
	end
	if type(price) ~= "number" or price < 1 or price > max_price or price ~= math.floor(price) then
		return false, "price must be 1-" .. max_price .. " coins"
	end
	return true
end

return M
