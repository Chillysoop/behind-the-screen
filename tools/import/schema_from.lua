-- Write a first schema (game/data/adventure_schema.lua) from an adventure's data as it stands: each top-level
-- table's kind (a map of records, a list of records, or a value) and the fields its records use, with their types.
-- A starting point to review by hand, not the standard itself (docs/design/adventure-standard.md).
--     lua tools/import/schema_from.lua [adventure id] > game/data/adventure_schema.lua
package.path = "./?.lua;" .. package.path
local adventures = require "game.data.adventures"
local id = arg[1] or adventures.default
local MODULE = adventures.part(id, "module")

local KEYWORDS = {}
for w in string.gmatch("and break do else elseif end false for function goto if in local nil not or repeat return then true until while", "%a+") do
    KEYWORDS[w] = true
end
local function sorted(t)
    local out = {}
    for k in pairs(t) do table.insert(out, k) end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
end
local function is_list(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" then return false end
        n = n + 1
    end
    return n > 0
end
local function fields_of(records)
    local f = {}
    for _, r in pairs(records) do
        if type(r) == "table" then
            for k, v in pairs(r) do
                local key = type(k) == "number" and "[]" or k
                f[key] = f[key] or {}
                f[key][type(v)] = true
            end
        end
    end
    return f
end
local function types(set)
    local t = sorted(set)
    return #t == 1 and string.format("%q", t[1]) or ("{ " .. table.concat((function()
        local q = {} for _, x in ipairs(t) do table.insert(q, string.format("%q", x)) end return q end)(), ", ") .. " }")
end

print("-- The shape of an adventure's data (docs/design/adventure-standard.md; root-causes class 11): each top-level")
print("-- table, its kind, and the fields its records may have with their types. tools/tests/schema_check.lua fails any")
print("-- field not listed here. First written by tools/import/schema_from.lua from the museum (November 6); a new")
print("-- field is added here on purpose, with the standard. Data only.")
print("return {")
for _, k in ipairs(sorted(MODULE)) do
    local v = MODULE[k]
    if type(v) ~= "table" then
        print(string.format("    %s = { kind = \"value\", type = %q },", k, type(v)))
    else
        local recs = {}
        local all_tables = true
        for _, x in pairs(v) do
            if type(x) ~= "table" then all_tables = false end
        end
        local kind = is_list(v) and "list" or "map"
        if not all_tables then
            print(string.format("    %s = { kind = \"open\" },", k))
        else
            local f = fields_of(v)
            local parts = {}
            for _, fk in ipairs(sorted(f)) do
                local name = fk == "[]" and '["[]"]' or ((fk:match("^[%a_][%w_]*$") and not KEYWORDS[fk]) and fk or string.format("[%q]", fk))
                table.insert(parts, string.format("%s = %s", name, types(f[fk])))
            end
            print(string.format("    %s = { kind = %q, fields = { %s } },", k, kind, table.concat(parts, ", ")))
        end
    end
end
print("}")
