-- Every line an adventure can say, for the dialogue review page (the playtest, November 3: "a tool
-- for me to see dialogue in game vs book, tweak it, and push it back"). Walks the adventure's own
-- data (game/data/<adventure>/*.lua) and the shared lines the adventure lets through
-- (adventure.fits), and writes one JSON file: each line's file, its place in the data (a key path),
-- the room it belongs to, who says it, and its text. The page shows them beside the book's pages
-- (the reader's own PDF, opened in their browser: the book's text never goes in this file), takes
-- edits, and tools/dialogue/apply.lua writes the edits back. Run from the project root:
--   lua tools/dialogue/export.lua out.json
-- Works for any adventure written in the module format: change ADV_FILES and BOOK_PAGES.

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
adventure.enter()
local MODULE = adventure.data

-- The adventure's own files, and the shared ones whose lines can play in it.
local ADV_FILES = {
    { file = "game/data/museum/module.lua", mod = "game.data.museum.module", group = "Adventure" },
    { file = "game/data/museum/cards.lua", mod = "game.data.museum.cards", group = "Adventure cards" },
    { file = "game/data/museum/table_life.lua", mod = "game.data.museum.table_life", group = "Small moments" },
    { file = "game/data/museum/people.lua", mod = "game.data.museum.people", group = "People who remember" },
}
local SHARED_FILES = {
    { file = "game/data/barks.lua", mod = "game.data.barks", group = "Fight barks" },
    { file = "game/data/intros.lua", mod = "game.data.intros", group = "Introductions" },
    { file = "game/data/thoughts.lua", mod = "game.data.thoughts", group = "Thoughts" },
    { file = "game/data/table_behaviors.lua", mod = "game.data.table_behaviors", group = "Table behaviour" },
    { file = "game/data/killing_blows.lua", mod = "game.data.killing_blows", group = "Killing blows" },
    { file = "game/data/friction.lua", mod = "game.data.friction", group = "Friends and friction" },
    { file = "game/data/session_zero.lua", mod = "game.data.session_zero", group = "Session Zero" },
    { file = "game/data/death.lua", mod = "game.data.death", group = "Death" },
    { file = "game/data/decisions.lua", mod = "game.data.decisions", group = "Shared cards" },
    { file = "game/data/rests.lua", mod = "game.data.rests", group = "Rests" },
}
-- Lines kept in the game's code, beside what uses them (each table is exposed as a field of its module).
local CODE_TABLES = {
    { file = "game/model/museum_night.lua", mod = "game.model.museum_night", group = "Game night",
      keys = { "LOOK_SAY", "LEAN_WHY", "VOTE_WHY", "VOTE_NAMED", "VOTE_PUSH_LINES", "VOTE_CAVE", "VOTE_SIDE", "VOTE_TIE", "VOTE_TIE_SPLIT", "BREAK_START",
               "BREAK_END", "BREAK_LOGS", "BREAK_SAD", "WEEKLY", "GENTLE_STOP" } },
    { file = "game/model/museum_week.lua", mod = "game.model.museum_week", group = "Group chat", keys = { "CHAT", "CHAT_REPLY" } },
    { file = "game/model/night.lua", mod = "game.model.night", group = "Game night",
      keys = { "READY", "REACTED", "WRAP_LINES", "FRANC_LINES", "FIGHT_CAPTIONS", "INSPIRE_LINES", "FOE_LINES", "FOE_HIDDEN",
               "FOE_ALONE", "FIGHT_TEXT", "ALONE_TEXT", "LATE_LINES", "LATE_HIGH", "RESEARCH_LINES" } },
    { file = "game/model/items.lua", mod = "game.model.items", group = "Game night", keys = { "GOT" } },
    { file = "game/model/museum_night.lua", mod = "game.model.museum_night", group = "Game night", keys = { "WORLD_LINES" } },
    { file = "game/model/fight.lua", mod = "game.model.fight", group = "Game night", keys = { "SWITCH_LINES" } },
    { file = "game/model/intros.lua", mod = "game.model.intros", group = "Introductions", keys = { "ASKS_OPEN", "ANSWER" } },
}
-- Parts of a file listed under another file: the module pulls in its small moments, which are listed under
-- game/data/museum/table_life.lua (where an edit to them goes).
local SKIP_TOP = { ["game/data/museum/module.lua"] = { table_life = true, people_memory = true, people_lines = true, people_about = true,
                                                         ideas = true } }


-- Where each room is in the book (the reader's own copy: page numbers only).
local BOOK_PAGES = {
    street = { 4, 7 }, garden = { 8, 10 }, entrance = { 11, 12 }, chamber = { 12, 14 }, paintings = { 15, 16 },
    gift_shop = { 16, 17 }, hunting = { 18, 20 }, offices = { 21, 22 }, tomorrow = { 22, 23 }, lecture = { 23, 24 },
    stairs = { 25, 25 }, lair = { 25, 27 },
}

-- Keys that are never said out loud (names of things, conditions, numbers).
local NOT_TEXT = { id = true, when = true, kind = true, type = true, trigger = true, skill = true, actor = true,
    class = true, room = true, spot = true, who = true, owner = true, monster = true, cast = true, map = true,
    order = true, next = true, links = true, comps = true, encounter = true, mark = true, flag = true, knob = true,
    tags = true, setting = true, like = true, effects = true, mus = true, joins = true, opt = true,
    rooms = false, at = true, part = true, boss = true, style = true, tone = true, sub_tone = true, pose = true,
    lean = true, leans = true, arch = true, doers = true, needs = true, sprite = true, icon = true, font = true,
    key = true, there = true, warn = true, risk = true, harsh = true, drag = true, hurt = true, speaker = true,
    suits = true, objects = true, enjoys = true, feeds = true, tag_taste = true, content = true, promise = true,
    card = true, minion = true, where = true, fixed_actor = true, effect = true, sees = true, hears = true, start = true,
    weights = true, breaks = true, thing = true, kind = true, whom = true }
local PLAYERS = { mara = true, dev = true, jess = true, sam = true }
local HEROES = { mara = "Thessaly", dev = "Brannoc", jess = "Pip", sam = "Oswin" }
local json = require "game.model.jsonlite"

local function keep_line(file, path, l)
    if file == "game/data/dialogue/lines.json" then
        -- The friends' own lines only: the adventure's people have theirs in the module, and the plain
        -- voice for anyone without lines of their own ("anyone") isn't a friend's.
        return PLAYERS[l.speaker or ""]
    end
    return true
end

local lines = {}
local seen_text = {}

local function json_str(s)
    s = string.gsub(s, '[%c"\\]', function(ch)
        local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
        return map[ch] or string.format("\\u%04x", string.byte(ch))
    end)
    return '"' .. s .. '"'
end

local function encode(v)
    local t = type(v)
    if t == "string" then
        return json_str(v)
    elseif t == "number" then
        return tostring(v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "table" then
        if #v > 0 or next(v) == nil then
            local out = {}
            for _, x in ipairs(v) do
                table.insert(out, encode(x))
            end
            return "[" .. table.concat(out, ",") .. "]"
        end
        local keys = {}
        for k in pairs(v) do
            table.insert(keys, tostring(k))
        end
        table.sort(keys)
        local out = {}
        for _, k in ipairs(keys) do
            table.insert(out, json_str(k) .. ":" .. encode(v[k]))
        end
        return "{" .. table.concat(out, ",") .. "}"
    end
    return "null"
end

-- What a string is, from where it sits: who says it, the room it's in, what kind of line.
local function classify(path, owners)
    local speaker, room, role
    for i, k in ipairs(path) do
        local ks = tostring(k)
        if PLAYERS[ks] then
            speaker = ks
        end
        if BOOK_PAGES[ks] and (path[i - 1] == "rooms" or path[i - 1] == "explore" or path[i - 1] == "LEFT"
            or i == 2) then
            room = room or ks
        end
    end
    for _, o in ipairs(owners) do
        room = room or (type(o) == "table" and type(o.room) == "string" and o.room) or nil
        if type(o) == "table" and type(o.who) == "string" and PLAYERS[o.who] then
            speaker = speaker or o.who
        end
    end
    local last = tostring(path[#path])
    local prev = tostring(path[#path - 1] or "")
    if last == "label" or prev == "label" then
        role = "Option"
    elseif last == "title" then
        role = "Title"
    elseif last == "text" or last == "read" then
        role = "Read aloud / card text"
    elseif last == "log" or prev == "lines" or last == "line" then
        role = "Narration"
    elseif last == "ask" then
        role = speaker and "Player" or "Question"
    elseif last == "dull" or last == "detail" or last == "lore" or last == "answer" or last == "better" then
        role = "DM's answer"
    elseif speaker then
        role = "Player"
    else
        role = "Line"
    end
    return speaker, room, role
end

local function walk(src, t, path, owners, shared, depth)
    depth = depth or 0
    if depth > 14 then
        return
    end
    if type(t) == "string" then
        if #t < 3 or not string.find(t, "%a%a") or not string.find(t, " ") then
            return       -- (a name or a key, not a line)
        end
        if shared and not adventure.fits(t) then
            return       -- (a shared line that never plays in this adventure)
        end
        local speaker, room, role = classify(path, owners)
        local p = {}
        for _, k in ipairs(path) do
            table.insert(p, k)
        end
        local key = src.file .. "|" .. t
        local dup = seen_text[key]
        if dup then
            dup.count = (dup.count or 1) + 1
            return
        end
        local e = { id = #lines + 1, file = src.file, group = src.group, path = p, text = t, room = room,
                    speaker = speaker, hero = speaker and HEROES[speaker] or nil, role = role, shared = shared or nil }
        seen_text[key] = e
        table.insert(lines, e)
        return
    end
    if type(t) ~= "table" then
        return
    end
    if shared then
        -- A shared entry about things the adventure's world doesn't have.
        if type(path[#path]) == "number" and adventure.deep_foreign(t) then
            return
        end
    end
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then
            return a < b
        end
        return type(a) == "number"
    end)
    table.insert(owners, 1, t)
    local skip = #path == 0 and SKIP_TOP[src.file] or {}
    for _, k in ipairs(keys) do
        if not (type(k) == "string" and (NOT_TEXT[k] or skip[k])) then
            table.insert(path, k)
            walk(src, t[k], path, owners, shared, depth + 1)
            table.remove(path)
        end
    end
    table.remove(owners, 1)
end

for _, src in ipairs(ADV_FILES) do
    walk(src, require(src.mod), {}, {}, false)
end
for _, src in ipairs(SHARED_FILES) do
    local ok, mod = pcall(require, src.mod)
    if ok then
        walk(src, mod, {}, {}, true)
    end
end
-- Who says the code's lines: a friend by their type (players.lua: each type is one friend's, first or
-- second), the narration otherwise.
local TYPE_WHO = { storyteller = "mara", explorer = "mara", butt_kicker = "dev", power_gamer = "dev",
                   method_actor = "jess", instigator = "jess", casual = "sam", tactician = "sam" }
local MAIN_WHO = { storyteller = "mara", butt_kicker = "dev", method_actor = "jess", casual = "sam" }
for _, src in ipairs(CODE_TABLES) do
    local mod = require(src.mod)
    for _, k in ipairs(src.keys) do
        local first = #lines + 1
        walk(src, assert(mod[k], src.mod .. " doesn't expose " .. k), { k }, {}, false)
        for i = first, #lines do
            local e = lines[i]
            -- (Looking round goes by each friend's main type only: museum_night look_card.)
            local sp = (k == "LEAN_WHY" and TYPE_WHO[e.path[2]]) or (k == "LOOK_SAY" and MAIN_WHO[e.path[2]])
                or ((k == "VOTE_CAVE" or k == "VOTE_SIDE") and PLAYERS[e.path[2]] and e.path[2]) or nil
            e.speaker, e.hero = sp, sp and HEROES[sp] or nil
            e.role = sp and "Player" or "Narration"
        end
    end
end

-- The table-talk library (game/data/dialogue/lines.json): each friend's lines by moment.
do
    local lib = require("game.model.content").dialogue
    local src = { file = "game/data/dialogue/lines.json", group = "Table talk" }
    -- (Only the file's own lines: the adventure adds its people's lines to the library at load,
    -- and those are listed above, under the adventure's file.)
    local own = {}
    local raw = json.decode(assert(io.open("game/data/dialogue/lines.json")):read("*a"))
    for _, l in ipairs(raw.lines or {}) do
        own[l.id] = true
    end
    for _, l in ipairs(lib.lines or {}) do
        if own[l.id] and type(l.text) == "string" and adventure.fits(l.text) and adventure.fits(l.reply)
            and l.status ~= "cut" and l.status ~= "rejected" and keep_line(src.file, { "lines", l.id }, l) then
            local key = src.file .. "|" .. l.text
            if not seen_text[key] then
                local sp = PLAYERS[l.speaker or ""] and l.speaker or nil
                local e = { id = #lines + 1, file = src.file, group = src.group, path = { "lines", l.id }, text = l.text,
                            speaker = sp, hero = sp and HEROES[sp] or nil, role = "Player", shared = true,
                            moment = l.trigger }
                seen_text[key] = e
                table.insert(lines, e)
            end
        end
    end
end

-- When each line is said, and how sure it is to be (tools/dialogue/when.lua): rules keyed on the
-- line's file and the shape of its path, read off the code that uses that data.
local when_mod = require "tools.dialogue.when"
local specific = 0
do
    local cells = when_mod.cells(lines)
    for _, e in ipairs(lines) do
        local r, matched = when_mod.describe(e, cells)
        e.when, e.odds = r.when, r.odds
        if matched then
            specific = specific + 1
        end
    end
end

-- The rooms, in the order they come in the book.
local rooms = {}
for _, id in ipairs({ "street", "garden", "entrance", "chamber", "paintings", "gift_shop", "hunting", "offices",
                      "tomorrow", "lecture", "stairs", "lair" }) do
    local r = MODULE.rooms[id]
    table.insert(rooms, { id = id, name = r and r.name or id, pages = BOOK_PAGES[id] })
end

local out = {
    adventure = MODULE.title or "The adventure",
    credit = MODULE.credit,
    generated = os.date("!%Y-%m-%d %H:%M UTC"),
    rooms = rooms,
    lines = lines,
}
local path = arg[1] or "dialogue.json"
local f = assert(io.open(path, "w"))
f:write(encode(out))
f:close()
local by = {}
for _, e in ipairs(lines) do
    by[e.group] = (by[e.group] or 0) + 1
end
local parts = {}
for g, n in pairs(by) do
    table.insert(parts, g .. " " .. n)
end
table.sort(parts)
print(string.format("dialogue export: %d lines (%s) -> %s", #lines, table.concat(parts, ", "), path))
print(string.format("when: %d of %d lines (%.1f%%) have a specific when; the rest have the fallback", specific, #lines,
    100 * specific / math.max(1, #lines)))
