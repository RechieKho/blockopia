-- Accounts, keyed by the Keycloak subject (player:get_login().subject), never by player name.
-- With the engine started without auth (--insecure-skip-auth) there is no login, and the account
-- key is "dev:<name>" instead.
local store = require("game.store")
local ledger = require("game.ledger")
local util = require("lib.util")
local balance = require("data.balance")

local M = {}

local live = {} -- player name -> account (only while the player is connected)
local online = {} -- player name -> Player handle
local by_subject = {} -- subject -> account, for accounts that are connected

local function account_key(subject)
	return "account:" .. subject
end

local function sanitize_int(v, default)
	return util.int(v) or default
end

local function group_set(login)
	local groups = {}
	local claim = login and login.claims and login.claims.groups
	if type(claim) == "table" then
		for _, g in ipairs(claim) do
			if type(g) == "string" then
				groups[g:gsub("^/", "")] = true
			end
		end
	end
	return groups
end

-- Called from the pre-join event. Returns false when the account is banned.
function M.on_join(name, login)
	local subject = login and login.subject or ("dev:" .. name)
	local bans = store.get("bans") or {}
	if bans[subject] then
		return false
	end
	local rec = store.get(account_key(subject))
	local fresh = rec == nil
	if fresh then
		rec = {
			subject = subject, coins = balance.start_coins, inventory = {}, stats = {},
			found = {}, recipes = {}, created = store.now(), starter_given = false,
		}
	end
	rec.coins = sanitize_int(rec.coins, 0)
	rec.name = name
	rec.groups = group_set(login)
	rec.fresh = fresh
	rec.found = rec.found or {}
	rec.recipes = rec.recipes or {}
	rec.stats = rec.stats or {}
	rec.inventory = rec.inventory or {}
	rec.ready = false
	if live[name] then
		return false
	end
	live[name] = rec
	by_subject[subject] = rec
	-- name -> subject index, so locks can be shared by display name
	local names = store.get("names") or {}
	names[name:lower()] = subject
	store.set("names", names)
	if fresh then
		M.save(rec)
		ledger.log("mint", { to = subject, coins = rec.coins, note = "starting coins" })
	end
	return true
end

function M.of(player)
	return live[player:get_name()]
end

function M.of_name(name)
	return live[name]
end

function M.online(name)
	return online[name]
end

function M.each_online()
	return pairs(online)
end

function M.set_online(player)
	online[player:get_name()] = player
end

function M.subject_of_name(name)
	local acc = live[name]
	if acc then
		return acc.subject
	end
	local names = store.get("names") or {}
	return names[name:lower()]
end

function M.display_name_of(subject)
	local acc = by_subject[subject]
	if acc then
		return acc.name
	end
	local rec = store.get(account_key(subject))
	return rec and rec.name or subject
end

function M.save(acc)
	local copy = {}
	for k, v in pairs(acc) do
		if k ~= "ready" and k ~= "fresh" then
			copy[k] = v
		end
	end
	store.set(account_key(acc.subject), copy)
end

function M.is_mod(acc)
	return acc ~= nil and (acc.groups.moderators == true or acc.groups.admins == true)
end

function M.is_admin(acc)
	return acc ~= nil and acc.groups.admins == true
end

-- Snapshot of the engine inventory into the account (the engine does not persist it).
function M.snapshot_inventory(player, acc)
	local list = {}
	for _, slot in ipairs(player:get_inventory()) do
		if slot.item ~= 0 and slot.count > 0 then
			list[#list + 1] = { item = slot.item, count = slot.count }
		end
	end
	acc.inventory = list
end

function M.on_leave(player)
	local name = player:get_name()
	local acc = live[name]
	if acc then
		if acc.ready then
			M.snapshot_inventory(player, acc)
		end
		M.save(acc)
		by_subject[acc.subject] = nil
	end
	live[name] = nil
	online[name] = nil
end

-- Coins. All changes go through here so they are logged.
function M.add_coins(acc, amount, kind, note)
	acc.coins = acc.coins + amount
	if kind == "break" then
		-- breaking blocks is by far the most frequent mint; log it in aggregate instead of per punch
		local eco = store.get("meta:economy") or { minted = 0, burned = 0 }
		eco.minted = (eco.minted or 0) + amount
		store.set("meta:economy", eco)
	else
		ledger.log(kind or "mint", { to = acc.subject, coins = amount, note = note })
	end
	return acc.coins
end

function M.spend_coins(acc, amount, kind, note)
	if amount < 0 or acc.coins < amount then
		return false
	end
	acc.coins = acc.coins - amount
	ledger.log(kind or "burn", { from = acc.subject, coins = amount, note = note })
	return true
end

function M.discover(acc, key)
	if not acc.found[key] then
		acc.found[key] = true
		return true
	end
	return false
end

return M
