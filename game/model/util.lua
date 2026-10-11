-- Small helpers shared by the game model. Pure Lua (LuaJIT and 5.3), no engine calls.

local M = {}

function M.clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

function M.round(x)
    return math.floor(x + 0.5)
end

-- Integer text that looks the same in LuaJIT and Lua 5.3.
function M.int(x)
    return string.format("%d", math.floor(x + 0.5))
end

function M.signed(x)
    local r = math.floor(x + 0.5)
    if r > 0 then
        return "+" .. string.format("%d", r)
    end
    return string.format("%d", r)
end

function M.copy(t)
    local o = {}
    for k, v in pairs(t) do
        o[k] = v
    end
    return o
end

function M.contains(list, value)
    if not list then
        return false
    end
    for _, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

-- Fill {key} placeholders. Unknown keys are left as they are. {one|many} picks by
-- vars.plural (the slice rework, A3: "Rook's bandits are", "Gus is"): the first word for one,
-- the second for a group.
function M.fill(template, vars)
    template = string.gsub(template, "{([%w' ]*)|([%w' ]*)}", function(one, many)
        return (vars and vars.plural) and many or one
    end)
    local out = string.gsub(template, "{([%w_]+)}", function(k)
        local v = vars[k]
        if v == nil then
            return "{" .. k .. "}"
        end
        return tostring(v)
    end)
    return out
end

-- "The old bridge" -> "the old bridge" (for the middle of a sentence), but leave names
-- like "Ilsa's ring" or "Gus, the innkeeper" alone.
function M.lower_first(text)
    for _, w in ipairs({ "A ", "An ", "The ", "Fresh ", "Market " }) do
        if string.sub(text, 1, #w) == w then
            return string.lower(string.sub(text, 1, 1)) .. string.sub(text, 2)
        end
    end
    return text
end

function M.capitalize(s)
    return (string.gsub(s, "^%l", string.upper))
end

-- Every sentence starts with a capital, whatever got substituted in (A3: "the biggest drunk
-- hesitates" at the start of a line). A trailing "..." doesn't end a sentence.
function M.sentence_case(s)
    s = string.gsub(s, "^(['\"]?)(%l)", function(q, c) return q .. string.upper(c) end)
    s = string.gsub(s, "([^%.][%.!?] ['\"]?)(%l)", function(pre, c) return pre .. string.upper(c) end)
    s = string.gsub(s, "([%.!?]['\"] )(%l)", function(pre, c) return pre .. string.upper(c) end)
    return s
end

-- Join names: "A", "A and B", "A, B and C".
function M.join_names(names)
    local n = #names
    if n == 0 then
        return ""
    elseif n == 1 then
        return names[1]
    end
    return table.concat(names, ", ", 1, n - 1) .. " and " .. names[n]
end

return M
