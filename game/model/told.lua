-- What the table has been told (docs/design/2026-11-05-knowledge-playtest.md; the root-cause doc's class 5).
--
-- The friends know only what their heroes have seen, heard or been told at the table this campaign. This is
-- the one record of it: `campaign.adv.told[key]`, for the adventure's names and secrets (`MODULE.told`).
--   tell(campaign, keys)   the table's been told (a moment's option or roll branch with `tells`, an event's
--                          `tells`, a line with one of a key's `intro` phrases)
--   knows(campaign, key)   has it?
--   hear(campaign, text)   a line said to the table: what it tells (a key's `intro` phrases, and for a key
--                          with no mask, any of its `words`)
--   mask(campaign, text)   a line about to be said to the table, with each name it hasn't been told yet put
--                          as the table knows it (`mask`: "Euryale" is "the hooded woman" until someone says
--                          her name). A DM's label the table never hears (the Knight of Shades) is `always`.
--   untold(campaign, text) the keys a line names that the table hasn't been told (not counting the DM's
--                          labels, which mask renames): a stock line with one waits (night:fresh); a line
--                          written for it says so with adventure.test's `told` / `not_told`.
-- Pure Lua. Lines the DM alone sees (cards, the screen, the report) keep the DM's names.
--
-- What's known lives in game/model/secrets.lua now (one record per secret, the table's knowledge and each
-- hero's): a key here is a secret there. `hero` (what that hero knows in character) and `player` (what that
-- friend knows: everything said out loud, and their hero's) narrow knows/mask/untold to one of them.

local util = require "game.model.util"

local M = {}

local secrets = require "game.model.secrets"

local function data()
    return secrets.defs()
end

local function esc(s)
    return (string.gsub(s, "([%-%.%+%[%]%(%)%$%^%%%?%*])", "%%%1"))
end
-- (A phrase, whole words, any case: "Gorgon" in "the Gorgon's", not in "gorgonzola".)
-- (A phrase that starts or ends on punctuation, "A Gorgon.", has no word edge there to find.)
local function find_ci(text, phrase, from)
    local pat = string.lower(esc(phrase))
    if string.find(phrase, "^%w") then
        pat = "%f[%w]" .. pat
    end
    if string.find(phrase, "%w$") then
        pat = pat .. "%f[%W]"
    end
    return string.find(string.lower(text), pat, from)
end
M.find = find_ci

-- The campaign being played (a night sets it as it starts), for what the table calls things where a line
-- is made without one in hand: a foe's name in a fight bark (barks.foe_label).
M.current = nil
function M.use(campaign)
    M.current = campaign
end
function M.name(text)
    return M.current and M.mask(M.current, text) or text
end

-- opts (secrets.learn's): heroes, private, how, by.
function M.tell(campaign, keys, opts)
    if not (campaign and campaign.adv) or not keys then
        return
    end
    if type(keys) == "string" then
        keys = { keys }
    end
    for _, k in ipairs(keys) do
        secrets.learn(campaign, k, "known", opts or { how = "said" })
    end
end

function M.knows(campaign, key, hero, player)
    return secrets.knows(campaign, key, hero, player)
end

-- Does a line name this key? (Any of its words.)
local function names(text, d)
    for _, w in ipairs(d.words or {}) do
        if find_ci(text, w) then
            return true
        end
    end
    return false
end

function M.hear(campaign, text, opts)
    if not text or text == "" then
        return
    end
    for key, d in util.sorted_pairs(data()) do
        -- (A hint said out loud: one of the secret's `hint_words`.)
        if not secrets.hinted(campaign, key) then
            for _, p in ipairs(d.hint_words or {}) do
                if find_ci(text, p) then
                    secrets.learn(campaign, key, "hint", opts or { how = "said" })
                end
            end
        end
        if not M.knows(campaign, key) then
            local told = false
            for _, p in ipairs(d.intro or {}) do
                if find_ci(text, p) then
                    told = true
                end
            end
            -- (A secret with no mask is told by any line that names it to the table, unless naming it isn't
            -- knowing it: the ritual is learned a line of the tablet at a time.)
            if not told and not d.mask and not d.always and not d.parts and d.hear ~= false and names(text, d) then
                told = true
            end
            if told then
                M.tell(campaign, key, opts)
            end
        end
    end
end

-- Replace each phrase, keeping a capital where the line had one.
local function swap(text, from, to)
    local out, pos = {}, 1
    local low = string.lower(text)
    local pat = "%f[%w]" .. string.lower(esc(from)) .. "%f[%W]"
    while true do
        local a, b = string.find(low, pat, pos)
        if not a then
            break
        end
        local head = string.sub(text, pos, a - 1)
        local rep = to
        -- ("a armoured hunter": the article goes with what's said now.)
        if string.find(rep, "^[AaEeIiOoUu]") then
            head = string.gsub(head, "(%f[%a][Aa]) $", "%1n ")
        elseif string.find(head, "%f[%a][Aa]n $") then
            head = string.gsub(head, "(%f[%a][Aa])n $", "%1 ")
        end
        table.insert(out, head)
        -- (At the start of the line or of a sentence, or where the name stood capitalised after "The":
        -- "The Knight of Shades drops" keeps its "The"; "Euryale waits" becomes "The hooded woman waits".)
        local before = table.concat(out)
        if before == "" or string.find(before, "[%.!%?\"]%s*$") then
            rep = util.capitalize(rep)
        end
        table.insert(out, rep)
        pos = b + 1
    end
    table.insert(out, string.sub(text, pos))
    return table.concat(out)
end

function M.mask(campaign, text, hero, player)
    if not text or text == "" then
        return text
    end
    for key, d in util.sorted_pairs(data()) do
        -- (A DM's label, `always`, is renamed until the table learns the real name: kruthik, once someone reads
        -- the guide.)
        if d.mask and not M.knows(campaign, key, hero, player) then
            for _, m in ipairs(d.mask) do
                local to = m[2]
                -- (What it's called instead can wait on another secret: the hooded woman is the Gorgon once
                -- the table knows there's a Gorgon.)
                if m.told and M.knows(campaign, m.told, hero, player) then
                    to = m.then_to or to
                end
                if find_ci(text, m[1]) then
                    text = swap(text, m[1], to)
                end
            end
        end
    end
    return text
end

function M.untold(campaign, text, hero, player)
    local out = {}
    if not text or text == "" then
        return out
    end
    for key, d in util.sorted_pairs(data()) do
        -- (A DM's label the table never hears is renamed as it's said, not held back: mask.)
        -- (Some can be named once there's a hint: the ritual, after one line of the tablet. `say_at`.)
        local ok = M.knows(campaign, key, hero, player)
        if not ok and d.say_at == "hint" then
            ok = secrets.hinted(campaign, key, hero, player)
        end
        if not d.always and not ok and names(text, d) then
            table.insert(out, key)
        end
    end
    return out
end

-- Is a line fine to say now? (Nothing in it the table hasn't been told.)
function M.ok(campaign, text, hero, player)
    return #M.untold(campaign, text, hero, player) == 0
end

return M
