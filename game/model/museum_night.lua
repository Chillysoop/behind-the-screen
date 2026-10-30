-- Game night in the museum (v2): the night walks the module's map room by room until the evening
-- runs out or the party reaches a natural stop, asks the DM at each fork, plays each room's own
-- moments, and cuts upstairs to Euryale as her card picks up marks. Boss night is its own shape.
-- Engine-free; it drives game/model/night.lua's methods (the night is passed in, never required).

local content = require "game.model.content"
local util = require "game.model.util"
local score = require "game.model.score"
local adventure = require "game.model.adventure"
local prep_mod = require "game.model.prep"
local map_repo = require "game.model.map_repo"

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
    v.painting = port and port.painting or "a frosty mountain portrait"
    v.gift = port and port.gift or "a painted scimitar"
    return v
end

-- Building a room's scene -------------------------------------------------------------------------

function M.build_scene(night, id)
    local r = MODULE.rooms[id]
    local comps = {}
    for kind, cid in pairs(r.comps or {}) do
        comps[kind] = content.components[cid]
    end
    local pm = night.prep and night.prep.museum
    local prepped = pm and pm.prepped and pm.prepped[id] or false
    if id == "lair" and pm and pm.boss then
        prepped = true          -- (boss week's hours already went on the lair: museum_week.spent)
    end
    if MODULE.rooms[id].epilogue then
        prepped = true
    end
    local q = r.virtual and 0.6 or prep_mod.quality(r.type, comps, night.prep and night.prep.inspired or {})
    local sc = {
        type = r.type, comps = comps, missing = {}, room = id, quick = r.quick, virtual = r.virtual,
        prepped = prepped or r.virtual,
        quality = q - ((prepped or r.virtual or r.cost == 0) and 0 or MODULE.UNPREPPED_QUALITY),
        difficulty = prep_mod.difficulty(comps),
        optional_fight = r.optional_fight,
        boss = r.boss,
        epilogue = r.epilogue,
        rest_here = r.rest or nil,
    }
    if r.encounter then
        sc.encounter = { ids = util.copy(r.encounter), boss_name = r.boss_name, built = true }
    end
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

function M.bank(night, n, why)
    local st = st_of(night)
    st.bank = math.max(0, (st.bank or 0) + n)
    night:emit({ kind = "warning", bank = st.bank, why = why })
    night:say(why .. " Fair warning in the bank: " .. util.int(st.bank) .. ".", "aside")
end

function M.harsh(night, sc)
    local st = st_of(night)
    local mus = night.mus
    mus.harsh_tonight = (mus.harsh_tonight or 0) + 1
    local free = adventure.free_harsh(night.campaign) - (mus.harsh_free_used or 0)
    local earned = false
    if free > 0 then
        mus.harsh_free_used = (mus.harsh_free_used or 0) + 1
        earned = true
    elseif (st.bank or 0) > 0 then
        st.bank = st.bank - 1
        earned = true
    end
    if earned then
        st.harsh.paid = st.harsh.paid + 1
        night:say("It stings, but nobody argues. They knew the risk.", "good")
        night:apply({ { "arch:butt_kicker", fun = 3 }, { "arch:instigator", fun = 3 }, { "all", challenge = 4 } })
        night:emit({ kind = "warning", bank = st.bank, spent = true })
    else
        st.harsh.unpaid = st.harsh.unpaid + 1
        night:say("That came out of nowhere. Somebody mutters about it, and the table goes quiet.", "bad")
        for _, p in ipairs(night.players) do
            score.add(p, "trust", -3)
            night:suspect(p, 2, "a harsh call with no warning")
        end
        night:apply({ { "all", fun = -3 } })
        night:emit({ kind = "warning", bank = st.bank, unearned = true })
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
    local added = adventure.apply(c, mus, sc and sc.room)
    for _, id in ipairs(added) do
        table.insert(night.mus.pending, id)
    end
    if mus.flag == "notebook" then
        st.flags.notebook = true
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
    if sc then
        if mus.fight then
            sc.fight_on = true
        end
        if mus.no_fight then
            sc.no_fight = true
            sc.fight_on = nil
            if sc.room ~= "paintings" then
                sc.resolved = true      -- the room's done without a fight (the ritual)
                sc.outcome = sc.outcome or "win"
                sc.had_roll = true
            end
        end
        if mus.drop then
            drop_from(sc, mus.drop)
        end
        if mus.resolve then
            sc.resolved = true
            sc.outcome = mus.resolve
            sc.had_roll = true
        end
        if mus.ending then
            st.ending = mus.ending
            sc.outcome = "win"
            sc.resolved = true
            sc.had_roll = true
            sc.fight_on = nil
        end
    end
    if mus.risk then
        M.bank(night, 1, "They took that chance knowingly.")
    end
    if mus.warn then
        M.bank(night, 1, "You warned them.")
        night:apply({ { "arch:butt_kicker", challenge = -2 } })
    end
    if mus.harsh then
        M.harsh(night, sc)
    end
end

-- Moments -----------------------------------------------------------------------------------------

local function option_ok(night, o)
    local c = night.campaign
    local knobs = knobs_of(night)
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
    copy.trigger = copy.trigger or "museum"
    copy.options = {}
    for _, o in ipairs(card.options) do
        if option_ok(night, o) then
            local oc = o
            if o.price and (st.francs or 0) < o.price then
                oc = {}
                for k, v in pairs(o) do
                    oc[k] = v
                end
                oc.disabled = true
                oc.label = o.label .. " (not enough Francs)"
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
    end
    night.mus_vars = mus_vars(night, sc)
    local o = night:decision(copy, night.mus_vars)
    if not o then
        return nil
    end
    M.handle(night, o.mus, sc)
    local got = gained(o.mus)
    if o.roll then
        local out = night.last_roll and o.roll.success or o.roll.fail
        M.handle(night, out and out.mus, sc)
        got = out ~= nil and gained(out.mus) and night.last_roll and true or false
    end
    st.seen[card.id] = true
    if got then
        st.took[card.id] = true
    end
    return o
end

function M.moments(night, sc, at)
    if night.end_early then
        return
    end
    local knobs = knobs_of(night)
    for _, m in ipairs(MODULE.moments) do
        if m.room == sc.room and (m.at or "start") == at and adventure.test(night.campaign, m.when, knobs)
            and not (m.unless and adventure.test(night.campaign, m.unless, knobs)) then
            M.play_moment(night, m, sc)
            if night.end_early then
                return
            end
        end
    end
end

-- A room starts: its read-aloud, the heroes it was made for, and how the DM chose to run it.
function M.read(night, sc)
    local r = MODULE.rooms[sc.room]
    night:say(r.read, "narration")
    if not sc.prepped then
        night:say("You never read this room properly. You skim the page while they wait.", "warn")
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
            for key, v in pairs(k.like or {}) do
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
            night:say(p.name .. " sits up. This is what " .. p.char .. " came to the museum for.", "thread")
            score.add(p, "investment", 3)
            score.add(p, "fun", 4)
            local st = c.adv
            st.aspects = st.aspects or {}
            st.aspects[p.key] = st.aspects[p.key] or {}
            table.insert(st.aspects[p.key], 1, "Came for " .. util.lower_first(h.name) .. ", and found it in "
                .. util.lower_first(MODULE.rooms[sc.room].name))
            night:highlight(6, p.char .. " finds what they came for: " .. util.lower_first(h.name), { p }, "thread")
        end
    end
    M.moments(night, sc, "start")
    if sc.showdown then
        M.showdown_start(night, sc)
    end
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
    night:emit({ kind = "scene", index = sc.index, title = sc.title, type = sc.type,
                 board = night:board_for(sc), type_name = content.scenes[sc.type].name, terrain = sc.terrain,
                 party = party, npc = npc, npc_hidden = npc ~= nil, cast = cast and cast.name,
                 goal = goal and goal.name })
    night.npc_pending = npc ~= nil or nil
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
        night:note_meeting(sc)
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
        night:do_rest({ rest = "short" }, "short", "town", sc)
    end
    if not sc.virtual then
        night:settle_scene(sc)
    else
        sc.outcome = sc.outcome or "win"
    end
    M.moments(night, sc, "end")
    local r = sc.comps.reward
    if r and sc.outcome == "win" and not night.end_early then
        night:say("They earn " .. util.lower_first(r.line), "reward")
    end
    if not sc.virtual and not night.end_early then
        night:emit({ kind = "scene_end", index = sc.index, title = sc.title,
                     type_name = content.scenes[sc.type] and content.scenes[sc.type].name or nil,
                     goal = sc.comps.goal and sc.comps.goal.name or nil, outcome = sc.outcome,
                     reward = r and sc.outcome == "win" and util.capitalize(r.got or r.name) or nil,
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

local function want_new(p, id, c, steps, floor_left)
    local n = want(p, id, c) - 0.6 * math.max(0, (steps or 1) - 1)
    if id == "stairs" then
        n = n + 1.5 * score.arch(p, "butt_kicker")
            - floor_left * (1.2 * score.arch(p, "explorer") + 0.8 * score.arch(p, "storyteller") + 0.4)
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
                elseif (st.francs or 0) >= 3 and not night.mus.shopped then
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
        night:emit({ kind = "scene_end", index = sc.index, title = sc.title, outcome = "win" })
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
    -- Each friend's first choice (a little noise: people are people).
    local first, by = {}, {}
    for _, p in ipairs(night.players) do
        local best, bv
        for i, ch in ipairs(choices) do
            local v = (ch.back and want_back(p, ch.back, night)) or (ch.side and want_side(p, ch.side))
                or want_new(p, ch.id, c, ch.steps, floor_left)
            v = v + night.rng:next() * 0.6
            if not bv or v > bv then
                best, bv = i, v
            end
        end
        first[p.key] = best
        by[best] = by[best] or {}
        table.insert(by[best], p)
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
    local parts = {}
    for i, ch in ipairs(choices) do
        local names = {}
        for _, p in ipairs(by[i] or {}) do
            table.insert(names, p.name)
        end
        if ch.side then
            if #names > 0 then
                table.insert(parts, util.join_names(names) .. (#names == 1 and " wants " or " want ") .. "to poke into "
                    .. ch.side.name .. ".")
            end
        elseif ch.back then
            local line = MODULE.revisit_why[ch.back.why]
            if line and (#names > 0 or ch.back.why == "hint") then
                table.insert(parts, util.fill(line, { names = util.join_names(names), want = #names == 1 and "wants" or "want",
                                                     room = util.lower_first(MODULE.rooms[ch.id].name) }))
            end
        elseif #names > 0 then
            table.insert(parts, util.join_names(names) .. (#names == 1 and " wants " or " want ") .. pull_of(ch.id).want .. ".")
        end
    end
    local pm = night.prep and night.prep.museum
    local card = { id = "mus_fork_" .. key, type = "story", trigger = "museum", title = fk.title,
                   actor = { "instigator", "explorer", "butt_kicker" },
                   text = fk.text .. " " .. table.concat(parts, " "), options = {} }
    -- What the table wants most, first (following them is the top option).
    local order = {}
    for i in ipairs(choices) do
        table.insert(order, i)
    end
    table.sort(order, function(a, b)
        local na, nb = #(by[a] or {}), #(by[b] or {})
        if na ~= nb then
            return na > nb
        end
        return a < b
    end)
    for _, i in ipairs(order) do
        local ch = choices[i]
        local effs = {}
        for _, p in ipairs(night.players) do
            table.insert(effs, { "key:" .. p.key, fun = (first[p.key] == i) and 3 or -2 })
        end
        local steer = i ~= top and #(by[i] or {}) < top_n
        if steer and (night.mus.steered or 0) >= 1 then
            table.insert(effs, { "all", trust = -2 })
        end
        local label
        if ch.side then
            label = "Into " .. ch.side.name .. " (a side room)"
        elseif ch.back then
            label = back_label(ch.back)
        else
            local r = MODULE.rooms[ch.id]
            local note = (r.cost == 0 and "") or ((pm and pm.prepped and pm.prepped[ch.id]) and "  (you prepped it)" or "  (not prepped)")
            label = pull_of(ch.id).label .. note
        end
        table.insert(card.options, { label = label, effects = effs, choice = i, steer = steer,
                                     log = steer and "You nudge them the other way. A couple of looks across the table." or nil })
    end
    -- The DM's own move: a hint that a room they cleared still has something in it.
    if not night.mus.hinted and (night.mus.backs or 0) < M.MAX_BACKS then
        for _, id in ipairs(MODULE.order) do
            local cl = select(2, adventure.reachable(c, pos or id))
            if cl[id] and not st.hinted[id] and #adventure.missed(c, id) > 0 and not (night.mus.been or {})[id] then
                table.insert(card.options, {
                    label = "Hint they missed something in " .. util.lower_first(MODULE.rooms[id].name),
                    effects = { { "arch:explorer", fun = 4 }, { "arch:butt_kicker", fun = -1 } },
                    log = "\"You know, you never did look properly at " .. util.lower_first(MODULE.rooms[id].name)
                        .. ".\" Someone groans. Someone grabs their pencil.",
                    hint = id })
                break
            end
        end
    end
    local o = night:decision(card)
    if o and o.hint then
        night.mus.hinted = true
        st.hints[o.hint] = true
        st.hinted[o.hint] = true
        return { back = { id = o.hint, why = "hint", steps = (select(2, adventure.reachable(c, pos)))[o.hint] or 1 } }
    end
    if o and o.steer then
        night.mus.steered = (night.mus.steered or 0) + 1
        if night.mus.steered >= 2 then
            night:say("Twice tonight you've steered them. It's starting to feel like a railroad.", "warn")
        end
    end
    local ch = choices[(o and o.choice) or top] or choices[1]
    -- The friend who runs off (the BBQ story): the instigator, outvoted, heads for the stairs alone.
    local jess = present(night, "jess")
    if not ch.back and not ch.side and ch.id == "stairs" and jess and not st.flags.seen and night.rng:chance(0.6) then
        st.flags.pip_alone = true
    end
    if ch.side then
        return { side = ch.side }
    end
    if ch.back then
        return { back = ch.back }
    end
    return { id = ch.id }
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
            night:do_rest({ rest = "short" }, "short", "town", sc)
        end
    end
    sc.outcome = "win"
    sc.had_roll = true
    if not night.end_early then
        night:emit({ kind = "scene_end", index = sc.index, title = sc.title, outcome = "win" })
    end
    table.insert(night.mus.rooms, { room = b.id, outcome = "win", back = b.why })
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

local function fled_count(sc)
    local res = sc.result
    if not res then
        return 0
    end
    if res.fled then
        return type(res.fled) == "table" and #res.fled or tonumber(res.fled) or 0
    end
    return 0
end

function M.after_room(night, sc)
    local c = night.campaign
    local st = st_of(night)
    local id = sc.room
    local outcome = sc.outcome or "win"
    local function mark(m)
        if adventure.add_mark(c, m, id) then
            table.insert(night.mus.pending, m)
        end
    end
    if id == "garden" and sc.fought and outcome ~= "win" then
        mark("topiary")
    elseif id == "chamber" and sc.fought then
        mark("scarabs")
    elseif id == "hunting" then
        local n = fled_count(sc)
        if n > 0 then
            st.pack = n
            mark("pack")
        end
    elseif id == "lecture" then
        if outcome == "win" then
            st.flags.pages = true
            mark("pages")
        else
            mark("drone")
        end
    elseif id == "offices" and outcome == "win" then
        st.flags.notebook = true
    elseif id == "gift_shop" then
        st.flags.rested_shop = true
    end
    table.insert(night.mus.rooms, { room = id, outcome = outcome })
    adventure.leave_room(c, id, outcome, c.week)
    M.interlude(night, sc)
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
            night:emit({ kind = "mark", id = id, name = m.name, why = m.why, showdown = m.showdown, thought = m.thought })
            night:say("Upstairs, Euryale: \"" .. m.thought .. "\"", "interlude")
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
    night:say("Everyone's here. Dice out.", "system")
    night:table_behavior("start")
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
        local lines = adventure.story_so_far(c)
        local bits = {}
        for i = math.max(1, #lines - 2), #lines do
            table.insert(bits, lines[i].text)
        end
        if #bits > 0 then
            night:say("Last time: " .. table.concat(bits, "; ") .. ".", "recap")
        end
        if night.campaign.last_cliff then
            night:say("They stopped mid-museum, with " .. night.campaign.last_cliff .. " still ahead.", "recap")
        end
        local last = st.last_room and MODULE.rooms[st.last_room]
        if last and last.part ~= part then
            night:say(MODULE.openings[part] or MODULE.openings[1], "opening")
        elseif first and MODULE.rooms[first] then
            night:say("They pick up right where they stopped: " .. util.lower_first(MODULE.rooms[first].name) .. ".", "opening")
        else
            night:say("They pick up right where they stopped, at a fork in the museum.", "opening")
        end
    end
    night:say(night.rng:pick(MODULE.thoughts.open), "interlude")
end

-- When time runs out before a room: stop here, next week picks up.
function M.out_of_time(night, next_name)
    night:say("You glance at the clock: " .. night:clock_text() .. ". \"And that's where we stop tonight.\" "
        .. (next_name and (next_name .. " will have to wait for next week.") or ""), "dm")
    night.campaign.last_cliff = next_name and util.lower_first(next_name) or nil
    night.ended_on_cliff = true
end

-- Into a room: anything that leaves behind for good marks her card (the lair, for rooms unseen).
function M.enter(night, id)
    local c = night.campaign
    local left = adventure.enter_room(c, id, c.week)
    for _, lid in ipairs(left) do
        local lb = MODULE.left_behind[lid]
        if lb and lb.mark and adventure.add_mark(c, lb.mark, lid) then
            table.insert(night.mus.pending, lb.mark)
        end
    end
    return left
end

function M.play(night, id)
    local c = night.campaign
    local st = st_of(night)
    M.enter(night, id)
    local sc = M.build_scene(night, id)
    table.insert(night.scenes, sc)
    sc.index = #night.scenes
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
    return sc
end

function M.run(night)
    local c = night.campaign
    local st = st_of(night)
    st.weeks = (st.weeks or 0) + 1
    night.scenes = {}
    night.mus = { added = {}, pending = {}, rooms = {}, harsh_log = {}, bank_start = st.bank }
    local ahead = adventure.ahead(c)
    night.mus.total = math.max(1, #ahead)
    c.last_cliff = nil
    M.intro(night)
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
                break
            end
            local nxt = MODULE.rooms[options[1] or (backs[1] or sides[1]).id]
            if nxt.boss then
                break
            end
            if #night.scenes > 0 and night.table_min > night.table_planned - M.STOP_BEFORE_END and #options > 0 then
                -- One room left on the floor before the stairs: finish the floor tonight rather than
                -- leave next week a night of one room and a staircase (a little late is the lesser evil).
                local rest = {}
                for _, oid in ipairs(options) do
                    if oid ~= "stairs" then
                        table.insert(rest, oid)
                    end
                end
                local last_one = util.contains(options, "stairs") and #rest == 1
                    and night.table_min <= night.table_planned + M.FINISH_FLOOR
                if not last_one then
                    M.out_of_time(night, #options == 1 and nxt.name or "the next room")
                    break
                end
                night:say("You glance at the clock. One room left before the stairs. \"Let's finish the floor.\"", "dm")
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
            end
            if pick.side then
                M.side_room(night, pick.side)
            elseif pick.back then
                M.go_back(night, pick.back)
            else
                local id = pick.id
                local r = MODULE.rooms[id]
                M.play(night, id)
                if r.stop and (id == "stairs" or #night.scenes >= 3 or night.table_min > night.table_planned * 0.55) then
                    break
                elseif r.stop then
                    night:say("They catch their breath, check their packs, and keep going.", "dm")
                end
            end
            if #night.scenes > 0 then
                night:clock_tells()
            end
        end
    end
    night:run_tail()
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
    if boss.opener == "ambush" then
        night:say("No drink, no questions. An arrow is already on the string when they reach the top step.", "bad")
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
        -- She's agreed, but what the build-up brought her hasn't: the marks still come to the fight.
        table.remove(sc.encounter.ids, 1)
        sc.encounter.boss_name = nil
        sc.resolved, sc.had_roll = nil, nil
        sc.fight_on = true
        sc.extras_only = true
        night:say("Euryale steps back with a little shrug. \"I agreed. They didn't.\" Behind her, the things she collected come forward.", "bad")
    end
end

-- The book's ending, played as boss night's last scene: back in the gift shop with Flitwidget, the
-- reward, and the first hint of what comes next. Not a room on the map.
function M.thanks(night)
    if night.end_early then
        return
    end
    local sc = M.build_scene(night, "thanks")
    table.insert(night.scenes, sc)
    sc.index = #night.scenes
    night.mus.total = #night.scenes
    night:play_scene(sc)
    if not night.end_early then
        table.insert(night.mus.rooms, { room = "thanks", outcome = "win" })
    end
end

function M.after_showdown(night, sc)
    local c = night.campaign
    local st = st_of(night)
    local boss = st.boss or {}
    if not st.ending then
        if sc.fought and sc.outcome == "win" then
            if boss.style ~= "last" then
                M.play_moment(night, MODULE.showdown.yield, sc)
            end
            st.ending = st.ending or "fallen"
        elseif sc.fought then
            night:say("They tumble back down the stairs with her laughter behind them. She lets them go. She wants them to come back.", "bad")
            night:say("They limp out of the caravan, sleep for a day, and come back angry.", "dm")
            sc.rest_here = true      -- (home to rest: next week's try starts whole, not where this one broke)
            st.at, st.choices = "lair", nil
            st.lost_once = true
            return
        end
    end
    local e = st.ending and MODULE.endings[st.ending]
    table.insert(night.mus.rooms, { room = "lair", outcome = e and "win" or "lose" })
    if e then
        night:say(e.line, "good")
        night:emit({ kind = "npc", name = "Flitwidget", cast = "mus_flitwidget", text = (string.gsub(e.flit, "^\"(.*)\"$", "%1")) })
        st.done.lair = "win"
        table.insert(st.path, { room = "lair", week = c.week, outcome = "win" })
        st.at, st.choices = nil, nil
        M.thanks(night)
        for _, line in ipairs(MODULE.epilogue) do
            night:say(line, "narration")
        end
        for _, p in ipairs(night.players) do
            local lines = MODULE.want_more[p.key]
            if lines then
                night:emit({ kind = "say", who = p.key, text = night.rng:pick(lines), ic = false })
                score.add(p, "commitment", 5)
                score.add(p, "investment", 4)
            end
        end
    end
end

return M
