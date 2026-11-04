-- The November 3 playtest notes, played (the 26-point list): whole prologues headless, three kinds of
-- DM, and for each note the evidence that the fix shows up in play, not just in a unit test. Run from
-- the project root:  lua tools/tests/playtest_nov3_check.lua [runs per style]
-- Prints one line per note: what was seen, and FAIL lines where play contradicts the fix.

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"
local score = require "game.model.score"
local tile_stats = require "game.model.tile_stats"
local warnings = require "game.model.warnings"
local companions = require "game.model.companions"

local RUNS = tonumber(arg[1]) or 6
local STYLES = { "careful", "random", "careless" }

local fails = {}
local function fail(item, msg)
    fails[item] = fails[item] or {}
    if #fails[item] < 6 then
        table.insert(fails[item], msg)
    end
    fails[item].n = (fails[item].n or 0) + 1
end

-- What each note's evidence counts.
local E = setmetatable({}, { __index = function(t, k)
    local v = {}
    rawset(t, k, v)
    return v
end })
local function add(item, key, n)
    E[item][key] = (E[item][key] or 0) + (n or 1)
end

-- Resources on a hero now: { id = { cur, max } } (slots summed over levels).
local function res_of(c, night, key)
    local ts = tile_stats.of(c, night, key)
    local out = {}
    for _, r in ipairs(ts and ts.res or {}) do
        if r.levels then
            local cur, max = 0, 0
            for _, l in ipairs(r.levels) do
                cur, max = cur + (l.cur or l[1] or 0), max + (l.max or l[2] or 0)
            end
            out[r.id] = { cur, max }
        elseif r.max then
            out[r.id] = { r.cur or 0, r.max }
        end
    end
    return out, ts
end

local function play(seed, style)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    local s0 = social.default_choices()
    s0.rules = s0.rules or {}
    s0.rules.harsh = ({ careful = "fair", random = "gentle", careless = "brutal" })[style]
    c:session_zero(s0)
    local rng = require("game.model.rng").new(seed * 13 + #style)
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = adventure.data.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    local last_fun = {}
    for w = 1, adventure.data.MAX_WEEKS do
        local prep = c:start_week()
        -- The group chat: answer what can be answered (the companion asks, the dice banter).
        for _, m in ipairs(c.chat or {}) do
            if m.ask and not m.answered then
                local pick = ({ careful = 1, random = rng:int(1, 3), careless = 3 })[style]
                if m.ask == "pip_pet" then
                    add(12, "asked_" .. pick)
                end
                museum_week.answer_chat(c, m, pick)
            end
        end
        -- 11: Sam's new dice, if he said so this week.
        for _, b in ipairs(adventure.data.chat_banter or {}) do
            if b.dice then
                for _, m in ipairs(c.chat or {}) do
                    if m.text == b[2] and m.key == b[1] then
                        add(11, "dice_said")
                        local has = require("game.model.dice_sets").get(c).players[b[1]]
                        if has == b.dice then
                            add(11, "dice_match")
                        else
                            fail(11, string.format("seed %d %s week %d: %s said new %s dice, has %s", seed, style, w, b[1], b.dice,
                                tostring(has)))
                        end
                    end
                end
            end
        end
        for _, pr in ipairs(c.adv.prompts) do
            if pr.kind == "request" then
                local a = adventure.data.ANSWERS[style == "careful" and 2 or rng:int(1, 4)]
                adventure.answer_request(c, pr.id, a)
            elseif pr.kind == "loose" then
                adventure.answer_loose(c, pr.id, 1)
            elseif pr.kind == "ruling" then
                adventure.answer_ruling(c, pr.id, style ~= "careless")
            elseif pr.kind == "favor" then
                adventure.answer_favor(c, pr.id, rng:int(1, 2), rng:int(1, 2))
            end
        end
        if style ~= "careless" then
            museum_week.prep_greedy(prep)
        end
        local pm = prep.museum
        if pm.boss then
            c.adv.boss = { opener = rng:chance(0.7) and "talk" or "ambush", style = rng:chance(0.6) and "yields" or "last" }
        end
        local night = c:start_night()
        -- 13: the mood they came in with.
        for _, p in ipairs(night.players) do
            if last_fun[p.key] then
                local now = score.fun(p)
                add(13, "nights")
                if last_fun[p.key] >= 70 and now < 50 then
                    fail(13, string.format("seed %d %s week %d: %s left last week at %d, came in at %d", seed, style, w, p.key,
                        last_fun[p.key], now))
                elseif last_fun[p.key] >= 70 then
                    add(13, "stoked_kept")
                end
            end
        end
        local N = { breaks = 0, offers = 0, offers_yes = 0, tokens = 0, warn_cards = 0, battles = 0 }
        local last_pos, before_battle_res = nil, nil
        local npc_shown, lecturer_seen_before_fight, euryale_spoke, euryale_shown = false, nil, false, false
        local scene_room
        local ev = night:advance()
        local guard = 0
        local pending_offer
        while ev.kind ~= "done" and guard < 5000 do
            guard = guard + 1
            local answer
            if ev.kind == "scene" then
                scene_room = night.scene and night.scene.room
                npc_shown = not ev.npc_hidden
                euryale_shown = false
                if ev.npc_hidden then
                    add(24, "npc_out_of_sight_at_start")
                end
            end
            if ev.npc_show then
                npc_shown = true
                add(24, "npc_came_into_view")
            end
            if ev.kind == "warning" and ev.how then
                add(1, "warning_" .. ev.how)
            end
            if (ev.kind == "npc" or ev.kind == "narrate") and scene_room == "lair" and ev.text and string.find(ev.text, "Euryale", 1, true) then
                npc_shown = npc_shown or ev.npc_show
                if not euryale_spoke then
                    euryale_spoke = true
                    if npc_shown then
                        add(24, "euryale_on_mat_before_she_speaks")
                    else
                        fail(24, string.format("seed %d %s: Euryale speaks before she's on the mat", seed, style))
                    end
                end
            end
            if ev.kind == "walk" then
                add(6, "walks")
            elseif ev.kind == "door" then
                add(24, "doors_opened")
            elseif ev.kind == "token" and not ev.spent and ev.what == "inspiration" then
                N.tokens = N.tokens + 1
            elseif ev.kind == "rested" then
                -- 7: what came back.
                for _, p in ipairs(night.players) do
                    local r = res_of(c, night, p.key)
                    -- (The morning's buffs go up after a long rest: Mage Armor and Aid, a slot each.)
                    local pc = night.pcs and night.pcs[p.key]
                    local buffs = pc and (((pc.mage_armor and 1) or 0) + ((pc.aid_caster and 1) or 0)) or 0
                    -- (A hero who died doesn't rest: their player plays on, wave 2's first night saw one.)
                    for id, cm in pairs((pc and pc.dead) and {} or r) do
                        if ev.long then
                            add(7, "long_rest_checks")
                            if cm[1] < cm[2] - (id == "slots" and buffs or 0) then
                                fail(7, string.format("seed %d %s week %d: %s's %s %d/%d after a long rest", seed, style, w, p.key, id,
                                    cm[1], cm[2]))
                            end
                        elseif id == "action_surge" or id == "second_wind" then
                            add(7, "short_rest_checks")
                            if cm[1] < 1 then
                                fail(7, string.format("seed %d %s week %d: %s's %s %d/%d after a short rest", seed, style, w, p.key,
                                    id, cm[1], cm[2]))
                            end
                        end
                    end
                end
            elseif ev.kind == "battle" and ev.phase == "start" then
                if os.getenv("DIAG") == (seed .. ":" .. style .. ":" .. w) then
                    for _, q in ipairs(ev.party or {}) do
                        print(string.format("DIAG start party %s %s at %d,%d", tostring(q.id), tostring(q.class), q.x, q.y))
                    end
                    for _, q in ipairs(ev.foes or {}) do
                        print(string.format("DIAG start foe %s %s at %d,%d", tostring(q.id), tostring(q.name), q.x, q.y))
                    end
                end
                N.battles = N.battles + 1
                add(6, "battles")
                -- 6: where they start.
                local mp = night.mini_pos or {}
                for _, q in ipairs(ev.party or {}) do
                    local was = mp[q.id] or (q.key and mp[q.key])
                    if was then
                        add(6, "heroes_with_a_spot")
                        if math.abs(was[1] - q.x) <= 1 and math.abs(was[2] - q.y) <= 1 then
                            add(6, "heroes_started_where_they_stood")
                        end
                    end
                end
                -- 25: who's along fights.
                for _, e in ipairs(companions.fighters(night)) do
                    add(25, "allies_due")
                    local found = false
                    for _, a in ipairs(ev.allies or {}) do
                        found = found or a.monster == e.id or a.name == e.name or (a.name and string.find(a.name, e.name, 1, true))
                    end
                    if found then
                        add(25, "allies_on_the_mat")
                    else
                        fail(25, string.format("seed %d %s week %d (%s): %s is along but not in the fight", seed, style, w,
                            tostring(scene_room), e.name))
                    end
                end
                -- 20: the lecturer's on the mat before the fight.
                if scene_room == "lecture" then
                    lecturer_seen_before_fight = npc_shown
                    if npc_shown then
                        add(20, "lecturer_seen_first")
                    else
                        fail(20, string.format("seed %d %s: the lecture hall's fight starts with the lecturer not yet seen", seed, style))
                    end
                end
                N.steps = {}
                before_battle_res = {}
                for _, p in ipairs(night.players) do
                    before_battle_res[p.key] = res_of(c, night, p.key)
                    -- A long rest promised in the chat: the first fight starts with everything back.
                    if N.promised_rest and N.battles == 1 then
                        local pc = night.pcs and night.pcs[p.key]
                        local buffs = pc and (((pc.mage_armor and 1) or 0) + ((pc.aid_caster and 1) or 0)) or 0
                        for id, cm in pairs(before_battle_res[p.key]) do
                            add(7, "long_rest_checks")
                            if cm[1] < cm[2] - (id == "slots" and buffs or 0) then
                                fail(7, string.format("seed %d %s week %d: promised a long rest, %s's %s is %d/%d at the first fight",
                                    seed, style, w, p.key, id, cm[1], cm[2]))
                            end
                        end
                    end
                end
            elseif ev.kind == "battle" and ev.phase == "end" then
                local sm = ev.summary or {}
                -- 26: everyone who could fight did something.
                for _, h in ipairs(sm.heroes or {}) do
                    add(26, "hero_fights")
                    local did = (N.steps or {})[h.id] or {}
                    local acted = (did.spell or 0) + (did.attack or 0) + (did.feature or 0) > 0
                    if (h.swings or 0) > 0 or (h.dealt or 0) > 0 or acted then
                        add(26, "hero_fights_with_a_swing")
                    elseif (sm.rounds or 0) >= 4 and not h.dead and (h.downs or 0) == 0
                        and not (function()
                            -- (Held all fight by something that stops them acting, the Lecturer's drone say:
                            -- they couldn't swing. Wave 2 saw Brannoc listen to all four rounds.)
                            for _, e in ipairs((night.pcs and night.pcs[h.id] and night.pcs[h.id].effects) or {}) do
                                if e.conds and e.conds.incapacitated then
                                    return true
                                end
                            end
                            return false
                        end)() then
                        local did = {}
                        for k, n in pairs((N.steps or {})[h.id] or {}) do
                            table.insert(did, k .. "=" .. n)
                        end
                        table.sort(did)
                        fail(26, string.format("seed %d %s week %d (%s): %s never swung in %d rounds [%s]", seed, style, w,
                            tostring(scene_room), tostring(h.name), sm.rounds or 0, table.concat(did, " ")))
                    end
                end
                -- 7: what they spent.
                for _, p in ipairs(night.players) do
                    local now = res_of(c, night, p.key)
                    local was = before_battle_res and before_battle_res[p.key] or {}
                    for id, cm in pairs(now) do
                        if cm[1] > cm[2] then
                            fail(7, string.format("seed %d %s: %s has %s %d of %d", seed, style, p.key, id, cm[1], cm[2]))
                        end
                        if was[id] and cm[1] < was[id][1] then
                            add(7, "spent_in_fights")
                        end
                    end
                end
                -- 9: who went down is who the fight says went down.
                for _, h in ipairs(sm.heroes or {}) do
                    if (h.downs or 0) > 0 then
                        add(9, "heroes_down")
                    end
                end
            elseif ev.kind == "turn" then
                if os.getenv("DIAG") == (seed .. ":" .. style .. ":" .. w) then
                    local ks = {}
                    for _, st in ipairs(ev.steps or {}) do
                        table.insert(ks, st.kind .. (st.name and ("(" .. tostring(st.name) .. ")") or "")
                            .. (st.id and ("@" .. tostring(st.id)) or ""))
                    end
                    print("DIAG turn " .. tostring(ev.who) .. ": " .. table.concat(ks, " "))
                end
                N.steps = N.steps or {}
                if ev.who then
                    local t = N.steps[ev.who] or {}
                    N.steps[ev.who] = t
                    for _, st in ipairs(ev.steps or {}) do
                        local k = st.kind .. ((st.kind == "condition" and st.name) and (":" .. st.name) or "")
                        t[k] = (t[k] or 0) + 1
                    end
                end
                for _, st in ipairs(ev.steps or {}) do
                    if st.kind == "death_save" then
                        add(9, "death_saves_rolled")
                    end
                end
            end
            if ev.kind == "decision" then
                local id = ev.card.id
                local opts = ev.card.options
                local pick = (style == "careful") and 1 or rng:int(1, #opts)
                if id == "table_break" then
                    N.breaks = N.breaks + 1
                    add(14, "breaks")
                    pick = ({ careful = 2, random = rng:int(1, 4), careless = 1 })[style]
                    if opts[pick].disabled then
                        pick = 1
                    end
                    add(14, "break_pick_" .. pick)
                elseif id == "inspire_offer" then
                    N.offers = N.offers + 1
                    add(3, "offers")
                    pick = (style == "careless") and 2 or 1
                    if pick == 1 then
                        N.offers_yes = N.offers_yes + 1
                    end
                elseif string.sub(id, 1, 5) == "warn_" then
                    N.warn_cards = N.warn_cards + 1
                    add(1, "warn_cards")
                    pick = ({ careful = 1, random = rng:int(1, 3), careless = 3 })[style]
                    add(1, ({ "told", "asked", "silent" })[pick])
                elseif id == "mus_drink" or id == "mus_ultimatum" or id == "mus_yield" then
                    fail(22, string.format("seed %d %s: the DM got the players' call %s", seed, style, id))
                elseif id == "fallen_seat" then
                    add(9, "fallen_seat_cards")
                end
                if opts[pick] and opts[pick].disabled then
                    pick = 1
                end
                -- 4: the people in it on the card.
                if ev.card.people and #ev.card.people > 0 then
                    add(4, "cards_with_faces")
                end
                answer = pick
            elseif ev.kind == "ruling" then
                answer = 1
            elseif ev.kind == "improv" then
                answer = { 1 }
            elseif ev.kind == "roll_where" then
                -- 19: sometimes the DM picks the DC and says it.
                if style == "random" and rng:chance(0.3) and ev.dc then
                    answer = "dc:" .. tostring(ev.dc + 2)
                    add(19, "own_dc")
                else
                    answer = (style == "careless") and "hidden" or "open"
                end
            elseif ev.kind == "roll" then
                answer = rng:d20()
            end
            if ev.kind == "say" and ev.text and string.find(ev.text, "Exhibit B", 1, true) then
                add(12, "exhibit_b_lines")
            end
            if ev.kind == "narrate" and ev.text and string.find(ev.text, "after a long rest in the gift shop", 1, true) then
                N.promised_rest = true
                add(7, "promised_long_rests")
            end
            if ev.kind == "narrate" and ev.text and string.find(ev.text, "You said DC", 1, true) then
                add(19, "dc_said")
            end
            ev = night:advance(answer)
        end
        if guard >= 5000 then
            fail(0, string.format("seed %d %s week %d: the night never ended", seed, style, w))
        end
        -- 14: every session takes a break.
        add(14, "nights")
        if N.breaks == 0 then
            local rooms = {}
            for _, sc2 in ipairs(night.scenes) do
                table.insert(rooms, tostring(sc2.room))
            end
            fail(14, string.format("seed %d %s week %d: no break (table %s of %s min, rooms %s%s, ending %s)", seed, style, w,
                tostring(math.floor(night.table_min or 0)), tostring(night.table_planned), table.concat(rooms, ","),
                night.end_early and ", ended early" or "", tostring(c.adv.ending)))
        elseif N.breaks > 1 then
            fail(14, string.format("seed %d %s week %d: %d breaks", seed, style, w, N.breaks))
        end
        -- 3: no inspiration you didn't give.
        if N.tokens > N.offers_yes then
            fail(3, string.format("seed %d %s week %d: %d tokens given, %d offers taken", seed, style, w, N.tokens, N.offers_yes))
        end
        add(3, "tokens", N.tokens)
        -- 12: the rat.
        if companions.def("exhibit_b") and c.adv.companions and c.adv.companions.exhibit_b then
            add(12, "nights_with_exhibit_b")
        end
        if night.companion_found and next(night.companion_found) then
            add(12, "companion_finds")
        end
        local rep = c:finish_night()
        for _, p in ipairs(c.players) do
            last_fun[p.key] = p.last_fun
        end
        -- 9: the report says only what happened (the truth test does the words; here, deaths).
        add(9, "deaths_so_far", 0)
        for _, rec in ipairs(c.fallen or {}) do
            if rec.week == c.week then
                add(9, "deaths")
            end
        end
        c:level_up()
        if adventure.over(c) then
            break
        end
    end
    -- 1: what they ended up knowing, and how the harsh calls landed.
    add(1, "warned_things", warnings.count(c))
    add(1, "harsh_fair", c.adv.harsh.paid)
    add(1, "harsh_out_of_nowhere", c.adv.harsh.unpaid)
    if c.adv.flags and c.adv.flags.telpur_along then
        add(25, "runs_with_telpur_along")
    end
    add(0, "prologues")
    add(0, "ending_" .. tostring(c.adv.ending))
end

for _, style in ipairs(STYLES) do
    for run = 1, RUNS do
        local base = tonumber(os.getenv("SEED_BASE") or "") or 300
        local ok, err = pcall(play, base + run * 17, style)
        if not ok then
            fail(0, "seed " .. (300 + run * 17) .. " " .. style .. ": " .. tostring(err))
        end
    end
end

-- 21: the boot is explained where it's asked.
local boot = false
for _, r in ipairs(adventure.data.requests or {}) do
    if r.id == "keep_boot" then
        boot = r.about ~= nil
    end
end
add(21, boot and "keep_boot_explained" or "keep_boot_not_explained")
if not boot then
    fail(21, "the keep_boot request has no 'about' line")
end

local NAMES = { [0] = "whole prologues", "fair warning", "pause/speed", "inspiration you give", "faces on cards", "in character",
    "fights start where they stand", "resources", "replay", "recap, downs and death", "bars moved", "dice from the chat",
    "companions (Exhibit B)", "moods carry over", "the break", "people clickable", "speed hover", "sheet header", "stairs",
    "your own DC", "the lecturer seen first", "the boot explained", "the drink is theirs", "roll math", "sight lines",
    "allies in initiative", "fight AI" }
local total = 0
for item = 0, 26 do
    local parts = {}
    for k, v in pairs(rawget(E, item) or {}) do
        table.insert(parts, k .. " " .. v)
    end
    table.sort(parts)
    local f = fails[item]
    print(string.format("%2d %-30s %s%s", item, NAMES[item], #parts > 0 and table.concat(parts, ", ") or "(UI: the smoke and engine runs)",
        f and ("  FAILS " .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("     FAIL " .. m)
    end
    total = total + (f and f.n or 0)
end
print(total == 0 and "playtest check: every note holds" or ("playtest check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
