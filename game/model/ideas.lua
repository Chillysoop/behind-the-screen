-- The friends' own ideas (roadmap R12; the Main Campaign Design doc: "the room's cards stay, but
-- they're no longer the only things that can happen"). A small set of verbs any friend can reach for
-- in a room, aimed at what's there: ask (a person), take (something a person carries, or a shop's
-- shelf), help (a person), follow (a person), hide (from the room's business), poke (a curio on the
-- board). Each friend in the scene scores the verb-and-target pairs from what they want: their kind of
-- player, their hero's class and reason for coming, how tonight's going for them, their hero's state,
-- and what the person thinks of their hero. The strongest idea, if it's strong enough, happens.
--
-- Most just happen, with a small die on its own and the DM's answer from behind the screen, like the
-- small moments (table_life.lua: poke and ask are its curios and questions). Only an idea that matters
-- comes to the DM as a card, within the night's call budget: lifting something off someone could turn
-- them against the party, so it's yours to rule (allow, roll, or no); without a call to spare, the dice
-- decide in the open.
--
-- Take (R13, the pickpocket slice, built all the way through first): a friend notices what someone
-- carries (MODULE.ideas.pockets, nobody planted it; or what the DM put in their pockets, npcs.lua);
-- their player says so out loud, someone may object or join in; you rule; Sleight of Hand; a miss means
-- they're seen (an event in the log with its witnesses: game/model/events.lua), the one robbed thinks
-- less of them (people.lua) and acts on it later (a refusal, a higher price, a word to Flitwidget). What
-- they took goes into their hero's pack (items.lua). Pure Lua.

local util = require "game.model.util"
local score = require "game.model.score"
local events = require "game.model.events"
local people = require "game.model.people"
local skills = require "game.rules.skills"

local M = {}

M.PER_ROOM = { lots = 1, some = 1, quiet = 1 }
M.PER_NIGHT = { lots = 3, some = 3, quiet = 2 }
M.IDEA_AT = 3.2          -- how strong an idea has to be before a friend acts on it
M.CALL_CAP = 13          -- the night's call budget a card of theirs fits under (night:room)

local function module()
    return util.lazy("game.model.adventure").data or {}
end
local function data()
    return module().ideas or {}
end

-- The heroes in this scene (night:at_hand): one who wandered off has ideas elsewhere.
local function here(night)
    return night.at_hand and night:at_hand() or night.players
end

local function fill(text, v)
    return util.sentence_case(util.fill(text, v))
end

local function npc_say(night, who_id, name, text)
    if text then
        night:emit({ kind = "npc", name = name, cast = who_id, text = (string.gsub(text, '^"(.*)"$', "%1")) })
    end
end

-- Who's in this room to reach for: the room's own person, and anyone whose sheet puts them here.
function M.people_here(night, sc)
    local npcs = require "game.model.npcs"
    local adv = util.lazy("game.model.adventure")
    local out, seen = {}, {}
    local function add(id)
        if id and not seen[id] and not adv.person_hidden(night.campaign, id) then
            local n = npcs.get(id)
            if n and not n.monster then
                seen[id] = true
                table.insert(out, n)
            end
        end
    end
    local cast = sc.comps and sc.comps.cast
    if cast and not cast.foe then
        add(cast.id)
    end
    for _, n in ipairs(npcs.all()) do
        if n.room == sc.room then
            add(n.id)
        end
    end
    return out
end

-- What someone has on them that could be lifted: their own pockets (MODULE.ideas.pockets) and what
-- the DM put there to be pickpocketed (npcs.lua drops, how = "pocket").
function M.pockets(night, n)
    local adv = night.campaign.adv
    adv.lifted = adv.lifted or {}
    local out = {}
    for _, pk in ipairs((data().pockets or {})[n.id] or {}) do
        if not adv.lifted[pk.id] then
            table.insert(out, { id = pk.id, thing = pk.thing, what = pk.what, short = pk.short or pk.what, dc = pk.dc or 13,
                                shelf = pk.shelf, owner = n })
        end
    end
    local items_mod = require "game.model.items"
    for _, d in ipairs(require("game.model.npcs").drops(night.campaign, n.id)) do
        if d.how == "pocket" and not d.got then
            local def = items_mod.def(d.item)
            local name = util.lower_first(def and def.name or "something")
            table.insert(out, { id = "drop_" .. n.id .. "_" .. d.item, magic = d.item, drop = d, what = name .. " on " .. (n.short or n.name),
                                short = name, dc = n.monster and 15 or 13, owner = n, planted = true })
        end
    end
    return out
end

-- How much a friend wants to do this: their kind of player, their hero's class, what their hero
-- came for, how the night's going for them, their hero's state, and what the person thinks of them.
function M.want(night, p, verb, target)
    local d = data()
    local likes = (d.likes or {})[verb] or {}
    local w = (likes[p.primary] or 0) + 0.5 * (likes[p.secondary] or 0)
    w = w + (((d.class or {})[verb] or {})[p.class] or 0)
    local adv = util.lazy("game.model.adventure")
    local c = night.campaign
    -- (Their reason for coming is in this room: they lean in. A hero who came for a con, in the
    -- con man's street, reaches for his pockets.)
    local h = adv.hook(c, p.key)
    local sc = night.scene
    local hooked = h and sc and h.room == sc.room
    if hooked and (verb == "ask" or verb == "poke" or verb == "take" or verb == "follow") then
        w = w + 1
    end
    -- (Drifting tonight: something to do, anything. Having a bad night: they keep their heads down.)
    local e = p.engagement or 0.5
    if e < 0.45 and (verb == "take" or verb == "poke" or verb == "follow") then
        w = w + 1
    end
    if (score.fun(p) or 50) < 35 and verb == "hide" then
        w = w + 1
    end
    -- (Hurt: no risks, more hiding.)
    local pc = night.pcs and night.pcs[p.key]
    if pc and pc.hp_max and pc.hp <= pc.hp_max * 0.5 then
        if verb == "take" then
            w = w - 1.5
        elseif verb == "hide" then
            w = w + 1
        end
    end
    -- (What the person thinks of them: nobody asks someone who won't answer; a grudge goes both ways.)
    if target and target.owner then
        local lv = people.level(c, target.owner.id, p.key)
        if verb == "ask" and people.RANK[lv] < 0 then
            w = w - 1
        elseif verb == "help" and people.RANK[lv] < 0 then
            w = w + 0.5          -- (a chance to make amends)
        end
    end
    -- (Already caught at it tonight: they lie low for a bit.)
    if verb == "take" and night.ideas and night.ideas.caught then
        w = w - 2
    end
    return w + night.rng:next() * 0.8, hooked and h or nil
end

-- Every idea a friend could have here: { verb, target, p, w, hook }.
function M.ideas(night, sc, phase)
    local tl = require "game.model.table_life"
    local d = data()
    local out = {}
    local done = (night.ideas and night.ideas.done) or {}
    local list = M.people_here(night, sc)
    local function add(p, verb, target, key)
        if done[key] then
            return
        end
        local w, hook = M.want(night, p, verb, target)
        table.insert(out, { verb = verb, target = target, p = p, w = w, hook = hook, key = key })
    end
    for _, p in ipairs(here(night)) do
        if not (night.watching and night.watching[p.key]) then
            for _, n in ipairs(list) do
                if phase ~= "after" or sc.room == "thanks" then
                    for _, pk in ipairs(M.pockets(night, n)) do
                        add(p, "take", pk, "take:" .. pk.id)
                    end
                end
                local hd = (d.help or {})[n.id]
                if hd then
                    add(p, "help", { owner = n, def = hd }, "help:" .. n.id .. ":" .. sc.room)
                end
                local fd = (d.follow or {})[n.id]
                if fd then
                    add(p, "follow", { owner = n, def = fd }, "follow:" .. n.id .. ":" .. sc.room)
                end
            end
            local hide = (d.hide or {})[sc.room]
            if hide and #list > 0 then
                add(p, "hide", { def = hide }, "hide:" .. sc.room)
            end
            for _, b in ipairs(tl.open_curios(night, sc)) do
                add(p, "poke", { curio = b }, "poke:" .. tostring(b.id))
            end
            for _, q in ipairs(tl.open_questions(night, sc, phase)) do
                local owner
                for _, n in ipairs(list) do
                    if string.gsub(string.gsub(n.id, "^mus_", ""), "_.*$", "") == q.who then
                        owner = n
                    end
                end
                add(p, "ask", { question = q, owner = owner }, "ask:" .. tostring(q.ask))
            end
        end
    end
    table.sort(out, function(a, b)
        if a.w ~= b.w then
            return a.w > b.w
        end
        return a.key < b.key
    end)
    return out
end

-- The small die, on its own (table_life's): theirs, with the sum.
local function tiny(night, p, skill)
    local name, mod = night:best_skill(p, { skill or "perception" })
    local dd = night.rng:d20()
    local total = dd + (mod or 0)
    night:emit({ kind = "tiny_roll", who = p.key, roll = dd, mod = mod or 0, total = total, skill = skills.name(name or skill or "perception") })
    return dd, total
end

-- Somebody else at the table pipes up: against it, or in on it.
local function other_friend(night, p, prefs)
    local best, bw
    for _, q in ipairs(here(night)) do
        if q ~= p then
            local w = 0
            for i, a in ipairs(prefs) do
                if q.primary == a then
                    w = w + (4 - i)
                elseif q.secondary == a then
                    w = w + (2 - i * 0.3)
                end
            end
            w = w + night.rng:next()
            if not bw or w > bw then
                best, bw = q, w
            end
        end
    end
    return best
end

-- Take: the pickpocket slice (R13) ---------------------------------------------------------------

-- The card you rule on: let it work, roll for it, or no.
-- (ok_line, fail_line: what the table hears either way, already in this friend's words.)
local function take_card(night, p, t, ok_line, fail_line)
    local who = t.owner.short or t.owner.name
    return { id = "idea_take_" .. t.owner.id, type = "story", trigger = "museum_fixed", fixed_actor = true, keep_actor = true,
             actor = { "instigator" }, title = "Light fingers",
             text = "{actor_char} wants to lift " .. t.short .. ". " .. (t.planted and "(You put it there.) " or "") .. "Can they?",
             options = {
                 { label = "Let it work.", sub = who .. " never feels a thing.", allow = true, log = ok_line,
                   effects = { { "actor", spotlight = 8, fun = 6 }, { "arch:instigator", fun = 2 } } },
                 { label = "Roll for it: Sleight of Hand.", sub = "Miss, and " .. who .. " sees it. They'll remember.",
                   roll = { dc = t.dc, skill = { "sleight_of_hand" }, convenient = "success",
                            success = { log = ok_line, effects = { { "actor", spotlight = 8, fun = 6 }, { "arch:instigator", fun = 2 } } },
                            fail = { log = fail_line, effects = { { "actor", spotlight = 4, challenge = 3 }, { "arch:storyteller", fun = 1 } } } } },
                 { label = "No. Not this one.", sub = "Out of character. A little sulk, and on.", no = true,
                   log = "You shake your head at " .. p.name .. " over the screen.",
                   effects = { { "actor", fun = -2 }, { "arch:tactician", fun = 1 } } },
             } }
end

-- Who's there to see it go wrong: the one robbed, anyone else whose room it is, and whoever's along.
local function witnesses(night, sc, t)
    local seen = { [t.owner.id] = true }
    for _, id in ipairs(people.watchers(night.campaign, sc.room)) do
        seen[id] = true
    end
    for _, e in ipairs(require("game.model.companions").active(night.campaign, night.players)) do
        seen[e.id == "telpur" and "mus_telpur" or e.id] = true
    end
    return seen
end

function M.take(night, sc, idea)
    local c = night.campaign
    local d = data().take or {}
    local p, t = idea.p, idea.target
    local who = t.owner.short or t.owner.name
    local v = { char = p.char, what = t.what, who = who, thing = t.short, name = p.name }
    night.actor = p
    night:say(fill(night:fresh(d.notice, "idea_take_notice"), v), "narration")
    -- Their player says so out loud; someone at the table has something to say about it.
    night:emit({ kind = "say", who = p.key, text = fill(night:fresh(d.say, "idea_take_say"), v), ic = false })
    local q = other_friend(night, p, { "tactician", "casual", "storyteller" })
    if q and night.rng:chance(0.7) then
        local against = q.primary == "tactician" or q.primary == "casual" or q.secondary == "tactician"
        local line = against and night:fresh(d.object, "idea_take_object") or night:fresh(d.join, "idea_take_join")
        night:emit({ kind = "say", who = q.key, text = fill(line, v), ic = false })
        if against then
            require("game.model.rapport").bond(c, q.key, p.key, -1)
        end
    end
    -- It could turn someone against the party: your call, if the night has one to spare.
    local o
    local adv = c.adv
    local ok
    local ok_line = fill(night:fresh(d.ok, "idea_take_ok"), v)
    local fail_line = fill(night:fresh(d.fail, "idea_take_fail"), v)
    local carded = false
    if night:room(M.CALL_CAP) then
        carded = true
        o = night:decision(take_card(night, p, t, ok_line, fail_line))
        if o and o.no then
            night:emit({ kind = "say", who = p.key, text = fill(night:fresh(d.no, "idea_take_no"), v), ic = false })
            events.add(c, { kind = "ruled_no", who = p.key, whom = t.owner.id, thing = t.thing or t.magic, where = sc.room })
            return p
        end
        ok = (o and o.allow) or (o and o.roll and night.last_roll) or false
    else
        -- (No call left tonight: the dice decide, out in the open.)
        local _, total = tiny(night, p, "sleight_of_hand")
        ok = total >= t.dc
    end
    adv.lifted = adv.lifted or {}
    local motive = idea.hook and events.last(c, { kind = "hook", who = p.key }) or nil
    if ok then
        adv.lifted[t.id] = c.week or 0
        local seen = {}
        local ev = events.add(c, { kind = "steal", who = p.key, whom = t.owner.id, thing = t.thing or t.magic, where = sc.room,
                                   outcome = "got", seen = seen, from = motive, beat = true,
                                   text = p.char .. " lifted " .. t.short .. ((t.shelf or string.find(t.short, who, 1, true)) and "" or (" off " .. who)) })
        sc.last_beat = ev.id
        local prev = events.cause(c)
        events.set_cause(c, ev)
        local items_mod = require "game.model.items"
        if t.magic then
            local e = items_mod.earn(c, t.magic, { p }, "stolen", t.owner)
            t.drop.got, t.drop.entry = c.week, e
            local pc = e and night.pcs and night.pcs[p.key]
            if pc then
                items_mod.apply(c, p.key, pc)
            end
        else
            items_mod.give(c, t.thing, p.key, "stolen", t.owner)
        end
        events.set_cause(c, prev)
        if not carded then
            night:say(ok_line, "good")
        end
        night:react({ [p.key] = "cheer" })
        return p
    end
    -- Seen: the one robbed (and anyone else there) knows now, and remembers.
    local seen = witnesses(night, sc, t)
    local ev = events.add(c, { kind = "steal", who = p.key, whom = t.owner.id, thing = t.thing or t.magic, where = sc.room,
                               outcome = "caught", seen = seen, from = motive, beat = true,
                               text = p.char .. " went for " .. t.short .. ", and " .. who .. " caught them at it" })
    sc.last_beat = ev.id
    night.ideas = night.ideas or {}
    night.ideas.caught = true
    if not carded then
        night:say(fail_line, "bad")
    end
    local line = people.line(night, t.owner.id, "caught", p)
    npc_say(night, t.owner.id, t.owner.short or t.owner.name, line)
    night:react({ [p.key] = "gasp" })
    return p
end

-- Help, follow, hide: small moments with a die of their own ---------------------------------------

local function help(night, sc, idea)
    local c = night.campaign
    local p, t = idea.p, idea.target
    local hd = t.def
    local v = { char = p.char }
    night.actor = p
    night:say(fill(night:fresh(hd.lines, "idea_help_" .. t.owner.id), v), "table")
    local _, total = tiny(night, p, hd.skill)
    local ev = events.add(c, { kind = "help", who = p.key, whom = t.owner.id, where = sc.room, n = total >= 10 and 1 or 0.5,
                               seen = { [t.owner.id] = true }, beat = true,
                               from = people.knows_of(c, t.owner.id, "steal", p.key, true) or nil, how = nil,
                               text = p.char .. " helped " .. (t.owner.short or t.owner.name) })
    if ev.from then
        ev.how = "therefore"          -- (making amends: it follows from what they did)
    end
    sc.last_beat = ev.id
    npc_say(night, t.owner.id, t.owner.short or t.owner.name, people.line(night, t.owner.id, "helped", p))
    score.nudge_engagement(p, 2)
    night:apply({ { "arch:casual", fun = 1 } })
    return p
end

local function look(night, sc, idea, kind)
    local p, t = idea.p, idea.target
    local def = t.def
    local v = { char = p.char }
    night.actor = p
    night:say(fill(def.go, v), "table")
    local _, total = tiny(night, p, def.skill)
    local text = (total >= 12 and def.detail) or def.dull
    if text then
        night:say(fill(text, v), "dm")
    end
    events.add(night.campaign, { kind = kind, who = p.key, whom = t.owner and t.owner.id or nil, where = sc.room })
    score.nudge_engagement(p, 2)
    return p
end

-- A room's ideas: the strongest one, if a friend wants it enough. Same quiet stretch as the small
-- moments (never in a fight, at 4x, in the lair, or late in the evening). Returns how many played.
function M.room(night, sc, phase)
    if not sc or night.end_early or sc.boss or sc.showdown or night.fast or (sc.ideas_played and sc.ideas_played >= 1) then
        return 0
    end
    if (night.table_min or 0) > (night.table_planned or 210) - 40 then
        return 0
    end
    local tl = require "game.model.table_life"
    local lvl = tl.level(night.campaign)
    night.ideas = night.ideas or { n = 0, done = {} }
    local ni = night.ideas
    ni.n, ni.done = ni.n or 0, ni.done or {}
    if ni.n >= (M.PER_NIGHT[lvl] or 3) then
        return 0
    end
    local list = M.ideas(night, sc, phase)
    local top = list[1]
    if not top or top.w < M.IDEA_AT then
        return 0
    end
    sc.ideas_played = (sc.ideas_played or 0) + 1
    ni.n = ni.n + 1
    ni.done[top.key] = true
    local who
    if top.verb == "take" then
        who = M.take(night, sc, top)
    elseif top.verb == "help" then
        who = help(night, sc, top)
    elseif top.verb == "follow" then
        who = look(night, sc, top, "follow")
    elseif top.verb == "hide" then
        who = look(night, sc, top, "hide")
    elseif top.verb == "poke" then
        who = tl.poke(night, sc, top.target.curio, nil, top.p)
    elseif top.verb == "ask" then
        who = tl.ask_one(night, sc, top.target.question, nil, top.p)
    end
    if who then
        night.tl = night.tl or { n = 0 }
        night.tl.last = who.key
        night.table_min = (night.table_min or 0) + 1
    end
    return who and 1 or 0
end

return M
