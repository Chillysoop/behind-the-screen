-- What the table has been shown in a room (Conner, November 5: "in real life the DM knows everything and is
-- revealing everything to the players: location, terrain, characters they see, character quirks and tells").
-- The public half of a room, as secrets.lua is the hidden half: every place and feature on a room's board is
-- something the heroes can see once it's described, and only then can a friend name it. A line said to the
-- table shows what it names (the room's opening, a place's line as someone walks over, a moment's scene); a
-- friend's line that names something here nobody's described gets it described first, as the DM would when
-- a player turns to it ("Is something in that jungle moving?": the jungle, then the question).
--
-- campaign.adv.shown[room] = { [thing id] = week }
--   things(room)            the room's things: { id, words, line } from its board (map_library: places and
--                           features), the floor, walls and doors left out
--   hear(c, room, text)     a line said to the table: what it names is shown
--   unshown(c, room, text)  what a line names that nobody's shown yet
-- Pure Lua.

local util = require "game.model.util"

local M = {}

-- (Words too common to mean the thing: "Down the stairs", "a glass of wine".)
M.STOP = { down = true, floor = true, roof = true, door = true, doors = true, walls = true, wall = true, steps = true,
           stairs = true, glass = true, holes = true, front = true, path = true, paths = true, light = true, statue = true,
           counter = true, case = true, cases = true, desk = true, table = true, chair = true, plants = true, branches = true,
           specimen = true, misted = true, frozen = true, screaming = true, visitors = true, victims = true, passage = true }

local cache = {}
function M.things(room)
    local key = util.lazy("game.model.adventure").current() .. ":" .. tostring(room)
    if cache[key] then
        return cache[key]
    end
    local ok, lib = pcall(require, "game.data.map_library")
    local out = {}
    -- (A room id names a board only in its own adventure: the museum's garden isn't the Sheep Chase's.)
    local cur = util.lazy("game.model.adventure").current()
    for _, b in util.sorted_pairs(ok and lib.boards or {}) do
        if b.room == room and (b.adventure == nil or b.adventure == cur) then
            local feat = {}
            for _, f in ipairs(b.features or {}) do
                feat[f.id] = f
            end
            local used = {}
            for _, pl in ipairs(b.places or {}) do
                local words = {}
                local head = string.lower(string.gsub(pl.name or "", "^the ", ""))
                -- (Its name, and the name's last word: "the misted cabinet", "cabinet".)
                if head ~= "" then
                    table.insert(words, head)
                    local last = string.match(head, "(%a+)$")
                    if last and #last >= 4 and not M.STOP[last] and last ~= head then
                        table.insert(words, last)
                    end
                end
                for _, fid in ipairs(pl.near or {}) do
                    local f = feat[fid]
                    -- (Only the feature that is this place, "the pickling jars" and the jars: not the jungle
                    -- beside them.)
                    local its = f and string.find(head, fid, 1, true)
                    for _, w in ipairs((f and f.words) or {}) do
                        its = its or string.find(head, string.lower(w), 1, true)
                    end
                    if f and not f.base and its then
                        used[fid] = true
                        for _, w in ipairs(f.words or {}) do
                            if #w >= 4 and not M.STOP[w] then
                                table.insert(words, string.lower(w))
                            end
                        end
                    end
                end
                table.insert(out, { id = pl.id, words = words, line = pl.line })
            end
            for _, f in ipairs(b.features or {}) do
                if not f.base and not used[f.id] then
                    local words = {}
                    for _, w in ipairs(f.words or {}) do
                        if #w >= 4 and not M.STOP[w] then
                            table.insert(words, string.lower(w))
                        end
                    end
                    if #words > 0 then
                        table.insert(out, { id = f.id, words = words, line = f.say and (util.capitalize(f.say) .. ".") or nil })
                    end
                end
            end
        end
    end
    cache[key] = out
    return out
end

local function find_word(low, w)
    local pat = "%f[%w]" .. string.gsub(w, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "%f[%W]"
    return string.find(low, pat) ~= nil
end

-- (One of these alone is table talk, not the thing: "Hold on, I have the book open" is the rulebook, not the
-- lecture theatre's stacks of books. Seed 523, round three's words check.)
M.NOT_ONE = { book = true, page = true, card = true, sheet = true }

local function names(text, t)
    local low = string.lower(text or "")
    for _, w in ipairs(t.words) do
        -- (And one of them: "the pickling jar" names "the pickling jars".)
        local one = string.match(w, "^(.-[^s])s$")
        if one and M.NOT_ONE[one] then
            one = nil
        end
        if find_word(low, w) or (one and find_word(low, one)) then
            return true
        end
    end
    return false
end

local function st(c, room)
    local adv = c and c.adv
    if not adv or not room then
        return nil
    end
    adv.shown = adv.shown or {}
    adv.shown[room] = adv.shown[room] or {}
    return adv.shown[room]
end

function M.is_shown(c, room, id)
    local s = st(c, room)
    return s ~= nil and s[id] ~= nil
end

function M.show(c, room, id)
    local s = st(c, room)
    if s and not s[id] then
        s[id] = c.week or 0
    end
end

function M.hear(c, room, text)
    if not (room and text) then
        return
    end
    for _, t in ipairs(M.things(room)) do
        if not M.is_shown(c, room, t.id) and names(text, t) then
            M.show(c, room, t.id)
        end
    end
end

-- (Behind a door still locked: not there to be seen yet. MODULE.behind_doors.)
function M.behind(c, room, id)
    local mod = util.lazy("game.model.adventure").data or {}
    local b = mod.behind_doors and mod.behind_doors[room]
    if not b then
        return false
    end
    local flags = c and c.adv and c.adv.flags or {}
    return util.contains(b.places or {}, id) and not (b.open and flags[b.open])
end

function M.unshown(c, room, text)
    local out = {}
    if not (room and text) then
        return out
    end
    for _, t in ipairs(M.things(room)) do
        if not M.is_shown(c, room, t.id) and not M.behind(c, room, t.id) and names(text, t) then
            table.insert(out, t)
        end
    end
    return out
end

-- The adventure's people, by name: a friend names someone only once the table's heard who they are (a line
-- said to the table with their name in it). MODULE.people's `known` are known from the start.
-- campaign.adv.names_heard = { [npc id] = week }
function M.hear_names(c, text)
    if not (c and c.adv and text) then
        return
    end
    local npcs = util.lazy("game.model.npcs")
    c.adv.names_heard = c.adv.names_heard or {}
    for _, n in ipairs(npcs.all()) do
        if not c.adv.names_heard[n.id] then
            local nm = n.short or n.name
            if nm and find_word(string.lower(text), string.lower(nm)) then
                c.adv.names_heard[n.id] = c.week or 0
            end
        end
    end
end

function M.named(c, id)
    local adv = c and c.adv
    if adv and adv.names_heard and adv.names_heard[id] then
        return true
    end
    local mod = util.lazy("game.model.adventure").data or {}
    for _, p in ipairs(mod.people or {}) do
        if p.id == id and p.known then
            return true
        end
    end
    return false
end

return M
