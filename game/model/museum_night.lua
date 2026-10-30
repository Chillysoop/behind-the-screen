-- Game night in the museum (v2): the night walks the module's map room by room until the evening
-- runs out or the party reaches a natural stop, asks the DM at each fork, plays each room's own
-- moments, and cuts upstairs to Euryale as her card picks up marks. Boss night is its own shape.
-- Engine-free; it drives game/model/night.lua's methods (the night is passed in, never required).

local content = require "game.model.content"
local util = require "game.model.util"
local score = require "game.model.score"
local adventure = require "game.model.adventure"
local prep_mod = require "game.model.prep"

local MODULE = adventure.data
local M = {}

M.STOP_BEFORE_END = 25     -- table minutes: no new room this close to the agreed end

local function present(night, key)
    for _, p in ipairs(night.players) do
        if p.key == key then
            return p
        end
    end
end

local function st_of(night)
    return night.campaign.adv
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
    local q = r.virtual and 0.6 or prep_mod.quality(r.type, comps, night.prep and night.prep.inspired or {})
    local sc = {
        type = r.type, comps = comps, missing = {}, room = id, quick = r.quick, virtual = r.virtual,
        prepped = prepped or r.virtual,
        quality = q - ((prepped or r.virtual or r.cost == 0) and 0 or MODULE.UNPREPPED_QUALITY),
        difficulty = prep_mod.difficulty(comps),
        optional_fight = r.optional_fight,
        boss = r.boss,
        rest_here = r.rest or nil,
    }
    if r.encounter then
        sc.encounter = { ids = util.copy(r.encounter), boss_name = r.boss_name, built = true }
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
    if o.roll then
        local out = night.last_roll and o.roll.success or o.roll.fail
        M.handle(night, out and out.mus, sc)
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
function M.quick_room(night, sc)
    night.scene = sc
    night.actor, night.other = nil, nil
    if not sc.virtual then
        sc.terrain = night:terrain_for(sc)
        sc.title = night:scene_title(sc)
        local party, npc = night:staging(sc)
        local cast, goal = sc.comps.cast, sc.comps.goal
        night.stage_now = { terrain = sc.terrain, board = night:board_for(sc), party = party, npc = npc }
        night:board_set(night:board_for(sc), sc)
        night:emit({ kind = "scene", index = sc.index, title = sc.title, type = sc.type,
                     board = night:board_for(sc), type_name = content.scenes[sc.type].name, terrain = sc.terrain,
                     party = party, npc = npc, npc_hidden = npc ~= nil, cast = cast and cast.name,
                     goal = goal and goal.name })
        night.npc_pending = npc ~= nil or nil
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

local function want(p, id, c)
    local pl = MODULE.pull[id]
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

function M.fork(night, options)
    local c = night.campaign
    local st = st_of(night)
    -- Each friend's first choice (a little noise: people are people).
    local first, by_room = {}, {}
    for _, p in ipairs(night.players) do
        local best, bv
        for _, id in ipairs(options) do
            local v = want(p, id, c) + night.rng:next() * 0.6
            if not bv or v > bv then
                best, bv = id, v
            end
        end
        first[p.key] = best
        by_room[best] = by_room[best] or {}
        table.insert(by_room[best], p)
    end
    local top, top_n
    for _, id in ipairs(options) do
        local n = #(by_room[id] or {})
        if not top_n or n > top_n then
            top, top_n = id, n
        end
    end
    local key = "hub"
    if util.contains(options, "chamber") or util.contains(options, "paintings") then
        key = (st.done.chamber or st.done.paintings) and "second_wing" or "wings"
    end
    local fk = MODULE.forks[key]
    local parts = {}
    for _, id in ipairs(options) do
        local names = {}
        for _, p in ipairs(by_room[id] or {}) do
            table.insert(names, p.name)
        end
        if #names > 0 then
            table.insert(parts, util.join_names(names) .. (#names == 1 and " wants " or " want ")
                .. MODULE.pull[id].want .. ".")
        end
    end
    local pm = night.prep and night.prep.museum
    local card = { id = "mus_fork_" .. key, type = "story", trigger = "museum", title = fk.title,
                   actor = { "instigator", "explorer", "butt_kicker" },
                   text = fk.text .. " " .. table.concat(parts, " "), options = {} }
    for _, id in ipairs(options) do
        local effs = {}
        for _, p in ipairs(night.players) do
            local f = (first[p.key] == id) and 3 or -2
            table.insert(effs, { "key:" .. p.key, fun = f })
        end
        local steer = id ~= top and #(by_room[id] or {}) < top_n
        if steer and (night.mus.steered or 0) >= 1 then
            table.insert(effs, { "all", trust = -2 })
        end
        local r = MODULE.rooms[id]
        local note = (r.cost == 0 and "") or ((pm and pm.prepped and pm.prepped[id]) and "  (you prepped it)" or "  (not prepped)")
        table.insert(card.options, { label = MODULE.pull[id].label .. note, effects = effs, room = id, steer = steer,
                                     log = steer and "You nudge them the other way. A couple of looks across the table." or nil })
    end
    local o = night:decision(card)
    if o and o.steer then
        night.mus.steered = (night.mus.steered or 0) + 1
        if night.mus.steered >= 2 then
            night:say("Twice tonight you've steered them. It's starting to feel like a railroad.", "warn")
        end
    end
    -- The friend who runs off (the BBQ story): the instigator, outvoted, heads for the stairs alone.
    local jess = present(night, "jess")
    if o and o.room == "stairs" and jess and not st.flags.seen and night.rng:chance(0.6) then
        st.flags.pip_alone = true
    end
    return o and o.room or options[1]
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

function M.play(night, id)
    local c = night.campaign
    local st = st_of(night)
    local left = adventure.enter_room(c, id, c.week)
    for _, lid in ipairs(left) do
        local lb = MODULE.left_behind[lid]
        if lb and lb.mark and adventure.add_mark(c, lb.mark, lid) then
            table.insert(night.mus.pending, lb.mark)
        end
    end
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
            if #options == 0 then
                break
            end
            local nxt = MODULE.rooms[options[1]]
            if nxt.boss then
                break
            end
            if #night.scenes > 0 and night.table_min > night.table_planned - M.STOP_BEFORE_END then
                M.out_of_time(night, #options == 1 and nxt.name or "the next room")
                break
            end
            local id = options[1]
            if #options > 1 then
                id = M.fork(night, options)
            end
            local r = MODULE.rooms[id]
            M.play(night, id)
            if r.stop and (id == "stairs" or #night.scenes >= 3 or night.table_min > night.table_planned * 0.55) then
                break
            elseif r.stop then
                night:say("They catch their breath, check their packs, and keep going.", "dm")
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
    adventure.enter_room(c, "lair", c.week)
    local sc = M.build_scene(night, "lair")
    table.insert(night.scenes, sc)
    sc.index = 1
    night.mus.total = 1
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
            st.at, st.choices = "lair", nil
            st.lost_once = true
            return
        end
    end
    local e = st.ending and MODULE.endings[st.ending]
    table.insert(night.mus.rooms, { room = "lair", outcome = e and "win" or "lose" })
    if e then
        night:say(e.line, "good")
        night:emit({ kind = "npc", name = "Flitwidget", cast = "mus_flitwidget", text = string.gsub(e.flit, "^\"(.*)\"$", "%1") })
        for _, line in ipairs(MODULE.epilogue) do
            night:say(line, "narration")
        end
        st.done.lair = "win"
        table.insert(st.path, { room = "lair", week = c.week, outcome = "win" })
        st.at, st.choices = nil, nil
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
