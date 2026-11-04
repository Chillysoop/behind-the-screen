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

-- Who'd do it: their kind of player, a friend who's drifting gets first go, and not the same friend
-- twice running.
local function pick_friend(night, who, last, not_p)
    local list, w = {}, {}
    for _, p in ipairs(night.players) do
        if p ~= not_p and not (night.watching and night.watching[p.key]) then
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
            if last and p.key == last then
                v = v * 0.2
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
local function candidates(night, sc, room, phase)
    local s = seen(night)
    local out, w = {}, {}
    local adventure = require "game.model.adventure"
    local companions = require "game.model.companions"
    local knobs = night.prep and night.prep.museum and night.prep.museum.knobs or {}
    local function add(b, kind, weight)
        if (b.id and s[b.id]) or (not b.id and night.tl_bits and night.tl_bits[b]) then
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
        add(c, "curio", 3)
    end
    if phase ~= "after" then
        local present = night.tl_people or {}
        for _, q in ipairs(room.npc_questions or {}) do
            if present[q.who] then
                add(q, "ask", 2)
            end
        end
    end
    for _, t in ipairs(room.table_bits or {}) do
        add(t, "bit", 1)
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
        table.insert(card.options, { label = "A small trap: it stings.", sub = "1d4 damage, never enough to drop them.", trap = true,
            effects = { { "actor", challenge = 3 }, { "arch:butt_kicker", fun = 1 } } })
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
    elseif o.trap then
        local hurt = night.rng:int(1, 4)
        local c = night.pcs and night.pcs[p.key]
        if c then
            hurt = math.min(hurt, math.max(0, c.hp - 1))
            c.hp = c.hp - hurt
        end
        night:say(util.fill("A needle in " .. what .. ". {char} yelps: " .. util.int(hurt) .. " damage, and a lesson learned.", vars), "bad")
        night:emit({ kind = "rested", long = false, quiet = true })     -- (the tile shows the hit points)
    end
end

-- A friend pokes at something: their line, the little die, your answer, someone's reaction.
local function curio(night, sc, b, last)
    local p = pick_friend(night, b.who, last)
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
    say(night, p, b.ask)
    local d, total, pet = tiny_roll(night, p, b.skill)
    if pet then
        require("game.model.companions").say(night, pet, "look")
    end
    if M.crits_on(night.campaign) and (d == 20 or d == 1) and night:room(14) then
        crit_card(night, sc, p, b, d)
    else
        local ans = ((d == 20 or total >= M.LORE_AT) and b.lore) or (total >= M.DETAIL_AT and b.detail) or b.dull
        dm(night, ans, { char = p.char })
    end
    if b.react and #b.react > 0 and night.rng:chance(0.7) then
        local other = pick_friend(night, { "butt_kicker", "casual", "storyteller" }, nil, p)
        say(night, other, night.rng:pick(b.react))
    end
    -- (The friends who love poking around get a lift; whoever did it is back in the room.)
    score.nudge_engagement(p, 3)
    night:apply({ { "arch:explorer", fun = 1 } })
    return p
end

-- A question for someone in the room: in character, a little Persuasion or Insight, and an answer
-- that says more on a good roll.
local function ask(night, sc, q, last)
    local p = pick_friend(night, { "method_actor", "storyteller", "instigator", "explorer" }, last)
    if not p then
        return nil
    end
    night.actor = p
    say(night, p, q.ask, true)
    local _, total = tiny_roll(night, p, q.skill or "persuasion")
    local text = (total >= 15 and q.better) or q.answer
    local name = night.tl_people and night.tl_people[q.who]
    if name and text then
        -- (The caption adds its own quote marks.)
        text = string.gsub(util.fill(text, { char = p.char }), '^"(.*)"$', "%1")
        night:emit({ kind = "npc", name = name, text = text })
    end
    score.nudge_engagement(p, 2)
    night:apply({ { "arch:method_actor", fun = 1 }, { "arch:storyteller", fun = 1 } })
    return p
end

-- A little bit of table life: a snack, a cantrip trick, planning at the door, a souvenir.
local function bit(night, sc, t, last)
    local p = (t.who and night.campaign:player(t.who)) or pick_friend(night, nil, last)
    if p and not util.contains(night.players, p) then
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
            dm(night, "Telpur adds a Franc to the bill. \"Lace tax.\" Pip pays it, grumbling.")
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

-- A room's quiet stretch: when it starts (after the look round), or after its fight. A beat or two,
-- never late in the evening, never at 4x, never in the lair.
function M.room(night, sc, phase)
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
    if tl.n >= night_cap or (night.table_min or 0) > (night.table_planned or 210) - 40 then
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
    local done, last = 0, tl.last
    for _ = 1, n do
        if tl.n >= night_cap then
            break
        end
        local list, w = candidates(night, sc, room, phase)
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
    return done
end

return M
