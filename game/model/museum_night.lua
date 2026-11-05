-- Game night in the museum (v2): the night walks the module's map room by room until the evening
-- runs out or the party reaches a natural stop, asks the DM at each fork, plays each room's own
-- moments, and cuts upstairs to Euryale as her card picks up marks. Boss night is its own shape.
-- Engine-free; it drives game/model/night.lua's methods (the night is passed in, never required).

local content = require "game.model.content"
local util = require "game.model.util"
local score = require "game.model.score"
local rapport = require "game.model.rapport"
local adventure = require "game.model.adventure"
local prep_mod = require "game.model.prep"
local map_repo = require "game.model.map_repo"
local thoughts = require "game.model.thoughts"
local standing = require "game.model.standing"
local ties = require "game.model.ties"
local fight = require "game.model.fight"

local events = require "game.model.events"
local able = require "game.model.able"
local people = require "game.model.people"
local _ideas = require "game.model.ideas"      -- (reached lazily from table_life.lua: required here so it's built in)

local MODULE = adventure.data
local M = {}

M.STOP_BEFORE_END = 25     -- table minutes: no new room this close to the agreed end
M.FINISH_FLOOR = 20        -- ...unless it's the floor's last room, and the night isn't this far past its end
M.MAX_BACKS = 2            -- trips back to a cleared room in one night (a second look, a rest, fleeing)
M.KEEN = 0.5               -- how much someone has to want a trip back before it's even raised

local function present(night, key)
    for _, p in ipairs(night.players) do
        if p.key == key then
            return p
        end
    end
end

local function st_of(night)
    return adventure.fill(night.campaign.adv)
end

local function knobs_of(night)
    return (night.prep and night.prep.museum and night.prep.museum.knobs) or {}
end

-- Fill-ins only the museum has: the hero's painting, the Mech's name, the party's Francs.
local function mus_vars(night, sc)
    local st = st_of(night)
    local v = { francs = tostring(st.francs or 0), mech = st.mech_name or "Hans" }
    local who = night.actor and night.actor.key
    local pick = knobs_of(night).portrait
    local whose = (type(pick) == "string" and MODULE.portraits[pick] and pick) or (who and MODULE.portraits[who] and who) or nil
    local port = (whose and MODULE.portraits[whose]) or MODULE.portrait_default or {}
    v.portrait_whose = whose          -- (whose painting this is, if anyone's: the one the hall shows)
    v.painting = port.painting or "a frosty mountain portrait"
    v.gift = port.gift or "a painted scimitar"
    v.gift_the = (string.gsub(v.gift, "^an? ", "the "))      -- (the one they pulled out: "the painted scimitar")
    v.gift_empty = port.empty or nil
    -- (What reaching into this painting risks, as the book has it: mus_reach.)
    v.portrait = port
    v.reach_hint = port.hint and (" " .. port.hint) or ""
    return v
end

-- What's said when something changes hands at the table (round three, batch B: "Thessaly came away with
-- the Lecturer's notes" in every report, and no line ever gave them to her). Each three ways, fresh
-- across weeks; on the Dialogue Desk (tools/dialogue/export.lua CODE_TABLES, when.lua).
M.WORLD_LINES = {
    -- The Lecturer's notes, picked up by whoever's best with a page (the room's end, the Lecturer silenced).
    pages = { "{char} gathers every page up off the floor.",
              "{char} scoops up the three pages, careful not to read a single word.",
              "{char} picks the pages up by one corner and folds them away, unread." },
    -- A Franc paid for what they did, when the moment's own words didn't hand it over (to the hero
    -- whose moment it was; the party's, when it was everyone's), said as it goes in the pool.
    franc = { "A Flitwidget Franc turns up in {char}'s pocket. The gnome pays for clever.",
              "{char} finds a crisp Flitwidget Franc tucked in {char_their} sleeve. Clever pays, in this museum.",
              "There's a Flitwidget Franc in {char}'s hand that wasn't there a moment ago." },
    francs = { "{n} Flitwidget Francs turn up in {char}'s pocket. The gnome pays for clever.",
               "{char} finds {n} crisp Flitwidget Francs tucked in {char_their} sleeve. Clever pays, in this museum.",
               "There are {n} Flitwidget Francs in {char}'s hand that weren't there a moment ago." },
    -- (Right after the same roll's triumph Franc: one more, to the same hero.)
    franc_more = { "And a second Franc for {char}: the gnome pays for clever, too.",
                   "That's two Flitwidget Francs for {char} off one roll. The gnome pays for clever.",
                   "Another Flitwidget Franc turns up for {char}, for the clever bit. Two off one roll." },
    francs_more = { "And {n} more Flitwidget Francs for {char}: the gnome pays for clever, too.",
                    "{n} more Flitwidget Francs turn up for {char}, for the clever bit.",
                    "On top of that, {n} more Flitwidget Francs for {char}. The gnome pays for clever." },
    franc_party = { "A Flitwidget Franc flutters down out of nowhere. The gnome pays for clever.",
                    "A crisp Flitwidget Franc turns up on the floor at their feet.",
                    "Somebody finds a Flitwidget Franc in the party's things that wasn't there before." },
    francs_party = { "{n} Flitwidget Francs flutter down out of nowhere. The gnome pays for clever.",
                     "{n} crisp Flitwidget Francs turn up on the floor at their feet.",
                     "Somebody finds {n} Flitwidget Francs in the party's things that weren't there before." },
    -- Francs someone pressed on them between sessions (a favor), said as the next night starts.
    between_francs = { "Between sessions, {who} pressed {n} Flitwidget Francs on them, \"for the trouble\". That's {pool} in the pool.",
                       "{who} slipped them {n} Francs between sessions, with a wink. The pool's at {pool}.",
                       "Since last time, {who} has found {n} Francs for them, from somewhere. {pool} in the pool now." },
    -- Heroes still stone when she's beaten them and lets them go (a lost fight in her lair): how they came
    -- back, said, before "She lets them go" (the confirming playtest, seed 54: Oswin stone, then whole the
    -- next week with no word).
    -- Her garden burned, and she's beaten them once already: back up her stairs, she knows them.
    burned_again = { "\"You came back. You still smell of my garden.\" No drink this time either.",
                     "\"Again? You still smell of smoke.\" She doesn't pour anything.",
                     "Euryale doesn't get up. \"Back from the floor, and still smelling of my garden.\" No drink." },
    stone_let_go = { "Euryale waves a hand, and {names} {crack} out of the stone, gasping.",
                     "The grey drains out of {names} as Euryale turns away.",
                     "Euryale snaps her fingers. {names} {crack} out of the stone, gasping." },
    -- A promise kept: first pick of the next find, to the friend it was promised to.
    first_pick = { "{by} hangs back: \"First pick's {to_char}'s. I promised.\"",
                   "{to_char} gets first pick, as {by_char} promised.",
                   "\"Yours,\" says {by}, nodding at {to_char}. \"First pick. A promise is a promise.\"" },
    -- What a hero pocketed, given back at Flitwidget's thanks if it hasn't come back already.
    pocket_back = { "{char} quietly puts {thing} back on Flitwidget's counter. Flitwidget pretends not to see.",
                    "Before the biscuits, {char} slides {thing} across the counter to Flitwidget. \"Found it.\"",
                    "{char} gives {thing} back to Flitwidget, a little sheepishly. He pockets it and says nothing." },
    -- The same, when the one who pocketed it can't (dead, or stone): a friend gives it back for them
    -- ({who}: the hero who pocketed it). Round three: "Pip quietly puts a glass eye back" with Pip dead.
    pocket_back_for = { "In {who}'s place, {char} puts {thing} back on Flitwidget's counter. Flitwidget nods.",
                        "{char} gives {thing} back to Flitwidget in {who}'s place, a little sheepishly.",
                        "{char} sets {thing} on the counter, in {who}'s place. Flitwidget takes it gently." },
    -- The archivist's notebook, taken by whoever took the second study in (the room's end).
    notebook = { "{char} tucks the archivist's notebook under {char_their} arm.",
                 "{char} slips the notebook into {char_their} pack, carefully, as if it might bite.",
                 "{char} closes the notebook gently and takes it off the desk." },
}

-- The event log (R7, R14: game/model/events.lua) ---------------------------------------------------
-- Every beat the night plays goes in the log with what it follows from: a room walked into for a
-- reason, the moment a choice came from, what a roll turned. Consequences (a mark, a thing changing
-- hands, a fight) follow from the cause the night is playing (events.cause).

-- The party's own words for what they chose (an option's `want`, "set the bushes on fire"), as a
-- clause for the chain: "they set the bushes on fire".
local PAST = { buy = "bought", reach = "reached", skip = "skipped", save = "saved", give = "gave", work = "worked",
               leave = "left", forget = "forgot", keep = "kept", douse = "doused", set = "set", flip = "flipped",
               drop = "dropped", pick = "picked", tidy = "tidied", shoulder = "shouldered", take = "took", go = "went",
               try = "tried", have = "had", follow = "followed", put = "put", drink = "drank", fight = "fought",
               let = "let", make = "made", finish = "finished", talk = "talked", read = "read", wake = "woke",
               smash = "smashed", ask = "asked", help = "helped", hide = "hid", poke = "poked", lift = "lifted" }
function M.past(phrase)
    if type(phrase) ~= "string" then
        return nil
    end
    local lead, first, rest = string.match(phrase, "^(just )(%a+)(.*)$")
    if not lead then
        lead, first, rest = "", string.match(phrase, "^(%a+)(.*)$")
    end
    local v = first and PAST[string.lower(first)]
    if not v then
        return nil
    end
    rest = string.gsub(rest, "%f[%a]us%f[%A]", "them")
    rest = string.gsub(rest, "%f[%a]we%f[%A]", "they")
    return lead .. v .. rest
end

-- The clause a moment's beat is told with: the adventure's own (MODULE.beats: did, ok when its roll
-- worked), else the party's want in the past tense. nil: it isn't a beat (a call that changed nothing
-- in the story: "Not this time").
local function changes(mus)
    return type(mus) == "table" and (mus.flag or mus.mark or mus.francs or mus.fight or mus.no_fight or mus.drop or mus.hurt
        or mus.ending or mus.resolve or mus.spend or mus.careful or mus.favor or mus.unmark or mus.use or mus.deeds) ~= nil
end
function M.beat_clause(night, card, o, i, rolled_ok)
    local b = MODULE.beats and MODULE.beats[card.id]
    local ob = b and b[i]
    local who = night.actor and night.actor.char or "they"
    local subj = card.party and "they" or who
    local function fill(t)
        return t and util.fill(t, { char = who, actor_char = who, mech = (st_of(night).mech_name or "the Mech"),
                                    gift = night.mus_vars and night.mus_vars.gift_the or "the painted weapon" }) or nil
    end
    if type(ob) == "table" then
        if rolled_ok and ob.empty and night.mus_vars and night.mus_vars.gift_empty then
            return fill(ob.empty)
        end
        if rolled_ok and ob.ok then
            return fill(ob.ok)
        end
        if ob.did then
            return fill(ob.did)
        end
    elseif type(ob) == "string" then
        return fill(ob)
    end
    if ob == false then
        return nil
    end
    local out = o.roll and (rolled_ok and o.roll.success or o.roll.fail) or nil
    if not (changes(o.mus) or o.roll or (out and changes(out.mus))) then
        return nil
    end
    -- (Looking round a room: what they went over to.)
    if card.look then
        return events.word("look", { char = who, what = card.look })
    end
    -- (A roll that didn't come off was a try, not a deed: "they tried to put her to sleep".)
    if o.roll and not rolled_ok and o.want and string.match(o.want, "^%a+") and PAST[string.lower(string.match(o.want, "^%a+"))] then
        local w = string.gsub(string.gsub(o.want, "%f[%a]us%f[%A]", "them"), "%f[%a]we%f[%A]", "they")
        return events.word("tried", { who = subj, want = w })
    end
    local p = M.past(o.want)
    return p and (subj .. " " .. p) or nil
end

-- What a card (or one of its options) waits on: the event that made it possible (a flag a moment set,
-- a mark on her card, a moment that played, a choice on an earlier card). Its beat follows from that.
local function gate_cause(night, conds)
    local c = night.campaign
    for _, cond in ipairs(conds) do
        if type(cond) == "table" then
            local ev = (cond.flag and events.last(c, { kind = "moment", flag = cond.flag }))
                or (cond.flag and events.last(c, { kind = { moment = true, setback = true }, flag2 = cond.flag }))
                or (cond.mark and events.last(c, { kind = "mark", thing = cond.mark }))
                or (cond.seen and events.last(c, { kind = "moment", card = cond.seen }))
                or (cond.chose and events.last(c, { kind = "moment", card = cond.chose[1] }))
                or (cond.holds and events.last(c, { kind = "get", thing = cond.holds }))
            if ev then
                return ev
            end
        end
    end
    return nil
end
M.gate_cause = gate_cause

-- A beat of the night, written to the log (the room it's in, the hero it's about).
function M.log_beat(night, ev, sc)
    sc = sc or night.scene
    ev.where = ev.where or (sc and sc.room) or nil
    ev.beat = ev.text ~= nil or nil
    local e = events.add(night.campaign, ev)
    if sc and e.beat then
        sc.last_beat = e.id
    end
    return e
end

-- Building a room's scene -------------------------------------------------------------------------

function M.build_scene(night, id)
    local r = MODULE.rooms[id]
    local comps = {}
    for kind, cid in pairs(r.comps or {}) do
        -- (Someone the DM is keeping out of sight: the room plays without them. game/model/ties.lua)
        if not (kind == "cast" and not r.epilogue and adventure.person_hidden(night.campaign, cid)) then
            comps[kind] = content.components[cid]
        end
    end
    local pm = night.prep and night.prep.museum
    local prepped = pm and pm.prepped and pm.prepped[id] or false
    if id == "lair" and pm and pm.boss then
        prepped = true          -- (boss week's hours already went on the lair: museum_week.spent)
    end
    if MODULE.rooms[id].epilogue then
        prepped = true
    end
    -- Improvised on the spot (M.whats_there): no skimming, short, and a little thinner than prepped.
    local improv = (not prepped) and night.mus and night.mus.improv and night.mus.improv[id] or false
    if improv then
        prepped = true
    end
    -- The backup page (an hour of prep: museum_week.SPARE): the first room tonight that wasn't prepped.
    local backup = false
    if not prepped and not r.virtual and (r.cost or 0) > 0 and pm and pm.spare and pm.spare.backup then
        night.mus = night.mus or {}
        if not night.mus.backup_used then
            night.mus.backup_used = id
            prepped, backup = true, true
        end
    end
    local q = r.virtual and 0.6 or prep_mod.quality(r.type, comps)
    local sc = {
        type = r.type, comps = comps, missing = {}, room = id, quick = r.quick or (improv and true) or nil, virtual = r.virtual,
        prepped = prepped or r.virtual,
        backup = backup or nil,
        improv = improv or nil,
        quality = q - ((prepped or r.virtual or r.cost == 0) and 0 or MODULE.UNPREPPED_QUALITY) - (improv and 0.1 or 0),
        difficulty = prep_mod.difficulty(comps),
        optional_fight = r.optional_fight,
        boss = r.boss,
        epilogue = r.epilogue,
        rest_here = r.rest or nil,
    }
    if r.encounter then
        sc.encounter = { ids = util.copy(r.encounter), boss_name = r.boss_name, built = true }
    end
    sc.wake = r.wake           -- the room's pieces that come alive when the fight starts (fight.lua)
    -- The DM's choice of map from the repository: for this room (prep), or the next scene (tonight).
    local ref = night.map_next or map_repo.room_map(night.campaign, id)
    if ref then
        local t, m = map_repo.terrain_of(night.campaign, ref)
        if t then
            sc.board_override, sc.custom_map = t, m
        end
        night.map_next = nil
    end
    return sc
end

-- The adventure's own fight lineups go to the battle as they are (no XP padding).
local function drop_from(sc, ids)
    if not (sc.encounter and ids) then
        return
    end
    for _, mid in ipairs(ids) do
        for i, e in ipairs(sc.encounter.ids) do
            if e == mid and #sc.encounter.ids > 1 then
                table.remove(sc.encounter.ids, i)
                break
            end
        end
    end
end

-- Fair warning (Straps: a harsh call feels earned when they took the chance knowingly) -----------

-- Something harsh just happened. Did they know? (warnings.lua: warned about this very thing, a die
-- everyone saw, or a table that asked for brutal; a grim table forgives one a night.)
local HARSH_FAIR = {
    warned = "It stings, but nobody argues. They'd been warned.",
    open = "Everyone saw the die. Nobody argues with a die.",
    brutal = "Brutal. But it's the game they asked for at Session Zero, and they know it.",
    tone = "It's grim, and so is the game you all agreed to. Nobody argues.",
}
function M.harsh(night, sc)
    local st = st_of(night)
    local mus = night.mus
    local warnings = require "game.model.warnings"
    mus.harsh_tonight = (mus.harsh_tonight or 0) + 1
    local why = warnings.judge(night, night.moment_key)
    if not why and adventure.free_harsh(night.campaign) - (mus.harsh_free_used or 0) > 0 then
        mus.harsh_free_used = (mus.harsh_free_used or 0) + 1
        why = "tone"
    end
    local dial = warnings.dial(night.campaign)
    if why then
        st.harsh.paid = st.harsh.paid + 1
        night:say(HARSH_FAIR[why], "good")
        night:apply({ { "arch:butt_kicker", fun = 3 }, { "arch:instigator", fun = 3 }, { "all", challenge = 4 } })
        if dial == "gentle" then
            night:apply({ { "all", fun = -1 } })      -- (fair, but they asked for gentle)
        end
        night:emit({ kind = "warning", judged = why, fair = true })
    else
        st.harsh.unpaid = st.harsh.unpaid + 1
        night:say("That came out of nowhere. Nobody saw it coming, and nobody was warned. The table goes quiet.", "bad")
        for _, p in ipairs(night.players) do
            score.add(p, "trust", dial == "gentle" and -5 or -3)
            night:suspect(p, 2, "a harsh call with no warning")
        end
        night:apply({ { "all", fun = -3 } })
        night:emit({ kind = "warning", unearned = true })
        -- The one who minds most keeps it to themselves (what they think, game/model/thoughts.lua).
        local sharp
        for _, p in ipairs(night.players) do
            if not sharp or p.perception > sharp.perception then
                sharp = p
            end
        end
        thoughts.doubt(night, sharp)
    end
    table.insert(mus.harsh_log, { room = sc and sc.room, earned = earned })
    return earned
end

-- What an option's `mus` does tonight (adventure.apply does the bookkeeping).
local FLAG_OPT = { paint = "paint", deaf = "earplugs" }

function M.handle(night, mus, sc)
    if not mus then
        return
    end
    local c = night.campaign
    local st = st_of(night)
    -- (Who it was: the one whose choice it was carries what it hands over, items.lua. A purchase
    -- the table settled is the buyer's: table_pick's backer, the one who wanted it.)
    local added = adventure.apply(c, mus, sc and sc.room, night.actor and night.actor.key)
    -- (Francs this room already paid, and what the gift shop sold tonight: the room's prize and its
    -- last line don't say it twice, or say it when nothing changed hands.)
    if mus.francs and sc and sc.room then
        night.mus.room_francs = night.mus.room_francs or {}
        night.mus.room_francs[sc.room] = true
    end
    if mus.francs and mus.francs > 0 then
        night.mus.francs_earned = (night.mus.francs_earned or 0) + mus.francs      -- (for the report)
        -- (A find, in the log: it follows from what they were doing when it turned up.)
        local who = night.actor
        -- (And at the table: every Franc in the pool was heard going in, to whoever it went to. Round
        -- three: "They doused the hedges, so Oswin found a Franc" when nobody heard one.)
        if not (mus.told or mus.find_text or night.mus.franc_told) then
            local key = mus.francs == 1 and "franc" or "francs"
            -- (The same roll's triumph just gave this hero a Franc: this one is another, said as one more,
            -- not a second "a Franc turns up". The confirming playtest, 51 careful week 1.)
            local rf = night.mus.roll_franc
            if who and rf and rf == who.key then
                key = key .. "_more"
            end
            night.mus.roll_franc = nil
            night:say(util.fill(night:fresh(M.WORLD_LINES[who and key or (key .. "_party")], "world_" .. key .. (who and "" or "_party")),
                night:vars({ char = who and who.char or "they", n = util.int(mus.francs) })), "good")
        end
        night.mus.franc_told = nil
        M.log_beat(night, { kind = "find", who = who and who.key or "party", thing = "francs", n = mus.francs,
                            from = events.cause(c),
                            text = mus.find_text or events.word(mus.francs == 1 and "find" or "finds", { char = who and who.char or "they", n = util.int(mus.francs) }) })
    end
    if mus.spend then
        night.mus.bought = true
    end
    -- (Something bought or found that isn't one of MODULE.items: the report still lists it.)
    if mus.got then
        M.note_got(night, mus.got)
    end
    -- (What the museum's people would know about, for when they see the party again: mus.deeds,
    -- logged by adventure.apply, R7.)
    for _, id in ipairs(added) do
        table.insert(night.mus.pending, id)
    end
    if mus.flag == "notebook" then
        st.flags.notebook = true
    end

    -- (Who drank her wine and is still smiling: they start the fight charmed, MODULE.items.)
    if mus.flag == "charmed" and night.actor then
        st.charmed_hero = night.actor.key
    end
    -- (What they came away with tonight, for the report: anything MODULE.items names.)
    for _, it in ipairs(MODULE.items or {}) do
        local w = it.when or {}
        if it.name and ((mus.flag and w.flag == mus.flag) or (mus.mark and w.mark == mus.mark))
            and not util.contains(night.mus.got or {}, it.name) then
            night.mus.got = night.mus.got or {}
            table.insert(night.mus.got, it.name)
        end
    end
    for _, it in ipairs(MODULE.items or {}) do
        if it.magic and mus.flag and it.when and it.when.flag == mus.flag then
            local items_mod = require "game.model.items"
            local have = false
            for _, e in ipairs(items_mod.list(c)) do
                have = have or e.id == it.magic
            end
            if not have then
                -- (Whoever picked it up offers it to whoever'll use it best: M.hand_off. Who ends up with it is
                -- what the moment's beat and history say: the confirming playtest's "Brannoc kept the twin
                -- daggers" for daggers Pip carried all prologue.)
                local to = M.hand_off(night, it.magic, night.actor)
                if to and night.actor and to ~= night.actor then
                    night.mus.handed = { from = night.actor, to = to, name = it.name }
                end
                local holder = to and { to } or night.players
                local e = items_mod.earn(c, it.magic, holder)
                -- (Tonight's sheets are already built: the item goes on theirs now, for tonight's fights.)
                local pc = e and e.holder and night.pcs and night.pcs[e.holder]
                if pc then
                    items_mod.apply(c, e.holder, pc)
                end
                if e then
                    e.from = mus.spend and "bought" or "found"
                end
            end
        end
    end
    -- What a moment hands the fight in this room (game/rules/museum.lua's battle options): weapons
    -- pulled out of a painting, candle wax in the ears.
    local opt = mus.flag and FLAG_OPT[mus.flag]
    if opt and sc and sc.encounter then
        -- (The painted weapon is the one hero's who pulled it out, as the book has it: a scimitar that
        -- counts as paint. Conner's playtest, C14. Wax in the ears is everyone's.)
        sc.encounter[opt] = (opt == "paint" and night.actor and night.actor.key) or true
        if opt == "paint" and night.actor then
            st.paint_by, st.paint_gift = night.actor.key, night.mus_vars and night.mus_vars.gift_the
        end
    end
    if mus.mark == "mech" then
        st.mech_name = st.mech_name or night.rng:pick(MODULE.mech_names)
        st.mech_commander = night.actor and night.actor.key
    end
    if mus.aspect and night.actor then
        -- (The history is the one who has it now: handed on, theirs.)
        local whose = (night.mus.handed and night.mus.handed.to) or night.actor
        st.aspects = st.aspects or {}
        st.aspects[whose.key] = st.aspects[whose.key] or {}
        table.insert(st.aspects[whose.key], util.fill(mus.aspect, { char = whose.char }))
    end
    -- (A history that's since changed says so: the Mech they woke, burnt out.)
    if mus.flag == "mech_burnt" then
        for _, list in pairs(st.aspects or {}) do
            for i, a in ipairs(list) do
                if string.find(a, "Woke the Steam Mech", 1, true) and not string.find(a, "burnt", 1, true) then
                    list[i] = (string.gsub(a, " and commands it", "")) .. ", until it burnt out"
                end
            end
        end
    end
    -- What it did to the hero it happened to: hurt them (their sheet says so), or a boon.
    local who = night.actor
    -- Dragged somewhere (the pond's tentacles): their mini goes in, then scrambles back out.
    if mus.drag and who and sc then
        M.drag(night, sc, who, mus.drag)
    end
    if mus.hurt and who then
        fight.party(night)
        local pc = night.pcs and night.pcs[who.key]
        if pc and not pc.dead then
            local n = 0
            for _ = 1, mus.hurt[1] do
                n = n + night.rng:int(1, mus.hurt[2])
            end
            local was = pc.hp
            pc.hp = math.max(1, pc.hp - n)
            night:say(who.char .. " takes " .. util.int(was - pc.hp) .. " damage (" .. util.int(pc.hp) .. "/"
                .. util.int(pc.hp_max) .. " HP).", "bad")
        end
    end
    -- (The museum's thanks is an offer: the token is yours to give. The playtest, November 3.)
    if mus.inspire and who and not who.heroic then
        night:offer_inspiration(who, type(mus.inspire) == "string" and util.fill(mus.inspire, { char = who.char }) or nil)
    end
    if mus.ready and sc then
        sc.ready = true      -- (fight.lua: the room's ambushers don't surprise them)
        if not sc.fight_from then
            sc.fight_from, sc.fight_how = events.cause(c), nil      -- (they walked into it knowingly: the fight follows from it)
        end
    end
    if sc then
        if mus.fight then
            sc.fight_on = true
            sc.fight_from, sc.fight_how = events.cause(c), nil      -- (the fight follows from the choice that started it)
        end
        if mus.no_fight then
            sc.no_fight = true
            sc.fight_on = nil
            if sc.room ~= "paintings" then
                sc.resolved = true      -- the room's done without a fight (the ritual)
                sc.outcome = sc.outcome or "win"
                sc.had_roll = true
                sc.resolve_ev = sc.resolve_ev or events.cause(c)      -- (what the room's done follows from: R14)
            end
        end
        if mus.drop then
            drop_from(sc, mus.drop)
            sc.woke = true      -- (a moment that already set the room's pieces moving: no wake line after)
        end
        if mus.resolve then
            sc.resolved = true
            sc.outcome = mus.resolve
            sc.had_roll = true
            sc.resolve_ev = events.cause(c)
        end
        if mus.ending then
            st.ending = mus.ending
            sc.outcome = "win"
            sc.resolved = true
            sc.had_roll = true
            sc.fight_on = nil
            sc.ending_ev = events.cause(c)      -- (the card that settled it: the ending follows from it, R14)
        end
    end
    -- Fair warning is about the thing (warnings.lua): an option that says they know what they're
    -- walking into is a warning (not when the players chose it themselves: then it's what you told
    -- them, or what they found, that counts), and your "are you sure?" in a card is one too.
    local warnings = require "game.model.warnings"
    local wkey = night.moment_key or (sc and sc.room and ("room:" .. sc.room)) or nil
    local wwhat = night.moment_what or (sc and sc.room and MODULE.rooms[sc.room] and ("what's in " .. util.lower_first(MODULE.rooms[sc.room].name)))
    if mus.risk and not night.party_choice then
        warnings.warn(night, wkey, wwhat, "knew")
    end
    if mus.warn then
        warnings.warn(night, wkey, wwhat, "asked")
        night:apply({ { "arch:butt_kicker", challenge = -2 } })
    end
    if mus.harsh then
        M.harsh(night, sc)
    end
end

-- How a room came out, said the way it actually went ------------------------------------------
-- Who ran from a room's fight (sc.foes_ran, from night.lua's combat_scene) and what the DM chose
-- pick the goal's line: a card's `win_if` / `lose_if` list, first match wins, else its own.
local function alt_holds(night, sc, alt)
    local st = st_of(night)
    if alt.when and not adventure.test(night.campaign, alt.when, knobs_of(night)) then
        return false
    end
    -- (fled = n: exactly that many ran.)
    local ran = sc.foes_ran and #sc.foes_ran or 0
    if type(alt.fled) == "number" and alt.fled ~= ran then
        return false
    elseif type(alt.fled) == "boolean" and alt.fled ~= (ran > 0) then
        return false
    end
    -- (Whether the room's fight happened: a Sentinel smashed to scrap doesn't watch them leave.)
    if alt.fought ~= nil and alt.fought ~= (sc.fought == true) then
        return false
    end
    if alt.ending and alt.ending ~= st.ending then
        return false
    end
    if alt.bought ~= nil and alt.bought ~= (night.mus.bought == true) then
        return false
    end
    return true
end

function M.goal_text(night, sc, goal)
    local win = sc.outcome == "win"
    local text = win and goal.win or (goal.lose or goal.win)
    local alt_said = false
    for _, alt in ipairs((win and goal.win_if or goal.lose_if) or {}) do
        if alt_holds(night, sc, alt) then
            text = alt.text
            alt_said = true
            break
        end
    end
    -- (After a death, a goal's quiet win: not "shakes every hand twice". able.somber.)
    if win and not alt_said and goal.win_sad and able.somber(night) then
        text = goal.win_sad
    end
    M.heard(night, text)
    return text
end

-- A name the table has now heard said (F13: "Okay, the Witness." before anyone had): lines that
-- name it later wait on the flag.
function M.heard(night, text)
    local st = st_of(night)
    if text and string.find(text, "Witness", 1, true) then
        st.flags.witness_named = true
    end
    -- (And the sunken city, which only the notebook read out says: with the Witness, witness_city.)
    if text and (string.find(text, "city under the sea", 1, true) or string.find(text, "sunken city", 1, true)) then
        st.flags.sunken_city = true
    end
    if st.flags.witness_named and st.flags.sunken_city then
        st.flags.witness_city = true
    end
    -- (And whatever else the adventure names out loud: MODULE.names_heard, the bird.)
    for flag, words in util.sorted_pairs(MODULE.names_heard or {}) do
        for _, w in ipairs(words) do
            if text and not st.flags[flag] and string.find(text, w, 1, true) then
                st.flags[flag] = true
            end
        end
    end
end

-- Does the party hold a room's prize now? (Its `has`: a flag, a mark, or bought tonight.)
-- What they came away with tonight, for the report ("Picked up: ..."): once each.
function M.note_got(night, what)
    if not what or what == "" then
        return
    end
    night.mus.got = night.mus.got or {}
    for _, g in ipairs(night.mus.got) do
        if string.lower(g) == string.lower(what) then
            return
        end
    end
    table.insert(night.mus.got, what)
end

-- What something they picked up does, and who has it (the report's hover: the playtest,
-- November 3, "hover over items to see what they do, and who has them"). name: as note_got wrote it.
function M.item_info(c, name)
    local items_mod = require "game.model.items"
    local st = adventure.fill(c.adv)
    local low = string.lower(name or "")
    for _, it in ipairs(MODULE.items or {}) do
        if it.name and (string.lower(it.name) == low or string.lower(it.title or "") == low) then
            -- (Who has it is the inventory's to say: items.lua.)
            local _, hk = items_mod.holding(c, it.magic or it.id)
            local holder = hk and c:player(hk) or nil
            local d = it.magic and items_mod.def(it.magic)
            local text = (d and d.text) or it.text or util.fill(it.line or "", { holder = holder and holder.char or "Whoever has it",
                                                                                  mech = st.mech_name or "the Mech" })
            return { title = util.capitalize(it.title or it.name), text = text, holder = holder }
        end
    end
    for _, e in ipairs(items_mod.list(c)) do
        local d = items_mod.def(e.id)
        if d and string.lower(d.name) == low then
            return { title = d.name, text = d.text or "", holder = e.holder and c:player(e.holder) or nil }
        end
    end
    return nil
end

function M.has_reward(night, sc, r)
    local held = M.has_reward_raw(night, sc, r)
    if held and r and not r.francs and not r.owner then
        M.note_got(night, util.lower_first(r.got or r.name))
    end
    return held
end

function M.has_reward_raw(night, sc, r)
    if r.ran and sc.boss_ran then
        return false
    end
    if r.owner == "ending" then
        return night.campaign.adv.ending ~= nil
    end
    if r.owner == "moment" then
        return r.has ~= nil and alt_holds(night, sc, r.has.bought ~= nil and { bought = r.has.bought } or { when = r.has })
    end
    return sc.outcome == "win"
end

-- A room's prize at its end. Only what they earned, said once: a prize a moment already handed
-- over (the mirror, the Mech) isn't announced again; one the room's moments decided against isn't
-- announced at all; a Franc is counted into the pool as it's said; one they didn't win isn't
-- "still out there" unless something says where it is.
function M.reward(night, sc)
    local r = sc.comps and sc.comps.reward
    if not r or night.end_early or (night.muted and night:muted(r)) then
        return
    end
    local st = st_of(night)
    if r.owner then
        return
    end
    if sc.outcome ~= "win" then
        if r.lost and r.lost ~= "" then
            night:say(r.lost, "bad")
        end
        return
    end
    -- (Its keeper got away with it: said, not handed over.)
    if r.ran and sc.boss_ran then
        night:say(r.ran, "bad")
        return
    end
    if r.francs then
        if (night.mus.room_francs or {})[sc.room] then
            return
        end
        st.francs = (st.francs or 0) + r.francs
        night.mus.francs_earned = (night.mus.francs_earned or 0) + r.francs
        night.mus.room_francs = night.mus.room_francs or {}
        night.mus.room_francs[sc.room] = true
        night.actor = night.actor or night:pick_actor({ "power_gamer", "instigator", "casual" })
        -- (The room's pay, in the log: it follows from how they got through it, their fight or the card
        -- that settled the room; a room that was simply walked through pays with no link. R14.)
        M.log_beat(night, { kind = "find", who = "party", thing = "francs", n = r.francs, pay = true,
                            from = sc.fight_ev or sc.resolve_ev,
                            text = events.word(r.francs == 1 and "pay" or "pays", { n = util.int(r.francs) }) }, sc)
        night:say(r.said or ("They earn " .. util.lower_first(r.line)), "reward", { francs = tostring(st.francs) })
        return
    end
    -- (Half, if she got away: R5. The thanks says what it pays, read from the one place.)
    local gold = adventure.reward_gold(night.campaign)
    night:say("They earn " .. util.lower_first(able.pick(night, r.line, r.line_sad)), "reward", { gold = util.int(gold) })
    local why = r.id == "mus_thanks" and adventure.reward_why(night.campaign)
    M.note_got(night, r.id == "mus_thanks" and (util.int(gold) .. " gold each" .. (why and (" (" .. why .. ")") or "") .. " and a pick from the gift shop")
        or util.lower_first(r.got or r.name))
end

-- Moments -----------------------------------------------------------------------------------------

local function option_ok(night, o)
    local c = night.campaign
    local knobs = knobs_of(night)
    -- (What they own isn't on the shelf any more: the gorgon book sold twice, the second playtest
    -- review. Something used up can be bought again.)
    if o.price then
        local t = require("game.model.items").thing_for(o.mus)
        if t and require("game.model.items").owned(c, t.magic or t.id) then
            return false
        end
    end
    if o.when and not adventure.test(c, o.when, knobs) then
        return false
    end
    if o.unless and adventure.test(c, o.unless, knobs) and next(o.unless) then
        return false
    end
    if o.needs then
        local ok = adventure.test(c, o.needs, knobs)
        if not ok and o.alt_needs then
            ok = adventure.test(c, o.alt_needs, knobs)
        end
        if not ok then
            return false
        end
    end
    return true
end

-- Play one moment card: the options that apply here, the DM's pick, its roll, its consequences.
-- Did an option hand the party something (a weapon, a Franc, a mark on her card)?
local function gained(mus)
    return mus ~= nil and (mus.flag or mus.francs or mus.mark or mus.careful or mus.favor) ~= nil
end

function M.play_moment(night, card, sc)
    local st = st_of(night)
    local copy = {}
    for k, v in pairs(card) do
        copy[k] = v
    end
    -- The card's words for how things stand (text_if: the first whose `when` holds): a rematch, a
    -- burned garden, a table that veiled gore. What it says has to fit what's happened.
    -- (A second look at a card they saw before says so, not the same words over again.)
    if sc and sc.revisit and st.seen[card.id] then
        copy.title = (card.title or "") .. ", again"
        copy.text = "Second time round: " .. util.lower_first(card.text or "")
    end
    M.soft_check(night, card.text_if)
    for _, alt in ipairs(card.text_if or {}) do
        if adventure.test(night.campaign, alt.when, knobs_of(night)) then
            copy.text = alt.text
            break
        end
    end
    copy.trigger = copy.trigger or "museum"
    -- What fair warning is judged against (warnings.lua): this moment, its danger.
    night.moment_key, night.moment_what = card.id, card.danger
    night.party_choice = card.party and true or nil
    night.last_roll_fresh = false
    -- Each moment finds its own lead, not whoever took the room's first one (the playtest, Nov 2:
    -- the plaque and then the tablet were always Mara's). A moment for the person who's already
    -- in it (keep_actor) keeps them.
    if copy.trigger == "museum" and not card.keep_actor and card.type ~= "boss" and card.type ~= "talk" then
        night.actor, night.other = nil, nil
    end
    -- A moment that's one friend's own (who): theirs, whoever's had the spotlight.
    if card.who and present(night, card.who) then
        night.actor = present(night, card.who)
        copy.trigger = "museum_fixed"
    end
    copy.options = {}
    -- Telpur's prices on the day (R11): the shelf's own (MODULE.PRICE), moved by what he thinks of
    -- the party now. He says so, and the log has why (a theft he saw, or a friend's discount).
    local markup = 0
    if card.shop then
        M.owner_sees(night, "mus_telpur", sc)          -- (before his prices: what he sees changes them)
        local _, d = people.price(night.campaign, 1, "mus_telpur")
        local lv = people.level(night.campaign, "mus_telpur")
        markup = d
        if d ~= 0 then
            local line = people.line(night, "mus_telpur", d > 0 and "price_up" or "price_down")
            if line then
                night:emit({ kind = "npc", name = "Telpur", cast = "mus_telpur", text = line })
            end
            local why = people.knows_of(night.campaign, "mus_telpur", "steal", nil, true)
                or events.last(night.campaign, { kind = "help", whom = "mus_telpur" })
            local ev = M.log_beat(night, { kind = "price", who = "mus_telpur", n = d, from = why, level = lv,
                                           text = events.word(d > 1 and "price_up_n" or (d > 0 and "price_up") or "price_down", { n = util.int(d) }) }, sc)
            ev.how = why and "therefore" or nil
        end
    end
    for _, o in ipairs(card.options) do
        if option_ok(night, o) then
            local oc = o
            if o.price and markup ~= 0 and o.mus and o.mus.spend then
                local price = people.price(night.campaign, o.price, "mus_telpur")
                oc = {}
                for k, v in pairs(o) do
                    oc[k] = v
                end
                oc.mus = {}
                for k, v in pairs(o.mus) do
                    oc.mus[k] = v
                end
                oc.price, oc.mus.spend = price, price
                oc.of = o                   -- (the option as written: what the DM chose, st.chose)
                oc.label = (string.gsub(o.label, "%(%d+ Francs%)", "(" .. util.int(price) .. " Francs)"))
            end
            if oc.price and (st.francs or 0) < oc.price then
                local was = oc
                oc = {}
                for k, v in pairs(was) do
                    oc[k] = v
                end
                oc.disabled = true
                oc.of = was.of or o
                oc.label = was.label .. " (not enough Francs)"
            end
            table.insert(copy.options, oc)
        end
    end
    if #copy.options == 0 then
        return nil
    end
    -- Whoever the room's painting is for takes the hall's big moment.
    local pick = knobs_of(night).portrait
    if card.id == "mus_reach" and type(pick) == "string" and present(night, pick) then
        night.actor = present(night, pick)
        copy.actor_class = nil
        copy.trigger = "museum_fixed"
        copy.fixed_actor = true      -- (the painting is theirs: the big-roll share doesn't hand it on. F18)
    end
    night.mus_vars = mus_vars(night, sc)
    -- Reaching into a painting risks what that painting risks (the book: cold, a blade, or nothing at
    -- all): its own danger, its own miss, and no roll for one that's safe.
    if card.id == "mus_reach" then
        M.reach_for(night, copy, night.mus_vars.portrait or {})
    end
    -- A roll whose prize isn't there for this hero (an empty painting): its empty outcome instead.
    if night.mus_vars.gift_empty then
        local opts = {}
        for i, o in ipairs(copy.options or {}) do
            if o.roll and o.roll.success and o.roll.success.empty then
                local oo = {}
                for k, v in pairs(o) do
                    oo[k] = v
                end
                local rr = {}
                for k, v in pairs(o.roll) do
                    rr[k] = v
                end
                rr.success = o.roll.success.empty
                oo.roll = rr
                opts[i] = oo
            else
                opts[i] = o
            end
        end
        copy.options = opts
    end
    -- (How everyone felt going in: who it drew toward the room's people, for the DM's recap.)
    local fun_before = {}
    for _, p in ipairs(night.players) do
        fun_before[p.key] = score.fun(p)
    end
    -- A moment about something one hero has (card.owner: the card whose moment handed it over, as
    -- the log has it): theirs, whoever's had the spotlight, and whoever the table backs (round three:
    -- "Oswin could slide each one back" when Pip pulled the one painted scimitar out).
    local owned
    if card.owner then
        local ev = events.last(night.campaign, { kind = "moment", card = card.owner, session = night.campaign.week })
        owned = ev and present(night, ev.who)
        if owned then
            night.actor = owned
            night.mus_vars = mus_vars(night, sc)
            night.mus_vars.gift_the = ev.gift or night.mus_vars.gift_the      -- (what they pulled out, as the log has it)
        end
    end
    -- The players' own choice (card.party): they talk it over, and play what they settle on.
    if card.party then
        if not night.actor then
            -- (A moment you promised someone: theirs, before the talk, so the card that names them is.)
            night.actor = night:take_owed("cards") or night:pick_lead(card.actor)
        end
        if card.spot then
            night:walk(night.actor, card.spot, nil, sc)
            copy.walked = true
        end
        local vars = night:vars(night.mus_vars)
        night:say(util.sentence_case(util.fill(copy.text or "", vars)), "narration")
        night.party_backers = nil
        copy.proposes = card.proposes and card.options[card.proposes] or nil
        copy.party_pick = M.table_pick(night, copy, night.mus_vars)
        -- Whoever acts on what the table settled is someone who wanted it (F18: a hero acted against
        -- their own player's vote). The card keeps the words it was read out with.
        -- (And whose hero is here: not one who wandered off, F11.)
        local backers = {}
        local here = {}
        for _, p in ipairs(night:at_hand()) do
            here[p] = true
        end
        for _, p in ipairs(night.party_backers or {}) do
            if here[p] then
                table.insert(backers, p)
            end
        end
        local backs = false
        for _, p in ipairs(backers) do
            backs = backs or p == night.actor
        end
        -- (A card about what one hero holds still names them; if they were against what the table
        -- settled, someone who wanted it does it: F18.)
        if #backers > 0 and night.actor and not backs then
            copy.text = util.fill(copy.text or "", vars)
            night.actor = backers[1]
        end
        copy.fixed_actor = true
        copy.trigger = "museum_fixed"
        -- A lock is picked by whoever's best with one (the playtest, November 3: "lock picking needs a
        -- roll from the lockpicker").
        local chosen = copy.options[copy.party_pick]
        -- (An option whose roll comes on a follow-up card, the donation box's lock, names its skill
        -- itself: `best`. Whoever kneels by the case is the one best with picks of those who wanted it,
        -- and the follow-up keeps them: round three, "Pip cracks her knuckles" then Brannoc had the picks.)
        local best_skill = chosen and ((chosen.roll and chosen.roll.best and chosen.roll.skill) or (type(chosen.best) == "table" and chosen.best))
        if best_skill then
            local best, bm
            local pool = chosen.roll and night:at_hand() or (#backers > 0 and backers) or night:at_hand()
            for _, p in ipairs(pool) do
                local _, m = night:best_skill(p, best_skill)
                if m and (not bm or m > bm) then
                    best, bm = p, m
                end
            end
            if copy.walked and best and best ~= night.actor then
                night:walk(best, card.spot, nil, sc)      -- (the one doing it goes over too)
            end
            night.actor = best or night.actor
            copy.fixed_actor = true
        end
        -- (An option that's done with something someone carries, a page of the Lecturer's notes: theirs
        -- to do, whoever backed it. Round three: Thessaly had the pages, and Pip read one to Euryale.)
        if chosen and chosen.by_holder then
            local _, key = require("game.model.items").holding(night.campaign, chosen.by_holder, true)
            local h = key and present(night, key)
            if h and h ~= night.actor then
                copy.text = util.fill(copy.text or "", night:vars(night.mus_vars))
                night.actor = h
            end
        end
        -- They picked something that can go badly: does anyone tell them? (warnings.lua)
        if chosen and card.danger then
            M.warn_step(night, card, copy)
        end
    end
    -- A puzzle roll goes to whoever's best at it (the playtest review, November 4: Brannoc, Int -1,
    -- cracked the machine's code with Thessaly standing right there).
    if not card.party and card.type == "puzzle" and not copy.fixed_actor then
        local sk
        for _, oo in ipairs(copy.options or {}) do
            sk = sk or (oo.roll and oo.roll.skill)
        end
        if sk then
            local best, bm
            for _, p in ipairs(night:at_hand()) do        -- (of the heroes in this scene: F11)
                local _, m = night:best_skill(p, sk)
                if m and (not bm or m > bm) then
                    best, bm = p, m
                end
            end
            if best then
                night.actor = best
                copy.fixed_actor = true
                copy.actor_class = nil
                copy.trigger = "museum_fixed"
            end
        end
    end
    -- (What the hero stops in front of is said to the table: they all see the painting, so the chat
    -- and the friends can talk about it after. The gate after the final pass's merge, 35 random.)
    if card.id == "mus_reach" and night.mus_vars and night.mus_vars.painting then
        night:say("One painting holds everyone's eye: " .. night.mus_vars.painting .. ".", "narration")
    end
    local o = night:decision(copy, night.mus_vars)
    if not o then
        return nil
    end
    -- (Whose painting the hall showed: the chat and the notes can say so.)
    -- (The painting they were shown: whose it is, the DM's pick or the hero's own, not who leaned in.
    -- Round three: "the lady by the mountains" when the hall showed the elf in the snow.)
    -- (Read off the fill-ins the card was told with: the hall can show the elf in the snow, nobody's,
    -- when the card's hero was picked after its words were. Round three, seed 38.)
    if card.id == "mus_reach" then
        local whose = night.mus_vars and night.mus_vars.portrait_whose
        if whose then
            st.flags["portrait_" .. whose] = true
        end
    end
    -- What the DM chose, by the option's place on the card as written: lines later on (a goal's
    -- ending, the group chat, what an NPC remembers) say only what follows from it.
    local chosen_i
    for i, opt in ipairs(card.options) do
        if opt == o or opt == o.of or opt.label == o.label or (o.label and opt.label and string.sub(o.label, 1, #opt.label) == opt.label) then
            st.chose[card.id] = i
            chosen_i = i
            break
        end
    end
    -- The moment in the log (R7, R14): what was chosen, by whom, and what it follows from (what made
    -- it possible: a flag, a mark, an earlier card; the moment it follows on from), before what it
    -- does, so everything it causes follows from it.
    local c = night.campaign
    local rolled_ok = o.roll and night.last_roll and true or false
    local out_pre = o.roll and (rolled_ok and o.roll.success or o.roll.fail) or nil
    local prev_cause = events.cause(c)
    local gate = (card.follows_ev and events.get(c, card.follows_ev))
        or gate_cause(night, { card.when, o.needs, o.when, card.needs })
    local mev = M.log_beat(night, { kind = "moment", card = card.id, opt = chosen_i, look = card.look and true or nil, who = night.actor and night.actor.key or "party",
                                    party = card.party or nil, flag = o.mus and o.mus.flag or nil,
                                    flag2 = rolled_ok and out_pre and out_pre.mus and out_pre.mus.flag or nil,
                                    rolled = o.roll and (rolled_ok and "ok" or "fail") or nil,
                                    text = M.beat_clause(night, card, o, chosen_i or 0, rolled_ok), from = gate })
    -- (What came out of a painting, by name: the one thing its puller holds.)
    if card.id == "mus_reach" and night.mus_vars and not night.mus_vars.gift_empty then
        mev.gift = night.mus_vars.gift_the
    end
    -- (Whose plan it was: the friends who wanted what the table settled, for a line that gives one
    -- of them the credit. Round three: "Brannoc's plan" for a ritual Dev argued against.)
    if card.party and night.party_backers then
        mev.backers = {}
        for _, p in ipairs(night.party_backers) do
            table.insert(mev.backers, p.key)
        end
    end
    events.set_cause(c, mev)
    if sc and mev.beat and not card.look then
        sc.last_moment = mev.id
    end
    mev.handing = true                  -- (what it hands over is told by the moment itself: items.lua)
    -- (A Franc the option's own words already handed over isn't said twice; one they didn't is said.)
    night.mus.franc_told = type(o.log) == "string" and string.find(o.log, "Franc", 1, true) and true or nil
    night.mus.handed = nil
    M.handle(night, o.mus, sc)
    -- (Handed on to whoever'll use it best: the beat says who carries it.)
    local ho = night.mus.handed
    if ho and mev.text then
        local them = string.find(ho.name or "", "s$") and "them" or "it"
        mev.text = mev.text .. ", and gave " .. them .. " to " .. ho.to.char
        mev.holder = ho.to.key
    end
    night.mus.handed = nil
    local got = gained(o.mus)
    local out
    if o.roll then
        out = night.last_roll and o.roll.success or o.roll.fail
        -- (A roll that went wrong turns the moment: a beat of its own, "but".)
        if not night.last_roll then
            local b = MODULE.beats and MODULE.beats[card.id]
            local fb = b and type(b[chosen_i or 0]) == "table" and b[chosen_i].fail
            local who = night.actor and night.actor.char or "they"
            -- (What the miss sets, the ritual failed, follows from the miss: a card it opens follows from it.)
            local sev = M.log_beat(night, { kind = "setback", card = card.id, who = night.actor and night.actor.key or "party",
                                            from = mev, how = "but", flag2 = out_pre and out_pre.mus and out_pre.mus.flag or nil,
                                            text = (fb and util.fill(fb, { char = who, actor_char = who }))
                                                or (card.trap and events.word("trap", { what = card.trap }))
                                                or (mev.text and events.word("didnt")) or nil })
            events.set_cause(c, sev)
        end
        night.mus.franc_told = out and type(out.log) == "string" and string.find(out.log, "Franc", 1, true) and true or nil
        M.handle(night, out and out.mus, sc)
        night.mus.franc_told = nil
        got = out ~= nil and gained(out.mus) and night.last_roll and true or false
    end
    mev.handing = nil
    local with = {}
    local room = sc and MODULE.rooms[sc.room]
    if room and room.comps and room.comps.cast then
        table.insert(with, room.comps.cast)
    end
    for _, m in ipairs({ o.mus, out and out.mus }) do
        if type(m) == "table" and m.favor and m.favor.who then
            table.insert(with, "mus_" .. m.favor.who)
        end
    end
    standing.note(night, with, fun_before)
    st.seen[card.id] = true
    if got then
        st.took[card.id] = true
    end
    -- What the players chose can still need the DM: a hand on the donation box's lock, say. The
    -- follow-up is a moment of its own (at = "follow"), for the same hero.
    if o.then_moment then
        for _, m in ipairs(MODULE.moments) do
            if m.id == o.then_moment then
                local fm = {}
                for k, v in pairs(m) do
                    fm[k] = v
                end
                fm.keep_actor = true
                -- (The same hero, whatever the spotlight share or a promise would hand on: the card
                -- that said they knelt by the case is the one whose roll it is.)
                fm.fixed_actor = true
                fm.trigger = "museum_fixed"
                fm.follows_ev = mev.id          -- (it follows on from this one: "therefore")
                M.play_moment(night, fm, sc)
            end
        end
    end
    events.set_cause(c, prev_cause)
    M.ties_beat(night, sc)
    return o
end

-- The hall's reach-in card, for the painting it's about (MODULE.portraits): copy is the card as it'll
-- be played. A safe painting: the reach needs no roll, and its outcome is the success. One with a
-- danger: the card's danger is that painting's, and the miss is its own bite.
function M.reach_for(night, copy, port)
    copy.danger = port.danger
    night.moment_what = port.danger
    local opts = {}
    for i, o in ipairs(copy.options or {}) do
        local oo = o
        if o.roll and o.roll.success then
            oo = {}
            for k, v in pairs(o) do
                oo[k] = v
            end
            if port.safe then
                local win = (port.empty and o.roll.success.empty) or o.roll.success
                oo.roll = nil
                oo.log = win.log
                oo.effects = win.effects
                oo.mus = {}
                for k, v in pairs(win.mus or {}) do
                    -- (Not a weapon, the glass from the throne: nothing painted to fight with. C14.)
                    if k ~= "risk" and not (port.not_weapon and k == "flag" and v == "paint") then
                        oo.mus[k] = v
                    end
                end
                if port.not_weapon and oo.mus.aspect then
                    oo.mus.aspect = "Pulled something to drink out of a painting"
                end
                oo.label = "Let them reach in."
            else
                local rr = {}
                for k, v in pairs(o.roll) do
                    rr[k] = v
                end
                rr.skill = port.skill or rr.skill
                local fail = {}
                for k, v in pairs(rr.fail or {}) do
                    fail[k] = v
                end
                fail.log = port.bite or fail.log
                fail.mus = {}
                for k, v in pairs((rr.fail or {}).mus or {}) do
                    fail.mus[k] = v
                end
                fail.mus.hurt = port.hurt or fail.mus.hurt
                fail.mus.aspect = port.aspect or fail.mus.aspect
                rr.fail = fail
                oo.roll = rr
            end
        end
        if port.safe and not o.roll and o.mus and o.mus.warn then
            -- (No danger to warn about: keeping hands in pockets is just that.)
            oo = {}
            for k, v in pairs(o) do
                oo[k] = v
            end
            oo.mus = nil
        end
        opts[i] = oo
    end
    copy.options = opts
end

-- Could this option end badly? (A harsh outcome, on it or on its roll's miss.)
local function risky(o)
    return o and ((o.mus and o.mus.harsh) or (o.roll and o.roll.fail and o.roll.fail.mus and o.roll.fail.mus.harsh)) and true or false
end
M.risky = risky

-- The players have picked something risky (a party moment): your call, behind the screen, on what
-- they know before they do it. Describe the danger (a warning in the story), ask "Are you sure?"
-- (out of character: the careful ones may back down, the bold ones dig in), or say nothing.
local CAREFUL = { tactician = true, casual = true, storyteller = true }
function M.warn_step(night, card, copy)
    local warnings = require "game.model.warnings"
    local chosen = copy.options[copy.party_pick]
    if not risky(chosen) or warnings.warned(night.campaign, card.id) or not night:room(12) then
        return
    end
    local vars = night:vars(night.mus_vars)
    local wcard = { id = "warn_" .. card.id, type = "screen", trigger = "museum_fixed", fixed_actor = true,
                    title = "Before they do it",
                    text = "{actor_char} is about to " .. (chosen.want or "go ahead") .. ". If it goes wrong, it goes badly ("
                        .. card.danger .. "). Do they know that?",
                    options = {
                        { label = "Describe the danger first.", sub = "A warning in the story. They go ahead knowing.", warn = "told",
                          log = "You lean in and tell them: " .. (string.match(card.danger, "^[^:]+: (.+)$") or card.danger) .. ".",
                          effects = { { "arch:explorer", fun = 1 }, { "arch:storyteller", fun = 1 } } },
                        { label = "Ask them: \"Are you sure?\"", sub = "Out of character. The careful ones might think again.", warn = "asked",
                          log = "\"Are you sure?\" you ask, and let it hang there." },
                        { label = "Say nothing. Let it play.", sub = "Suspense. If it goes badly, it came out of nowhere.",
                          effects = { { "arch:instigator", fun = 1 }, { "arch:butt_kicker", fun = 1 } } },
                    } }
    local o = night:decision(wcard, night.mus_vars)
    if not (o and o.warn) then
        return
    end
    warnings.warn(night, card.id, card.danger, o.warn)
    local lead = night.actor
    if o.warn == "asked" and lead then
        -- The one doing it answers, as who they are: a careful player backs down to something safer.
        local safe
        for i, opt in ipairs(copy.options) do
            if not risky(opt) and not opt.disabled and i ~= copy.party_pick then
                safe = safe or i
            end
        end
        if CAREFUL[lead.primary] and safe then
            -- (Their decision, in their words: the DM doesn't narrate what a hero thinks. Conner's
            -- playtest, C5: "Pip thinks better of it." after the friend had said so.)
            local sw = copy.options[safe].short or copy.options[safe].want
            night:emit({ kind = "say", who = lead.key, ic = false,
                         text = sw and ("...Actually, no. Let's " .. sw .. " instead.") or "...Actually, no. Let's not." })
            copy.party_pick = safe
        else
            night:emit({ kind = "say", who = lead.key, text = "Yes. Very sure.", ic = false })
            night:apply({ { "actor", fun = 2 } })
        end
    end
end

-- The DM's ties and locks (game/model/ties.lua) at a beat of the night: a moment just played, a
-- room just done, the start of the evening. A lock whose condition has come true opens, with a
-- line; a tie whose condition holds fires once (a mark goes on her card the usual way, and her
-- thought comes with the room's others at its end).
function M.ties_beat(night, sc)
    local c = night.campaign
    if not ties.any(c) or (sc and sc.boss) then
        return
    end
    for _, line in ipairs(ties.news(c)) do
        night:say(line, "narration")
    end
    for _, l in ipairs(ties.open_locks(c)) do
        night:say(ties.open_line(l), "narration")
    end
    for _, t in ipairs(ties.fire(c, function(mark)
        -- (The DM's tie put it there, not anything the night is playing: no link, R14.)
        local was = events.cause(c)
        events.set_cause(c, nil)
        M.handle(night, { mark = mark }, sc)
        events.set_cause(c, was)
        -- (Her card says it was the DM's tie, not something the party did.)
        local rec = c.adv.marks[mark]
        if type(rec) == "table" then
            rec.tied = true
        end
    end)) do
        local line = ties.fired_line(c, t)
        if line then
            night:say(line, "aside")
        end
    end
end

-- The ways a lock is holding shut from where the party stands, said once a night per room.
local function say_shut(night, from)
    local line = ties.shut_line(night.campaign, from)
    night.mus.shut_said = night.mus.shut_said or {}
    if line and not night.mus.shut_said[from] then
        night.mus.shut_said[from] = true
        night:say(line, "dm")
    end
end

function M.moments(night, sc, at)
    if night.end_early then
        return
    end
    -- (A lost fight: they're getting out, not fishing in the pond or prising off a cupboard door with the
    -- huntlings still out there. Round three, A6.)
    if at == "end" and ((sc.fought and sc.outcome ~= "win") or sc.outcome == "lose") then
        return
    end
    local knobs = knobs_of(night)
    for _, m in ipairs(MODULE.moments) do
        -- (fight_only: a moment about the fight, when the talk has just ended it without one.)
        if m.room == sc.room and (m.at or "start") == at and adventure.test(night.campaign, m.when, knobs)
            and not (m.fight_only and not M.has_fight(sc))
            and not (m.unless and adventure.test(night.campaign, m.unless, knobs)) and adventure.moment_open(night.campaign, m) then
            M.play_moment(night, m, sc)
            if night.end_early then
                return
            end
        end
    end
end

-- Looking around (the playtest, November 3: "players should explore a map one at a time,
-- commenting on and interacting with things"). Before a room's business, the friends take turns:
-- one walks over to something on the map, the DM describes it, and they say what they make of
-- it. Who goes is who'd want to (the curious first, nobody twice running). A find or a trap there
-- is the DM's call first, behind the screen (MODULE.explore): a trap can go off, give them a
-- chance to spot it, or never go off at all; a find can be handed over, made more of, moved
-- somewhere they'll look later, or not be there tonight.
-- What each kind of friend says walking over to a place on the board. A place says what it is (its
-- map spec's form: one or many, and a kind: a loose thing, a fixture too big or fixed to move, a
-- picture, a figure shaped like someone, a person, or an area), and a line names the kinds it fits
-- (`only`, every kind without it), so nobody asks "Is the shears in the grass a clue?" or offers to
-- take the front doors home (the second playtest review). {it}, {is}, {does} follow the place: "it",
-- "is", "does" for one, "them", "are", "do" for many. calm: only in a room with no fight in it.
local OBJ = { "thing", "fixture", "picture", "figure" }       -- (something you can poke, not a person or an area)
local LOOK_SAY = {
    explorer = { "Hang on. I want a proper look at {place}.",
                 { "Nobody touch {place}. I'm looking first.", only = OBJ },
                 "Okay, what's the deal with {place}?",
                 { "Where did {place} come from? I need to know.", only = { "thing", "picture", "figure" } } },
    tactician = { "{place}. Could be useful later. Noting it.",
                  { "Could we hide behind {place} in a pinch?", only = { "fixture", "figure" } },
                  "Anything about {place} that's going to hurt us?" },
    butt_kicker = { { "{does} {place} fight back? No? Moving on.", only = OBJ },
                    { "Can I hit {place}? I want to hit {it}.", only = { "thing", "fixture", "figure" } },
                    { "Cool. Where are the monsters?", calm = true },
                    "{place}? Fine. Anything in here I'm allowed to hit?" },
    storyteller = { { "Who left {place} here? There's a story in that.", only = { "thing" } },
                    { "I love that this museum has {place}.", only = OBJ },
                    { "Wait. Could {place} be a clue?", only = OBJ },
                    "There's a story behind {place}. I can feel it." },
    instigator = { { "I poke {place} with a stick.", only = { "thing", "fixture", "picture", "figure", "area" } },
                   { "I lick {it}. I'm licking {place}.", only = { "thing", "fixture", "figure" } },
                   { "What happens if I knock {place} over?", only = { "thing", "figure" } },
                   "What happens if I shout at {place}? Just a little shout." },
    method_actor = { "\"Stay close,\" I tell the others, and step up to {place}.",
                     { "\"I've seen one of these before. Never like this.\"", one = true, only = OBJ },
                     "\"Careful. Nothing in this place is what it looks like.\"" },
    power_gamer = { { "{is} {place} worth anything? Can we sell {it}?", only = { "thing", "picture", "figure" } },
                    { "{does} {place} actually do anything?", only = { "thing", "fixture", "figure" } },
                    "I check {place} for anything magic." },
    casual = { "Ha. {place}. Neat.", "Ooh. Look at {place}.",
               { "Can we take {place} home? No? Fine.", only = { "thing", "picture" } } },
}
M.LOOK_SAY = LOOK_SAY
local LOOK_IC = { method_actor = true }

-- The lines a friend of this kind can say about this place, filled in (pl: a board place with its
-- form; how.calm: the room has no fight in it).
function M.look_lines(arch, pl, how)
    local out = {}
    local many = pl and pl.many
    local kind = (pl and pl.kind) or "thing"
    local vars = { place = util.lower_first((pl and pl.name) or "it"), it = many and "them" or "it",
                   is = many and "are" or "is", does = many and "do" or "does" }
    for _, l in ipairs(LOOK_SAY[arch] or {}) do
        local text, ok = l, true
        if type(l) == "table" then
            text = l[1]
            ok = (not l.only or util.contains(l.only, kind)) and not (l.one and many) and not (l.calm and not (how and how.calm))
        end
        if ok then
            table.insert(out, util.sentence_case(util.fill(text, vars)))
        end
    end
    return out
end

local function look_card(night, sc, pl, ex)
    local what = util.lower_first(pl.name or "it")
    if ex.trap then
        local t = ex.trap
        local hurt = { log = t.hit, effects = { { "actor", spotlight = 4, challenge = 4 }, { "arch:butt_kicker", fun = 1 } },
                       mus = { hurt = t.hurt or { 1, 4 }, harsh = true } }
        return { id = "mus_look_trap_" .. sc.room .. "_" .. pl.id, type = "screen", trigger = "museum_fixed", fixed_actor = true,
                 keep_actor = true, actor = { "explorer" }, look = what, trap = t.what,
                 title = "A trap: " .. what,
                 text = "{actor_char} is heading for " .. what .. ". Your notes put a trap there: " .. t.what .. ". They haven't seen it.",
                 options = {
                     { label = "Let it go off. They roll to get clear.", sub = "In front of the screen: everyone sees the roll.",
                       roll = { dc = t.dc or 12, skill = t.skill or { "acrobatics" }, convenient = "success",
                                success = { log = t.dodge, effects = { { "actor", spotlight = 6, fun = 3 }, { "all", challenge = 2 } } },
                                fail = hurt } },
                     { label = "Give them a chance to spot it first.", sub = "A Perception roll. Miss it, and it goes off.",
                       roll = { dc = t.spot_dc or 13, skill = { "perception", "investigation" }, convenient = "success",
                                success = { log = t.spotted, effects = { { "actor", spotlight = 6, fun = 4 }, { "arch:tactician", fun = 3 },
                                                                         { "arch:explorer", fun = 2 } } },
                                fail = hurt } },
                     { label = "It doesn't go off tonight.", sub = "Behind the screen: they never know it was there.",
                       log = "{actor_char} walks right past it. Behind your screen, you cross it out.",
                       effects = { { "all", challenge = -1 }, { "arch:casual", fun = 1 } } },
                 } }
    end
    local f = ex.find
    local n = f.francs or 1
    local st = st_of(night)
    return { id = "mus_look_find_" .. sc.room .. "_" .. pl.id, type = "screen", trigger = "museum_fixed", fixed_actor = true,
             keep_actor = true, actor = { "explorer" }, look = what,
             title = "Something to find: " .. what,
             text = "{actor_char} is poking around " .. what .. ". Your notes put " .. f.what .. " here.",
             options = {
                 { label = "They find it.", log = f.line,
                   effects = { { "actor", spotlight = 6, fun = 4 }, { "arch:power_gamer", fun = 2 } }, mus = { francs = n } },
                 { label = "Make it more: " .. util.int(n + 1) .. " Francs.", sub = "Generous. A little less to earn later.",
                   log = f.line .. " And another one, just past it.",
                   effects = { { "actor", spotlight = 6, fun = 5 }, { "arch:power_gamer", fun = 3 }, { "all", challenge = -1 } },
                   mus = { francs = n + 1 } },
                 { label = "Move it somewhere they'll look later.", sub = "It turns up the next time someone looks around.",
                   log = "{actor_char} finds dust and cobwebs. Behind your screen, you move a note to another room.",
                   effects = { { "arch:explorer", fun = -1 } }, later = n },
                 { label = "There's nothing here tonight.", log = "{actor_char} finds dust and cobwebs. Nothing else.",
                   effects = { { "arch:explorer", fun = -2 }, { "arch:power_gamer", fun = -1 } } },
             } }
end

-- A hero's mini yanked into a feature on the map (mus.drag = { feature, place }) and back out to
-- the place they were standing: the playtest, November 3 ("Pip being grabbed by the tentacle
-- should move him").
function M.drag(night, sc, who, d)
    local board = require "game.model.board"
    local feat_id, place_id = d[1], d[2]
    local _, by_id = night:board_places(sc)
    local pl = by_id[place_id]
    local ok, c = pcall(board.compile, night:board_for(sc))
    local f = ok and c and c.by_id[feat_id]
    if not (pl and f) then
        return
    end
    local best, bd
    for _, pi in ipairs(f.pieces) do
        local pc = c.pieces[pi]
        for _, sq in ipairs(board.squares(pc.kind, pc.x, pc.y, pc.r)) do
            local dd = math.max(math.abs(sq[1] - pl.x), math.abs(sq[2] - pl.y))
            if not bd or dd < bd then
                best, bd = sq, dd
            end
        end
    end
    if best then
        night:walk(who, { best[1], best[2] }, { { pl.x, pl.y } }, sc)
    end
end

-- A room with a fight in it, looked around once it's safe (and a room whose fight never came).
function M.explore_after(night, sc)
    M.drops_beaten(night, sc)
    if not sc.explored and not night.end_early and (not sc.fought or sc.outcome == "win") then
        sc.explored = true
        M.explore(night, sc)
    end
end

-- The small stuff, once the room's danger is settled (table_life.lua): poking at things, a question,
-- a snack. After the room's last moments, so nobody browses while something's still coming.
function M.quiet_stretch(night, sc)
    -- (Nor after backing out of a room: "They back out of the hall", then a compliment for the dwarf
    -- king's beard. Round three, A6.)
    if night.end_early or (sc.fought and sc.outcome ~= "win") or sc.outcome == "lose" then
        return
    end
    require("game.model.table_life").room(night, sc, sc.fought and "after" or "enter")
end

-- Who takes a magic item the party just got is the players' call (the playtest, November 3:
-- "players give items to whoever can best use them"). Whoever has it in their hands offers it to
-- the friend whose hero gets the most out of it; a power gamer who can use it themselves keeps it,
-- and the one who'd have used it best notices. Returns the hero who ends up with it (or nil).
function M.hand_off(night, id, finder)
    local items_mod = require "game.model.items"
    local c = night.campaign
    local d = items_mod.def(id)
    if not d then
        return nil
    end
    -- (Only to a hero in this scene: one who's wandered off isn't there to take it. Wave 1's leftover, F11.)
    local here = night:at_hand()
    -- (A friend promised first pick: theirs, if they can use it.)
    local promised = M.first_pick(night, function(p)
        return items_mod.can_use(c, p, id)
    end)
    if promised then
        return promised
    end
    local best = items_mod.pick_holder(c, id, #here > 0 and here or night.players)
    finder = finder or night.actor
    if not best or not finder or best == finder then
        return best or finder
    end
    local name = util.lower_first(d.name)
    local can = items_mod.can_use(c, finder, id)
    if can and finder.primary == "power_gamer" then
        night:emit({ kind = "say", who = finder.key, text = "Mine. I found it.", ic = false })
        night:react({ [best.key] = "arms" })
        night:say(best.name .. " says nothing. " .. best.char .. " would have got more out of " .. name .. ".", "aside")
        score.add(best, "fun", -2)
        rapport.bond(c, best.key, finder.key, -2)
        return finder
    end
    local line = can and ("Here. " .. best.char .. " will get more out of this than me.")
        or ("This is no good to me. " .. best.char .. ", it's yours.")
    night:emit({ kind = "say", who = finder.key, text = line, ic = false })
    night.handed_off = night.scene and night.scene.index or true     -- (the table's loot-sharing bond won't say it again here)
    night:react({ [best.key] = "cheer" })
    score.add(best, "fun", 4)
    score.add(finder, "fun", 1)
    rapport.bond(c, best.key, finder.key, 3)
    return best
end

-- The party gets a magic item off someone (npcs.lua drops), handed to whoever'll use it best.
local function earn_drop(night, sc, n, w)
    local items_mod = require "game.model.items"
    local c = night.campaign
    local who = M.hand_off(night, w.drop.item, night.actor)
    local e = items_mod.earn(c, w.drop.item, who and { who } or night.players)
    local pc = e and e.holder and night.pcs and night.pcs[e.holder]
    if pc then
        items_mod.apply(c, e.holder, pc)
    end
    w.drop.got = c.week
    w.drop.entry = e            -- (who has it now is the inventory's to say: items.lua)
    local d = items_mod.def(w.drop.item)
    M.note_got(night, d and util.lower_first(d.name) or nil)
    local holder = e and e.holder and present(night, e.holder)
    night:say((d and d.name or "Something") .. (holder and (": " .. holder.char .. " carries it now.") or "."), "good")
end

-- What the DM put on someone (npcs.lua), and the party's ways of getting it. Beaten: it falls out
-- after the fight they were in. A pocket or an ask is a player's idea (the light-fingered, the
-- talkers: their stats say who'd think of it), and the DM rules on whether it works.
local POCKET_KEEN = { instigator = 0.8, power_gamer = 0.7, butt_kicker = 0.3, explorer = 0.4 }
local ASK_KEEN = { storyteller = 0.7, method_actor = 0.7, casual = 0.6, power_gamer = 0.6, tactician = 0.4 }

local function keenest(night, keen, skill)
    local best, bw
    for _, p in ipairs(night:at_hand()) do       -- (a hero in this scene: F11)
        local w = (keen[p.primary] or 0.15) + ((p.class == "rogue" and skill == "sleight_of_hand") and 0.4 or 0)
        local _, m = night:best_skill(p, { skill })
        w = w + (m or 0) * 0.04
        if not bw or w > bw then
            best, bw = p, w
        end
    end
    return best, bw or 0
end

function M.drops_social(night, sc)
    if sc.boss or night.end_early then
        return
    end
    local npcs = require "game.model.npcs"
    local items_mod = require "game.model.items"
    local c = night.campaign
    -- (A pocket the DM filled is one of the friends' own ideas now: game/model/ideas.lua lifts it, the
    -- one way anyone picks a pocket in the museum, R13. An ask is still asked here.)
    for _, how in ipairs({ "ask" }) do
        for _, w in ipairs(npcs.waiting(c, sc.room, how)) do
            if night.end_early or not night:room(12) then
                return
            end
            local n = w.npc
            local d = items_mod.def(w.drop.item)
            local skill = how == "pocket" and "sleight_of_hand" or "persuasion"
            local p, keen = keenest(night, how == "pocket" and POCKET_KEEN or ASK_KEEN, skill)
            -- (Nobody at this table would think of it: it stays on them.)
            if p and night.rng:chance(math.min(0.95, keen)) then
                night.actor = p
                local item = util.lower_first(d and d.name or "something")
                local who = n.short or n.name
                local card
                if how == "pocket" then
                    card = { id = "mus_drop_pocket_" .. n.id .. "_" .. w.drop.item, type = "story", trigger = "museum_fixed",
                             fixed_actor = true, keep_actor = true, actor = { "instigator" },
                             title = "Light fingers",
                             text = "{actor_char} has spotted " .. item .. " on " .. who .. ", and wants to lift it. (You put it there.) Can they?",
                             options = {
                                 { label = "Let them try. Sleight of Hand.", sub = "Miss, and " .. who .. " notices.",
                                   roll = { dc = n.monster and 15 or 13, skill = { "sleight_of_hand" }, convenient = "success",
                                            success = { log = "{actor_char} comes away with " .. item .. ". " .. who .. " never feels a thing.",
                                                        effects = { { "actor", spotlight = 8, fun = 6 }, { "arch:instigator", fun = 2 } },
                                                        drop = true },
                                            fail = { log = who .. " turns round at exactly the wrong moment. \"Do you mind?\"",
                                                     effects = { { "actor", spotlight = 4, challenge = 3 }, { "arch:storyteller", fun = 1 } } } } },
                                 { label = who .. " notices before they can try.", log = "{actor_char} gets one look at " .. item .. " before " .. who .. " turns round.",
                                   effects = { { "actor", fun = -2 }, { "arch:tactician", fun = 1 } } },
                             } }
                else
                    card = { id = "mus_drop_ask_" .. n.id .. "_" .. w.drop.item, type = "story", trigger = "museum_fixed",
                             fixed_actor = true, keep_actor = true, actor = { "storyteller" },
                             title = "Can we have that?",
                             text = "{actor_char} asks " .. who .. " for " .. item .. ". (You put it on them.) What do they say?",
                             options = {
                                 { label = "They hand it over.", log = who .. " hands it over. \"Look after it.\"",
                                   effects = { { "actor", spotlight = 6, fun = 4 }, { "arch:storyteller", fun = 2 } }, drop = true },
                                 { label = "Only if they're talked round. Persuasion.",
                                   roll = { dc = 13, skill = { "persuasion", "deception" }, convenient = "success",
                                            success = { log = who .. " sighs, and hands it over.", effects = { { "actor", spotlight = 8, fun = 5 } }, drop = true },
                                            fail = { log = who .. " shakes their head. Not today.", effects = { { "actor", fun = -1 } } } } },
                                 { label = "No.", log = who .. " says no, and means it.", effects = { { "actor", fun = -2 }, { "arch:power_gamer", fun = -1 } } },
                             } }
                end
                local o = M.play_moment(night, card, sc)
                local won = o and (o.drop or (o.roll and night.last_roll and o.roll.success and o.roll.success.drop))
                if won and not w.drop.got then
                    earn_drop(night, sc, n, w)
                end
            end
        end
    end
end

-- After the fight: what the DM put on anyone they beat falls out (npcs.lua, how = "beaten").
function M.drops_beaten(night, sc)
    if not sc.fought or (sc.outcome or "win") ~= "win" then
        return
    end
    local npcs = require "game.model.npcs"
    for _, w in ipairs(npcs.waiting(night.campaign, sc.room, "beaten")) do
        if w.npc.monster and util.contains(sc.foes_beaten or {}, w.npc.monster) then
            night:say("Among what's left of " .. (w.npc.short or w.npc.name) .. ": something you put there.", "narration")
            -- (It falls out because they beat them: the find follows from the fight, R14.)
            local was = events.cause(night.campaign)
            events.set_cause(night.campaign, sc.fight_ev)
            earn_drop(night, sc, w.npc, w)
            events.set_cause(night.campaign, was)
        end
    end
end

function M.explore(night, sc)
    local data = MODULE.explore and MODULE.explore[sc.room]
    if not data or night.end_early or sc.boss or sc.epilogue or sc.showdown then
        return
    end
    local st = st_of(night)
    st.looked = st.looked or {}
    local _, by_id = night:board_places(sc)
    local open = {}
    for _, pid in ipairs(data) do
        if by_id[pid] and not st.looked[sc.room .. "/" .. pid] then
            table.insert(open, pid)
        end
    end
    local looks = math.min(#open, (sc.quick or sc.revisit) and 1 or (data.looks or 2))
    -- (Late in the evening, one look and on with it.)
    if (night.table_min or 0) > (night.table_planned or 210) * 0.75 then
        looks = math.min(looks, 1)
    end
    local last
    for _ = 1, looks do
        if night.end_early or #open == 0 then
            break
        end
        local p = night:pick_lead({ "explorer", "instigator", "storyteller", "power_gamer" }, last)
        last = p
        night.tl = night.tl or { n = 0 }
        night.tl.last = p and p.key or night.tl.last      -- (and sits out the next small moment)
        local i = night.rng:int(1, #open)
        local pid = table.remove(open, i)
        local pl = by_id[pid]
        st.looked[sc.room .. "/" .. pid] = true
        night.actor = p
        night:walk(p, { pl.x, pl.y }, nil, sc)
        if pl.line then
            night:say(pl.line, "narration")
        end
        -- Their companion helps (companions.lua): a sniff round, an old boot's memory. A pet they
        -- were told to find turns up here.
        local companions = require "game.model.companions"
        companions.maybe_find(night, p)
        local bonus, found = companions.help_look(night, p)
        if bonus > 0 then
            night.edge_next = night.edge_next or {}
            night.edge_next[p.key] = math.max(night.edge_next[p.key] or 0, bonus)
        end
        if found then
            night:say(found.helps.find_line, "good")
            M.handle(night, { francs = 1, find_text = events.word("pet_find", { pet = found.name or "Their pet" }) }, sc)
        end
        -- What they make of it: about that thing (MODULE.explore_say), the first look in a room only, and
        -- nothing at all about a place with nothing to say. (The third playtest, alive 6: a stock line,
        -- "There's a story behind the X", at every place, 11 a prologue.)
        local says = MODULE.explore_say and MODULE.explore_say[sc.room] and MODULE.explore_say[sc.room][pid]
        -- (No "There's a tiny train!" while the table grieves: able.somber. The look still happens.)
        if says and not sc.look_said and not able.somber(night) then
            sc.look_said = true
            local line = night:fresh(says, "look_" .. sc.room .. "_" .. pid)
            if line then
                night:emit({ kind = "say", who = p.key, text = line, ic = false })
            end
        end
        score.nudge_engagement(p, 4)
        night:apply({ { "actor", spotlight = 2 }, { "arch:explorer", fun = 1 } })
        night.table_min = (night.table_min or 0) + 2
        local ex = (data.finds and data.finds[pid] and { find = data.finds[pid] })
            or (data.traps and data.traps[pid] and { trap = data.traps[pid] }) or nil
        -- (Only while the night has calls to spare: a find or a trap never crowds out the room's
        -- own moments under the 8-to-15 budget. Without one, they just look.)
        if ex and night:room(11) and not sc.look_card then
            sc.look_card = true
            local card = look_card(night, sc, pl, ex)
            local o = M.play_moment(night, card, sc)
            if o and o.later then
                st.find_later = (st.find_later or 0) + o.later
                st.find_from = sc.room       -- (moved to another room: not the next look in this one, F12)
            end
        elseif (st.find_later or 0) > 0 and st.find_from ~= sc.room then
            -- The find the DM moved: here it is.
            local n = st.find_later
            st.find_later, st.find_from = 0, nil
            night:say("Tucked away by " .. util.lower_first(pl.name or "it") .. ", " .. p.char .. " finds "
                .. (n == 1 and "a Flitwidget Franc" or (util.int(n) .. " Flitwidget Francs")) .. ".", "good")
            night:say("The find you moved behind your screen turns up here.", "screen")
            M.handle(night, { francs = n, told = true }, sc)
            night:apply({ { "actor", spotlight = 4, fun = 4 } })
        end
    end
end

-- A Session Zero ask meets what's in tonight's room (a text with a soft variant for its tag):
-- agreed, you keep it gentle and say so; asked and refused, they feel it. Once a night per tag.
function M.soft_check(night, alts)
    local t = night.campaign.table or {}
    night.mus.soft = night.mus.soft or {}
    for _, alt in ipairs(alts or {}) do
        local tag = alt.when and (alt.when.soft or alt.when.line)
        if tag and not night.mus.soft[tag] then
            local key = (t.lines and t.lines[tag]) or (t.veils and t.veils[tag])
            local p = key and present(night, key)
            if p then
                night.mus.soft[tag] = true
                local name = (MODULE.content_names or {})[tag] or tag
                night:say((t.lines and t.lines[tag]) and ("You leave the " .. name .. " out, as you promised " .. p.name .. " at Session Zero.")
                    or ("You keep the " .. name .. " off screen, as you agreed with " .. p.name .. " at Session Zero."), "screen")
                score.add(p, "trust", 1)
            elseif t.pushed and t.pushed[tag] and present(night, t.pushed[tag]) then
                p = present(night, t.pushed[tag])
                night.mus.soft[tag] = true
                night:react({ [p.key] = "arms" })
                night:say(util.fill("{name} goes quiet. {Name_they} asked you about this at Session Zero.", { name = p.name }), "warn")
                score.add(p, "trust", -4)
                score.add(p, "fun", -6)
            end
        end
    end
end

-- A room starts: its read-aloud, the heroes it was made for, and how the DM chose to run it.
function M.read(night, sc)
    local r = MODULE.rooms[sc.room]
    M.soft_check(night, r.read_if)
    local text = r.read
    for _, alt in ipairs(r.read_if or {}) do
        if adventure.test(night.campaign, alt.when, knobs_of(night)) then
            text = alt.text
            break
        end
    end
    night:say(text, "narration")
    -- (A hero who died tonight: the wake, back in the gift shop, once the danger's over. Round three, B1.)
    if sc.room == "thanks" or sc.room == "gift_shop" then
        require("game.model.death").hold_wake(night)
    end
    if sc.backup then
        night:say("You hadn't prepped this one, but your backup page covers it: the map, the minis, a voice or two.", "screen")
    elseif sc.improv then
        night:say(night.mus.winged and night:fresh(M.WEEKLY.improv_again, "weekly_improv_again")
            or night:fresh(M.WEEKLY.improv, "weekly_improv"), "screen")
        night.mus.winged = true
    end
    if not sc.prepped then
        -- (You chose to read it from the book: say that, not that you skimmed it.)
        if night.mus.from_book and night.mus.from_book[sc.room] then
            night:say(night.mus.read_book and night:fresh(M.WEEKLY.from_book_again, "weekly_from_book_again")
                or night:fresh(M.WEEKLY.from_book, "weekly_from_book"), "warn")
            night.mus.read_book = true
        else
            -- (Once a night in full; after that, shorter: "You never read this room properly." four times
            -- in one night, the second playtest review.)
            night:say(night.mus.skimmed and night:fresh(M.WEEKLY.skim_again, "weekly_skim_again")
                or night:fresh(M.WEEKLY.skim, "weekly_skim"), "warn")
            night.mus.skimmed = true
        end
        night.table_min = night.table_min + 5
        night:apply({ { "arch:tactician", fun = -2 }, { "all", boredom = 3 } })
    end
end

-- What the week between promised, paying off here (the room's callbacks): a line, and maybe
-- something handed over for real. Each once (`adv.cb_said`): a trip back to the room plays the ones
-- that have come true since (round three: the vorpal sword promised after their first visit to the
-- gift shop was never on Telpur's shelf when they came back to spend their Francs).
function M.callbacks(night, sc)
    local c = night.campaign
    local r = MODULE.rooms[sc.room]
    local knobs = knobs_of(night)
    if not c.adv.cb_said then
        -- (A save from before kept no record: the rooms they've been through have had theirs.)
        c.adv.cb_said = {}
        for id in util.sorted_pairs(c.adv.done or {}) do
            for i in ipairs((MODULE.rooms[id] or {}).callbacks or {}) do
                c.adv.cb_said[id .. "#" .. i] = true
            end
        end
    end
    for i, cb in ipairs(r.callbacks or {}) do
        local key = sc.room .. "#" .. i
        if not c.adv.cb_said[key] and adventure.test(c, cb.when, knobs) then
            c.adv.cb_said[key] = c.week
            local given
            if cb.give and cb.give.magic then
                local items_mod = require "game.model.items"
                local to = cb.give.who and present(night, cb.give.who)
                local e = items_mod.earn(c, cb.give.magic, to and { to } or night.players)
                given = e and e.holder and present(night, e.holder)
                local d = items_mod.def(cb.give.magic)
                M.note_got(night, d and string.lower(d.name) or nil)
            end
            -- (A callback's other ways, `text` as a list, and its quiet one after a death, `sad` (false:
            -- unsaid then): "Telpur ... tells everyone who'll listen how he took a hit for the party" word
            -- for word every time, and after a wake. Round three's merge.)
            local text = able.pick(night, cb.text, cb.sad)
            if type(text) == "table" then
                text = night:fresh(text, "callback_" .. key)
            end
            if text then
                -- ({dead}: the heroes they've lost, by name.)
                local dead = {}
                for _, rec in ipairs(c.fallen or {}) do
                    if not util.contains(dead, rec.char) then
                        table.insert(dead, rec.char)
                    end
                end
                night:say(util.fill(text, { given = given and given.char or "the party", dead = util.join_names(dead) }), "narration")
            end
        end
    end
end

function M.room_start(night, sc)
    local c = night.campaign
    local r = MODULE.rooms[sc.room]
    if night.mood_later then
        night.mood_later = nil
        thoughts.mood(night)
    end
    if sc.room == "tomorrow" and not c.adv.mech_name then
        c.adv.mech_name = night.rng:pick(MODULE.mech_names)
    end
    local knobs = knobs_of(night)
    for _, kid in ipairs(r.knobs or {}) do
        local k = MODULE.knobs[kid]
        if knobs[kid] and k then
            local effs = {}
            for key, v in util.sorted_pairs(k.like or {}) do
                if v ~= 0 then
                    table.insert(effs, { "key:" .. key, fun = 3 * v })
                end
            end
            if k.pick_hero and type(knobs[kid]) == "string" then
                table.insert(effs, { "key:" .. knobs[kid], fun = 6, spotlight = 6, investment = 2 })
            end
            night:apply(effs)
            if k.say then
                night:say(k.say, "dm")
            end
        end
    end
    -- A hero's reason for coming is right here.
    for _, p in ipairs(adventure.hooked(c, sc.room)) do
        -- (Not for a hero who died and was replaced: the reason was theirs. "Brannoc tightens his grip",
        -- with Bryn in Dev's seat.)
        local replaced = c.new_char and c.new_char[p.key] and c.new_char[p.key].done
        if util.contains(night.players, p) and not replaced then
            local h = adventure.hook(c, p.key)
            night:react({ [p.key] = "lean" })
            night:say(util.fill(night:fresh(M.WEEKLY.thread, "weekly_thread"), { name = p.name, char = p.char }), "thread")
            -- The reason itself, paid off in the room: a real beat, not just a nod.
            if h.payoff then
                night:say(h.payoff, "thread")
            end
            c.adv.hook_paid = c.adv.hook_paid or {}
            c.adv.hook_paid[p.key] = c.adv.hook_paid[p.key] or c.week
            p.thread_hits = (p.thread_hits or 0) + 1      -- (a one-on-one want for it was given)
            score.add(p, "investment", 3)
            score.add(p, "fun", 4)
            local st = c.adv
            st.aspects = st.aspects or {}
            st.aspects[p.key] = st.aspects[p.key] or {}
            table.insert(st.aspects[p.key], 1, "Came for " .. util.mid_sentence(h.name) .. ", and found it in "
                .. util.lower_first(MODULE.rooms[sc.room].name))
            night:highlight(6, util.fill("{char} finds what {char_they} came for: ", { char = p.char }) .. util.lower_first(h.name), { p }, "thread")
        end
    end
    M.callbacks(night, sc)
    -- (Back where a hero fell with nobody to take their pack: it's picked up now. death.pick_up_pack.)
    require("game.model.death").pick_up_pack(night, sc.room)
    -- (A room with a fight in it gets looked around once it's safe: after the fight.)
    if not M.has_fight(sc) then
        M.explore(night, sc)
        sc.explored = true
        -- (A quiet room's small stuff comes now; a room with danger in it waits: quiet_stretch.)
        if not require("game.model.table_life").danger_ahead(night, sc) then
            require("game.model.table_life").room(night, sc, "enter")
        end
    end
    if sc.room == "thanks" then
        M.thanks_word(night, sc)
    end
    M.drops_social(night, sc)
    M.moments(night, sc, "start")
    if sc.showdown then
        M.showdown_start(night, sc)
    end
end

-- What the party brings into this fight (MODULE.items): each thing they picked up, bought or were
-- handed works here if it can, and the table hears what it does before initiative. night.lua's
-- combat_scene calls this before it builds the fight.
function M.arm(night, sc)
    local c = night.campaign
    local st = st_of(night)
    if not sc.encounter or sc.armed then
        return
    end
    sc.armed = true
    local knobs = knobs_of(night)
    local allies = {}
    for _, a in ipairs(sc.encounter.allies or {}) do
        allies[type(a) == "table" and a.id or a] = true
    end
    st.items_used = st.items_used or {}
    local lines = {}
    -- (The Mech they woke last session walks in with them: said before what it can do. F5.)
    for _, l in ipairs(require("game.model.companions").ally_arrives(night, sc.encounter.allies)) do
        table.insert(lines, l)
    end
    -- Once a night, at the first fight: what the week between left them with (MODULE.asides).
    night.mus.asides = night.mus.asides or {}
    st.asides_week = st.asides_week or {}
    for _, a in ipairs(MODULE.asides or {}) do
        -- (One that changes nothing isn't said two weeks running: R2.)
        local rested = not a.no_sneak and st.asides_week[a.id] == (c.week or 0) - 1
        if not night.mus.asides[a.id] and adventure.test(c, a.when, knobs) and not rested then
            night.mus.asides[a.id] = true
            st.asides_week[a.id] = c.week or 0
            night:say((a.in_room and a.in_room[sc.room]) or (a.lines and night:fresh(a.lines, "aside_" .. a.id)) or a.text, "dm")
            if a.no_sneak then
                sc.no_sneak = true       -- (night.lua's combat_scene: no scouting, nobody surprised)
            end
        end
    end
    local items_mod = require "game.model.items"
    for _, it in ipairs(MODULE.items or {}) do
        local ok = adventure.test(c, it.when, knobs) and not (it.once and not it.carry and st.items_used[it.id])
            and (not it.rooms or util.contains(it.rooms, sc.room)) and (not it.ally or allies[it.ally])
            and not (sc.extras_only and it.boss)      -- (what's for her, when she's already gone)
        -- (Something they carry is in one hero's pack, items.lua: it works only if they're here
        -- tonight, and it hasn't been used up.)
        local holder
        if it.carry then
            local _, hk = items_mod.holding(c, it.magic or it.id)
            holder = hk and present(night, hk)
            ok = ok and holder ~= nil
        elseif it.charm then
            holder = st.charmed_hero and present(night, st.charmed_hero)
            ok = ok and holder ~= nil
            if ok then
                sc.encounter.charmed = holder.key     -- (fight.lua: they start the fight charmed by the boss)
            end
        end
        if ok then
            -- (Handed round in front of the one they were lifted off: Telpur, along for the fight.)
            local along = false
            for _, e in ipairs(require("game.model.companions").fighters(night)) do
                along = along or e.id == "telpur"
            end
            if it.id == "arrows_lifted" and along then
                M.owner_sees(night, "mus_telpur", sc)
            end
            if it.opt then
                -- (A part of it, opt_value, never takes the place of the whole: bought arrows and slime
                -- and a lifted quiver together are still arrows and slime.)
                sc.encounter[it.opt] = (sc.encounter[it.opt] == true) or it.opt_value or true
            end
            if it.once and it.carry then
                items_mod.use(c, it.magic or it.id, holder and holder.key)
            elseif it.once then
                st.items_used[it.id] = c.week
            end
            night.mus.items_said = night.mus.items_said or {}
            if it.line and not night.mus.items_said[it.id] then
                night.mus.items_said[it.id] = true
                -- (Said at every first fight: three ways, fresh across weeks, when the module has them.)
                local said = (it.lines and night:fresh(it.lines, "item_" .. it.id)) or it.line
                local pb = st.paint_by and c:player(st.paint_by)
                table.insert(lines, util.fill(said, { holder = holder and holder.char or "Somebody",
                                                          mech = st.mech_name or "The Mech",
                                                          gift_the = st.paint_gift or "the painted weapon",
                                                          paint_holder = pb and pb.char or "somebody" }))
            end
        end
    end
    if #lines > 0 then
        night:say(table.concat(lines, " "), "good")
    end
end

-- The cheapest thing in the gift shop they don't have yet (a trip back to spend Francs is only
-- worth it if they can buy something: the playtest, Nov 2, kept going back with too few).
function M.cheapest(c)
    local st = c.adv
    local best = math.huge
    for _, m in ipairs(MODULE.moments) do
        if m.shop then
            for _, o in ipairs(m.options) do
                local mu = o.mus or {}
                local t = require("game.model.items").thing_for(mu)
                local have
                if t then
                    have = require("game.model.items").owned(c, t.magic or t.id)
                else
                    have = (mu.flag and st.flags[mu.flag]) or (mu.mark and st.marks[mu.mark])
                end
                local ok = not o.needs or adventure.test(c, o.needs)
                if o.price and not have and ok and o.price < best then
                    best = o.price
                end
            end
        end
    end
    return best
end

-- Whether this room has a fight tonight.
function M.has_fight(sc)
    if not sc.encounter or sc.no_fight or sc.resolved then
        return false
    end
    if sc.optional_fight then
        return sc.fight_on == true
    end
    return true
end

-- A short room: the hook, a beat, a rest. No checks or big finish, just its moments.
-- Put a room on the table: its board, the minis, the scene's title card.
function M.stage(night, sc, title)
    night.scene = sc
    night.actor, night.other = nil, nil
    sc.terrain = night:terrain_for(sc)
    sc.title = title or night:scene_title(sc)
    local party, npc = night:staging(sc)
    local cast, goal = sc.comps.cast, sc.comps.goal
    night.stage_now = { terrain = sc.terrain, board = night:board_for(sc), party = party, npc = npc }
    night:board_set(night:board_for(sc), sc)
    -- (A trip back to a cleared room isn't its fight or puzzle again: "Combat with the Briar
    -- Guardians" over a garden that had burned.)
    local back = sc.revisit ~= nil
    night:emit({ kind = "scene", index = sc.index, title = sc.title, type = sc.type,
                 board = night:board_for(sc), type_name = back and "A trip back" or content.scenes[sc.type].name, terrain = sc.terrain,
                 party = party, npc = npc, npc_hidden = npc ~= nil and not night:npc_in_view(sc, party, npc),
                 cast = (not back) and cast and cast.name or nil, goal = (not back) and goal and goal.name or nil })
    -- (In plain view from where they come in: on the mat at once. Behind a wall: when they walk in.)
    night.npc_pending = (npc ~= nil and not night:npc_in_view(sc, party, npc)) or nil
    return party, npc
end

function M.quick_room(night, sc)
    night.scene = sc
    night.actor, night.other = nil, nil
    if not sc.virtual then
        M.stage(night, sc)
        local cast, goal = sc.comps.cast, sc.comps.goal
        M.read(night, sc)
        night:dress_board()
        if cast and cast.talks ~= false then
            night.npc_cue = true
            night:describe(cast, "narration")
            night.npc_cue = nil
            night:npc_line("greet")
        elseif cast then
            night:describe(cast, "narration")
        end
        night:describe(goal, "goal")
    else
        sc.title = MODULE.rooms[sc.room].name
        M.read(night, sc)
    end
    M.room_start(night, sc)
    M.moments(night, sc, "mid")
    if M.has_fight(sc) and not night.end_early then
        sc.fought = true
        night:combat_scene(sc)
    end
    if sc.rest_here and not night.end_early then
        night:say("They sit down among the souvenirs and catch their breath: a short rest.", "aside")
        if not night.pc_list then
            require("game.model.fight").party(night)
        end
        night:do_rest("short", "town")
    end
    if not sc.virtual then
        night:settle_scene(sc)
    else
        sc.outcome = sc.outcome or "win"
    end
    M.explore_after(night, sc)
    M.moments(night, sc, "end")
    M.quiet_stretch(night, sc)
    local r = sc.comps.reward
    M.reward(night, sc)
    if not sc.virtual and not night.end_early then
        night:emit({ kind = "scene_end", index = sc.index, title = sc.title, call = night:scene_call(sc),
                     type_name = content.scenes[sc.type] and content.scenes[sc.type].name or nil,
                     goal = sc.comps.goal and sc.comps.goal.name or nil, outcome = sc.outcome,
                     reward = r and M.has_reward(night, sc, r) and util.capitalize(r.got or r.name) or nil,
                     fight = sc.fought or nil })
    end
end

-- Forks: the table says where it wants to go ----------------------------------------------------
-- The party goes where the table wants: new rooms by what each friend likes and the reason their
-- hero came, the nearest first (nobody wanders the long way round for nothing). Going back to a
-- room they've cleared needs a reason: something in it got away from them (and the explorer at
-- the table minds), the DM hinted there's more, they're hurt and the gift shop is a rest, they
-- have Francs to spend, or a room they walked past on the floor below. Fleeing a lost fight is
-- its own trip back (M.flee).

-- A friend saying where they'd go at a fork ({way}: "on to the offices", "back to the gift shop for a
-- breather"), and a second fan agreeing.
M.FORK_SAY = { "I say we go {way}.", "Can we go {way}?", "{Way}. That's my vote.", "I want to go {way}." }
M.FORK_SAME = { "Same.", "Yeah, that.", "Seconded.", "What they said." }
-- The DM's read of who wants what (C7): behind the screen, as a hunch, and only as good as the DM knows
-- them (familiar.lua): new to you, it's often wrong; like a book, nearly always right.
M.READ_LINES = { "Your hunch: {read}.", "Reading the table: {read}.", "Your read on them: {read}." }
-- "the offices" -> "to the offices"; "on to the offices", "up the stairs" stay as they are.
function M.go_way(way)
    if string.find(way or "", "^the ") then
        return "to " .. way
    end
    return way
end
local function night_side(night, key)
    return require("game.model.night").side_roll(night, key)
end
function M.fork_read(night, voters, first, choices, said_of, truth)
    if #choices < 2 or #voters == 0 then
        return
    end
    local familiar = require "game.model.familiar"
    local bits = {}
    for _, p in ipairs(voters) do
        local lv = familiar.level(night.campaign, p.key)
        local right = 0.45 + 0.12 * lv
        local i = first[p.key]
        -- (Its own dice, night.side_roll: the hunch never changes what the night's dice do.)
        if night_side(night, p.key .. "read") >= right then
            local other = {}
            for j in ipairs(choices) do
                if j ~= i then
                    table.insert(other, j)
                end
            end
            if #other > 0 then
                i = other[1 + math.floor(night_side(night, p.key .. "which") * #other) % #other]
            end
        end
        table.insert(bits, p.name .. " would go " .. M.go_way(said_of(i)))
    end
    night.fork_truth = truth
    -- (A glance behind the screen, not table time: `glance`, pacing.duration.)
    night:emit({ kind = "narrate", style = "screen", glance = true,
                 text = util.sentence_case(util.fill(night:fresh(M.READ_LINES, "fork_read"), { read = table.concat(bits, "; ") })) })
end

local function hurt(night)
    local hp, max = 0, 0
    for _, c in ipairs(night.pc_list or {}) do
        hp = hp + math.max(0, c.hp or 0)
        max = max + (c.hp_max or 0)
    end
    return max > 0 and (1 - hp / max) or 0
end

-- What a room promises at a fork (MODULE.pull, or plainly its name).
local function pull_of(id)
    local r = MODULE.rooms[id]
    return MODULE.pull[id] or { label = "On to " .. util.lower_first(r.name), want = "to go on to " .. util.lower_first(r.name), tags = {} }
end

local function want(p, id, c)
    local pl = pull_of(id)
    local n = 0
    for _, t in ipairs(pl and pl.tags or {}) do
        n = n + score.like(p, t)
    end
    local h = adventure.hook(c, p.key)
    if h and h.room == id then
        n = n + 2.5
    end
    return n
end

-- What the night so far does to a friend's vote (the playtest, Nov 2: the second floor's votes
-- were the same in 8 runs of 8, archetype and nothing else). Their hero hurt, the last room's
-- fight and how it went for them, boredom, a quiet night: each moves the vote, and the biggest
-- one that pulled them toward their pick is the reason they give. Returns bonus, reason.
local TAG_WORD = { explore = "new to look at", lore = "to read", puzzle = "to work out", danger = "to fight",
                   funny = "daft", cozy = "quiet", loot = "to take home", mystery = "to figure out",
                   action = "to happen" }

local function hero_hurt(night, p)
    local pc = night:pc_of(p)
    if not pc or not pc.hp_max or pc.hp_max <= 0 or (pc.hp or 0) <= 0 then
        return 0
    end
    return 1 - pc.hp / pc.hp_max
end

local function fork_mood(night, p, ch, c)
    local tags = (not ch.back and not ch.side) and (pull_of(ch.id).tags or {}) or {}
    local danger = util.contains(tags, "danger") or util.contains(tags, "action")
    local rest = (ch.back and ch.back.why == "rest") or (ch.id == "gift_shop" and not ch.back and not ch.side)
    local bonus, why = 0, nil
    local function add(n, text)
        bonus = bonus + n
        if n > 0 and text and (not why or n > why.n) then
            why = { n = n, text = text }
        end
    end
    -- Their hero is hurt: not another fight just yet, and a sit-down sounds good.
    local hh = hero_hurt(night, p)
    if hh >= 0.4 then
        if danger then
            add(-2 * hh)
        elseif rest then
            add(3 * hh, p.char .. "'s hurt and could use a sit-down")
        else
            add(1.2 * hh, p.char .. "'s hurt: nothing with teeth, please")
        end
    end
    -- The last room: their hero went down in it; a fight that went badly for them, or one they
    -- loved; a quiet one for a fighter.
    local last = night.mus.last
    local d = last and last.deltas[p.key] or 0
    if last and last.downs and last.downs[p.key] and not danger then
        add(rest and 2 or 1.5, p.char .. " went down in " .. util.lower_first(MODULE.rooms[last.id].name))
    elseif last and last.downs and last.downs[p.key] then
        add(-1.5)
    end
    if last and last.fought then
        if d <= -3 and p.primary ~= "butt_kicker" then
            add(danger and -1.2 or 1.2, (not danger) and "enough fighting for a bit" or nil)
        elseif d >= 4 and danger then
            add(1.4, "still buzzing from " .. util.lower_first(MODULE.rooms[last.id].name))
        end
    elseif last and danger and score.arch(p, "butt_kicker") > 0 and (d <= 1 or (p.boredom or 0) >= 15) then
        add(1.2 * score.arch(p, "butt_kicker") + 0.4, "itching for a fight")
    end
    -- Bored or flat: what they like, louder.
    if (p.boredom or 0) >= 25 or score.fun(p) < 30 then
        local best, bw = nil, 0
        for _, t in ipairs(tags) do
            local w = score.like(p, t)
            if w > bw then
                best, bw = t, w
            end
        end
        if best then
            add(0.8 * bw, "bored, and up for something " .. (TAG_WORD[best] or "new"))
        end
    end
    -- A quiet night so far: a room that's theirs.
    local avg = 0
    for _, q in ipairs(night.players) do
        avg = avg + (q.m.spotlight or 0)
    end
    avg = avg / math.max(1, #night.players)
    if (p.m.spotlight or 0) < avg - 10 and not ch.back and not ch.side and want(p, ch.id, c) > 0.5 then
        add(0.8, "barely had a moment yet")
    end
    -- Their hero's reason for coming (want() counts it: this is the words).
    local h = adventure.hook(c, p.key)
    if h and h.room == ch.id and not ch.back and not ch.side then
        add(0, nil)
        if not why or why.n < 2.5 then
            why = { n = 2.5, text = "it's why " .. p.char .. " came" }
        end
    end
    return bonus, why and why.text
end

-- The table decides ------------------------------------------------------------------------------
-- A choice that's the players' to make (the playtest, November 3: "it's critical that the DM is never
-- making player decisions for them; player play should be emergent but grounded in their stats"):
-- a card marked `party` in the module. Each friend leans by who they are (what each option does
-- for their kind of player), how their hero's doing, and a little noise; they talk it over, the
-- ones who don't much mind come round to the others, and when they're still split someone asks the
-- DM, who can nudge or leave it to them. The option they settle on plays as written.

-- Why someone leans the way they do, in their own voice, by the kind of player it pleased.
-- (A few ways each, fresh across weeks, and at most twice a night from one friend: "Less talking,
-- more hitting" after nearly every one of Dev's suggestions, the review found.)
local LEAN_WHY = {
    -- (Not "what's in there": that was Mara's reason for pouring pond water on the hedges. The confirming playtest, alive N2.)
    explorer = { "I want to see what it does.", "I want to know what happens.", "Come on, aren't you curious?" },
    tactician = { "It's the smart play.", "Fewer ways for it to go wrong.", "Think about it. It's the safest bet." },
    butt_kicker = { "Less talking, more hitting.", "Let's just get on with it.", "Sooner we start, sooner something gets hit." },
    instigator = { "Come on, it'll be chaos.", "What's the worst that could happen?", "It'll be funny. Trust me." },
    storyteller = { "It feels right, for the story.", "That's the better story.", "Think how it'll sound in the recap." },
    casual = { "Easiest way through.", "I'm happy with that.", "Works for me, honestly." },
    power_gamer = { "That's the best payoff.", "Best reward, easy.", "More loot that way." },
    method_actor = { "It's what {char} would do.", "{char} wouldn't have it any other way.", "{char} is already halfway there." },
}
M.LEAN_WHY = LEAN_WHY      -- (for the Dialogue Desk: tools/dialogue/export.lua)
M.LEAN_WHY_MAX = 2         -- reasons a night from one friend

-- An option that's a risk to them: a roll, a fight, a risk, or a moment that follows.
function M.risky_option(o)
    local m = o.mus or {}
    return (m.risk or m.fight or o.roll ~= nil or o.then_moment ~= nil) and true or false
end

-- What one option is worth to one friend, and the reason that weighed most. o: the card's option.
local function lean(night, p, o, not_them)
    local v, why, whyv = 0, nil, 0
    local function eff(list, w)
        for _, e in ipairs(list or {}) do
            local t = e[1]
            local f = (e.fun or 0) + 0.25 * (e.spotlight or 0) + 0.15 * (e.reward or 0)
            local mine = 0
            if t == "all" then
                mine = f
            elseif t == "actor" then
                mine = (night.actor == p) and f or 0.2 * f
            elseif t == "others" then
                mine = (night.actor ~= p) and f or 0
            elseif type(t) == "string" and string.sub(t, 1, 4) == "key:" then
                mine = (string.sub(t, 5) == p.key) and f or 0
            elseif type(t) == "string" and string.sub(t, 1, 5) == "arch:" then
                local a = string.sub(t, 6)
                mine = score.arch(p, a) * f
                if mine * w > whyv then
                    why, whyv = a, mine * w
                end
            end
            -- How hard it makes things: the fighters like it, the easy-going don't.
            if e.challenge and (t == "all" or t == "actor") then
                mine = mine + e.challenge * (0.25 * score.arch(p, "butt_kicker") - 0.15 * score.arch(p, "casual"))
            end
            v = v + mine * w
        end
    end
    if o.roll then
        eff(o.roll.success and o.roll.success.effects, 0.6)
        eff(o.roll.fail and o.roll.fail.effects, 0.4)
    end
    eff(o.effects, 1)
    local m = o.mus or {}
    if m.fight then
        v = v + 2 * score.arch(p, "butt_kicker")
    end
    if m.francs or m.flag or m.mark then
        v = v + 0.8 * score.arch(p, "power_gamer")
    end
    -- Their hero's state: hurt heroes don't want risks or fights. (Not where what's at stake isn't
    -- them: the card's `risks`, the Mech's red switch.) That's the moment, not who they are: it comes
    -- back apart (hv), so a strong taste doesn't soften it (the confirming playtest, alive 1: "Dev, on
    -- 3 HP, says berth").
    local hv = 0
    local hh = not_them and 0 or hero_hurt(night, p)
    local risky = M.risky_option(o)
    if risky and hh >= 0.4 then
        hv = hv - 4 * hh
    elseif m.warn and hh >= 0.4 then
        hv = hv + 2 * hh
        if 2 * hh > whyv then
            why, whyv = "hurt", 2 * hh
        end
    end
    return v, why, hv
end
M.lean = function(night, p, o, not_them)       -- (for the checks: tools/tests/roadmap_table_check.lua)
    local v, why, hv = lean(night, p, o, not_them)
    return v + hv, why
end

-- What carries over into a vote (R10, the round-two review: the table picked the same option on a card
-- in three runs of four): the week a friend's had, the spotlight so far tonight, a vote they lost last
-- time, and the table's habit ("we played it safe last time"). Each is a reason they say out loud, in
-- their own words, three ways each (fresh across weeks).
-- And the moment itself (the third playtest, alive 1: every friend made the same bid at the same beat
-- in 24 runs of 24, their seat and nothing else): their hero hurt or someone else's, the last fight
-- (a rough one, an easy one), being bored, what the card's own words point at (the sign says try the
-- water), and something they carry that's for this (the key from the pond). Every reason fits the
-- option's lean (an option's `lean`, else vote_kind): a tired friend never says "easy does it" for
-- setting the bushes on fire.
-- When the vote before was, in the friends' words: "earlier tonight", "last week", "a while back".
function M.vote_back(night, rec)
    local now = night.campaign and night.campaign.week or 0
    local w = rec and rec.week
    if not w or w >= now then
        return "earlier tonight"
    elseif now - w == 1 then
        return "last week"
    end
    return "a while back"
end
M.VOTE_WHY = {
    -- ({back}: when the vote before was, "earlier tonight" or "last week", never "last time": Conner's
    -- playtest, C26, heard "last time" as a game they'd played before. It's always their first time.)
    pushed = { "I went along {back}. This one's mine.", "I gave way {back}. Not on this one.",
               "I came round {back}. This time you can." },
    safe_last = { "We played it safe {back}. Let's not.", "We were careful {back}. Where's the fun in that?",
                  "Come on, we played it safe {back}." },
    bold_last = { "We went in swinging {back}. Let's be smart for once.", "We charged in {back}. Maybe not again.",
                  "We were reckless {back}. Let's not push it." },
    tired = { "I'm wiped tonight. The easy way, please.", "Long week. Let's keep it simple.", "I'm running on fumes. Easy does it." },
    celebrating = { "I'm in too good a mood to play it safe.", "Tonight's a good night. Let's go big.", "I'm feeling lucky tonight." },
    stressed = { "I just need one thing to go right tonight.", "No surprises, please. Not tonight.", "Let's do the one we know works." },
    quiet = { "I've barely done anything tonight.", "Let me have this one. I've been quiet all night.",
              "My turn, surely. I've hardly had a go." },
    -- ({edge}: what they brought against her, M.edges; {mine}: the one this friend carries.)
    edges = { "We came ready for her: {edge}.", "We've got {edge}. We can take her, fair and square.",
              "Let's do this properly. We've got {edge}." },
    mine = { "What did I bring {mine} up here for, then?", "I've been saving {mine} for her.",
             "I've got {mine}. I want to use it on her." },
    -- (The moment, R3 C1: {char} their own hero, {hurt} the hero who's hurt.)
    hurt = { "{char}'s hurt. Let's not.", "Not with {char} like this. The careful way.", "{char} needs a breather. Let's not risk it." },
    hurt_other = { "{hurt} is in no state for this. Easy does it.", "Look at {hurt}. Let's not.", "{hurt} needs a minute. The careful way, please." },
    rough = { "After that last fight? Let's be careful.", "We only just got through the last one. Gently, please.",
              "I'm still shaking from that last fight." },
    easy = { "That last lot went down easy. Let's keep going.", "We've got this. Look how the last fight went.",
             "The last fight was a warm-up. Come on." },
    bored = { "I'm bored. Let's make something happen.", "I need something to do. Let's go.", "Something should happen. Let's make it happen." },
    holds = { "I've got {thing}. Let's use it.", "That's what {thing} is for, surely.", "I didn't carry {thing} all this way for nothing." },
}
-- The same, naming what happened ({won}: what the table picked over them last time, {lost}: what they
-- wanted, {did}: what the table did, "we set the bushes on fire"). Said in turn with VOTE_WHY's own,
-- only when the vote before is known, and `pushed`'s only when the table heard them want the other
-- thing (the confirming playtest, alive N1: "I said yes when we X" was false 8 of 8 times, from a
-- friend who'd argued against X, or said nothing). (The third playtest, alive 4: "I lost last time" in three
-- phrasings, 159 times; name what was lost.)
M.VOTE_NAMED = {
    pushed = { "I let you {won} {back}. This one's mine.", "I wanted to {lost} {back}, and we didn't. Not again.",
               "I went along when {did}. My turn now." },
    safe_last = { "{Did} {back}. Let's do something braver.", "{Did} {back}. Let's not play it safe twice.",
                  "We were good {back}: {did}. My turn for some fun." },
    bold_last = { "{Did} {back}. Let's be smart for once.", "{Did} {back}. Maybe not again.",
                  "We pushed our luck {back}: {did}. Let's not." },
}
-- Someone on the winning side talks round one friend who barely minds ({name}: them; {want}, {Want}:
-- the winning side's), and they come round in their own voice ({name}: whoever talked them round). At
-- most one a vote, and only in answer to a push (the third playtest, alive 2: a friend overturned their
-- own bid on the very next line, "Okay, okay.", 47 times).
M.VOTE_PUSH_LINES = { "Come on, {name}. {Want}.", "{Name}, trust me on this one. {Want}.", "Please, {name}? {Want}. It'll be fine." }
M.VOTE_CAVE = {
    dev = { "Fine, {name}. {Want}. But I'm hitting something later.", "Ugh. Okay, {name}. {Want}.", "Fine. {Want}. You owe me one, {name}." },
    jess = { "Okay, okay, {name}. {Want}. Spoilsport.", "Fine, {name}. {Want}. Pip will sulk about it.", "Hmph. {Want}, then. You win, {name}." },
    mara = { "That's fair, {name}. {Want}.", "Hm. All right, {name}, you've talked me round. {Want}.", "Okay. {Want}. Good point, {name}." },
    sam = { "Yeah, okay, {name}. {Want}.", "Fair enough, {name}. {Want}.", "Sure, {name}. {Want}. Why not." },
    any = { "Okay, {name}. {Want}.", "Fine, {name}. {Want}.", "All right, {name}. {Want}." },
}
-- A friend who said nothing, and whose vote settles it, says so ({name}: the friend they side with;
-- {want}). The third playtest, alive 5 and F3: "(Dev and Jess's idea)" when Dev never spoke.
M.VOTE_SIDE = {
    dev = { "Let's {want}. Whatever {name} said.", "Let's {want}. I'm with {name}.", "Let's {want}. Can we go now?" },
    jess = { "Let's {want}. I'm with {name}.", "Let's {want}! Obviously.", "Let's {want}. Pip votes with {name}." },
    mara = { "Let's {want}. {Name}'s right, actually.", "Let's {want}. Put me down with {name}.", "Let's {want}. I'm with {name} on this one." },
    sam = { "Let's {want}. I'll go with {name}.", "Let's {want}. That's fine by me.", "Let's {want}. Same as {name}." },
    any = { "Let's {want}. I'm with {name}.", "Let's {want}. Same as {name}.", "Let's {want}, then." },
}
-- Two against two, settled (tally's order): say how. {name}: whose side it went to; {Their}: theirs.
M.VOTE_TIE = {
    pushed = { "Two against two. {name} gave way {back}, so this one's {name_theirs}.",
               "It's two each, and {name} went along {back}. Nobody argues.",
               "Two all. {name} gave in {back}, so this time {name} gets the say." },
    lead = { "Two against two. {name} found it, so it's {name_their} call.",
             "It's two each, and {name} is the one standing there. {Name_their} call.",
             "Two all. {name} found it, so {name} gets the say." },
    keen = { "Two against two. {name} wants it more, and it shows.", "It's two each, but {name} is keener. That settles it.",
             "Two all, until {name} says please. That settles it." },
}
-- (The reasons that are the week a friend's had, or why their hero came: said once a night each.)
local MOOD_WHY = { tired = true, celebrating = true, stressed = true, hook = true }
-- Everyone for something different (one voice each, the shop's four shelves, or three friends at hand):
-- settled the same way, said as it is. (The confirming playtest, truth M8: "Two all" after three voices
-- for three different things.)
M.VOTE_TIE_SPLIT = {
    pushed = { "Everyone wants something different. {name} gave way {back}, so this one's {name_theirs}.",
               "Nobody agrees, and {name} went along {back}. {Name_their} pick, then.",
               "All different. {name} gave in {back}, so this time {name} gets the say." },
    lead = { "Everyone wants something different. {name} found it, so it's {name_their} call.",
             "Nobody agrees, and {name} is the one standing there. {Name_their} call.",
             "All different. {name} found it, so {name} gets the say." },
    keen = { "Everyone wants something different. {name} wants it most, and it shows.",
             "Nobody agrees, but {name} is keenest. That settles it.",
             "All different, until {name} says please. That settles it." },
}
M.VOTE_PUSH = 1.2          -- what losing the last vote adds to a friend's own pick (twice running: twice that)
M.VOTE_HABIT = 0.8         -- what the last pick's kind adds to the other kind, for the friends who like it
M.VOTE_EDGE = 1.1          -- what each thing they brought against her adds to fighting her (up to three), for a planner
M.VOTE_MINE = 1.2          -- and what each one a friend carries adds, for them (up to two)
M.VOTE_NOISE = 1.6         -- people are people: what a friend's mood on the night adds, at most
M.VOTE_TASTE = 0.4         -- how much who they are weighs against the moment (lean's share)
M.VOTE_CAP = 6             -- and how far it goes: a taste this strong or more counts about the same
-- (How far apart two options are for a friend who "barely minds", "minded it", "really wants the other way":
-- the gaps scale with the taste, which counts for about a third of what it did before the confirming playtest.)
M.VOTE_GAP = 0.6
M.VOTE_BARE = 1.0          -- what facing her with nothing brought against her takes off fighting her, for all but a fighter
M.VOTE_FOUND = 1.0         -- what finding it adds to a side's care in a two-all (not a trump: R10)
M.VOTE_POINTS = 0.5        -- what the card's own words pointing at an option add for the one who found it
M.VOTE_MOOD = 1.5          -- what the week they've had adds to its kind of option (tired, stressed: careful; celebrating: bold)
M.VOTE_HOOK = 0.8          -- what their hero's reason for coming adds to its kind of option (MODULE.hooks[..].votes)
M.VOTE_MOMENT = 1.0        -- what the moment's pulls (their week, their hero, the last fight, the habit...) weigh

-- What the party brought that's good against Euryale in a fight (MODULE.showdown.edges, the ones
-- whose `when` holds): a list of { text, mine, holder } (holder: the hero key whose it is, at the
-- table), and the words for the first two.
function M.edges(c)
    local items_mod = require "game.model.items"
    local out, words = {}, {}
    for _, e in ipairs((MODULE.showdown or {}).edges or {}) do
        if adventure.test(c, e.when) then
            local holder
            if e.item then
                holder = select(2, items_mod.holding(c, e.item, true))
            elseif e.commander then
                local p = c.adv.mech_commander and c:player(c.adv.mech_commander)
                holder = p and p.present and p.key or nil
            end
            table.insert(out, { text = e.text, mine = e.mine, holder = holder })
            table.insert(words, e.text)
        end
    end
    return out, util.join_names({ words[1], words[2] })
end

-- An option's kind, for the table's habit and for which reasons fit it: "bold" (a roll, a fight, a
-- risk) or "safe" (a warning heeded, a fight avoided, careful hands), or nil (neither: a purchase, a
-- way through). The module can say it outright (`lean`: "bold", "safe" or "none"), where the shape of
-- the option misleads (the ritual is a roll, and the careful way).
function M.vote_kind(o)
    if o.lean then
        return o.lean ~= "none" and o.lean or nil
    end
    local m = o.mus or {}
    if o.roll or m.fight or m.risk or m.harsh or o.then_moment then
        return "bold"
    elseif m.warn or m.no_fight or m.careful then
        return "safe"
    end
    return nil
end
-- (Who likes which kind: the ones who came for a fight or for chaos go bold after a careful pick; the
-- ones who came for a plan or an easy night go careful after a reckless one.)
local KIND_FANS = { bold = { "butt_kicker", "instigator", "explorer" }, safe = { "tactician", "casual" } }
-- (Which of a friend's own reasons fit which kind: "It's the smart play" isn't said for the reckless
-- option, nor "What's the worst that could happen?" for the careful one.)
local LEAN_FITS = { tactician = "safe", casual = "safe", butt_kicker = "bold", instigator = "bold" }

local function fan_of(p, kind)
    local n = 0
    for _, a in ipairs(KIND_FANS[kind] or {}) do
        n = math.max(n, score.arch(p, a))
    end
    return n
end

-- The vote before, as the table would say it: "we set the bushes on fire" (its beat, MODULE.beats,
-- by the option's place on the card as written: the card played may have fewer).
local function we_did(card_id, o)
    local b = MODULE.beats and MODULE.beats[card_id]
    local card
    for _, m in ipairs(MODULE.moments) do
        if m.id == card_id then
            card = m
        end
    end
    for _, k in ipairs({ "drink", "talk", "yield" }) do
        local sd = MODULE.showdown and MODULE.showdown[k]
        if sd and sd.id == card_id then
            card = sd
        end
    end
    local i
    for j, oo in ipairs(card and card.options or {}) do
        if oo == o or oo == o.of or (o.want and oo.want == o.want) then
            i = j
        end
    end
    local ob = b and i and b[i]
    local t = type(ob) == "table" and ob.did or ob
    if type(t) ~= "string" or not string.find(t, "^they ") then
        return nil
    end
    t = string.gsub(t, "^they ", "we ")
    t = string.gsub(t, "%f[%a]them%f[%A]", "us")
    -- (A beat that names what came of it, "{gift}", needs the night's own facts: the plain reason says it instead.
    -- The confirming playtest: "I said yes when we kept {gift} until it dripped away.")
    if string.find(t, "{", 1, true) then
        return nil
    end
    return t
end
M.we_did = we_did

-- What carries over for friend p on option o, beside who they are: bonus, reason (a VOTE_WHY key),
-- and the words that reason needs ({mine}, {hurt}, {thing}). The night so far (their mood this week,
-- the spotlight tonight, their hero, the last fight), the votes before (the habit), what the card points
-- at, what they carry, and against Euryale, what they brought (edges: M.edges).
local function carry(night, p, o, votes, avg_spot, edges, risky, no_mood)
    local bonus, why, whyv = 0, nil, 0
    local alt, altv = nil, 0        -- (the biggest reason that isn't the week they've had or their hero's: MOOD_WHY)
    local words = {}
    local function add(n, key)
        if key ~= "edges" and key ~= "mine" then
            n = n * M.VOTE_MOMENT
        end
        bonus = bonus + n
        if key and n > whyv then
            why, whyv = key, n
        end
        if key and not MOOD_WHY[key] and n > altv then
            alt, altv = key, n
        end
    end
    local kind = M.vote_kind(o)
    local m = o.mus or {}
    local safe, bold = kind == "safe", kind == "bold"
    -- (The week they've had and why their hero came weigh on what's theirs to risk: not on the Mech's red
    -- switch, whose risk is the Mech's (`risks`), nor at her ultimatum, where what counts is what they
    -- brought against her (`edges`): with nothing brought, only her fight's own fan wants it, R10.)
    local personal = not no_mood
    local mood = personal and p.mood or nil
    if mood == "tired" then
        -- (The careful way, if it's the easy way: not a puzzle to work out, `effort`. "The easy way,
        -- please" was a tired friend's reason for working out a tomb's ritual from a notebook.)
        if safe and not o.effort then
            add(M.VOTE_MOOD, "tired")
        elseif m.fight then
            bonus = bonus - 0.6
        end
    elseif mood == "celebrating" and bold then
        add(M.VOTE_MOOD, "celebrating")
    elseif mood == "celebrating" and safe then
        bonus = bonus - 0.5 * M.VOTE_MOOD
    elseif mood == "stressed" and safe and not o.effort then      -- ("the one we know works": not a puzzle)
        add(M.VOTE_MOOD, "stressed")
    elseif mood == "stressed" and bold then
        bonus = bonus - 0.5 * M.VOTE_MOOD
    end
    -- Their hero hurt, or someone else's badly: the careful way, where the other way is a risk. (Lean
    -- takes the risky ones down.) Only the one who minds most says it for someone else.
    local hh = hero_hurt(night, p)
    if hh >= 0.4 and safe and risky then
        add(2.5 * hh, "hurt")
    end
    local worst, wh = nil, 0
    for _, q in ipairs(night.players) do
        local h = q ~= p and hero_hurt(night, q) or 0
        if h > wh then
            worst, wh = q, h
        end
    end
    if worst and wh >= 0.5 and safe and risky then
        local f = math.max(score.arch(p, "tactician"), score.arch(p, "casual"))
        if f > 0 then
            add(1.8 * f * wh, "hurt_other")
            words.hurt = worst.char
        end
    end
    -- The last fight: a rough one makes them careful, an easy one makes the keen keener.
    local last = night.mus and night.mus.last
    if last and last.fought then
        local downs = 0
        for _ in pairs(last.downs or {}) do
            downs = downs + 1
        end
        local d = (last.deltas or {})[p.key] or 0
        if downs > 0 or d <= -3 then
            if safe and risky then
                add(1.6 - 0.8 * score.arch(p, "butt_kicker"), "rough")
            elseif bold then
                bonus = bonus - 0.8
            end
        elseif d >= 3 and bold and m.fight then
            local f = math.max(score.arch(p, "butt_kicker"), score.arch(p, "instigator"))
            if f > 0 then
                add(1.2 * f, "easy")
            end
        end
    end
    -- Their hero's reason for coming (this run's, MODULE.hooks[..].votes): the careful way or the bold
    -- one, where one of the ways is a risk to them (`risky`), and in the room it's about, the fight. Only the hero who came for it: not a new one rolled up
    -- after a death. (The confirming playtest, alive 1: the same bid from the same seat, 24 runs of 24.)
    local h = personal and adventure.hook(night.campaign, p.key) or nil
    local hv = h and h.votes
    local own = content.players[p.key]
    if hv and (not own or own.char == p.char) then
        local scene_room = night.scene and night.scene.room
        local here = hv.here and h.room == scene_room and (m.fight or m.ending == "fallen")
        if here then
            add(M.VOTE_HOOK, "hook")
            words.hook = hv.here.say
        elseif kind and kind == hv.kind and risky then
            add(M.VOTE_HOOK, "hook")
            words.hook = hv.say
        elseif kind and kind ~= hv.kind and risky then
            bonus = bonus - 0.5 * M.VOTE_HOOK       -- (and the other way, a little less)
        end
    end
    -- Bored: anything, as long as something happens.
    if (p.boredom or 0) >= 22 and bold then
        add(math.min(1.5, 0.05 * p.boredom), "bored")
    end
    -- Leading this one, and quiet all night: the option that's theirs to play.
    local quiet = false
    if night.actor == p and (p.m.spotlight or 0) < avg_spot - 8 then
        local theirs = false
        for _, list in ipairs({ o.effects or {}, (o.roll and o.roll.success and o.roll.success.effects) or {} }) do
            for _, e in ipairs(list) do
                theirs = theirs or (e[1] == "actor" and (e.spotlight or 0) > 0)
            end
        end
        if theirs then
            add(1.4, "quiet")
            quiet = true
        end
    end
    -- What the card's own words point at (the sign says to try the water): whoever found it reads it out.
    -- (Not on top of a quiet night: that's already why the one who found it wants it.)
    if o.points and night.actor == p and not quiet then
        add(M.VOTE_POINTS, "points")
    end
    -- What happened earlier that bears on this one (an option's `pulls`: { when, who = a friend's key or
    -- the kinds of player it moves, n, say }): "We've already burnt his garden. Let's not rob him as well."
    for _, pl in ipairs(o.pulls or {}) do
        local f = (type(pl.who) == "string" and (pl.who == p.key and 1 or 0)) or 0
        if type(pl.who) == "table" then
            for _, a in ipairs(pl.who) do
                f = math.max(f, score.arch(p, a))
            end
        end
        if f > 0 and adventure.test(night.campaign, pl.when) then
            add((pl.n or 1.5) * f, "pull")
            if why == "pull" or alt == "pull" then
                words.pull = pl
            end
        end
    end
    -- Something they carry that's for this (the brass key from the pond, `uses`: the flag it came with).
    if o.uses then
        local got = events.last(night.campaign, { kind = "moment", flag = o.uses })
        if got and got.who == p.key then
            add(2.2, "holds")
            words.thing = o.uses_name or "it"
        end
    end
    -- Nothing brought against her: fighting a Gorgon bare-handed frightens all but her fight's own fan.
    if o.edges and (not edges or #edges == 0) then
        bonus = bonus - M.VOTE_BARE * (1 - score.arch(p, "butt_kicker"))
    end
    -- They came ready for her (R10, after the world merge: with the fight and the Lecturer's page the
    -- only answers left, the table read her the page every time, as only Dev wanted the fight): a
    -- friend who likes a fair, clever fight counts what they brought against her, and says what it is.
    if o.edges and edges and #edges > 0 then
        local f = math.max(score.arch(p, "tactician"), 0.5 * score.arch(p, "power_gamer"))
        if f > 0 then
            add(M.VOTE_EDGE * f * math.min(3, #edges), "edges")
        end
        local mine = {}
        for _, e in ipairs(edges) do
            if e.holder == p.key and e.mine then
                table.insert(mine, e.mine)
            end
        end
        if #mine > 0 then
            add(M.VOTE_MINE * math.min(2, #mine), "mine")
            words.mine = mine[1]
        end
    end
    -- The table's habit: the last pick's kind, and the friends who like the other kind.
    local lastv = votes and votes.last
    if lastv and lastv.kind and kind and kind ~= lastv.kind then
        local f = fan_of(p, kind)
        if f > 0 then
            add(M.VOTE_HABIT * f * math.min(2, lastv.streak or 1), lastv.kind == "safe" and "safe_last" or "bold_last")
        end
    end
    words.alt = alt
    return bonus, why, words
end

local function short_want(o)
    return o.want or util.lower_first((string.gsub(o.label or "", "[%.!]+$", "")))
end

-- A friend's own line for the talk (VOTE_CAVE, VOTE_SIDE: by friend, else "any"), three ways, fresh.
local function own_line(night, tbl, p, key, vars)
    local list = tbl[p.key] or tbl.any
    local l = night:fresh(list, key .. "_" .. p.key) or list[1]
    return util.fill(l, vars)
end

-- copy: the card as it'll be played (its options already filtered). Returns the option's index in
-- copy.options, after the talk (and the DM's nudge, if they asked). Says the talk out loud.
function M.table_pick(night, copy, vars)
    local nudged_to         -- (the option your nudge pointed at, if you were asked and gave one)
    local opts = copy.options
    local live = {}
    for i, o in ipairs(opts) do
        if not o.disabled then
            table.insert(live, i)
        end
    end
    if #live <= 1 then
        return live[1] or 1
    end
    -- (Who has a say: the friends whose heroes are in the scene and can act. One who went off on their
    -- own isn't there to vote on it, or to act on it (F18, F11); a dead or stoned hero's player watches
    -- this one (round three, A1, "dead Oswin's player then votes on the yield": night:at_hand asks able).)
    local players = night:at_hand()
    if #players == 0 then
        players = night.players
    end
    local vals, first, why = {}, {}, {}
    -- (What carries over from the votes before, R10: kept with the adventure, so it lasts the weeks.)
    local adv = night.campaign.adv
    local votes = adv and adv.votes or {}
    local avg_spot = 0
    for _, p in ipairs(players) do
        avg_spot = avg_spot + (p.m.spotlight or 0)
    end
    avg_spot = avg_spot / math.max(1, #players)
    local edges, edge_words = M.edges(night.campaign)
    -- (A card with a risk to them on it: what being hurt, or a rough fight, makes them shy of. Not a
    -- card whose risk falls on something else, its `risks`: "Oswin's hurt. Let's not." about the
    -- Mech's red switch, the switch saved for her in two runs of three.)
    local not_them = copy.risks ~= nil
    -- (Nor the week they've had, at her ultimatum: carry's `personal`.)
    local no_mood = not_them
    for _, i in ipairs(live) do
        no_mood = no_mood or opts[i].edges ~= nil
    end
    local risky = false
    for _, i in ipairs(live) do
        local o = opts[i]
        risky = risky or M.risky_option(o)
    end
    risky = risky and not not_them
    -- (Who they are is a lean, not a verdict: a strong taste counts, but less and less the stronger it
    -- is, so the moment can still turn it. And a friend who's had a big night already lets the others
    -- choose: their taste counts for less, and they speak up last.)
    local avg_fun = 0
    for _, p in ipairs(players) do
        avg_fun = avg_fun + score.fun(p)
    end
    avg_fun = avg_fun / math.max(1, #players)
    local had_fun = {}
    for _, p in ipairs(players) do
        had_fun[p.key] = ((p.m.spotlight or 0) > avg_spot + 12 or score.fun(p) > avg_fun + 12) or nil
    end
    local function taste(x, p)
        local e = math.exp(2 * x / M.VOTE_CAP)
        return M.VOTE_TASTE * (had_fun[p.key] and 0.6 or 1) * M.VOTE_CAP * (e - 1) / (e + 1)
    end
    for _, p in ipairs(players) do
        vals[p.key] = {}
        local best, bv, plain, pv
        for _, i in ipairs(live) do
            local v, w, hv = lean(night, p, opts[i], not_them)
            local tv = taste(v, p)
            v = tv + hv
            local cb, cw, cwords = carry(night, p, opts[i], votes, avg_spot, edges, risky, no_mood)
            local nz = night.rng:next() * M.VOTE_NOISE
            v = v + nz
            if M.on_vote_vals then      -- (for tuning and the checks: each friend's sum, part by part)
                M.on_vote_vals(night, copy, p, i, { taste = tv, hurt = hv, noise = nz, carry = cb, why = cw })
            end
            if not pv or v > pv then
                plain, pv = i, v
            end
            -- (Their own reason only where it fits the option's lean.)
            local kind = M.vote_kind(opts[i])
            if w and LEAN_FITS[w] and kind and LEAN_FITS[w] ~= kind then
                w = nil
            end
            vals[p.key][i] = { v = v + cb, why = w, cwhy = cw, cb = cb, words = cwords }
            if not bv or v + cb > bv then
                best, bv = i, v + cb
            end
        end
        first[p.key] = best
        -- (The reason they give is what swung it: the night so far or the last vote, when that turned
        -- their pick or weighed as much as who they are.)
        local b = vals[p.key][best]
        why[p.key] = (b.cwhy and (plain ~= best or b.cb >= 0.5)) and b.cwhy or b.why or b.cwhy
    end
    -- A friend who lost the last vote holds out for theirs this time (twice running: harder), and says so.
    -- (Said only when the table doesn't already agree, and when it matters to them: nobody needs to
    -- hold out for what everyone wants, or for what they barely mind.)
    local agreed = true
    for _, p in ipairs(players) do
        agreed = agreed and first[p.key] == first[players[1].key]
    end
    local pushers = {}
    for _, p in ipairs(players) do
        local n = (votes.lost or {})[p.key]
        if n and n > 0 then
            local b = vals[p.key][first[p.key]]
            b.v = b.v + M.VOTE_PUSH * math.min(2, n)
            local next_best = nil
            for _, i in ipairs(live) do
                if i ~= first[p.key] and (not next_best or vals[p.key][i].v > next_best) then
                    next_best = vals[p.key][i].v
                end
            end
            -- (Once a night each: "I lost last time" every other vote is a habit, not a reason.)
            night.mus.pushed_said = night.mus.pushed_said or {}
            if not agreed and (not next_best or b.v - next_best >= 1.5 * M.VOTE_GAP) and not night.mus.pushed_said[p.key] then
                why[p.key] = "pushed"
                night.mus.pushed_said[p.key] = true
            end
            pushers[p.key] = true
        end
    end
    -- (A card that says what its lead wants, "{actor_char} wants a closer look", has them vote for
    -- it: the second playtest review heard Oswin want a closer look, then Sam vote to give the knight
    -- a wide berth. F18.)
    local lead = night.actor
    local prop
    for _, i in ipairs(live) do
        if copy.proposes and opts[i] == copy.proposes then
            prop = i
        end
    end
    if lead and prop and vals[lead.key] then
        first[lead.key] = prop
        why[lead.key] = nil
        vals[lead.key][prop].v = vals[lead.key][prop].v + 0.5    -- (they said it: they hold to it)
    end
    local wanted = util.copy(first)         -- (what each wanted going in: who lost, for next time)
    local function tally()
        local n, top, top_n = {}, nil, 0
        -- (Two against two: the side of whoever went along last time, then the side of whoever found
        -- it, then the keener side. R10.)
        local care = {}
        for _, p in ipairs(players) do
            local i = first[p.key]
            n[i] = (n[i] or 0) + 1
            care[i] = (care[i] or 0) + math.min(4, vals[p.key][i].v) + (pushers[p.key] and 100 or 0)
                + (p == night.actor and M.VOTE_FOUND or 0)
        end
        for _, i in ipairs(live) do
            if (n[i] or 0) > top_n or ((n[i] or 0) == top_n and top_n > 0 and care[i] > care[top]) then
                top, top_n = i, n[i]
            end
        end
        local tied = 0
        for _, i in ipairs(live) do
            if (n[i] or 0) == top_n then
                tied = tied + 1
            end
        end
        return top, top_n, tied, n, care
    end
    -- What each says first: the ones with a real reason speak up (two at most), in their own words.
    local spoke = 0
    local order = util.copy(players)
    local function keen(p)
        return vals[p.key][first[p.key]].v - (had_fun[p.key] and 3 or 0)
    end
    table.sort(order, function(a, b)
        local va, vb = keen(a), keen(b)
        if va ~= vb then
            return va > vb
        end
        return a.key < b.key
    end)
    local said = {}         -- key -> the option they've been heard for
    local heard_by = {}     -- option -> the first friend heard for it
    local function heard(p, i)
        said[p.key] = i
        heard_by[i] = heard_by[i] or p
    end
    -- Before anyone counts the votes (a two-all, or the card asking you), everyone counted has said
    -- where they stand: the confirming playtest, truth M8: "Two all" after three voices, 22 times in
    -- 41, and a card saying "Mara and Jess want this" when Jess hadn't spoken.
    local function voice_all()
        for _, p in ipairs(order) do
            local i = first[p.key]
            if i and said[p.key] ~= i then
                local friend = heard_by[i]
                local sw = (p ~= night.actor and opts[i].short) or short_want(opts[i])
                local want_vars = { want = sw, Want = util.capitalize(sw), name = friend and friend.name or "",
                                    Name = friend and friend.name or "" }
                night:emit({ kind = "say", who = p.key, ic = false,
                             text = (friend and friend ~= p) and own_line(night, M.VOTE_SIDE, p, "vote_side", want_vars)
                                 or util.sentence_case("Let's " .. sw .. ".") })
                heard(p, i)
            end
        end
    end
    -- (The vote before, for the reasons that name it: what won, what they wanted, what the table did.)
    local lastv = votes.last
    local lost_to = votes.lost_to
    -- (A friend's reason is a catchphrase: each one once a session, and never from the same friend two
    -- talks running. R2, the second playtest review: "Less talking, more hitting" after nearly every
    -- one of Dev's suggestions.)
    night.lean_talks = (night.lean_talks or 0) + 1
    night.lean_last = night.lean_last or {}
    local sided = false
    for _, p in ipairs(order) do
        if spoke < 3 and (spoke < 2 or first[p.key] ~= first[order[1].key]) then
            local i = first[p.key]
            -- A friend close to the one who spoke first, and nearly as happy either way, backs them
            -- (the moment decides who they side with, not their seat). Once a vote.
            local leader = order[1]
            local siding
            if spoke == 1 and not sided and i ~= first[leader.key] and not pushers[p.key] and p ~= night.actor then
                local r = rapport.rel(night.campaign, p.key, leader.key)
                if r and r.rapport >= 64 and r.heat < 10 and vals[p.key][i].v - vals[p.key][first[leader.key]].v < M.VOTE_GAP then
                    i = first[leader.key]
                    first[p.key] = i
                    siding = leader
                    sided = true
                end
            end
            local w = siding and nil or why[p.key]
            -- (The week they've had is said once a night: it's still true at the next vote, but it isn't
            -- news. The confirming playtest, alive N2: "running on fumes", "wiped tonight" and "Long week"
            -- from Sam at three votes running.)
            night.mus.mood_said = night.mus.mood_said or {}
            if w and MOOD_WHY[w] then
                if night.mus.mood_said[p.key] then
                    w = (vals[p.key][i].words or {}).alt or vals[p.key][i].why
                else
                    night.mus.mood_said[p.key] = true
                end
            end
            night.lean_why_n = night.lean_why_n or {}
            local said_n = night.lean_why_n[p.key] or 0
            local rested = night.lean_last[p.key] == night.lean_talks - 1
            local fill = { char = p.char, edge = edge_words, mine = (vals[p.key][i].words or {}).mine,
                           hurt = (vals[p.key][i].words or {}).hurt, thing = (vals[p.key][i].words or {}).thing }
            local reason
            if siding then
                reason = util.fill(night:fresh({ "I'm with {name}.", "{Name}'s right.", "What {name} said." }, "vote_siding") or "I'm with {name}.",
                    { name = siding.name, Name = siding.name })
            elseif w == "pull" then
                local pl = (vals[p.key][i].words or {}).pull
                reason = pl and night:fresh(pl.say, "vote_pull_" .. tostring(copy.id) .. "_" .. i) or nil
            elseif w == "hook" then
                local hs = (vals[p.key][i].words or {}).hook
                reason = hs and night:fresh(hs, "vote_hook_" .. p.key, true) or nil
            elseif w == "points" then
                local says = opts[i].points
                reason = type(says) == "table" and night:fresh(says, "vote_points_" .. tostring(copy.id)) or (type(says) == "string" and says) or nil
            elseif w and M.VOTE_WHY[w] then
                local list = {}
                for _, l in ipairs(M.VOTE_WHY[w]) do
                    table.insert(list, l)
                end
                local named = M.VOTE_NAMED[w]
                local heard_lose = lost_to and lost_to.heard
                local nv = { did = lastv and lastv.did, Did = lastv and lastv.did and util.capitalize(lastv.did),
                             won = w == "pushed" and heard_lose and lost_to.won or nil, lost = w == "pushed" and heard_lose and lost_to.wanted or nil }
                if w == "pushed" then
                    nv.did = heard_lose and lost_to.did or nil
                end
                nv.back = M.vote_back(night, w == "pushed" and lost_to or lastv)
                for _, l in ipairs(named or {}) do
                    -- (Every fill-in it needs, not just the first: "We were good {back}: {did}." with no {did}.)
                    local ok = string.find(l, "{%a+}") ~= nil
                    for need in string.gmatch(l, "{(%a+)}") do
                        ok = ok and nv[need] ~= nil
                    end
                    if ok then
                        table.insert(list, util.fill(l, nv))
                    end
                end
                reason = night:fresh(list, "vote_" .. w, true)
                reason = reason and util.fill(reason, { back = M.vote_back(night, w == "pushed" and lost_to or lastv) })
            elseif w and LEAN_WHY[w] and said_n < M.LEAN_WHY_MAX and not rested then
                reason = night:fresh(LEAN_WHY[w], "lean_" .. w .. "_" .. p.key, true)
            end
            if reason and not siding and not M.VOTE_WHY[w] and w ~= "points" and w ~= "pull" and w ~= "hook" then
                night.lean_why_n[p.key] = said_n + 1
                night.lean_last[p.key] = night.lean_talks
            end
            -- (The second voice for the same thing says it shorter: three bubbles of "work out the ritual
            -- while someone holds the guardian off" at once, the engine run's 8_14.)
            local said_it = heard_by[i] ~= nil and p ~= night.actor
            local line = "Let's " .. ((said_it and not reason and opts[i].short) or short_want(opts[i])) .. "."
                .. (reason and (" " .. util.fill(reason, fill)) or "")
            night:emit({ kind = "say", who = p.key, text = util.sentence_case(line), ic = false })
            heard(p, i)
            spoke = spoke + 1
        end
    end
    -- The talk: someone on the bigger side talks round one friend who barely minds (they answer that
    -- push, in their own voice), and the quiet ones who barely mind come round to where most of them are.
    local top, top_n, tied = tally()
    local half = #players / 2
    if top_n <= half then
        local pusher = heard_by[top]
        local caved = false
        for _, p in ipairs(order) do
            local mine = vals[p.key][first[p.key]].v
            -- (Not the one holding out after last time; a friend with half an eye on their phone, sooner.)
            local easy = (p.mood == "distracted" and 2 or 1.2) * M.VOTE_GAP
            if first[p.key] ~= top and vals[p.key][top] and mine - vals[p.key][top].v < easy and not pushers[p.key] then
                local sw = (p ~= night.actor and opts[top].short) or short_want(opts[top])
                local want_vars = { want = sw, Want = util.capitalize(sw) }
                if said[p.key] then
                    -- (A friend who spoke only gives way to a push, once a vote, from someone who spoke for it.)
                    if pusher and pusher ~= p and not caved then
                        caved = true
                        want_vars.name, want_vars.Name = p.name, p.name
                        night:emit({ kind = "say", who = pusher.key, ic = false,
                                     text = util.fill(night:fresh(M.VOTE_PUSH_LINES, "vote_push") or M.VOTE_PUSH_LINES[1], want_vars) })
                        want_vars.name, want_vars.Name = pusher.name, pusher.name
                        night:emit({ kind = "say", who = p.key, ic = false, text = own_line(night, M.VOTE_CAVE, p, "vote_cave", want_vars) })
                        first[p.key] = top
                        heard(p, top)
                    end
                else
                    first[p.key] = top
                    -- (Whoever comes round says so: nobody's counted for what they argued against.)
                    want_vars.name, want_vars.Name = pusher and pusher.name or "", pusher and pusher.name or ""
                    night:emit({ kind = "say", who = p.key, ic = false,
                                 text = pusher and own_line(night, M.VOTE_SIDE, p, "vote_side", want_vars)
                                     or ("Fine by me. " .. want_vars.Want .. ".") })
                    heard(p, top)
                end
            end
        end
        top, top_n, tied = tally()
    end
    -- Still split: someone asks the DM (the DM can nudge, or leave it to them).
    local asked = false
    if (tied > 1 or top_n <= half) and night.rng:chance(0.75) and not night.gentle then      -- (night 1: they settle it, R6)
        asked = true
        voice_all()
        local asker = night:pick_actor({ "casual", "tactician", "storyteller" }) or players[1]
        local card = { id = "table_asks_" .. (copy.id or "x"), type = "table", trigger = "museum_fixed", fixed_actor = true,
                       title = "They ask you",
                       text = "The table can't agree. " .. util.fill(night:fresh(M.WEEKLY.ask_look, "weekly_ask_look"), { name = asker.name })
                           .. ": \"What do you think?\"",
                       options = {} }
        for _, i in ipairs(live) do
            local names = {}
            for _, p in ipairs(players) do
                if first[p.key] == i then
                    table.insert(names, p.name)
                end
            end
            local against = i ~= top or tied > 1
            -- (What letting her go costs, said where you'd nudge them to it: R5.)
            local esc_sub
            if opts[i].escape then
                esc_sub = select(2, adventure.escape_cost(night.campaign))
            end
            table.insert(card.options, { label = "Nudge them: " .. short_want(opts[i]), nudge = i, cost = esc_sub and "escape" or nil,
                sub = (#names > 0 and (util.join_names(names) .. (#names == 1 and " wants this." or " want this.")) or "Nobody's for this yet.")
                    .. (esc_sub and (" " .. esc_sub) or ""),
                effects = { { "all", trust = (against and (night.mus.nudged or 0) >= 1) and -1 or 0 } },
                log = "You give them a little push: \"If it were me, I'd " .. short_want(opts[i]) .. ".\"" })
        end
        table.insert(card.options, { label = "\"It's up to you.\"", leave = true,
            sub = "They settle it themselves: whoever gave way at the vote before gets this one, or else whoever found it.",
            effects = { { "arch:storyteller", fun = 1 }, { "arch:casual", fun = -1 } },
            log = "You shrug behind the screen. \"Your call.\"" })
        local was_a = night.actor
        night.actor = asker
        local o = night:decision(card, vars)
        night.actor = was_a
        if o and o.nudge then
            nudged_to = o.nudge
            night.mus.nudged = (night.mus.nudged or 0) + 1
            -- They asked: most take the hint. Only someone who really wants the other way holds out.
            local held = {}
            for _, p in ipairs(players) do
                if first[p.key] ~= o.nudge then
                    local gap = vals[p.key][first[p.key]].v - vals[p.key][o.nudge].v
                    if gap < 4 * M.VOTE_GAP then
                        first[p.key] = o.nudge
                    else
                        table.insert(held, p)
                        score.add(p, "fun", -1)     -- (and minds a little that you leaned the other way)
                    end
                end
            end
            top, top_n, tied = tally()
            if tied > 1 then
                top = o.nudge
            end
            if top ~= o.nudge then
                night:say(night:fresh(M.WEEKLY.own_way, "weekly_own_way"), "aside")
            elseif #held > 0 then
                night:emit({ kind = "say", who = held[1].key, text = "For the record, I still think we should "
                    .. short_want(opts[first[held[1].key]]) .. ".", ic = false })
            end
        end
    end
    -- Nobody heard for the side that won, or a side that wins only on its quiet votes: the quiet ones
    -- say where they stand, so the table can follow it (the third playtest, F3: two friends voiced one
    -- option, one the other, and the other won on the silent fourth).
    if nudged_to ~= top then
        local n_heard, n_other = 0, 0
        local counts = {}
        for _, p in ipairs(players) do
            counts[first[p.key]] = (counts[first[p.key]] or 0) + 1
            if first[p.key] == top and said[p.key] == top then
                n_heard = n_heard + 1
            end
        end
        for _, i in ipairs(live) do
            if i ~= top then
                n_other = math.max(n_other, counts[i] or 0)
            end
        end
        for _, p in ipairs(order) do
            if first[p.key] == top and said[p.key] ~= top and n_heard <= n_other then
                local friend = heard_by[top]
                local sw = (p ~= night.actor and opts[top].short) or short_want(opts[top])
                local want_vars = { want = sw, Want = util.capitalize(sw),
                                    name = friend and friend.name or "everyone", Name = friend and friend.name or "Everyone" }
                night:emit({ kind = "say", who = p.key, ic = false,
                             text = friend and own_line(night, M.VOTE_SIDE, p, "vote_side", want_vars) or ("Let's " .. want_vars.want .. ".") })
                heard(p, top)
                n_heard = n_heard + 1
            end
        end
        -- Two against two, settled: say how (tally's order: who gave way last time, who found it, who's keener).
        if tied > 1 or (counts[top] or 0) == n_other then
            local by, kind
            for _, p in ipairs(players) do
                if first[p.key] == top and pushers[p.key] then
                    by, kind = p, "pushed"
                end
            end
            -- (Whoever found it settles it only when the sides care about the same: otherwise the keener
            -- side wins, and says so. The confirming playtest: the tablet's and the switch's two-alls all
            -- went to whoever found it, and the cards' finders are their fans.)
            local care = select(5, tally())
            local other = nil
            for _, i in ipairs(live) do
                if i ~= top and (counts[i] or 0) == (counts[top] or 0) and (not other or care[i] > other) then
                    other = care[i]
                end
            end
            if not by and night.actor and first[night.actor.key] == top and (not other or care[top] - M.VOTE_FOUND <= other) then
                by, kind = night.actor, "lead"
            end
            if not by then
                local bv
                for _, p in ipairs(players) do
                    if first[p.key] == top and (not bv or vals[p.key][top].v > bv) then
                        by, bv, kind = p, vals[p.key][top].v, "keen"
                    end
                end
            end
            if by then
                voice_all()
                -- (Two against two only when it is: one voice each is "everyone wants something different".)
                local tbl, tkey = M.VOTE_TIE, "vote_tie_"
                if (counts[top] or 0) <= 1 then
                    tbl, tkey = M.VOTE_TIE_SPLIT, "vote_split_"
                end
                night:say(util.fill(night:fresh(tbl[kind], tkey .. kind) or tbl[kind][1], { name = by.name, back = M.vote_back(night, votes.last) }), "aside")
            end
        end
    end
    -- (Whoever acts on it is one who backed it, from the heroes in the scene: if every voice heard for
    -- it is off somewhere else, a quiet backer who's here says so. F18, F11.)
    if nudged_to ~= top then
        local here, heard_here = {}, false
        for _, p in ipairs(night:at_hand()) do
            here[p] = true
            heard_here = heard_here or (first[p.key] == top and said[p.key] == top)
        end
        if not heard_here then
            for _, p in ipairs(order) do
                if not heard_here and here[p] and first[p.key] == top then
                    local friend = heard_by[top]
                    local sw = (p ~= night.actor and opts[top].short) or short_want(opts[top])
                    local want_vars = { want = sw, Want = util.capitalize(sw), name = friend and friend.name or "everyone",
                                        Name = friend and friend.name or "Everyone" }
                    night:emit({ kind = "say", who = p.key, ic = false,
                                 text = friend and own_line(night, M.VOTE_SIDE, p, "vote_side", want_vars) or ("Let's " .. want_vars.want .. ".") })
                    heard(p, top)
                    heard_here = true
                end
            end
        end
    end
    -- Who backed it is who the table heard back it (and the one who acts on it is one of them).
    local names = {}
    night.party_backers = {}
    night.party_backers_room = night.scene and night.scene.room or nil
    for _, p in ipairs(order) do
        if first[p.key] == top and (said[p.key] == top or nudged_to == top) then
            table.insert(night.party_backers, p)
        end
    end
    if #night.party_backers == 0 then
        for _, p in ipairs(order) do
            if first[p.key] == top then
                table.insert(night.party_backers, p)
            end
        end
    end
    for _, p in ipairs(players) do
        if util.contains(night.party_backers, p) then
            table.insert(names, p.name)
        end
    end
    night:say("The table decides: " .. short_want(opts[top]) .. ((nudged_to == top and " (on your nudge)")
        or ((#names > 0 and #names < #players) and (" (" .. util.join_names(names) .. "'s idea)")) or "") .. ".", "aside")
    -- What the next vote remembers (R10): who went along with what they didn't want (they push next
    -- time), and what kind of pick this was (the table notices a habit), in words that name it.
    if adv then
        adv.votes = adv.votes or {}
        local vt = adv.votes
        -- (The one who minded most: they push next time, harder if it's twice running.)
        local loser, gap = nil, 1.5 * M.VOTE_GAP       -- (minded it: not a shrug)
        for _, p in ipairs(players) do
            local mine = wanted[p.key]
            if said[p.key] and said[p.key] ~= mine then
                mine = said[p.key]       -- (what they were heard for: talked round, it's that)
            end
            local g = mine ~= top and (vals[p.key][mine].v - vals[p.key][top].v) or 0
            if g >= gap then
                loser, gap = p.key, g
            end
        end
        local again = loser and vt.lost and vt.lost[loser] or 0
        vt.lost = loser and { [loser] = again + 1 } or {}
        vt.lost_to = loser and { won = short_want(opts[top]), wanted = short_want(opts[said[loser] or wanted[loser]]),
                                 did = we_did(copy.id, opts[top]), card = copy.id, heard = said[loser] ~= nil or nil,
                                 week = night.campaign.week } or nil
        -- ("Last time" is the vote just gone: one that was neither bold nor careful breaks the habit.)
        local kind = M.vote_kind(opts[top])
        vt.last = { kind = kind, streak = kind and ((vt.last and vt.last.kind == kind) and ((vt.last.streak or 1) + 1) or 1) or 0,
                    card = copy.id, did = we_did(copy.id, opts[top]), week = night.campaign.week }
    end
    return top
end

-- New rooms still waiting on this floor (the stairs up wait for the rest, for most tables).
local function left_on_floor(c, options)
    local n = 0
    for _, id in ipairs(options) do
        if id ~= "stairs" then
            n = n + 1
        end
    end
    return n
end

-- early: how much of the evening is still ahead (0..1). With most of it ahead and rooms left on the
-- floor, nobody's in a hurry to meet the boss: "we've got all night, let's see the rest first".
-- (The sweep, October 30: a table that went up after one room had a night of one room, scored 17.)
local function want_new(p, id, c, steps, floor_left, early)
    local n = want(p, id, c) - 0.6 * math.max(0, (steps or 1) - 1)
    if id == "stairs" then
        n = n + 1.5 * score.arch(p, "butt_kicker")
            - floor_left * (1.2 * score.arch(p, "explorer") + 0.8 * score.arch(p, "storyteller") + 0.4)
        if floor_left > 0 and (early or 0) > 0.4 then
            n = n - 6 * ((early or 0) - 0.4)
        end
    end
    return n
end

local function want_back(p, b, night)
    local st = st_of(night)
    local n = -2.5 - 0.6 * math.max(0, (b.steps or 1) - 1)
    if b.why == "missed" then
        n = n + 6 * score.arch(p, "explorer") + 1.5 * score.arch(p, "power_gamer")
    elseif b.why == "hint" then
        n = n + 4.5
    elseif b.why == "passed" then
        n = n + 6 * score.arch(p, "explorer") + 1.5 * score.arch(p, "storyteller") - 0.3 * (b.steps or 1)
    elseif b.why == "shop" then
        n = n + 4 * score.arch(p, "power_gamer") + 2.5 * score.arch(p, "casual") + math.min(2, (st.francs or 0) / 4)
    elseif b.why == "rest" then
        n = n + 3 + 2 * score.arch(p, "tactician") + 2 * score.arch(p, "casual") + 3 * (hurt(night) - 0.45)
    end
    return n
end

-- The trips back worth raising right now: { id, why, steps }.
function M.second_looks(night)
    local c = night.campaign
    local st = st_of(night)
    local out = {}
    local pos = st.pos or st.last_room
    if not pos or st.ending or (night.mus.backs or 0) >= M.MAX_BACKS then
        return out
    end
    local fresh, cleared = adventure.reachable(c, pos)
    local been = night.mus.been or {}
    for _, id in ipairs(MODULE.order) do
        local steps = cleared[id]
        if steps and not been[id] then
            if #adventure.missed(c, id) > 0 then
                table.insert(out, { id = id, why = st.hints[id] and "hint" or "missed", steps = steps })
            end
            if id == "gift_shop" then
                if hurt(night) >= 0.45 then
                    table.insert(out, { id = id, why = "rest", steps = steps })
                elseif (st.francs or 0) >= M.cheapest(c) and not night.mus.shopped and M.shop_open(c, id) then
                    table.insert(out, { id = id, why = "shop", steps = steps })
                end
            end
        end
        if fresh[id] and st.passed[id] and not been[id] then
            table.insert(out, { id = id, why = "passed", steps = fresh[id] })
        end
    end
    -- Only the ones someone at the table actually wants (or the DM hinted at).
    local keen = {}
    for _, b in ipairs(out) do
        local best = -99
        for _, p in ipairs(night.players) do
            best = math.max(best, want_back(p, b, night))
        end
        if b.why == "hint" or best >= M.KEEN then
            b.keen = best
            table.insert(keen, b)
        end
    end
    return keen
end

-- Side rooms the DM opened from the map repository (map_repo.add_side_room): off the room the
-- party stands in, or one door away through cleared rooms. Each once.
function M.side_options(night)
    local c = night.campaign
    local st = st_of(night)
    local out = {}
    local pos = st.pos or st.last_room
    if not pos or not st.side_rooms then
        return out
    end
    local _, cleared = adventure.reachable(c, pos)
    cleared[pos] = 0
    st.side_done = st.side_done or {}
    local ids = {}
    for sid in pairs(st.side_rooms) do
        table.insert(ids, sid)
    end
    table.sort(ids)
    for _, sid in ipairs(ids) do
        local sr = st.side_rooms[sid]
        local steps = cleared[sr.off]
        if steps and steps <= 1 and not st.side_done[sid] then
            table.insert(out, { side = sid, id = sr.off, steps = steps, name = sr.name })
        end
    end
    return out
end

-- Is the room's shop open (its shopping moment not locked or cut, its shopkeeper about)?
function M.shop_open(c, id)
    for _, m in ipairs(MODULE.moments) do
        if m.room == id and m.shop then
            return adventure.moment_open(c, m)
        end
    end
    return true
end

local function want_side(p, sd)
    return 0.3 + 2.5 * score.arch(p, "explorer") + 1.0 * score.arch(p, "storyteller") + 0.8 * score.like(p, "explore")
        - 0.8 * score.arch(p, "butt_kicker") - 0.4 * (sd.steps or 0)
end

-- A side room: the map the DM chose, a look round its places of interest, and back out.
function M.side_room(night, sd)
    local c = night.campaign
    local st = st_of(night)
    local sr = st.side_rooms and st.side_rooms[sd.side]
    if not sr then
        return
    end
    st.side_done = st.side_done or {}
    st.side_done[sd.side] = true
    local off = MODULE.rooms[sr.off]
    local sc = { type = "exploration", comps = { location = content.components[off.comps and off.comps.location or ""] },
                 missing = {}, room = sr.off, side = sd.side, quick = true, prepped = true, quality = 0.6,
                 difficulty = 1 }
    sc.board_override, sc.custom_map = map_repo.terrain_of(c, sr.ref)
    if not sc.board_override then
        return
    end
    table.insert(night.scenes, sc)
    sc.index = #night.scenes
    night.mus.total = math.max(night.mus.total or 1, sc.index)
    M.stage(night, sc, sr.name)
    night:say("Off " .. util.lower_first(off.name) .. ", a door nobody noticed before: " .. sr.name .. ".", "narration")
    night.table_min = night.table_min + 6
    -- Its places of interest, two at most: a closer look each.
    local places = sr.places or {}
    local shown = 0
    for _, pl in ipairs(places) do
        if shown >= 2 or night.end_early then
            break
        end
        shown = shown + 1
        local card = { id = "mus_side_" .. sd.side .. "_" .. util.int(shown), type = "story", trigger = "museum",
                       actor = { "explorer", "storyteller", "instigator" },
                       title = pl.name or "A closer look",
                       text = (pl.line and (pl.line .. " ") or "") .. "{actor_char} wants a closer look.",
                       options = {
                           { label = "Let them look.", roll = { dc = 12, skill = { "investigation", "perception" }, convenient = "success",
                               success = { log = "{actor_char} turns up something: a Flitwidget Franc, wedged where nobody looked.",
                                           effects = { { "actor", spotlight = 8, fun = 4 }, { "arch:explorer", fun = 3 } },
                                           mus = { francs = 1, aspect = "Found a side room nobody else noticed" } },
                               fail = { log = "Dust, and the feeling of being watched.", effects = { { "actor", challenge = 3 } } } } },
                           { label = "Nothing in here for us. Move on.", log = "{actor_char} shrugs and follows the others out.",
                             effects = { { "arch:explorer", fun = -2 }, { "arch:butt_kicker", fun = 2 } } },
                       } }
        M.play_moment(night, card, sc)
    end
    if shown == 0 and not night.end_early then
        night:say("They poke around. It's quiet in here. Almost too quiet.", "dm")
    end
    sc.outcome, sc.had_roll = "win", true
    if not night.end_early then
        night:emit({ kind = "scene_end", index = sc.index, title = sc.title, outcome = "win", call = night:scene_call(sc) })
    end
    table.insert(night.mus.rooms, { room = sr.off, outcome = "win", side = sr.name })
    return sc
end

local function back_label(b)
    local r = MODULE.rooms[b.id]
    local why = { missed = "a second look", hint = "the thing you hinted at", passed = "they walked past it",
                  shop = "to spend Francs", rest = "a breather" }
    return "Back to " .. util.lower_first(r.name) .. " (" .. (why[b.why] or "") .. ")"
end

-- The fork: new rooms and any trip back worth raising. Returns { id = room } or { back = trip }.
function M.fork(night, options, backs, sides)
    local c = night.campaign
    local st = st_of(night)
    backs = backs or {}
    sides = sides or {}
    local pos = st.pos or st.last_room
    local fresh = pos and adventure.reachable(c, pos) or {}
    local floor_left = left_on_floor(c, options)
    local early = 1 - (night.table_min or 0) / math.max(1, night.table_planned or 210)
    -- (Who has a say: the friends whose heroes can act, as at a vote: round three, A1.)
    local voters = able.only(night, night.players)
    if #voters == 0 then
        voters = night.players
    end
    local choices = {}
    -- (You said one more room: not the stairs, which end the night at her door, while there's a room
    -- to play. The gate after the final pass's merge, 569 random: "one more room" was the stairs and
    -- goodbyes, a fourth time that night.)
    local skip_stairs = night.one_more and (#options + #backs + #sides) > 1
    for _, id in ipairs(options) do
        if not (skip_stairs and id == "stairs") then
            table.insert(choices, { id = id, steps = fresh[id] or 1 })
        end
    end
    for _, b in ipairs(backs) do
        table.insert(choices, { back = b, id = b.id })
    end
    for _, sd in ipairs(sides) do
        table.insert(choices, { side = sd, id = sd.id })
    end
    -- Each friend's first choice: what they like, what tonight has done to them, and a little
    -- noise (people are people). Each says why, when it's more than taste.
    local first, by, vals, said = {}, {}, {}, {}
    for _, p in ipairs(voters) do
        local best, bv
        vals[p.key] = {}
        for i, ch in ipairs(choices) do
            local v = (ch.back and want_back(p, ch.back, night)) or (ch.side and want_side(p, ch.side))
                or want_new(p, ch.id, c, ch.steps, floor_left, early)
            local m, why = fork_mood(night, p, ch, c)
            v = v + m + night.rng:next() * 0.9
            vals[p.key][i] = { v = v, why = why }
            if not bv or v > bv then
                best, bv = i, v
            end
        end
        first[p.key] = best
        said[p.key] = vals[p.key][best].why
    end
    -- A friend who's close to someone (rapport built up tonight or before), and nearly as happy
    -- either way, goes where they go. One a fork.
    for _, p in ipairs(voters) do
        local mine = vals[p.key][first[p.key]].v
        for _, q in ipairs(voters) do
            local r = q ~= p and rapport.rel(c, p.key, q.key)
            local theirs = first[q.key]
            if r and r.rapport >= 64 and r.heat < 10 and theirs ~= first[p.key]
                and mine - vals[p.key][theirs].v < 0.9 and not night.mus.followed then
                first[p.key] = theirs
                said[p.key] = "going where " .. q.name .. " goes"
                night.mus.followed = true
                break
            end
        end
    end
    night.mus.followed = nil
    for _, p in ipairs(voters) do
        local best = first[p.key]
        by[best] = by[best] or {}
        table.insert(by[best], p)
    end
    -- "Mara wants the offices (it's why Oswin came)."; two or more, each reason with a name.
    -- (The same reason from several of them is said once: "both still buzzing from...".)
    local function because(list)
        local groups, order = {}, {}
        for _, p in ipairs(list) do
            local r = said[p.key]
            if r then
                if not groups[r] then
                    groups[r] = {}
                    table.insert(order, r)
                end
                table.insert(groups[r], p.name)
            end
        end
        if #order == 0 then
            return ""
        end
        if #order == 1 and #groups[order[1]] == #list then
            local n = #list
            return " (" .. (n == 1 and "" or (n == 2 and "both " or "all ")) .. order[1] .. ")"
        end
        local why = {}
        for k, r in ipairs(order) do
            if k <= 2 then
                table.insert(why, util.join_names(groups[r]) .. ": " .. r)
            end
        end
        return " (" .. table.concat(why, "; ") .. ")"
    end
    local top, top_n
    for i in ipairs(choices) do
        local n = #(by[i] or {})
        if not top_n or n > top_n then
            top, top_n = i, n
        end
    end
    -- What the table says.
    local key = "hub"
    if util.contains(options, "chamber") or util.contains(options, "paintings") then
        key = (st.done.chamber or st.done.paintings) and "second_wing" or "wings"
    elseif #options <= 1 then
        key = "roam"
    end
    local fk = MODULE.forks[key] or { title = "Where next?", text = "The table looks at the map." }
    -- What they see is where they stand, not what's on offer.
    local here = st.pos or st.last_room
    local at = here and MODULE.fork_at and MODULE.fork_at[here]
    local at_text = at and at.text
    if at and at.after then
        local all = true
        for _, rid in ipairs(at.after.rooms or {}) do
            all = all and st.done[rid] ~= nil
        end
        if all then
            at_text = at.after.text
        end
    end
    fk = { title = fk.title, text = at_text or fk.text }
    local parts = {}
    for i, ch in ipairs(choices) do
        local names = {}
        for _, p in ipairs(by[i] or {}) do
            table.insert(names, p.name)
        end
        if ch.side then
            if #names > 0 then
                table.insert(parts, util.join_names(names) .. (#names == 1 and " wants " or " want ") .. "to poke into "
                    .. util.lower_first(ch.side.name) .. because(by[i]) .. ".")
            end
        elseif ch.back then
            local line = MODULE.revisit_why[ch.back.why]
            if line and (#names > 0 or ch.back.why == "hint") then
                table.insert(parts, util.fill(line, { names = util.join_names(names), want = #names == 1 and "wants" or "want",
                                                     room = util.lower_first(MODULE.rooms[ch.id].name) }))
            end
        elseif #names > 0 then
            table.insert(parts, util.join_names(names) .. (#names == 1 and " wants " or " want ") .. pull_of(ch.id).want
                .. because(by[i]) .. ".")
        end
    end
    local pm = night.prep and night.prep.museum
    -- A way the DM has locked shut: the table can see it, it just won't open yet.
    local shut = pos and ties.shut_line(c, pos)
    if shut then
        night.mus.shut_said = night.mus.shut_said or {}
        night.mus.shut_said[pos] = true
        table.insert(parts, shut)
    end
    -- Where they go is the table's to settle, never the DM's (the playtest, November 3): they say
    -- what they want, the ones who barely mind come round, and if they're still split someone asks
    -- you. You can nudge, hint at a room they missed, or leave it to them.
    -- (The read-aloud is the place, and a way the DM locked; what each of them wants is theirs to say,
    -- and what the DM makes of it is the DM's own read, behind the screen: Conner's playtest, C7, the
    -- fork's read-aloud told the table what each of them wanted. `parts` is that read, as it truly is.)
    night:say(fk.text .. (shut and (" " .. shut) or ""), "narration")
    local truth_parts = parts
    -- (A way, said mid-sentence: "the offices", "up the stairs now", "back to the gift shop".)
    local function low(t)
        local first = string.match(t, "^(%a+)")
        if first == "On" or first == "Up" or first == "Back" or first == "Into" or first == "Down" then
            return string.lower(string.sub(t, 1, 1)) .. string.sub(t, 2)
        end
        return util.lower_first(t)
    end
    local function label_of(i)
        local ch = choices[i]
        if ch.side then
            return "into " .. util.lower_first(ch.side.name) .. " (a side room)"
        elseif ch.back then
            return low(back_label(ch.back))
        end
        return low((string.gsub(pull_of(ch.id).label, ",", "")))
    end
    -- (The same, as the table says it: no card's note in brackets. "Okay, back to the gift shop (to
    -- spend Francs). Lead on." said aloud, the third playtest.)
    local SAID_WHY = { missed = "for a second look", hint = "to see what we missed", passed = "to see what we walked past",
                       shop = "to spend some Francs", rest = "for a breather" }
    local function said_of(i)
        local ch = choices[i]
        if ch.side then
            return "into " .. util.lower_first(ch.side.name)
        elseif ch.back then
            return "back to " .. util.lower_first(MODULE.rooms[ch.back.id].name) .. (SAID_WHY[ch.back.why] and (" " .. SAID_WHY[ch.back.why]) or "")
        end
        return label_of(i)
    end
    -- Each says where they'd go, in their own words: the first for each way, and one "same" after.
    local here = {}
    for _, p in ipairs(night:at_hand()) do
        here[p.key] = true
    end
    for i in ipairs(choices) do
        -- (Not a friend whose hero wandered off: they aren't in this scene. F11.)
        local fans = {}
        for _, p in ipairs(by[i] or {}) do
            if here[p.key] then
                table.insert(fans, p)
            end
        end
        if #fans > 0 then
            local way = M.go_way(said_of(i))
            local line = night:fresh(M.FORK_SAY, "fork_say")
            -- ("{Way}. That's my vote." wants the place itself: "The offices. That's my vote.")
            local w = string.find(line, "^{Way}") and said_of(i) or way
            night:emit({ kind = "say", who = fans[1].key, ic = false,
                         text = util.fill(line, { way = w, Way = util.capitalize(w) }) })
            if fans[2] then
                night:emit({ kind = "say", who = fans[2].key, ic = false, text = night:fresh(M.FORK_SAME, "fork_same") })
            end
        end
    end
    M.fork_read(night, voters, first, choices, said_of, truth_parts)
    local function tally()
        local n, t, tn = {}, nil, 0
        for _, p in ipairs(voters) do
            n[first[p.key]] = (n[first[p.key]] or 0) + 1
        end
        for i in ipairs(choices) do
            if (n[i] or 0) > tn then
                t, tn = i, n[i]
            end
        end
        local tied = 0
        for i in ipairs(choices) do
            if (n[i] or 0) == tn then
                tied = tied + 1
            end
        end
        return t, tn, tied
    end
    local half = #voters / 2
    if top_n <= half then
        for _, p in ipairs(voters) do
            local mine = vals[p.key][first[p.key]].v
            if first[p.key] ~= top and mine - vals[p.key][top].v < 1.0 then
                first[p.key] = top
                local way = said_of(top)
                night:emit({ kind = "say", who = p.key, ic = false,
                             text = util.fill(night:fresh(M.WEEKLY.easy, "weekly_easy"), { way = way, Way = util.capitalize(way) }) })
            end
        end
    end
    local tied
    top, top_n, tied = tally()
    -- The DM's own move, when they ask: a hint that a room they cleared still has something in it,
    -- with what's still in there (the playtest, November 3: the hint should remind you what they missed).
    -- (Offered at one fork a night, not every one: the playtest, Nov 2, saw it at five in a row.)
    local hint_id
    if not night.mus.hinted and not night.mus.hint_offered and (night.mus.backs or 0) < M.MAX_BACKS then
        for _, id in ipairs(MODULE.order) do
            local cl = select(2, adventure.reachable(c, pos or id))
            if cl[id] and not st.hinted[id] and #adventure.missed(c, id) > 0 and not (night.mus.been or {})[id] then
                hint_id = id
                break
            end
        end
    end
    local o
    local split = tied > 1 or top_n <= half
    if ((split and night.rng:chance(0.8)) or (hint_id and night.rng:chance(0.35))) and not night.gentle then   -- (night 1: theirs, R6)
        local asker = night:pick_actor({ "casual", "tactician", "storyteller" }) or voters[1]
        local card = { id = "mus_fork_" .. key, type = "story", trigger = "museum_fixed", fixed_actor = true, title = fk.title,
                       text = (split and "They can't agree. " or "They've more or less decided, but ")
                           .. util.fill(night:fresh(M.WEEKLY.ask_look, "weekly_ask_look"), { name = asker.name })
                           .. ": \"Where would you go?\"", options = {} }
        for i in ipairs(choices) do
            local names = {}
            for _, p in ipairs(voters) do
                if first[p.key] == i then
                    table.insert(names, p.name)
                end
            end
            local note = ""
            local ch = choices[i]
            if not ch.back and not ch.side then
                local r = MODULE.rooms[ch.id]
                note = (r.cost == 0 and "") or ((pm and pm.prepped and pm.prepped[ch.id]) and " You prepped it." or " Not prepped.")
                if r.stop and ch.id == "stairs" then
                    note = note .. " The night stops at the top step."
                end
            end
            local against = i ~= top or tied > 1
            table.insert(card.options, { label = "Nudge them: " .. label_of(i), choice = i,
                sub = (#names > 0 and (util.join_names(names) .. (#names == 1 and " wants this." or " want this.")) or "Nobody's for this yet.") .. note,
                effects = { { "all", trust = (against and (night.mus.steered or 0) >= 1) and -1 or 0 } },
                log = "\"If it were me? " .. util.capitalize(said_of(i)) .. ".\"" })
        end
        if hint_id then
            local what = {}
            for _, mid in ipairs(adventure.missed(c, hint_id)) do
                for _, m in ipairs(MODULE.moments) do
                    if m.id == mid then
                        table.insert(what, util.lower_first(util.sentence_case(util.fill(m.title or mid, night:vars(night.mus_vars)))))
                    end
                end
            end
            table.insert(card.options, {
                label = "Hint they missed something in " .. util.lower_first(MODULE.rooms[hint_id].name),
                sub = "Still in there: " .. (#what > 0 and util.join_names(what) or "something they passed up") .. ".", sub_tone = "teal",
                effects = { { "arch:explorer", fun = 4 }, { "arch:butt_kicker", fun = -1 } },
                log = "\"You know, you never did look properly at " .. util.lower_first(MODULE.rooms[hint_id].name)
                    .. ".\" Someone groans. Someone grabs their pencil.",
                hint = hint_id })
            night.mus.hint_offered = true
        end
        table.insert(card.options, { label = "\"It's up to you.\"", leave = true,
            sub = "They settle it themselves.", effects = { { "arch:storyteller", fun = 1 } },
            log = "You shrug behind the screen. \"You tell me.\"" })
        local was_a = night.actor
        night.actor = asker
        o = night:decision(card)
        night.actor = was_a
        if o and o.hint then
            night.mus.hinted = true
            st.hinted[o.hint] = true
            -- (Against a table that had already agreed, a hint is a suggestion: somebody grumbles,
            -- and the curious ones decide whether it's worth it. F18: a unanimous table turned
            -- round on a hint without a word.)
            local follow = true
            if not split then
                local grumbler
                for _, p in ipairs(voters) do
                    if first[p.key] == top and (not grumbler or vals[p.key][top].v > vals[grumbler.key][top].v) then
                        grumbler = p
                    end
                end
                if grumbler then
                    night:emit({ kind = "say", who = grumbler.key, text = util.fill(night:fresh(M.WEEKLY.grumble, "weekly_grumble"), { way = said_of(top), Way = util.capitalize(said_of(top)) }), ic = false })
                    night:react({ [grumbler.key] = "arms" })
                end
                local curious = 0
                for _, p in ipairs(voters) do
                    if p.primary == "explorer" or p.primary == "storyteller" or p.secondary == "explorer" then
                        curious = curious + 1
                    end
                end
                follow = curious > #voters / 2 or (curious * 2 == #voters and night.rng:chance(0.5))
                if not follow then
                    night:say(util.fill(night:fresh(M.WEEKLY.go_on, "weekly_go_on"), { way = said_of(top) }), "aside")
                end
            end
            if follow then
                st.hints[o.hint] = true
                if not split then
                    night:say("The table decides: back to " .. util.lower_first(MODULE.rooms[o.hint].name) .. " (on your hint).", "aside")
                end
                return { back = { id = o.hint, why = "hint", steps = (select(2, adventure.reachable(c, pos)))[o.hint] or 1 } }
            end
        end
        if o and o.choice then
            -- (Credit for the nudge only when there was a split to settle: "on your nudge" over a
            -- table that already all wanted to go, F18.)
            night.mus.nudged_to = split and o.choice or nil
            -- Asked, most take the hint; someone who really wanted the other way minds a little.
            local against = o.choice ~= top or tied > 1
            for _, p in ipairs(voters) do
                if first[p.key] ~= o.choice then
                    if vals[p.key][first[p.key]].v - vals[p.key][o.choice].v < 3.5 then
                        first[p.key] = o.choice
                    else
                        score.add(p, "fun", -1)
                        night.mus.overruled = night.mus.overruled or {}
                        night.mus.overruled[p.key] = (night.mus.overruled[p.key] or 0) + 1
                    end
                end
            end
            if against then
                night.mus.steered = (night.mus.steered or 0) + 1
                if night.mus.steered >= 2 then
                    local times = ({ "Twice", "Three times", "Four times" })[night.mus.steered - 1] or (util.int(night.mus.steered) .. " times")
                    night:say(times .. " tonight you've steered them. It's starting to feel like a railroad.", "warn")
                end
            end
            top, top_n, tied = tally()
            if tied > 1 then
                top = o.choice
            end
        end
    end
    -- Still tied: whoever's keenest settles it.
    if tied > 1 then
        local keen, kv
        for _, p in ipairs(voters) do
            local v = vals[p.key][first[p.key]].v
            if not kv or v > kv then
                keen, kv = p, v
            end
        end
        top = first[keen.key]
        night:emit({ kind = "say", who = keen.key, text = "Okay, I'm calling it: " .. said_of(top) .. ".", ic = false })
    end
    do
        local names = {}
        for _, p in ipairs(voters) do
            if first[p.key] == top then
                table.insert(names, p.name)
            end
        end
        -- (Your nudge settled it: say so, not that they all thought of it themselves.)
        local nudged = night.mus.nudged_to == top
        night.mus.nudged_to = nil
        night:say("The table decides: " .. said_of(top) .. (nudged and " (on your nudge)" or ((#names > 0 and #names < #voters)
            and (" (" .. util.join_names(names) .. "'s pick)")) or "") .. ".", "aside")
        -- (Whoever just got their way can't say "I gave way last time" at the next vote. The engine run,
        -- 8_14: Sam "gave way" right under his own pick.)
        local adv = c.adv
        if adv and adv.votes and adv.votes.lost then
            for _, p in ipairs(night.players) do
                if first[p.key] == top and adv.votes.lost[p.key] then
                    adv.votes.lost[p.key] = nil
                    adv.votes.lost_to = nil
                end
            end
        end
    end
    local ch = choices[top] or choices[1]
    -- The friend who runs off (the BBQ story): the instigator, outvoted, heads for the stairs alone.
    local jess = present(night, "jess")
    if not ch.back and not ch.side and ch.id == "stairs" and jess and not st.flags.seen and night.rng:chance(0.6) then
        st.flags.pip_alone = true
        thoughts.plan(night, jess, first[jess.key] ~= top)      -- a beat before she goes: what she's thinking, if you catch it
    end
    if ch.side then
        return { side = ch.side }
    end
    if ch.back then
        return { back = ch.back }
    end
    M.whats_there(night, ch.id)
    return { id = ch.id }
end

-- What's really through the door they picked is the DM's (the playtest, November 3: "once they
-- decide, the DM should have a moment to decide what is ACTUALLY in the direction they're going:
-- what is planned, improv, or move another encounter there"). Asked only for a room you didn't prep:
-- read it from the book while they wait, improvise it short, or move the prep you did for a room they
-- haven't reached here (that room plays unprepped, if they ever get there).
function M.whats_there(night, id)
    local st = st_of(night)
    local pm = night.prep and night.prep.museum
    local r = MODULE.rooms[id]
    night.mus.improv = night.mus.improv or {}
    if not (pm and r and (r.cost or 0) > 0 and not r.virtual and not pm.prepped[id] and not night.mus.improv[id]) then
        return
    end
    local donor
    for _, did in ipairs(pm.ahead or {}) do
        if did ~= id and pm.prepped[did] and not st.done[did] and not st.skipped[did] and not (night.mus.been or {})[did] then
            donor = did
            break
        end
    end
    local name = util.lower_first(r.name)
    local card = { id = "mus_whats_there", type = "screen", trigger = "museum", title = "What's really there?",
                   text = "They're heading for " .. name .. ", and you didn't prep it. Behind the screen, it's your call what "
                       .. "they find.", options = {
        { label = "Read it from the book while they wait.", there = "book",
          sub = "The room as written. You skim the page at the table: a few minutes of dead air.",
          effects = { { "arch:tactician", fun = 1 } } },
        { label = "Improvise it: keep it short and sweet.", there = "improv",
          sub = "No skimming. The room's big moments, quickly; it lands a little thinner than prepped.",
          effects = { { "arch:storyteller", fun = 2 }, { "arch:method_actor", fun = 1 }, { "arch:tactician", fun = -1 } },
          book_down = true },
    } }
    if donor then
        table.insert(card.options, { label = "Move your prep for " .. util.lower_first(MODULE.rooms[donor].name) .. " here.", there = "move",
            sub = "Your notes and minis work here as well. " .. MODULE.rooms[donor].name .. " plays unprepped, if they ever get there.",
            effects = { { "arch:tactician", fun = 1 } },
            log = "You slide your notes for " .. util.lower_first(MODULE.rooms[donor].name) .. " across. Nobody needs to know." })
    end
    local o = night:decision(card)
    if o and o.book_down then
        night:say(night:fresh(M.WEEKLY.book_down, "weekly_book_down"), "dm")      -- (only the line that's said is remembered)
    end
    if o and o.there == "book" then
        night.mus.from_book = night.mus.from_book or {}
        night.mus.from_book[id] = true
    end
    if o and o.there == "improv" then
        night.mus.improv[id] = true
    elseif o and o.there == "move" and donor then
        pm.prepped[donor] = nil
        pm.prepped[id] = true
        night.mus.moved_prep = { from = donor, to = id }
    end
end

-- A trip back to a room they've cleared: a short scene there, no fight (what was there is dealt
-- with), whatever brought them back, and on. A room they walked past plays in full instead.
function M.go_back(night, b)
    local c = night.campaign
    local st = st_of(night)
    night.mus.backs = (night.mus.backs or 0) + 1
    night.mus.been = night.mus.been or {}
    night.mus.been[b.id] = true
    local r = MODULE.rooms[b.id]
    if b.why == "passed" then
        night:say("Back down they go, for " .. util.lower_first(r.name) .. ". They walked right past it.", "dm")
        night.table_min = night.table_min + 6
        return M.play(night, b.id)
    end
    st.pos = b.id
    st.last_room = b.id
    local sc = M.build_scene(night, b.id)
    sc.revisit = b.why
    -- (In the log: a trip back has its reason. They fled a fight they lost; they went to rest after
    -- one; they went to spend what they'd found.)
    do
        local name = util.lower_first(r.name)
        local from, how, text = nil, nil, events.word("back", { room = name })
        if b.why == "flee" then
            from, how, text = events.last(c, { kind = "fight", outcome = "lost" }), "but", events.word("flee", { room = name })
        elseif b.why == "rest" then
            from, text = events.last(c, { kind = "fight", session = c.week }), events.word("rest", { room = name })
        elseif b.why == "shop" then
            from, text = events.last(c, { kind = "find", session = c.week }), events.word("shop", { room = name })
        end
        local ev = M.log_beat(night, { kind = "enter", who = "party", where = b.id, back = b.why, from = from, how = from and (how or "therefore") or nil,
                                       text = text }, sc)
        sc.enter_ev = ev.id
    end
    local room_fight = sc.encounter
    sc.encounter, sc.optional_fight = nil, nil
    table.insert(night.scenes, sc)
    sc.index = #night.scenes
    night.mus.total = math.max(night.mus.total or 1, sc.index)
    M.stage(night, sc, r.name .. ", again")
    local walk = (b.steps or 1) > 1 and ("They cut back through the rooms they've cleared to " .. util.lower_first(r.name) .. ".")
        or ("Back to " .. util.lower_first(r.name) .. ".")
    night:say(walk, "dm")
    night.table_min = night.table_min + 4 + 2 * (b.steps or 1)
    if b.why == "missed" or b.why == "hint" then
        for _, mid in ipairs(adventure.missed(c, b.id)) do
            for _, m in ipairs(MODULE.moments) do
                if m.id == mid and not night.end_early then
                    M.play_moment(night, m, sc)
                end
            end
        end
        st.hints[b.id] = nil
        st.looked[b.id] = true      -- (one second look per room: whatever they pass up now stays)
        -- A second look that wakes what's there (a hand on the donation box, the guard right there):
        -- then there's a fight after all.
        if sc.fight_on and room_fight and not night.end_early then
            sc.encounter = room_fight
            sc.fought = true
            night:combat_scene(sc)
            sc.outcome = sc.result and (sc.result.winner == "party" and "win" or "lose") or "win"
        end
    elseif b.why == "shop" or b.why == "rest" or b.why == "flee" then
        -- (What's come true here since they last stood in it: the vorpal sword on Telpur's shelf.)
        if b.why ~= "flee" and not night.end_early then
            M.callbacks(night, sc)
        end
        if b.why == "shop" then
            night.mus.shopped = true
            for _, m in ipairs(MODULE.moments) do
                if m.room == b.id and m.id == "mus_shopping" and not night.end_early then
                    M.play_moment(night, m, sc)
                end
            end
        end
        if not night.end_early and (b.why ~= "shop" or hurt(night) > 0.2) then
            night:say(b.why == "flee" and "They slam the door behind them and catch their breath: a short rest."
                or "They sit down among the souvenirs and catch their breath: a short rest.", "aside")
            if not night.pc_list then
                require("game.model.fight").party(night)
            end
            night:do_rest("short", "town")
        end
        -- (A breather is a quiet stretch: the room's small business, and the friends' own ideas, when
        -- there's time for them, or when you asked for one more room and this is it. F17.)
        if b.why ~= "flee" and not night.end_early then
            M.quiet_stretch(night, sc)
        end
    end
    sc.outcome = sc.outcome or "win"
    sc.had_roll = true
    if not night.end_early then
        night:emit({ kind = "scene_end", index = sc.index, title = sc.title, outcome = sc.outcome, fight = sc.fought or nil,
                     call = night:scene_call(sc) })
    end
    table.insert(night.mus.rooms, { room = b.id, outcome = sc.outcome, back = b.why })
    M.interlude(night, sc)
    return sc
end

-- A fight lost in a room: they get out, back to the nearest room they've cleared (the gift shop if
-- it's close), and patch themselves up. The room counts as got through, roughly.
function M.flee(night, sc)
    local c = night.campaign
    local st = st_of(night)
    if night.end_early or (night.mus.backs or 0) >= M.MAX_BACKS + 1 then
        return
    end
    local _, cleared = adventure.reachable(c, sc.room)
    local best, bs
    for _, id in ipairs(MODULE.order) do
        local steps = cleared[id]
        if steps and not MODULE.rooms[id].virtual then
            local v = steps - ((id == "gift_shop" and steps <= 2) and 2 or 0)
            if not bs or v < bs then
                best, bs = id, v
            end
        end
    end
    if not best then
        return
    end
    night:say("Nobody wants to stay. They fall back to " .. util.lower_first(MODULE.rooms[best].name) .. ", fast.", "bad")
    M.go_back(night, { id = best, why = "flee", steps = cleared[best] })
end

-- After a room: what it left behind, and Euryale upstairs ------------------------------------------

-- How many of a room's foes got away (any way: their nerve broke, you let them go, the fight
-- broke up): every one of them is somewhere upstairs now.
local function fled_count(sc)
    return sc.foes_ran and #sc.foes_ran or 0
end

function M.after_room(night, sc)
    local c = night.campaign
    local st = st_of(night)
    local id = sc.room
    local outcome = sc.outcome or "win"
    -- (What the room leaves behind follows from how it went: its fight, or the card that settled it. Not
    -- from whatever moment came last: "a voice whispered to Thessaly, so she came away with the
    -- notebook" was the room's own find, said as if the whisper brought it. R14.)
    local prev_cause = events.cause(c)
    events.set_cause(c, sc.fight_ev or sc.resolve_ev)
    local function mark(m, holder)
        if adventure.add_mark(c, m, id, holder) then
            table.insert(night.mus.pending, m)
            return true
        end
    end
    -- (Whoever picks something up is said out loud, and it's in their pack: one owner.)
    local function picked_up(what, p)
        if p then
            night:say(util.fill(night:fresh(M.WORLD_LINES[what], "pickup_" .. what), night:vars({ char = p.char })), "narration")
        end
    end
    if id == "garden" and sc.fought and (outcome ~= "win" or fled_count(sc) > 0) then
        mark("topiary")          -- (a hedge-beast still standing, or one that ran: it's at her couch now)
    elseif id == "paintings" and sc.fought and fled_count(sc) > 0 then
        mark("knight")           -- (the knight they let go climbs back into a frame, upstairs)
    elseif id == "chamber" and sc.fought and util.contains(sc.foes_beaten or {}, "bone_construct") then
        mark("scarabs")          -- (they smashed it: its scarabs crawl out and upstairs; not if it beat them)
    elseif id == "hunting" then
        local n = fled_count(sc)
        if n > 0 then
            st.pack = n
            mark("pack")
        end
    elseif id == "lecture" then
        if outcome == "win" then
            -- (Silenced, he isn't droning through anyone's floor any more.)
            if c.adv.marks.drone then
                adventure.remove_mark(c, "drone")
                night:say("Upstairs, the drone through the floor stops. Euryale notices the quiet.", "interlude")
            end
            -- (Not if he got away: he took his notes with him. Round three, B16.)
            -- (The pages go to whoever's best with a page of the heroes there, and the table sees it.)
            if not sc.boss_ran then
                local reader, rm = M.first_pick(night), nil
                for _, p in ipairs(reader and {} or night:at_hand()) do
                    local _, m = night:best_skill(p, { "investigation", "history" })
                    if m and (not rm or m > rm) then
                        reader, rm = p, m
                    end
                end
                if mark("pages", reader and reader.key) then
                    picked_up("pages", reader)
                end
            end
        else
            mark("drone")
        end
    elseif id == "offices" and outcome == "win" then
        st.flags.notebook = true
        -- (Somebody takes it off the desk: the one who wants it most, items.lua's `to`. It's on the desk
        -- in the second study, so it follows from the way in: the door they opened.)
        local items_mod = require "game.model.items"
        if not items_mod.owned(c, "notebook") then
            events.set_cause(c, events.last(c, { kind = { moment = true, setback = true }, flag = "door_open", session = c.week })
                or events.last(c, { kind = { moment = true, setback = true }, flag2 = "door_open", session = c.week }))
            -- (Whoever took the second study in takes it off the desk: round three, "Thessaly came away
            -- with the notebook" when Oswin read it.)
            local inside = events.last(c, { kind = "moment", card = "mus_office_inside", session = c.week })
            local taker = M.first_pick(night)
            for _, p in ipairs(taker and {} or night:at_hand()) do
                if inside and p.key == inside.who then
                    taker = p
                end
            end
            if items_mod.give(c, "notebook", taker and taker.key or nil, "found") then
                local it, key = items_mod.holding(c, "notebook")
                picked_up("notebook", key and present(night, key))
            end
        end
    end
    -- (What else the room's end brings, the DM's ties and her thoughts, follows from none of this.)
    events.set_cause(c, nil)
    table.insert(night.mus.rooms, { room = id, outcome = outcome })
    adventure.leave_room(c, id, outcome, c.week, sc.fought and true or nil)
    -- What they came away with, in words that match what happened (the goal's got_if), for the
    -- story so far: not "the truth about the Gorgon" when they never heard it.
    local goal = sc.comps and sc.comps.goal
    local step = st.path[#st.path]
    if goal and step and step.room == id then
        for _, alt in ipairs(goal.got_if or {}) do
            if alt_holds(night, sc, alt) then
                step.got = alt.text
                break
            end
        end
    end
    M.ties_beat(night, sc)
    M.interlude(night, sc)
    events.set_cause(c, prev_cause)
end

-- One of the museum's people sees their own stock in a hero's hands (round three: Telpur sold the quiver
-- Pip had lifted back to them, and rode on the pack strap while she handed it round, and said nothing):
-- he says so, it's a beat in the log (from the theft), and he knows it from now on (people.spots).
local SPOT_NAME = { mus_telpur = "Telpur" }
function M.owner_sees(night, person, sc)
    local c = night.campaign
    local here = {}
    for _, p in ipairs(night:at_hand()) do
        here[p.key] = true
    end
    -- (Not in the same room the same night it went: "nobody the wiser" has to hold for a while.)
    local ev, it = people.spots(c, person, here, function(e)
        return (e.session or 0) < (c.week or 0) or e.where ~= (sc and sc.room)
    end)
    if not ev then
        return nil
    end
    local p = present(night, it.holder)
    local line = people.line(night, person, "spots", p, { char = p.char })
    if line then
        night:emit({ kind = "npc", name = SPOT_NAME[person] or person, cast = person, text = line })
    end
    local t = require("game.model.items").thing(it.thing or it.id)
    local what = t and string.gsub(util.lower_first(t.name or t.title or "stock"), ", lifted$", "") or "stock"
    what = string.gsub(what, "^a quiver of ", "")
    M.log_beat(night, { kind = "notice", who = person, whom = it.holder, thing = it.thing, from = ev.id,
                        text = events.word("spotted", { who = SPOT_NAME[person] or person, thing = what, char = p.char }) }, sc)
    return ev
end

-- First pick of the next find (the friends' promise, night.lua bond_act: st.first_pick): when the party
-- finds something, it's theirs, if they're here and can use it (can: a test, for a magic item), and
-- the table hears the promise kept. Returns the player, or nil.
function M.first_pick(night, can)
    local st = st_of(night)
    local fp = st.first_pick
    if not fp then
        return nil
    end
    local to, by
    for _, p in ipairs(night:at_hand()) do
        if p.key == fp.to then
            to = p
        end
    end
    by = present(night, fp.by)
    if not to or (can and not can(to)) then
        return nil
    end
    st.first_pick = nil
    events.add(night.campaign, { kind = "promise", who = fp.by, whom = fp.to, kept = true, where = night.scene and night.scene.room })
    night:say(util.fill(night:fresh(M.WORLD_LINES.first_pick, "first_pick"),
        { by = by and by.name or "Everyone", by_char = by and by.char or "everyone", to_char = to.char }), "good")
    return to
end

-- What the week between handed over, said as the night starts: a thing someone gave a hero (its
-- `handover` words, to whoever has it: items.lua), and Francs someone pressed on them.
local GIVER = { mus_flitwidget = "Flitwidget", mus_telpur = "Telpur" }
function M.between_gifts(night)
    local c = night.campaign
    local st = st_of(night)
    local items_mod = require "game.model.items"
    for _, it in ipairs(items_mod.list(c)) do
        local t = it.thing and items_mod.thing(it.thing)
        local p = it.holder and present(night, it.holder)
        if t and t.handover and it.from == "given" and not it.shown and p and not it.gone then
            it.shown = c.week
            night:say(util.fill(night:fresh(t.handover, "handover_" .. t.id), { holder = p.char }), "recap")
        end
    end
    for _, f in ipairs(st.between_francs or {}) do
        night:say(util.fill(night:fresh(M.WORLD_LINES.between_francs, "between_francs"),
            { who = GIVER[f.whom or ""] or "Flitwidget", n = adventure.gold_word(f.n), pool = util.int(st.francs or 0) }), "recap")
    end
    st.between_francs = nil
end

-- The cut upstairs: Euryale's thought as each new mark lands on her card.
function M.interlude(night, sc)
    local pending = night.mus.pending
    if #pending == 0 then
        return
    end
    night.mus.pending = {}
    for _, id in ipairs(pending) do
        local m = MODULE.marks[id]
        if m and night.campaign.adv.marks[id] then
            local thought = adventure.mark_thought(night.campaign, id)
            night:emit({ kind = "mark", id = id, name = m.name, why = adventure.mark_why(night.campaign, id),
                         showdown = adventure.mark_showdown(night.campaign, id), thought = thought })
            night:say("Upstairs, Euryale: \"" .. thought .. "\"", "interlude")
            table.insert(night.mus.added, id)
        end
    end
end

-- The night ---------------------------------------------------------------------------------------

function M.intro(night)
    local c = night.campaign
    local st = st_of(night)
    local who = {}
    for _, p in ipairs(night.players) do
        table.insert(who, p)
    end
    night.rng:shuffle(who)
    for i = 1, math.min(2, #who) do
        night:bark(who[i], "arrive")
    end
    night:dice_moment()
    require("game.model.keepsakes").at_night(night)
    night:say(night:fresh(M.WEEKLY.ready, "weekly_ready"), "system")
    night:table_behavior("start")
    require("game.model.companions").night_start(night)      -- (Exhibit B says hi: companions.lua)
    local first = adventure.frontier(c)[1]
    local part = first and MODULE.rooms[first] and MODULE.rooms[first].part or 1
    if (st.weeks or 0) <= 1 then
        night:emit({ kind = "cinematic", id = "opening", slides = {
            { title = MODULE.title, text = "A one-shot prologue: a gnome's travelling museum, and the Gorgon who took it over." },
            { title = "Tonight", text = MODULE.openings[1] },
        } })
        night:say(MODULE.openings[1], "opening")
        require("game.model.intros").run(night)
    else
        -- What last session came to, in a sentence: its rooms, in order, as clauses.
        local bits, last_week = {}, nil
        for i = #st.path, 1, -1 do
            local step = st.path[i]
            last_week = last_week or step.week
            if step.week ~= last_week then
                break
            end
            local clause = adventure.recap_clause(c, step)
            if clause and not util.contains(bits, clause) then
                table.insert(bits, 1, clause)
            end
        end
        -- (What it cost them first: a death, a wipe, an ally lost, who went down. Round three, A7.)
        local lost = last_week and events.losses(c, last_week) or {}
        if #lost > 0 then
            night:say("Last time, " .. util.join_names(lost) .. ".", "recap")
            if #bits > 0 then
                night:say("They " .. util.join_names(bits) .. ".", "recap")
            end
        elseif #bits > 0 then
            night:say("Last time, they " .. util.join_names(bits) .. ".", "recap")
        end
        if night.campaign.last_cliff then
            night:say("They stopped mid-museum, with " .. night.campaign.last_cliff .. " still ahead.", "recap")
        end
        local last = st.last_room and MODULE.rooms[st.last_room]
        if last and last.part ~= part then
            -- (Where they stopped decides the words: the gift shop door only if they were in it.)
            local from = MODULE.openings_from and MODULE.openings_from[st.last_room]
            night:say((from and from[part]) or MODULE.openings[part] or MODULE.openings[1], "opening")
        elseif first and MODULE.rooms[first] then
            local fr = adventure.frontier(c)
            if #fr > 1 then
                local names = {}
                for _, id in ipairs(fr) do
                    table.insert(names, util.lower_first(MODULE.rooms[id].name))
                end
                night:say("They pick up where they stopped, at a fork: " .. util.join_names(names, "or") .. ".", "opening")
            else
                night:say("They pick up right where they stopped: " .. util.lower_first(MODULE.rooms[first].name) .. ".", "opening")
            end
        else
            night:say("They pick up right where they stopped, at a fork in the museum.", "opening")
        end
        -- A new hero at the table, in a fallen one's place: who they are, before the first room.
        require("game.model.death").intro(night)
        -- What the week between decided, out loud: a rest they were promised, and anything that went
        -- on Euryale's card in the group chat (her line as each one lands).
        if st.flags.rested and not st.rest_given then
            st.rest_given = c.week
            if c.party_state then
                c.party_state.rested = true
                c.party_state.fights_since_long = 0
            end
            if not night.pc_list then
                fight.party(night)          -- (fresh from the rest: the morning's buffs go up now)
            end
            -- (Where they rest is the gift shop, the one safe place to sleep; where they start is where they
            -- stopped. The second playtest review: "a long rest in the gift shop", then "Out of the World of
            -- Tomorrow".)
            local here = st.pos or st.last_room
            local in_shop = here == nil or here == "gift_shop"
            -- "...and wake to find a statue at the foot of the stairs": there it is, on the gift shop's
            -- board (F12: the chat's statue never appeared), said where they woke, before they walk back
            -- up to where they stopped (wave 1's leftover: it was told after the walk).
            local statue = (st.answered or {}).long_rest == "danger" and not st.flags.stairs_statue
            if statue then
                st.flags.stairs_statue = M.place_statue(c) and true or nil
            end
            local back = (not in_shop) and (here == "stairs" and "the top of the stairs" or util.lower_first(MODULE.rooms[here].name)) or nil
            local line
            if in_shop then
                line = "As promised in the group chat: they start tonight after a long rest in the gift shop, fully healed, every spell back."
            elseif statue then
                line = "As promised in the group chat: they start tonight after a long rest in the gift shop. They wake to find, just as you "
                    .. "told them, a statue that wasn't there last night at the foot of its stairs, its stone hand reaching for the first "
                    .. "step. Then a walk back up to " .. back .. ", where they stopped. Fully healed, every spell back."
            else
                line = "As promised in the group chat: they start tonight after a long rest in the gift shop, and a walk back up to "
                    .. back .. ", where they stopped. Fully healed, every spell back."
            end
            night:say(line .. fight.buff_line(night), "recap")
            if statue and in_shop then
                night:say("And there it is, just as you told them: at the foot of the gift shop's stairs, a statue that wasn't there last night."
                    .. " Its stone hand is reaching for the first step.", "narration")
            end
        end
        -- What was handed over between sessions, shown being handed over (round three: "Flitwidget's
        -- bracelet is on a wrist", and nobody saw him give it; Francs on the board nobody heard of).
        M.between_gifts(night)
        if st.unannounced and #st.unannounced > 0 then
            for _, id in ipairs(st.unannounced) do
                table.insert(night.mus.pending, id)
                -- (A mark someone else put there between sessions, said as theirs before her line: "Flitwidget
                -- woke the Steam Mech himself". The confirming playtest: Hans clanked up the stairs, and
                -- nobody had said how he woke.)
                local by = st.marks[id] and adventure.mark_words(c, id)
                if by and by.told then
                    night:say(util.fill(night:fresh(by.told, "mark_told_" .. id), { mech = st.mech_name or "the Mech" }), "recap")
                end
            end
            st.unannounced = nil
            M.interlude(night)
        end
    end
    night:say(night:fresh(MODULE.thoughts.open, "euryale_open"), "interlude")
end

-- The statue the group chat promised (the rest answered "yes, but it's dangerous"): a stone piece at
-- the foot of the gift shop's stairs, on its board for every scene there from now on.
M.STATUE_AT = { { 15, 8 }, { 16, 9 }, { 15, 9 }, { 15, 7 }, { 17, 9 } }
function M.place_statue(c)
    local maps = require "game.model.maps"
    local loc = content.components["mus_gift_shop"]
    if not loc then
        return false
    end
    local m = maps.get(c, loc.id) or maps.new(c, loc.id, maps.template(c, loc, "downtime"))
    for _, sq in ipairs(M.STATUE_AT) do
        if maps.place(m, "statue_victim_c", sq[1], sq[2], 1) then
            return true
        end
    end
    return false
end

-- Ending the session is always the DM's call (the playtest, November 3: "sessions should never
-- automatically end"): the End session button on game night, or "call it here" when it's getting
-- late. Where you stop matters: on a cliffhanger they love it, after a big fight it's a good place to
-- stop, in a lull it falls flat; early hurts a little now (and starting the big scene fresh next
-- week pays later), late makes everyone tired. Returns how it read: "cliff", "fight", "flat".
local function stop_kind(night, nxt)
    local last = night.mus.last
    -- (After a wipe or a death, it's a rough place to stop, not "high fives all round": round three, A6.)
    if able.somber(night) then
        return "loss"
    end
    if nxt and (nxt.boss or nxt.stop) then
        return "cliff"
    end
    if last and last.fought then
        return "fight"
    end
    return "flat"
end
M.stop_kind = stop_kind

function M.stop_note(night, nxt)
    local k = stop_kind(night, nxt)
    local planned = night.table_planned or 210
    local early = (night.table_min or 0) < planned - 45
    local late = (night.table_min or 0) > planned + 15
    local bits = {}
    if k == "loss" then
        table.insert(bits, "A rough place to stop: nobody's in the mood for one more room after that.")
    elseif k == "cliff" then
        table.insert(bits, "A cliffhanger: " .. util.lower_first(nxt.name) .. " is right there. They'll love it.")
    elseif k == "fight" then
        table.insert(bits, "A good place to stop: they've just come out of a fight.")
    else
        table.insert(bits, "A flat place to stop: nothing much happened in the last room.")
    end
    if early then
        table.insert(bits, (nxt and (nxt.boss or nxt.type == "combat"))
            and "Early, but starting the big one fresh next week will pay off." or "Early: they'd hoped to play longer.")
    elseif late then
        table.insert(bits, "It's late: they're tired.")
    end
    return table.concat(bits, " ")
end

function M.end_session(night, nxt)
    local c = night.campaign
    local k = stop_kind(night, nxt)
    local planned = night.table_planned or 210
    local early = (night.table_min or 0) < planned - 45
    local late = (night.table_min or 0) > planned + 15
    night.end_early = true
    night.dm_ended = k
    if nxt then
        c.last_cliff = util.lower_first(nxt.name)
    end
    night.ended_on_cliff = (k == "cliff") or nil
    night:say(night:fresh(M.WEEKLY.close, "weekly_close"), "dm")
    if k == "loss" then
        night:say(night:fresh(M.WEEKLY.stop_loss, "weekly_stop_loss"), "aside")
    elseif k == "cliff" then
        night:say("Groans round the table, the good kind. Nobody wants to wait a week for " .. util.lower_first(nxt.name) .. ".", "good")
        night:apply({ { "all", fun = 3 }, { "arch:storyteller", fun = 2 }, { "arch:instigator", fun = 2 } })
    elseif k == "fight" then
        night:say(night:fresh(M.WEEKLY.stop_fight, "weekly_stop_fight"), "good")
        night:apply({ { "all", fun = 2 } })
    else
        night:say(night:fresh(M.WEEKLY.stop_flat, "weekly_stop_flat"), "aside")
        night:apply({ { "all", fun = -1 }, { "arch:butt_kicker", fun = -1 } })
    end
    if early then
        night:apply({ { "all", commitment = -1 } })
        if nxt and (nxt.boss or nxt.type == "combat") then
            c.adv.fresh_start = c.week          -- (next week starts with the big one, and a full evening for it)
        end
    elseif late then
        night:apply({ { "arch:casual", fun = -2 }, { "all", boredom = 2 } })
    end
    -- (Every room after this waits for next week.)
    night.cliff_stop = true
end

-- A first night that already had its one more room ends there (R6: a gentler first night; a DM who
-- kept saying "one more" made night 1 as busy as any other).
M.GENTLE_STOP = {
    "It's a first night, and it's late: the table calls it here.",
    "First nights run short. Everyone agrees to stop here.",
    "\"Let's leave it there for a first night.\" Nobody argues.",
}

-- It's getting late: the DM's call, wrap up or one more room. Returns true when you called it.
function M.ask_wrap(night, nxt)
    local planned = night.table_planned or 210
    if night.gentle and night.one_more then
        night:say(night:fresh(M.GENTLE_STOP, "gentle_stop"), "aside")
        M.end_session(night, nxt)
        return true
    end
    night.mus.wrap_asks = (night.mus.wrap_asks or 0) + 1
    local late = (night.table_min or 0) > planned
    local card = { id = "mus_wrap", type = "table", trigger = "museum", title = late and "It's late" or "It's getting late",
                   text = "It's " .. night:clock_text() .. ". " .. (late and "Past the time you said you'd finish. " or "")
                       .. "Wrap up here, or one more room?", options = {
        { label = "Call it here.", wrap = true, sub = M.stop_note(night, nxt), effects = {} },
        { label = "One more room.", sub = late and "Everyone's tired, and it'll run later still." or "It'll run a little past the time you said.",
          effects = late and { { "all", boredom = 2 }, { "arch:casual", fun = -1 }, { "arch:butt_kicker", fun = 1 } } or {} },
    } }
    local o = night:decision(card)
    if o and o.wrap then
        M.end_session(night, nxt)
        return true
    end
    -- (You chose to play on: the room that follows is a real scene, even a short one. The second
    -- playtest review: "One more room" was one line about the stairs, then goodbyes.)
    night.one_more = true
    return false
end

-- Into a room: anything that leaves behind for good marks her card (the lair, for rooms unseen).
function M.enter(night, id)
    local c = night.campaign
    local lb_marks = MODULE.rooms[id].boss and adventure.left_behind(c) or {}
    -- (What they left behind downstairs, a room they never saw, follows from nothing they did: R14. The
    -- last beat of the night was linked here, so "they climbed the stairs, so the knight went to wait".)
    if #lb_marks > 0 then
        events.set_cause(c, nil)
    end
    local left = adventure.enter_room(c, id, c.week)
    for _, lb in ipairs(lb_marks) do
        if adventure.add_mark(c, lb.mark, lb.room) then
            table.insert(night.mus.pending, lb.mark)
        end
    end
    if #lb_marks > 0 then
        events.set_cause(c, nil)
    end
    return left
end

-- Why they walked in, in the log: a room a hero came to the museum for follows from their reason
-- (their hook, Session Zero); any other room is simply where they went next, with no link of its own.
local function hook_event(c, p)
    local h = adventure.hook(c, p.key)
    if not h then
        return nil
    end
    local ev = events.last(c, { kind = "hook", who = p.key, thing = h.id })
    if not ev then
        ev = events.add(c, { kind = "hook", who = p.key, thing = h.id, where = h.room or false, session = 0 })
    end
    return ev
end

function M.log_enter(night, id, sc)
    local c = night.campaign
    local r = MODULE.rooms[id]
    if r.virtual and not r.stop then
        return nil
    end
    local name = util.lower_first(r.name)
    local own = MODULE.beats and MODULE.beats.rooms and MODULE.beats.rooms[id]
    local text = own or events.word("enter", { room = name })
    local from
    for _, p in ipairs(adventure.hooked(c, id)) do
        if not from and present(night, p.key) then
            from = hook_event(c, p)
            text = events.word("hooked", { enter = text, char = p.char })
        end
    end
    local ev = M.log_beat(night, { kind = "enter", who = "party", where = id, from = from, text = text }, sc)
    if sc then
        sc.enter_ev = ev.id
    end
    return ev
end

function M.play(night, id)
    local c = night.campaign
    local st = st_of(night)
    M.enter(night, id)
    local sc = M.build_scene(night, id)
    table.insert(night.scenes, sc)
    sc.index = #night.scenes
    M.log_enter(night, id, sc)
    local fun_in = {}
    for _, p in ipairs(night.players) do
        fun_in[p.key] = score.fun(p)
    end
    local ledger_in = #(night.ledger or {})
    night.mus.total = math.max(night.mus.total or 1, sc.index)
    if sc.quick or sc.virtual then
        M.quick_room(night, sc)
    else
        night:play_scene(sc)
    end
    if not night.end_early then
        M.after_room(night, sc)
    end
    if sc.fought and sc.outcome == "lose" and not MODULE.rooms[id].boss then
        M.flee(night, sc)
    end
    if id == "stairs" then
        night:say("Upstairs, Euryale: \"" .. MODULE.thoughts.arrive .. "\"", "interlude")
    end
    st.last_room = id
    -- How the room went for each of them, for what they want next (M.fork).
    local deltas = {}
    for _, p in ipairs(night.players) do
        deltas[p.key] = score.fun(p) - (fun_in[p.key] or score.fun(p))
    end
    local downs = {}
    for k = ledger_in + 1, #(night.ledger or {}) do
        local e = night.ledger[k]
        if e.ev == "down" and e.who then
            downs[e.who] = true
        end
    end
    night.mus.last = { id = id, fought = sc.fought or false, deltas = deltas, downs = downs }
    return sc
end

function M.run(night)
    local c = night.campaign
    local st = st_of(night)
    st.weeks = (st.weeks or 0) + 1
    night.scenes = {}
    night.mus = { added = {}, pending = {}, rooms = {}, harsh_log = {}, francs_start = st.francs or 0, got = {} }
    local ahead = adventure.ahead(c)
    night.mus.total = math.max(1, #ahead)
    c.last_cliff = nil
    M.intro(night)
    -- (The first night's first thought waits until the first room has started: a newcomer met a
    -- friend's thought card before they'd seen anything. Round three, from batch D.)
    if night.gentle then
        night.mood_later = true
    else
        thoughts.mood(night)
    end
    -- Last week stopped early to give the big one a full evening (M.end_session): it pays now.
    if c.adv.fresh_start and c.adv.fresh_start == c.week - 1 then
        night:say("You stopped early last week so tonight could start with the big one. Everyone's here on time, dice out.", "good")
        night:apply({ { "all", fun = 4 } })
    end
    c.adv.fresh_start = nil
    -- The DM's ties: anything that came true between sessions opens or fires now, before a room.
    if ties.any(c) then
        M.ties_beat(night)
        M.interlude(night)
    end
    if adventure.boss_week(c) then
        M.boss_night(night)
    else
        for _ = 1, 12 do
            if night.end_early or night.cliff_stop then
                break
            end
            local options = adventure.frontier(c)
            local backs = M.second_looks(night)
            local sides = M.side_options(night)
            if #options == 0 and #backs == 0 and #sides == 0 then
                say_shut(night, st.pos or st.last_room)
                break
            end
            local nxt = MODULE.rooms[options[1] or (backs[1] or sides[1]).id]
            if nxt.boss then
                break
            end
            -- The End session button (game night's top bar): you call it, between rooms.
            if night.dm_end_requested and #night.scenes > 0 then
                M.end_session(night, #options == 1 and nxt or nil)
                break
            end
            -- Getting late: your call, never the clock's (the playtest, November 3). Asked before
            -- each room from here on.
            if #night.scenes > 0 and night.table_min > night.table_planned - M.STOP_BEFORE_END and #options > 0 then
                -- (Late, and the only way on is the stairs to her door: that's not one more room, it's the
                -- end of the night either way, so the night ends here. 569 random: "one more room" was the
                -- stairs and goodbyes.)
                local only_stairs = #options == 1 and options[1] == "stairs" and #backs == 0 and #sides == 0
                if only_stairs and night.table_min > night.table_planned then
                    M.end_session(night, nxt)
                    break
                end
                if M.ask_wrap(night, #options == 1 and nxt or nil) then
                    break
                end
            end
            -- A night doesn't open by going straight up the stairs while rooms are still waiting:
            -- that night would be the stairs and nothing else. (Up they go after the next room.)
            if #night.scenes == 0 and #options > 1 and util.contains(options, "stairs") then
                local keep = {}
                for _, oid in ipairs(options) do
                    if oid ~= "stairs" then
                        table.insert(keep, oid)
                    end
                end
                options = keep
            end
            local pick = { id = options[1] }
            if #options + #backs + #sides > 1 or #options == 0 then
                pick = M.fork(night, options, backs, sides)
            elseif st.pos or st.last_room then
                say_shut(night, st.pos or st.last_room)
            end
            if pick.side then
                M.side_room(night, pick.side)
            elseif pick.back then
                M.go_back(night, pick.back)
            else
                local id = pick.id
                local r = MODULE.rooms[id]
                -- The room that ends the night (the stairs: the boss is next week) comes after the
                -- break, however early: every session gets one (the playtest, November 3).
                if r.stop and #night.scenes > 0 and (id == "stairs" or #night.scenes + 1 >= 3
                    or night.table_min > night.table_planned * 0.55) then
                    M.maybe_break(night, true)
                end
                M.play(night, id)
                if r.stop and (id == "stairs" or #night.scenes >= 3 or night.table_min > night.table_planned * 0.55) then
                    -- (A night that ran long in this room and stops on it, before its break came round,
                    -- still takes the break before it ends: every night has one, F1.)
                    if not night.had_break and id ~= "stairs" then
                        M.maybe_break(night, true)
                    end
                    -- (Say so: a night that just stopped left the table wondering why.)
                    if id ~= "stairs" and not night.end_early then
                        night:say("It's a good place to stop. \"We'll pick it up here next week,\" you tell them, and nobody argues.", "dm")
                    end
                    break
                elseif r.stop then
                    night:say("They catch their breath, check their packs, and keep going.", "dm")
                end
            end
            if #night.scenes > 0 then
                night:clock_tells()
            end
            M.maybe_break(night)
        end
    end
    -- Anything that went on her card tonight and hasn't had her line yet (the night stopped
    -- before the room's end): she gets it now, before everyone goes home.
    M.interlude(night)
    M.lecturer_report(night)
    -- (Nobody went back to the gift shop tonight: the wake, before everyone goes home. Round three, B1.
    -- Where they rest, once they've found it; else right where they stopped, and the gift shop hears of it
    -- when they get there: the confirming playtest, 53 careful.)
    local st_end = st_of(night)
    local here = st_end.pos or st_end.last_room
    local away = not (st_end.done.gift_shop or here == "gift_shop") and here and MODULE.rooms[here]
    if require("game.model.death").hold_wake(night, away and util.lower_first(MODULE.rooms[here].name) or nil) and away then
        st_end.flags.wake_away = true
    end
    night:run_tail()
end

-- The Lecturer, droning above the gift shop and the second floor, hears what's done there, and
-- passes it on to Euryale upstairs (R11: "the Lecturer passes on what he saw"), every night he's still
-- lecturing. Silencing him stops it. The table hears it as a cut upstairs; it's in the log.
local NOISY = { ["break"] = true, steal = true, harm = true }
function M.lecturer_report(night)
    local c = night.campaign
    local st = st_of(night)
    if night.end_early and not night.cliff_stop then
        -- (A night that ended early still ends: the Lecturer reports all the same.)
    end
    -- (Silenced, he says nothing more; one who got away still has plenty to say upstairs. Round three, B16.)
    local escaped = events.any(c, { kind = "fight", where = "lecture", fate = "ran" })
    if (st.done.lecture == "win" and not escaped) or st.ending then
        return
    end
    local d = people.def("mus_lecturer")
    local rooms = {}
    for _, r in ipairs(d.sees or {}) do
        rooms[r] = true
    end
    for _, r in ipairs(d.hears or {}) do
        rooms[r] = true
    end
    -- (He hears what makes a noise: a shout of "thief", a smash. A pocket picked clean makes none.)
    for _, ev in ipairs(people.notice(c, "mus_lecturer", rooms, NOISY)) do
        if ev.kind == "steal" and ev.outcome ~= "caught" then
            ev.seen.mus_lecturer = nil
        end
    end
    local told = people.pass_on(c, "mus_lecturer", "mus_euryale", { kinds = NOISY })
    local first = told[1]
    local about = first and events.get(c, first.about)
    if about then
        local p = about.who and c.player and c:player(about.who)
        local what = util.fill((MODULE.people_about or {})[about.kind] or "the party", { char = p and p.char or "one of them" })
        local line = people.line(night, "mus_lecturer", "pass_on", nil, { what = what })
        if line then
            night:say(line, "interlude")
            first.beat = true
            first.text = events.word("lecturer", { what = what })
        end
    end
end

-- The break (the playtest, November 3: "a more pronounced 'let's take a break' moment; all sessions
-- should have at least one"). Once a night, between rooms, a little past a third of the evening:
-- pizza, stretching, phones out. You choose whether anything happens in the game meanwhile: a
-- short rest, a long one where it's safe, or the party reading up.
-- (Said a little differently each week: the same two lines every week, the review found.)
local BREAK_START = {
    "\"Okay, let's take a break.\" Chairs scrape back. Someone's already on the phone to the pizza place.",
    "\"Five minutes, everyone. Well, twenty.\" The snack bowl is empty, and Sam goes to refill it.",
    "\"Break time.\" Dev stretches until something pops. Jess is already in the kitchen.",
    "\"Let's stop there for a bit.\" Phones come out. Mara keeps writing in her notebook anyway.",
    "\"Breather, everyone.\" Jess opens a window. Mara stretches until her chair creaks.",
    "\"Let's pause it there.\" Jess does a lap of the kitchen. Dev follows the smell of toast.",
    "\"Twenty minutes.\" Somebody puts music on. Mara argues with it.",
}
local BREAK_END = {
    "Everyone settles back in. \"Right. Where were we?\"",
    "Pizza boxes stacked, dice back out. \"Okay. So. The museum.\"",
    "Everyone drifts back to the table. Someone reads the last line of their notes out loud.",
    "Chairs pulled back in. \"Recap, quick: where were we standing?\"",
    "Mugs refilled, crumbs swept off the map. \"Okay. Back in.\"",
    "Dev drums the table. \"Right. Museum. Go.\"",
    "Everyone finds their dice again. One of Sam's has rolled under the sofa.",
}
M.BREAK_START, M.BREAK_END = BREAK_START, BREAK_END   -- (for the Dialogue Desk)
-- The break on a night a hero died (able.somber): no pizza-place phone call, nobody "comes back warm".
-- start: the call; nothing: what the heroes did, when it's just a break; back: back at the table.
M.BREAK_SAD = {
    start = { "\"Let's take a break.\" Nobody argues. Chairs scrape back, quietly.",
              "\"Twenty minutes, everyone.\" Somebody fills the mugs. Nobody says much.",
              "\"Let's stop for a bit.\" Phones stay face down. Somebody opens a window." },
    nothing = { "Twenty quiet minutes. Somebody makes tea nobody drinks.",
                "A quiet break: a stretch, a glass of water, not much talk.",
                "Twenty minutes off. Somebody squeezes a shoulder on the way to the kitchen." },
    back = { "Everyone sits back down. It's quieter than before. \"Okay. Where were we?\"",
             "Chairs pulled back in, gently. \"Right. Let's keep going.\"",
             "Everyone drifts back to the table and picks up their dice without a word." },
}
-- The rest of what the table hears every week, three or more ways each (R3, the second playtest
-- review: "weekly lines are where players first notice the machine"): everyone sitting down, a
-- friend asking you, a hero finding what they came for, a room you skim, the way a night stops.
M.WEEKLY = {
    ready = { "Everyone's here. Dice out.", "Everyone's sat down. Dice out, sheets out.", "The whole table's here. Dice out.",
              "Snacks on the table, dice in hands. Everyone's here." },
    -- (a friend asking you, at a card the table can't settle: "{name} looks up from the map")
    ask_look = { "{name} looks up from the map", "{name} turns to you", "{name} glances over the screen at you",
                 "{name} taps the table and looks at you" },
    -- (a hero's reason for coming, right here)
    thread = { "{name} sits up. This is what {char} came to the museum for.", "{name} leans in. This is why {char} is here.",
               "{name} goes very still. This is what {char} came for." },
    -- (a room you never read: the first tonight, then any after it)
    skim = { "You never read this room properly. You skim the page while they wait.",
             "You didn't get to this room in your prep. You skim the page while they wait.",
             "This room's a blank in your notes. You speed-read it while the table waits." },
    skim_again = { "Another room you haven't read. More page-turning while they wait.", "You skim this one too. The table waits.",
                   "Back to skimming. Somebody gets up for a drink." },
    -- (a room you never prepped and chose to make up: the first tonight, then any after it)
    improv = { "You never prepped it, so you wing it: the room in a few strokes, and on to what matters.",
               "No prep for this one, so you make it up: a few quick strokes, and on to the good bit.",
               "You wing it: the room in a sentence or two, and straight to what matters." },
    -- (you put the book down to make a room up: the card's log)
    book_down = { "You put the book down. \"So. You open the door, and...\"", "You close the book. \"Right. So. You walk in, and...\"",
                  "You push your notes aside. \"Okay. Picture this...\"" },
    -- (you read a room from the book at the table: the first tonight, then any after it)
    from_book = { "You read the room straight from the book while they wait: a few minutes of turning pages and quiet.",
                  "You read this room off the page as you go. A few quiet minutes of page-turning.",
                  "Book open, you read the room out as you find it. The table waits through the pauses." },
    from_book_again = { "Back to the book for this one. More pages, more quiet.", "Another room read straight off the page. They wait, mostly patiently.",
                        "The book comes out again. Somebody checks their phone while you read." },
    -- (a friend who doesn't much mind comes round at a fork)
    easy = { "Fine, {way}. I'm easy.", "{Way} works for me.", "Okay, {way}. Lead on.", "Sure. {Way} it is." },
    -- (your hint, against a table that had already agreed where to go: the one keenest on it grumbles)
    grumble = { "We'd all just agreed on it: {way}.", "Hang on. We'd just agreed on it. {Way}.", "We'd literally just agreed on it: {way}." },
    -- (and the table hears you out, and sticks with it)
    go_on = { "They hear you out, and go on anyway: {way}.", "They listen, nod, and go on anyway: {way}.",
              "A fair point, they say, and go on anyway: {way}." },
    -- (you nudged a choice that's theirs, and they settle it their own way all the same)
    own_way = { "They hear you out, and go their own way anyway.", "They listen, and settle it their own way anyway.",
                "Thanks, they say, and decide for themselves anyway." },
    improv_again = { "No notes for this one either. You wing it, short and sweet.", "Another one you make up as you go. A few strokes, and on.",
                     "Winging it again. Nobody at the table can tell." },
    -- (how a night ends when you call it)
    close = { "You close the book. \"And that's where we stop tonight.\"", "You put the pencil down. \"That's where we leave it tonight.\"",
              "You close the book on your notes. \"Let's stop there for tonight.\"" },
    stop_fight = { "A good place to stop. Dice go back in their bags with a happy rattle.",
                   "A good place to stop, right after a fight. Everyone's still buzzing.",
                   "Off the back of a fight, a fine place to stop. High fives all round." },
    stop_flat = { "It peters out a bit. Somebody asks if that's it.", "It fizzles a little. Somebody checks the time.",
                  "A slightly flat stop. Somebody says \"Oh. Okay.\"" },
    stop_loss = { "Nobody argues for one more room. Not after that.", "Dice go back in their bags, quietly. It's been a rough one.",
                  "\"Let's stop there.\" Nobody says no. Somebody squeezes a shoulder on the way to the kitchen." },
}

-- What the heroes did while the table took its break, by your pick: three or more ways each, since
-- the break comes every week (R3: "Twenty minutes of pizza and gossip..." every week).
M.BREAK_LOGS = {
    nothing = { "Twenty minutes of pizza and gossip. Everyone comes back a bit happier and a bit sleepier.",
                "Twenty minutes of snacks and somebody's holiday photos. Everyone's back, crumbs and all.",
                "A proper break: pizza, a stretch, and a long argument about the best kind of dice.",
                "Twenty minutes off. Somebody tells the story of their week. Everyone comes back warm." },
    short = { "While the pizza goes round, the party sits with their backs to a wall for an hour.",
              "While the table eats, the heroes catch their breath: an hour with their boots off.",
              "An hour in the museum while the pizza goes round: bandages, water, a quiet sit." },
    long = { "The party beds down for the night. By the time the pizza's gone, they've slept eight hours.",
             "The heroes sleep the night through while the table eats. They wake up stiff, and whole.",
             "Eight hours of sleep in the museum, in the time it takes to finish the pizza." },
    research = { "Somebody gets the notes out. By the time the pizza's done, there's a plan, sort of.",
                 "Notebooks open between the pizza boxes. By the end of the break, there's a plan. Mostly.",
                 "The break turns into a study session: the museum, the Gorgon, and a lot of arrows on paper." },
}
M.BREAK_AT = 0.35          -- share of the planned evening before the break comes up
M.BREAK_MIN = 20           -- table minutes it takes

function M.maybe_break(night, before_boss)
    if night.had_break or night.end_early or (#night.scenes == 0 and not before_boss) then
        return false
    end
    local planned = night.table_planned or 210
    local t = night.table_min or 0
    -- (Brought forward on a friend's thought, "let's break after this bit": the next room's end.)
    if not before_boss and not night.break_soon and (t < math.max(60, planned * M.BREAK_AT) or t > planned - 30) then
        return false
    end
    night.break_soon = nil
    night.had_break = true
    local st = st_of(night)
    local room = MODULE.rooms[st.pos or st.last_room or ""] or {}
    local safe = room.rest and true or false
    local poses = {}
    for i, p in ipairs(night.players) do
        poses[p.key] = ({ "yawn", "laugh", "phone", "cheer" })[(i - 1) % 4 + 1]
    end
    night:react(poses)
    -- (After a death, a quiet break: round three's merge heard "Everyone comes back warm".)
    local sad = able.somber(night) ~= nil
    night:say(sad and night:fresh(M.BREAK_SAD.start, "break_sad_start") or night:fresh(BREAK_START, "break_start"), "dm")
    local card = { id = "table_break", type = "table", intermission = true,
                   title = "Let's take a break",
                   text = "Twenty minutes of pizza, stretching and gossip. Is anything happening in the game while you're all away from the table?",
                   options = {
                       { label = "Nothing. It's just a break.", break_log = "nothing",
                         effects = { { "all", social = 3, fun = 2 } } },
                       { label = "They take a short rest while we eat.", sub = "An hour in the game: Hit Dice, Second Wind, Channel Divinity, Arcane Recovery.",
                         break_log = "short", rest = "short",
                         effects = { { "all", social = 2, fun = 1 }, { "arch:tactician", fun = 2 } } },
                       { label = "They take a long rest here.", sub = safe and "A full night's sleep: everything back." or "Nowhere here is safe enough to sleep.",
                         disabled = not safe, rest = "long",
                         break_log = "long",
                         effects = { { "all", social = 2, fun = 1 }, { "arch:butt_kicker", challenge = -2 } } },
                       { label = "They read up: the museum, the Gorgon, their notes.", sub = "The next two rolls tonight get +2: they did their homework.",
                         break_log = "research", research = 2,
                         effects = { { "arch:storyteller", fun = 3, story = 3 }, { "arch:tactician", fun = 3 }, { "arch:butt_kicker", fun = -1 } } },
                   } }
    local o = night:decision(card)
    if o and o.break_log then
        -- (Picked after the call, so only the line that's said is remembered: R2.)
        if sad and M.BREAK_SAD[o.break_log] then
            night:say(night:fresh(M.BREAK_SAD[o.break_log], "break_sad_" .. o.break_log), "dm")
        else
            night:say(night:fresh(M.BREAK_LOGS[o.break_log], "break_" .. o.break_log), "dm")
        end
    end
    night.table_min = (night.table_min or 0) + M.BREAK_MIN
    for _, p in ipairs(night.players) do
        score.add(p, "boredom", -6)
        if p.mood == "tired" or p.mood == "distracted" then
            score.add(p, "fun", 3)       -- (the ones who were flagging get their second wind)
        end
    end
    if o and o.rest then
        if not night.pc_list then
            fight.party(night)
        end
        night:do_rest(o.rest == "long" and "long" or "short", "town")
    elseif o and o.research then
        night.research = (night.research or 0) + o.research
    end
    night:say(sad and night:fresh(M.BREAK_SAD.back, "break_sad_back") or night:fresh(BREAK_END, "break_end"), "dm")
    return true
end

-- Boss night ---------------------------------------------------------------------------------------

function M.boss_night(night)
    local c = night.campaign
    local st = st_of(night)
    -- Only the stairs left between them and her: they climb them first, as the night's way in.
    if st.at == "stairs" and not st.done.stairs then
        M.play(night, "stairs")
        if night.end_early then
            return
        end
    end
    -- The night's break (M.maybe_break): after the stairs if they climbed them tonight, at the lair
    -- door; else once her part is settled, before the gift shop (M.after_showdown). Never first thing,
    -- and never between the stand-off and the first blow (round three, A8: "They draw steel." then
    -- "Break time." on 19 of 22 boss nights).
    if #night.scenes > 0 then
        M.maybe_break(night, true)
    else
        night.break_after_lair = true
    end
    M.enter(night, "lair")
    M.interlude(night)
    local sc = M.build_scene(night, "lair")
    table.insert(night.scenes, sc)
    sc.index = #night.scenes
    night.mus.total = #night.scenes
    local enc = adventure.boss_encounter(c)
    sc.encounter = { ids = enc.ids, boss_name = "Euryale", built = true, allies = enc.allies, opts = enc.opts }
    for k, v in pairs(enc.opts) do
        sc.encounter[k] = v
    end
    sc.showdown = true
    -- How she fights, as the DM prepped it: she yields near the end (in the fight, fight.lua), or
    -- fights to the last. Either way she doesn't take a way out mid-fight on her own.
    sc.boss_style = (c.adv.boss and c.adv.boss.style == "last") and "last" or "yields"
    sc.yield_line = MODULE.showdown.yield_line
    -- Her goal's words wait for the ending (after_showdown): said at the fight's end, "It's over"
    -- came before she'd yielded and before anyone had decided what to do with her.
    sc.goal_said = true
    night:play_scene(sc)
    if not night.end_early then
        M.after_showdown(night, sc)
    end
end

-- Inside the lair's scene (night.lua calls this where a room's moments go): the talk, if she talks.
function M.showdown_start(night, sc)
    local c = night.campaign
    local st = st_of(night)
    local boss = st.boss or {}
    local sh = MODULE.showdown
    -- Someone notices the tapestry of three sisters.
    local best, bm
    for _, p in ipairs(night.players) do
        local m = night:mod_for(p, "perception")
        if not bm or m > bm then
            best, bm = p, m
        end
    end
    if best and night.rng:int(1, 20) + bm >= 13 then
        st.flags.tapestry = true
        night:say(best.char .. " notices a tapestry on the wall: three sisters, all with snake-slit eyes.", "good")
    end
    -- What the Lecturer told her on the way up (R11: people.pass_on), in her own words, first thing.
    local heard, entry = people.line(night, "mus_euryale", "heard")
    if heard then
        night:emit({ kind = "npc", name = "Euryale", cast = "mus_euryale", text = heard })
        local kind = entry and entry.when and entry.when.knows and entry.when.knows.kind
        local about = kind and people.knows_of(c, "mus_euryale", kind)
        local t = about and about.told and about.told.mus_euryale
        M.log_beat(night, { kind = "says", who = "mus_euryale", from = t or about, how = "therefore",
                            text = events.word("euryale") }, sc)
    end
    if boss.opener == "ambush" then
        -- (A second time up her stairs, she remembers the first: round three, B3.)
        night:say(st.flags.rematch and night:fresh(MODULE.showdown.ambush_again, "ambush_again")
            or "No drink, no questions. An arrow is already on the string when they reach the top step.", "bad")
        -- An ambush is a surprise (SRD 5.2.1: Disadvantage on Initiative), unless someone was ready.
        local rb, rm
        for _, p in ipairs(night.players) do
            local m = night:mod_for(p, "perception")
            if not rm or m > rm then
                rb, rm = p, m
            end
        end
        if rb and night.rng:int(1, 20) + rm >= 15 then
            night:say(rb.char .. " sees the bow come up in time and shouts a warning.", "good")
        else
            sc.ambushed = true      -- (night.lua's combat_scene: the party is surprised, no scouting)
        end
        sc.fight_on = true
        return
    end
    if not st.marks.garden_burned then
        M.play_moment(night, sh.drink, sc)
    elseif st.flags.rematch then
        -- (She beat them once already: not her first-meeting words. The confirming playtest, 56 careful.)
        night:say(night:fresh(M.WORLD_LINES.burned_again, "burned_again"), "bad")
    else
        night:say("\"You burned my garden.\" No drink. No small talk.", "bad")
    end
    M.play_moment(night, sh.talk, sc)
    if not st.ending then
        sc.fight_on = true
    elseif sc.encounter and #sc.encounter.ids > 1 then
        -- The talk ended it, but her marks brought her company: what they do follows from how it
        -- ended (an ally or a bargain calls them off; coin or a lecture doesn't).
        local at = MODULE.after_talk[st.ending] or { fight = false, line = "" }
        local rest = {}
        for i = 2, #sc.encounter.ids do
            table.insert(rest, sc.encounter.ids[i])
        end
        local lead = rest[1]
        for _, id in ipairs(MODULE.lead_order) do
            if util.contains(rest, id) then
                lead = id
                break
            end
        end
        local lead_name = MODULE.foe_names[lead] or "the first of them"
        if at.fight then
            -- The one leading them goes first on the mat, and the fight is named for them.
            for i, id in ipairs(rest) do
                if id == lead then
                    table.remove(rest, i)
                    break
                end
            end
            table.insert(rest, 1, lead)
            sc.encounter.ids = rest
            sc.encounter.boss_name = lead_name
            sc.resolved, sc.had_roll = nil, nil
            sc.fight_on = true
            sc.extras_only = true
            -- (Her collection's fight turns how the talk ended: she's gone, but they aren't. R14.)
            sc.fight_from, sc.fight_how = sc.ending_ev, "but"
        end
        night:say(util.fill(at.line, { lead = lead_name }), at.fight and "bad" or "good")
    end
end

-- The book's ending, played as boss night's last scene: back in the gift shop with Flitwidget, the
-- reward, and the first hint of what comes next. Not a room on the map.
-- Flitwidget back in his museum (R11): he sees what's left of his exhibits, Telpur has a word with him
-- about anything taken off the shelf, and what he thinks of them now is in his thanks (his line) and in
-- what he pays (a docked reward). Each is in the log, following from what it's about.
function M.thanks_word(night, sc)
    local c = night.campaign
    local st = st_of(night)
    local ending = st.ending and MODULE.endings[st.ending]
    -- (After a death, his word on how it ended is a quiet one: not "Splendid!" right after his grief.)
    local flit = ending and able.pick(night, ending.flit, ending.flit_sad)
    if flit then
        night:emit({ kind = "npc", name = "Flitwidget", cast = "mus_flitwidget", text = (string.gsub(flit, "^\"(.*)\"$", "%1")) })
    end
    local rooms = {}
    for id in pairs(MODULE.rooms) do
        rooms[id] = true
    end
    -- (He sees what's left of his exhibits now. It's a beat of the night only when he says so, docking the
    -- reward for it, below: the confirming playtest heard "Flitwidget saw what was left of the Bone
    -- Construct" in recaps where he never said a word about it.)
    local broke = people.notice(c, "mus_flitwidget", rooms, { ["break"] = true })
    local told = people.pass_on(c, "mus_telpur", "mus_flitwidget", { where = "thanks", kinds = { steal = true, harm = true } })
    for i, t in ipairs(told) do
        local about = events.get(c, t.about)
        local p = about and about.who and c:player(about.who)
        if i == 1 and p then
            t.beat = true
            -- (What he told: a theft, by the thing taken, as the pocket's own words name it.)
            local thing
            for _, list in util.sorted_pairs((MODULE.ideas or {}).pockets or {}) do
                for _, pk in ipairs(list) do
                    if about.kind == "steal" and pk.thing == about.thing then
                        thing = pk.short
                    end
                end
            end
            local char = about.char or p.char
            t.text = (thing and about.outcome == "got" and events.word("told_got", { char = char, thing = thing }))
                or (thing and about.outcome == "caught" and events.word("told_caught", { char = char, thing = thing }))
                or events.word("told", { char = char })
            sc.last_beat = t.id
        end
    end
    -- (What he knows they broke, in his words, from the log: the lines that name it say it.)
    local said, broke_words = {}, {}
    for _, ev in ipairs(events.find(c, { kind = "break", whom = "mus_flitwidget" })) do
        local w = ev.thing and ((MODULE.broke_words or {})[ev.thing] or ev.thing)
        if w and events.knows(c, "mus_flitwidget", ev) and not said[w] then
            said[w] = true
            table.insert(broke_words, w)
        end
    end
    local vars = { broke = #broke_words > 0 and util.join_names(broke_words) or "my exhibits" }
    -- (And in his words to the table, for the recap: what he saw broken, all of it.)
    local broke_things = {}
    for _, ev in ipairs(events.find(c, { kind = "break", whom = "mus_flitwidget" })) do
        if ev.thing and events.knows(c, "mus_flitwidget", ev) and not util.contains(broke_things, ev.thing) then
            table.insert(broke_things, ev.thing)
        end
    end
    -- (Anything pocketed along the way that hasn't come back comes back now, from the log.)
    -- (By the one who pocketed it while they're still that seat's hero and can act; else a friend gives
    -- it back for them, out loud: round three, A1 with B2.)
    for _, ev in ipairs(events.find(c, { kind = "pocket" })) do
        local p = not ev.returned and present(night, ev.who)
        local own = p and (not ev.char or p.char == ev.char) and able.can_act(night, p) and p or nil
        local by = own or (not ev.returned and night:at_hand()[1]) or nil
        if by then
            ev.returned = c.week
            if by == own then
                night:say(util.fill(night:fresh(M.WORLD_LINES.pocket_back, "pocket_back"), { char = by.char, thing = ev.thing }), "table")
            else
                night:say(util.fill(night:fresh(M.WORLD_LINES.pocket_back_for, "pocket_back_for"),
                    { char = by.char, thing = ev.thing, who = ev.char or (p and p.char) or "someone" }), "table")
            end
        end
    end
    -- (First pick of the gift shop's shelf, promised to a friend and not yet kept: theirs.)
    M.first_pick(night)
    -- (The one he caught with a hand in his pocket, for the line that forgives them by name.)
    local caught = people.knows_of(c, "mus_flitwidget", "steal", nil, true, nil, "caught")
    local thief = caught and present(night, caught.who)
    local line = people.line(night, "mus_flitwidget", "thanks", thief, vars)
    if line then
        night:emit({ kind = "npc", name = "Flitwidget", cast = "mus_flitwidget", text = line })
    end
    -- (Wary of them: ten gold each comes off the reward, for what he really holds against them. He says
    -- so, and what it comes to: one number, adventure.reward_vars.)
    -- (One reason, the one he can name from the log, said by him and told the same way in the recap, with
    -- the figure he said: what comes off what he pays, halved for an escape too. The confirming playtest:
    -- docked "for the business with my donation box" from a party that dropped a coin in it; the recap
    -- giving another reason than the table heard; "ten gold off" when the table heard five.)
    local reason, why, whom
    if people.RANK[people.level(c, "mus_flitwidget")] < 0 and not st.gold_docked then
        if #broke_things > 0 then
            reason = "break"
        elseif people.knows_of(c, "mus_flitwidget", "steal", nil, true, nil, "got") then
            reason, why = "draught", people.knows_of(c, "mus_flitwidget", "steal", nil, true, nil, "got")
        elseif people.knows_of(c, "mus_flitwidget", "steal", nil, true, nil, "caught") then
            reason, why = "caught", people.knows_of(c, "mus_flitwidget", "steal", nil, true, nil, "caught")
        elseif told[1] then
            reason, why = "told", told[1]
        elseif st.marks.robbed then
            reason, why = "box", (st.marks.robbed.ev and events.get(c, st.marks.robbed.ev)) or nil
        end
    end
    if reason then
        if reason == "break" then
            why = M.log_beat(night, { kind = "notice", who = "mus_flitwidget", from = broke[1] or events.last(c, { kind = "break", whom = "mus_flitwidget" }),
                                      how = "therefore", text = events.word("notice", { thing = util.join_names(broke_things) }) }, sc)
        end
        local before = adventure.reward_gold(c)
        st.gold_docked = 10
        st.gold = math.max(10, (st.gold or 30) - 10)
        local off = before - adventure.reward_gold(c)
        local p = why and why.who and c:player(why.who)
        if reason == "told" then
            local about = events.get(c, why.about)
            p = about and about.who and c:player(about.who) or p
        end
        M.log_beat(night, { kind = "docked", who = "mus_flitwidget", n = off, reason = reason, from = why,
                            text = events.word("docked_" .. reason, { n = adventure.gold_word(off), char = p and p.char or "them" },
                                               events.word("docked", { n = adventure.gold_word(off) })) }, sc)
        vars.off_word = adventure.gold_word(off)
        vars.Off_word = util.capitalize(vars.off_word)
        local dl = people.line(night, "mus_flitwidget", "docked", nil, night:vars(vars))
        if dl then
            night:emit({ kind = "npc", name = "Flitwidget", cast = "mus_flitwidget", text = dl })
        end
    else
        local rl = people.line(night, "mus_flitwidget", "reward", nil, night:vars(vars))
        if rl then
            night:emit({ kind = "npc", name = "Flitwidget", cast = "mus_flitwidget", text = rl })
        end
    end
end

function M.thanks(night)
    if night.end_early then
        return
    end
    local sc = M.build_scene(night, "thanks")
    sc.outcome = "win"          -- (the museum's done: nobody fails to be thanked)
    table.insert(night.scenes, sc)
    sc.index = #night.scenes
    night.mus.total = #night.scenes
    night:play_scene(sc)
    if not night.end_early then
        table.insert(night.mus.rooms, { room = "thanks", outcome = "win" })
    end
end

-- Heroes still stone when her fight stops (she yielded, ran, or let them go): her hold on them
-- breaks with it, and the table hears who's back (the playtest, Nov 2: a stone Oswin chatted in
-- the gift shop afterwards as if nothing had happened).
local function free_stone(night, sc)
    local freed = {}
    for _, pc in ipairs(night.pc_list or {}) do
        local was = false
        for i = #(pc.effects or {}), 1, -1 do
            local e = pc.effects[i]
            if e.stone or e.petrifying then
                table.remove(pc.effects, i)
                was = true
            end
        end
        if was and not pc.dead then
            table.insert(freed, pc.name)
        end
    end
    if #freed > 0 then
        local st = st_of(night)
        -- (Beaten, and she lets them go: her hold didn't break, she let it go. In the log, a lead beat, so the
        -- report and next week's "Last time" say how they came back, and in each one's history.)
        local let_go = sc and sc.fought and sc.outcome ~= "win" and not st.ending and not sc.extras_only
            and not (sc.boss_dead or sc.boss_yielded or sc.boss_ran)
        if let_go then
            night:say(util.fill(night:fresh(M.WORLD_LINES.stone_let_go, "stone_let_go"),
                { names = util.join_names(freed), crack = #freed == 1 and "cracks" or "crack" }), "bad")
            local keys = {}
            for _, pc in ipairs(night.pc_list or {}) do
                if util.contains(freed, pc.name) and pc.player_key then
                    table.insert(keys, pc.player_key)
                    st.aspects = st.aspects or {}
                    st.aspects[pc.player_key] = st.aspects[pc.player_key] or {}
                    table.insert(st.aspects[pc.player_key], "Turned to stone in her lair, until Euryale let go")
                end
            end
            events.add(night.campaign, { kind = "freed", who = "mus_euryale", heroes = keys, where = sc.room, beat = true, lead = true,
                                         from = sc.fight_ev, how = "therefore",
                                         text = events.word("freed", { names = util.join_names(freed) }, "Euryale let {names} out of the stone") })
            return
        end
        -- (Why it broke, from how her fight ended: the stone line promised "until her hold breaks".)
        local why = (sc and sc.boss_dead and "as she falls and her hold on the lair breaks")
            or (sc and sc.boss_yielded and "as she gives up the fight and her hold on the lair breaks")
            or (sc and sc.boss_ran and "as she flees and her hold on the lair breaks")
            or "as her hold on the lair breaks"
        night:say(util.join_names(freed) .. (#freed == 1 and " cracks" or " crack") .. " out of the stone, gasping, " .. why .. ".", "good")
    end
end

-- What's destroyed stays destroyed (round three, B3, the third playtest: Owen the Steam Mech destroyed on
-- screen, then back the next week "untouched", with last week's dead foes behind Euryale again). An ally
-- smashed or burnt out in her fight is off her card for good, and the night's recap leads with it; a
-- lost fight's fallen foes stay fallen: their marks come off her card (the huntlings by how many fell).
function M.lair_losses(night, sc, lost)
    local c = night.campaign
    local st = st_of(night)
    for _, a in ipairs(sc.allies_lost or {}) do
        for _, id in ipairs(MODULE.mark_order) do
            local m = MODULE.marks[id]
            if m.ally == a.id and st.marks[id] then
                local name = (id == "mech" and st.mech_name) or a.name
                local ev = events.add(c, { kind = "lost", who = "party", thing = a.id, where = sc.room, beat = true, lead = true,
                                           from = sc.fight_ev, how = "but", text = events.word("ally_lost", { name = name }) })
                events.set_cause(c, ev)
                adventure.remove_mark(c, id, true)
                events.set_cause(c, nil)
                st.flags[a.id .. "_lost"] = true
            end
        end
    end
    if not lost then
        return
    end
    local beaten = {}
    for _, mid in ipairs(sc.foes_beaten or {}) do
        beaten[mid] = (beaten[mid] or 0) + 1
    end
    for _, id in ipairs(MODULE.mark_order) do
        local m = MODULE.marks[id]
        if m.foe and st.marks[id] and beaten[m.foe] then
            if id == "pack" then
                st.pack = math.max(0, math.max(1, math.min(3, st.pack or 1)) - beaten[m.foe])
                if st.pack == 0 then
                    events.set_cause(c, sc.fight_ev)
                    adventure.remove_mark(c, id, true)
                    events.set_cause(c, nil)
                end
            else
                events.set_cause(c, sc.fight_ev)
                adventure.remove_mark(c, id, true)
                events.set_cause(c, nil)
            end
        end
    end
end

local function break_after_lair(night)
    if night.break_after_lair and not night.had_break then
        night.break_after_lair = nil
        M.maybe_break(night, true)
    end
end

function M.after_showdown(night, sc)
    local c = night.campaign
    local st = st_of(night)
    local boss = st.boss or {}
    free_stone(night, sc)
    M.lair_losses(night, sc, sc.fought and sc.outcome ~= "win" and not st.ending and not (sc.boss_yielded or sc.boss_ran or sc.boss_dead))
    if sc.extras_only and sc.fought and sc.outcome ~= "win" then
        -- She's gone already (paid, or carried out asleep): losing to her collection ends it anyway.
        night:say(MODULE.extras_lost, "bad")
    elseif not st.ending then
        -- What's said follows from what happened to her in the fight (the combat audit, Nov 2: she
        -- "yielded" after she was dead).
        if sc.fought and sc.boss_yielded then
            -- She asked to stop, in the fight: now the table decides what that means.
            M.play_moment(night, MODULE.showdown.yield, sc)
            st.ending = st.ending or "escape"      -- (nobody decided: she walks out)
        elseif sc.fought and sc.boss_ran then
            -- She got away mid-fight (a way out, or the whole fight breaking): that's the ending.
            st.ending = "escape"
        elseif sc.fought and sc.boss_dead then
            -- She's dead, whoever won the rest of the fight.
            if sc.outcome ~= "win" then
                night:say(MODULE.showdown.dead_but_lost, "bad")
            end
            st.ending = "fallen"
        elseif sc.fought and sc.outcome == "win" then
            st.ending = "fallen"
        elseif sc.fought then
            night:say("She lets them go. She wants them to come back.", "bad")
            night:say("They limp out of the caravan, sleep for a day, and come back angry.", "dm")
            sc.rest_here = true      -- (home to rest: next week's try starts whole, not where this one broke)
            st.at, st.choices = "lair", nil
            st.lost_once = true
            st.flags.rematch = true      -- (next time, her cards know they've been here before)
            table.insert(st.path, { room = "lair", week = c.week, outcome = "lose" })
            table.insert(night.mus.rooms, { room = "lair", outcome = "lose" })
            night:goal_event(sc)       -- (for the recap; the lines above already said it)
            -- (Beaten, sent home: the table's quiet for the rest of the night, and the night ends here,
            -- with no break to come back from: round three's merge heard "Everyone comes back warm" and
            -- "Recap, quick: where were we standing?" right before the goodnights.)
            if not (night.loss and night.loss.night) then
                night.loss = { scene = sc, kind = "lost", night = true }
            end
            night.break_after_lair = nil
            return
        end
    end
    local e = st.ending and MODULE.endings[st.ending]
    -- (How it ended, in the log: it follows from the card that settled it (her ultimatum, her yield), else
    -- the fight that did. Not from her collection's fight after she'd gone: R14.)
    if e then
        M.log_beat(night, { kind = "ending", who = "party", thing = st.ending, where = "lair",
                            from = sc.ending_ev or sc.fight_ev,
                            text = e.chain or util.lower_first(e.name) }, sc)
    end
    table.insert(night.mus.rooms, { room = "lair", outcome = e and "win" or "lose" })
    -- The goal came out how the ending says, whoever won the last of the fight: recorded for the
    -- recap in the ending's own words (the ending line is what the table hears).
    sc.outcome = e and "win" or "lose"
    night:goal_event(sc)
    if e then
        night:say((sc.boss_dead == "turned to stone" and e.stone_line) or e.line, "good")
        -- (Flitwidget's word on how it ended is said downstairs, in his thanks: thanks_word. Round
        -- three heard him in her lair, before the gift shop scene began.)
        st.done.lair = "win"
        table.insert(st.path, { room = "lair", week = c.week, outcome = "win" })
        st.at, st.choices = nil, nil
        break_after_lair(night)       -- (the lull: her part's over, the gift shop's next)
        M.thanks(night)
        for _, line in ipairs(MODULE.epilogue) do
            night:say(line, "narration")
        end
        -- (After a death tonight, the friends want the campaign the quiet way: not "Same heroes, bigger
        -- fights?" nor "Oswin says a prayer for the road" with Oswin dead. Round three's merge.
        -- MODULE.want_more_sad: `own` lines for the friend whose hero died, else theirs for a friend's.)
        -- (And whoever died on an earlier night: the prologue's dead are named when it ends, not "Same heroes,
        -- bigger fights?" from Dev, whose Brannoc died in week one. The confirming playtest, 53 careful.)
        local lost = {}
        for _, pc in ipairs(night.pc_list or {}) do
            if pc.dead then
                table.insert(lost, { name = pc.name, player_key = pc.player_key })
            end
        end
        for _, rec in ipairs(c.fallen or {}) do
            local dup = false
            for _, l in ipairs(lost) do
                dup = dup or l.name == rec.char
            end
            if not dup then
                table.insert(lost, { name = rec.char, player_key = rec.key })
            end
        end
        local sad = #lost > 0 and MODULE.want_more_sad
        for _, p in ipairs(night.players) do
            -- (A line about something only if it happened: { text, when }.)
            local lines = {}
            local others = {}
            local own = false
            for _, pc in ipairs(lost) do
                if pc.player_key == p.key then
                    own = pc.name
                else
                    table.insert(others, pc.name)
                end
            end
            -- (`was`: their hero died on an earlier night, and they play someone new now, {now}.)
            local which = (own and own ~= p.char and "was") or ((own or #others == 0) and "own") or "other"
            local pool = sad and ((sad[p.key] or {})[which] or (sad[p.key] or {}).own) or MODULE.want_more[p.key]
            for _, l in ipairs(pool or {}) do
                if type(l) == "string" then
                    table.insert(lines, l)
                elseif adventure.test(c, l.when) then
                    table.insert(lines, l[1])
                end
            end
            if #lines > 0 then
                -- (An own line's {char} is the hero who died, who may not be the one they play now.)
                local line = util.fill(night.rng:pick(lines), { char = (sad and own) or p.char, now = p.char, lost = util.join_names(others) })
                st.want_said = st.want_said or {}
                st.want_said[p.key] = line           -- (the journey quotes what they really said)
                night:emit({ kind = "say", who = p.key, text = line, ic = false })
                score.add(p, "commitment", 5)
                score.add(p, "investment", 4)
            end
        end
    end
end

return M
