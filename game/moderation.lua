-- Moderator and admin tools. Roles come from Keycloak groups: "moderators" and "admins".
local store = require("game.store")
local accounts = require("game.accounts")
local ledger = require("game.ledger")
local locks = require("game.locks")
local notify = require("game.notify")

local M = {}

local muted = {} -- subject -> true (kept in memory; mutes last until restart)

function M.is_muted(acc)
	return acc ~= nil and muted[acc.subject] == true
end

function M.ban(by, target_name, reason)
	local subject = accounts.subject_of_name(target_name)
	if not subject then
		notify.say(by, "Unknown player '" .. target_name .. "'.")
		return
	end
	local bans = store.get("bans") or {}
	bans[subject] = { name = target_name, reason = reason or "", by = accounts.of(by).subject }
	store.set("bans", bans)
	ledger.log("admin", { from = accounts.of(by).subject, to = subject, note = "ban: " .. (reason or "") })
	notify.say(by, target_name .. " is banned. The ban applies the next time they join.")
end

function M.unban(by, target_name)
	local subject = accounts.subject_of_name(target_name)
	local bans = store.get("bans") or {}
	if subject and bans[subject] then
		bans[subject] = nil
		store.set("bans", bans)
		ledger.log("admin", { from = accounts.of(by).subject, to = subject, note = "unban" })
		notify.say(by, target_name .. " is unbanned.")
	else
		notify.say(by, target_name .. " is not banned.")
	end
end

function M.mute(by, target_name, on)
	local subject = accounts.subject_of_name(target_name)
	if not subject then
		notify.say(by, "Unknown player '" .. target_name .. "'.")
		return
	end
	muted[subject] = on or nil
	notify.say(by, target_name .. (on and " is muted." or " is unmuted."))
end

function M.show_ledger(by, count)
	count = math.min(math.max(count or 10, 1), 30)
	local eco = ledger.economy()
	notify.say(by, string.format("Coins minted: %d, burned: %d", eco.minted or 0, eco.burned or 0))
	for _, e in ipairs(ledger.recent(count)) do
		notify.say(by, ledger.format(e))
	end
end

function M.remove_lock(by, id)
	if locks.force_remove(id) then
		ledger.log("admin", { from = accounts.of(by).subject, note = "force removed lock #" .. id })
		notify.say(by, "Lock #" .. id .. " removed.")
	else
		notify.say(by, "No lock #" .. tostring(id) .. ".")
	end
end

return M
