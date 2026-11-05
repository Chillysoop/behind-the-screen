-- Conner's playtest of the November 4 build (docs/playtests/2026-11-04/conner-feedback/README.md), the
-- points fixed first: who may hear a line, the DM speaking for the players, and claims with nothing
-- behind them (docs/design/2026-11-05-root-causes.md, classes 1 to 3). Whole prologues (the museum sim
-- in this process, three DMs) read back line by line, plus targeted cases. Each item fails on 5bf3311.
-- Run from the project root:
--     lua tools/tests/conner_nov4_check.lua [seeds]
--   A   audience: nothing the heroes haven't seen is said to the table (the hedges, the statue, the
--       knight, the hook lines, the stair's smoke); Euryale's thoughts are behind the screen; a "dm" line
--       is captioned as what it is; the knight is a painting until it wakes; nobody set down in the room
--       across the hall; the Lecturer behind his lectern (C4, C6, C12, C16, C21, C22, C23)
--   G   agency: the DM never says what a hero thinks or wants at a fork; the friends say it, and the DM's
--       read is behind the screen; more in character as the weeks go (C5, C7, C8, C20)
--   R   claims: "+1 on the next check" lands; the paint is its holder's; the daggers say what they do;
--       inspiration gets spent (C14, C15, C17, C25)
--   W   words: "You set it yourself" (C3); "last time" from the friends, who are always playing it for
--       the first time (C26)

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local SEEDS = tonumber(arg[1]) or 4
local FIRST = 61
local STYLES = { "careful", "random", "careless" }
local ITEMS = { "run", "A", "G", "R", "W" }
local NAMES = { run = "whole prologues", A = "who may hear a line", G = "the players decide, and say so",
                R = "claims with something behind them", W = "the words" }

local fails = {}
local function fail(item, msg)
    fails[item] = fails[item] or { n = 0 }
    if #fails[item] < 8 then
        table.insert(fails[item], msg)
    end
    fails[item].n = fails[item].n + 1
end
local E = {}
local function add(item, key, n)
    E[item] = E[item] or {}
    E[item][key] = (E[item][key] or 0) + (n or 1)
end
local function case(item, fn)
    local ok, err = pcall(fn)
    if not ok then
        fail(item, "error: " .. tostring(err))
    end
end
local function has(s, sub)
    return string.find(s or "", sub, 1, true) ~= nil
end

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local night_mod = require "game.model.night"

-- What the friends say in character, and the inspiration tokens, by week: from every event a night emits.
local IC = {}
local TOKENS = { given = 0, spent = 0 }
local real_emit = night_mod.emit
night_mod.emit = function(self, ev)
    local r = real_emit(self, ev)
    if ev.kind == "say" and ev.who and self.campaign and night_mod.hero_voiced and night_mod.hero_voiced(ev.text) then
        local w = self.campaign.week or 1
        IC[w] = IC[w] or { n = 0, ic = 0 }
        IC[w].n = IC[w].n + 1
        IC[w].ic = IC[w].ic + (ev.ic and 1 or 0)
    elseif ev.kind == "roll_where" and ev.text and string.find(ev.text, "they learned from the last miss", 1, true) then
        TOKENS.lessons = (TOKENS.lessons or 0) + 1        -- (a big roll's +1, said on its card)
    elseif ev.kind == "token" and ev.what == "inspiration" then
        if ev.spent then
            TOKENS.spent = TOKENS.spent + 1
        else
            TOKENS.given = TOKENS.given + 1
        end
    end
    return r
end

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
        fail("run", "seed " .. seed .. " " .. style .. ": " .. tostring(err))
        return
    end
    add("run", "prologues")
    table.insert(RUNS, { tag = seed .. " " .. style, L = out })
end
for _, style in ipairs(STYLES) do
    for seed = FIRST, FIRST + SEEDS - 1 do
        sim(seed, style)
    end
end

-- The styles the table hears (game/model/voice.lua's UNHEARD are the DM's alone).
local voice = require "game.model.voice"
local FRIENDS = { mara = true, dev = true, jess = true, sam = true }
local function each_line(fn)
    for _, R in ipairs(RUNS) do
        for i, l in ipairs(R.L) do
            local who, text = string.match(l, "^  %[([^%]]+)%] (.*)$")
            if who then
                fn(R, i, who, text)
            end
        end
    end
end

-- A: who may hear a line ---------------------------------------------------------------------------
local SPOILERS = { "aren't hedges", "hasn't moved. Yet", "so lifelike it almost breathes", "Hedges that walk",
                   "hunters hiding in the dioramas", "smell of smoke and wine", "Smoky air drifts" }
each_line(function(R, i, who, text)
    if voice.heard(who) then
        add("A", "heard_lines")
        for _, s in ipairs(SPOILERS) do
            if has(text, s) then
                fail("A", R.tag .. ": said to the table before anything showed it: '" .. text .. "'")
            end
        end
    end
    if who == "interlude" then
        add("A", "thoughts_upstairs")
    end
end)
case("A", function()
    if not voice.UNHEARD.interlude then
        fail("A", "Euryale's thoughts upstairs (the interlude) are heard by the table")
    end
    local f = io.open("game/ui/night_view.lua")
    local src = f:read("*a")
    f:close()
    if not has(src, 'interlude = { "BEHIND YOUR SCREEN') then
        fail("A", "the interlude is captioned as if you'd said it to the table")
    end
    local want = { ["You nod and keep going."] = "you", ["Chairs scrape. Here we go."] = "say",
                   ["The voice is terrible. Jess cries laughing. Sam has to put his drink down."] = "chatter",
                   ["Helmets full of pond water hit the topiary."] = "told",
                   ["You shrug behind the screen. \"Your call.\""] = "say",
                   ["Twenty minutes of pizza and gossip. Everyone comes back a bit happier."] = "chatter" }
    for t, k in pairs(want) do
        add("A", "voices_sorted")
        if voice.of(t) ~= k then
            fail("A", "a \"dm\" line captioned as " .. tostring(voice.of(t)) .. ", not " .. k .. ": " .. t)
        end
    end
end)
-- The board: the knight's not stood on the mat as the hall's person; nobody set down across the hall
-- in the offices; the Lecturer at his lectern.
local function fresh_campaign(seed)
    adventure.enter()
    local c = campaign_mod.new(seed or 5)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    return c
end
local function street_night(seed)
    local c = fresh_campaign(seed)
    c:start_week()
    local night = c:start_night()
    local ev = night:advance()
    local guard = 0
    while ev.kind ~= "done" and not (ev.kind == "scene" and night.scene and night.scene.room) and guard < 2000 do
        guard = guard + 1
        local answer
        if ev.kind == "decision" or ev.kind == "ruling" then
            answer = 1
        elseif ev.kind == "improv" then
            answer = { 1 }
        elseif ev.kind == "roll_where" then
            answer = "open"
        elseif ev.kind == "roll" then
            answer = 10
        end
        ev = night:advance(answer)
    end
    return c, night
end
case("A", function()
    local mn = require "game.model.museum_night"
    local fight = require "game.model.fight"
    local c, night = street_night(7)
    local function stage(id)
        local sc = mn.build_scene(night, id)
        sc.terrain = night:terrain_for(sc)
        local party, npc = night:staging(sc)
        local _, layout = fight.blocked_set(sc.terrain, night:map_for(sc))
        return party, npc, layout
    end
    local _, npc = stage("paintings")
    add("A", "boards_staged")
    if npc and npc.cast == "mus_knight" then
        fail("A", "the Hall of Paintings: the knight's mini stands on the mat before it climbs out of its frame")
    end
    local party, _, layout = stage("offices")
    add("A", "boards_staged")
    for _, q in ipairs(party) do
        if q.y > layout.party[2] or q.y < layout.party[2] - 2 then
            fail("A", "the offices: " .. q.id .. " set down at " .. q.x .. "," .. q.y .. ", in a study across the hall from the party's way in")
        end
    end
    local _, lnpc, llayout = stage("lecture")
    add("A", "boards_staged")
    if not lnpc or math.abs(lnpc.x - 17) > 1 or math.abs(lnpc.y - 7) > 1 then
        fail("A", "the lecture theatre: the Lecturer isn't behind his lectern (at " .. (lnpc and (lnpc.x .. "," .. lnpc.y) or "nowhere") .. ")")
    end
end)

-- G: the players decide, and say so -----------------------------------------------------------------
local forks, reads = 0, 0
each_line(function(R, i, who, text)
    if (who == "dm" or who == "narration") and has(text, "thinks better of it") then
        fail("G", R.tag .. ": the DM says what a hero decided: '" .. text .. "'")
    end
    if who == "narration" or who == "dm" then
        if has(text, "Everyone has an opinion") then
            forks = forks + 1
            fail("G", R.tag .. ": the fork's read-aloud says what each of them wants: '" .. string.sub(text, 1, 140) .. "'")
        end
        for _, n in ipairs({ "Mara", "Dev", "Jess", "Sam" }) do
            if string.find(text, n .. " wants? ") or string.find(text, n .. " and %a+ want ") then
                fail("G", R.tag .. ": the DM tells the table what " .. n .. " wants: '" .. string.sub(text, 1, 140) .. "'")
                break
            end
        end
    end
    if who == "screen" and (has(text, "Your hunch:") or has(text, "Reading the table:") or has(text, "Your read on them:")) then
        reads = reads + 1
    end
end)
E.G = E.G or {}
E.G.dm_reads_behind_the_screen = reads
if reads == 0 then
    fail("G", "no fork had the DM's own read of the table, behind the screen")
end
do
    local first, late = IC[1], nil
    for w = 3, 8 do
        if IC[w] then
            late = late or { n = 0, ic = 0 }
            late.n, late.ic = late.n + IC[w].n, late.ic + IC[w].ic
        end
    end
    local s1 = first and first.ic / math.max(1, first.n) or 0
    local s3 = late and late.ic / math.max(1, late.n) or 0
    E.G.bids_in_character_week1_pct = math.floor(100 * s1 + 0.5)
    E.G.bids_in_character_week3on_pct = math.floor(100 * s3 + 0.5)
    if not (late and first) or s3 < s1 + 0.15 then
        fail("G", string.format("a bid for what the party does is said in character no more from week 3 on (%.0f%%) than in week 1 (%.0f%%)", 100 * s3, 100 * s1))
    end
end

-- R: claims with something behind them -------------------------------------------------------------
case("R", function()
    local c, night = street_night(9)
    local p = night.players[1]
    c.learned = { [p.key] = 1 }
    local n, n2 = 0, 0
    -- (Inside the night's own coroutine: it says the +1 out loud.)
    local co = coroutine.create(function()
        n = night.take_learned and night:take_learned(p) or 0
        n2 = night.take_learned and night:take_learned(p) or 0
    end)
    local guard = 0
    while coroutine.status(co) ~= "dead" and guard < 100 do
        guard = guard + 1
        local ok, e = coroutine.resume(co)
        if not ok then
            error(e)
        end
    end
    add("R", "learned_cases")
    if n ~= 1 then
        fail("R", "a hero who learned from a miss doesn't get +1 on their next check")
    elseif n2 ~= 0 then
        fail("R", "the +1 from a miss lands twice")
    end
end)
local near, remembered = 0, 0
each_line(function(R, i, who, text)
    if who == "good" and string.find(text, "^Not quite, but") then
        near = near + 1
    elseif who == "record" and has(text, "remembers the miss") then
        remembered = remembered + 1
    end

    if has(text, "twin daggers") and has(text, "hit like magic weapons") then
        fail("R", R.tag .. ": the daggers don't say what they do: '" .. text .. "'")
    end
    if has(text, "still wet in") and has(text, "counts as paint") then
        add("R", "painted_weapon_said")
    end
end)
E.R = E.R or {}
remembered = remembered + (TOKENS.lessons or 0)
E.R.near_misses_learned, E.R.learned_used = near, remembered
if near > 0 and remembered < math.floor(near / 2) then
    fail("R", string.format("%d misses ruled \"they learn from it\", and only %d +1s landed on a check", near, remembered))
end
case("R", function()
    local mr = require "game.rules.museum"
    local b = {}
    mr.setup(b, { paint = "dev" })
    add("R", "paint_cases")
    if b.paint ~= "dev" then
        fail("R", "the painted weapon is everyone's, not the one hero's who pulled it out of the painting")
    end
end)
E.R.inspiration_given, E.R.inspiration_spent_out_of_fights = TOKENS.given, TOKENS.spent
-- (When a player spends it: a natural 1, or a miss a new die could turn; on a quick check, a near miss.)
case("R", function()
    local sp = night_mod.spends_inspiration
    add("R", "inspiration_cases")
    if not sp then
        fail("R", "nothing decides when a friend spends Heroic Inspiration out of a fight but a miss on a big roll")
        return
    end
    local p = { heroic = true }
    local cases = { { 1, 3, 15, "check", true }, { 9, 3, 15, "check", true }, { 4, 3, 15, "check", false },
                    { 5, 2, 21, "big", false }, { 8, 3, 15, "big", true }, { 2, 0, 12, "check", false } }
    for _, t in ipairs(cases) do
        if sp(p, t[1], t[2], t[3], t[4]) ~= t[5] then
            fail("R", string.format("a %d%+d against DC %d on a %s: spends inspiration %s, should be %s", t[1], t[2], t[3], t[4],
                tostring(not t[5]), tostring(t[5])))
        end
    end
end)

-- W: the words -----------------------------------------------------------------------------------------
each_line(function(R, i, who, text)
    if has(text, "You set it yourself") then
        fail("W", R.tag .. ": '" .. text .. "'")
    end
    if FRIENDS[who] and string.find(string.lower(text), "last time") then
        add("W", "last_time_from_a_friend")
        fail("W", R.tag .. ": a friend says \"last time\", as if they'd played it before: '" .. text .. "'")
    end
end)

-- Report ------------------------------------------------------------------------------------------------
local total = 0
for _, item in ipairs(ITEMS) do
    local f = fails[item]
    local bits = {}
    local keys = {}
    for k in pairs(E[item] or {}) do
        table.insert(keys, k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        table.insert(bits, k .. " " .. tostring(E[item][k]))
    end
    print(string.format("%-4s %-36s %s%s", item, NAMES[item], table.concat(bits, ", "), f and ("  FAIL x" .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("     FAIL: " .. m)
    end
    total = total + (f and f.n or 0)
end
print(total == 0 and "conner nov4 check: all clear" or ("conner nov4 check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
