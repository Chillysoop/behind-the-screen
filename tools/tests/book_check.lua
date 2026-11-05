-- The book check (docs/design/2026-11-05-root-causes.md, class 4): the museum against the book's own
-- structure, as game/data/museum/fidelity.lua writes it down with its page numbers. Run from the project
-- root:
--     lua tools/tests/book_check.lua [seeds]
--   SHEET  every room the book has, in the sheet, with its pages, and every board and cast card it names exists
--   START  a foe that looks like part of the room (a prop, a painting) or hides says nothing and stands no mini
--          on the mat as the room opens; one that wakes only when robbed or inspected is an optional fight
--   PLACE  everyone starts where the book puts them: each board's anchor, and each garden beast's square, by
--          the place the book names
--   DOORS  a door the book locks is locked on the board, and one it leaves open isn't
--   TRAPS  every trap the game springs is in the sheet, the book's or marked as ours; the book's at its DC
--   WORDS  nothing the room says as it opens (its read, its cast's line, a hero's hook paid off there) gives a
--          secret away; and in whole prologues nothing the table hears in the room does before its reveal
--   ITEMS  each hero's painting gives what the book's painting gives, paint or not; every magic item the
--          module hands out is the book's or marked as ours
-- Each fails on 1ea3901.

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local SEEDS = tonumber(arg[1]) or 2
local ITEMS = { "SHEET", "START", "PLACE", "DOORS", "TRAPS", "WORDS", "ITEMS" }
local fails, E = {}, {}
local function fail(item, msg)
    fails[item] = fails[item] or { n = 0 }
    if #fails[item] < 10 then
        table.insert(fails[item], msg)
    end
    fails[item].n = fails[item].n + 1
end
local function add(item, key, n)
    E[item] = E[item] or {}
    E[item][key] = (E[item][key] or 0) + (n or 1)
end
local function has(s, w)
    return string.find(s or "", w, 1, true) ~= nil
end

local adventure = require "game.model.adventure"
adventure.enter()
local MODULE = require "game.data.museum.module"
local CARDS = require "game.data.museum.cards"
local LIB = require "game.data.map_library"
local F = require "game.data.museum.fidelity"
local util = require "game.model.util"

local card_by = {}
for _, c in ipairs(CARDS.cards or {}) do
    card_by[c.id] = c
end
local function map_of(id)
    return (LIB.boards or {})[id]
end
local function place_of(m, pid)
    for _, pl in ipairs((m and m.places) or {}) do
        if pl.id == pid then
            return pl
        end
    end
end
local function dist(a, b)
    return math.max(math.abs(a[1] - b[1]), math.abs(a[2] - b[2]))
end

-- SHEET --------------------------------------------------------------------------------------------------
for _, rid in ipairs({ "garden", "entrance", "chamber", "paintings", "gift_shop", "hunting", "offices", "tomorrow", "lecture", "lair" }) do
    local r = F.rooms[rid]
    add("SHEET", "rooms")
    if not r then
        fail("SHEET", rid .. ": not in the sheet")
    else
        if not (r.pages and r.pages[1]) then
            fail("SHEET", rid .. ": no page numbers")
        end
        if not MODULE.rooms[rid] then
            fail("SHEET", rid .. ": the sheet has it, the module doesn't")
        end
        if not map_of(r.map) then
            fail("SHEET", rid .. ": no board " .. tostring(r.map))
        end
        for _, f in ipairs(r.foes or {}) do
            if not card_by[f.cast] then
                fail("SHEET", rid .. ": no cast card " .. tostring(f.cast))
            end
            if not f.page then
                fail("SHEET", rid .. ": " .. tostring(f.cast) .. " has no page")
            end
        end
    end
end

-- START --------------------------------------------------------------------------------------------------
for rid, r in util.sorted_pairs(F.rooms) do
    for _, f in ipairs(r.foes or {}) do
        local c = card_by[f.cast] or {}
        add("START", "foes")
        if f.starts == "prop" and not (c.seen == false or c.dormant) then
            fail("START", rid .. ": " .. f.cast .. " looks like part of the room until it moves (p" .. f.page .. "), and the room says it's there as it opens")
        elseif f.starts == "painting" and not c.dormant then
            fail("START", rid .. ": " .. f.cast .. " is a painting until it climbs out (p" .. f.page .. "), and its mini stands on the mat from the start")
        elseif f.starts == "hidden" and c.visible then
            fail("START", rid .. ": " .. f.cast .. " hides (p" .. f.page .. "), and stands in plain view")
        end
        if (f.wakes == "steal" or f.wakes == "inspect") and not (MODULE.rooms[rid] or {}).optional_fight then
            fail("START", rid .. ": " .. f.cast .. " only fights if " .. (f.wakes == "steal" and "robbed" or "inspected") .. " (p" .. f.page .. "), and the room always fights")
        end
    end
end

-- PLACE --------------------------------------------------------------------------------------------------
for rid, r in util.sorted_pairs(F.rooms) do
    local m = map_of(r.map)
    local function check(what, anchor_name, pid, page, near)
        local pl = place_of(m, pid)
        local an = m and m[anchor_name]
        add("PLACE", "placed")
        if not pl then
            fail("PLACE", rid .. ": the board has no place " .. tostring(pid) .. " for " .. what)
        elseif not an then
            fail("PLACE", rid .. ": the board has no " .. anchor_name .. " anchor for " .. what)
        elseif dist({ pl.x, pl.y }, an) > (near or 3) then
            fail("PLACE", string.format("%s: %s starts at %d,%d, %d squares from %s (%s, p%d)", rid, what, an[1], an[2],
                dist({ pl.x, pl.y }, an), pid, pl.name or "", page))
        end
    end
    for _, f in ipairs(r.foes or {}) do
        if type(f.at) == "string" then
            check(f.cast, f.anchor or "foes", f.at, f.page)
        elseif type(f.at) == "table" and f.at[1] then
            -- (Any of several places: the nearest.)
            local best
            for _, pid in ipairs(f.at) do
                local pl = place_of(m, pid)
                local an = m and m[f.anchor or "foes"]
                if pl and an and (not best or dist({ pl.x, pl.y }, an) < best[2]) then
                    best = { pid, dist({ pl.x, pl.y }, an) }
                end
            end
            check(f.cast, f.anchor or "foes", best and best[1] or f.at[1], f.page, 4)
        elseif type(f.at) == "table" then
            -- (One place per creature: the room's wake squares.)
            local wake = (MODULE.rooms[rid] or {}).wake
            for who, pid in util.sorted_pairs(f.at) do
                local sq = wake and wake.at and wake.at[who]
                local pl = place_of(m, pid)
                add("PLACE", "placed")
                if not (sq and pl) then
                    fail("PLACE", rid .. ": " .. who .. " has no square, or the board no place " .. pid)
                elseif dist(sq, { pl.x, pl.y }) > 1 then
                    fail("PLACE", string.format("%s: %s wakes at %d,%d, not on %s (%s, p%d)", rid, who, sq[1], sq[2], pid, pl.name or "", f.page))
                end
            end
        end
    end
    for _, p in ipairs(r.people or {}) do
        check(p.cast or p.what, p.anchor or "npc", p.place, p.page)
    end
end

-- DOORS --------------------------------------------------------------------------------------------------
for rid, r in util.sorted_pairs(F.rooms) do
    local m = map_of(r.map)
    for _, d in ipairs(r.doors or {}) do
        local pl = place_of(m, d.place)
        local locked_near = false
        for _, pc in ipairs((m and m.features) or {}) do
            if pc.kind == "door_locked" and pl then
                for _, a in ipairs(pc.at or {}) do
                    if dist({ a[1], a[2] }, { pl.x, pl.y }) <= 1 then
                        locked_near = true
                    end
                end
            end
        end
        add("DOORS", "doors")
        if not pl then
            fail("DOORS", rid .. ": the board has no place " .. d.place)
        elseif d.locked and not locked_near then
            fail("DOORS", rid .. ": " .. (pl.name or d.place) .. " is locked in the book (p" .. d.page .. "), and open on the board")
        elseif not d.locked and locked_near then
            fail("DOORS", rid .. ": " .. (pl.name or d.place) .. " isn't locked in the book (p" .. d.page .. "), and is on the board")
        end
    end
end

-- TRAPS --------------------------------------------------------------------------------------------------
do
    local moment_by = {}
    for _, mo in ipairs(MODULE.moments or {}) do
        moment_by[mo.id] = mo
    end
    for rid, ex in util.sorted_pairs(MODULE.explore or {}) do
        for place in util.sorted_pairs(ex.traps or {}) do
            add("TRAPS", "game_traps")
            local found
            for _, t in ipairs((F.rooms[rid] or {}).traps or {}) do
                if t.place == place then
                    found = t
                end
            end
            if not found then
                fail("TRAPS", rid .. ": the trap at " .. place .. " isn't in the sheet: the book's, or ours?")
            elseif not found.ours then
                fail("TRAPS", rid .. ": the trap at " .. place .. " is a looking-round trap, the game's own, and the sheet calls it the book's")
            elseif not found.book then
                fail("TRAPS", rid .. ": the trap at " .. place .. " is ours, and the sheet doesn't say what the book has there")
            end
        end
    end
    for rid, r in util.sorted_pairs(F.rooms) do
        for _, t in ipairs(r.traps or {}) do
            if t.dc and t.game then
                add("TRAPS", "book_traps")
                local mo = moment_by[t.game]
                local dcs = {}
                for _, o in ipairs((mo and mo.options) or {}) do
                    if o.roll and o.roll.dc then
                        table.insert(dcs, o.roll.dc)
                    end
                end
                if not mo then
                    fail("TRAPS", rid .. ": no moment " .. t.game .. " plays " .. t.what)
                elseif #dcs == 0 then
                    fail("TRAPS", rid .. ": " .. t.game .. " has no roll for " .. t.what)
                else
                    for _, dc in ipairs(dcs) do
                        if dc ~= t.dc then
                            fail("TRAPS", string.format("%s: %s rolls DC %d; the book's is DC %d (p%d)", rid, t.game, dc, t.dc, t.page))
                        end
                    end
                end
            end
        end
    end
end

-- WORDS: as the room opens -------------------------------------------------------------------------------
for rid, r in util.sorted_pairs(F.rooms) do
    local room = MODULE.rooms[rid] or {}
    local opening = { { "its read", room.read } }
    for _, ri in ipairs(room.read_if or {}) do
        table.insert(opening, { "its read", ri.text })
    end
    local cast = room.comps and room.comps.cast and card_by[room.comps.cast]
    if cast and cast.seen ~= false then
        table.insert(opening, { "its cast's line", cast.line })
    end
    for _, h in pairs(MODULE.hooks or {}) do
        if type(h) == "table" and h.room == rid then
            table.insert(opening, { "a hook's payoff", h.payoff })
        end
    end
    for _, s in ipairs(r.secrets or {}) do
        for _, o in ipairs(opening) do
            add("WORDS", "opening_texts")
            for _, w in ipairs(s.words or {}) do
                if has(o[2], w) then
                    fail("WORDS", string.format("%s: %s gives away that %s (p%d): '%s'", rid, o[1], s.what, s.page, string.sub(o[2], 1, 140)))
                end
            end
        end
    end
end

-- WORDS: in whole prologues, before the reveal ----------------------------------------------------------
local RUNS = {}
local real_exit, real_print = os.exit, print
local function sim(seed, style)
    arg = { [0] = "tools/sim/museum.lua", tostring(seed), style, "log" }
    local out = {}
    os.exit = function() error("__done__", 0) end
    print = function(...)
        local t = {}
        for i = 1, select("#", ...) do
            t[i] = tostring(select(i, ...))
        end
        for l in string.gmatch(table.concat(t, " ") .. "\n", "([^\n]*)\n") do
            table.insert(out, l)
        end
    end
    local ok, err = pcall(dofile, "tools/sim/museum.lua")
    print, os.exit = real_print, real_exit
    if not ok and err ~= "__done__" then
        fail("WORDS", "seed " .. seed .. " " .. style .. ": " .. tostring(err))
        return
    end
    table.insert(RUNS, { tag = seed .. " " .. style, L = out })
end
for _, style in ipairs({ "careful", "random", "careless" }) do
    for seed = 81, 80 + SEEDS do
        sim(seed, style)
    end
end
local voice = require "game.model.voice"
local by_name = {}
for rid, room in pairs(MODULE.rooms) do
    if room.name then
        by_name[room.name] = rid
    end
end
for _, R in ipairs(RUNS) do
    -- (Where each scene's foes show themselves: the line that is the moment, or the last narration before
    -- its fight opens, which brings them on.)
    local shown_at, rid_at, scene_rid = {}, {}, nil
    local last_narr
    for i, l in ipairs(R.L) do
        local title = string.match(l, "^== Scene %d+[^:]*: (.-) %(")
        if title then
            scene_rid, last_narr = by_name[title], nil
        end
        rid_at[i] = scene_rid
        if string.match(l, "^  %[narration%] ") then
            last_narr = i
        end
        if scene_rid and string.find(l, "## fight starts", 1, true) then
            shown_at[i] = true
            if last_narr and rid_at[last_narr] == scene_rid then
                shown_at[last_narr] = true
            end
        end
    end
    local rid, revealed = nil, false
    for i, l in ipairs(R.L) do
        if rid_at[i] ~= rid then
            rid, revealed = rid_at[i], false
        end
        local sheet = rid and F.rooms[rid]
        local who, text = string.match(l, "^  %[([^%]]+)%] (.*)$")
        if shown_at[i] then
            revealed = true
        end
        for _, s in ipairs((sheet and sheet.secrets) or {}) do
            for _, w in ipairs(s.shows or {}) do
                if has(text, w) then
                    revealed = true
                end
            end
        end
        if who and sheet and not revealed and voice.heard(who) and who ~= "aside" then
            for _, s in ipairs(sheet.secrets or {}) do
                if s.reveal == "fight" then
                    add("WORDS", "lines_before_a_reveal")
                    for _, w in ipairs(s.words or {}) do
                        if has(text, w) then
                            fail("WORDS", string.format("%s (%s): said before anything showed it, that %s (p%d): '%s'",
                                R.tag, rid, s.what, s.page, string.sub(text, 1, 140)))
                        end
                    end
                end
            end
        end
    end
end
E.WORDS = E.WORDS or {}
E.WORDS.prologues = #RUNS

-- ITEMS --------------------------------------------------------------------------------------------------
do
    local pr = F.rooms.paintings
    local by_place = {}
    for _, it in ipairs(pr.items or {}) do
        by_place[it.place] = it
    end
    for who, pid in util.sorted_pairs(pr.portraits or {}) do
        local port = who == "default" and MODULE.portrait_default or (MODULE.portraits or {})[who]
        local book = by_place[pid]
        add("ITEMS", "portraits")
        if not (port and book) then
            fail("ITEMS", "the painting for " .. who .. " (" .. pid .. ") is missing from the module or the sheet")
        else
            local weapon = not (port.empty or port.not_weapon)
            if book.paint and not weapon then
                fail("ITEMS", string.format("%s's painting (%s, p%d) gives a painted weapon in the book; the game gives %s", who, pid, book.page, tostring(port.gift)))
            elseif not book.paint and weapon then
                fail("ITEMS", string.format("%s's painting (%s, p%d) gives no painted weapon in the book; the game's '%s' counts as paint", who, pid, book.page, tostring(port.gift)))
            end
            if book.empty and not port.empty then
                fail("ITEMS", string.format("%s's painting (%s, p%d) has nothing to take in the book; the game gives %s", who, pid, book.page, tostring(port.gift)))
            end
        end
    end
    -- Every magic item the module hands out: the book's, or marked as ours with what the book has instead.
    local listed = {}
    for _, r in pairs(F.rooms) do
        for _, it in ipairs(r.items or {}) do
            if it.game then
                listed[it.game] = it
            end
        end
    end
    for id in util.sorted_pairs(MODULE.magic_items or {}) do
        add("ITEMS", "magic_items")
        local it = listed[id]
        if not it then
            fail("ITEMS", "the module's magic item " .. id .. " isn't in the sheet: is it the book's, or ours?")
        elseif it.ours and not it.book then
            fail("ITEMS", id .. " is ours, and the sheet doesn't say what the book has instead")
        end
    end
end

-- Report -------------------------------------------------------------------------------------------------
local total = 0
for _, item in ipairs(ITEMS) do
    local f = fails[item]
    local bits = {}
    for k, v in util.sorted_pairs(E[item] or {}) do
        table.insert(bits, k .. " " .. tostring(v))
    end
    print(string.format("%-6s %s%s", item, table.concat(bits, ", "), f and ("  FAIL x" .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("       FAIL: " .. m)
    end
    total = total + (f and f.n or 0)
end
print(total == 0 and "book check: all clear" or ("book check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
