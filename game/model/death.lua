-- Death at the table (M8, B3). "The last death save" is the way in: fudge it (the existing
-- cooked roll), or let it ride, and then this flow: what happens next, filtered by what Session
-- Zero agreed and what each player asked for; the goodbye; a new character next week, or back
-- with a scar; and the shelf of fallen heroes. game/data/death.lua has the words and numbers.
-- Pure Lua.

local score = require "game.model.score"
local util = require "game.model.util"
local data = require "game.data.death"

local M = {}
M.data = data

-- The table's default, and this player's own setting if the DM honours their preference.
function M.table_mode(campaign)
    local r = campaign.table and campaign.table.rules
    return (r and r.death) or data.DEFAULT
end

function M.mode_for(campaign, key)
    local o = campaign.death_overrides and campaign.death_overrides[key]
    return o or M.table_mode(campaign)
end

-- Honour (or stop honouring) a player's own preference: from their character sheet.
function M.set_override(campaign, key, mode)
    campaign.death_overrides = campaign.death_overrides or {}
    campaign.death_overrides[key] = mode
end

function M.pref(key)
    return data.PREF[key]
end

-- The options for this death, by the mode that applies to them. Each: { label, outcome }.
--   goodbye   they're gone: last words and a wake, a new character next week
--   quick     gone, without the goodbye (a small cost)
--   scar      back now, with a scar in canon
--   ask       the player decides (by who they are)
function M.options(campaign, p)
    local mode = M.mode_for(campaign, p.key)
    local opts = {}
    local function add(label, outcome)
        table.insert(opts, { label = label, outcome = outcome })
    end
    if mode == "permanent" or mode == "meaningful" then
        add("Say goodbye. {actor_char} gets last words, and the table holds a wake.", "goodbye")
        add("Move on quickly. A new character joins next week.", "quick")
    elseif mode == "cost" then
        add("Bring {actor_char} back, and it leaves a mark.", "scar")
        add("Let {actor_char} go. Say goodbye.", "goodbye")
    else
        add("Ask {actor}. It's {friend_their} call.", "ask")
        add("Say goodbye. {actor_char} gets last words, and the table holds a wake.", "goodbye")
    end
    return opts, mode
end

-- What a player picks when it's their call: a good ending, or back at any cost (an adventure's
-- rooms are the book's, so there's no quest scene to earn a way back in).
function M.player_choice(p)
    local a = p.primary
    if a == "method_actor" or a == "storyteller" then
        return "goodbye"
    end
    return "scar"
end

-- Did this outcome honour what they wanted? 1 yes, -1 no, 0 neither.
local function honoured(pref, outcome, asked)
    if asked then
        return 1
    end
    local gone = outcome == "goodbye" or outcome == "quick"
    if pref == "permanent" then
        return gone and 1 or -1
    elseif pref == "meaningful" then
        return outcome == "goodbye" and 1 or (outcome == "quick" and -1 or 0)
    elseif pref == "cost" then
        return gone and -1 or 1
    elseif pref == "choice" then
        return -1      -- they wanted a say and didn't get one
    end
    return 0
end

-- A hero has died on game night. Deals the card, plays what follows, and records it.
function M.on_death(night, p, c, sc)
    local campaign = night.campaign
    local opts, mode = M.options(campaign, p)
    -- (Its actor is the hero who died: a trigger keeps the card from handing it to someone else,
    -- the combat audit, Nov 2: the card named whoever the table's picker chose.)
    local card = { id = "hero_dies", type = "screen", title = p.char .. " is dead", trigger = "hero_dies", fixed_actor = true,
                   text = "By the rules and the dice, {actor_char} is dead. Session Zero said: "
                       .. string.lower(data.MODE[mode].name) .. ". {actor} is waiting to see what you do.",
                   options = {} }
    for i, o in ipairs(opts) do
        card.options[i] = { label = o.label, log = nil, effects = {}, outcome = o.outcome }
    end
    night.actor = p
    local o = night:decision(card)
    -- The last death save and what follows are one moment at the table: one decision.
    if night.last_save_for == p.key then
        night.counts.decision = night.counts.decision - 1
        night.last_save_for = nil
    end
    local outcome = o and o.outcome or opts[1].outcome
    local asked = outcome == "ask"
    if asked then
        outcome = M.player_choice(p)
        night:emit({ kind = "say", who = p.key, text = outcome == "goodbye" and "Let them go. It's a good ending."
            or "Bring them back. I don't care what it costs.", ic = false })
    end
    local h = honoured(M.pref(p.key), outcome, asked)
    local fair = h >= 0 and outcome ~= "quick"           -- a death the villain can be taunted about
    score.add(p, "trust", h > 0 and data.HONOURED or (h < 0 and data.IGNORED or 0))
    if h < 0 then
        score.add(p, "fun", -6)
    end
    campaign.deaths = campaign.deaths or {}
    local rec = { key = p.key, char = p.char, class = p.class, level = campaign.level or 2, week = campaign.week,
                  slain_by = night.villain_here, at = sc and sc.comps.location and sc.comps.location.id,
                  how = "fell at " .. ((sc and sc.comps.location and (sc.comps.location.short or util.lower_first(sc.comps.location.name))) or "the table")
                      .. ((night.battle_boss_name and (" to " .. night.battle_boss_name)) or ""),
                  outcome = outcome, mini = p.mini or nil }
    rec.fair = fair
    table.insert(campaign.deaths, rec)
    local dev = { who = p.key, text = p.char .. " died. " .. util.capitalize(rec.how) .. ".", weight = 10 }
    night:event("death", dev)
    -- (In the event log, the one record: a beat that turns the fight that took them, told first in the
    -- recap, and what the people there remember. Round three, B1 and A7.)
    local events = require "game.model.events"
    local loc = sc and sc.comps and sc.comps.location
    local room = loc and (loc.short or util.lower_first(loc.name)) or "the museum"
    rec.ev = events.add(campaign, { kind = "death", who = p.key, where = sc and sc.room, beat = true, lead = true,
                                    from = sc and sc.fight_ev, how = "but", outcome = nil,
                                    text = events.word("death", { char = p.char, room = room }, "{char} died") }).id
    -- What came of it, for the recap (October 15: "We lost Brannoc", when he came back), and the
    -- canon line the death save wrote ("Brannoc died at ...") says how it ended.
    dev.outcome = outcome
    local after = (outcome == "scar" and ", and came back") or nil
    if after then
        for i = #(night.canon or {}), 1, -1 do
            if string.find(night.canon[i], p.char .. " died", 1, true) then
                night.canon[i] = night.canon[i] .. after
                break
            end
        end
    end
    if outcome == "scar" and rec.ev then
        -- (Brought back: the log says so, and it's no longer a death.)
        local ev = events.get(campaign, rec.ev)
        if ev then
            ev.kind, ev.lead, ev.back = "back", nil, true
            ev.text = events.word("came_back", { char = p.char }, "{char} nearly died, and came back")
        end
    end
    if outcome == "goodbye" or outcome == "quick" then
        M.fall(night, p, rec, outcome == "goodbye")
    elseif outcome == "scar" then
        local scar = util.fill(data.SCARS[night.rng:int(1, #data.SCARS)], { char = p.char })
        p.scar = scar
        table.insert(night.canon, scar)
        night:say(scar, "narration")
        night:highlight(9, p.char .. " came back", { p }, "back")
        rec.back = campaign.week
    end
    return outcome
end

-- They're gone: the goodbye (or not), the shelf, and a new character next week.
function M.fall(night, p, rec, goodbye)
    local campaign = night.campaign
    if goodbye then
        local lines = data.LAST_WORDS[p.class] or data.LAST_WORDS.fighter
        night:emit({ kind = "say", who = p.key, text = lines[night.rng:int(1, #lines)], ic = true, farewell = true })
        -- (The wake comes once the danger's over, back where they rest: M.hold_wake. Round three, B1: it
        -- was held while Euryale still knelt in her lair.)
        night.wake_due = night.wake_due or {}
        table.insert(night.wake_due, p.char)
        score.add(p, "spotlight", data.GOODBYE.spotlight)
        score.add(p, "story", data.GOODBYE.story)
        for _, q in ipairs(night.players) do
            score.add(q, "social", data.GOODBYE.social)
            score.add(q, "story", 4)
        end
        local poses = {}
        for _, q in ipairs(night.players) do
            poses[q.key] = "gasp"
        end
        night:react(poses)
        night:highlight(10, p.char .. "'s last words", { p }, "goodbye")
    else
        score.add(p, "fun", data.GOODBYE.skip_fun)
    end
    campaign.fallen = campaign.fallen or {}
    table.insert(campaign.fallen, rec)
    campaign.new_char = campaign.new_char or {}
    campaign.new_char[p.key] = { week = campaign.week, was = p.char }
    table.insert(night.canon, p.char .. " " .. rec.how)
    M.after_fall(night, p)
    M.settle_pack(night, p)
end

-- What the dead hero carried (round three, A1, found by batch B: the bracelet showed on "Sister Aldith's
-- wrist", the new hero in the dead one's seat): it's settled out loud, never inherited. The friends whose
-- heroes can act share it out, a magic thing to whoever can use it, the rest to the closest friend; with
-- nobody left to take it, it stays with them. Each change of hands is in the log ("given", from the dead).
-- The words: game/data/death.lua PACK_SHARED, PACK_LEFT.
function M.settle_pack(night, p)
    local campaign = night.campaign
    local items = require "game.model.items"
    local events = require "game.model.events"
    local held = items.held_by(campaign, p.key)
    if #held == 0 then
        return
    end
    local able = require "game.model.able"
    local here = {}
    for _, q in ipairs(night.players) do
        if q ~= p and able.can_act(night, q) then
            table.insert(here, q)
        end
    end
    if #here == 0 then
        -- (Where it fell, so it's picked up there: M.pick_up_pack.)
        local at = night.scene and night.scene.room
        for _, it in ipairs(held) do
            it.left_with = p.key
            it.left_char = p.char
            it.left_at = at
            it.gone = campaign.week or 0
        end
        night:say(night:fresh(data.PACK_LEFT, "pack_left"), "narration", { char = p.char })
        return
    end
    -- (The friend closest to them takes what isn't for anyone in particular.)
    local rapport = require "game.model.rapport"
    local close, best = here[1], nil
    for _, q in ipairs(here) do
        local r = rapport.rel(campaign, q.key, p.key)
        local v = type(r) == "table" and (r.rapport or 0) or 0
        if not best or v > best then
            close, best = q, v
        end
    end
    local gets, order = {}, {}
    for _, it in ipairs(held) do
        local to = close
        if items.def(it.id) then
            to = items.pick_holder(campaign, it.id, here) or close
        end
        it.holder = to.key
        items.log_get(campaign, it, { id = p.key, name = p.char }, "given")
        local about = items.about(it)
        local t = it.thing and items.thing(it.thing)
        local name = (t and util.lower_first(t.name or t.title)) or util.lower_first(about.name or "something")
        if not gets[to.key] then
            gets[to.key] = {}
            table.insert(order, to)
        end
        table.insert(gets[to.key], name)
    end
    local parts = {}
    for _, q in ipairs(order) do
        table.insert(parts, q.char .. " takes " .. util.join_names(gets[q.key]))
    end
    night:say(night:fresh(data.PACK_SHARED, "pack_shared"), "narration", { char = p.char, gets = table.concat(parts, "; ") })
end

-- Back in the room where a hero fell with nobody left to take their pack: whoever can act there picks it
-- up (their seat's new hero first), out loud and in the log. The confirming playtest, 56 careful: "It stays
-- where he fell", and the next week Bryn walked in carrying it.
function M.pick_up_pack(night, room)
    local campaign = night.campaign
    local items = require "game.model.items"
    local able = require "game.model.able"
    local by_old, order = {}, {}
    for _, it in ipairs(items.list(campaign)) do
        if it.left_at and it.left_at == room and it.gone then
            if not by_old[it.left_with] then
                by_old[it.left_with] = {}
                table.insert(order, it.left_with)
            end
            table.insert(by_old[it.left_with], it)
        end
    end
    for _, old in ipairs(order) do
        local who
        local seat = campaign:player(old)
        if seat and util.contains(night.players, seat) and able.can_act(night, seat) then
            who = seat
        end
        for _, q in ipairs(night.players) do
            who = who or (able.can_act(night, q) and q) or nil
        end
        if who then
            local names, char = {}, nil
            for _, it in ipairs(by_old[old]) do
                char = char or it.left_char
                it.holder, it.gone, it.left_at, it.left_with = who.key, nil, nil, nil
                items.log_get(campaign, it, { id = old, name = it.left_char }, "found")
                local about = items.about(it)
                local t = it.thing and items.thing(it.thing)
                table.insert(names, (it.id == items.POTION and "a healing potion")
                    or (t and util.lower_first(t.name or t.title)) or util.lower_first(about.name or "something"))
                it.left_char = nil
            end
            night:say(night:fresh(data.PACK_FOUND, "pack_found"), "narration",
                { char = char or "the one who fell", who = who.char, gets = util.join_names(names) })
        end
    end
end

-- The wake (round three, B1): held where they rest, once the fight that took them is over and
-- whatever came after it is settled (the gift shop, or the night's end), never mid-lair. The
-- adventure's words (data.WAKE); whoever runs the place says something (people_lines `grief`).
-- here: the room they're in, when that isn't the place they rest (data.WAKE_HERE: before they've found it).
function M.hold_wake(night, here)
    local due = night.wake_due
    if not due or #due == 0 then
        return false
    end
    night.wake_due = nil
    local names = util.join_names(due)
    night:say(util.fill((here and data.WAKE_HERE) or data.WAKE, { char = names, room = here or "" }), "narration")
    local ok, people = pcall(require, "game.model.people")
    local line = ok and people.line and night.mus and people.line(night, "mus_flitwidget", "grief", nil,
        { char = names, plural = #due > 1 or nil }) or nil
    if line then
        night:emit({ kind = "npc", name = "Flitwidget", cast = "mus_flitwidget", text = line })
    end
    return true
end

-- The table, after (the playtest, November 3: "does the player immediately leave the table? How
-- does the table react?"). A friend says something; the player stays, and you decide what they do
-- with the rest of the night: play someone who's with the party, help you run the monsters, or
-- watch and start on their new hero.
M.FRIEND_SAYS = { "No. No no no. {char}.", "That was a good death, {name}. Honestly.", "I'm so sorry. {char} was the best of us.",
                  "Okay, I'm actually sad about this." }
M.STAYS_SAYS = { "I'm staying. I want to see how it ends.", "I'm not going anywhere. Pass the crisps.",
                 "Can I at least do the voices for the monsters?" }
function M.after_fall(night, p)
    local friend, best
    local rapport = require "game.model.rapport"
    for _, q in ipairs(night.players) do
        if q ~= p then
            local r = rapport.rel(night.campaign, q.key, p.key)
            local v = type(r) == "table" and (r.rapport or 0) or 0
            if not best or v > best then
                friend, best = q, v
            end
        end
    end
    if friend then
        night:emit({ kind = "say", who = friend.key, text = util.fill(night:fresh(M.FRIEND_SAYS, "fall_friend"), { char = p.char, name = p.name }),
                     ic = false })
    end
    night:emit({ kind = "say", who = p.key, text = night:fresh(M.STAYS_SAYS, "fall_stays"), ic = false })
    night.watching = night.watching or {}
    night.watching[p.key] = true
    if not night:room(14) then
        return
    end
    local companions = require "game.model.companions"
    local ally
    for _, e in ipairs(companions.active(night.campaign, night.players)) do
        if e.monster and not e.pocket then
            ally = e
        end
    end
    local card = { id = "fallen_seat", type = "table", trigger = "museum_fixed", fixed_actor = true,
                   title = "{actor} is still at the table",
                   text = "{actor_char} is gone, but {actor} isn't going anywhere. What does {actor} do for the rest of the night?",
                   options = {} }
    if ally then
        -- (A card's sub isn't filled in for you: said here with their name.)
        table.insert(card.options, { label = "{actor} plays " .. ally.name .. " from now on.",
                                     sub = ally.name .. " is in every fight; " .. p.name .. " runs " .. util.pronoun_of(ally.name).them .. ".",
                                     pilot = ally.id, effects = { { "actor", fun = 5, spotlight = 4 } } })
    end
    table.insert(card.options, { label = "{actor} helps you run the monsters.",
                                 sub = util.fill("{Friend_they'll} love it. The others might find the monsters a little meaner.", { actor = p.name }),
                                 effects = { { "actor", fun = 4, social = 3 }, { "others", challenge = 2 } }, monsters = true })
    table.insert(card.options, { label = "{actor} watches, and starts on a new hero.", effects = { { "actor", fun = -1, investment = 2 } } })
    night.actor = p
    local o = night:decision(card)
    if o and o.pilot then
        night.pilots = night.pilots or {}
        night.pilots[o.pilot] = p.key
    elseif o and o.monsters then
        night.monster_helper = p.key
    end
end

-- A fudged last save. The second and later ones cost Trust with the players who came for stakes.
function M.fudged(night)
    local campaign = night.campaign
    campaign.death_fudges = (campaign.death_fudges or 0) + 1
    if campaign.death_fudges >= 2 then
        night:apply({ { "arch:tactician", trust = data.FUDGE_STAKES }, { "arch:butt_kicker", trust = data.FUDGE_STAKES },
                      { "arch:power_gamer", trust = data.FUDGE_STAKES } })
        local q = night:pick_actor(data.STAKES)
        if q then
            night:emit({ kind = "say", who = q.key, text = "Does anyone actually die in this game?", ic = false })
        end
    end
end

-- The start of a week: whoever fell rolls up a new character (the next pregen of their class),
-- and a way back that went unused closes.
function M.start_week(campaign)
    local out = {}
    for key, nc in util.sorted_pairs(campaign.new_char or {}) do
        local p = campaign:player(key)
        if p and not nc.done then
            local used = campaign.pregens_used or {}
            campaign.pregens_used = used
            local pick
            for _, g in ipairs(data.PREGENS[p.class] or {}) do
                if not pick and not used[g.id] then
                    pick = g
                end
            end
            pick = pick or (data.PREGENS[p.class] or data.PREGENS.fighter)[1]
            used[pick.id] = true
            -- The fallen hero's sheet goes on the shelf; the new character starts fresh.
            if campaign.party_state and campaign.party_state.pcs then
                campaign.party_state.pcs[key] = nil
            end
            p.old_char = p.char
            p.char = pick.name
            p.pregen = pick.id
            p.mini = pick.mini
            p.hook = pick.hook
            -- The fallen hero's story ended with them; the new one's starts here.
            p.thread = util.lower_first(pick.hook)
            p.thread_progress = 0
            nc.done = true
            nc.joins = campaign.week
            nc.pregen = pick.id
            table.insert(out, { key = key, pregen = pick, was = nc.was })
        end
    end
    return out
end

-- The night a new character joins: their introduction, a Spotlight spike and a warm-up.
function M.intro(night)
    local campaign = night.campaign
    for key, nc in util.sorted_pairs(campaign.new_char or {}) do
        if nc.joins and nc.joins <= campaign.week and not nc.introduced then
            local p = night.campaign:player(key)
            local g
            for _, x in ipairs(data.PREGENS[p.class] or {}) do
                if x.id == nc.pregen then
                    g = x
                end
            end
            if p and g and p.present then
                nc.introduced = true
                -- Who this is, before the scene introduces them (the story playtest: a new name
                -- turning up with no word of who they are lost the table).
                night:say(p.name .. " has a new character tonight: " .. p.char .. ". " .. (g.hook or ""), "system")
                night:say(util.fill(data.INTRO[g.intro] or data.INTRO.hired, { new = p.char, old = nc.was }), "opening")
                score.add(p, "spotlight", data.INTRO_SPOTLIGHT)
                score.add(p, "fun", 4)
                night:react({ [p.key] = "lean" })
                night:event("new_character", { who = p.key, text = p.char .. " joins the party, in " .. nc.was .. "'s place.", weight = 7 })
                -- (A pet that was the fallen hero's running joke is handed on, once, out loud: the confirming
                -- playtest, 56 careful, had Exhibit B carry on with Tam as if Pip had never been.)
                for _, e in ipairs(require("game.model.companions").active(campaign, night.players)) do
                    local said = e.lines and e.lines.handed_on
                    if e.kind == "pet" and e.owner == key and said then
                        night:say(util.fill(night:fresh(said, "handed_on_" .. e.id), { new = p.char, old = nc.was }), "narration")
                    end
                end
            end
        end
    end
end

return M
