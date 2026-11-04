-- Fair warning, the way a table does it (the playtest, November 3: "the fair warning system is
-- confusing... make it feel more like a real TTRPG session"). A warning is about a thing, not a
-- point in a bank: the pond has something with tentacles in it, and Flitwidget said so. The DM
-- warns the way DMs do: describes the danger before they commit ("the water ripples as Pip leans
-- in"), asks "Are you sure?" when someone goes for something risky, or lets them find out (a
-- sign, a look round, an option that says they know). When something harsh happens, the table
-- asks one question: did we know? Warned, it lands as fair. A die rolled in the open is fair on
-- its own. Unwarned, it came out of nowhere. And a DM who warns about everything drains the
-- suspense. How harsh the museum gets is agreed at Session Zero (table rules: harsh). Pure Lua.
--
-- campaign.adv.warned = { [key] = { what, how = "told" | "asked" | "found" | "knew", week, room } }

local util = require "game.model.util"
local score = require "game.model.score"

local M = {}

M.TOO_MANY = 3          -- warnings you give in one night before the table starts to roll its eyes
M.HOW = { told = "you described the danger", asked = "you asked \"Are you sure?\"", found = "they found out for themselves",
          knew = "they knew what they were walking into" }

local function list(campaign)
    campaign.adv = campaign.adv or {}
    campaign.adv.warned = campaign.adv.warned or {}
    return campaign.adv.warned
end

-- The table's agreement: gentle | fair | brutal (Session Zero; fair when it never came up).
function M.dial(campaign)
    local r = campaign.table and campaign.table.rules
    return (r and r.harsh) or "fair"
end

-- They know about this now. key: the thing (a moment's id); what: what they know, in words.
-- by_dm: a warning you gave (it counts toward too many).
function M.warn(night, key, what, how)
    if not key then
        return nil
    end
    local campaign = night.campaign
    local w = list(campaign)
    if w[key] then
        return w[key]
    end
    local sc = night.scene
    local rec = { what = what or "a danger", how = how or "told", week = campaign.week or 0, room = sc and sc.room or nil }
    w[key] = rec
    if how == "told" or how == "asked" then
        night.warns_tonight = (night.warns_tonight or 0) + 1
        if night.warns_tonight > M.TOO_MANY then
            -- (Warn about everything and nothing feels dangerous any more.)
            night:apply({ { "arch:butt_kicker", fun = -1, challenge = -2 }, { "arch:explorer", fun = -1 } })
            if not night.warn_sigh then
                night.warn_sigh = true
                local q = night:pick_actor({ "butt_kicker", "explorer", "instigator" })
                if q then
                    night:emit({ kind = "say", who = q.key, text = "Okay, we get it. Everything in here wants to kill us.", ic = false })
                end
            end
        end
    end
    night:emit({ kind = "warning", key = key, what = rec.what, how = rec.how, count = M.count(campaign) })
    return rec
end

-- Between nights (a chat answer, a favour): they know now, with no night to tell it in.
function M.note(campaign, key, what, how)
    if not key then
        return nil
    end
    local w = list(campaign)
    if not w[key] then
        w[key] = { what = what or "a danger", how = how or "told", week = campaign.week or 0 }
    end
    return w[key]
end

function M.warned(campaign, key)
    return key and list(campaign)[key] or nil
end

function M.count(campaign)
    local n = 0
    for _ in pairs(list(campaign)) do
        n = n + 1
    end
    return n
end

-- What they've been warned about, newest first: { { key, what, how, week } }.
function M.all(campaign)
    local out = {}
    for k, r in pairs(list(campaign)) do
        table.insert(out, { key = k, what = r.what, how = r.how, week = r.week or 0 })
    end
    table.sort(out, function(a, b)
        if a.week ~= b.week then
            return a.week > b.week
        end
        return a.key < b.key
    end)
    return out
end

-- Something harsh just happened (key: the thing it came from). Does it land as fair?
-- Returns "warned" | "open" (a die everyone saw) | "brutal" (the table signed up for it) | nil.
function M.judge(night, key)
    local campaign = night.campaign
    if M.warned(campaign, key) then
        return "warned"
    end
    if night.last_roll_where == "open" and night.last_roll_fresh then
        return "open"
    end
    if M.dial(campaign) == "brutal" then
        return "brutal"
    end
    return nil
end

-- The hover's words: what they know, a few things.
function M.summary(campaign, n)
    local out = {}
    for i, r in ipairs(M.all(campaign)) do
        if i > (n or 5) then
            break
        end
        table.insert(out, util.capitalize(r.what) .. " (" .. (M.HOW[r.how] or r.how) .. ")")
    end
    return out
end

return M
