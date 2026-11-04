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
    { file = "game/data/inspiration.lua", mod = "game.data.inspiration", group = "Inspiration" },
    { file = "game/data/rests.lua", mod = "game.data.rests", group = "Rests" },
}

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
    tags = true, setting = true, like = true, effects = true, mus = true, answer = true, joins = true, opt = true,
    rooms = false, at = true, part = true, boss = true, style = true, tone = true, sub_tone = true, pose = true,
    lean = true, leans = true, arch = true, doers = true, needs = true, sprite = true, icon = true, font = true,
    key = true, there = true, warn = true, risk = true, harsh = true, drag = true, hurt = true, speaker = true,
    suits = true, objects = true, enjoys = true, feeds = true, tag_taste = true, content = true, promise = true,
    card = true, minion = true, where = true, fixed_actor = true }
local PLAYERS = { mara = true, dev = true, jess = true, sam = true }
local HEROES = { mara = "Thessaly", dev = "Brannoc", jess = "Pip", sam = "Oswin" }

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
    for _, k in ipairs(keys) do
        if not (type(k) == "string" and NOT_TEXT[k]) then
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
