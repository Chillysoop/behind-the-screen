-- The shape of an adventure's data (root-causes class 11; docs/design/adventure-standard.md). Every top-level table
-- of the adventure is in game/data/adventure_schema.lua, of the kind it says (a map of records, a list of records, a
-- value), and every field of every record is one the schema lists, of a type it allows. An unknown field is a
-- failure, not ignored: the locked door's places, written in the middle of the look-around table (November 6), took
-- two rooms' look-arounds with them and nothing noticed. A self-test makes sure that case fails.
--     lua tools/tests/schema_check.lua            the default adventure (ADVENTURE=<id> for another)
package.path = "./?.lua;" .. package.path
local adventures = require "game.data.adventures"
local SCHEMA = require "game.data.adventure_schema"

local function check(MODULE, schema)
    local fails = {}
    local function fail(msg)
        table.insert(fails, msg)
    end
    local function list_like(t)
        for k in pairs(t) do
            if type(k) ~= "number" then return false end
        end
        return true
    end
    local function allowed(spec, v)
        if type(spec) == "string" then
            return spec == "any" or spec == type(v)
        end
        for _, t in ipairs(spec) do
            if t == "any" or t == type(v) then return true end
        end
        return false
    end
    local keys = {}
    for k in pairs(MODULE) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v, s = MODULE[k], schema[k]
        if not s then
            fail("M." .. k .. ": not in the schema (a new table goes in game/data/adventure_schema.lua with the standard)")
        elseif s.kind == "value" then
            if type(v) ~= s.type then fail("M." .. k .. ": a " .. type(v) .. ", the schema says " .. s.type) end
        elseif s.kind == "record" then
            -- (One record, not a table of them: the hand-off, the money, the levels.)
            if type(v) ~= "table" then
                fail("M." .. k .. ": not a table")
            else
                for fk, fv in pairs(v) do
                    local name = type(fk) == "number" and "[]" or fk
                    local spec = s.fields and s.fields[name]
                    if not spec then
                        fail("M." .. k .. "." .. tostring(fk) .. ": a field the schema doesn't have")
                    elseif not allowed(spec, fv) then
                        fail("M." .. k .. "." .. tostring(fk) .. ": a " .. type(fv) .. ", not what the schema allows")
                    end
                end
            end
        elseif s.kind ~= "open" then
            if type(v) ~= "table" then
                fail("M." .. k .. ": not a table")
            elseif s.kind == "list" and not list_like(v) then
                fail("M." .. k .. ": the schema says a list, and it has named fields")
            else
                for rk, r in pairs(v) do
                    if type(r) ~= "table" then
                        fail("M." .. k .. "[" .. tostring(rk) .. "]: not a record")
                    else
                        for fk, fv in pairs(r) do
                            local name = type(fk) == "number" and "[]" or fk
                            -- (values: a record keyed by the adventure's own ids, a place's or a room's, each a value
                            -- of that type: content tags by place.)
                            local spec = s.values or (s.fields and s.fields[name])
                            if not spec then
                                fail("M." .. k .. "[" .. tostring(rk) .. "]." .. tostring(fk) .. ": a field the schema doesn't have")
                            elseif not allowed(spec, fv) then
                                fail("M." .. k .. "[" .. tostring(rk) .. "]." .. tostring(fk) .. ": a " .. type(fv) .. ", not what the schema allows")
                            end
                        end
                    end
                end
            end
        end
    end
    return fails
end

local id = adventures.from_env()
local MODULE = adventures.part(id, "module")
local fails = check(MODULE, SCHEMA)

-- Self-test: the November 6 slip (look-around entries written inside the locked doors' table) has to fail.
local copy = {}
for k, v in pairs(MODULE) do copy[k] = v end
-- (Written for any adventure: a locked-doors entry holding a look-around's spots and finds.)
copy.behind_doors = { somewhere = { "cases", "console", finds = {} } }
local caught = #check(copy, SCHEMA) > 0
if not caught then
    table.insert(fails, "self-test: a look-around written inside the locked doors' table wasn't caught")
end

local n = 0
for k in pairs(MODULE) do n = n + 1 end
print(string.format("SHAPE  every table and field is in the schema   adventure %s, tables %d, self_test %s%s", id, n,
    caught and "caught" or "missed", #fails > 0 and ("  FAIL x" .. #fails) or ""))
for i, f in ipairs(fails) do
    if i <= 30 then print("       FAIL: " .. f) end
end
print(#fails == 0 and "schema check: all clear" or ("schema check: " .. #fails .. " failures"))
os.exit(#fails == 0 and 0 or 1)
