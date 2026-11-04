-- Table life (the playtest, November 3: "filler of players investigating random stuff with nothing,
-- the DM saying 'it's just a normal candle'... asking NPCs questions, a drink... grounded in the
-- room... a nat 20 or 1 lets the DM improvise... without more decisions for the real player").
-- Small beats that play themselves in a room's quiet stretches: a friend pokes at something on the
-- board, a little die rolls on its own, and you answer from behind the screen: dull, a detail, or a
-- bit of lore. Or they ask someone a question, haggle, have a snack, pocket a souvenir. Only a natural
-- 20 or 1 stops for a card (and only with small-moment crits on: campaign.small_crits, the toggle top
-- right on game night). How much of this there is: Session Zero's table rule, chatter (lots, some,
-- quiet). The words are the adventure's (MODULE.table_life), drawn from the book's rooms in our own
-- words. Pure Lua.
--
-- campaign.adv.tl_seen = { [beat id] = week }: a curio is poked at once in the whole prologue.

local util = require "game.model.util"
local score = require "game.model.score"
local skills = require "game.rules.skills"

local M = {}

M.PER_ROOM = { lots = 3, some = 2, quiet = 0 }
M.PER_NIGHT = { lots = 12, some = 8, quiet = 0 }
M.LORE_AT, M.DETAIL_AT = 17, 10

local function data()
    local ok, adv = pcall(require, "game.model.adventure")
    return ok and adv.data and adv.data.table_life or nil
end

function M.level(campaign)
    local r = campaign.table and campaign.table.rules
    return (r and r.chatter) or "some"
end

-- Small-moment crits: on unless you turned them off (game night's top-right toggle).
function M.crits_on(campaign)
    return campaign.small_crits ~= false
end

function M.set_crits(campaign, on)
    campaign.small_crits = on and true or false
end

-- The friends whose heroes are in this scene (night:at_hand): a hero who wandered off doesn't poke
-- at things, ask or haggle in the room they left (F11).
local function here(night)
    return night.at_hand and night:at_hand() or night.players
end

-- Does a line name a hero who isn't in this scene (off elsewhere, or not at the table tonight)?
local function names_absent(night, text)
    if type(text) ~= "string" then
        return false
    end
    local in_scene = {}
    for _, p in ipairs(here(night) or {}) do
        in_scene[p.key] = true
    end
    for key, names in pairs(require("game.model.dialogue").NAMES) do
        if not in_scene[key] and string.find(text, "%f[%a]" .. names[2] .. "%f[%A]") then
            return true
        end
    end
    return false
end

-- Who'd do it: their kind of player, a friend who's drifting gets first go, and whoever just had a
-- beat sits this one out (the second playtest review: one friend took several turns running).
local function pick_friend(night, who, last, not_p)
    local list, w = {}, {}
    local others = 0
    local players = here(night)
    for _, p in ipairs(players) do
        if p ~= not_p and p.key ~= last and not (night.watching and night.watching[p.key]) then
            others = others + 1
        end
    end
    for _, p in ipairs(players) do
        if p ~= not_p and not (night.watching and night.watching[p.key]) and not (others > 0 and p.key == last) then
            local v = 1
            for _, a in ipairs(who or {}) do
                if a == p.primary then
                    v = v + 3
                elseif a == p.secondary then
                    v = v + 1.5
                elseif a == p.key then
                    v = v + 6
                end
            end
            if (p.engagement or 0.5) < 0.45 then
                v = v + 2
            end
            table.insert(list, p)
            table.insert(w, v)
        end
    end
    if #list == 0 then
        return nil
    end
    return night.rng:weighted(list, w)
end

local function seen(night)
    local adv = night.campaign.adv
    adv.tl_seen = adv.tl_seen or {}
    return adv.tl_seen
end

-- What could happen here now: the room's curios nobody's poked at yet, questions for whoever's in
-- the room (and not hostile), and its little table bits.
local function candidates(night, sc, room, phase, last)
    local s = seen(night)
    local out, w = {}, {}
    local looked = night.campaign.adv and night.campaign.adv.looked or {}
    local tl = night.tl or {}
    local adventure = require "game.model.adventure"
    local companions = require "game.model.companions"
    local knobs = night.prep and night.prep.museum and night.prep.museum.knobs or {}
    local function add(b, kind, weight)
        if (b.id and s[b.id]) or (not b.id and night.tl_bits and night.tl_bits[b]) then
            return
        end
        -- (Nothing that names a hero who isn't in this scene, and no friend's own bit without them:
        -- Brannoc's five chestnuts with Brannoc off elsewhere. F11.)
        if kind == "bit" then
            if b.who and not util.contains(here(night), night.campaign:player(b.who) or false) then
                return
            end
            for _, l in ipairs(b.lines or {}) do
                if names_absent(night, l) then
                    return
                end
            end
        elseif names_absent(night, b.ask) or names_absent(night, b.see) then
            return
        end
        -- (Only when it holds: after the lair, with Pip's rat along...)
        if b.when then
            if b.when.companion then
                local along = false
                for _, e in ipairs(companions.active(night.campaign, night.players)) do
                    along = along or e.id == b.when.companion
                end
                if not along then
                    return
                end
            end
            if not adventure.test(night.campaign, b.when, knobs) then
                return
            end
        end
        table.insert(out, { kind = kind, b = b })
        table.insert(w, weight)
    end
    for _, c in ipairs(room.curios or {}) do
        -- (Not the thing someone just walked over to and looked at: the second playtest review.)
        if not (c.spot and looked[sc.room .. "/" .. c.spot]) then
            add(c, "curio", 3)
        end
    end
    if phase ~= "after" then
        local present = night.tl_people or {}
        for _, q in ipairs(room.npc_questions or {}) do
            if present[q.who] then
                add(q, "ask", 2)
            end
        end
    end
    -- About one table bit a night (the second playtest review: one in about 27 moments): rare until
    -- the night has had a beat or two without one, likely then, and rare again once there's been one.
    local bit_w = ((tl.bits or 0) > 0 and 0.4) or (((tl.n or 0) >= 1) and 12) or 1
    for _, t in ipairs(room.table_bits or {}) do
        -- (A bit that's one friend's waits if that friend just had a beat.)
        if not (t.who and t.who == last) then
            add(t, "bit", bit_w)
        end
    end
    return out, w
end

-- Someone at the table says something (out of character unless it says so).
local function say(night, p, text, ic)
    if p and text then
        night:emit({ kind = "say", who = p.key, text = util.sentence_case(util.fill(text, { char = p.char })), ic = ic or false })
    end
end

-- The DM's answer, to the table.
local function dm(night, text, vars)
    if text then
        night:say(util.sentence_case(util.fill(text, vars or {})), "dm")
    end
end

-- The little die: theirs, on its own, with the sum (the tile shows it small; no DC, no card).
local function tiny_roll(night, p, skill)
    local name, mod = night:best_skill(p, { skill or "perception" })
    local bonus = 0
    local companions = require "game.model.companions"
    local e = companions.of(night, p)
    if e and e.helps and e.pocket then
        bonus = e.helps.bonus or 0
    end
    local d = night.rng:d20()
    local total = d + (mod or 0) + bonus
    night:emit({ kind = "tiny_roll", who = p.key, roll = d, mod = (mod or 0) + bonus, total = total,
                 skill = skills.name(name or skill or "perception") })
    return d, total, e and bonus > 0 and e or nil
end

-- The danger in this room, if it has one (a moment's `danger`): what a lucky look can reveal.
local function room_danger(sc)
    local ok, adv = pcall(require, "game.model.adventure")
    for _, m in ipairs(ok and adv.data.moments or {}) do
        if m.room == sc.room and m.danger then
            return m
        end
    end
    return nil
end

-- A natural 20 or 1: your call, in one card. The harmless answer is first (a timer that runs out
-- picks it).
local function crit_card(night, sc, p, b, nat)
    local what = b.what or "it"
    local card = { id = "tl_crit", type = "table", trigger = "museum_fixed", fixed_actor = true, options = {} }
    local prev = night.actor
    night.actor = p
    if nat == 20 then
        card.title = "A natural 20"
        card.text = "{actor_char} rolled a natural 20 poking at " .. what .. ". Improvise something?"
        table.insert(card.options, { label = "Nope. Still just " .. what .. ".", sub = "The table laughs. Nothing changes.",
            log = "\"It's " .. what .. ". A really, really ordinary one.\" The table loses it.", laugh = true,
            effects = { { "all", fun = 1 }, { "arch:casual", fun = 1 } } })
        local c20 = b.crit20 or {}
        if c20.find then
            table.insert(card.options, { label = "Hide something small there: " .. c20.find .. ".", sub = "A Flitwidget Franc for them.",
                find = c20.find, effects = { { "actor", fun = 3, spotlight = 4 }, { "arch:power_gamer", fun = 2 } } })
        end
        local danger = room_danger(sc)
        if c20.clue and danger then
            table.insert(card.options, { label = "A clue about the danger here.", sub = "They find out for themselves: it counts as a warning.",
                clue = c20.clue, danger = danger, effects = { { "actor", fun = 2 }, { "arch:explorer", fun = 2 }, { "arch:tactician", fun = 1 } } })
        elseif c20.clue then
            table.insert(card.options, { label = "Something about this room: " .. util.lower_first(c20.clue), clue = c20.clue,
                effects = { { "actor", fun = 2 }, { "arch:storyteller", fun = 2 } } })
        end
    else
        card.title = "A natural 1"
        card.text = "{actor_char} rolled a natural 1 poking at " .. what .. ". Improvise something?"
        table.insert(card.options, { label = "Laugh it off.", sub = "A groan, a laugh, on you go.",
            log = "A groan round the table, and then a laugh. On you go.", laugh = true, effects = { { "all", fun = 1 } } })
        table.insert(card.options, { label = "A little mishap: noisy.", sub = "Whatever's in the next fight hears them coming.",
            mishap = b.crit1 or "{actor_char} knocks it over with a clatter that echoes all the way down the hall.",
            effects = { { "actor", fun = 1 }, { "arch:instigator", fun = 2 }, { "arch:tactician", fun = -1 } } })
        -- A scare and a scratch, in this room's own words, and only inside the museum (the second
        -- playtest review: "A needle in a trodden handbill... 2 damage" out on the public street).
        local room = data() and data().rooms and data().rooms[sc.room]
        local scare = room and room.scare
        if scare then
            table.insert(card.options, { label = "A little scare: a jolt and a scratch.", sub = "No lasting harm. They jump; the table laughs.",
                scare = type(scare) == "table" and night.rng:pick(scare) or scare,
                effects = { { "actor", challenge = 3, fun = 1 }, { "arch:butt_kicker", fun = 1 }, { "arch:instigator", fun = 1 } } })
        end
    end
    local o = night:decision(card)
    night.actor = prev or night.actor
    if not o then
        return
    end
    local vars = { char = p.char, actor_char = p.char }
    if o.find then
        night.campaign.adv.francs = (night.campaign.adv.francs or 0) + 1
        if night.mus then
            night.mus.francs_earned = (night.mus.francs_earned or 0) + 1
        end
        dm(night, "Tucked away there: " .. o.find .. ". A Flitwidget Franc, in fact.", vars)
    elseif o.clue then
        dm(night, o.clue, vars)
        if o.danger then
            require("game.model.warnings").warn(night, o.danger.id, o.danger.danger, "found")
        end
    elseif o.mishap then
        night:say(util.fill(o.mishap, vars), "bad")
        night.noisy = true          -- (the next fight: nobody sneaks up on anyone. night.lua combat_scene)
    elseif o.scare then
        night:say(util.fill(o.scare, vars), "twist")
        night:react({ [p.key] = "gasp" })
    end
end

-- A natural 20 or 1 on a question (the second playtest review: "a natural 1 or 20 on a question does
-- nothing"): your call, in one card, the harmless answer first. They tell you more than they meant
-- to, or they hear a different question altogether (the adventure's people: their `slip` and
-- `misheard` lines).
local function ask_crit(night, sc, p, q, name, nat)
    local d = data() or {}
    local who = (d.people or {})[q.who] or {}
    local card = { id = "tl_crit", type = "table", trigger = "museum_fixed", fixed_actor = true, options = {} }
    local prev = night.actor
    night.actor = p
    local plain = (nat == 20 and q.better) or q.answer
    name = string.match(name, "^([^,]+)") or name       -- ("Telpur", not "Telpur, a talking boot")
    card.title = nat == 20 and "A natural 20" or "A natural 1"
    card.text = "{actor_char} rolled a natural " .. util.int(nat) .. " asking " .. name .. " a question. Improvise something?"
    table.insert(card.options, { label = "Just the answer.", sub = "Nothing more. On you go.", answer = plain,
        effects = { { "actor", fun = 1 } } })
    if nat == 20 and who.slip then
        table.insert(card.options, { label = name .. " lets something slip.", sub = "A little more than they meant to say.",
            answer = plain, slip = night.rng:pick(who.slip), effects = { { "actor", fun = 3, spotlight = 3 }, { "arch:storyteller", fun = 2 },
            { "arch:method_actor", fun = 2 } } })
    elseif nat == 1 and who.misheard then
        table.insert(card.options, { label = name .. " hears a different question.", sub = "A muddle, and a laugh.",
            answer = night.rng:pick(who.misheard), laugh = true, effects = { { "all", fun = 1 }, { "arch:casual", fun = 2 } } })
    end
    local o = night:decision(card)
    night.actor = prev or night.actor
    return o
end

-- What a friend says back depends on what you said (the second playtest review: "Leave the biscuit."
-- after an answer with no biscuit in it). react = { dull = {...}, detail = {...}, lore = {...},
-- any = {...} }: the answer's own, or one about the poking itself. A line may carry a `when`.
function M.reactions(night, b, level)
    local out = {}
    local adventure = require "game.model.adventure"
    local function take(list)
        for _, l in ipairs(type(list) == "table" and list or { list }) do
            local text = type(l) == "table" and l[1] or l
            if type(text) == "string" and (type(l) ~= "table" or not l.when or adventure.test(night.campaign, l.when)) then
                table.insert(out, text)
            end
        end
    end
    local r = b.react or {}
    if level then
        take(r[level])
    end
    take(r.any)
    return out
end

-- Who says a reaction: not the one who did it, and not someone whose own hero it names.
local function reactor(night, p, text)
    local dialogue = require "game.model.dialogue"
    local named
    for key, names in pairs(dialogue.NAMES) do
        if string.find(text, "%f[%a]" .. names[2] .. "%f[%A]") then
            named = key
        end
    end
    local q = night.campaign:player(named or "")
    if q and util.contains(here(night), q) and q ~= p then
        -- (pick_friend's not_p only takes one: keep the other out by making them "last".)
        return pick_friend(night, { "butt_kicker", "casual", "storyteller" }, q.key, p)
    end
    return pick_friend(night, { "butt_kicker", "casual", "storyteller" }, nil, p)
end

M.crit_card, M.ask_crit = crit_card, ask_crit      -- (for the roadmap words check's unit cases)

-- A friend pokes at something: what's there, their line, the little die, your answer, someone's
-- reaction to what you said.
local function curio(night, sc, b, last, forced)
    local p = forced or pick_friend(night, b.who, last)
    if not p then
        return nil
    end
    night.actor = p
    if b.spot then
        local _, by_id = night:board_places(sc)
        local pl = by_id and by_id[b.spot]
        if pl then
            night:walk(p, { pl.x, pl.y }, nil, sc)
        end
    end
    -- (Something nobody's described yet gets a line first: "I do a cat voice at the cat" with no cat.)
    if b.see then
        night:say(util.fill(b.see, { char = p.char }), "narration")
    end
    say(night, p, b.ask)
    local d, total, pet = tiny_roll(night, p, b.skill)
    local crit = M.crits_on(night.campaign) and (d == 20 or d == 1) and night:room(14)
    local level = ((d == 20 or total >= M.LORE_AT) and b.lore and "lore") or (total >= M.DETAIL_AT and b.detail and "detail") or "dull"
    if pet then
        -- (The pet's nose leads somewhere: "something's here" only when there is.)
        require("game.model.companions").say(night, pet, (level ~= "dull" and not crit) and "hint" or "look")
    end
    if crit then
        crit_card(night, sc, p, b, d)
        level = nil         -- (whatever the card made of it, none of the three answers was said)
    else
        dm(night, b[level], { char = p.char })
        night.heard_lore = night.heard_lore or (level == "lore") or nil     -- ("the clue from earlier": barks' context)
    end
    local reacts = {}
    for _, t in ipairs(M.reactions(night, b, level)) do
        if not names_absent(night, t) then
            table.insert(reacts, t)
        end
    end
    if #reacts > 0 and night.rng:chance(0.7) then
        local text = night.rng:pick(reacts)
        say(night, reactor(night, p, text), text)
    end
    -- (The friends who love poking around get a lift; whoever did it is back in the room.)
    score.nudge_engagement(p, 3)
    night:apply({ { "arch:explorer", fun = 1 } })
    return p
end

-- A question for someone in the room: in character, a little Persuasion or Insight, and an answer
-- that says more on a good roll.
local function ask(night, sc, q, last, forced)
    local p = forced or pick_friend(night, { "method_actor", "storyteller", "instigator", "explorer" }, last)
    if not p then
        return nil
    end
    night.actor = p
    say(night, p, q.ask, true)
    local name = night.tl_people and night.tl_people[q.who]
    -- Someone who's gone off this hero won't answer them (R11: what they did is in the log, and they
    -- remember it: people.lua). A refusal, in their own words, and in the log.
    local people = require "game.model.people"
    local pid = "mus_" .. tostring(q.who)
    if name and people.RANK[people.level(night.campaign, pid, p.key)] < 0 then
        local line = people.line(night, pid, "refuse", p)
        if line then
            night:emit({ kind = "npc", name = name, text = (string.gsub(line, '^"(.*)"$', "%1")) })
            local events = require "game.model.events"
            local why = people.knows_of(night.campaign, pid, "steal", p.key, true) or people.knows_of(night.campaign, pid, "harm", p.key, true)
            local ev = events.add(night.campaign, { kind = "refuse", who = pid, whom = p.key, where = sc.room, from = why, beat = true,
                                                    text = (string.match(name, "^([^,]+)") or name) .. " wouldn't answer " .. p.char })
            sc.last_beat = ev.id
            score.add(p, "fun", -1)
            return p
        end
    end
    local d, total = tiny_roll(night, p, q.skill or "persuasion")
    local text = (total >= 15 and q.better) or q.answer
    local slip
    if name and M.crits_on(night.campaign) and (d == 20 or d == 1) and night:room(14) then
        local o = ask_crit(night, sc, p, q, name, d)
        if o then
            text, slip = o.answer or text, o.slip
        end
    end
    local function line(t)
        -- (The caption adds its own quote marks.)
        t = string.gsub(util.fill(t, { char = p.char }), '^"(.*)"$', "%1")
        night:emit({ kind = "npc", name = name, text = t })
    end
    if name and text then
        line(text)
        if slip then
            line(slip)
        end
    end
    score.nudge_engagement(p, 2)
    night:apply({ { "arch:method_actor", fun = 1 }, { "arch:storyteller", fun = 1 } })
    return p
end

-- A little bit of table life: a snack, a cantrip trick, planning at the door, a souvenir.
local function bit(night, sc, t, last)
    local p = (t.who and night.campaign:player(t.who)) or pick_friend(night, nil, last)
    if p and not util.contains(here(night), p) then
        p = pick_friend(night, nil, last)
    end
    if not p then
        return nil
    end
    -- (Told the way the table tells it: what the heroes get up to, and who says what, in one line
    -- each. Not out of one friend's mouth: "Telpur: 'No eating in the shop'" isn't Sam's to say.)
    for _, line in ipairs(t.lines or {}) do
        night:say(util.fill(line, { char = p.char }), "table")
    end
    if t.kind == "haggle" then
        -- Double or nothing (Telpur's shop): a Franc back, or one more on the price.
        local _, total = tiny_roll(night, p, "persuasion")
        local adv = night.campaign.adv
        if total >= 14 then
            adv.francs = (adv.francs or 0) + 1
            dm(night, "Telpur sighs. \"Fine. One Franc off, for the face.\"")
        elseif (adv.francs or 0) > 0 then
            adv.francs = adv.francs - 1
            dm(night, "Telpur adds a Franc to the bill. \"Lace tax.\" {char} pays it, grumbling.", { char = p.char })
        end
    end
    if t.keepsake then
        night.mus = night.mus or {}
        night.mus.junk = night.mus.junk or {}
        table.insert(night.mus.junk, { who = p.key, what = t.keepsake })
    end
    score.nudge_engagement(p, 2)
    return p
end

-- For the friends' own ideas (game/model/ideas.lua): the curios still to poke at here and the
-- questions still to ask, and poking or asking with a given friend.
function M.open_curios(night, sc)
    local d = data()
    local room = d and d.rooms and d.rooms[sc.room]
    local out = {}
    if not room then
        return out
    end
    local list = candidates(night, sc, room, "enter", nil)
    for _, x in ipairs(list) do
        if x.kind == "curio" then
            table.insert(out, x.b)
        end
    end
    return out
end
function M.open_questions(night, sc, phase)
    local d = data()
    local room = d and d.rooms and d.rooms[sc.room]
    local out = {}
    if not room or phase == "after" then
        return out
    end
    local list = candidates(night, sc, room, phase, nil)
    for _, x in ipairs(list) do
        if x.kind == "ask" then
            table.insert(out, x.b)
        end
    end
    return out
end
function M.poke(night, sc, b, last, p)
    local who = curio(night, sc, b, last, p)
    if who and b.id then
        seen(night)[b.id] = night.campaign.week or 0
    end
    return who
end
function M.ask_one(night, sc, q, last, p)
    local who = ask(night, sc, q, last, p)
    if who and q.id then
        seen(night)[q.id] = night.campaign.week or 0
    elseif who then
        night.tl_bits = night.tl_bits or {}
        night.tl_bits[q] = true
    end
    return who
end

-- Is there still danger in this room (a fight, or a moment with a danger that can still play)? Small
-- moments wait until it's settled (the second playtest review: poking at jars and sand while the
-- guardian lifts its staff, a joke about the pond's tentacle before anyone had seen it).
function M.danger_ahead(night, sc)
    local adventure = require "game.model.adventure"
    local MODULE = adventure.data or {}
    local r = (MODULE.rooms or {})[sc.room] or {}
    if r.encounter then
        return true
    end
    local knobs = night.prep and night.prep.museum and night.prep.museum.knobs or {}
    for _, m in ipairs(MODULE.moments or {}) do
        if m.room == sc.room and m.danger and adventure.test(night.campaign, m.when, knobs) then
            return true
        end
    end
    return false
end

-- A room's quiet stretch: when it starts (after the look round), or once its danger is settled (after
-- its fight and its last moments). A beat or two, never late in the evening, never at 4x, never in
-- the lair. Once a visit.
function M.room(night, sc, phase)
    if not sc or sc.tl_played then
        return 0
    end
    sc.tl_played = true
    if night.end_early or not sc or sc.boss or sc.showdown or sc.epilogue or night.fast then
        return 0
    end
    local lvl = M.level(night.campaign)
    local cap = M.PER_ROOM[lvl] or 2
    local d = data()
    local room = d and d.rooms and d.rooms[sc.room]
    if cap == 0 or not room then
        return 0
    end
    night.tl = night.tl or { n = 0 }
    local tl = night.tl
    local night_cap = M.PER_NIGHT[lvl] or 8
    -- (Late in the evening there's no time for it, unless you asked for one more room and it's a
    -- short one: then its small business is the scene.)
    local one_more = night.one_more and (sc.quick or sc.virtual)
    if (tl.n >= night_cap and not one_more) or ((night.table_min or 0) > (night.table_planned or 210) - 40 and not one_more) then
        return 0
    end
    -- Who's here to ask: the room's own person (not a foe), by the name the table hears.
    night.tl_people = {}
    local cast = sc.comps and sc.comps.cast
    if cast and cast.name and not sc.fight_now then
        local key = string.gsub(string.gsub(cast.id or "", "^mus_", ""), "_.*$", "")
        night.tl_people[key] = cast.name
    end
    for _, q in ipairs(room.npc_questions or {}) do
        if q.who == "flitwidget" and (sc.room == "street" or sc.room == "gift_shop") then
            night.tl_people.flitwidget = night.tl_people.flitwidget or "Flitwidget"
        elseif q.who == "telpur" and sc.room == "gift_shop" then
            night.tl_people.telpur = night.tl_people.telpur or "Telpur"
        end
    end
    local n = (phase == "after") and 1 or cap
    if night.speed_hint == 3 then
        n = math.min(n, 1)           -- (at 2x, one)
    end
    if one_more then
        n = math.max(n, 2)
        night_cap = math.max(night_cap, tl.n + n)
    end
    local done, last = 0, tl.last
    for _ = 1, n do
        if tl.n >= night_cap then
            break
        end
        local list, w = candidates(night, sc, room, phase, last)
        if #list == 0 then
            break
        end
        local pick = night.rng:weighted(list, w)
        local who
        if pick.kind == "curio" then
            who = curio(night, sc, pick.b, last)
        elseif pick.kind == "ask" then
            who = ask(night, sc, pick.b, last)
        else
            who = bit(night, sc, pick.b, last)
            if who then
                tl.bits = (tl.bits or 0) + 1
            end
        end
        if pick.b.id then
            seen(night)[pick.b.id] = night.campaign.week or 0
        else
            -- (A bit without an id: once a night.)
            night.tl_bits = night.tl_bits or {}
            night.tl_bits[pick.b] = true
        end
        if who then
            last = who.key
            tl.n, done = tl.n + 1, done + 1
            night.table_min = (night.table_min or 0) + 1
        end
    end
    tl.last = last
    -- The friends' own ideas (R12): after the small moments, the strongest idea anyone has here.
    if tl.n < night_cap or one_more then
        done = done + util.lazy("game.model.ideas").room(night, sc, phase)
    end
    return done
end

return M
