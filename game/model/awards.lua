-- Table awards (M9's scrapbook awards, in the slice): at the end of the first act the table hands
-- out superlatives, one per player, from what actually happened. The counts come from two places:
-- the notebook's ledger (the one event log: downs, natural 20s, dice jail, clues, conversations,
-- jokes, curveballs, moments) and the night's own tallies of each hero's fights and in-character
-- lines, filed once a night is finished so a replayed night never counts twice. The awards are
-- game/data/awards.lua. Pure Lua.

local data = require "game.data.awards"
local ledger = require "game.model.ledger"
local util = require "game.model.util"

local M = {}
M.data = data

-- Conversations that went their way (the ledger's acts): a talker's award.
local TALK = { persuasion = true, deception = true, performance = true, history = true, intimidation = true,
               talk_warm = true }

local function tally(night, key)
    night.tallies = night.tallies or {}
    local t = night.tallies[key]
    if not t then
        t = { dealt = 0, healed = 0, taken = 0, kills = 0, ic = 0 }
        night.tallies[key] = t
    end
    return t
end

-- After a fight: what each hero did in it.
function M.after_fight(night)
    for _, c in ipairs(night.pc_list or {}) do
        if c.player_key and c.stats then
            local t = tally(night, c.player_key)
            t.dealt = t.dealt + (c.stats.dealt or 0)
            t.healed = t.healed + (c.stats.healed or 0)
            t.taken = t.taken + (c.stats.taken or 0)
            t.kills = t.kills + (c.stats.kills or 0)
            -- (critical hits are in the event log already, with the natural 20s on checks)
        end
    end
end

-- A line said in character at the table.
function M.heard(night, ev)
    if ev.kind == "say" and ev.ic and ev.who and night.campaign:player(ev.who) then
        local t = tally(night, ev.who)
        t.ic = t.ic + 1
    end
end

-- The night's done: its tallies join the campaign's.
function M.after_night(campaign, night)
    campaign.tallies = campaign.tallies or {}
    for key, t in pairs(night.tallies or {}) do
        local into = campaign.tallies[key] or {}
        campaign.tallies[key] = into
        for k, v in pairs(t) do
            into[k] = (into[k] or 0) + v
        end
    end
end

-- Everything an award can be for, by player: { [key] = { dealt, healed, ..., clues, talked } }.
function M.stats(campaign)
    local out = {}
    for _, p in ipairs(campaign.players) do
        local t = (campaign.tallies or {})[p.key] or {}
        out[p.key] = { dealt = t.dealt or 0, healed = t.healed or 0, taken = t.taken or 0, kills = t.kills or 0,
                       ic = t.ic or 0, crits = 0, downs = 0, jail = 0, clues = 0, talked = 0, warmth = 0,
                       curveballs = 0, jokes = 0, moments = 0 }
    end
    for _, e in ipairs(ledger.get(campaign).log) do
        local s = out[e.who]
        if s then
            if e.ev == "down" then
                s.downs = s.downs + 1
            elseif e.ev == "crit" then
                s.crits = s.crits + 1
            elseif e.ev == "jail" then
                s.jail = s.jail + 1
            elseif e.ev == "clue" then
                s.clues = s.clues + 1
            elseif e.ev == "curveball" then
                s.curveballs = s.curveballs + 1
            elseif e.ev == "joke" then
                s.jokes = s.jokes + 1
            elseif e.ev == "moment" or e.ev == "killing_blow" or e.ev == "villain_falls" then
                s.moments = s.moments + 1
            elseif e.did and TALK[e.did] and e.ok ~= false then
                s.talked = s.talked + 1
            end
        end
    end
    -- Who the Vale likes: every warm word anyone has for them.
    for pid in pairs(ledger.get(campaign).people or {}) do
        for _, w in ipairs(ledger.warmth(campaign, pid)) do
            if out[w.key] and w.n > 0 then
                out[w.key].warmth = out[w.key].warmth + w.n
            end
        end
    end
    return out
end

local function fell(campaign, key)
    for _, rec in ipairs(campaign.fallen or {}) do
        if rec.key == key then
            return true
        end
    end
    return false
end

-- One award each: the clearest lead first (a player's share of the table's total, and how much
-- the table likes giving it), every award to one player only, and a fallback by who they are for
-- anyone who led at nothing. Returns { [key] = { id, title, reason, n } } and the order handed out.
function M.pick(campaign)
    local stats = M.stats(campaign)
    local cands = {}
    for _, id in ipairs(data.order) do
        local a = data[id]
        local total, best, second, who = 0, -1, -1, nil
        for _, p in ipairs(campaign.players) do
            local v = stats[p.key][a.stat] or 0
            total = total + v
            if v > best then
                second, best, who = best, v, p.key
            elseif v > second then
                second = v
            end
        end
        -- A clear winner only: at least the minimum, and ahead of everyone else.
        if who and best >= a.min and best > second then
            table.insert(cands, { id = id, key = who, n = best, score = (best / math.max(1, total)) * (a.weight or 1) })
        end
    end
    table.sort(cands, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.id < b.id
    end)
    local out, taken, order = {}, {}, {}
    for _, c in ipairs(cands) do
        if not out[c.key] and not taken[c.id] then
            local a = data[c.id]
            local p = campaign:player(c.key)
            local reason = (a.alive_reason and not fell(campaign, c.key)) and a.alive_reason or a.reason
            if c.n == 1 and a.reason_one then
                reason = a.reason_one
            end
            out[c.key] = { id = c.id, title = a.title, n = c.n,
                           reason = util.fill(reason, { n = util.int(c.n), char = p and p.char or "" }) }
            taken[c.id] = true
            table.insert(order, c.key)
        end
    end
    local used = {}
    for _, p in ipairs(campaign.players) do
        if not out[p.key] then
            local fb = data.fallback[p.primary] or data.fallback.default
            if used[fb.title] then
                fb = data.fallback.default
            end
            used[fb.title] = true
            out[p.key] = { id = "fallback", title = fb.title, reason = fb.reason }
            table.insert(order, p.key)
        else
            used[out[p.key].title] = true
        end
    end
    return out, order
end

return M
