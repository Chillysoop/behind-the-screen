-- Fun failure (M8, B2): the fail fan, roll mood, dice jail, player-framed fails, table
-- reputations and defeat scenes. game/data/fails.lua has the cards and numbers; game night
-- (game/model/night.lua, big_roll) deals the fan when a big roll misses. Pure Lua.

local content = require "game.model.content"
local score = require "game.model.score"
local stale = require "game.model.stale"
local util = require "game.model.util"
local data = require "game.data.fails"

local M = {}
M.data = data

-- The roller's Fun right now, in bands (the Terms table's "roll mood").
function M.roll_mood(p)
    local f = score.fun(p)
    if f < data.MOOD.low then
        return "low", f
    elseif f >= data.MOOD.high then
        return "high", f
    end
    return "mid", f
end

function M.action(skill)
    return data.ACTION[skill] or "know"
end

-- A solemn moment: a hero's own backstory, the arc's serious week, a set piece, or someone
-- down. A pratfall here costs Trust with the people who care about the story.
function M.solemn(night, sc)
    if not sc then
        return false
    end
    for _, c in pairs(sc.comps or {}) do
        if c.thread and not night:muted(c) then
            return true
        end
    end
    local beat = night.campaign:arc_beat()
    if beat and beat.pressure and (beat.pressure.tone or 0) >= 20 then
        return true
    end
    if night.campaign.table and night.campaign.table.tone == "grim" then
        return true
    end
    return sc.type == "set_piece"
end

local function props_for(sc)
    local loc = sc and sc.comps and sc.comps.location
    for _, set in ipairs(loc and loc.setting or {}) do
        if data.PROPS[set] then
            return data.PROPS[set]
        end
    end
    return data.PROPS.default
end

-- The records kept on the campaign: lines used (for staleness) and each player's fails.
function M.get(campaign)
    campaign.fails = campaign.fails or { lines = {}, record = {}, rep = {}, jail = {} }
    return campaign.fails
end

local function line_key(kind, act, i)
    return kind .. ":" .. (act or "any") .. ":" .. i
end

-- A line of this kind for this action, fitted to the scene, and not used in the last weeks.
-- Somewhere with walls and doors, and whether there's anything to fight (playtest, October 13:
-- "the doors seal" on a forest road, "the creature" in front of a secret door).
local INSIDE = { tavern = true, shop = true, indoor = true, under = true, bells = true, ship = true }

local function inside(sc)
    local loc = sc and sc.comps and sc.comps.location
    for _, set in ipairs(loc and loc.setting or {}) do
        if INSIDE[set] then
            return true
        end
    end
    return false
end

local function has_foe(sc)
    if not sc then
        return false
    end
    if sc.type == "combat" or sc.type == "set_piece" then
        return true
    end
    local cast = sc.comps and sc.comps.cast
    return cast ~= nil and cast.foe == true
end

local function pick_line(night, kind, act, has_cast, sc)
    local f = M.get(night.campaign)
    local pool, keys = {}, {}
    local list = kind == "pratfall" and data.LINES.pratfall or (data.LINES[kind] and data.LINES[kind][act]) or {}
    local walls, foe = inside(sc), has_foe(sc)
    for i, l in ipairs(list) do
        local ok = (not l.act or l.act == act) and (has_cast or not l.cast) and (walls or not l.inside) and (foe or not l.foe)
        local key = line_key(kind, kind == "pratfall" and "any" or act, i)
        local rec = f.lines[key]
        if ok and not (rec and stale.too_soon(rec, night.campaign.week, 3)) and not (night.fail_used and night.fail_used[key]) then
            table.insert(pool, l)
            table.insert(keys, key)
        end
    end
    if #pool == 0 then
        return nil
    end
    local i = night.rng:int(1, #pool)
    return pool[i][1], keys[i]
end

-- How much each kind suits this table and this moment.
local function weights(night, p, sc, tier, solemn)
    local w = { pratfall = 1, forward = 1.2, costly = 1, dramatic = 1, near = tier == "near" and 2.2 or 0.5 }
    for _, q in ipairs(night.players) do
        local function arch(a) return score.arch(q, a) end
        w.pratfall = w.pratfall + 0.5 * (arch("instigator") + arch("casual"))
        w.dramatic = w.dramatic + 0.5 * arch("storyteller") + 0.3 * arch("butt_kicker")
        w.forward = w.forward + 0.3 * (arch("explorer") + arch("storyteller"))
        w.costly = w.costly + 0.4 * (arch("tactician") + arch("power_gamer"))
    end
    if solemn then
        w.pratfall = w.pratfall * 0.25
        w.dramatic = w.dramatic * 1.4
    end
    if p and p.primary == "tactician" then
        w.pratfall = w.pratfall * 0.5
    end
    if tier == "flop" then
        w.dramatic = w.dramatic * 1.3
        w.pratfall = w.pratfall * 1.3
    end
    -- A reputation the table expects comes up more (it lands bigger, too).
    local rep = p and M.get(night.campaign).rep[p.key]
    if rep and w[rep.kind] then
        w[rep.kind] = w[rep.kind] * 1.6
    end
    return w
end

-- The fan for a missed big roll: three cards fitted to the scene, then the flat fail, then (Trust
-- 75+) the player's own idea. Each: { kind, label, text, key, tone }.
function M.fan(night, p, skill, sc, tier, act)
    act = act or M.action(skill)
    local cast = sc and sc.comps and night:shown_cast(sc)
    local solemn = M.solemn(night, sc)
    local w = weights(night, p, sc, tier, solemn)
    local props = props_for(sc)
    local others = {}
    for _, q in ipairs(night.players) do
        if q ~= p then
            table.insert(others, q)
        end
    end
    local other = #others > 0 and others[night.rng:int(1, #others)] or p
    local vars = night:vars({ char = p and p.char or "They", other_char = other and other.char or "someone",
                              place = sc and sc.comps.location and (sc.comps.location.short or util.lower_first(sc.comps.location.name))
                                  or "here",
                              prop = props[night.rng:int(1, #props)] })
    vars.cost = util.fill(data.COSTS[night.rng:int(1, #data.COSTS)], vars)
    local cards, used = {}, {}
    local kinds = {}
    for _, k in ipairs(data.KINDS) do
        table.insert(kinds, k)
    end
    while #cards < 3 and #kinds > 0 do
        local wl = {}
        for i, k in ipairs(kinds) do
            wl[i] = w[k] or 0.1
        end
        local idx = {}
        for j = 1, #kinds do
            idx[j] = j
        end
        local kind = table.remove(kinds, night.rng:weighted(idx, wl))
        local text, key = pick_line(night, kind, act, cast ~= nil, sc)
        if text then
            text = util.sentence_case(util.fill(text, vars))
            used[kind] = true
            table.insert(cards, { kind = kind, text = text, key = key, solemn = solemn and kind == "pratfall",
                                  label = data.NAMES[kind] .. ": " .. text,
                                  tone = (kind == "dramatic" and "bad") or ((kind == "forward" or kind == "near" or kind == "pratfall") and "good")
                                      or "twist" })
        end
    end
    table.insert(cards, { kind = "flat", text = "It just doesn't work.", label = "No. It just doesn't work." })
    -- Trust 75 and up: they ask to describe their own fail.
    if p and (p.trust or 0) >= data.FRAME_TRUST then
        local list = data.FRAMED[act] or data.FRAMED.know
        local pair = list[night.rng:int(1, #list)]
        local idea = util.fill(pair[1], vars)
        -- When you let them, the table hears what happens (not the question again).
        local told = p.name .. " tells it: " .. util.fill(pair[2], vars)
        table.insert(cards, { kind = "framed", text = told, ask = idea, label = p.name .. " asks: \"" .. idea .. "\" Let them.",
                              tone = "good" })
    end
    return cards, act
end

-- Play the card the DM picked. Returns success (which branch of the roll plays).
function M.play(night, p, card, fan, tier)
    local f = M.get(night.campaign)
    local def = data.EFFECTS[card.kind] or data.EFFECTS.flat
    night.fail_used = night.fail_used or {}
    if card.key then
        night.fail_used[card.key] = true
        f.lines[card.key] = f.lines[card.key] or { born = night.campaign.week }
        stale.use(f.lines[card.key], night.campaign.week)
    end
    -- A reputation lands bigger (GDD Reputations).
    local rep = p and f.rep[p.key]
    local big = rep and rep.kind == card.kind
    local fx = def.effects
    if big then
        fx = {}
        for _, e in ipairs(def.effects) do
            local e2 = {}
            for k, v in pairs(e) do
                e2[k] = (type(v) == "number") and v * 1.5 or v
            end
            table.insert(fx, e2)
        end
    end
    night:apply(fx)
    if p then
        if card.kind == "pratfall" and p.primary == "tactician" then
            score.add(p, "fun", data.TACTICIAN_PRATFALL)
        end
        if card.kind == "pratfall" and card.solemn then
            night:apply({ { "arch:storyteller", trust = data.SOLEMN_TRUST }, { "arch:method_actor", trust = data.SOLEMN_TRUST } })
        end
        if card.kind == "near" then
            night.edge_next = night.edge_next or {}
            night.edge_next[p.key] = def.edge
        end
        if card.kind == "flat" then
            night.flat_fails = night.flat_fails or {}
            night.flat_fails[p.key] = (night.flat_fails[p.key] or 0) + 1
            local mood = M.roll_mood(p)
            if night.flat_fails[p.key] > data.FLAT_FREE and mood == "high" then
                mood = "mid"
            end
            for k, v in pairs(data.FLAT_BY_MOOD[mood] or {}) do
                score.add(p, k, v)
            end
        end
        -- They offered their own fail and you went another way.
        for _, c in ipairs(fan or {}) do
            if c.kind == "framed" and c ~= card then
                score.add(p, "fun", data.VETO_FUN)
            end
        end
        if card.kind ~= "flat" then
            M.record(night, p, card)
        end
    end
    local said = card.text or ""
    if p and not string.find(said, p.char, 1, true) then
        said = p.char .. ": " .. said
    end
    night:event("fail_card", { who = p and p.key or "party", kind = card.kind, text = said, weight = big and 6 or 4 })
    return def.success
end

-- A fail that landed well, toward a reputation: five of one kind over three sessions or more.
function M.record(night, p, card)
    local f = M.get(night.campaign)
    local week = night.campaign.week
    f.record[p.key] = f.record[p.key] or {}
    local r = f.record[p.key][card.kind] or { n = 0, weeks = {} }
    f.record[p.key][card.kind] = r
    r.n = r.n + 1
    r.last = week
    if not util.contains(r.weeks, week) then
        table.insert(r.weeks, week)
    end
    local rep = f.rep[p.key]
    if r.n >= 5 and #r.weeks >= 3 and not (rep and rep.kind == card.kind) then
        local title = M.TITLES[card.kind]
        if title then
            f.rep[p.key] = { kind = card.kind, title = title, since = week,
                             embraced = (p.primary == "instigator" or p.primary == "casual" or p.primary == "method_actor") }
            night:event("reputation", { who = p.key, text = p.char .. " is " .. title .. " now. The table expects it.", weight = 7 })
            night:say(p.char .. " has a reputation now: " .. title .. ".", "system")
        end
    end
end

M.TITLES = { pratfall = "the klutz", dramatic = "the doomed hero", forward = "the one with a backup plan",
             costly = "the one who always pays for it", near = "so close, every time" }

-- Start of a week: reputations fade when the fails stop; one a player hates rubs.
function M.start_week(campaign)
    local f = M.get(campaign)
    for key, rep in pairs(f.rep) do
        local r = f.record[key] and f.record[key][rep.kind]
        if not r or campaign.week - (r.last or rep.since) > 6 then
            f.rep[key] = nil
        elseif not rep.embraced then
            local p = campaign:player(key)
            if p and not p.on_break then
                score.add(p, "commitment", -1)
            end
        end
    end
end

-- The reputation line for a player, or nil.
function M.reputation(campaign, key)
    local rep = M.get(campaign).rep[key]
    return rep and (rep.title .. (rep.embraced and "" or " (and not happy about it)")) or nil
end

-- A natural 1 goes to dice jail: the die sits in the cup on the table, and everyone laughs.
function M.jail(night, p)
    local f = M.get(night.campaign)
    f.jail[p.key] = (f.jail[p.key] or 0) + 1
    night:apply({ { "all", social = data.JAIL_SOCIAL } })
    night:event("jail", { who = p.key, text = p.name .. "'s d20 goes to dice jail.", weight = 3 })
    night:emit({ kind = "jail", who = p.key })
end

-- A lost fight's defeat scene, fitted to the place.
function M.defeat(night, sc)
    local loc = sc and sc.comps.location
    -- A second lost fight in one night can't end somewhere else entirely (October 15: "wake up in a
    -- cell" and "come to in the mud" in one recap): the night goes on, so only the endings that
    -- leave the party where they were.
    local again = night.defeated
    -- Nobody claims "everyone's alive" over a hero who just died (October 15).
    local died = false
    for _, d in ipairs(night.campaign.deaths or {}) do
        died = died or d.week == night.campaign.week
    end
    local pool = {}
    for _, d in ipairs(data.DEFEATS) do
        local fits = not d.where
        for _, set in ipairs(d.where or {}) do
            fits = fits or (loc and util.contains(loc.setting or {}, set))
        end
        local seen = night.campaign.defeats_seen and night.campaign.defeats_seen[d.id]
        if fits and not seen and (not again or data.STAY_PUT[d.id]) and not (died and d.alive) then
            table.insert(pool, d)
        end
    end
    if #pool == 0 then
        night.campaign.defeats_seen = {}
        for _, d in ipairs(data.DEFEATS) do
            if (not again or (data.STAY_PUT[d.id] and d.id ~= again)) and not (died and d.alive) then
                table.insert(pool, d)
            end
        end
    end
    local d = pool[night.rng:int(1, #pool)]
    night.defeated = d.id
    night.campaign.defeats_seen = night.campaign.defeats_seen or {}
    night.campaign.defeats_seen[d.id] = night.campaign.week
    return d
end

return M
