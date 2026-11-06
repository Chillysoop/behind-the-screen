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
M.CLOSE = 1.0            -- how close behind the strongest want another can be and still get picked
M.CALL_CAP = 13          -- the night's call budget a card of theirs fits under (night:room)
M.FIRST_NIGHT_CAP = 9    -- ...and on the first night, a smaller one: a newcomer has enough calls already (R6)

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
    -- (Already caught at it tonight: they lie low for a bit. And what they've done tonight already
    -- appeals less than something new.)
    if verb == "take" and night.ideas and night.ideas.caught then
        w = w - 2
    end
    local did = night.ideas and night.ideas.by and night.ideas.by[p.key .. ":" .. verb]
    if did then
        w = w - 1.2 * did
    end
    return w + night.rng:next() * 0.8, hooked and h or nil
end

-- Every idea a friend could have here: { verb, target, p, w, hook }.
function M.ideas(night, sc, phase)
    local tl = require "game.model.table_life"
    local d = data()
    local out = {}
    local done = (night.ideas and night.ideas.done) or {}
    if not night.tl_people or night.tl_people_room ~= sc then
        tl.set_people(night, sc)
        night.tl_people_room = sc
    end
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
local function tiny(night, p, skill, what)
    local name, mod = night:best_skill(p, { skill or "perception" })
    mod = (mod or 0) + night:take_learned(p)      -- (a miss they learned from: C25)
    local dd = night.rng:d20()
    local total = dd + (mod or 0)
    night.tl_roller = p.key
    -- (what: a roll with a purpose, digging for a secret, not a small moment.)
    night:emit({ kind = "tiny_roll", who = p.key, roll = dd, mod = mod or 0, total = total, skill = skills.name(name or skill or "perception"), what = what })
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
             -- (The player asks; you rule. Conner's playtest, C20: never the DM saying what a hero wants.)
             text = "{actor} leans over: \"Can {actor_char} lift " .. t.short .. "?\" " .. (t.planted and "(You put it there.) " or "") .. "Your call.",
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
    if night:room((c.week or 1) <= 1 and M.FIRST_NIGHT_CAP or M.CALL_CAP) then
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
        local ev = events.add(c, { kind = "steal", who = p.key, char = p.char, whom = t.owner.id, thing = t.thing or t.magic, where = sc.room,
                                   outcome = "got", seen = seen, from = motive, beat = true,
                                   text = events.word((t.shelf or string.find(t.short, who, 1, true)) and "lifted" or "lifted_off",
                                                      { char = p.char, thing = t.short, who = who }) })
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
    local ev = events.add(c, { kind = "steal", who = p.key, char = p.char, whom = t.owner.id, thing = t.thing or t.magic, where = sc.room,
                               outcome = "caught", seen = seen, from = motive, beat = true,
                               text = events.word("caught", { char = p.char, thing = t.short, who = who }) })
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
    local said = night:fresh(hd.lines, "idea_help_" .. t.owner.id)
    night:say(fill(said, v), "narration")
    local _, total = tiny(night, p, hd.skill)
    -- (The recap says what they did, the same deed the table heard: hd.did, line for line.)
    local i = util.index_of(hd.lines, said)
    local did = i and hd.did and hd.did[i]
    local ev = events.add(c, { kind = "help", who = p.key, whom = t.owner.id, where = sc.room, n = total >= 10 and 1 or 0.5,
                               seen = { [t.owner.id] = true }, beat = true,
                               from = people.knows_of(c, t.owner.id, "steal", p.key, true) or nil, how = nil,
                               text = did and util.fill(did, v) or events.word("helped", { char = p.char, who = t.owner.short or t.owner.name }) })
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
    night:say(fill(def.go, v), "narration")
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
    -- (One more room, asked for late: its small business is the scene, so up to two ideas, and a
    -- smaller want will do.)
    local one_more = night.one_more and (sc and (sc.quick or sc.virtual))
    local cap = one_more and 2 or 1
    if not sc or night.end_early or sc.boss or sc.showdown or night.fast or (sc.ideas_played and sc.ideas_played >= cap) then
        return 0
    end
    if (night.table_min or 0) > (night.table_planned or 210) - 40 and not one_more then
        return 0
    end
    local tl = require "game.model.table_life"
    local lvl = tl.level(night.campaign)
    night.ideas = night.ideas or { n = 0, done = {} }
    local ni = night.ideas
    ni.n, ni.done = ni.n or 0, ni.done or {}
    if ni.n >= (M.PER_NIGHT[lvl] or 3) and not one_more then
        return 0
    end
    -- (Whoever just had a small moment sits this one out, while anyone else is here: F26.)
    local last, roller = night.tl and night.tl.last, night.tl_roller
    local others = 0
    for _, p in ipairs(here(night)) do
        others = others + ((p.key ~= last and p.key ~= roller) and 1 or 0)
    end
    -- (The strongest wants, and any close behind them: which one a friend acts on is a little
    -- chance among them, so the same room doesn't always go the same way.)
    local at = M.IDEA_AT - (one_more and 1.5 or 0)
    local close, weights = {}, {}
    local best
    for _, idea in ipairs(M.ideas(night, sc, phase)) do
        if not (others > 0 and (idea.p.key == last or idea.p.key == roller)) and idea.w >= at then
            best = best or idea.w
            if idea.w >= best - M.CLOSE then
                table.insert(close, idea)
                table.insert(weights, idea.w - at + 0.5)
            end
        end
    end
    local top = #close > 0 and night.rng:weighted(close, weights) or nil
    if not top then
        return 0
    end
    sc.ideas_played = (sc.ideas_played or 0) + 1
    ni.n = ni.n + 1
    ni.done[top.key] = true
    ni.by = ni.by or {}
    ni.by[top.p.key .. ":" .. top.verb] = (ni.by[top.p.key .. ":" .. top.verb] or 0) + 1
    -- (Every idea acted on is in the log, whatever it was: the friends' own, not a card's.)
    events.add(night.campaign, { kind = "idea", verb = top.verb, who = top.p.key, where = sc.room,
                                 whom = top.target and top.target.owner and top.target.owner.id or nil })
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
    local n = who and 1 or 0
    if who and one_more and sc.ideas_played < cap then
        n = n + M.room(night, sc, phase)
    end
    return n
end

-- Finding things out (Conner's calls of November 5: the friends dig by their kind of player, their hero and
-- the clues they've gathered, and they're curious by default) -------------------------------------------
-- Each friend in the scene looks at the secrets that could come out here (game/model/secrets.lua: a person
-- here who holds one, a place in this room, a thing someone carries) and the ways their hero could dig
-- (game/data/find_out.lua): talk them round, lean on them, sing for them, read the tablet, cast a spell. A
-- way that's one of the secret's paths uses its DC and gives what it gives; one that isn't is improvised,
-- and the DM makes up the reveal on the card. What matters comes to the DM as a card while the night has
-- a call to spare; the rest is a small die in the open, and the DM's answer.

M.FIND_PER_ROOM = 1
M.FIND_PER_NIGHT = { lots = 4, some = 3, quiet = 2 }
M.FIND_AT = 3.0           -- how strong the want to dig has to be
M.CURIOUS = 1.7           -- everyone's a little curious (Conner: "by default friends should generally be curious")

local function ways()
    return require "game.data.find_out"
end

-- The person, place or thing a path is on, if it's here: { kind = "person" | "place" | "item", name, npc }.
local function holder_here(night, sc, path, d, people_list)
    local c = night.campaign
    if type(path.on) == "string" then
        -- (Someone the table's met by name: nobody leans on "Telpur" before anyone's said who he is.)
        if not require("game.model.shown").named(night.campaign, path.on) then
            return nil
        end
        for _, n in ipairs(people_list) do
            if n.id == path.on then
                return { kind = "person", name = n.short or n.name, npc = n }
            end
        end
        return nil
    end
    if path.item then
        local items_mod = require "game.model.items"
        local it, hk = items_mod.holding(c, path.item, true)
        if it then
            for _, q in ipairs(here(night)) do
                if q.key == hk then
                    local def = items_mod.thing(path.item) or items_mod.def(path.item)
                    return { kind = "item", name = util.lower_first((def and def.name) or "it"), holder = hk }
                end
            end
        end
        return nil
    end
    local room = path.room or d.room
    if room and room == sc.room then
        local name
        if path.spot then
            for _, pl in ipairs((night.board_places and night:board_places(sc)) or {}) do
                if pl.id == path.spot then
                    name = pl.name
                end
            end
        end
        -- (What the friends call it: the secret's `about` ("the hedges"), else the place's name on the board.)
        name = d.about or (name and util.lower_first(name)) or "the room"
        return { kind = "place", name = name, spot = path.spot }
    end
    return nil
end

-- What kind of way fits: a person's ways for a person, a document's for reading, the secret's own kind else.
local function way_kind(holder, path, d)
    if holder.kind == "person" then
        return "person"
    end
    if path.kind == "read" then
        return "document"
    end
    if d.type == "creature" then
        return "creature"
    end
    if holder.kind == "item" then
        return "item"
    end
    return d.type or "place"
end

local function has_spell(night, p, spell)
    local pc = night.pcs and night.pcs[p.key]
    if not pc then
        return false
    end
    for _, list in ipairs({ pc.prepared or {}, pc.cantrips or {}, pc.rituals or {} }) do
        for _, sp in ipairs(list) do
            if sp == spell then
                return true
            end
        end
    end
    return false
end

local function overlap(a, b)
    local out = {}
    for _, x in ipairs(a or {}) do
        for _, y in ipairs(b or {}) do
            if x == y then
                table.insert(out, x)
            end
        end
    end
    return out
end

-- Can this hero dig this way at this path? Returns the skills to roll (or {}), or nil if not.
local function can_dig(night, p, way, path, holder)
    local c = night.campaign
    if way.kind ~= path.kind then
        return nil
    end
    if way.spell and not has_spell(night, p, way.spell) then
        return nil
    end
    if path.kind == "spell" then
        local ok = false
        for _, sp in ipairs(path.spell or {}) do
            if sp == way.spell then
                ok = true
            end
        end
        if not ok then
            return nil
        end
        return {}
    end
    if path.kind == "trade" and (c.adv.francs or 0) < (path.francs or way.francs or 1) then
        return nil
    end
    if (path.kind == "ask" or path.opinion) and holder.npc then
        local lv = people.level(c, holder.npc.id, p.key)
        if (people.RANK[lv] or 0) < (people.RANK[path.opinion or "warm"] or 0) then
            return nil
        end
    end
    if path.skill then
        local sk = overlap(way.skill, path.skill)
        if #sk == 0 then
            return nil
        end
        return sk
    end
    -- (Reading a thing that just says it, the Mech's manual: no roll.)
    if path.kind == "read" then
        return {}
    end
    return way.skill or {}
end

-- Every way a friend could dig here: { verb = "find", key, path, way, holder, skills, p, w }.
function M.find_ideas(night, sc)
    local secrets = require "game.model.secrets"
    local c = night.campaign
    local d_ideas = data()
    local out = {}
    local list = M.people_here(night, sc)
    local hints = {}
    for _, p in ipairs(here(night)) do
        local n = 0
        for _, key in ipairs(secrets.list()) do
            if secrets.hinted(c, key, p.key) and not secrets.knows(c, key, p.key) then
                n = n + 1
            end
        end
        hints[p.key] = n
    end
    local done = (night.ideas and night.ideas.found) or {}
    for _, key in ipairs(secrets.list()) do
        local d = secrets.def(key)
        if not secrets.held(c, key) then
            for _, path in ipairs(secrets.paths(key, c)) do
                local holder = path.kind ~= "dm" and path.kind ~= "event" and path.kind ~= "see"
                    and not (path.after_fight and not sc.fought) and holder_here(night, sc, path, d, list)
                if holder then
                    local kind = way_kind(holder, path, d)
                    for _, way in ipairs(ways().ways[kind] or {}) do
                        for _, p in ipairs(here(night)) do
                            local mine = secrets.level(c, key, p.key)
                            local gives = path.gives == "part" and "hint" or path.gives or "known"
                            local better = path.gives == "part" and mine ~= "known" or (secrets.RANK[gives] or 0) > (secrets.RANK[mine] or 0)
                            local needs_ok = path.needs ~= "hint" or secrets.hinted(c, key, p.key, p.key)
                            local dkey = key .. ":" .. p.key .. ":" .. way.id
                            local sk = better and needs_ok and not done[dkey] and not (night.watching and night.watching[p.key])
                                and can_dig(night, p, way, path, holder)
                            if sk then
                                local likes = way.likes or {}
                                local w = M.CURIOUS + (likes[p.primary] or 0) + 0.5 * (likes[p.secondary] or 0)
                                w = w + ((way.class or {})[p.class] or 0)
                                if #sk > 0 then
                                    local _, mod = night:best_skill(p, sk)
                                    w = w + 0.12 * (mod or 0)
                                end
                                -- (A clue in hand pulls them in: a hint of their own, one the table has, a theory
                                -- building from several.)
                                if mine == "hint" then
                                    w = w + 1.4
                                elseif secrets.hinted(c, key, nil, p.key) then
                                    w = w + 0.7
                                end
                                w = w + 0.25 * math.min(3, hints[p.key] or 0)
                                -- (Their reason for coming is in this room.)
                                local h = util.lazy("game.model.adventure").hook(c, p.key)
                                if h and h.room == sc.room then
                                    w = w + 0.6
                                end
                                w = w + (d.weight or 0)
                                -- (What they've done tonight appeals less than something new, and a friend who's dug up
                                -- a lot already lets the others have a go: everyone gets to find things.)
                                local did = night.ideas and night.ideas.by and night.ideas.by[p.key .. ":find"]
                                if did then
                                    w = w - 0.8 * did
                                end
                                local dug = c.adv.dug and c.adv.dug[p.key] or 0
                                w = w - 0.35 * math.min(4, dug)
                                w = w + night.rng:next() * 0.8
                                table.insert(out, { verb = "find", key = key, path = path, way = way, holder = holder, skills = sk,
                                                    p = p, w = w, dkey = dkey, gives = path.gives or "known" })
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.w ~= b.w then
            return a.w > b.w
        end
        return a.dkey < b.dkey
    end)
    return out
end

-- The card the DM rules on: roll the path's check, give it, give a hint, or hold it back tonight.
local function find_card(night, idea, vars, lines)
    local secrets = require "game.model.secrets"
    local skills_mod = require "game.rules.skills"
    local p, path, way = idea.p, idea.path, idea.way
    local d = secrets.def(idea.key) or {}
    local gives = idea.gives == "part" and "hint" or idea.gives
    local where = idea.holder.name
    local notes = {}
    for _, q in ipairs(secrets.paths(idea.key, night.campaign)) do
        if q.book and q.skill and q.dc then
            table.insert(notes, skills_mod.name(q.skill[1]) .. " " .. q.dc)
        end
    end
    local improvised = path.improvised or path.default
    local text = "{actor} asks: \"" .. (idea.bid or util.fill(way.say[1], vars)) .. "\" "
        .. util.capitalize(where) .. " holds a secret: " .. util.lower_first(d.name or idea.key) .. (d.page and (" (page " .. d.page .. ")") or "") .. ". "
        .. (improvised and ways().improvised or (#notes > 0 and ("The book's way in: " .. table.concat(notes, ", ") .. ".") or "Your call."))
    -- (What the whole of it tells, told as the line's said, so the line names what they've just learned.)
    local tells
    if gives == "known" then
        tells = { idea.key }
        for _, k in ipairs(path.tells or {}) do
            table.insert(tells, k)
        end
    end
    local options = {}
    if #(idea.skills or {}) > 0 then
        local dc = path.dc or way.dc or 13
        table.insert(options, { label = "Roll for it: " .. skills_mod.name(idea.skills[1]) .. ", DC " .. dc .. (path.book and " (the book's)" or "") .. ".",
                                sub = gives == "known" and "Make it, and they have it." or "Make it, and they get a hint.",
                                roll = { dc = dc, true_dc = true, skill = idea.skills, convenient = "success", adv = way.adv,
                                         success = { log = lines.win, tells = tells, tells_how = path.kind }, fail = { log = lines.miss } },
                                find = gives })
    end
    table.insert(options, { label = gives == "known" and "It works. Tell them." or "It works: a hint.", sub = "No roll.",
                            log = lines.win, find = gives, tells = tells, tells_how = path.kind })
    if gives == "known" and not secrets.hinted(night.campaign, idea.key) and lines.hint then
        table.insert(options, { label = "A hint, for now.", sub = "Keep the rest for later.", log = lines.hint, find = "hint" })
    end
    table.insert(options, { label = "Not tonight.", sub = "It stays hidden this session. No harm done.", log = lines.miss, hold = true })
    return { id = "idea_find_" .. idea.key, type = "story", trigger = "museum_fixed", fixed_actor = true, keep_actor = true,
             actor = { "storyteller" }, title = "Digging", text = text, options = options }
end

-- One friend digs. Returns the friend, or nil.
function M.find(night, sc, idea)
    local secrets = require "game.model.secrets"
    local c = night.campaign
    local p, path, way, key = idea.p, idea.path, idea.way, idea.key
    local d = secrets.def(key) or {}
    night.actor = p
    local who = idea.holder.name
    local v = { char = p.char, who = who, thing = who }
    -- (A hunch they've been building, said first: the clue that set them digging.)
    if secrets.hinted(c, key, p.key, p.key) and d.theory then
        night:emit({ kind = "say", who = p.key, ic = false, text = fill(night:fresh(d.theory, "find_theory_" .. key), v) })
    end
    -- Their player says it out loud, or their hero does.
    local use_ic = way.ic and idea.holder.kind == "person" and night.rng:chance(0.5)
    local bid = use_ic and way.ic or way.say
    local said = fill(night:fresh(bid, "find_say_" .. way.id), v)
    night:emit({ kind = "say", who = p.key, ic = use_ic or false, text = said })
    -- (The card quotes what the player asked, out of character: never the DM saying what they want.)
    idea.bid = use_ic and fill(way.say[1], v) or said
    -- What comes out if it works: the path's words, the secret's, or one more piece of it.
    local gives = idea.gives
    local part
    if gives == "part" then
        local left = secrets.parts_left(c, key)
        part = #left > 0 and left[night.rng:int(1, #left)] or nil
        if not part then
            return nil
        end
    end
    local function line_for(level)
        if part then
            return "One " .. (d.part_word or "line") .. " comes clear: \"" .. d.parts[part] .. "\""
        end
        return secrets.line(night, key, level, path, v)
    end
    local lines = { win = line_for(gives == "part" and "hint" or gives), hint = not part and line_for("hint") or nil,
                    miss = fill(night:fresh(way.miss, "find_miss_" .. way.id), v) }
    -- (A Franc for a trade, paid as it's offered.)
    if path.kind == "trade" then
        local n = path.francs or way.francs or 1
        c.adv.francs = (c.adv.francs or 0) - n
        events.add(c, { kind = "spend", who = p.key, whom = idea.holder.npc and idea.holder.npc.id or nil, n = n, where = sc.room })
    end
    night:say(fill(night:fresh(way.go, "find_go_" .. way.id), v), "narration")
    -- The DM's call while the night has one to spare; otherwise the dice, in the open.
    local level, ok, carded
    local matters = d.weight or (gives == "known") or path.improvised or path.default
    if matters and night:room((c.week or 1) <= 1 and M.FIRST_NIGHT_CAP or M.CALL_CAP) then
        carded = true
        local o = night:decision(find_card(night, idea, v, lines))
        if o and o.hold then
            secrets.hold(c, key)
            return p
        end
        ok = o and ((o.roll and night.last_roll) or (not o.roll and o.find)) or false
        level = o and o.find
    else
        local dc = path.dc or way.dc or 13
        local sk = idea.skills or {}
        if #sk > 0 then
            local _, total = tiny(night, p, sk[1], "find")
            ok = total >= dc
        else
            ok = true
        end
        level = gives
        if not ok then
            night:say(lines.miss, "narration")
        end
    end
    if not ok then
        return p
    end
    local opts = { how = path.kind, by = p.key, path = path, private = path.private }
    if part then
        secrets.learn_part(c, key, part, opts)
    else
        secrets.learn(c, key, level == "part" and "hint" or level, opts)
    end
    if secrets.knows(c, key) then
        for _, k in ipairs(path.tells or {}) do
            secrets.learn(c, k, "known", opts)
        end
        if path.flag then
            c.adv.flags = c.adv.flags or {}
            c.adv.flags[path.flag] = true
        end
    end
    -- (By the dice, the DM says it now it's learned, so the line names what they know. The card said its own.)
    if not carded then
        night:say(level == "hint" and lines.hint or lines.win, "dm")
    end
    local f = ways()
    night:emit({ kind = "say", who = p.key, ic = false,
                 text = night:fresh(secrets.knows(c, key, p.key) and f.cheer or f.half, "find_react") })
    night:react({ [p.key] = "cheer" })
    score.nudge_engagement(p, 3)
    return p
end

-- A room's digging: the strongest want to find something out, if it's strong enough. At the room's start
-- (phase "enter": before its business, when knowing helps) or in its quiet stretch ("after"). Never in a
-- fight, at 4x, in the lair or late. Returns how many played.
function M.find_room(night, sc, phase)
    if not sc or night.end_early or sc.boss or sc.showdown or sc.epilogue or night.fast then
        return 0
    end
    if (sc.finds or 0) >= M.FIND_PER_ROOM then
        return 0
    end
    if (night.table_min or 0) > (night.table_planned or 210) - 30 then
        return 0
    end
    if require("game.model.able").somber(night) then
        return 0
    end
    local tl = require "game.model.table_life"
    local lvl = tl.level(night.campaign)
    night.ideas = night.ideas or { n = 0, done = {} }
    local ni = night.ideas
    ni.finds = ni.finds or 0
    if ni.finds >= (M.FIND_PER_NIGHT[lvl] or 3) then
        return 0
    end
    local list = M.find_ideas(night, sc)
    local close, weights = {}, {}
    local best
    for _, idea in ipairs(list) do
        if idea.w >= M.FIND_AT then
            best = best or idea.w
            if idea.w >= best - M.CLOSE then
                table.insert(close, idea)
                table.insert(weights, idea.w - M.FIND_AT + 0.5)
            end
        end
    end
    local top = #close > 0 and night.rng:weighted(close, weights) or nil
    if not top then
        return 0
    end
    sc.finds = (sc.finds or 0) + 1
    ni.finds = ni.finds + 1
    ni.by = ni.by or {}
    ni.by[top.p.key .. ":find"] = (ni.by[top.p.key .. ":find"] or 0) + 1
    ni.found = ni.found or {}
    ni.found[top.dkey] = true
    local adv = night.campaign.adv
    adv.dug = adv.dug or {}
    adv.dug[top.p.key] = (adv.dug[top.p.key] or 0) + 1
    events.add(night.campaign, { kind = "idea", verb = "find", who = top.p.key, where = sc.room, what = top.key,
                                 whom = top.holder.npc and top.holder.npc.id or nil })
    local who = M.find(night, sc, top)
    if who then
        night.table_min = (night.table_min or 0) + 2
    end
    return who and 1 or 0
end

-- The DM's "Reveal now" and "Drop a hint" from a person's sheet or the prep board (secrets.ask): said at the
-- night's next beat, in the DM's words, to the heroes in the scene.
function M.dm_asks(night)
    local secrets = require "game.model.secrets"
    local c = night.campaign
    local n = 0
    for _, a in ipairs(secrets.take_asks(c)) do
        if (secrets.RANK[a.level] or 0) > (secrets.RANK[secrets.level(c, a.key)] or 0) then
            local line = secrets.line(night, a.key, a.level, nil, {})
            if line then
                night:say(line, "dm")
            end
            secrets.learn(c, a.key, a.level, { how = "dm" })
            n = n + 1
        end
    end
    return n
end

return M
