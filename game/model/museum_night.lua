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
    local port = (type(pick) == "string" and MODULE.portraits[pick]) or (who and MODULE.portraits[who])
        or MODULE.portrait_default or {}
    v.painting = port.painting or "a frosty mountain portrait"
    v.gift = port.gift or "a painted scimitar"
    v.gift_empty = port.empty or nil
    -- (What reaching into this painting risks, as the book has it: mus_reach.)
    v.portrait = port
    v.reach_hint = port.hint and (" " .. port.hint) or ""
    return v
end

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
        return t and util.fill(t, { char = who, actor_char = who, mech = (st_of(night).mech_name or "the Mech") }) or nil
    end
    if type(ob) == "table" then
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
                -- (Whoever picked it up offers it to whoever'll use it best: M.hand_off.)
                local to = M.hand_off(night, it.magic, night.actor)
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
        sc.encounter[opt] = true
    end
    if mus.mark == "mech" then
        st.mech_name = st.mech_name or night.rng:pick(MODULE.mech_names)
        st.mech_commander = night.actor and night.actor.key
    end
    if mus.aspect and night.actor then
        st.aspects = st.aspects or {}
        st.aspects[night.actor.key] = st.aspects[night.actor.key] or {}
        table.insert(st.aspects[night.actor.key], mus.aspect)
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
    if alt.fled ~= nil and alt.fled ~= (sc.foes_ran ~= nil and #sc.foes_ran > 0) then
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
    for _, alt in ipairs((win and goal.win_if or goal.lose_if) or {}) do
        if alt_holds(night, sc, alt) then
            text = alt.text
            break
        end
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
    night:say("They earn " .. util.lower_first(r.line), "reward", { gold = util.int(gold) })
    M.note_got(night, r.id == "mus_thanks" and (util.int(gold) .. " gold each and a pick from the gift shop")
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
        if #backers > 0 and night.actor and not backs then
            copy.text = util.fill(copy.text or "", vars)
            night.actor = backers[1]
        end
        copy.fixed_actor = true
        copy.trigger = "museum_fixed"
        -- A lock is picked by whoever's best with one (the playtest, November 3: "lock picking needs a
        -- roll from the lockpicker").
        local chosen = copy.options[copy.party_pick]
        if chosen and chosen.roll and chosen.roll.best then
            local best, bm
            for _, p in ipairs(night:at_hand()) do
                local _, m = night:best_skill(p, chosen.roll.skill)
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
    local o = night:decision(copy, night.mus_vars)
    if not o then
        return nil
    end
    -- (Whose painting the hall showed: the chat and the notes can say so.)
    if card.id == "mus_reach" and night.actor then
        st.flags["portrait_" .. night.actor.key] = true
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
    events.set_cause(c, mev)
    if sc and mev.beat and not card.look then
        sc.last_moment = mev.id
    end
    mev.handing = true                  -- (what it hands over is told by the moment itself: items.lua)
    M.handle(night, o.mus, sc)
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
        M.handle(night, out and out.mus, sc)
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
                    if k ~= "risk" then
                        oo.mus[k] = v
                    end
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
            night:emit({ kind = "say", who = lead.key, text = "...Actually, no. Let's not.", ic = false })
            copy.party_pick = safe
            night:say(util.fill("{actor_char} thinks better of it.", vars), "dm")
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
    if night.end_early or (sc.fought and sc.outcome ~= "win") then
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
        local arch = LOOK_SAY[p.primary] and p.primary or "casual"
        -- ("Where are the monsters?" only where there are none: no fight in the room, before or after.)
        local room = MODULE.rooms[sc.room] or {}
        local lines = M.look_lines(arch, pl, { calm = not room.encounter and not sc.fought })
        local line = night:fresh(lines, "look_" .. arch)
        night:emit({ kind = "say", who = p.key, text = line, ic = LOOK_IC[arch] or false })
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
            night:say("Tucked away by " .. util.lower_first(pl.name or "it") .. ": " .. (n == 1 and "a Flitwidget Franc" or (util.int(n) .. " Flitwidget Francs"))
                .. ".", "good")
            night:say("The find you moved behind your screen turns up here.", "screen")
            M.handle(night, { francs = n }, sc)
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

function M.room_start(night, sc)
    local c = night.campaign
    local r = MODULE.rooms[sc.room]
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
        if util.contains(night.players, p) then
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
            table.insert(st.aspects[p.key], 1, "Came for " .. util.lower_first(h.name) .. ", and found it in "
                .. util.lower_first(MODULE.rooms[sc.room].name))
            night:highlight(6, util.fill("{char} finds what {char_they} came for: ", { char = p.char }) .. util.lower_first(h.name), { p }, "thread")
        end
    end
    -- What the week between promised, paying off here (the room's callbacks): a line, and maybe
    -- something handed over for real.
    for _, cb in ipairs(r.callbacks or {}) do
        if adventure.test(c, cb.when, knobs) then
            local given
            if cb.give and cb.give.magic then
                local items_mod = require "game.model.items"
                local to = cb.give.who and present(night, cb.give.who)
                local e = items_mod.earn(c, cb.give.magic, to and { to } or night.players)
                given = e and e.holder and present(night, e.holder)
                local d = items_mod.def(cb.give.magic)
                M.note_got(night, d and string.lower(d.name) or nil)
            end
            night:say(util.fill(cb.text, { given = given and given.char or "the party" }), "narration")
        end
    end
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
            if it.opt then
                sc.encounter[it.opt] = true
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
                table.insert(lines, util.fill(said, { holder = holder and holder.char or "Somebody",
                                                          mech = st.mech_name or "The Mech" }))
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
    explorer = { "I want to see what it does.", "I want to know what's in there.", "Come on, aren't you curious?" },
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

-- What one option is worth to one friend, and the reason that weighed most. o: the card's option.
local function lean(night, p, o)
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
    -- Their hero's state: hurt heroes don't want risks or fights; a fresh fighter does.
    local hh = hero_hurt(night, p)
    local m = o.mus or {}
    local risky = m.risk or m.fight or o.roll ~= nil or (o.roll and o.roll.fail and o.roll.fail.mus and o.roll.fail.mus.hurt)
    if risky and hh >= 0.4 then
        v = v - 4 * hh
    elseif m.warn and hh >= 0.4 then
        v = v + 2 * hh
        if 2 * hh > whyv then
            why, whyv = "hurt", 2 * hh
        end
    end
    if m.fight then
        v = v + 2 * score.arch(p, "butt_kicker")
    end
    if m.francs or m.flag or m.mark then
        v = v + 0.8 * score.arch(p, "power_gamer")
    end
    return v, why
end
M.lean = lean       -- (for the checks: tools/tests/roadmap_table_check.lua)

-- What carries over into a vote (R10, the round-two review: the table picked the same option on a card
-- in three runs of four): the week a friend's had, the spotlight so far tonight, a vote they lost last
-- time, and the table's habit ("we played it safe last time"). Each is a reason they say out loud, in
-- their own words, three ways each (fresh across weeks).
M.VOTE_WHY = {
    pushed = { "I went along last time. This one's mine.", "I gave way last time. Not on this one.",
               "Last time I came round. This time you can." },
    safe_last = { "We played it safe last time. Let's not.", "We were careful last time. Where's the fun in that?",
                  "Come on, we played it safe last time." },
    bold_last = { "We went in swinging last time. Let's be smart for once.", "We charged in last time. Maybe not again.",
                  "We were reckless last time. Let's not push it." },
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
}
M.VOTE_PUSH = 1.4          -- what losing the last vote adds to a friend's own pick (twice running: twice that)
M.VOTE_HABIT = 1.1         -- what the last pick's kind adds to the other kind, for the friends who like it
M.VOTE_EDGE = 2.4          -- what each thing they brought against her adds to fighting her (up to three), for a planner
M.VOTE_MINE = 2.5          -- and what each one a friend carries adds, for them (up to two)

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

-- An option's kind, for the table's habit: "bold" (a roll, a fight, a risk) or "safe" (a warning
-- heeded, a fight avoided, careful hands), or nil (neither: a purchase, a way through).
function M.vote_kind(o)
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

local function fan_of(p, kind)
    local n = 0
    for _, a in ipairs(KIND_FANS[kind] or {}) do
        n = math.max(n, score.arch(p, a))
    end
    return n
end

-- What carries over for friend p on option o, beside who they are: bonus, reason (a VOTE_WHY key),
-- and the words that reason needs ({mine}). The night so far (their mood this week, the spotlight
-- tonight), the votes before (the habit), and against Euryale, what they brought (edges: M.edges).
local function carry(night, p, o, votes, avg_spot, edges)
    local bonus, why, whyv = 0, nil, 0
    local function add(n, key)
        bonus = bonus + n
        if n > whyv then
            why, whyv = key, n
        end
    end
    local kind = M.vote_kind(o)
    local m = o.mus or {}
    local easy = kind ~= "bold"
    local mood = p.mood
    if mood == "tired" then
        if easy then
            add(1.3, "tired")
        elseif m.fight then
            bonus = bonus - 0.6
        end
    elseif mood == "celebrating" and kind == "bold" then
        add(1.2, "celebrating")
    elseif mood == "stressed" and kind ~= "bold" then
        add(1.2, "stressed")
    end
    -- Leading this one, and quiet all night: the option that's theirs to play.
    if night.actor == p and (p.m.spotlight or 0) < avg_spot - 8 then
        local theirs = false
        for _, list in ipairs({ o.effects or {}, (o.roll and o.roll.success and o.roll.success.effects) or {} }) do
            for _, e in ipairs(list) do
                theirs = theirs or (e[1] == "actor" and (e.spotlight or 0) > 0)
            end
        end
        if theirs then
            add(1.4, "quiet")
        end
    end
    -- They came ready for her (R10, after the world merge: with the fight and the Lecturer's page the
    -- only answers left, the table read her the page every time, as only Dev wanted the fight): a
    -- friend who likes a fair, clever fight counts what they brought against her, and says what it is.
    local words
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
            words = { mine = mine[1] }
        end
    end
    -- The table's habit: the last pick's kind, and the friends who like the other kind.
    local last = votes and votes.last
    if last and last.kind and kind and kind ~= last.kind then
        local f = fan_of(p, kind)
        if f > 0 then
            add(M.VOTE_HABIT * f * math.min(2, last.streak or 1), last.kind == "safe" and "safe_last" or "bold_last")
        end
    end
    return bonus, why, words
end

local function short_want(o)
    return o.want or util.lower_first((string.gsub(o.label or "", "[%.!]+$", "")))
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
    local vals, first, why = {}, {}, {}
    -- (What carries over from the votes before, R10: kept with the adventure, so it lasts the weeks.)
    local adv = night.campaign.adv
    local votes = adv and adv.votes or {}
    local avg_spot = 0
    for _, p in ipairs(night.players) do
        avg_spot = avg_spot + (p.m.spotlight or 0)
    end
    avg_spot = avg_spot / math.max(1, #night.players)
    local edges, edge_words = M.edges(night.campaign)
    for _, p in ipairs(night.players) do
        vals[p.key] = {}
        local best, bv, plain, pv
        for _, i in ipairs(live) do
            local v, w = lean(night, p, opts[i])
            local cb, cw, cwords = carry(night, p, opts[i], votes, avg_spot, edges)
            v = v + night.rng:next() * 1.6
            if not pv or v > pv then
                plain, pv = i, v
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
        why[p.key] = (b.cwhy and (plain ~= best or b.cb >= 1)) and b.cwhy or b.why
    end
    -- A friend who lost the last vote holds out for theirs this time (twice running: harder), and says so.
    -- (Said only when the table doesn't already agree: nobody needs to hold out for what everyone wants.)
    local agreed = true
    for _, p in ipairs(night.players) do
        agreed = agreed and first[p.key] == first[night.players[1].key]
    end
    local pushers = {}
    for _, p in ipairs(night.players) do
        local n = (votes.lost or {})[p.key]
        if n and n > 0 then
            local b = vals[p.key][first[p.key]]
            b.v = b.v + M.VOTE_PUSH * math.min(2, n)
            if not agreed then
                why[p.key] = "pushed"
            end
            pushers[p.key] = true
        end
    end
    local wanted = util.copy(first)         -- (what each wanted before the talk: who lost, for next time)
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
        vals[lead.key][prop].v = vals[lead.key][prop].v + 1      -- (they said it: they hold to it)
    end
    local function tally()
        local n, top, top_n = {}, nil, 0
        -- (Two against two: the side of whoever went along last time, then the side of whoever found
        -- it, then the keener side. R10.)
        local care = {}
        for _, p in ipairs(night.players) do
            local i = first[p.key]
            n[i] = (n[i] or 0) + 1
            care[i] = (care[i] or 0) + math.min(4, vals[p.key][i].v) + (pushers[p.key] and 100 or 0)
                + (p == night.actor and 10 or 0)
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
        return top, top_n, tied, n
    end
    -- What each says first: the ones with a real reason speak up (two at most), in their own words.
    local spoke = 0
    local order = util.copy(night.players)
    table.sort(order, function(a, b)
        local va, vb = vals[a.key][first[a.key]].v, vals[b.key][first[b.key]].v
        if va ~= vb then
            return va > vb
        end
        return a.key < b.key
    end)
    local said = {}
    -- (A friend's reason is a catchphrase: each one once a session, and never from the same friend two
    -- talks running. R2, the second playtest review: "Less talking, more hitting" after nearly every
    -- one of Dev's suggestions.)
    night.lean_talks = (night.lean_talks or 0) + 1
    night.lean_last = night.lean_last or {}
    for _, p in ipairs(order) do
        if spoke < 3 and (spoke < 2 or first[p.key] ~= first[order[1].key]) then
            local w = why[p.key]
            night.lean_why_n = night.lean_why_n or {}
            local said_n = night.lean_why_n[p.key] or 0
            local rested = night.lean_last[p.key] == night.lean_talks - 1
            local reason = (w == "hurt" and (p.char .. "'s hurt. Let's not."))
                or (w and M.VOTE_WHY[w] and night:fresh(M.VOTE_WHY[w], "vote_" .. w, true))
                or (w and LEAN_WHY[w] and said_n < M.LEAN_WHY_MAX and not rested
                    and night:fresh(LEAN_WHY[w], "lean_" .. w .. "_" .. p.key, true)) or nil
            if reason and w ~= "hurt" and not M.VOTE_WHY[w] then
                night.lean_why_n[p.key] = said_n + 1
                night.lean_last[p.key] = night.lean_talks
            end
            local mine = (vals[p.key][first[p.key]].words or {}).mine
            local line = "Let's " .. short_want(opts[first[p.key]]) .. "."
                .. (reason and (" " .. util.fill(reason, { char = p.char, edge = edge_words, mine = mine })) or "")
            night:emit({ kind = "say", who = p.key, text = util.sentence_case(line), ic = false })
            said[p.key] = true
            spoke = spoke + 1
        end
    end
    -- The talk: a friend who barely minds comes round to where most of the table is.
    local top, top_n, tied = tally()
    local half = #night.players / 2
    if top_n <= half then
        for _, p in ipairs(night.players) do
            local mine = vals[p.key][first[p.key]].v
            -- (Not the one holding out after last time; a friend with half an eye on their phone, sooner.)
            local easy = p.mood == "distracted" and 2 or 1.2
            if first[p.key] ~= top and vals[p.key][top] and mine - vals[p.key][top].v < easy and not pushers[p.key] then
                first[p.key] = top
                -- (Whoever comes round says so: nobody's counted for what they argued against.)
                night:emit({ kind = "say", who = p.key, text = (said[p.key] and "Okay, okay. " or "Fine by me. ")
                    .. util.capitalize(short_want(opts[top])) .. ".", ic = false })
                said[p.key] = true
            end
        end
        top, top_n, tied = tally()
    end
    -- Still split: someone asks the DM (the DM can nudge, or leave it to them).
    local asked = false
    if (tied > 1 or top_n <= half) and night.rng:chance(0.75) and not night.gentle then      -- (night 1: they settle it, R6)
        asked = true
        local asker = night:pick_actor({ "casual", "tactician", "storyteller" }) or night.players[1]
        local card = { id = "table_asks_" .. (copy.id or "x"), type = "table", trigger = "museum_fixed", fixed_actor = true,
                       title = "They ask you",
                       text = "The table can't agree. " .. util.fill(night:fresh(M.WEEKLY.ask_look, "weekly_ask_look"), { name = asker.name })
                           .. ": \"What do you think?\"",
                       options = {} }
        for _, i in ipairs(live) do
            local names = {}
            for _, p in ipairs(night.players) do
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
            sub = "They settle it themselves: whoever gave way last time gets this one, or else whoever found it.",
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
            for _, p in ipairs(night.players) do
                if first[p.key] ~= o.nudge then
                    local gap = vals[p.key][first[p.key]].v - vals[p.key][o.nudge].v
                    if gap < 4 then
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
    -- A tie goes to the side of whoever went along last time, then of whoever found it, then to the
    -- keener side (tally's order).
    local names = {}
    night.party_backers = {}
    for _, p in ipairs(order) do
        if first[p.key] == top then
            table.insert(night.party_backers, p)
        end
    end
    for _, p in ipairs(night.players) do
        if first[p.key] == top then
            table.insert(names, p.name)
        end
    end
    night:say("The table decides: " .. short_want(opts[top]) .. ((nudged_to == top and " (on your nudge)")
        or ((#names > 0 and #names < #night.players) and (" (" .. util.join_names(names) .. "'s idea)")) or "") .. ".", "aside")
    -- What the next vote remembers (R10): who went along with what they didn't want (they push next
    -- time), and what kind of pick this was (the table notices a habit).
    if adv then
        adv.votes = adv.votes or {}
        local vt = adv.votes
        -- (The one who minded most: they push next time, harder if it's twice running.)
        local loser, gap = nil, 1.5       -- (minded it: not a shrug)
        for _, p in ipairs(night.players) do
            local mine = wanted[p.key]
            local g = mine ~= top and (vals[p.key][mine].v - vals[p.key][top].v) or 0
            if g >= gap then
                loser, gap = p.key, g
            end
        end
        local again = loser and vt.lost and vt.lost[loser] or 0
        vt.lost = loser and { [loser] = again + 1 } or {}
        local kind = M.vote_kind(opts[top])
        if kind then
            vt.last = { kind = kind, streak = (vt.last and vt.last.kind == kind) and ((vt.last.streak or 1) + 1) or 1, card = copy.id }
        end
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
    local choices = {}
    for _, id in ipairs(options) do
        table.insert(choices, { id = id, steps = fresh[id] or 1 })
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
    for _, p in ipairs(night.players) do
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
    for _, p in ipairs(night.players) do
        local mine = vals[p.key][first[p.key]].v
        for _, q in ipairs(night.players) do
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
    for _, p in ipairs(night.players) do
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
    fk = { title = fk.title, text = (at_text and (at_text .. " Everyone has an opinion.")) or fk.text }
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
    night:say(fk.text .. " " .. table.concat(parts, " "), "narration")
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
    local function tally()
        local n, t, tn = {}, nil, 0
        for _, p in ipairs(night.players) do
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
    local half = #night.players / 2
    if top_n <= half then
        for _, p in ipairs(night.players) do
            local mine = vals[p.key][first[p.key]].v
            if first[p.key] ~= top and mine - vals[p.key][top].v < 1.0 then
                first[p.key] = top
                local way = label_of(top)
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
        local asker = night:pick_actor({ "casual", "tactician", "storyteller" }) or night.players[1]
        local card = { id = "mus_fork_" .. key, type = "story", trigger = "museum_fixed", fixed_actor = true, title = fk.title,
                       text = (split and "They can't agree. " or "They've more or less decided, but ")
                           .. util.fill(night:fresh(M.WEEKLY.ask_look, "weekly_ask_look"), { name = asker.name })
                           .. ": \"Where would you go?\"", options = {} }
        for i in ipairs(choices) do
            local names = {}
            for _, p in ipairs(night.players) do
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
                log = "\"If it were me? " .. util.capitalize(label_of(i)) .. ".\"" })
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
                for _, p in ipairs(night.players) do
                    if first[p.key] == top and (not grumbler or vals[p.key][top].v > vals[grumbler.key][top].v) then
                        grumbler = p
                    end
                end
                if grumbler then
                    night:emit({ kind = "say", who = grumbler.key, text = util.fill(night:fresh(M.WEEKLY.grumble, "weekly_grumble"), { way = label_of(top) }), ic = false })
                    night:react({ [grumbler.key] = "arms" })
                end
                local curious = 0
                for _, p in ipairs(night.players) do
                    if p.primary == "explorer" or p.primary == "storyteller" or p.secondary == "explorer" then
                        curious = curious + 1
                    end
                end
                follow = curious > #night.players / 2 or (curious * 2 == #night.players and night.rng:chance(0.5))
                if not follow then
                    night:say(util.fill(night:fresh(M.WEEKLY.go_on, "weekly_go_on"), { way = label_of(top) }), "aside")
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
            for _, p in ipairs(night.players) do
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
        for _, p in ipairs(night.players) do
            local v = vals[p.key][first[p.key]].v
            if not kv or v > kv then
                keen, kv = p, v
            end
        end
        top = first[keen.key]
        night:emit({ kind = "say", who = keen.key, text = "Okay, I'm calling it: " .. label_of(top) .. ".", ic = false })
    end
    do
        local names = {}
        for _, p in ipairs(night.players) do
            if first[p.key] == top then
                table.insert(names, p.name)
            end
        end
        -- (Your nudge settled it: say so, not that they all thought of it themselves.)
        local nudged = night.mus.nudged_to == top
        night.mus.nudged_to = nil
        night:say("The table decides: " .. label_of(top) .. (nudged and " (on your nudge)" or ((#names > 0 and #names < #night.players)
            and (" (" .. util.join_names(names) .. "'s pick)")) or "") .. ".", "aside")
    end
    local ch = choices[top] or choices[1]
    -- The friend who runs off (the BBQ story): the instigator, outvoted, heads for the stairs alone.
    local jess = present(night, "jess")
    if not ch.back and not ch.side and ch.id == "stairs" and jess and not st.flags.seen and night.rng:chance(0.6) then
        st.flags.pip_alone = true
        thoughts.plan(night, jess)         -- a beat before she goes: what she's thinking, if you catch it
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
    local function mark(m)
        if adventure.add_mark(c, m, id) then
            table.insert(night.mus.pending, m)
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
            mark("pages")
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
            items_mod.give(c, "notebook", nil, "found")
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
            night:emit({ kind = "mark", id = id, name = m.name, why = adventure.mark_why(night.campaign, id), showdown = m.showdown, thought = thought })
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
        if #bits > 0 then
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
        if st.unannounced and #st.unannounced > 0 then
            for _, id in ipairs(st.unannounced) do
                table.insert(night.mus.pending, id)
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
    if k == "cliff" then
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
    if k == "cliff" then
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
    thoughts.mood(night)
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
    if st.done.lecture == "win" or st.ending then
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
}
local BREAK_END = {
    "Everyone settles back in. \"Right. Where were we?\"",
    "Pizza boxes stacked, dice back out. \"Okay. So. The museum.\"",
    "Everyone drifts back to the table. Someone reads the last line of their notes out loud.",
    "Chairs pulled back in. \"Recap, quick: where were we standing?\"",
}
M.BREAK_START, M.BREAK_END = BREAK_START, BREAK_END   -- (for the Dialogue Desk)
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
    grumble = { "We'd all just agreed on {way}, though.", "Hang on, we'd just agreed on {way}.", "We'd literally just agreed on {way}." },
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
    night:say(night:fresh(BREAK_START, "break_start"), "dm")
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
        night:say(night:fresh(M.BREAK_LOGS[o.break_log], "break_" .. o.break_log), "dm")
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
    night:say(night:fresh(BREAK_END, "break_end"), "dm")
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
    -- The night's break (M.maybe_break): after the stairs if they climbed them tonight, else after
    -- the talk, right before the fight (night.lua combat_scene). Never first thing.
    if #night.scenes > 0 then
        M.maybe_break(night, true)
    else
        night.break_before_fight = true
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
        night:say("No drink, no questions. An arrow is already on the string when they reach the top step.", "bad")
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
    local rooms = {}
    for id in pairs(MODULE.rooms) do
        rooms[id] = true
    end
    local broke = people.notice(c, "mus_flitwidget", rooms, { ["break"] = true })
    if #broke > 0 then
        M.log_beat(night, { kind = "notice", who = "mus_flitwidget", from = broke[1], how = "therefore",
                            text = events.word("notice", { thing = broke[1].thing or "his exhibits" }) }, sc)
    end
    local told = people.pass_on(c, "mus_telpur", "mus_flitwidget", { where = "thanks", kinds = { steal = true, harm = true } })
    for i, t in ipairs(told) do
        local about = events.get(c, t.about)
        local p = about and about.who and c:player(about.who)
        if i == 1 and p then
            t.beat = true
            t.text = events.word("told", { char = p.char })
            sc.last_beat = t.id
        end
    end
    local line = people.line(night, "mus_flitwidget", "thanks")
    if line then
        night:emit({ kind = "npc", name = "Flitwidget", cast = "mus_flitwidget", text = line })
    end
    -- (Wary of them: the breakages come out of the reward. He says so.)
    if people.RANK[people.level(c, "mus_flitwidget")] < 0 and not st.gold_docked then
        st.gold_docked = 10
        st.gold = math.max(10, (st.gold or 30) - 10)
        local why = (#broke > 0 and events.last(c, { kind = "notice", who = "mus_flitwidget" })) or told[1]
            or people.knows_of(c, "mus_flitwidget", "harm") or people.knows_of(c, "mus_flitwidget", "steal")
        M.log_beat(night, { kind = "docked", who = "mus_flitwidget", n = 10, from = why,
                            text = events.word("docked") }, sc)
        local dl = people.line(night, "mus_flitwidget", "docked")
        if dl then
            night:emit({ kind = "npc", name = "Flitwidget", cast = "mus_flitwidget", text = dl })
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
local function free_stone(night)
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
        night:say(util.join_names(freed) .. (#freed == 1 and " cracks" or " crack") .. " out of the stone, gasping, as her hold on the lair breaks.", "good")
    end
end

function M.after_showdown(night, sc)
    -- (No fight after the talk, so no break before it: take it now, before the ending plays out.)
    if night.break_before_fight and not night.had_break then
        night.break_before_fight = nil
        M.maybe_break(night, true)
    end
    local c = night.campaign
    local st = st_of(night)
    local boss = st.boss or {}
    free_stone(night)
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
        night:emit({ kind = "npc", name = "Flitwidget", cast = "mus_flitwidget", text = (string.gsub(e.flit, "^\"(.*)\"$", "%1")) })
        st.done.lair = "win"
        table.insert(st.path, { room = "lair", week = c.week, outcome = "win" })
        st.at, st.choices = nil, nil
        M.thanks(night)
        for _, line in ipairs(MODULE.epilogue) do
            night:say(line, "narration")
        end
        for _, p in ipairs(night.players) do
            -- (A line about something only if it happened: { text, when }.)
            local lines = {}
            for _, l in ipairs(MODULE.want_more[p.key] or {}) do
                if type(l) == "string" then
                    table.insert(lines, l)
                elseif adventure.test(c, l.when) then
                    table.insert(lines, l[1])
                end
            end
            if #lines > 0 then
                local line = night.rng:pick(lines)
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
