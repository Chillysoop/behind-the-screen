-- Villains who remember (the villain monologues idea, folded into M8). A villain's ledger is
-- built from the event log (B1): the heroes they killed or knocked down, the backstories their
-- people scarred, the party's defeats and their own escapes and humiliations. Fudged moments
-- never get there: a fudged hit never drops anyone, a fudged save never kills. What the villain
-- says comes from templates (game/data/villains.lua) filled from the ledger.
--
-- Where it plays:
--   the monologue    the villain's "talk as them" takeover (B8): a fan of callbacks, the DM picks;
--                    an interrupt or a second callback is the takeover's second turn (one card)
--   barks            in a fight, on their own, and only light ones (a knockdown, a defeat, a tag)
--   last words       the biggest taunt nobody answered, right before the killing blow
--   the retort       the striker's final hit answers it (the killing blow, B4)
-- A taunt that fits is fuel (Story, Investment, Vendetta); one that doesn't is salt (Trust).
-- Vendetta is the mirror of Grudge: how much a player wants this villain, 0 to 5. Pure Lua.

local content = require "game.model.content"
local score = require "game.model.score"
local util = require "game.model.util"
local ledger = require "game.model.ledger"
local data = require "game.data.villains"

local M = {}
M.data = data

local function state(campaign, pid)
    campaign.villains = campaign.villains or {}
    local s = campaign.villains[pid]
    if not s then
        s = { uses = {}, taunts = {}, vendetta = {}, monologues = {}, interrupted = {} }
        campaign.villains[pid] = s
    end
    return s
end
M.state = state

function M.voice(pid)
    return data.VOICE[pid] or "gloater"
end

-- Is this cast card (person pid) a villain the party is up against?
function M.is_villain(campaign, cast, pid)
    if cast and (cast.revered or cast.talks == false) then
        return false
    end
    if cast and cast.villain then
        return true
    end
    return pid ~= nil and ledger.person(campaign, pid) ~= nil and ledger.att(campaign, pid) <= -2
end

-- The villain in this scene, as a person id, or nil.
function M.present(night, sc)
    local cast = sc and sc.comps.cast
    if not cast or night:muted(cast) then
        return nil
    end
    local pid = ledger.person_of(cast)
    if pid and M.is_villain(night.campaign, cast, pid) then
        return pid
    end
    return nil
end

-- Session Zero's backstory boundary for a player: their own wish, unless the DM changed it.
function M.boundary(campaign, key)
    return (campaign.boundaries and campaign.boundaries[key]) or data.BOUNDARY[key] or "gently"
end

function M.set_boundary(campaign, key, b)
    campaign.boundaries = campaign.boundaries or {}
    campaign.boundaries[key] = b
end

local function place_name(at)
    local c = at and content.components[at]
    if not c then
        return "the last fight"
    end
    return c.short or util.lower_first(c.name)
end

local function faction_members(campaign, fid)
    local out = {}
    if fid then
        for _, m in ipairs(ledger.members(campaign, fid, true) or {}) do
            out[m] = true
        end
    end
    return out
end

-- The ledger: everything this villain was part of. Each entry: id, type, key (the player it's
-- aimed at, or "party"), char (their hero then), fallen, hook, place, count, week, sting.
function M.ledger(campaign, pid, night)
    local out = {}
    local nb = ledger.get(campaign)
    local events = {}
    for _, e in ipairs(nb.log) do
        table.insert(events, e)
    end
    if night and not night.filed then
        for _, e in ipairs(night.ledger or {}) do
            table.insert(events, e)
        end
    end
    local fid = ledger.faction_of(campaign, pid)
    local members = faction_members(campaign, fid)
    members[pid] = true
    local downs = {}
    for _, e in ipairs(events) do
        local week = e.w or campaign.week
        local mine = e.villain == pid
        if e.ev == "down" and mine and e.who ~= "party" then
            local k = e.who .. "|" .. tostring(e.char)
            local d = downs[k] or { type = "knockdown", key = e.who, char = e.char, count = 0 }
            downs[k] = d
            d.count = d.count + 1
            d.week, d.place = week, place_name(e.at)
        elseif e.ev == "defeat" and mine then
            table.insert(out, { type = "defeat", key = "party", week = week, place = place_name(e.at), id = "defeat:" .. week })
        elseif e.ev == "escape" and (e.to == pid or mine) then
            table.insert(out, { type = "escape", key = "party", week = week, place = place_name(e.at), id = "escape:" .. week })
        elseif e.ev == "reputation" and mine then
            table.insert(out, { type = "tag", key = e.who, char = e.char, week = week, id = "tag:" .. e.who .. ":" .. week })
        elseif e.ev == "joke" and mine and e.joke then
            table.insert(out, { type = "joke", key = "party", joke = e.joke, week = week, id = "joke:" .. e.joke })
        elseif e.ev == "thread" and mine and e.who ~= "party" then
            local h = data.HOOKS[e.who]
            if h then
                table.insert(out, { type = "backstory", key = e.who, char = e.char, hook = h.hook, week = week,
                                    place = place_name(e.at), id = "struck:" .. e.who .. ":" .. week })
            end
        elseif not e.ev and e.to and members[e.to] and e.who and (e.did == "beat" or e.did == "exposed" or e.did == "outplayed") then
            table.insert(out, { type = "humiliated", key = e.who, char = e.who ~= "party" and e.char or nil, week = week,
                                place = place_name(e.at), id = "humiliated:" .. e.did .. ":" .. e.to .. ":" .. week })
        end
    end
    for k, d in pairs(downs) do
        d.id = "knockdown:" .. k
        d.repeated = d.count >= 3
        table.insert(out, d)
    end
    -- The heroes they killed, and whether the death was fair (B3: the player's wish honoured,
    -- and a goodbye or a way back).
    for i, rec in ipairs(campaign.deaths or {}) do
        if rec.slain_by == pid then
            table.insert(out, { type = "killed", key = rec.key, fallen = rec.char, week = rec.week, place = place_name(rec.at),
                                fair = rec.fair ~= false, id = "killed:" .. rec.key .. ":" .. i })
        end
    end
    -- Backstories their people scarred before the campaign began.
    for key, h in pairs(data.HOOKS) do
        if fid and util.contains(h.factions or {}, fid) then
            table.insert(out, { type = "backstory", key = key, hook = h.hook, week = 0, pre = true, id = "hook:" .. key })
        end
    end
    -- Being interrupted mid-speech is a humiliation too.
    for i, it in ipairs(state(campaign, pid).interrupted) do
        table.insert(out, { type = "humiliated", key = it.who, char = it.char, week = it.week, place = it.place or "the last fight",
                            id = "interrupted:" .. i })
    end
    for _, en in ipairs(out) do
        en.sting = data.STING[en.type] or 1
        if en.type == "knockdown" then
            en.sting = math.min(data.KNOCKDOWN_CAP, en.sting + (en.count - 1))
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- How fresh an entry still is: used twice tonight goes flat; recently used is worn.
local RECOVER = { killed = 3, backstory = 3 }
function M.freshness(campaign, pid, entry)
    local uses = state(campaign, pid).uses[entry.id] or {}
    local tonight, recent = 0, false
    for _, w in ipairs(uses) do
        if w == campaign.week then
            tonight = tonight + 1
        elseif campaign.week - w <= (RECOVER[entry.type] or 2) then
            recent = true
        end
    end
    if tonight >= 2 then
        return 0
    elseif tonight == 1 or recent then
        return 0.6
    end
    return 1
end

function M.answered(campaign, pid, entry)
    return state(campaign, pid).answered and state(campaign, pid).answered[entry.id] ~= nil
end

local function player(night, key)
    for _, p in ipairs(night.players) do
        if p.key == key then
            return p
        end
    end
    return nil
end

-- Can this entry be aimed at the table now? Its target has to be here, on the same hero (a
-- fallen hero's player is taunted as their new character, with the replacement line).
local function aimable(night, e)
    if e.key == "party" then
        return true
    end
    local p = player(night, e.key)
    if not p then
        return false
    end
    if e.type == "killed" then
        return true
    end
    return e.char == nil or e.char == p.char
end

-- Fill the template for an entry, in the villain's voice.
function M.line(night, pid, e, rng)
    local v = data.LINES[M.voice(pid)] or data.LINES.gloater
    local p = e.key ~= "party" and player(night, e.key)
    local kind = e.type
    if kind == "knockdown" and e.repeated then
        kind = "knockdown_repeat"
    end
    if kind == "killed" and p and p.char ~= e.fallen then
        kind = "replacement"
    end
    local pool = v[kind] or v.generic
    local vars = { char = p and p.char or "you", fallen = e.fallen or "", hook = e.hook or "", place = e.place or "the last fight",
                   count = util.int(e.count or 0), tag = e.tag or "", joke = e.joke or "", week = util.int(e.week or 0) }
    if e.type == "tag" and p then
        local fails = require "game.model.fails"
        local rep = fails.get(night.campaign).rep[p.key]
        vars.tag = rep and rep.title or "the clumsy one"
    end
    local text = util.fill(pool[(rng or night.rng):int(1, #pool)], vars)
    return util.sentence_case(text)
end

-- Fuel or salt: how this entry lands on its target now. Returns { fuel, shift, trust, why }.
function M.fit(night, pid, e)
    local campaign = night.campaign
    local out = { fuel = true, shift = 0, trust = 0 }
    local p = e.key ~= "party" and player(night, e.key)
    if e.type == "killed" and not e.fair then
        out.fuel, out.trust, out.why = false, -2, "a death that wasn't fair"
    end
    if e.type == "backstory" and p then
        local b = M.boundary(campaign, p.key)
        if b == "off" then
            out.fuel, out.trust, out.why = false, -4, "a backstory they asked you to leave alone"
        elseif b == "fair" then
            out.trust = out.trust + 1
        end
    end
    if e.type == "tag" and p then
        local fails = require "game.model.fails"
        local rep = fails.get(campaign).rep[p.key]
        if rep and not rep.embraced then
            out.trust, out.why = out.trust - 1, "a reputation they don't like"
        end
    end
    if p then
        -- Kicking someone who's down.
        local eng = p.engagement or 0.5
        if eng < 0.22 then
            out.shift, out.trust = out.shift - 1, out.trust - 1
            out.why = out.why or "someone already having a bad night"
        elseif eng < 0.35 then
            out.shift = out.shift - 1
        end
        -- What kind of player they are.
        if score.arch(p, "storyteller") >= 1 and (e.type == "killed" or e.type == "backstory") then
            out.shift = out.shift + 1
        end
        local comic = score.arch(p, "instigator") >= 1 or score.arch(p, "method_actor") >= 1
        if comic and e.type == "killed" and M.voice(pid) ~= "petty" then
            out.shift = out.shift - 1
        end
        if comic and (e.type == "tag" or e.type == "joke") and M.voice(pid) == "petty" then
            out.shift = out.shift + 1
        end
    end
    return out
end

local function size(meter, n)
    n = util.clamp(n, 0, 3)
    local t = data.LONG[meter] and data.SIZE.long or data.SIZE.session
    return t[n + 1]
end

local function apply_meters(p, meters, shift)
    for k, v in pairs(meters or {}) do
        local n = v + shift
        if n > 0 then
            score.add(p, k, size(k, n))
        end
    end
end

function M.add_vendetta(campaign, pid, key, n)
    local s = state(campaign, pid)
    s.vendetta[key] = util.clamp((s.vendetta[key] or 0) + n, 0, data.VENDETTA_MAX)
end

function M.vendetta(campaign, pid, key)
    return state(campaign, pid).vendetta[key] or 0
end

-- Apply a callback's effects. mode "full" (a monologue) or "bark" (one size smaller).
-- Returns the fit.
function M.land(night, pid, e, mode)
    local campaign = night.campaign
    local fit = M.fit(night, pid, e)
    local fresh = M.freshness(campaign, pid, e)
    local s = state(campaign, pid)
    s.uses[e.id] = s.uses[e.id] or {}
    table.insert(s.uses[e.id], campaign.week)
    local shift = fit.shift + (mode == "bark" and -1 or 0) + (fresh < 1 and -1 or 0)
    if fresh == 0 then
        shift = -9          -- the third time is a flat line
    end
    local p = e.key ~= "party" and player(night, e.key)
    if p and fit.trust ~= 0 then
        score.add(p, "trust", fit.trust)
    end
    if not fit.fuel then
        if p then
            score.add(p, "fun", -3)
            night:emit({ kind = "say", who = p.key, text = night.rng:pick(data.SALT), ic = false })
            night:react({ [p.key] = "arms" })
        end
        return fit
    end
    local eff = data.EFFECT[e.type] or data.EFFECT.generic
    if p then
        apply_meters(p, eff.target, shift)
    end
    for _, q in ipairs(night.players) do
        if q ~= p then
            apply_meters(q, eff.table, shift)
        end
        apply_meters(q, eff.all, shift)
    end
    if shift > -9 then
        if p and eff.vendetta then
            M.add_vendetta(campaign, pid, p.key, eff.vendetta)
        end
        if p and eff.vendetta_from and (e.count or 0) >= eff.vendetta_from then
            M.add_vendetta(campaign, pid, p.key, 1)
        end
        if eff.vendetta_all then
            for _, q in ipairs(night.players) do
                M.add_vendetta(campaign, pid, q.key, eff.vendetta_all)
            end
        end
    end
    if p and mode == "full" and shift > -9 then
        night:emit({ kind = "say", who = p.key, text = night.rng:pick(data.FUEL), ic = false })
        night:react({ [p.key] = "lean" })
    end
    return fit
end

-- A taunt aimed at someone: kept until a retort answers it.
local function remember_taunt(campaign, pid, e, text)
    if e.key == "party" or e.type == "generic" then
        return
    end
    local s = state(campaign, pid)
    for _, t in ipairs(s.taunts) do
        if t.id == e.id and not t.answered then
            return
        end
    end
    table.insert(s.taunts, { id = e.id, key = e.key, type = e.type, sting = e.sting, week = campaign.week, fallen = e.fallen,
                             hook = e.hook, place = e.place, text = text })
end

-- The callbacks the DM can pick from: biggest sting first, fresh, aimed at someone here.
function M.fan(night, pid, n, skip)
    local campaign = night.campaign
    local list = {}
    for _, e in ipairs(M.ledger(campaign, pid, night)) do
        if not M.answered(campaign, pid, e) and aimable(night, e) and not (skip and skip[e.id]) then
            local f = M.freshness(campaign, pid, e)
            if f > 0 then
                e.score = e.sting * f + night.rng:next()
                table.insert(list, e)
            end
        end
    end
    table.sort(list, function(a, b) return a.score > b.score end)
    local out = {}
    local per = {}
    for _, e in ipairs(list) do
        -- One card per target, so the DM chooses whose wound to press.
        if #out < n and not per[e.key .. e.type] then
            per[e.key .. e.type] = true
            table.insert(out, e)
        end
    end
    local g = 0
    while #out < math.min(n, 3) do
        g = g + 1
        table.insert(out, { type = "generic", key = "party", id = "generic:" .. g, sting = 1 })
    end
    return out
end

local function grudge_tier(g)
    return (g >= 4 and "high") or (g >= 2 and "rising") or "low"
end

-- The card for a set of callbacks: who each is aimed at, the line, and how it'd land.
local function fan_card(night, pid, name, cards, step, extra_option)
    local card = { id = "monologue_" .. pid .. "_" .. step, type = "talk", cast = night.monologue_cast,
                   title = step == 1 and (util.capitalize(name) .. " remembers") or ("And " .. name .. " goes on"),
                   text = step == 1 and ("You're speaking for " .. name .. ". What do they bring up? Whatever you pick, someone at the table takes it personally.")
                       or "Another one, or let it hang?",
                   options = {} }
    for i, e in ipairs(cards) do
        local text = M.line(night, pid, e)
        e.text = text
        local fit = M.fit(night, pid, e)
        local eff = data.EFFECT[e.type] or data.EFFECT.generic
        -- How they'd take it, as faces on the option (never the numbers).
        local preview = {}
        if e.key ~= "party" then
            table.insert(preview, fit.fuel and { "key:" .. e.key, story = 4 } or { "key:" .. e.key, trust = -4 })
        elseif eff.all or eff.table then
            table.insert(preview, { "all", story = 2 })
        end
        local who = e.key ~= "party" and player(night, e.key)
        card.options[i] = { label = (who and (who.name .. ": ") or "") .. "\"" .. text .. "\"", effects = {}, entry = e,
                            preview = preview }
    end
    if extra_option then
        table.insert(card.options, extra_option)
    end
    return card
end

-- The monologue (the villain's takeover). Returns true when it played.
function M.monologue(night, sc, cast, pid)
    local campaign = night.campaign
    local name = cast.short or cast.name
    local s = state(campaign, pid)
    s.seen = campaign.week
    local g = ledger.grudge_level(campaign, pid)
    local allowed = data.CALLBACKS[g] or 1
    local n = (g >= 4) and data.FAN_HIGH or data.FAN
    night.monologue_cast = cast.id
    local voice = M.voice(pid)
    night:emit({ kind = "npc", name = cast.name, cast = cast.id, text = data.OPENER[voice][grudge_tier(g)], voiced = true })
    local cards = M.fan(night, pid, n)
    local picked = {}
    local card = fan_card(night, pid, name, cards, 1)
    local o = night:decision(card) or card.options[1]
    local e = o.entry
    picked[e.id] = true
    night:emit({ kind = "npc", name = cast.name, cast = cast.id, text = e.text, voiced = true })
    local fit = M.land(night, pid, e, "full")
    remember_taunt(campaign, pid, e, e.text)
    local used = 1
    -- The second turn: someone interrupts, or the villain goes on (Grudge allowing).
    local interrupter
    for _, p in ipairs(night.players) do
        if (p.investment or 0) >= data.INTERRUPT.investment and (score.arch(p, "tactician") >= 1 or score.arch(p, "instigator") >= 1
            or score.arch(p, "butt_kicker") >= 1) and p.key ~= e.key then
            interrupter = interrupter or p
        end
    end
    local second = false
    if interrupter and night.rng:chance(data.INTERRUPT.chance) then
        second = true
        night:emit({ kind = "say", who = interrupter.key, text = night.rng:pick(data.INTERRUPT_LINES), ic = false })
        night.actor = interrupter
        local ic = { id = "interrupt_" .. pid, type = "talk", cast = cast.id, title = interrupter.name .. " interrupts",
                     text = interrupter.char .. " doesn't wait for " .. name .. " to finish.",
                     options = {
                         { label = "Let it land. The speech is over, and " .. interrupter.char .. " gets the moment.", let = true,
                           effects = { { "actor", spotlight = 10 }, { "all", social = 6 } } },
                         { label = "The villain shrugs it off and keeps talking.", let = false,
                           effects = { { "actor", trust = -1 }, { "arch:storyteller", story = 3 } } },
                     } }
        local io = night:decision(ic) or ic.options[1]
        if io.let then
            night:emit({ kind = "npc", name = cast.name, cast = cast.id, text = data.INTERRUPTED[voice], voiced = true })
            table.insert(s.interrupted, { week = campaign.week, who = interrupter.key, char = interrupter.char,
                                          place = place_name(sc.comps.location and sc.comps.location.id) })
            night:event("interrupt", { who = interrupter.key, villain = pid,
                                       text = interrupter.char .. " cut " .. name .. " off mid-speech", weight = 6 })
            allowed = 0
        else
            night:emit({ kind = "npc", name = cast.name, cast = cast.id, text = data.SHRUG[voice], voiced = true })
        end
    end
    if not second and allowed >= 2 then
        local more = M.fan(night, pid, 3, picked)
        local real = {}
        for _, x in ipairs(more) do
            if x.type ~= "generic" then
                table.insert(real, x)
            end
        end
        if #real > 0 then
            second = true
            local c2 = fan_card(night, pid, name, real, 2, { label = "That's enough. Let it hang.", effects = {}, stop = true })
            local o2 = night:decision(c2) or c2.options[#c2.options]
            if o2.entry then
                night:emit({ kind = "npc", name = cast.name, cast = cast.id, text = o2.entry.text, voiced = true })
                M.land(night, pid, o2.entry, "full")
                remember_taunt(campaign, pid, o2.entry, o2.entry.text)
                used = used + 1
            end
        end
    end
    if second then
        -- One takeover, one card.
        night.counts.decision = night.counts.decision - 1
    end
    -- A villain with a big Grudge counts the shelf before the closer.
    local fallen = #(campaign.fallen or {})
    if g >= 4 and fallen >= 2 then
        local shelf = (data.LINES[voice] or data.LINES.gloater).shelf
        night:emit({ kind = "npc", name = cast.name, cast = cast.id, voiced = true,
                     text = util.fill(shelf[1], { count = util.int(fallen) }) })
    end
    if allowed > 0 then
        local closers = data.CLOSER[voice]
        night:emit({ kind = "npc", name = cast.name, cast = cast.id, text = closers[night.rng:int(1, #closers)], voiced = true })
    end
    -- A full monologue gives the whole table a scene; the same villain every week wears thin.
    table.insert(s.monologues, campaign.week)
    local streak = 0
    for w = campaign.week, campaign.week - 2, -1 do
        streak = streak + (util.contains(s.monologues, w) and 1 or 0)
    end
    if streak < 3 then
        night:apply({ { "all", story = 3 } })
    end
    local target = e.key ~= "party" and player(night, e.key)
    night:event("taunt", { who = target and target.key or "party", villain = pid, weight = 6,
                           text = util.capitalize(name) .. " taunted " .. (target and target.char or "the party")
                               .. (fit.fuel and "" or ", and it didn't go down well") })
    night.took_talk_with = { pid = pid, cast = cast.id, monologue = true, picked = e.type, fuel = fit.fuel, used = used }
    return true
end

-- A bark in a fight, on its own: only light memories, only ones that fit, twice per kind a fight.
function M.bark(night, kind, p)
    local pid = night.villain_here
    if not pid or (kind == "knockdown" and not night.battle) then
        return false
    end
    local campaign = night.campaign
    night.villain_barks = night.villain_barks or {}
    if (night.villain_barks[kind] or 0) >= 2 then
        return false
    end
    local best
    for _, e in ipairs(M.ledger(campaign, pid, night)) do
        if e.type == kind and aimable(night, e) and (not p or e.key == p.key) and M.freshness(campaign, pid, e) > 0 then
            best = best or e
        end
    end
    if not best then
        return false
    end
    local fit = M.fit(night, pid, best)
    if not fit.fuel or fit.trust < 0 then
        return false            -- barks never salt a wound: those are the DM's call
    end
    night.villain_barks[kind] = (night.villain_barks[kind] or 0) + 1
    local person = ledger.about(pid)
    local text = M.line(night, pid, best)
    night:emit({ kind = "npc", name = person.name, cast = pid, text = text, voiced = true })
    M.land(night, pid, best, "bark")
    remember_taunt(campaign, pid, best, text)
    return true
end

-- The biggest taunt nobody has answered, for the villain's last words. Returns taunt, line.
function M.last_words(night, pid)
    local s = state(night.campaign, pid)
    local best
    for _, t in ipairs(s.taunts) do
        if not t.answered and (not best or t.sting > best.sting) then
            best = t
        end
    end
    local lw = data.LAST_WORDS[M.voice(pid)] or data.LAST_WORDS.gloater
    local kind = best and (best.type == "killed" and "killed" or (best.type == "backstory" and "backstory" or "other")) or "other"
    local text = util.fill(lw[kind], { fallen = best and best.fallen or "", hook = best and best.hook or "",
                                       place = best and best.place or "the end" })
    return best, util.sentence_case(text)
end

-- The striker's open taunt from this villain (the one a retort answers), or nil.
function M.open_taunt(campaign, pid, key)
    if not pid then
        return nil
    end
    local best
    for _, t in ipairs(state(campaign, pid).taunts) do
        if not t.answered and t.key == key and (not best or t.sting > best.sting) then
            best = t
        end
    end
    return best
end

-- The retort: the final hit answers the taunt. Returns the line, or nil.
function M.retort(night, pid, p)
    local campaign = night.campaign
    local t = M.open_taunt(campaign, pid, p.key)
    if not t then
        return nil
    end
    local lines = data.RETORT[p.class] or data.RETORT.fighter
    local kind = (t.type == "killed" or t.type == "backstory" or t.type == "knockdown") and t.type or "other"
    local text = util.fill(lines[kind], { char = p.char, fallen = t.fallen or "", hook = t.hook or "" })
    t.answered = campaign.week
    local s = state(campaign, pid)
    s.answered = s.answered or {}
    s.answered[t.id] = campaign.week
    s.retort = { key = p.key, char = p.char, text = text, taunt = t.text, week = campaign.week }
    score.add(p, "story", data.SIZE.session[4])
    for _, q in ipairs(night.players) do
        if q ~= p then
            score.add(q, "story", data.SIZE.session[3])
        end
    end
    if t.type == "killed" then
        score.add(p, "investment", data.SIZE.long[3])    -- the fallen hero's player, on their new one
    end
    night:event("retort", { who = p.key, villain = pid, weight = 9,
                            text = p.char .. " answered " .. ledger.about(pid).name .. " at last" })
    return util.capitalize(text)
end

-- The killing blow and Vendetta: how much bigger it lands, and whether it's fair to the table.
-- Returns the spotlight scale and whether the usual "same player again" check is waived.
function M.vendetta_blow(night, pid, p)
    if not pid then
        return 1, false
    end
    local campaign = night.campaign
    local v = M.vendetta(campaign, pid, p.key)
    local top, top_v = nil, 0
    for _, q in ipairs(night.players) do
        local qv = M.vendetta(campaign, pid, q.key)
        if qv > top_v then
            top, top_v = q, qv
        end
    end
    local waive = top ~= nil and (top == p or v >= top_v)
    for _, q in ipairs(night.players) do
        if q ~= p and M.vendetta(campaign, pid, q.key) >= data.VENDETTA_MAX and v < 3 then
            score.add(q, "investment", -data.SIZE.long[3])
            night:emit({ kind = "say", who = q.key, text = "Hey. That was MY kill.", ic = false })
        end
    end
    return 1 + (v >= 3 and 0.3 or 0) + (v >= 5 and 0.3 or 0), waive
end

-- Who should get the final hit, by Vendetta: the player who wants it most (3 or more), else nil.
function M.wants_it(night, pid, exclude)
    if not pid then
        return nil
    end
    local best, bv = nil, 2
    for _, q in ipairs(night.players) do
        local v = M.vendetta(night.campaign, pid, q.key)
        if q ~= exclude and v > bv then
            best, bv = q, v
        end
    end
    return best
end

-- The start of a week: Vendetta fades for villains who haven't shown up in a while.
function M.start_week(campaign)
    for _, s in pairs(campaign.villains or {}) do
        if s.seen and campaign.week - s.seen >= data.VENDETTA_FADE then
            for key, v in pairs(s.vendetta) do
                s.vendetta[key] = math.max(0, v - 1)
            end
            s.seen = campaign.week      -- the next fade is another stretch away
        end
    end
end

-- For the notebook: a villain's best taunt and the retort that answered it, and who wants them.
function M.notes(campaign, pid)
    local s = campaign.villains and campaign.villains[pid]
    if not s then
        return {}
    end
    local rows = {}
    local best
    for _, t in ipairs(s.taunts) do
        if not best or t.sting > best.sting then
            best = t
        end
    end
    if best and best.text then
        local p = campaign:player(best.key)
        table.insert(rows, "Taunted " .. (p and p.name or "someone") .. ": \"" .. best.text .. "\"")
    end
    if s.retort then
        table.insert(rows, "Answered by " .. s.retort.char .. ": " .. s.retort.text)
    end
    local keys = {}
    for key, v in pairs(s.vendetta) do
        if v >= 3 then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local p = campaign:player(key)
        if p then
            table.insert(rows, p.char .. (s.vendetta[key] >= 5 and " won't rest until this one's beaten." or " wants this one badly."))
        end
    end
    return rows
end

return M
