-- The knowledge check (docs/design/2026-11-05-root-causes.md, class 5: knowledge, including from earlier runs).
-- The friends are always playing it for the first time: they know only what this campaign has told them. Run
-- from the project root:
--     lua tools/tests/knowledge_check.lua [seeds]
--   KNOWN  every friend line (at the table, in character, in the group chat, a thought) that names something in
--          the adventure (a person, a creature, a room, an item, a secret: the module's names and the fidelity
--          sheet's) comes after the table heard it said: the pitch and their own reasons for coming at Session
--          Zero, the DM's words, the people's, the story told, the DM's answers in the chat. A name a friend
--          makes up themselves (Exhibit B) is theirs from the start.
--   FACTS  every friend line with one of the book's facts the friends can't know until they're told (the
--          ritual, her sisters, her drink, the bird's name...: game/data/museum/fidelity.lua's `facts`) comes
--          after a line said to the table that told it
--   MASKED no friend line named something the table hadn't been told, so that game night had to say it as
--          they'd know it (game/model/told.lua; the sim prints each one)
--   TWICE  a campaign played in the same process straight after another plays exactly as it does on its own:
--          nothing from the first (a cache, a memory, a "last time") reaches a line of the second.
-- Each fails on 1ea3901 (KNOWN: Mara asks about Flitwidget by name in the chat before anyone's said it).

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local SEEDS = tonumber(arg[1]) or 2
local ITEMS = { "KNOWN", "FACTS", "MASKED", "TWICE" }
local fails, E = {}, {}
local function fail(item, msg)
    fails[item] = fails[item] or { n = 0 }
    if #fails[item] < 12 or os.getenv("ALL") then
        table.insert(fails[item], msg)
    end
    fails[item].n = fails[item].n + 1
end
local function add(item, key, n)
    E[item] = E[item] or {}
    E[item][key] = (E[item][key] or 0) + (n or 1)
end

local adventure = require "game.model.adventure"
adventure.enter()
-- (Any registered adventure: ADVENTURE=<id>, else the default. game/data/adventures.lua.)
local ADV = require "game.data.adventures"
local ADV_ID = ADV.from_env()
local MODULE = ADV.part(ADV_ID, "module")
local CARDS = ADV.part(ADV_ID, "cards")
local F = ADV.part(ADV_ID, "fidelity")
local voice = require "game.model.voice"
local util = require "game.model.util"

-- The adventure's nouns: who's in it, its rooms, its things, its secrets. (Each a plain phrase, matched
-- whole-word and ignoring case.)
local NOUNS, seen_noun = {}, {}
local function noun(w)
    w = string.gsub(w or "", "^[Tt]he ", "")
    if #w >= 4 and not seen_noun[string.lower(w)] then
        seen_noun[string.lower(w)] = true
        table.insert(NOUNS, w)
    end
end
for _, c in ipairs(CARDS.cards or {}) do
    if c.kind == "cast" then
        noun(string.match(c.name or "", "^([^,]+)"))
    end
end
for _, p in ipairs(MODULE.people or {}) do
    noun(p.name)
end
for _, rid in ipairs({ "chamber", "paintings", "tomorrow", "hunting" }) do
    noun(MODULE.rooms[rid].name)
end
-- (Of the magic items, only a name that isn't just what they look like: "the twin daggers" is what anyone
-- would call two daggers locked together.)
noun("Vorpal sword")
for _, r in util.sorted_pairs(F.rooms) do
    for _, s in ipairs(r.secrets or {}) do
        for _, w in ipairs(s.words or {}) do
            if string.match(w, "^%u%l") and not string.find(w, "%.") then
                noun(w)
            end
        end
    end
end
-- (And what the table must be told before it's said: MODULE.told, the registry's own names.)
for _, d in util.sorted_pairs(MODULE.told or {}) do
    for _, w in ipairs(d.words or {}) do
        -- (A plural is its singular: "gorgons" is matched by "Gorgon".)
        if string.match(w, "^%u") and not string.match(w, "s$") then
            noun(w)
        end
    end
end
for _, w in ipairs({ "Gorgon", "Flitwidget", "Formicarius", "Huntling", "Kruthik", "Briar", "Mech", "Witness", "Stheno", "Medusa",
                     "Nephthys", "Vorpal", "Francs", "archivist", "Exhibit B", "Flappy Six" }) do
    noun(w)
end
-- Names the friends make up themselves.
local THEIRS = { ["exhibit b"] = true, ["flappy six"] = true }

local function low(s)
    return string.lower(s or "")
end
local function names_in(text)
    local t, out = " " .. low(text) .. " ", {}
    for _, n in ipairs(NOUNS) do
        local pat = "%f[%w]" .. string.gsub(low(n), "([%-%.%+%[%]%(%)%$%^%%%?%*])", "%%%1") .. "s?%f[%W]"
        if string.find(t, pat) then
            out[low(n)] = n
        end
    end
    return out
end

-- What the table knows before the first night: the premise you've told them (Session Zero's `told`, on its
-- screen), the tones you pitch, each hero's reason for coming as Session Zero gives it (its name, your words
-- and the friend's; not its payoff, said when it pays off), and the names they make up themselves.
local S0 = MODULE.session_zero or {}
local function learner(k)
    return function(s)
        for key in pairs(names_in(s)) do
            k[key] = true
        end
    end
end
local function known_at_start(tone)
    local k = {}
    local learn = learner(k)
    learn(S0.told)
    for key, t in util.sorted_pairs(S0.tones or {}) do
        if type(t) == "table" and (tone == nil or tone == key) then
            learn(t.name)
            learn(t.blurb)
        end
    end
    for _, list in util.sorted_pairs(MODULE.hooks or {}) do
        for _, h in ipairs(list) do
            learn(h.name)
            learn(h.text)
            learn(h.intro)
            learn(h.says)
        end
    end
    for key in pairs(THEIRS) do
        k[key] = true
    end
    return k
end

-- Session Zero's own friend lines: what they say to a tone knows that tone's pitch; an ask, only the premise.
do
    local function check(where, text, known)
        add("KNOWN", "session_zero_lines")
        for key, n in util.sorted_pairs(names_in(text)) do
            if not known[key] then
                fail("KNOWN", string.format("Session Zero: %s names %s, and all they've been told is the premise: '%s'", where, n,
                    string.sub(text, 1, 120)))
            end
        end
    end
    for key, t in util.sorted_pairs(S0.tones or {}) do
        if type(t) == "table" then
            for who, say in util.sorted_pairs(t.says or {}) do
                check(who .. " on " .. tostring(t.name), say, known_at_start(key))
            end
        end
    end
    local bare = known_at_start("(none)")
    for who, a in util.sorted_pairs(S0.asks or {}) do
        if type(a) == "table" then
            check(who .. "'s ask", a.text, bare)
            check(who .. "'s answer", a.agree and a.agree.reply, bare)
            check(who .. "'s answer", a.push and a.push.reply, bare)
        end
    end
end

local FRIEND = { dev = true, mara = true, jess = true, sam = true }
local CHAT_FRIEND = { Dev = true, Mara = true, Jess = true, Sam = true }
local ask_by = {}
for _, a in ipairs(MODULE.chat_ask or {}) do
    ask_by[a.id] = a
end

local FACTS = F.facts or {}
local function has_ci(text, w)
    return string.find(string.lower(text or ""), string.lower(w), 1, true) ~= nil
end
local function scan(R)
    local known = known_at_start()
    local fact_told = {}
    for _, l in ipairs(R.L) do
        local masked = string.match(l, "^  %-%- masked friend line: (.*)$")
        if masked then
            add("MASKED", "masked")
            fail("MASKED", R.tag .. ": " .. string.sub(masked, 1, 160))
        end
        local tag, text = string.match(l, "^  %[([^%]]+)%] (.*)$")
        local thinker, thought = string.match(l, "^  %((%a+) thinks%) (.-)%s%s%[")
        local friend_text
        if tag == "chat" then
            local who, post = string.match(text, "^(%a+): (.*)$")
            if who and CHAT_FRIEND[who] then
                friend_text = post
            else
                text = post or text
            end
        elseif tag == "chat answer" then
            -- (The DM's answer in the chat: what was posted.)
            local id, n = string.match(text, "^(%S+) %-> option (%d+)")
            local a = ask_by[id or ""]
            local rep = a and a.replies and a.replies[tonumber(n)]
            text = rep and rep.say or ""
        elseif tag and FRIEND[tag] then
            friend_text = text
        end
        if thinker then
            friend_text = thought
        end
        if friend_text then
            for _, fct in ipairs(FACTS) do
                for _, w in ipairs(fct.words) do
                    if not fact_told[fct.id] and has_ci(friend_text, w) then
                        add("FACTS", "facts_said")
                        fail("FACTS", string.format("%s: %s knows %s (p%d) before anyone's told them: '%s'", R.tag,
                            thinker or (tag == "chat" and "a friend in the chat" or tag), fct.id, fct.page, string.sub(friend_text, 1, 120)))
                        fact_told[fct.id] = true
                        break
                    end
                end
            end
            add("KNOWN", "friend_lines")
            for key, n in util.sorted_pairs(names_in(friend_text)) do
                add("KNOWN", "names_said")
                if not known[key] then
                    fail("KNOWN", string.format("%s: %s names %s before anyone's said it: '%s'", R.tag,
                        thinker or (tag == "chat" and "a friend in the chat" or tag), n, string.sub(friend_text, 1, 120)))
                    known[key] = true
                end
            end
        elseif tag and tag ~= "aside" and tag ~= "between sessions" and voice.heard(tag)
            and not (tag == "dm" and voice.of(text) == "you") then
            -- (Not the DM's own unspoken doing: "You let your eyes linger on the tablet.")
            for key in pairs(names_in(text)) do
                known[key] = true
            end
            for _, fct in ipairs(FACTS) do
                for _, w in ipairs(fct.told_by) do
                    if has_ci(text, w) then
                        fact_told[fct.id] = true
                    end
                end
            end
        end
    end
end

-- Whole prologues, in this one process, one after another.
local RUNS = {}
local real_exit, real_print = os.exit, print
local function sim(seed, style)
    arg = { [0] = "tools/sim/museum.lua", tostring(seed), style, "log" }
    local out = {}
    os.exit = function() error("__done__", 0) end
    print = function(...)
        local t = {}
        for i = 1, select("#", ...) do
            t[i] = tostring(select(i, ...))
        end
        for l in string.gmatch(table.concat(t, " ") .. "\n", "([^\n]*)\n") do
            table.insert(out, l)
        end
    end
    local ok, err = pcall(dofile, "tools/sim/museum.lua")
    print, os.exit = real_print, real_exit
    if not ok and err ~= "__done__" then
        fail("KNOWN", "seed " .. seed .. " " .. style .. ": " .. tostring(err))
        return
    end
    table.insert(RUNS, { tag = seed .. " " .. style, seed = seed, style = style, L = out })
end
for _, style in ipairs({ "careful", "random", "careless" }) do
    for seed = 81, 80 + SEEDS do
        sim(seed, style)
    end
end
for _, R in ipairs(RUNS) do
    scan(R)
end
E.KNOWN = E.KNOWN or {}
E.KNOWN.prologues = #RUNS
E.KNOWN.nouns = #NOUNS
if os.getenv("NOUNS") then
    print("nouns: " .. table.concat(NOUNS, ", "))
end

-- TWICE: the second and the last campaign played here, against each on its own.
local function fresh(seed, style)
    local p = io.popen("lua tools/sim/museum.lua " .. seed .. " " .. style .. " log 2>&1")
    local out = {}
    for l in p:lines() do
        table.insert(out, l)
    end
    p:close()
    return out
end
for _, i in ipairs({ 2, #RUNS }) do
    local R = RUNS[i]
    if R and i > 1 then
        add("TWICE", "campaigns")
        local alone = fresh(R.seed, R.style)
        local n = math.max(#alone, #R.L)
        for j = 1, n do
            if alone[j] ~= R.L[j] then
                fail("TWICE", string.format("%s, played after %s: line %d differs from playing it alone.\n         after: %s\n         alone: %s",
                    R.tag, RUNS[i - 1].tag, j, string.sub(tostring(R.L[j]), 1, 150), string.sub(tostring(alone[j]), 1, 150)))
                break
            end
        end
        add("TWICE", "lines", #R.L)
    end
end

-- Report -------------------------------------------------------------------------------------------------
local total = 0
for _, item in ipairs(ITEMS) do
    local f = fails[item]
    local bits = {}
    for k, v in util.sorted_pairs(E[item] or {}) do
        table.insert(bits, k .. " " .. tostring(v))
    end
    print(string.format("%-6s %s%s", item, table.concat(bits, ", "), f and ("  FAIL x" .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("       FAIL: " .. m)
    end
    total = total + (f and f.n or 0)
end
print(total == 0 and "knowledge check: all clear" or ("knowledge check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
