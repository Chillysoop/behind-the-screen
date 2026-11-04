-- Roadmap phase 1, "Polish the words": the round-two playtest findings Conner said yes to, each kept
-- fixed. Whole prologues headless over several seeds and three kinds of DM, watching what the table
-- hears, plus targeted unit cases. Run from the project root:
--     lua tools/tests/roadmap_words_check.lua [runs per style]
-- Prints one line per item: what was seen, and FAIL lines where play contradicts the fix.
--
-- Items: F2 near misses, F6 F7 F8 F26 small moments, F9 the offices (and the shop, the paintings),
-- F15 Flitwidget's thanks, F16 Euryale in the room, F17 location slips, F21 behind your screen,
-- F22 looking round, F24 R2 R3 repeats and cool-downs, F25 chatter that fits.

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"
local util = require "game.model.util"

local RUNS = tonumber(arg[1]) or 4
local STYLES = { "careful", "random", "careless" }
local ITEMS = { "F21" }
local NAMES = {
    F2 = "near misses", F6 = "small moments: reactions", F7 = "small moments: the natural 1",
    F8 = "small moments: danger first", F9 = "the offices, shop, paintings", F15 = "Flitwidget's thanks",
    F16 = "Euryale in the room", F17 = "location slips", F21 = "behind your screen", F22 = "looking round",
    F24 = "lines every week", F25 = "chatter that fits", F26 = "small moments: variety", R2 = "catchphrase cool-downs",
    R3 = "variants for weekly lines", run = "whole prologues",
}

local fails = {}
local function fail(item, msg)
    fails[item] = fails[item] or { n = 0 }
    if #fails[item] < 6 then
        table.insert(fails[item], msg)
    end
    fails[item].n = fails[item].n + 1
end
local E = setmetatable({}, { __index = function(t, k)
    local v = {}
    rawset(t, k, v)
    return v
end })
local function add(item, key, n)
    E[item][key] = (E[item][key] or 0) + (n or 1)
end
local function has(s, pat)
    return type(s) == "string" and string.find(s, pat, 1, true) ~= nil
end

-- Playing ------------------------------------------------------------------------------------------

-- One prologue: every event the table sees, in order, with where it happened.
-- run.log = { { k, style, text, who, name, room, week, scene, card, opts, ... } }
local function play(seed, style, opts)
    opts = opts or {}
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    local s0 = social.default_choices()
    s0.rules = s0.rules or {}
    s0.rules.harsh = ({ careful = "fair", random = "gentle", careless = "brutal" })[style]
    if opts.chatter then
        s0.rules.chatter = opts.chatter
    end
    c:session_zero(s0)
    local rng = require("game.model.rng").new(seed * 31 + #style)
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = adventure.data.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    local run = { seed = seed, style = style, log = {}, c = c, chats = {} }
    for w = 1, adventure.data.MAX_WEEKS do
        local prep = c:start_week()
        for _, m in ipairs(c.chat or {}) do
            table.insert(run.chats, { week = w, who = m.key or m.who, text = m.text })
        end
        for _, m in ipairs(c.chat or {}) do
            if m.ask and not m.answered then
                museum_week.answer_chat(c, m, ({ careful = 1, random = rng:int(1, 3), careless = 3 })[style])
            end
        end
        for _, pr in ipairs(c.adv.prompts) do
            if pr.kind == "request" then
                adventure.answer_request(c, pr.id, adventure.data.ANSWERS[style == "careful" and 2 or rng:int(1, 4)])
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
            for _, id in ipairs(prep.museum.ahead) do
                for _, kid in ipairs(adventure.data.rooms[id].knobs or {}) do
                    local k = adventure.data.knobs[kid]
                    museum_week.set_knob(prep, kid, k.pick_hero and "mara" or (rng:chance(0.6) or nil))
                end
            end
        end
        if prep.museum.boss then
            c.adv.boss = { opener = rng:chance(0.7) and "talk" or "ambush", style = rng:chance(0.6) and "yields" or "last" }
        end
        local night = c:start_night()
        run.night = night
        local ev = night:advance()
        local guard = 0
        while ev.kind ~= "done" and guard < 6000 do
            guard = guard + 1
            local sc = night.scene
            local rec = { k = ev.kind, style = ev.style, text = ev.text, who = ev.who, name = ev.name, week = w,
                          room = sc and sc.room, scene = sc and sc.index, fought = sc and sc.fought or nil,
                          epilogue = sc and sc.epilogue or nil, boss = sc and sc.boss or nil, ev = ev }
            table.insert(run.log, rec)
            local answer
            if ev.kind == "decision" then
                local o = ev.card.options
                rec.card = ev.card.id
                rec.title = ev.card.title
                rec.ctext = ev.card.text
                rec.opts = o
                local pick = (style == "careful") and 1 or rng:int(1, #o)
                if opts.pick then
                    pick = opts.pick(ev, pick, rng) or pick
                end
                if o[pick] and o[pick].disabled then
                    pick = 1
                end
                rec.pick = pick
                answer = pick
            elseif ev.kind == "thought" then
                require("game.model.thoughts").bot_play(night, ev, style, rng)
            elseif ev.kind == "ruling" then
                answer = opts.ruling and opts.ruling(ev, rng) or 1
                rec.tier = ev.tier
            elseif ev.kind == "improv" then
                answer = { 1 }
            elseif ev.kind == "roll_where" then
                answer = (style == "careless") and "hidden" or "open"
            elseif ev.kind == "roll" then
                answer = opts.roll and opts.roll(ev, rng) or rng:d20()
            end
            ev = night:advance(answer)
        end
        if guard >= 6000 then
            fail("run", string.format("seed %d %s week %d: the night never ended", seed, style, w))
        end
        c:finish_night()
        c:level_up()
        if adventure.over(c) then
            break
        end
    end
    add("run", "prologues")
    return run
end

local function where(run, r)
    return string.format("seed %d %s week %d (%s)", run.seed, run.style, r.week or 0, tostring(r.room))
end

-- The items, over whole prologues ---------------------------------------------------------------------

local CHECKS = {}

-- F21: notes only the DM knows have their own caption.
local SCREEN_NOTES = { "behind your screen", "You never prepped it", "You hadn't prepped this one", "off screen, as you agreed",
    "You leave the ", "You make a note", "You make a mental note", "Your rolls go back behind the screen" }
function CHECKS.F21(run)
    for _, r in ipairs(run.log) do
        if r.k == "narrate" then
            for _, pat in ipairs(SCREEN_NOTES) do
                if has(r.text, pat) or has(string.lower(r.text or ""), string.lower(pat)) then
                    if r.style == "screen" then
                        add("F21", "notes_behind_the_screen")
                    else
                        fail("F21", where(run, r) .. ": a note only you know, captioned " .. tostring(r.style) .. ": " .. r.text)
                    end
                    break
                end
            end
        end
    end
end

-- F22: what the friends say looking round fits what they're looking at.
function CHECKS.F22(run)
    local fought = {}
    for _, r in ipairs(run.log) do
        if r.k == "battle" and r.ev.phase == "start" and r.room then
            fought[r.week .. "/" .. r.room] = true
        end
        if r.k == "say" and has(r.text, "Where are the monsters?") then
            local room = adventure.data.rooms[r.room or ""] or {}
            if fought[r.week .. "/" .. tostring(r.room)] or room.encounter then
                fail("F22", where(run, r) .. ": \"" .. r.text .. "\" in a room with a fight in it")
            else
                add("F22", "where_are_the_monsters_in_a_quiet_room")
            end
        end
        for _, bad in ipairs({ "Is the shears", "Who left the front doors", "Who left the museum's doors", "has under the",
                               "hit the piles of books? I want to hit it.", "Does the cases", "Is the anatomy drawings",
                               "Does the eye on every wall", "Is the piles", "Is the cases" }) do
            if r.k == "say" and has(r.text, bad) then
                fail("F22", where(run, r) .. ": \"" .. r.text .. "\"")
            end
        end
    end
end

-- Unit cases ----------------------------------------------------------------------------------------

local UNITS = {}

-- F21: the caption is its own, and quieter than the DM's voice.
function UNITS.F21()
    local real_gui, real_vmath = gui, vmath
    gui = setmetatable({}, { __index = function() return function() end end })
    vmath = vmath or { vector3 = function() return {} end, vector4 = function() return {} end }
    local ok, nv = pcall(require, "game.ui.night_view")
    gui, vmath = real_gui, real_vmath
    if not ok then
        fail("F21", "night_view didn't load: " .. tostring(nv))
        return
    end
    local v = nv.VOICE and nv.VOICE.screen
    if not v or v[1] ~= "BEHIND YOUR SCREEN" then
        fail("F21", "no BEHIND YOUR SCREEN caption (VOICE.screen)")
    else
        add("F21", "caption_behind_your_screen")
        local function lum(hex)
            local r, g, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
            return 0.2126 * r + 0.7152 * g + 0.0722 * b
        end
        if lum(v[2]) >= lum(nv.VOICE.dm[2]) then
            fail("F21", "the screen's caption isn't quieter than the DM's (" .. v[2] .. " vs " .. nv.VOICE.dm[2] .. ")")
        else
            add("F21", "quieter_than_speech")
        end
    end
    local theme = require "game.ui.theme"
    if not (theme.log and theme.log.screen) then
        fail("F21", "no log colour for notes behind your screen (theme.log.screen)")
    end
    local night_mod = require "game.model.night"
    if not (night_mod.screen_note and night_mod.screen_note("Behind your screen, you cross it out.")) then
        fail("F21", "night.screen_note doesn't know a note behind your screen")
    end
end

-- F22: every place the friends walk over to says what it is, and every line said of it fits.
function UNITS.F22()
    local mn = require "game.model.museum_night"
    local lib = require "game.data.map_library"
    if not mn.look_lines then
        fail("F22", "museum_night.look_lines (the lines that fit a place) is missing")
        return
    end
    for room, list in pairs(adventure.data.explore or {}) do
        local board
        for _, b in pairs(lib.boards) do
            if b.room == room then
                board = b
            end
        end
        local by = {}
        for _, pl in ipairs(board and board.places or {}) do
            by[pl.id] = pl
        end
        for _, pid in ipairs(list) do
            local pl = by[pid]
            if not pl then
                fail("F22", room .. ": no place " .. tostring(pid) .. " on its board")
            elseif not pl.kind then
                fail("F22", room .. "/" .. pid .. ": the place doesn't say what kind of thing it is")
            else
                add("F22", "places_with_a_form")
                for arch in pairs(mn.LOOK_SAY) do
                    local lines = mn.look_lines(arch, pl, { calm = false })
                    if #lines == 0 then
                        fail("F22", room .. "/" .. pid .. ": nothing a " .. arch .. " can say about " .. pl.name)
                    end
                    for _, t in ipairs(lines) do
                        local name = util.lower_first(pl.name)
                        add("F22", "lines_checked")
                        local low = string.lower(t)
                        local n = string.lower(name)
                        if pl.many and (has(low, "is " .. n) or has(low, "does " .. n) or has(low, n .. " is ")
                            or has(low, "hit it") or has(low, "lick it") or has(low, "sell it")) then
                            fail("F22", room .. "/" .. pid .. " (many): \"" .. t .. "\"")
                        elseif not pl.many and (has(low, "are " .. n) or has(low, "do " .. n) or has(low, "them")) then
                            fail("F22", room .. "/" .. pid .. " (one): \"" .. t .. "\"")
                        end
                        if pl.kind ~= "thing" and has(low, "who left") then
                            fail("F22", room .. "/" .. pid .. " (" .. pl.kind .. "): \"" .. t .. "\"")
                        end
                        if (pl.kind == "fixture" or pl.kind == "area" or pl.kind == "person") and (has(low, "take " .. n .. " home")
                            or has(low, "knock " .. n .. " over")) then
                            fail("F22", room .. "/" .. pid .. " (" .. pl.kind .. "): \"" .. t .. "\"")
                        end
                        if pl.kind == "area" and (has(low, "has " .. n) or has(low, "touch " .. n)) then
                            fail("F22", room .. "/" .. pid .. " (area): \"" .. t .. "\"")
                        end
                        if has(t, "Where are the monsters") then
                            fail("F22", "\"Where are the monsters?\" offered for a room that isn't calm")
                        end
                    end
                end
            end
        end
    end
end

-- Running -----------------------------------------------------------------------------------------------

for _, item in ipairs(ITEMS) do
    if UNITS[item] then
        local ok, err = pcall(UNITS[item])
        if not ok then
            fail(item, "unit case error: " .. tostring(err))
        end
    end
end
local base = tonumber(os.getenv("SEED_BASE") or "") or 500
for _, style in ipairs(STYLES) do
    for i = 1, RUNS do
        local seed = base + i * 23
        local ok, run = pcall(play, seed, style)
        if not ok then
            fail("run", "seed " .. seed .. " " .. style .. ": " .. tostring(run))
        else
            for _, item in ipairs(ITEMS) do
                if CHECKS[item] then
                    local ok2, err = pcall(CHECKS[item], run)
                    if not ok2 then
                        fail(item, "seed " .. seed .. " " .. style .. ": check error: " .. tostring(err))
                    end
                end
            end
        end
    end
end

local total = 0
for _, item in ipairs({ "run", unpack(ITEMS) }) do
    local parts = {}
    for k, v in pairs(rawget(E, item) or {}) do
        table.insert(parts, k .. " " .. v)
    end
    table.sort(parts)
    local f = fails[item]
    print(string.format("%-4s %-30s %s%s", item, NAMES[item] or item, #parts > 0 and table.concat(parts, ", ") or "(nothing seen)",
        f and ("  FAILS " .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("       FAIL " .. m)
    end
    total = total + (f and f.n or 0)
end
print(total == 0 and "roadmap words check: every item holds" or ("roadmap words check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
