-- The secrets check (docs/design/2026-11-05-secrets-and-knowledge.md; Conner's calls of November 5). Driven by the
-- adventure's own data (MODULE.secrets, MODULE.told), so an imported campaign gets it for free. Run from the
-- project root:
--     lua tools/tests/secrets_check.lua [runs]
--   DATA   every secret says what it is, its page, what kind of thing holds it and what the DM says when it
--          comes out; it has two ways out or more, of two kinds or more (the usual ones for its kind count);
--          every way out points at something real (a person with a sheet, a room, a place on that room's
--          board, a thing in the adventure, a real skill or spell, an event the game fires); a secret told a
--          piece at a time has its pieces and says which it needs
--   LINT   no line a friend says in the adventure's data (a vote's want and reasons, a pull, an approach, a
--          question, a reaction, the group chat) names a secret's words unless a condition waits for it to be
--          told; and no hidden name is in a thing's or a place's name
--   REACH  in whole prologues, three kinds of DM: every secret whose room was played comes out at least once;
--          the big ones (`major`: the Gorgon, her sisters, the Witness) come out more than one way and to more
--          than one hero; and the friends dig in most nights. A coverage report shows how each came out
--   EARLY  nothing is known without a way it came out (the log says how); and no friend in character names
--          what their hero doesn't know (the night's masked lines, by hero)

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local RUNS = tonumber(arg[1]) or 3
local ITEMS = { "DATA", "LINT", "REACH", "EARLY" }
local fails, E = {}, {}
local function fail(item, msg)
    fails[item] = fails[item] or { n = 0 }
    if #fails[item] < 12 then
        table.insert(fails[item], msg)
    end
    fails[item].n = fails[item].n + 1
end
local function add(item, key, n)
    E[item] = E[item] or {}
    E[item][key] = (E[item][key] or 0) + (n or 1)
end
local function set(item, key, v)
    E[item] = E[item] or {}
    E[item][key] = v
end

local adventure = require "game.model.adventure"
adventure.enter()
local MODULE = adventure.data
local secrets = require "game.model.secrets"
local util = require "game.model.util"
local skills = require "game.rules.skills"
local spells = require "game.rules.spells"
local lib = require "game.data.map_library"

-- DATA ------------------------------------------------------------------------------------------------
local npc_ids = {}
for _, id in ipairs((MODULE.npc_sheet or {}).order or {}) do
    npc_ids[id] = true
end
-- (The standard's people and places, for an adventure written in it: M.people, M.places and their spots.)
for _, p in ipairs(MODULE.people or {}) do
    if p.tier then npc_ids[p.id] = true end
end
local rooms = {}
for id in pairs(MODULE.rooms or {}) do rooms[id] = true end
for _, pl in ipairs(MODULE.places or {}) do rooms[pl.id] = true end
local board_places = {}
for _, pl in ipairs(MODULE.places or {}) do
    if pl.spots then
        board_places[pl.id] = {}
        for _, sp in ipairs(pl.spots) do board_places[pl.id][sp] = true end
    end
end
for _, b in pairs(lib.boards or {}) do
    if b.room and (b.adventure == nil or b.adventure == adventure.current()) then
        board_places[b.room] = board_places[b.room] or {}
        for _, pl in ipairs(b.places or {}) do
            board_places[b.room][pl.id] = true
        end
    end
end
local things = {}
for _, it in ipairs(MODULE.items or {}) do
    things[it.id] = true
end
-- (The events the game fires: "fight_<room>" for every room's fight, and the names the code passes to
-- secrets.event or a moment's secret_event.)
local fired = {}
for room in pairs(MODULE.rooms or {}) do
    fired["fight_" .. room] = true
end
-- (And the standard's story events: each fires its own id.)
for _, ev in ipairs(MODULE.events or {}) do
    fired[ev.id] = true
end
local function scan_code(path)
    local f = io.open(path)
    if not f then
        return
    end
    local s = f:read("*a")
    f:close()
    for ev in string.gmatch(s, 'secrets"%)%.event%([^,]+,%s*"([%w_]+)"') do
        fired[ev] = true
    end
    for ev in string.gmatch(s, 'secret_event%s*=%s*"([%w_]+)"') do
        fired[ev] = true
    end
end
for _, p in ipairs({ "game/model/fight.lua", "game/model/night.lua", "game/model/museum_night.lua", "game/data/museum/module.lua" }) do
    scan_code(p)
end
-- (night.lua fires paint_hit and deafened from a fight's options.)
do
    local f = io.open("game/model/night.lua")
    local s = f and f:read("*a") or ""
    if f then f:close() end
    for ev in string.gmatch(s, 'secrets%.event%(self%.campaign,%s*"([%w_]+)"') do
        fired[ev] = true
    end
end

local KINDS = { check = true, ask = true, read = true, see = true, spell = true, perform = true, trade = true, steal = true, event = true, dm = true }
for _, key in ipairs(secrets.list()) do
    local d = secrets.def(key)
    add("DATA", "secrets")
    if not d.page then fail("DATA", key .. ": no page") end
    if not d.type or not (secrets.DEFAULTS[d.type] or d.defaults == false) then fail("DATA", key .. ": no kind of holder (type)") end
    if not d.tell or #d.tell == 0 then fail("DATA", key .. ": nothing for the DM to say when it comes out (tell)") end
    if d.parts and not d.needs then fail("DATA", key .. ": told a piece at a time, but doesn't say which pieces it needs") end
    local kinds, n = {}, 0
    for _, p in ipairs(secrets.paths(key)) do
        if p.kind ~= "dm" then
            n = n + 1
            kinds[p.kind] = true
            add("DATA", "ways_out")
        end
        if not KINDS[p.kind] then fail("DATA", key .. ": a way out of no known kind: " .. tostring(p.kind)) end
        if type(p.on) == "string" and not npc_ids[p.on] then fail("DATA", key .. ": a way out on someone with no sheet: " .. p.on) end
        if p.room and not rooms[p.room] then fail("DATA", key .. ": a way out in no room: " .. p.room) end
        if p.spot and not (board_places[p.room or ""] or {})[p.spot] then
            fail("DATA", key .. ": a way out at no place on " .. tostring(p.room) .. "'s board: " .. p.spot)
        end
        if p.item and not things[p.item] then fail("DATA", key .. ": a way out through a thing the adventure doesn't have: " .. p.item) end
        for _, s in ipairs(p.skill or {}) do
            if not skills.ABILITY[s] then fail("DATA", key .. ": no such skill: " .. s) end
        end
        for _, sp in ipairs(p.spell or {}) do
            -- (A spell the rules don't have yet is fine for a hero who might: but it has to be a spell's name.)
            if not string.find(sp, "^[a-z_]+$") then fail("DATA", key .. ": not a spell's name: " .. sp) end
            if spells.list[sp] then add("DATA", "spells_the_rules_have") end
        end
        if p.kind == "event" and not fired[p.event or ""] then fail("DATA", key .. ": an event nothing fires: " .. tostring(p.event)) end
    end
    local nk = 0
    for _ in pairs(kinds) do nk = nk + 1 end
    if n < 2 or nk < 2 then
        fail("DATA", key .. ": " .. n .. " ways out of " .. nk .. " kinds; it needs two of two")
    end
end

-- LINT ------------------------------------------------------------------------------------------------
-- The names that wait (told keys with words, not the DM's own labels, which are renamed as they're said).
local WAIT = {}
for key, d in util.sorted_pairs(secrets.defs()) do
    if d.words and not d.always then
        WAIT[key] = d.words
    end
end
local FRIEND_KEYS = { say = true, points = true, want = true, intent = true, ask = true, asks = true, react = true, talk = true,
                      talk_sad = true, theory = true, chat = true }
local told_mod = require "game.model.told"
local function names_of(text)
    local out = {}
    for key, words in pairs(WAIT) do
        for _, w in ipairs(words) do
            if told_mod.find(text, w) then
                out[key] = true
            end
        end
    end
    return out
end
-- (Does a condition on the way down wait for the key: told, hinted, or a flag the secret sets.)
local function covers(conds, key)
    local d = secrets.def(key) or {}
    for _, c in ipairs(conds) do
        local function has(v)
            if v == key then return true end
            if type(v) == "table" then
                for _, x in ipairs(v) do
                    if x == key then return true end
                end
            end
            return false
        end
        if has(c.told) or has(c.hinted) then
            return true
        end
        -- (A condition that only holds once it's told: the secret's `covered_by`, or the flag it unlocks.)
        for _, cb in ipairs(d.covered_by or {}) do
            local all = true
            for f, v in pairs(cb) do
                if c[f] ~= v then
                    all = false
                end
            end
            if all then
                return true
            end
        end
        if d.unlocks and c.flag == d.unlocks.flag then
            return true
        end
    end
    return false
end
local seen_tables = {}
local function walk(t, conds, where, friend)
    if type(t) ~= "table" or seen_tables[t] then
        return
    end
    seen_tables[t] = true
    local here = conds
    if t.when or t.needs then
        here = {}
        for _, c in ipairs(conds) do table.insert(here, c) end
        if t.when then table.insert(here, t.when) end
        if t.needs then table.insert(here, t.needs) end
    end
    for k, v in pairs(t) do
        -- (A friend key's own lines, and a list of them: not a whole card that happens to sit under one, the
        -- ultimatum's `talk`.)
        local is_friend = (friend and type(k) == "number") or FRIEND_KEYS[k]
        if type(v) == "string" and is_friend then
            add("LINT", "friend_lines")
            for key in pairs(names_of(v)) do
                -- (A line that tells it, the confession in someone's own words, is the reveal itself.)
                local tells = false
                for _, ph in ipairs((secrets.def(key) or {}).intro or {}) do
                    tells = tells or told_mod.find(v, ph) ~= nil
                end
                if not tells and not covers(here, key) then
                    fail("LINT", where .. "." .. tostring(k) .. " names " .. key .. " with nothing waiting for it: '" .. string.sub(v, 1, 90) .. "'")
                end
            end
        elseif type(v) == "table" and k ~= "told" and k ~= "secrets" then
            walk(v, here, where .. "." .. tostring(k), is_friend)
        end
    end
end
walk(MODULE, {}, "MODULE", false)
-- (A place's or a thing's name is said as it's walked to or handed over: no hidden name in it.)
for room, places in pairs(board_places) do
    for _, b in pairs(lib.boards) do
        if b.room == room and (b.adventure == nil or b.adventure == adventure.current()) then
            for _, pl in ipairs(b.places or {}) do
                add("LINT", "place_names")
                for key in pairs(names_of(pl.name or "")) do
                    fail("LINT", "the place " .. pl.id .. " in " .. room .. " is called '" .. pl.name .. "', which names " .. key)
                end
            end
        end
    end
end
for _, it in ipairs(MODULE.items or {}) do
    if it.name then
        add("LINT", "thing_names")
        for key in pairs(names_of(it.name)) do
            fail("LINT", "the thing " .. it.id .. " is called '" .. it.name .. "', which names " .. key)
        end
    end
end

-- REACH and EARLY: whole prologues ------------------------------------------------------------------------
local STYLES = { "careful", "random", "careless" }
local found = {}          -- key -> { runs, ways = {}, heroes = {} }
local visited = {}        -- room -> runs
local digs, nights = 0, 0
for r = 1, RUNS do
    for _, style in ipairs(STYLES) do
        local seed = 700 + r
        local cmd = string.format("lua tools/sim/museum.lua %d %s log 2>&1", seed, style)
        local h = io.popen(cmd)
        local out = h:read("*a")
        h:close()
        local tag = seed .. " " .. style
        local rooms = {}
        for name in string.gmatch(out, "== Scene %d+: ([^\n%(]+)") do
            rooms[util.trim and util.trim(name) or name] = true
        end
        for id, room in pairs(MODULE.rooms) do
            for name in pairs(rooms) do
                if room.name and string.find(name, room.name, 1, true) then
                    visited[id] = (visited[id] or 0) + 1
                end
            end
        end
        for _ in string.gmatch(out, "== Night %d+") do
            nights = nights + 1
        end
        local _, n_weeks = string.gsub(out, "\n== Scene 1:", "")
        nights = nights + (n_weeks or 0)
        local _, dn = string.gsub(out, "%(small roll%)[^\n]*\n%s*%[dm%]", "")
        local _, cards = string.gsub(out, ">> Digging:", "")
        digs = digs + cards
        local line = string.match(out, "\n  secrets: ([^\n]*)")
        add("REACH", "prologues")
        for entry in string.gmatch(line or "", "[^;]+") do
            local key, lv, how, by = string.match(entry, "^%s*([%w_]+) (~?)%(([%w_]+), ([%w_%-]+)")
            if key then
                local f = found[key] or { runs = 0, ways = {}, heroes = {} }
                found[key] = f
                f.runs = f.runs + 1
                f.ways[how] = true
                if by ~= "-" then
                    f.heroes[by] = true
                end
                if how == "?" or how == nil then
                    fail("EARLY", tag .. ": " .. key .. " known with no way it came out")
                end
            end
        end
        for m in string.gmatch(out, "%-%- masked friend line: ([^\n]*)") do
            add("EARLY", "masked_lines")
            if string.find(m, "in character%)") then
                fail("EARLY", tag .. ": in character, a friend names what their hero doesn't know: " .. string.sub(m, 1, 140))
            end
        end
        local _, said = string.gsub(out, "Digging", "")
        add("REACH", "digging_cards", said)
        local _, find_rolls = string.gsub(out, "\n  %[(%a+)%] [^\n]*\n  %[narration%][^\n]*\n  %(small roll%)", "")
        -- (Since November 6 the going is the player's own line: "I'll kneel by the scratch marks." agency.lua.)
        local _, announced = string.gsub(out, "\n  %[(%a+)%] [^\n]*\n  %[(%a+)%] I'll [^\n]*\n  %(small roll%)", "")
        find_rolls = find_rolls + announced
        add("REACH", "digs_by_the_dice", find_rolls)
        digs = digs + find_rolls      -- (a dig is a dig, a card or the dice: an adventure whose ways out all have DCs)
    end
end
-- Coverage: how each came out.
local report = {}
for _, key in ipairs(secrets.list()) do
    local d = secrets.def(key)
    local f = found[key]
    local runs = RUNS * #STYLES
    if f then
        local ways, heroes = {}, {}
        for w in util.sorted_pairs(f.ways) do table.insert(ways, w) end
        for h in util.sorted_pairs(f.heroes) do table.insert(heroes, h) end
        table.insert(report, string.format("%s: %d of %d prologues, by %s, found by %s", key, f.runs, runs, table.concat(ways, "/"),
            #heroes > 0 and table.concat(heroes, "/") or "nobody in particular"))
        if d.major and (#ways < 2 or #heroes < 2) then
            fail("REACH", key .. " only ever comes out " .. #ways .. " way(s), to " .. #heroes .. " hero(es)")
        end
    else
        table.insert(report, key .. ": never")
        local room = d.room
        -- (A secret only a thing they might not buy can tell is the table's choice to miss: the scholar's book.)
        local needs_thing = true
        for _, p in ipairs(secrets.paths(key)) do
            if p.kind ~= "dm" and not p.item then
                needs_thing = false
            end
        end
        if room and (visited[room] or 0) >= 3 and not needs_thing then
            fail("REACH", key .. " never comes out, in " .. visited[room] .. " prologues that played " .. room)
        end
    end
    add("REACH", "secrets")
end
-- (RUNS = 0 is the data alone: an adventure the sims don't play yet, the Sheep Chase until step 5.)
if digs == 0 and RUNS > 0 then
    fail("REACH", "nobody ever dug for anything")
end

-- Report ----------------------------------------------------------------------------------------------
local NAMES = { DATA = "every secret has real ways out", LINT = "friend lines wait for what they name",
                REACH = "every secret can be found", EARLY = "nothing known before it's found" }
local total = 0
for _, item in ipairs(ITEMS) do
    local f = fails[item]
    local parts = {}
    for k, v in util.sorted_pairs(E[item] or {}) do
        table.insert(parts, k .. " " .. tostring(v))
    end
    print(string.format("%-6s %-38s %s%s", item, NAMES[item], table.concat(parts, ", "), f and ("  FAIL x" .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("       FAIL: " .. m)
    end
    total = total + (f and f.n or 0)
end
print("coverage:")
for _, l in ipairs(report) do
    print("  " .. l)
end
print(total == 0 and "secrets check: all clear" or ("secrets check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
