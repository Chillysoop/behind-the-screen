-- Players announce, the DM answers (Conner, November 6; root-causes class 2). Every line the DM says to the table
-- passes through here (night:emit), and two rules hold, for any adventure:
--
--   1. The DM never says what a hero or a friend feels, wants, thinks or decides ("Pip feels", "Jess wants": a
--      hard rule). Such a sentence is never said; the check (tools/tests/agency_check.lua) fails the line where
--      it's written, so it gets rewritten there.
--   2. What a hero does by choice is said by their player first, in character ("I'll go over the pond, carefully."),
--      and the DM's line is the answer: what happens. A sentence of the DM's that has a hero doing something
--      ("Thessaly goes over the pond carefully.") becomes their player's announcement, or, when the player has just
--      said it, is left out as an echo. What happens to a hero (takes damage, is flung, finds, sees, rolls) stays
--      the DM's to say.
--
-- Also: a friend's words written into the DM's line ('Mara: "..."', "'...,' Jess shrugs.") become that friend's
-- own line. Pure Lua; nothing here knows an adventure: heroes and friends come from the night's players.

local util = require "game.model.util"

local M = {}

local function esc(s)
    return (string.gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- The DM's styles the table hears (game/model/voice.lua's UNHEARD are behind the screen: the DM's own read).
M.SAID = { narration = true, dm = true, good = true, bad = true, table = true, twist = true, thread = true,
           record = true, reward = true, opening = true, recap = true }

-- What only a person can say of themselves: feelings, wants, thoughts, decisions.
M.MIND = { "feels?", "felt", "wants?", "wanted", "thinks?", "thought", "decides?", "decided", "would rather", "is sure",
           "is certain", "hopes?", "wonders?", "wish", "wishes", "likes", "loves", "hates", "fears", "is afraid",
           "is scared", "is keen", "is delighted", "is thrilled", "is happy", "is glad", "is sad", "is worried",
           "worries", "can't wait", "is dying to", "is itching", "longs", "means to", "intends", "is tempted",
           "fancies", "prefers", "remembers", "realises", "realizes", "knows", "believes", "suspects", "is pleased",
           "is relieved", "is nervous", "is excited", "changes? %a+ mind", "has a bad feeling", "goes quiet" }
-- How a hero looks or sounds: the player's to play, never the DM's to say.
M.SHOWS = { "grins", "smiles", "frowns", "scowls", "sighs", "shrugs", "laughs", "giggles", "mutters", "winces",
            "beams", "blushes", "gulps", "nods", "shakes %a+ head", "rolls %a+ eyes", "sniffs", "snorts", "groans" }
-- What a hero does by choice.
M.DOES = { "goes", "takes", "pockets", "reaches", "digs", "opens", "leans", "works", "scoops", "pulls", "picks",
           "unscrews", "bends", "copies", "fills", "gives", "draws", "sits", "tips", "looks", "stops", "kneels",
           "holds", "walks", "steps", "climbs", "searches", "reads", "grabs", "touches", "tries", "puts", "hands",
           "offers", "asks", "tells", "says", "calls", "waves", "pushes", "lifts", "sets", "keeps", "follows", "leads",
           "heads", "hides", "sneaks", "casts", "drinks", "eats", "throws", "ties", "straps", "pours", "runs",
           "examines", "studies", "checks", "taps", "knocks", "listens", "waits", "watches", "raises", "lowers",
           "wipes", "pats", "crouches", "peers", "pokes", "hums", "sings", "shouts", "whispers", "turns", "slips",
           "tucks", "stuffs", "lights", "rings", "tugs", "presses", "flips", "unlocks", "picks", "moves", "settles",
           "starts", "sets", "shoves", "knocks", "squeezes", "rubs", "strokes", "counts", "traces", "sketches",
           "writes", "scribbles", "jots", "stays", "backs", "edges", "creeps", "darts", "hurries", "wanders",
           "strolls", "marches", "plays", "goes back", "comes back" }
M.ADVERB = { just = true, ["then"] = true, quietly = true, carefully = true, slowly = true, gently = true, quickly = true }
M.VERB = {}
for _, list in ipairs({ M.DOES, M.SHOWS, { "listens", "folds", "has", "sits", "starts", "stares", "waits", "leaves", "comes",
                                           "makes", "gets", "lets", "puts", "kneels", "wipes", "sets", "tries", "finds",
                                           "closes", "shuts", "drops", "nudges", "lays", "slides", "brings", "carries",
                                           "breathes", "blows", "catches", "keeps", "takes", "starts", "scrambles", "hears", "creeps",
                                           "backs", "ducks", "jumps", "leaps", "climbs" } }) do
    for _, v in ipairs(list) do
        if not string.find(v, " ") and not string.find(v, "%%") then M.VERB[v] = true end
    end
end
-- What happens to a hero, or what they are or have: the DM's to say. Any other present-tense verb straight after a
-- hero's name is a move of theirs ("Pip cracks her knuckles"), whether or not it's in M.DOES.
M.HAPPENS = { is = true, has = true, was = true, finds = true, sees = true, hears = true, gets = true, falls = true,
              lands = true, rolls = true, misses = true, hits = true, wins = true, loses = true, comes = true, wakes = true,
              drops = true, stumbles = true, flies = true, needs = true, owes = true, carries = true, holds = true,
              stands = true, survives = true, dies = true, bleeds = true, burns = true, freezes = true, glows = true,
              learns = true, earns = true, gains = true, spots = true, notices = true, catches = true, saves = true,
              fails = true, succeeds = true, passes = true, makes = true, does = true, goes = true, can = true,
              staggers = true, reels = true, slumps = true, collapses = true, shivers = true, trembles = true,
              sways = true, coughs = true, chokes = true, sneezes = true, yelps = true, flinches = true, jerks = true,
              tumbles = true, sinks = true, floats = true, shrinks = true, grows = true, changes = true, blinks = true,
              sleeps = true, snores = true, dreams = true, yawns = true }
function M.any_move(s, hero)
    local v = string.match(s, "^" .. esc(hero) .. " (%a+s)%f[%A]")
    if v and not M.HAPPENS[v] and not string.match(v, "ss$") then
        return v
    end
end
-- (Outcomes stay the DM's: takes N damage, takes a hit; is flung, is knocked, is hit.)
local OUTCOME_AFTER = { takes = { "^%d", "^a hit", "^the hit", "^damage", "^the full", "^half" },
                        turns = { "^to stone", "^grey", "^to ", "^pale", "^white" },
                        goes = { "^down", "^flying", "^still", "^grey", "^stiff", "^limp", "^pale", "^white", "^under", "^sprawling" },
                        slips = { "^on ", "^and falls", "^off" }, holds = { "^on by", "^up under" } }

local function sentences(text)
    local out = {}
    -- (A sentence ends at . ! or ? followed by a space and a capital or a quote; quotes stay whole.)
    local rest = text
    while #rest > 0 do
        local i = 1
        local cut
        local inq = false
        while i <= #rest do
            local ch = string.sub(rest, i, i)
            if ch == '"' then
                inq = not inq
                -- (A quote that ends a sentence: '..."Lit." Pip looks', cut after the quote.)
                if not inq and string.match(string.sub(rest, i - 1, i - 1), "[%.!?]") and string.match(string.sub(rest, i + 1, i + 2), "^ [A-Z\"']") then
                    cut = i
                    break
                end
            elseif not inq and (ch == "." or ch == "!" or ch == "?") then
                local nxt = string.sub(rest, i + 1, i + 2)
                if nxt == "" or string.match(nxt, "^ [A-Z\"']") then
                    cut = i
                    break
                end
            end
            i = i + 1
        end
        if not cut then
            table.insert(out, rest)
            break
        end
        table.insert(out, string.sub(rest, 1, cut))
        rest = string.gsub(string.sub(rest, cut + 1), "^%s+", "")
    end
    return out
end
M.sentences = sentences

local function starts_with(s, name)
    return string.sub(s, 1, #name) == name and not string.match(string.sub(s, #name + 1, #name + 1), "[%w]")
end

-- The verb's plain form: goes go, reaches reach, copies copy, uses use.
local IRREG = { goes = "go", does = "do", has = "have", is = "am" }
function M.base(v)
    if IRREG[v] then
        return IRREG[v]
    end
    if string.match(v, "[^aeiou]ies$") then
        return string.sub(v, 1, -4) .. "y"
    end
    if string.match(v, "sses$") or string.match(v, "zzes$") or string.match(v, "xes$") or string.match(v, "[cs]hes$") then
        return string.sub(v, 1, -3)
    end
    if string.match(v, "s$") and not string.match(v, "ss$") then
        return string.sub(v, 1, -2)
    end
    return v
end

-- Said by the hero's own player: "Thessaly unscrews a cupboard door and straps it to her pack." becomes "I'll
-- unscrew a cupboard door and strap it to my pack." (their own pronouns only: another hero's "her" stays).
function M.first_person(sentence, hero, pronoun, others)
    local rest = string.sub(sentence, #hero + 2)
    local verb, after = string.match(rest, "^(%a+)(.*)$")
    if not verb then
        return nil
    end
    local out = "I'll " .. M.base(verb) .. after
    -- (A second verb of theirs: "and straps it", "and just listens", "and has to sit down".)
    out = string.gsub(out, " and (%a+ ?)(%a+s)%f[%A]", function(adv, v)
        if M.VERB[v] then
            return " and " .. adv .. M.base(v)
        end
        if M.ADVERB[string.gsub(adv, " $", "")] == nil and M.VERB[string.gsub(adv, " $", "")] then
            return nil
        end
        return nil
    end)
    out = string.gsub(out, " and (%a+s)%f[%A]", function(v)
        return M.VERB[v] and (" and " .. M.base(v)) or nil
    end)
    local own = (pronoun == "she" and { her = "my", herself = "myself", she = "I" })
        or (pronoun == "he" and { his = "my", himself = "myself", he = "I", him = "me" })
        or { their = "my", themselves = "myself", themself = "myself" }
    -- (Their pronouns until someone else is named: "a flower into Thessaly's notebook, marking the page she was
    -- stuck on" keeps Thessaly's "she".)
    local cut = #out + 1
    for _, n in ipairs(others or {}) do
        if n ~= hero then
            local i = string.find(out, "%f[%a]" .. esc(n) .. "%f[%A]")
            if i and i < cut then cut = i end
        end
    end
    local head = string.sub(out, 1, cut - 1)
    -- (Their contractions first: "before he's left" is "before I've left", "she's ready" "I'm ready".)
    local subj = (pronoun == "she" and "she") or (pronoun == "he" and "he") or "they"
    for _, pair in ipairs({ { "'s (%a+ed)%f[%A]", "'ve %1" }, { "'s (left)%f[%A]", "'ve %1" }, { "'s (gone)%f[%A]", "'ve %1" },
                            { "'s (been)%f[%A]", "'ve %1" }, { "'s (got)%f[%A]", "'ve %1" }, { "'s (seen)%f[%A]", "'ve %1" },
                            { "'s (done)%f[%A]", "'ve %1" }, { "'s%f[%A]", "'m" }, { "'d%f[%A]", "'d" }, { "'ll%f[%A]", "'ll" } }) do
        head = string.gsub(head, "%f[%a]" .. subj .. pair[1], "I" .. pair[2])
    end
    head = string.gsub(head, "%f[%a]" .. subj .. "'re%f[%A]", "I'm")
    head = string.gsub(head, "%f[%a](%a+)%f[%A]", function(w)
        return own[w] or w
    end)
    out = head .. string.sub(out, cut)
    out = string.gsub(out, "%f[%a]" .. esc(hero) .. "'s%f[%A]", "my")
    out = string.gsub(out, "%f[%a]" .. esc(hero) .. "%f[%A]", "me")
    -- (A list of their moves: "creeps up to the curtain, listens, and scrambles back down".)
    out = string.gsub(out, ", (%a+s)%f[%A]", function(v)
        return M.VERB[v] and (", " .. M.base(v)) or nil
    end)
    for a, b in pairs({ ["doesn't"] = "not", ["hasn't"] = "haven't", ["isn't"] = "I'm not", ["wasn't"] = "wasn't" }) do
        out = string.gsub(out, "%f[%a]" .. a .. "%f[%A]", b)
    end
    return out
end

local function matches_at(s, name, list)
    for _, v in ipairs(list) do
        if string.find(s, "^" .. esc(name) .. "'?s? " .. v .. "%f[%A]") then
            return v
        end
    end
end

-- Anywhere in a sentence (outside quotes): a person as the subject of a feeling or a want.
function M.mind_in(text, names)
    local bare = string.gsub(text or "", '"[^"]*"', '""')
    bare = string.gsub(bare, "\226\128\156.-\226\128\157", '""')
    for _, n in ipairs(names) do
        for _, v in ipairs(M.MIND) do
            if string.find(bare, "%f[%a]" .. esc(n) .. " " .. v .. "%f[%A]") then
                return n .. " " .. string.gsub(v, "[%%%?]", "")
            end
        end
        if string.find(bare, "%f[%a]" .. esc(n) .. "'s bad feeling") then
            return n .. "'s bad feeling"
        end
    end
    -- ("His bad feeling is worse up here", "a Franc he's sure wasn't there": a pronoun's feeling or certainty, in a
    -- line about a hero.)
    local about = false
    for _, n in ipairs(names) do
        if string.find(bare, "%f[%a]" .. esc(n) .. "%f[%A]") then about = true end
    end
    if about or string.find(bare, "%f[%a][Hh][ie][sr] bad feeling") then
        for _, pat in ipairs({ "[Hh][ie][sr] bad feeling", "s?he's sure", "s?he is sure", "s?he feels", "s?he wants", "s?he thinks",
                               "s?he decides", "s?he'd rather", "s?he hopes" }) do
            if string.find(bare, "%f[%a]" .. pat .. "%f[%A]") then
                return "a hero's " .. pat
            end
        end
    end
end

-- people: { { hero = "Thessaly", friend = "Mara", key = "mara", pronoun = "she" }, ... }. last: the last line said
-- before this one ({ who = key, text }), for an echo. Returns the lines to say, in order: { kind = "say", who, ic,
-- text } for the friends', and the DM's own as { kind = "dm", text }; and the sentences never said (a feeling, a
-- want, a look), for the check.
function M.split(text, people, last)
    local unsaid = {}
    local names = {}
    for _, p in ipairs(people) do
        table.insert(names, p.hero)
        table.insert(names, p.friend)
    end
    local out, kept = {}, {}
    -- (In the order said: the DM's description, the player's move, the DM's answer.)
    local function flush()
        if #kept > 0 then
            table.insert(out, { kind = "dm", text = table.concat(kept, " ") })
            kept = {}
        end
    end
    -- (A friend's words written into the DM's line.)
    for _, p in ipairs(people) do
        local q = string.match(text, "^" .. esc(p.friend) .. ': "(.*)"$')
        if q then
            return { { kind = "say", who = p.key, ic = false, text = q } }, unsaid
        end
    end
    for _, s in ipairs(sentences(text)) do
        local handled = false
        for _, p in ipairs(people) do
            local q, f = string.match(s, "^['\"](.-)[,.!?]?['\"],? (%a+) %a+s%.?$")
            if q and f == p.friend then
                flush()
                table.insert(out, { kind = "say", who = p.key, ic = false, text = util.sentence_case(q) .. "." })
                handled = true
                break
            end
            if starts_with(s, p.hero) or starts_with(s, p.friend) then
                local who_name = starts_with(s, p.hero) and p.hero or p.friend
                if matches_at(s, who_name, M.MIND) or matches_at(s, who_name, M.SHOWS) then
                    handled = true      -- (never said)
                    table.insert(unsaid, s)
                    break
                end
                local v = who_name == p.hero and (matches_at(s, p.hero, M.DOES) or M.any_move(s, p.hero))
                if v then
                    local after = string.match(string.sub(s, #p.hero + 2 + #v), "^%s*(.*)$") or ""
                    local outcome = false
                    for _, pat in ipairs(OUTCOME_AFTER[v] or {}) do
                        if string.find(after, pat) then outcome = true end
                    end
                    if not outcome then
                        handled = true
                        local echo = last and last.who == p.key and M.overlap(last.text, s)
                        if not echo then
                            local fp = M.first_person(s, p.hero, p.pronoun, names)
                            if fp then
                                flush()
                                table.insert(out, { kind = "say", who = p.key, ic = true, text = fp, announce = true })
                            end
                        end
                        break
                    end
                end
            end
        end
        if not handled then
            if M.mind_in(s, names) then
                -- (A feeling or a want inside a longer sentence: that sentence isn't said.)
                table.insert(unsaid, s)
            else
                table.insert(kept, s)
            end
        end
    end
    flush()
    return out, unsaid
end

local STOP = { the = true, a = true, an = true, ["and"] = true, of = true, to = true, ["in"] = true, on = true, at = true,
               it = true, is = true, i = true, ["i'll"] = true, ["i'm"] = true, my = true, her = true, his = true,
               with = true, ["for"] = true, by = true, up = true, over = true, that = true, this = true, all = true }
-- Do two lines share a word that matters (an echo: "I'm searching the pond." then "Thessaly goes over the pond.")?
function M.overlap(a, b)
    local seen = {}
    for w in string.gmatch(string.lower(a or ""), "[%a']+") do
        if #w > 3 and not STOP[w] then seen[w] = true end
    end
    for w in string.gmatch(string.lower(b or ""), "[%a']+") do
        if seen[w] then return true end
    end
    return false
end

-- The night's people, for split: each seat's hero, friend, key and pronoun.
function M.people_of(players)
    local out = {}
    for _, p in ipairs(players or {}) do
        if p.char and p.name then
            local pt = util.pronoun_of(p.char)
            table.insert(out, { hero = p.char, friend = p.name, key = p.key, pronoun = type(pt) == "table" and pt.they or pt })
        end
    end
    return out
end

return M
