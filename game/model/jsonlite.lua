-- A small JSON reader and writer in plain Lua (5.1 / LuaJIT / 5.3), for the
-- dialogue data. The writer keeps keys in a fixed order so saved files diff
-- cleanly; decode returns plain tables (JSON null becomes nil).

local M = {}

-- Decoding ------------------------------------------------------------------------------

local escapes = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function utf8_char(code)
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
    end
    return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end

local function fail(s, i, what)
    local line = 1
    for _ in string.gmatch(string.sub(s, 1, i), "\n") do
        line = line + 1
    end
    error("JSON: " .. what .. " at line " .. line, 0)
end

local decode_value

local function skip(s, i)
    local _, e = string.find(s, "^[ \t\r\n]*", i)
    return e + 1
end

local function decode_string(s, i)
    -- s[i] is the opening quote
    local out = {}
    local j = i + 1
    while true do
        local c = string.sub(s, j, j)
        if c == "" then
            fail(s, j, "unterminated string")
        elseif c == '"' then
            return table.concat(out), j + 1
        elseif c == "\\" then
            local n = string.sub(s, j + 1, j + 1)
            if n == "u" then
                local hex = string.sub(s, j + 2, j + 5)
                local code = tonumber(hex, 16)
                if not code then
                    fail(s, j, "bad \\u escape")
                end
                table.insert(out, utf8_char(code))
                j = j + 6
            elseif escapes[n] then
                table.insert(out, escapes[n])
                j = j + 2
            else
                fail(s, j, "bad escape")
            end
        else
            local k = string.find(s, '["\\]', j)
            if not k then
                fail(s, j, "unterminated string")
            end
            table.insert(out, string.sub(s, j, k - 1))
            j = k
        end
    end
end

local function decode_array(s, i)
    local out = {}
    i = skip(s, i + 1)
    if string.sub(s, i, i) == "]" then
        return out, i + 1
    end
    while true do
        local v
        v, i = decode_value(s, i)
        table.insert(out, v)
        i = skip(s, i)
        local c = string.sub(s, i, i)
        if c == "]" then
            return out, i + 1
        elseif c ~= "," then
            fail(s, i, "expected , or ]")
        end
        i = skip(s, i + 1)
    end
end

local function decode_object(s, i)
    local out = {}
    i = skip(s, i + 1)
    if string.sub(s, i, i) == "}" then
        return out, i + 1
    end
    while true do
        if string.sub(s, i, i) ~= '"' then
            fail(s, i, "expected a key")
        end
        local k
        k, i = decode_string(s, i)
        i = skip(s, i)
        if string.sub(s, i, i) ~= ":" then
            fail(s, i, "expected :")
        end
        local v
        v, i = decode_value(s, skip(s, i + 1))
        out[k] = v
        i = skip(s, i)
        local c = string.sub(s, i, i)
        if c == "}" then
            return out, i + 1
        elseif c ~= "," then
            fail(s, i, "expected , or }")
        end
        i = skip(s, i + 1)
    end
end

decode_value = function(s, i)
    i = skip(s, i)
    local c = string.sub(s, i, i)
    if c == "{" then
        return decode_object(s, i)
    elseif c == "[" then
        return decode_array(s, i)
    elseif c == '"' then
        return decode_string(s, i)
    elseif string.sub(s, i, i + 3) == "true" then
        return true, i + 4
    elseif string.sub(s, i, i + 4) == "false" then
        return false, i + 5
    elseif string.sub(s, i, i + 3) == "null" then
        return nil, i + 4
    end
    local num = string.match(s, "^-?%d+%.?%d*[eE]?[-+]?%d*", i)
    if num and num ~= "" then
        return tonumber(num), i + #num
    end
    fail(s, i, "unexpected character '" .. c .. "'")
end

function M.decode(s)
    local v, i = decode_value(s, 1)
    i = skip(s, i)
    if i <= #s then
        fail(s, i, "trailing characters")
    end
    return v
end

-- Encoding ----------------------------------------------------------------------------------

local function encode_string(v)
    local s = string.gsub(v, '[%c"\\]', function(c)
        if c == '"' then
            return '\\"'
        elseif c == "\\" then
            return "\\\\"
        elseif c == "\n" then
            return "\\n"
        elseif c == "\t" then
            return "\\t"
        end
        return string.format("\\u%04x", string.byte(c))
    end)
    return '"' .. s .. '"'
end

local function is_array(t)
    if next(t) == nil then
        return true
    end
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" then
            return false
        end
        n = n + 1
    end
    return n == #t
end

-- order: optional list of keys written first, in that order; the rest follow sorted.
local function encode(v, order)
    local t = type(v)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then
            return "null"
        end
        if v == math.floor(v) then
            return string.format("%d", v)
        end
        return string.format("%.4g", v)
    elseif t == "string" then
        return encode_string(v)
    elseif t == "table" then
        if is_array(v) then
            local parts = {}
            for i = 1, #v do
                parts[i] = encode(v[i], order)
            end
            return "[" .. table.concat(parts, ", ") .. "]"
        end
        local keys, seen = {}, {}
        for _, k in ipairs(order or {}) do
            if v[k] ~= nil then
                table.insert(keys, k)
                seen[k] = true
            end
        end
        local rest = {}
        for k in pairs(v) do
            if not seen[k] then
                table.insert(rest, tostring(k))
            end
        end
        table.sort(rest)
        for _, k in ipairs(rest) do
            table.insert(keys, k)
        end
        local parts = {}
        for _, k in ipairs(keys) do
            table.insert(parts, encode_string(k) .. ": " .. encode(v[k], order))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return "null"
end

M.encode = encode

return M
