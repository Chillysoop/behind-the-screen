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

-- Where value is in list (nil if it isn't).
function M.index_of(list, value)
    for i, v in ipairs(list or {}) do
        if v == value then
            return i
        end
    end
    return nil
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

-- A hero's own pronouns (D6: Thessaly she, Brannoc he, Pip she, Oswin he; the new characters
-- theirs), by the hero's name: game/data/players.lua and the pregens in game/data/death.lua. The
-- friends at the table have theirs (Mara she, Dev he, Jess she, Sam he: game/data/thoughts.lua), and so
-- do the adventure's people, by the name on their card (a cast card's `pronoun`: Flitwidget he, Telpur
-- he, the Lecturer he, Euryale she) and the companions (MODULE.companions' `pronoun`: Exhibit B he).
M.PRONOUNS = {
    she = { they = "she", them = "her", their = "her", theirs = "hers", themselves = "herself", ["they're"] = "she's",
            ["they've"] = "she's", ["they'll"] = "she'll", ["they'd"] = "she'd" },
    he = { they = "he", them = "him", their = "his", theirs = "his", themselves = "himself", ["they're"] = "he's",
           ["they've"] = "he's", ["they'll"] = "he'll", ["they'd"] = "he'd" },
    they = { they = "they", them = "them", their = "their", theirs = "theirs", themselves = "themselves", ["they're"] = "they're",
             ["they've"] = "they've", ["they'll"] = "they'll", ["they'd"] = "they'd" },
    -- (A construct, a swarm, a beast: the Sentinel, the Knight of Shades, a huntling. Round three's merge:
    -- "Who does they go for?" for the biggest huntling.)
    it = { they = "it", them = "it", their = "its", theirs = "its", themselves = "itself", ["they're"] = "it's",
           ["they've"] = "it's", ["they'll"] = "it'll", ["they'd"] = "it'd" },
}
local pronoun_names
-- (Built once from the adventure's cards and people; adventure.use starts it again for the next adventure.)
function M.reset_pronouns()
    pronoun_names = nil
end
-- (Who's who changes when an adventure brings its own heroes: adventure.enter forgets the names it knew.)
function M.forget_pronouns()
    pronoun_names = nil
end

function M.pronoun_of(name)
    if not pronoun_names then
        pronoun_names = {}
        local ok, players = pcall(M.lazy, "game.data.players")
        for _, key in ipairs(ok and players.order or {}) do
            local d = players[key]
            if d and d.char then
                pronoun_names[d.char] = d.pronouns
            end
        end
        -- (The players themselves, for a line that names the friend: game/data/thoughts.lua's pronouns.)
        local okt, th = pcall(M.lazy, "game.data.thoughts")
        for key, pr in pairs(okt and th.pronouns or {}) do
            local d = ok and players[key]
            if d and d.name then
                pronoun_names[d.name] = (pr.them == "her" and "she") or (pr.them == "him" and "he") or "they"
            end
        end
        local okd, death = pcall(M.lazy, "game.data.death")
        for _, list in pairs(okd and death.PREGENS or {}) do
            for _, g in ipairs(list) do
                pronoun_names[g.name] = g.pronouns
            end
        end
        -- (The adventure's people, by their short name, and "The Lecturer" as well as "the Lecturer".)
        local okc, content = pcall(M.lazy, "game.model.content")
        for _, card in M.sorted_pairs(okc and content.components or {}) do
            if card.kind == "cast" and card.short and M.PRONOUNS[card.pronoun or ""] then
                pronoun_names[card.short] = pronoun_names[card.short] or card.pronoun
                pronoun_names[M.capitalize(card.short)] = pronoun_names[M.capitalize(card.short)] or card.pronoun
            end
        end
        local oka, adv = pcall(M.lazy, "game.model.adventure")
        -- (Everyone the adventure names with a pronoun, by name and short name, not just a scene's cast: "Teddy narrows
        -- their eyes", the playtest, November 6.)
        for _, pp in ipairs(oka and adv.data and adv.data.people or {}) do
            if M.PRONOUNS[pp.pronoun or ""] then
                for _, n in ipairs({ pp.name, pp.short }) do
                    if n then
                        pronoun_names[n] = pronoun_names[n] or pp.pronoun
                    end
                end
            end
        end
        local comps = oka and adv.data and adv.data.companions or {}
        for _, id in ipairs(comps.order or {}) do
            local d = comps[id]
            if d and d.name and M.PRONOUNS[d.pronoun or ""] then
                pronoun_names[d.name] = pronoun_names[d.name] or d.pronoun
            end
        end
        -- (The adventure's monsters, one at a time, by every name the table calls them: the stat block's
        -- ("Knight of Shades", "Kruthik Huntling"), with "the", the room's boss_name ("the biggest
        -- huntling") and MODULE.foe_names. Each by its cast card's pronoun, through MODULE.npc_sheet's
        -- monster, else MODULE.foe_pronouns. Round three's merge: "The Knight of Shades came at them,
        -- and they brought them down"; "Who does they go for?" for the biggest huntling.)
        local data = oka and adv.data or {}
        local okm, mons = pcall(function() return M.lazy("game.model.ruleset").engine("data.monsters") end)
        local by_id = {}
        for id, pr in M.sorted_pairs(data.foe_pronouns or {}) do
            by_id[id] = pr
        end
        for _, cid in ipairs((data.npc_sheet or {}).order or {}) do
            local e = data.npc_sheet[cid]
            local card = okc and content.components and content.components[cid]
            if e and e.monster and card and M.PRONOUNS[card.pronoun or ""] then
                by_id[e.monster] = card.pronoun
            end
        end
        local function put(n, pr)
            if type(n) == "string" and n ~= "" then
                pronoun_names[n] = pronoun_names[n] or pr
                pronoun_names[M.capitalize(n)] = pronoun_names[M.capitalize(n)] or pr
            end
        end
        for id, pr in M.sorted_pairs(by_id) do
            local m = okm and type(mons) == "table" and mons[id]
            if m and m.name then
                put(m.name, pr)
                if string.sub(m.name, 1, 4) ~= "The " then
                    put("the " .. m.name, pr)
                    put("the " .. string.lower(m.name), pr)
                else
                    put("the " .. string.sub(m.name, 5), pr)
                end
            end
            put((data.foe_names or {})[id], pr)
        end
        for _, r in M.sorted_pairs(data.rooms or {}) do
            local first = r.encounter and r.encounter[1]
            if r.boss_name and first and by_id[first] then
                put(r.boss_name, by_id[first])
            end
        end
        -- (And as the table calls them before it's told who they are: "the armoured hunter", "the hooded
        -- woman", "the Gorgon". game/model/told.lua.)
        local okt, told = pcall(M.lazy, "game.model.told")
        if okt and told and told.mask then
            local names = {}
            for n, pr in M.sorted_pairs(pronoun_names) do
                names[#names + 1] = { n, pr }
            end
            for _, knows in ipairs({ {}, { gorgon = 0 } }) do
                local blank = { adv = { told = knows } }
                for _, np in ipairs(names) do
                    local ok, said = pcall(told.mask, blank, np[1])
                    if ok and said ~= np[1] then
                        put(said, np[2])
                    end
                end
            end
        end
    end
    local key = name or ""
    if not pronoun_names[key] then
        -- (The mat's numbered label, "Kruthik Huntling 2": the same one.)
        key = string.gsub(key, "%s+%d+$", "")
    end
    return M.PRONOUNS[pronoun_names[key] or "they"] or M.PRONOUNS.they
end

-- Fill {key} placeholders. Unknown keys are left as they are. {one|many} picks by
-- vars.plural (the slice rework, A3: "Rook's bandits are", "Gus is"): the first word for one,
-- the second for a group. A hero's pronouns: {actor_their}, {target_them}, {char_they} and so on
-- (actor, target, other, doer, lowest: the hero named by {actor_char} etc.; char, new, old: the
-- hero named by {char}...), capitalised as {Actor_they}. {friend_their} and the like are the friend's
-- at the table that {actor} names (Mara, not Thessaly: a new character can be someone else); any other
-- name in vars works the same ({Name_they} for {name}: "Mara goes quiet. She asked you..."). D6.
local PRON_WORD = { they = true, them = true, their = true, theirs = true, themselves = true, ["they're"] = true,
                    ["they've"] = true, ["they'll"] = true, ["they'd"] = true }
function M.fill(template, vars)
    template = string.gsub(template, "{([%w' ]*)|([%w' ]*)}", function(one, many)
        return (vars and vars.plural) and many or one
    end)
    local out = string.gsub(template, "{([%w_']+)}", function(k)
        local v = vars[k]
        if v == nil then
            local who, word = string.match(k, "^(%a+)_([%a']+)$")
            if who and PRON_WORD[word] then
                local low = string.lower(string.sub(who, 1, 1)) .. string.sub(who, 2)
                local name = vars[low .. "_char"] or vars[low]
                if low == "friend" then
                    name = vars.friend or vars.actor        -- (the friend {actor} names, not their hero)
                end
                if type(name) == "string" then
                    local w = M.pronoun_of(name)[word]
                    return (low ~= who) and (string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2)) or w
                end
            end
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

-- A sentence used in the middle of another ("The bit where {moment}"): its first letter goes
-- lower case unless it starts with a name (names: a set of words that stay capitalised).
function M.mid_sentence(text, names)
    if type(text) ~= "string" then
        return text
    end
    local first = string.match(text, "^([%a']+)")
    if not first or (names and names[first]) or string.match(first, "^%u%u") or first == "I" then
        return text
    end
    return string.lower(string.sub(text, 1, 1)) .. string.sub(text, 2)
end

-- Title Case for a session title: every word capitalised but the small ones (unless first).
local SMALL = { a = true, an = true, the = true, of = true, ["in"] = true, on = true, at = true, to = true, ["and"] = true,
                ["or"] = true, by = true, with = true }
function M.title_case(s)
    local i = 0
    return (string.gsub(s or "", "(%S+)", function(w)
        i = i + 1
        local low = string.lower(w)
        if i > 1 and SMALL[low] then
            return low
        end
        return (string.gsub(w, "^%l", string.upper))
    end))
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
function M.join_names(names, word)
    local n = #names
    if n == 0 then
        return ""
    elseif n == 1 then
        return names[1]
    end
    return table.concat(names, ", ", 1, n - 1) .. " " .. (word or "and") .. " " .. names[n]
end

-- A require done when it's needed, for a module that requires this one back. Written so the
-- Defold builder's scan doesn't see it (it refuses a build with a require cycle in it); the
-- module is still in the build, since something else requires it outright.
function M.lazy(name)
    return require(name)
end

-- Iterate a table in sorted key order: for code whose result depends on the order (a first
-- match, a running float sum). Plain pairs() order differs between a campaign played and the
-- same campaign loaded from a save, so the two could drift apart.
function M.sorted_pairs(t)
    local keys = {}
    for k in pairs(t or {}) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    local i = 0
    return function()
        i = i + 1
        local k = keys[i]
        if k ~= nil then
            return k, t[k]
        end
    end
end

return M
