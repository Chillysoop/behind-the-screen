-- M8's gates (no new sessions yet, so they run on the slice's weeks and past them): the event log
-- (B1), fun failure (B2), the moments to hand out and the headaches (B4), theories, jokes and
-- shower thoughts (B5), the villain who gets away (B6) and the big questions (B10). Plays
-- campaigns with the simulated DMs and watches every event. Run from the project root:
--   texlua tools/tests/m8_check.lua [campaigns per DM] [weeks]
-- Exit code 1 if a check fails.

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local content = require "game.model.content"
local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local stale = require "game.model.stale"
local seeds = require "game.model.seeds"
local jokes = require "game.model.jokes"
local fails = require "game.model.fails"
local ledger = require "game.model.ledger"
local questions = require "game.model.questions"
local util = require "game.model.util"
local bots = require "slice_bots"

local RUNS = tonumber(arg and arg[1]) or 10
local WEEKS = tonumber(arg and arg[2]) or 8

local checks, fails_list = {}, {}
local function check(ok, name, detail)
    table.insert(checks, { ok = ok and true or false, name = name, detail = detail or "" })
end
local function fail(msg)
    if #fails_list < 25 then
        table.insert(fails_list, msg)
    end
end

-- The shared staleness rule (B1) on its own.
do
    local item = { born = 3 }
    local ok = stale.state(item, 3, "seed") == "fresh" and stale.state(item, 4, "seed") == "ripe"
        and stale.state(item, 6, "seed") == "ripe" and stale.state(item, 7, "seed") == "stale"
    local j = { born = 2 }
    stale.use(j, 3)
    stale.use(j, 4)
    local worn = stale.freshness(j, 4, "joke") < stale.freshness({ born = 2 }, 4, "joke")
    stale.use(j, 5)
    local gone = stale.state(j, 5, "joke") == "stale"
    check(ok and worn and gone, "One staleness rule: seeds ripen and go stale on their window; jokes wear out with use (B1)",
        "seed and joke cases")
end

local T = {
    nights = 0, events = 0, event_kinds = {}, nights_with_events = 0,
    misses = 0, fans = 0, fan_bad = 0, fan_solemn = 0, fan_solemn_prat = 0, fan_open = 0, fan_open_prat = 0,
    framed_offered = 0, framed_bad = 0, nat1_player = 0, jail = 0, robbed_line = 0, defeats = 0, line_repeats = 0,
    reps = 0, kb_offered = 0, kb_cards = 0, kb_other_fair = 0, kb_other = 0, insp_given = 0, insp_spent = 0, insp_two = 0,
    headache = 0, headache_bad = 0, shower_weeks = 0, showers = 0, shower_free_bad = 0, shower_over = 0,
    theories = 0, stolen = 0, stolen_paid = 0, jokes = 0, callbacks = 0, stale_callbacks = 0,
    escapes = 0, escape_cards = 0, grudges = 0, grudge_falls = 0,
    q_min = 99, q_weeks = 0,
    deaths = 0, death_cards = 0, new_chars = 0, new_named = 0, intros = 0, scars = 0, quests = 0, quest_pinned = 0,
    fallen = 0, death_opts_bad = 0,
    talks = 0, talk_turn_bad = 0, talk_logged = 0, talk_count_bad = 0, talk_stances = {}, boss = 0, boss_two = 0,
    boss_kinds = {}, monologues = 0, mono_kinds = {}, mono_unlogged = 0, retorts = 0,
}

local SHOP = { "town", "crowd", "shop" }

for _, dm_key in ipairs(bots.ORDER) do
    local dm = bots.DMS[dm_key]
    for run = 1, RUNS do
        local seed = 21000 + run * 41 + #dm_key * 7
        local c = campaign_mod.new(seed)
        local rng = rng_mod.new(seed + 9)
        c:session_zero(dm.s0)
        local lines_seen = {}
        for w = 1, WEEKS do
            local prep = c:start_week()
            -- Shower thoughts (B5): 0 to 2, pinned, free.
            local n = #(c.showers or {})
            if n > 2 then
                T.shower_over = T.shower_over + 1
            end
            T.showers = T.showers + n
            T.shower_weeks = T.shower_weeks + 1
            for _, card in ipairs(c.showers or {}) do
                if prep:cost_of(card) ~= 0 or not prep:pinned(card.id) then
                    T.shower_free_bad = T.shower_free_bad + 1
                end
            end
            -- The careful DM steals a theory now and then (B5).
            for _, th in ipairs(seeds.pinned(c)) do
                T.theories = T.theories + 1
                if dm_key == "careful" and seeds.can_steal(c, th) then
                    if seeds.steal(c, th) then
                        T.stolen = T.stolen + 1
                    end
                end
            end
            -- New characters (B3): whoever fell plays someone new, by name, from their class's pregens.
            for _, nc in ipairs(c.new_chars or {}) do
                T.new_chars = T.new_chars + 1
                local p = c:player(nc.key)
                if p and p.char == nc.pregen.name and p.char ~= nc.was then
                    T.new_named = T.new_named + 1
                end
            end
            for key, q in pairs(c.death_quest or {}) do
                if q.card and q.week == c.week - 1 and prep:pinned(q.card) then
                    T.quest_pinned = T.quest_pinned + 1
                end
            end
            bots.prep(dm, c, prep, rng)
            local night = c:start_night()
            local insp_tonight = 0
            local talk_turns, boss_cards, dec_events, death_seen = 0, 0, 0, false
            local function watch(ev, nt)
                if ev.kind == "decision" and ev.card then
                    dec_events = dec_events + 1
                    death_seen = death_seen or ev.card.id == "hero_dies"
                    if ev.card.type == "talk" then
                        talk_turns = talk_turns + 1
                        if string.sub(ev.card.id, 1, 5) == "talk_" and #ev.card.options ~= 3 then
                            T.talk_turn_bad = T.talk_turn_bad + 1
                        end
                        for _, o in ipairs(ev.card.options) do
                            if string.find(o.label, "{", 1, true) then
                                T.talk_turn_bad = T.talk_turn_bad + 1
                                fail("an unfilled talk line: " .. o.label)
                            end
                        end
                    elseif ev.card.type == "boss" then
                        boss_cards = boss_cards + 1
                    end
                end
                if ev.kind == "ruling" and ev.fan then
                    T.fans = T.fans + 1
                    local kinds, n_cards, flat, framed = {}, 0, false, false
                    for _, o in ipairs(ev.options) do
                        if o.kind == "flat" then
                            flat = true
                        elseif o.kind == "framed" then
                            framed = true
                        elseif o.kind then
                            n_cards = n_cards + 1
                            if kinds[o.kind] then
                                T.fan_bad = T.fan_bad + 1
                            end
                            kinds[o.kind] = true
                            if lines_seen[o.label] and c.week - lines_seen[o.label] < 3 and lines_seen[o.label] ~= c.week then
                                T.line_repeats = T.line_repeats + 1
                                fail("week " .. c.week .. ": a fail line from week " .. lines_seen[o.label] .. " again: " .. o.label)
                            end
                        end
                    end
                    if n_cards ~= 3 or not flat then
                        T.fan_bad = T.fan_bad + 1
                        fail("a fan with " .. n_cards .. " cards" .. (flat and "" or " and no flat fail"))
                    end
                    local p = nt.actor
                    if framed then
                        T.framed_offered = T.framed_offered + 1
                        if not p or (p.trust or 0) < fails.data.FRAME_TRUST then
                            T.framed_bad = T.framed_bad + 1
                        end
                    end
                    local solemn = fails.solemn(nt, nt.scene)
                    if solemn then
                        T.fan_solemn = T.fan_solemn + 1
                        T.fan_solemn_prat = T.fan_solemn_prat + (kinds.pratfall and 1 or 0)
                    else
                        T.fan_open = T.fan_open + 1
                        T.fan_open_prat = T.fan_open_prat + (kinds.pratfall and 1 or 0)
                    end
                elseif ev.kind == "narrate" and ev.text and string.find(ev.text, "robbed and very much alive", 1, true) then
                    T.robbed_line = T.robbed_line + 1
                elseif ev.kind == "decision" and ev.card then
                    local id = ev.card.id
                    if id == "hero_dies" then
                        T.death_cards = T.death_cards + 1
                        -- The options follow the mode that applies to that player.
                        local death = require "game.model.death"
                        local mode = death.mode_for(c, nt.actor and nt.actor.key)
                        local want = (mode == "cost") and 3 or 2
                        if #ev.card.options ~= want then
                            T.death_opts_bad = T.death_opts_bad + 1
                        end
                    elseif id == "killing_blow" then
                        T.kb_cards = T.kb_cards + 1
                    elseif id == "escape_earned" or id == "escape_cheap" then
                        T.escape_cards = T.escape_cards + 1
                    end
                    local def
                    for _, d in ipairs(content.decisions) do
                        if d.id == id then
                            def = d
                        end
                    end
                    if def and def.headache then
                        T.headache = T.headache + 1
                        if def.needs and not nt:headache_ok(def.needs, nt.scene) then
                            T.headache_bad = T.headache_bad + 1
                            fail("headache " .. id .. " without its situation")
                        end
                        if id == "shopping" then
                            local been = false
                            for _, s2 in ipairs(nt.scenes) do
                                if s2 == nt.scene or s2.outcome then
                                    local loc = s2.comps.location
                                    for _, set in ipairs(loc and loc.setting or {}) do
                                        been = been or util.contains(SHOP, set)
                                    end
                                    been = been or s2.type == "downtime"
                                end
                            end
                            if not been then
                                T.headache_bad = T.headache_bad + 1
                                fail("shopping without any shopping")
                            end
                        end
                    end
                elseif ev.kind == "token" and not ev.spent then
                    insp_tonight = insp_tonight + 1
                end
            end
            bots.play_night(night, rng, dm, watch)
            -- Taking over (B8): once a night each, two turns of talk, counted as one card.
            local w = night.took_talk_with
            if talk_turns > 0 and w and w.monologue then
                -- A villain's monologue: one or two turns, and the taunt goes in the log.
                T.monologues = T.monologues + 1
                T.mono_kinds[w.picked] = (T.mono_kinds[w.picked] or 0) + 1
                if talk_turns > 2 then
                    T.talk_turn_bad = T.talk_turn_bad + 1
                    fail("a monologue with " .. talk_turns .. " turns")
                end
                if #night:events("taunt") ~= 1 then
                    T.mono_unlogged = T.mono_unlogged + 1
                end
            elseif talk_turns > 0 then
                T.talks = T.talks + 1
                if talk_turns ~= 2 then
                    T.talk_turn_bad = T.talk_turn_bad + 1
                    fail("a talk with " .. talk_turns .. " turns")
                end
                if w then
                    T.talk_stances[w.second] = (T.talk_stances[w.second] or 0) + 1
                end
                for _, e in ipairs(night.ledger) do
                    if e.voiced and e.did and string.sub(e.did, 1, 5) == "talk_" then
                        T.talk_logged = T.talk_logged + 1
                    end
                end
            end
            for _, e in ipairs(night:events("retort")) do
                T.retorts = T.retorts + 1
            end
            if boss_cards > 0 then
                T.boss = T.boss + 1
                if boss_cards > 1 then
                    T.boss_two = T.boss_two + 1
                end
                for _, e in ipairs(night:events("boss_turn")) do
                    T.boss_kinds[e.kind] = (T.boss_kinds[e.kind] or 0) + 1
                end
            end
            if not death_seen and dec_events - (talk_turns > 1 and 1 or 0) ~= night.counts.decision then
                T.talk_count_bad = T.talk_count_bad + 1
                fail("week " .. c.week .. ": " .. dec_events .. " cards shown, " .. night.counts.decision .. " counted")
            end
            if insp_tonight > 1 then
                T.insp_two = T.insp_two + 1
            end
            -- The event log (B1).
            local evs = night:events()
            T.nights = T.nights + 1
            T.events = T.events + #evs
            if #evs > 0 then
                T.nights_with_events = T.nights_with_events + 1
            end
            for _, e in ipairs(evs) do
                T.event_kinds[e.ev] = (T.event_kinds[e.ev] or 0) + 1
                if e.ev == "fail_card" then
                    lines_seen["x"] = nil
                elseif e.ev == "jail" then
                    T.jail = T.jail + 1
                elseif e.ev == "defeat" then
                    T.defeats = T.defeats + 1
                elseif e.ev == "inspiration" then
                    if e.spent then
                        T.insp_spent = T.insp_spent + 1
                    else
                        T.insp_given = T.insp_given + 1
                    end
                elseif e.ev == "killing_blow" then
                    T.kb_offered = T.kb_offered + 1
                elseif e.ev == "death" then
                    T.deaths = T.deaths + 1
                elseif e.ev == "new_character" then
                    T.intros = T.intros + 1
                elseif e.ev == "escape" then
                    T.escapes = T.escapes + 1
                elseif e.ev == "joke" then
                    T.callbacks = T.callbacks + 1
                    T.stale_callbacks = T.stale_callbacks + (e.stale and 1 or 0)
                elseif e.ev == "theory" then
                    T.stolen_paid = T.stolen_paid + 1
                elseif e.ev == "reputation" then
                    T.reps = T.reps + 1
                elseif e.ev == "villain_falls" and e.weight and e.weight >= 10 then
                    T.grudge_falls = T.grudge_falls + 1
                end
            end
            for _, r in ipairs(night.rulings) do
                if r.fail then
                    -- remember the lines the fan offered this week
                end
            end
            -- Every fan option this week, for the repeat check next weeks.
            for _, e in ipairs(evs) do
                if e.ev == "fail_card" and e.kind ~= "flat" then
                    T.misses = T.misses + 1
                end
            end
            -- The killing blow's "other": nobody with more killing blows in the window than the actor.
            local rep = c:finish_night()
            T.jokes = T.jokes + #(rep.jokes or {})
            if dm.level and rep.level and rep.level.ready then
                c:level_up()
            end
            -- The three clue rule (B10): every big question keeps three roads to it.
            for _, st in ipairs(questions.all(c)) do
                T.q_min = math.min(T.q_min, st.found + st.out)
            end
            T.q_weeks = T.q_weeks + 1
            if w == WEEKS then
                T.fallen = T.fallen + #(c.fallen or {})
                for _, p in ipairs(c.players) do
                    T.scars = T.scars + (p.scar and 1 or 0)
                end
            end
            for pid in pairs(ledger.get(c).people) do
                if ledger.grudge_level(c, pid) > 0 then
                    T.grudges = T.grudges + 1
                end
            end
        end
    end
end

-- Villains who remember (the villain monologues idea): the ledger, fuel and salt, Vendetta, the
-- fan, staleness, last words and the retort, on a hand-built night.
do
    local villains = require "game.model.villains"
    local V = {}
    local c = campaign_mod.new(9191)
    c:session_zero(bots.DMS.careful.s0)
    local prep = c:start_week()
    bots.prep(bots.DMS.careful, c, prep, rng_mod.new(3))
    local night = c:start_night()
    local pid = "wolf_lieutenant"
    local ps = night.players
    -- Lines go out through the night's coroutine: run the checks inside one.
    local co = coroutine.create(function()
    local a, b2, c3 = ps[1], ps[2], ps[3]
    -- Backstories their people scarred before the campaign (Brannoc's village is the warband's).
    local hook = false
    for _, e in ipairs(villains.ledger(c, pid, night)) do
        hook = hook or (e.type == "backstory" and e.key == "dev" and e.pre)
    end
    V.hook = hook
    -- Knockdowns in front of the villain, and two deaths: one fair, one not.
    night.villain_here = pid
    for _ = 1, 3 do
        night:event("down", { who = a.key })
    end
    night.villain_here = nil
    night:event("down", { who = b2.key })          -- no villain there: not theirs to remember
    c.deaths = { { key = b2.key, char = b2.char, week = 1, slain_by = pid, fair = true },
                 { key = c3.key, char = c3.char, week = 1, slain_by = pid, fair = false } }
    local L = villains.ledger(c, pid, night)
    local kd, other_kd, fair, unfair
    for _, e in ipairs(L) do
        if e.type == "knockdown" and e.key == a.key then kd = e end
        if e.type == "knockdown" and e.key == b2.key then other_kd = e end
        if e.type == "killed" and e.key == b2.key then fair = e end
        if e.type == "killed" and e.key == c3.key then unfair = e end
    end
    V.ledger = kd ~= nil and kd.count == 3 and kd.repeated and other_kd == nil and fair ~= nil and unfair ~= nil
    -- Fuel and salt.
    local t0 = c3.trust
    local f1 = villains.land(night, pid, fair, "full")
    local f2 = villains.land(night, pid, unfair, "full")
    V.fuel = f1.fuel and villains.vendetta(c, pid, b2.key) >= 2
    V.salt = not f2.fuel and c3.trust < t0 and villains.vendetta(c, pid, c3.key) == 0
    -- An Off limits backstory is always salt.
    local dev = nil
    for _, p in ipairs(ps) do if p.key == "dev" then dev = p end end
    if dev then
        villains.set_boundary(c, "dev", "off")
        local be
        for _, e in ipairs(L) do if e.type == "backstory" and e.key == "dev" then be = e end end
        local td = dev.trust
        local f3 = villains.land(night, pid, be, "full")
        V.off = not f3.fuel and dev.trust <= td - 4
        villains.set_boundary(c, "dev", nil)
    else
        V.off = true
    end
    -- The third use of the same memory in one session is a flat line.
    villains.land(night, pid, kd, "full")
    V.fresh2 = villains.freshness(c, pid, kd)
    villains.land(night, pid, kd, "full")
    V.flat = villains.freshness(c, pid, kd) == 0
    -- The fan: three cards at low Grudge, four at Grudge 4 or more, never fewer than three.
    V.fan = #villains.fan(night, pid, 3) == 3 and #villains.fan(night, "nobody_at_all", 3) == 3
    -- Last words come from the biggest unanswered taunt; a retort answers it, once.
    local s = villains.state(c, pid)
    s.taunts = { { id = fair.id, key = b2.key, type = "killed", sting = 10, fallen = b2.char, text = "x", week = 1 },
                 { id = kd.id, key = a.key, type = "knockdown", sting = 5, text = "y", week = 1 } }
    local big = villains.last_words(night, pid)
    V.last = big ~= nil and big.id == fair.id
    local r = villains.retort(night, pid, b2)
    V.retort = r ~= nil and villains.open_taunt(c, pid, b2.key) == nil and villains.retort(night, pid, b2) == nil
    local again = false
    for _, e in ipairs(villains.fan(night, pid, 4)) do
        again = again or e.id == fair.id
    end
    V.closed = not again
    end)
    while coroutine.status(co) ~= "dead" do
        local ok, err = coroutine.resume(co, 1)
        if not ok then
            fail("villain checks: " .. tostring(err))
            break
        end
    end
    check(V.hook and V.ledger, "A villain's ledger holds what they were there for, and the backstories their people scarred",
        "knockdowns counted, deaths kept, the warband's village on Brannoc's page")
    check(V.fuel and V.salt and V.off, "A fair death taunted is fuel (Vendetta); an unfair one, or an Off limits backstory, is salt (Trust)",
        "fuel " .. tostring(V.fuel) .. ", salt " .. tostring(V.salt) .. ", off limits " .. tostring(V.off))
    check(V.flat and V.fan, "The same memory three times in a session goes flat; the fan always has three cards",
        "freshness after one use " .. tostring(V.fresh2))
    check(V.last and V.retort and V.closed, "Last words come from the biggest unanswered taunt; a retort answers it, and it's never used again",
        "last words " .. tostring(V.last) .. ", retort " .. tostring(V.retort))
end

-- Quick maps (B9): a map drawn for a place is what the fight there plays on, and it keeps.
do
    local maps = require "game.model.maps"
    local save = require "game.model.save"
    local B9 = { maps = 0, scene_pieces = 0, fights = 0, walls_block = 0, cover = 0, starts = 0, kept = 0, tilt_ok = false }
    for run = 1, 6 do
        local c = campaign_mod.new(31000 + run * 13)
        local rng = rng_mod.new(run)
        c:session_zero(bots.DMS.careful.s0)
        local prep = c:start_week()
        bots.prep(bots.DMS.careful, c, prep, rng)
        -- Scene 1 becomes a fight at a place, on a map: a wall line, cover, rough ground, a trap.
        local s1 = prep.scenes[1]
        s1.open, s1.module = nil, nil
        prep:set_type(1, "combat")
        local loc = s1.slots.location or content.components.forest_road
        s1.slots.location = loc
        local m = maps.new(c, loc.id, maps.auto_template(c, loc, "combat"))
        local placed = {}
        for y = 3, 10 do
            if maps.place(m, "wall", 10, y) then
                table.insert(placed, { 10, y })
            end
        end
        maps.place(m, "cover", 14, 6)
        maps.place(m, "rough", 7, 7)
        maps.place(m, "trap", 12, 7)
        maps.place(m, "party", 3, 7)
        maps.place(m, "foes", 17, 7)
        B9.maps = B9.maps + 1
        local night = c:start_night()
        bots.play_night(night, rng, bots.DMS.careful, function(ev, nt)
            if ev.kind == "scene" and ev.index == 1 and ev.board and string.sub(ev.board, 1, 4) == "map:" then
                B9.scene_pieces = B9.scene_pieces + 1
            elseif ev.kind == "battle" and ev.phase == "start" and nt.scene and nt.scene.index == 1 then
                B9.fights = B9.fights + 1
                local b = nt.battle
                local all = true
                for _, sq in ipairs(placed) do
                    all = all and b.blocked[sq[1] * 1000 + sq[2]] == true
                end
                B9.walls_block = B9.walls_block + (all and #placed > 0 and 1 or 0)
                B9.cover = B9.cover + ((b.cover and b.cover["14,6"]) and 1 or 0)
                local near = 0
                for _, pc in ipairs(ev.party) do
                    if math.abs(pc.x - 3) <= 2 and math.abs(pc.y - 7) <= 2 then
                        near = near + 1
                    end
                end
                B9.starts = B9.starts + (near == #ev.party and 1 or 0)
            end
        end)
        c:finish_night()
        local back = save.load(save.dump(c))
        local m2 = back and back.maps and back.maps[loc.id]
        local crate = false
        for _, p in ipairs(m2 and m2.props or {}) do
            crate = crate or (p.kind == "crate" and p.x == 14 and p.y == 6)
        end
        if crate and m2.party and m2.party[1] == 3 then
            B9.kept = B9.kept + 1
        end
    end
    local tm = maps.new(campaign_mod.new(5), "x", "blank")
    maps.place(tm, "foes", 17, 7)
    maps.place(tm, "cover", 16, 6)
    maps.place(tm, "trap", 9, 7)
    local t1 = maps.tilt(tm)
    maps.place(tm, "erase", 16, 6)
    maps.place(tm, "cover", 4, 7)
    B9.tilt_ok = t1 > 0 and maps.tilt(tm) < t1
    -- (A fight talked down before it starts is fine: the map only has to hold for the fights that happen.)
    check(B9.scene_pieces == B9.maps and B9.fights >= B9.maps - 1 and B9.walls_block == B9.fights and B9.cover == B9.fights
        and B9.starts == B9.fights,
        "A map drawn for a place is the fight there: its walls block, its cover counts, everyone starts where it says (B9)",
        B9.fights .. " fights on " .. B9.maps .. " maps")
    check(B9.kept == B9.maps and B9.tilt_ok, "Maps keep with the save, and the difficulty meter moves with them (B9)",
        B9.kept .. " of " .. B9.maps .. " kept")
end

local kinds = {}
for k, n in pairs(T.event_kinds) do
    table.insert(kinds, k .. " " .. n)
end
table.sort(kinds)
check(T.nights_with_events == T.nights and T.event_kinds.moment and T.event_kinds.clue and T.event_kinds.fail_card,
    "Every night writes its moments to the one event log (B1)",
    string.format("%d events over %d nights: %s", T.events, T.nights, table.concat(kinds, ", ")))
check(T.fans > 0 and T.fan_bad == 0, "A missed big roll deals the fail fan: three different cards and the flat fail (B2)",
    T.fans .. " fans")
local sp = T.fan_solemn > 0 and T.fan_solemn_prat / T.fan_solemn or 0
local op = T.fan_open > 0 and T.fan_open_prat / T.fan_open or 0
check(T.fan_solemn > 0 and sp < op, "Pratfalls come up less at solemn moments (B2)",
    string.format("pratfall in %.0f%% of solemn fans, %.0f%% of the rest", 100 * sp, 100 * op))
check(T.line_repeats == 0, "No fail line twice within three weeks (B2)", T.line_repeats .. " repeats")
check(T.framed_bad == 0, "Only players at Trust 75+ frame their own fail (B2)", T.framed_offered .. " offered")
check(T.jail > 0, "Natural 1s go to dice jail (B2)", T.jail .. " dice jailed")
check(T.robbed_line == 0, "A lost fight ends in a defeat scene, never \"robbed and very much alive\" (B2)",
    T.defeats .. " defeat scenes")
check(T.kb_cards > 0 and T.kb_offered > 0, "Bosses and villains fall to a killing blow someone describes (B4)",
    T.kb_cards .. " cards, " .. T.kb_offered .. " described by a player")
check(T.insp_given > 0 and T.insp_two == 0 and T.insp_spent > 0, "Heroic Inspiration: one a night at most, and it gets spent (B4)",
    T.insp_given .. " given, " .. T.insp_spent .. " spent")
check(T.headache > 0 and T.headache_bad == 0, "Headaches only when their situation happened (B4)", T.headache .. " headaches")
check(T.shower_over == 0 and T.shower_free_bad == 0 and T.showers > 0,
    "Shower thoughts: 0 to 2 a week, pinned and free (B5)", string.format("%.2f a week", T.showers / math.max(1, T.shower_weeks)))
check(T.theories > 0 and T.stolen > 0 and T.stolen_paid > 0, "Theories pin to the board; a stolen one comes true at the payoff (B5)",
    T.theories .. " pinned, " .. T.stolen .. " stolen, " .. T.stolen_paid .. " came true")
check(T.jokes > 0 and T.callbacks > 0, "Running jokes come from the log and get called back (B5)",
    T.jokes .. " jokes, " .. T.callbacks .. " callbacks, " .. T.stale_callbacks .. " stale")
check(T.escape_cards > 0 and T.escapes > 0 and T.grudges > 0, "Villains get away on a call, and their Grudge builds (B6)",
    T.escape_cards .. " escape cards, " .. T.escapes .. " escapes")
check(T.deaths > 0 and T.death_cards == T.deaths and T.death_opts_bad == 0,
    "A hero who dies gets the death flow, its choices set by Session Zero and their own wish (B3)",
    T.deaths .. " deaths (" .. T.death_cards .. " cards, " .. T.death_opts_bad .. " wrong), " .. T.fallen .. " on the shelf, " .. T.scars .. " came back scarred")
check(T.new_chars == 0 or (T.new_named == T.new_chars and T.intros > 0),
    "Whoever fell comes back as someone new, introduced on their first night (B3)",
    T.new_chars .. " new characters, " .. T.intros .. " introductions")
check(T.q_min >= 3, "Every big question keeps at least three clues reachable (B10)", "the fewest roads left: " .. T.q_min)
local function tally(t)
    local out = {}
    for k, v in pairs(t) do
        table.insert(out, k .. " " .. v)
    end
    table.sort(out)
    return table.concat(out, ", ")
end
check(T.talks > 0 and T.talk_turn_bad == 0 and T.talk_logged == T.talks,
    "Talk as the NPC: a key person once a night at most, warm, guarded or a lie, logged in the notebook (B8)",
    T.talks .. " talks in " .. T.nights .. " nights (" .. tally(T.talk_stances) .. "), " .. T.talk_logged .. " logged, "
        .. T.talk_turn_bad .. " bad")
check(T.monologues > 0 and T.mono_unlogged == 0,
    "Villains who remember: monologues from the ledger, and every taunt in the log",
    T.monologues .. " monologues (" .. tally(T.mono_kinds) .. "), " .. T.retorts .. " retorts")
check(T.boss > 0 and T.boss_two == 0, "Run the boss's turn: once a night at most, and the table reacts (B8)",
    T.boss .. " boss turns (" .. tally(T.boss_kinds) .. ")")
check(T.talk_count_bad == 0, "A takeover stands in for a card: the night counts it once (B8)",
    T.talk_count_bad .. " nights miscounted")

for _, f in ipairs(fails_list) do
    print("  problem: " .. f)
end
local ok = true
for _, ch in ipairs(checks) do
    print(string.format("  [%s] %s  -  %s", ch.ok and "PASS" or "FAIL", ch.name, ch.detail))
    ok = ok and ch.ok
end
os.exit(ok and 0 or 1)
