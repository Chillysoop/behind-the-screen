-- The rule fence at runtime (docs/design/rule-sets.md: "It's critical that systems never leak into another system"):
-- every line a playthrough says to the table, checked for words another rule set owns. A Death in Space night that
-- says "Armor Class", or a 5e night that says "void point", is a leak, wherever in the shared game it came from. Words
-- both sets use are the set's `shares` and pass. Reads the logs `lua tools/sim/museum.lua <seed> <style> log` writes.
--     lua tools/tests/set_words_check.lua <set id> <log file>...

package.path = "./?.lua;" .. package.path
local ruleset = require "game.model.ruleset"

local id = arg[1]
local set = ruleset.SETS[id]
if not set or not arg[2] then
    print("usage: lua tools/tests/set_words_check.lua <set id> <log file>...")
    os.exit(2)
end

-- Every other set's own words; a phrase this set shares is taken out of the line before they're looked for.
local banned = {}
for other_id, other in pairs(ruleset.SETS) do
    if other_id ~= id then
        for _, w in ipairs(other.owns or {}) do
            table.insert(banned, { pat = w, from = other_id })
        end
    end
end
local function strip_shares(line)
    for _, s in ipairs(set.shares or {}) do
        line = string.gsub(line, s, "")
    end
    return line
end

local fails, lines = 0, 0
for i = 2, #arg do
    local f = io.open(arg[i], "r")
    if not f then
        print("  FAIL can't read " .. arg[i])
        fails = fails + 1
    else
        for line in f:lines() do
            -- (What the table hears: "  [who] text" lines. The sim's own debug lines, "(big roll) ... vs DC", aren't said.)
            local said = string.match(line, "^  %[[^%]]+%] (.*)$")
            if said then
                lines = lines + 1
                local text = strip_shares(said)
                for _, b in ipairs(banned) do
                    if string.find(text, b.pat) then
                        fails = fails + 1
                        if fails <= 20 then
                            print("  FAIL " .. arg[i] .. ": a " .. b.from .. " word (" .. b.pat .. "): " .. said)
                        end
                        break
                    end
                end
            end
        end
        f:close()
    end
end
print(fails == 0 and ("set words (" .. id .. "): all clear, " .. lines .. " lines") or ("set words (" .. id .. "): " .. fails .. " leaks"))
os.exit(fails == 0 and 0 or 1)
