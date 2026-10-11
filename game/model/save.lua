-- Saving the campaign between sessions (M7), so playtesters can stop after any session
-- and pick it up later, the way a real table meets once a week. Pure Lua.
--
-- What's saved is the campaign as it stands between weeks: everything except this
-- week's prep board, game night and report (those are rebuilt by start_week). The state
-- is a graph, not a tree (the players are shared by several lists, the rng by the
-- talker), so every table gets a number and links are written as numbers. Tables that
-- belong to the game's data (a card, a dialogue library) are written as their place in
-- game.model.content instead of copied, so they're the same tables again after loading.
--
-- The file is Lua source in a tiny language: one statement per table,
--   T[3] = { m = "rng", "s","s", "n",123456 }
-- the flat list holding key, value, key, value, each led by a tag:
--   n number, s string, b boolean, t another table (by number), c a content path.
-- It loads in an empty environment, so it can only build tables.

local content = require "game.model.content"

local M = {}

M.FORMAT = 1
M.SKIP = { prep = true, night = true, report = true }   -- top-level campaign fields not saved
-- ...except the prep board when the save was made at "Run game night" (campaign.at_night, the
-- fix pass): then the board is kept, and loading starts that night again with it intact. And
-- while prepping (campaign.at_prep, A11): the board autosaves, so quitting mid-prep comes back
-- to the same board, the week not dealt again.
local function keeps_board(campaign)
    return campaign.at_night or campaign.at_prep
end

-- Classes with metatables that can be part of the saved state. The talker's metatable
-- is filled in lazily (game.model.talk requires content, which is fine, but keep the
-- require list here short and obvious).
local function classes()
    return {
        campaign = require "game.model.campaign",
        rng = require "game.model.rng",
        talk = require "game.model.talk",
        prep = require "game.model.prep",
    }
end

-- Every table in content, by its shortest path (keys sorted, so the same build always
-- gives the same paths). Built once per save/load; content is a few thousand tables.
local function sorted_keys(t)
    local keys = {}
    for k in pairs(t) do
        local kt = type(k)
        if kt == "string" or kt == "number" then
            table.insert(keys, k)
        end
    end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then
            return ta == "number"
        end
        return a < b
    end)
    return keys
end

local function content_paths()
    local paths = {}
    local queue = {}
    for _, k in ipairs(sorted_keys(content)) do
        local v = content[k]
        if type(v) == "table" and not paths[v] and not rawget(v, "runtime") then
            paths[v] = { k }
            table.insert(queue, v)
        end
    end
    local i = 1
    while i <= #queue do
        local t = queue[i]
        i = i + 1
        local base = paths[t]
        for _, k in ipairs(sorted_keys(t)) do
            local v = rawget(t, k)
            -- Cards a campaign made for itself (rawget(v, "runtime")) aren't game data: the
            -- campaign keeps them in campaign.registered and they're saved with it.
            if type(v) == "table" and not paths[v] and not rawget(v, "runtime") then
                local p = {}
                for j = 1, #base do
                    p[j] = base[j]
                end
                p[#p + 1] = k
                paths[v] = p
                table.insert(queue, v)
            end
        end
    end
    return paths
end

local function num(v)
    if v ~= v then
        return "0/0"
    elseif v == math.huge then
        return "1/0"
    elseif v == -math.huge then
        return "-1/0"
    end
    if math.type and math.type(v) == "float" and v == math.floor(v) and math.abs(v) < 2 ^ 53 then
        return string.format("%.1f", v) -- keep floats floats in Lua 5.3 (the tests); LuaJIT doesn't care
    end
    if v == math.floor(v) and math.abs(v) < 2 ^ 53 then
        return string.format("%d", v)
    end
    return string.format("%.17g", v)
end

-- A string literal on one line (every statement must stay on its own line).
local function str(s)
    return '"' .. string.gsub(s, '[%c"\\]', function(c)
        return string.format("\\%03d", string.byte(c))
    end) .. '"'
end

local function path_src(p)
    local parts = {}
    for i, k in ipairs(p) do
        parts[i] = type(k) == "number" and num(k) or str(k)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- campaign -> string
function M.dump(campaign)
    local cls = classes()
    local class_name = {}
    for name, mt in pairs(cls) do
        class_name[mt] = name
    end
    local paths = content_paths()
    local dialogue_lib = require "game.model.dialogue"
    local ids, order = {}, {}
    local out = {}

    local function id_of(t)
        if not ids[t] then
            table.insert(order, t)
            ids[t] = #order
        end
        return ids[t]
    end

    local function value(v, where)
        local tv = type(v)
        if tv == "number" then
            return '"n",' .. num(v)
        elseif tv == "string" then
            return '"s",' .. str(v)
        elseif tv == "boolean" then
            return '"b",' .. tostring(v)
        elseif tv == "table" then
            if paths[v] then
                return '"c",' .. path_src(paths[v])
            end
            if getmetatable(v) == dialogue_lib then
                -- An older copy of the dialogue library (the review mode swapped in a fresher
                -- one mid-campaign): it loads as whichever library the game has then.
                return '"c",{"dialogue"}'
            end
            return '"t",' .. id_of(v)
        end
        error("can't save a " .. tv .. " at " .. where)
    end

    id_of(campaign)
    local i = 1
    while i <= #order do
        local t = order[i]
        local mt = getmetatable(t)
        local fields = {}
        if mt then
            local name = class_name[mt]
            if not name then
                error("can't save a table with an unknown metatable (table " .. i .. ")")
            end
            fields[1] = "m=" .. str(name)
        end
        for _, k in ipairs(sorted_keys(t)) do
            if not (t == campaign and M.SKIP[k] and not (k == "prep" and keeps_board(campaign))) then
                local v = rawget(t, k)
                local where = "table " .. i .. "." .. tostring(k)
                table.insert(fields, value(k, where) .. "," .. value(v, where))
            end
        end
        -- Keys that aren't strings or numbers (none expected) would be dropped silently; refuse instead.
        for k in pairs(t) do
            local kt = type(k)
            if kt ~= "string" and kt ~= "number" then
                error("can't save a " .. kt .. " key in table " .. i)
            end
        end
        table.insert(out, "T[" .. i .. "]={" .. table.concat(fields, ",") .. "}")
        i = i + 1
    end
    local head = string.format("F=%d\nW=%d\nS=%s\nQ=%d\nN=%d\nP=%d\n", M.FORMAT, campaign.week or 0, num(campaign.seed or 0),
        campaign.slice_survey_done and 1 or 0, campaign.at_night and 1 or 0, (campaign.at_prep and not campaign.at_night) and 1 or 0)
    return head .. table.concat(out, "\n") .. "\n"
end

-- Run the save in an empty environment, a few hundred lines at a time (one huge chunk
-- could run into the compiler's limit on constants per function).
local CHUNK = 300

local function run(env, src)
    local fn, err
    if setfenv then
        fn, err = loadstring(src, "=save")
        if fn then
            setfenv(fn, env)
        end
    else
        fn, err = load(src, "=save", "t", env)
    end
    if not fn then
        return nil, err
    end
    return pcall(fn)
end

-- A line may only build a table: T[n]={...} with string literals (\ddd escapes only),
-- numbers, true/false, nested braces and "m=". Anything else (a call, a loop, a method on a
-- string) is refused before it runs.
local function safe_line(line)
    if not string.match(line, "^T%[%d+%]={.*}$") then
        return false
    end
    local rest = string.gsub(line, "\\%d%d%d", "_")
    if string.find(rest, "\\", 1, true) then
        return false
    end
    rest = string.gsub(rest, '"[^"]*"', "")
    rest = string.gsub(rest, "true", "")
    rest = string.gsub(rest, "false", "")
    rest = string.gsub(rest, "^T%[%d+%]=", "")
    rest = string.gsub(rest, "m=", "")
    return string.match(rest, "^[%d%.%-%+eE,{}/ ]*$") ~= nil and not string.find(rest, "..", 1, true)
end
M.safe_line = safe_line

local function compile(src)
    local env = { T = {} }
    local buf = {}
    for line in string.gmatch(src, "[^\r\n]+") do
        if string.sub(line, 1, 2) == "T[" then
            if not safe_line(line) then
                return nil, "broken save: a line that isn't plain data"
            end
            table.insert(buf, line)
            if #buf >= CHUNK then
                local ok, e = run(env, table.concat(buf, "\n"))
                if not ok then
                    return nil, e
                end
                buf = {}
            end
        end
    end
    if #buf > 0 then
        local ok, e = run(env, table.concat(buf, "\n"))
        if not ok then
            return nil, e
        end
    end
    return env
end

-- Just the header: { format, week, seed }, or nil if the text isn't a save.
function M.peek(src)
    if type(src) ~= "string" then
        return nil
    end
    local f = tonumber(string.match(src, "^F=(%d+)"))
    local w = tonumber(string.match(src, "\nW=(%d+)"))
    local s = tonumber(string.match(src, "\nS=([%d%.e%+%-]+)"))
    if not (f and w) then
        return nil
    end
    return { format = f, week = w, seed = s, survey_done = string.match(src, "\nQ=1") ~= nil,
             at_night = string.match(src, "\nN=1") ~= nil, at_prep = string.match(src, "\nP=1") ~= nil }
end

-- string -> campaign, or nil and why.
function M.load(src)
    local head = M.peek(src)
    if not head then
        return nil, "not a save"
    end
    if head.format ~= M.FORMAT then
        return nil, "saved by a different version"
    end
    local env, err = compile(src)
    if not env then
        return nil, err
    end
    local cls = classes()
    local raw = env.T
    if not raw[1] then
        return nil, "empty save"
    end
    local tables = {}
    for i in pairs(raw) do
        tables[i] = {}
    end
    local function resolve_path(p)
        local t = content
        for _, k in ipairs(p) do
            t = type(t) == "table" and t[k] or nil
        end
        if type(t) ~= "table" then
            error("it points at game data that isn't in this build", 0)
        end
        return t
    end
    local function decode(tag, v)
        if tag == "n" or tag == "s" or tag == "b" then
            return v
        elseif tag == "t" then
            return assert(tables[v], "broken save: missing table " .. tostring(v))
        elseif tag == "c" then
            return resolve_path(v)
        end
        error("broken save: unknown tag " .. tostring(tag), 0)
    end
    local ok, e = pcall(function()
        for i, r in pairs(raw) do
            local t = tables[i]
            for j = 1, #r, 4 do
                t[decode(r[j], r[j + 1])] = decode(r[j + 2], r[j + 3])
            end
            if r.m then
                setmetatable(t, assert(cls[r.m], "broken save: unknown class " .. tostring(r.m)))
            end
        end
    end)
    if not ok then
        return nil, e
    end
    local campaign = tables[1]
    if getmetatable(campaign) ~= cls.campaign then
        return nil, "broken save: no campaign in it"
    end
    if campaign.at_night and not campaign.prep then
        campaign.at_night = nil   -- a board that didn't make it into the save: back to prep
    end
    if campaign.at_prep and not campaign.prep then
        campaign.at_prep = nil
    end
    for _, card in ipairs(campaign.registered or {}) do
        content.register(card)
    end
    return campaign
end

return M
