-- Round three, batch C: words, votes and the chat (the third playtest's reviews: alive.md 1-22, the
-- careful and random DMs' M1, M8, M11, M13-M15, F1-F4 and broken text, the engine run's 7, 8 and 10).
-- Whole prologues: the museum sim (tools/sim/museum.lua) played in this process over the reviewers'
-- seeds (31 to 38) with its three DMs, every line the table hears read back as the reviewers read it,
-- plus targeted cases. Each item fails on e691363.
-- Run from the project root:
--     lua tools/tests/round3_words_check.lua [seeds]
--   V   votes: bids from the moment, not the seat; nobody overturns their own bid unasked; reasons fit
--       the option; "last time" is true; nobody credited who never spoke; no loser's line from the
--       winners; "Outvoted" only when outvoted
--   L   looking round and the friends' small looks: about that thing, once a room; more ways; lines that
--       fit the hero, the room and how the fight went
--   C   the group chat: from what happened, no card titles, no script, true counts, news that comes out
--   P   pronouns and broken text: chat, Euryale, single foes, Session Zero, spoken labels; wider pools
--   S   the chain and the journey read as a story

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local SEEDS = tonumber(arg[1]) or 8
local FIRST = 31
local STYLES = { "careful", "random", "careless" }
local ITEMS = { "run", "V", "L", "C", "P", "S" }
local NAMES = { run = "whole prologues", V = "votes from the moment", L = "looking round, fitting lines",
                C = "the group chat", P = "pronouns, broken text, wider pools", S = "the chain as a story" }

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
local function set(item, key, v)
    E[item] = E[item] or {}
    E[item][key] = v
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
local util = require "game.model.util"
local mn = require "game.model.museum_night"
local events = require "game.model.events"
local MODULE = adventure.data

-- The options the reviewers judged careful or bold (alive.md's votes.py): the "last time" and the
-- mood reasons are checked against these, whatever the code calls them.
local CAREFUL = { "douse the hedges", "drop a coin", "give the knight a wide berth", "put the painted weapons back", "put it back", "work out the ritual",
    "tidy up for flitwidget", "leave the exhibits alone", "pick the lock, quietly", "save it for the gorgon", "leave the wine alone",
    "forget the frame", "try the brass key", "leave the mess", "save the francs", "talk her round", "go round and make" }
-- (Not the mirror-bright door: the module says it's neither, `lean = "none"`, a precaution as much as a
-- grab, so "It's the smart play" fits it as well as "You never know".)
local BOLD = { "set the bushes on fire", "just fight them", "have a go at the lock", "take a closer look at the knight", "keep them till they drip", "keep it till it drips",
    "skip the homework", "keep the twin daggers", "shoulder it open", "flip the switch", "drink the wine",
    "fight her", "reach into the frame", "follow the marks", "put her to sleep" }
local function cls(t)
    t = string.lower(t or "")
    for _, c in ipairs(CAREFUL) do
        if has(t, c) then
            return "careful"
        end
    end
    for _, b in ipairs(BOLD) do
        if has(t, b) then
            return "bold"
        end
    end
    return nil
end
-- Reasons that only fit one kind of option.
local BOLD_WORDS = { "Let's go big", "too good a mood to play it safe", "feeling lucky", "Where's the fun in that", "played it safe last time",
    "Come on, it'll be chaos", "What's the worst that could happen", "Let's do something braver", "My turn for some fun", "Let's not play it safe twice" }
local SAFE_WORDS = { "Easy does it", "keep it simple", "The easy way", "No surprises", "Fewer ways for it to go wrong", "safest bet", "smart play",
    "charged in last time", "went in swinging last time", "reckless last time", "Easiest way through", "Let's be smart for once", "Maybe not again",
    "Let's not push it", "pushed our luck before", "Let's be careful", "Gently, please", "The careful way" }
local HABIT_SAFE = { "played it safe last time", "were careful last time", "Let's do something braver", "Let's not play it safe twice", "We were good before" }
local HABIT_BOLD = { "went in swinging last time", "charged in last time", "reckless last time", "Let's be smart for once", "Maybe not again", "pushed our luck before" }
local PUSHED = { "I went along last time", "I gave way last time", "Last time I came round", "Last time I let you", "and we didn't. Not again",
    "My turn now" }
local FRIENDS = { mara = "Mara", dev = "Dev", jess = "Jess", sam = "Sam" }

-- The wants and their short forms, by card: which option a line names.
local WANTS = {}
local function card_opts(m)
    for _, o in ipairs(m.options or {}) do
        if o.want then
            table.insert(WANTS, { w = string.lower(o.want), card = m.id })
            if o.short then
                table.insert(WANTS, { w = string.lower(o.short), card = m.id, of = string.lower(o.want) })
            end
        end
    end
end
for _, m in ipairs(MODULE.moments) do
    if m.party then
        card_opts(m)
    end
end
for _, k in ipairs({ "drink", "talk", "yield" }) do
    if MODULE.showdown[k] then
        card_opts(MODULE.showdown[k])
    end
end
table.sort(WANTS, function(a, b)
    return #a.w > #b.w
end)
local function names_want(t)
    t = string.lower(t or "")
    for _, x in ipairs(WANTS) do
        local s, e = string.find(t, x.w, 1, true)
        if s then
            local before = s == 1 and " " or string.sub(t, s - 1, s - 1)
            local after = string.sub(t, e + 1, e + 1)
            if not string.find(before, "%a") and not string.find(after, "%a") then
                return x.of or x.w, x.card
            end
        end
    end
    return nil
end

-- Whole prologues ---------------------------------------------------------------------------------
-- Each run's log, exactly as `lua tools/sim/museum.lua <seed> <style> log` prints it.
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
    for _, l in ipairs(out) do
        if string.find(l, "^FAIL") then
            fail("run", "seed " .. seed .. " " .. style .. ": " .. l)
        end
    end
    add("run", "prologues")
    table.insert(RUNS, { tag = seed .. " " .. style, L = out })
end
for _, style in ipairs(STYLES) do
    for seed = FIRST, FIRST + SEEDS - 1 do
        sim(seed, style)
    end
end
local N = #RUNS

-- V: the votes ------------------------------------------------------------------------------------
do
    local card_n, bids = {}, {}
    local same_breath, reasons_wrong, claims_false, claims, silent, credited = 0, 0, 0, 0, 0, 0
    local winner_grumbles = 0
    for _, R in ipairs(RUNS) do
        local cur, spoke, lines = nil, nil, nil       -- (the vote being talked over: bids in order, who spoke)
        local last_dec_class, last_winners = nil, {}
        for i, l in ipairs(R.L) do
            if string.find(l, "^==") or string.find(l, "^########") then
                cur = nil
            end
            local who, t = string.match(l, "^  %[(%a+)%] (.*)$")
            if who and FRIENDS[who] then
                -- (What a line is for: its first sentence, not a reason that names the vote before.)
                local w = string.match(t, "^Let's ") and names_want(string.match(t, "^[^%.!?]*[%.!?]?") or t) or names_want(t)
                local bid = string.match(t, "^Let's ") and w
                if bid then
                    cur = cur or { first = {}, order = {}, spoke = {} }
                    local mine = cur.first[who]
                    if not mine then
                        cur.first[who] = bid
                    end
                    -- Reasons that fit the option.
                    local reason = string.match(t, "^Let's [^%.!]*[%.!]%s+(.+)$")
                    local k = cls(bid)
                    if reason and k then
                        for _, p in ipairs(k == "careful" and BOLD_WORDS or SAFE_WORDS) do
                            if has(reason, p) then
                                reasons_wrong = reasons_wrong + 1
                                fail("V", R.tag .. ": a reason for the other kind of option: '" .. t .. "'")
                            end
                        end
                    end
                    -- "Last time": the habit names the vote before, and "I gave way" only from someone who did.
                    if reason then
                        for _, p in ipairs(HABIT_SAFE) do
                            if has(reason, p) then
                                claims = claims + 1
                                if last_dec_class ~= "careful" then
                                    claims_false = claims_false + 1
                                    fail("V", R.tag .. ": '" .. t .. "' after a pick that wasn't careful")
                                end
                            end
                        end
                        for _, p in ipairs(HABIT_BOLD) do
                            if has(reason, p) then
                                claims = claims + 1
                                if last_dec_class ~= "bold" then
                                    claims_false = claims_false + 1
                                    fail("V", R.tag .. ": '" .. t .. "' after a pick that wasn't bold")
                                end
                            end
                        end
                        for _, p in ipairs(PUSHED) do
                            if has(reason, p) then
                                claims = claims + 1
                                if last_winners[FRIENDS[who]] then
                                    claims_false = claims_false + 1
                                    fail("V", R.tag .. ": '" .. t .. "' from someone the last pick went to")
                                end
                            end
                        end
                    end
                    table.insert(cur.order, { who = who, w = bid })
                    cur.spoke[who] = true
                elseif cur then
                    cur.spoke[who] = true
                    -- Overturning their own bid: only in answer to someone else's push after it.
                    local mine = cur.first[who]
                    if w and mine and w ~= mine and not string.find(t, "^For the record") then
                        local pushed = false
                        local after = false
                        for _, b in ipairs(cur.order) do
                            if b.who == who and b.w == mine then
                                after = true
                            elseif after and b.who ~= who and b.w == w then
                                pushed = true
                            end
                        end
                        if not pushed then
                            same_breath = same_breath + 1
                            fail("V", R.tag .. ": " .. who .. " overturns their own bid with nobody pushing: '" .. t .. "'")
                        end
                    end
                    if w then
                        table.insert(cur.order, { who = who, w = w })
                    end
                end
            end
            local dec = string.match(l, "^  %[aside%] The table decides: (.*)$")
            if dec then
                local credit = string.match(dec, "%(([^()]*)'s [ip][dic][ek]a?%)") or string.match(dec, "%(([^()]*)'s pick%)")
                last_winners = {}
                if credit then
                    for n in string.gmatch(credit, "%a+") do
                        last_winners[n] = true
                    end
                end
                if cur then
                    local w, card = names_want(dec)
                    if card then
                        card_n[card] = (card_n[card] or 0) + 1
                        bids[card] = bids[card] or {}
                        for f in pairs(FRIENDS) do
                            local b = cur.first[f] or "-"
                            bids[card][f] = bids[card][f] or {}
                            bids[card][f][b] = (bids[card][f][b] or 0) + 1
                        end
                    end
                    if credit then
                        for n in string.gmatch(credit, "%a+") do
                            if n ~= "and" then
                                credited = credited + 1
                                if not cur.spoke[string.lower(n)] then
                                    silent = silent + 1
                                    fail("V", R.tag .. ": '" .. dec .. "', and " .. n .. " never said a word")
                                end
                            end
                        end
                    end
                    last_dec_class = cls(dec) or last_dec_class
                    R.voted_room = R.room
                    R.backers = last_winners
                end
                cur = nil
            end
            -- The winners don't grumble about the room they just voted for.
            local sc = string.match(l, "^== Scene %d+: (.*) %(")
            if sc then
                R.room = sc
            end
        end
    end
    -- Bids that never change: a friend's same bid on a card in nine runs of ten (cards seen 6 times or more).
    local fixed, pairs_n = 0, 0
    for card, n in pairs(card_n) do
        if n >= 6 then
            for f, by in pairs(bids[card]) do
                local top = 0
                for b, k in pairs(by) do
                    if b ~= "-" then
                        top = math.max(top, k)
                    end
                end
                if top > 0 then
                    pairs_n = pairs_n + 1
                    if top / n >= 0.9 then
                        fixed = fixed + 1
                    end
                end
            end
        end
    end
    set("V", "fixed_seat_bids", fixed .. " of " .. pairs_n)
    set("V", "same_breath_reversals", same_breath)
    set("V", "reasons_for_the_other_kind", reasons_wrong)
    set("V", "last_time_claims", claims .. " (" .. claims_false .. " false)")
    set("V", "credited_never_spoke", silent .. " of " .. credited)
    -- (e691363: 20 of 59 pairs; the bar leaves room for a strong taste, Dev and a knight, staying itself.)
    if fixed > 15 then
        fail("V", fixed .. " (card, friend) pairs make the same bid in nine runs of ten or more")
    end
end

-- Run fn as game night does, inside a coroutine, answering every call with its last option.
local function beats(fn)
    local co = coroutine.create(fn)
    local ok, ev = coroutine.resume(co)
    local guard, out = 0, {}
    while coroutine.status(co) ~= "dead" and guard < 200 do
        guard = guard + 1
        if not ok then
            error(ev)
        end
        table.insert(out, ev)
        ok, ev = coroutine.resume(co, type(ev) == "table" and ev.kind == "decision" and #ev.card.options or 1)
    end
    if not ok then
        error(ev)
    end
    return ev, out
end

-- "Outvoted" only when she was.
case("V", function()
    local thoughts = require "game.model.thoughts"
    for trial = 1, 24 do
        adventure.enter()
        local c = campaign_mod.new(700 + trial)
        adventure.enter(c)
        c:session_zero(social.default_choices())
        c:start_week()
        local night = c:start_night()
        night.mus = night.mus or {}
        local jess = c:player("jess")
        c.adv.flags.pip_alone = true
        local _, evs = beats(function()
            return thoughts.plan(night, jess, false)
        end)
        local text = ""
        for _, ev in ipairs(evs) do
            if type(ev) == "table" and ev.kind == "thought" and has(ev.text, "Outvoted") then
                text = ev.text
            end
        end
        for _, t in ipairs((night.th or {}).list or {}) do
            if has(t.text, "Outvoted") then
                text = t.text
            end
        end
        if has(text, "Outvoted") then
            fail("V", "case: Jess voted for the stairs, and her thought says 'Outvoted'")
        end
        add("V", "plan_thoughts")
    end
end)

-- A tired table at the garden: nobody says "easy does it" for setting the bushes on fire.
case("V", function()
    for trial = 1, 30 do
        adventure.enter()
        local c = campaign_mod.new(800 + trial)
        adventure.enter(c)
        c:session_zero(social.default_choices())
        c:start_week()
        local night = c:start_night()
        night.mus = night.mus or {}
        night.gentle = nil
        for _, p in ipairs(night.players) do
            p.mood = (trial % 2 == 0) and "tired" or "celebrating"
        end
        local card
        for _, m in ipairs(MODULE.moments) do
            if m.id == "mus_plaque" then
                card = m
            end
        end
        night.actor = c:player("mara")
        local said = {}
        local own = rawget(night, "emit")
        night.emit = function(self, ev, ...)
            if type(ev) == "table" and ev.kind == "say" then
                table.insert(said, ev.text)
            end
            return require("game.model.night").emit(self, ev, ...)
        end
        beats(function()
            return mn.table_pick(night, { id = card.id, options = card.options }, night.mus_vars)
        end)
        night.emit = own
        for _, t in ipairs(said) do
            local k = cls(string.match(t, "^Let's ([^%.]*)") or "")
            for _, p in ipairs(k == "bold" and SAFE_WORDS or (k == "careful" and BOLD_WORDS) or {}) do
                if has(t, p) then
                    fail("V", "case: '" .. t .. "'")
                end
            end
            add("V", "garden_lines_read")
        end
    end
end)

-- L: looking round, and lines that fit -----------------------------------------------------------------
do
    local STOCK = { "There's a story behind ", "I love that this museum has ", "be a clue?", "\"Stay close,\" I tell the others",
        "I've seen one of these before. Never like this", "Nothing in this place is what it looks like", "fight back? No? Moving on",
        "Anything in here I'm allowed to hit", "Okay, what's the deal with", "Could be useful later. Noting it" }
    local places = {}
    local lib = require "game.data.map_library"
    for _, b in pairs(lib.boards) do
        for _, pl in ipairs(b.places or {}) do
            if pl.line then
                places[pl.line] = true
            end
        end
    end
    local stock, reacts, asks = 0, 0, {}
    local own_lines = {}
    for _, room in pairs(MODULE.explore_say or {}) do
        for _, list in pairs(room) do
            for _, t in ipairs(list) do
                own_lines[t] = true
            end
        end
    end
    local function is_stock(t)
        for _, s in ipairs(STOCK) do
            if has(t, s) then
                return true
            end
        end
        return false
    end
    local LOCK_ROOMS = { ["The entrance hall"] = true, ["The museum offices"] = true }
    for _, R in ipairs(RUNS) do
        local room, fights = nil, 0
        for i, l in ipairs(R.L) do
            local sc = string.match(l, "^== Scene %d+: (.*) %(")
            if sc then
                room = sc
            end
            local who, t = string.match(l, "^  %[(%a+)%] (.*)$")
            if who and FRIENDS[who] then
                for _, s in ipairs(STOCK) do
                    if has(t, s) then
                        stock = stock + 1
                        fail("L", R.tag .. ": a stock look-around line: '" .. t .. "'")
                    end
                end
                if string.find(R.L[i + 1] or "", "^%s+%(small roll%) " .. who) then
                    asks[t] = true
                end
                if has(t, "flat of my blade") or has(t, "Shield bash") or (who == "sam" and has(t, "Out of habit")) then
                    fail("L", R.tag .. ": a line that doesn't fit " .. who .. "'s hero: '" .. t .. "'")
                end
                if (has(t, "lock was rude") or has(t, "magic that lock") or has(t, "stronger than it looks")) and not LOCK_ROOMS[room or ""] then
                    fail("L", R.tag .. ": a lock line in " .. tostring(room) .. ": '" .. t .. "'")
                end
                if has(t, "off the roof") then
                    fail("L", R.tag .. ": there's no roof: '" .. t .. "'")
                end
            end
            -- (A look's reaction: a friend's word right after the DM describes a place, the stock lines or the
            -- place's own.)
            local narr = string.match(l, "^  %[narration%] (.*)$")
            local nwho, nt = string.match(R.L[i + 1] or "", "^  %[(%a+)%] (.*)$")
            if narr and places[narr] and nwho and FRIENDS[nwho] and (own_lines[nt] or is_stock(nt)) then
                reacts = reacts + 1
            end
        end
    end
    local n_asks = 0
    for _ in pairs(asks) do
        n_asks = n_asks + 1
    end
    set("L", "stock_look_lines", stock)
    set("L", "look_reactions_per_prologue", string.format("%.1f", reacts / math.max(1, N)))
    set("L", "distinct_small_looks", n_asks)
    -- (e691363: 11.5 reactions a prologue, every one a stock line; 59 distinct small looks over 24. Now one a
    -- room with something to say: about 7.)
    if reacts / math.max(1, N) > 8 then
        fail("L", string.format("%.1f look-around reactions a prologue", reacts / N))
    end
    if n_asks < 75 then
        fail("L", "only " .. n_asks .. " different small looks over " .. N .. " prologues")
    end
end

-- C: the group chat ----------------------------------------------------------------------------------
do
    local titles = {}
    for _, m in ipairs(MODULE.moments) do
        if m.title then
            titles[#titles + 1] = string.lower((string.gsub(m.title, "[\"{}]", "")))
        end
    end
    local runs_of, posts = {}, 0
    for _, R in ipairs(RUNS) do
        local seen, hunting_won = {}, nil
        for _, l in ipairs(R.L) do
            if has(l, "## fight: party") then
                hunting_won = true
            elseif has(l, "## fight: foes") then
                hunting_won = false
            end
            local t = string.match(l, "^  %[chat%] %a+: (.*)$")
            if t then
                posts = posts + 1
                if not seen[t] then
                    seen[t] = true
                    runs_of[t] = (runs_of[t] or 0) + 1
                end
                local low = string.lower(t)
                for _, title in ipairs(titles) do
                    if #title > 6 and (has(low, "\"" .. title .. "\"") or has(low, "'" .. title .. "'")) then
                        fail("C", R.tag .. ": the chat quotes a card's title: '" .. t .. "'")
                    end
                end
                if string.find(low, "^%a+ finally found what they came for") then
                    fail("C", R.tag .. ": one hero called they: '" .. t .. "'")
                end
            end
        end
    end
    local wide, wide_posts = 0, 0
    for t, n in pairs(runs_of) do
        if n >= N / 2 then
            wide = wide + 1
        end
    end
    for _, R in ipairs(RUNS) do
        for _, l in ipairs(R.L) do
            local t = string.match(l, "^  %[chat%] %a+: (.*)$")
            if t and runs_of[t] >= N / 2 then
                wide_posts = wide_posts + 1
            end
        end
    end
    set("C", "posts", posts)
    set("C", "posts_heard_in_half_the_runs_pct", math.floor(100 * wide_posts / math.max(1, posts) + 0.5))
    -- (e691363: 59%: the same script every run.)
    if wide_posts / math.max(1, posts) > 0.45 then
        fail("C", string.format("%d%% of the chat is lines heard in half the runs or more", math.floor(100 * wide_posts / posts + 0.5)))
    end
end

-- The chat from a night built by hand: the moment that made the night in the party's words, never the
-- card's title; one hero who found what they came for is that hero, by their pronoun; two downs is twice,
-- three is three times; good news nobody heard comes out.
case("C", function()
    local mw = require "game.model.museum_week"
    adventure.enter()
    local c = campaign_mod.new(77)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        adventure.set_hook(c, key, MODULE.hooks[key][1].id)
    end
    c:start_week()
    c.week = 2
    events.add(c, { kind = "moment", card = "mus_knight_frame", opt = 2, session = 1, beat = true, text = "they gave the knight a wide berth",
                    where = "paintings" })
    c.adv.hook_paid = { jess = 1 }
    local night = { ledger = { { ev = "down", who = "dev" }, { ev = "down", who = "dev" }, { ev = "down", who = "dev" } },
                    call_log = { { card = "mus_knight_frame", title = "The Knight of Shades", deltas = { mara = 9 } } },
                    th = { list = { { who = "sam", need = "celebrating" } } }, mus = {} }
    c.night = night
    local out = mw.night_lines(c, night)
    local all = table.concat({ out.mara or "", out.dev or "", out.jess or "", out.sam or "" }, " | ")
    if not has(string.lower(out.mara or ""), "we gave the knight a wide berth") or has(string.lower(all), "the knight of shades\"") then
        fail("C", "case: the night's best moment isn't in the party's words: '" .. tostring(out.mara) .. "'")
    end
    if has(all, "TWICE") or not (has(out.dev or "", "3") or has(out.dev or "", "three") or has(out.dev or "", "more than standing")) then
        fail("C", "case: Brannoc went down three times, and the chat says: '" .. tostring(out.dev) .. "'")
    end
    if out.jess and has(out.jess, "they came for") then
        fail("C", "case: Pip found what she came for, and the chat says they: '" .. out.jess .. "'")
    end
    local msgs = mw.write_chat(c)
    local news = false
    for _, m in ipairs(msgs) do
        if m.key == "sam" and (has(m.text, "job") or has(m.text, "new job")) then
            news = true
        end
    end
    if not news then
        fail("C", "case: Sam's good news never came out at the table, and the chat doesn't say it either")
    end
    add("C", "night_built_by_hand")
end)

-- P: pronouns, broken text, wider pools -------------------------------------------------------------
do
    local breaks, rests = {}, {}
    for _, R in ipairs(RUNS) do
        local round = {}
        local intro = false
        for _, l in ipairs(R.L) do
            local t = string.match(l, "^  %[[%w ]+%] (.*)$") or ""
            if has(l, "Introduce yourselves") then
                intro, round = true, {}
            elseif has(l, "[interlude]") or has(l, "== Scene") then
                intro = false
            end
            local who, said = string.match(l, "^  %[(%a+)%] (.*)$")
            if intro and who and FRIENDS[who] then
                for _, r in ipairs(require("game.data.intros").REACT.all_in) do
                    local plain = string.gsub(r, "{char_them}", "")
                    if #plain > 12 and has(said, plain) then
                        if round[plain] then
                            fail("P", R.tag .. ": Session Zero says '" .. said .. "' twice in one round")
                        end
                        round[plain] = true
                    end
                end
            end
            if has(t, "Tea guy") then
                fail("P", R.tag .. ": 'Tea guy!' with no tea")
            end
            if has(t, "Who does it go for?") or (has(t, "Euryale") and has(t, "It attacks with its")) then
                fail("P", R.tag .. ": Euryale called it: '" .. t .. "'")
            end
            if has(t, "(to spend Francs)") or has(t, " on on ") or string.find(t, "Goodnight, sweet [%a ]+ %d") then
                fail("P", R.tag .. ": a card's words said aloud, or a mat's label: '" .. t .. "'")
            end
            if has(t, "with ") and string.find(t, "behind them%.$") and string.find(t, "^%u[%a ]+, with ") then
                fail("P", R.tag .. ": one foe called them: '" .. t .. "'")
            end
            local b = string.match(l, "^  %[dm%] (\"[^\"]+\".*)$")
            if b then
                for _, x in ipairs(mn.BREAK_START) do
                    if b == x then
                        breaks[x] = true
                    end
                end
            end
            for _, rb in ipairs(require("game.data.rests").beats) do
                if has(l, rb.line) then
                    rests[rb.id] = true
                end
            end
        end
    end
    local nb, nr = 0, 0
    for _ in pairs(breaks) do
        nb = nb + 1
    end
    for _ in pairs(rests) do
        nr = nr + 1
    end
    set("P", "break_lines_heard", nb)
    set("P", "rest_moments_seen", nr)
    -- (e691363: four break lines, two rest moments.)
    if #mn.BREAK_START < 6 or #require("game.data.rests").beats < 5 then
        fail("P", "the break and the rests come from pools of " .. #mn.BREAK_START .. " and " .. #require("game.data.rests").beats)
    end
end

-- Pronoun fills: Flitwidget, Euryale and a hero, where screens and lines used to say "they".
case("P", function()
    adventure.enter()
    local checks = {
        { util.fill("{Name_their} Goodwill filled up this week.", { name = "Mara" }), "Her Goodwill" },
        { util.fill("nothing: {name_they're} here", { name = "Flitwidget" }), "he's here" },
        { util.fill("why {char_they} came to the museum", { char = "Brannoc" }), "why he came" },
    }
    for _, k in ipairs(checks) do
        if not has(k[1], k[2]) then
            fail("P", "case: '" .. k[1] .. "', not '" .. k[2] .. "'")
        end
    end
    local found = false
    for _, src in ipairs({ "game/ui/report_view.lua", "game/ui/ties_view.lua", "game/model/takeover.lua" }) do
        local f = io.open(src)
        local s = f and f:read("*a") or ""
        if f then
            f:close()
        end
        if has(s, "\"Their Goodwill filled up") or has(s, "\"nothing: they're here\"") or has(s, "\" Who does it go for?\"")
            or has(s, "\" It attacks with its \"") then
            found = true
            fail("P", "case: " .. src .. " still says they or it for one person")
        end
    end
    if not found then
        add("P", "screen_sources_clean")
    end
    for _, l in ipairs(MODULE.want_more.jess) do
        local t = type(l) == "table" and l[1] or l
        if has(t, "Pip is keeping") then
            fail("P", "case: Jess's last word names Pip, whoever her hero is now")
        end
    end
end)

-- S: the chain as a story ------------------------------------------------------------------------------
do
    local sentences, bare, taut, finds = 0, 0, 0, 0
    for _, R in ipairs(RUNS) do
        local week_finds = 0
        for _, l in ipairs(R.L) do
            if string.find(l, "^  %-%- chain week") then
                week_finds = 0
            end
            local t = string.match(l, "^  %-%- (.*)$")
            if t and not string.find(t, "^report:") and not string.find(t, "^chain week") and not string.find(t, "^LEVEL") then
                sentences = sentences + 1
                if string.find(t, "^They went into [^,]*%.$") then
                    bare = bare + 1
                    fail("S", R.tag .. ": a bare step into a room: '" .. t .. "'")
                end
                if has(t, "fought the guardian, so they fought") or has(t, "fight her, so they fought") or has(t, "got away, so Euryale slipped away")
                    or has(t, "So Euryale slipped away") or string.find(t, "deal[^%.]*, so they struck a bargain") then
                    taut = taut + 1
                    fail("S", R.tag .. ": the chain says it twice: '" .. t .. "'")
                end
                if string.find(t, "found %w+ Flitwidget Francs?%.$") or has(t, "found a Flitwidget Franc,") then
                    week_finds = week_finds + 1
                    if week_finds > 1 then
                        finds = finds + 1
                        fail("S", R.tag .. ": another Franc found, on its own line: '" .. t .. "'")
                    end
                end
            end
        end
    end
    set("S", "chain_sentences", sentences)
    set("S", "bare_steps_into_a_room", bare)
    set("S", "said_twice", taut)
end

-- The chain from a log built by hand: a step into a room says where the next thing happened; a fight
-- told after the choice that started it says only how it ended; a repeat is left out; the Francs found
-- are one line at the end.
case("S", function()
    adventure.enter()
    local c = campaign_mod.new(91)
    adventure.enter(c)
    c.week = 3
    local into = events.add(c, { kind = "enter", beat = true, text = "they went into the Chamber of Ancients", where = "chamber" })
    local skip = events.add(c, { kind = "moment", beat = true, text = "they skipped the tablet and fought the guardian", where = "chamber" })
    events.add(c, { kind = "fight", beat = true, text = "they fought the Bone Construct, and they won", tail = ", and they won", where = "chamber",
                    from = skip, how = "therefore" })
    events.add(c, { kind = "find", thing = "francs", n = 1, beat = true, text = "Oswin found a Flitwidget Franc", where = "chamber", from = skip })
    events.add(c, { kind = "find", thing = "francs", n = 2, beat = true, text = "Pip found 2 Flitwidget Francs", where = "chamber" })
    local fled = events.add(c, { kind = "fight", beat = true, text = "Euryale came at them, and she got away", where = "lair" })
    events.add(c, { kind = "ending", thing = "escape", beat = true, text = "Euryale slipped away", where = "lair", from = fled, how = "therefore" })
    local lines = events.chain(c, 3)
    local all = table.concat(lines, " ")
    if not has(all, "In the Chamber of Ancients, they skipped the tablet") then
        fail("S", "case: the step into the chamber is its own line: " .. all)
    end
    if has(all, "so they fought the Bone Construct") then
        fail("S", "case: the fight is said twice: " .. all)
    end
    if has(all, "slipped away") then
        fail("S", "case: 'she got away, so Euryale slipped away': " .. all)
    end
    local fl = 0
    for _, l in ipairs(lines) do
        if has(l, "Flitwidget Franc") then
            fl = fl + 1
        end
    end
    if fl ~= 1 or not has(all, "Along the way") then
        fail("S", "case: the Francs found are " .. fl .. " lines: " .. all)
    end
    add("S", "chain_built_by_hand")
end)

-- The report --------------------------------------------------------------------------------------
local total = 0
for _, item in ipairs(ITEMS) do
    if not E[item] and not fails[item] then
        fail(item, "nothing seen: no run or case reached this item")
    end
    local parts = {}
    for k, v in pairs(E[item] or {}) do
        table.insert(parts, k .. " " .. tostring(v))
    end
    table.sort(parts)
    local f = fails[item]
    print(string.format("%-4s %-34s %s%s", item, NAMES[item], table.concat(parts, ", "), f and ("  FAILS " .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("     FAIL " .. m)
    end
    total = total + (f and f.n or 0)
end
print(total == 0 and "round three words check: every item holds" or ("round three words check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
