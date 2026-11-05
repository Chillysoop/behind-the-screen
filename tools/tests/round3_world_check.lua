-- Round three, batch B: who did it, what they have, what it cost, who remembers (the third playtest's
-- reviews: careful_dm, random_dm, alive). Whole prologues headless, played exactly as tools/sim/museum.lua
-- plays them (the same seed and style give the same log the reviews read: seeds 31 to 38, three DMs),
-- with each finding checked against what the table heard, plus targeted cases for the moments a run
-- can't be counted on to reach. Run from the project root:
--     lua tools/tests/round3_world_check.lua [first seed] [last seed]
-- Prints one line per finding: what was seen, and FAIL lines where play contradicts it.

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local util = require "game.model.util"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"

local FIRST = tonumber(arg[1]) or 31
local LAST = tonumber(arg[2]) or 38
local STYLES = { "careful", "random", "careless" }
local ITEMS = { "B1", "B2", "B3", "B4" }
local NAMES = { B1 = "one owner per action", B2 = "only what's owned fires; what's given is shown",
                B3 = "money adds up", B4 = "memory and knowledge are true" }

local fails = {}
local CUR                    -- the scan or case running now: fails are counted by it too
local function fail(item, msg)
    fails[item] = fails[item] or { n = 0, by = {} }
    if CUR then
        fails[item].by[CUR] = (fails[item].by[CUR] or 0) + 1
    end
    if #fails[item] < (os.getenv("ALL") and 100000 or 8) then
        table.insert(fails[item], msg)
    end
    fails[item].n = fails[item].n + 1
end
local E = {}
local function add(item, key, n)
    E[item] = E[item] or {}
    E[item][key] = (E[item][key] or 0) + (n or 1)
end
-- (Targeted cases run after the whole prologues: they touch shared state, and the prologues have to
-- play exactly as the sim plays them.)
local CASES = {}
local function case(item, fn)
    table.insert(CASES, { item, fn })
end
local function run_cases()
    for _, c in ipairs(CASES) do
        local ok, err = pcall(c[2])
        if not ok then
            fail(c[1], "error: " .. tostring(err))
        end
    end
    CUR = nil
end

local HERO = { mara = "Thessaly", dev = "Brannoc", jess = "Pip", sam = "Oswin" }
local HEROES = { "Thessaly", "Brannoc", "Pip", "Oswin" }
local function hero_in(s)
    for _, h in ipairs(HEROES) do
        if string.find(s or "", h, 1, true) then
            return h
        end
    end
end
local function heroes_in(s)
    local out = {}
    for _, h in ipairs(HEROES) do
        local at = string.find(s or "", h, 1, true)
        if at then
            table.insert(out, { h = h, at = at })
        end
    end
    table.sort(out, function(a, b) return a.at < b.at end)
    return out
end

-- One prologue, played as the sim plays it (tools/sim/museum.lua: the same rng, the same picks), with
-- what the table heard kept in order: { kind = "line" | "card" | "chat" | "chain" | "check", w, who, text,
-- card = the card's view, pick }. Returns the transcript and the campaign.
local function play(seed, style)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    local rng = require("game.model.rng").new(seed + 77)
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = adventure.data.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    local T = { seed = seed, style = style, reps = {}, nights = {} }
    local function put(e)
        table.insert(T, e)
        return e
    end
    for w = 1, adventure.data.MAX_WEEKS do
        local prep = c:start_week()
        for _, m in ipairs(c.chat) do
            put({ kind = "chat", w = w, who = m.who or m.key, text = m.text })
        end
        local pm = prep.museum
        for _, m in ipairs(c.chat) do
            if m.ask and not m.answered then
                museum_week.answer_chat(c, m, (style == "careful") and 1 or rng:int(1, 3))
            end
        end
        for _, pr in ipairs(c.adv.prompts) do
            if pr.kind == "request" then
                adventure.answer_request(c, pr.id, adventure.data.ANSWERS[style == "careful" and 2 or rng:int(1, 4)])
                if pr.id == "vorpal" then
                    T.vorpal_week = w
                end
            elseif pr.kind == "loose" then
                adventure.answer_loose(c, pr.id, 1)
            elseif pr.kind == "ruling" then
                adventure.answer_ruling(c, pr.id, style ~= "careless")
            elseif pr.kind == "favor" then
                adventure.answer_favor(c, pr.id, 1, 1)
                put({ kind = "favor", w = w, text = pr.id })
            end
        end
        if style ~= "careless" then
            museum_week.prep_greedy(prep)
            for _, id in ipairs(pm.ahead) do
                for _, kid in ipairs(adventure.data.rooms[id].knobs or {}) do
                    local k = adventure.data.knobs[kid]
                    museum_week.set_knob(prep, kid, k.pick_hero and "mara" or (rng:chance(0.6) or nil))
                end
            end
        end
        if pm.boss then
            c.adv.boss = { opener = rng:chance(0.7) and "talk" or "ambush", style = rng:chance(0.6) and "yields" or "last" }
        end
        T.pool = T.pool or {}
        T.pool[w] = { before = c.adv.francs or 0 }
        local night = c:start_night()
        T.nights[w] = night
        local ev = night:advance()
        local guard = 0
        while ev.kind ~= "done" and guard < 4000 do
            guard = guard + 1
            local answer
            if ev.kind == "narrate" or ev.kind == "say" or ev.kind == "npc" then
                local who = ev.kind == "say" and ev.who or (ev.kind == "npc" and ev.name) or ev.style
                put({ kind = "line", w = w, who = tostring(who), text = ev.text, room = night.scene and night.scene.room })
            elseif ev.kind == "turn" then
                put({ kind = "turn", w = w, who = ev.who and tostring(ev.who), steps = ev.steps or {} })
            elseif ev.kind == "battle" then
                put({ kind = "battle", w = w, phase = ev.phase, winner = ev.winner, room = night.scene and night.scene.room })
            elseif ev.kind == "scene" then
                put({ kind = "scene", w = w, text = ev.title, room = night.scene and night.scene.room })
            elseif ev.kind == "thought" then
                require("game.model.thoughts").bot_play(night, ev, style, rng)
            elseif ev.kind == "decision" then
                local opts = ev.card.options
                local pick = (style == "careful") and 1 or rng:int(1, #opts)
                if style == "careful" and string.find(ev.card.id or "", "^table_asks_") then
                    pick = #opts
                end
                if style == "careful" and opts[pick] and opts[pick].cost then
                    local hp, max, down = 0, 0, false
                    for _, pc in ipairs(night.pc_list or {}) do
                        hp, max = hp + math.max(0, pc.hp or 0), max + (pc.hp_max or 0)
                        down = down or ((pc.hp or 1) <= 0 and not pc.dead)
                    end
                    if not down and hp > 0.35 * max then
                        for i, o in ipairs(opts) do
                            if not o.cost and not o.disabled then
                                pick = i
                                break
                            end
                        end
                    end
                end
                if opts[pick].disabled then
                    pick = 1
                end
                put({ kind = "card", w = w, card = ev.card, pick = pick, text = (ev.card.title or "") .. ": " .. (ev.card.text or ""),
                      room = night.scene and night.scene.room })
                answer = pick
            elseif ev.kind == "ruling" then
                answer = 1
            elseif ev.kind == "improv" then
                answer = { 1 }
            elseif ev.kind == "roll_where" then
                answer = "open"
            elseif ev.kind == "roll" then
                answer = rng:d20()
            elseif ev.kind == "check" then
                put({ kind = "check", w = w, text = tostring(ev.text) })
            end
            ev = night:advance(answer)
        end
        local rep = c:finish_night()
        T.reps[w] = rep
        T.pool[w].after = c.adv.francs or 0
        T.pool[w].week = c.week
        local events = require "game.model.events"
        for _, line in ipairs((events.chain(c, c.week))) do
            put({ kind = "chain", w = w, text = line })
        end
        c:level_up()
        if adventure.over(c) then
            break
        end
    end
    T.c = c
    return T
end
local function tag(T, w)
    return "seed " .. T.seed .. " " .. T.style .. (w and (" week " .. w) or "")
end

-- B1. One owner per action ------------------------------------------------------------------------

-- The donation box's lock: the hero who kneels by the case is the one on the card, the roll and the chain.
local function lock_owner(T)
    for i, e in ipairs(T) do
        if e.kind == "line" and string.find(e.text, "kneels by the case", 1, true) then
            local kneel = hero_in(e.text)
            add("B1", "lock_kneels")
            -- (Whoever's best with picks of those who wanted it: Pip, when Jess was for it.)
            local d = T[i - 1]
            if d and d.kind == "line" and string.find(d.text, "The table decides", 1, true) and string.find(d.text, "Jess", 1, true)
                and kneel ~= "Pip" then
                fail("B1", tag(T, e.w) .. ": '" .. d.text .. "', and " .. kneel .. " kneels by the case, not Pip")
            end
            for j = i + 1, math.min(#T, i + 6) do
                local f = T[j]
                if f.kind == "card" and f.card.id == "mus_box_lock" then
                    local on = hero_in(f.card.text)
                    if on ~= kneel then
                        fail("B1", tag(T, e.w) .. ": " .. kneel .. " kneels by the case, and the lock card says '" .. f.card.text .. "'")
                    else
                        add("B1", "lock_card_same")
                    end
                elseif f.kind == "line" and f.who == "record" and string.find(f.text, "You said DC 13", 1, true) then
                    if hero_in(f.text) ~= kneel then
                        fail("B1", tag(T, e.w) .. ": " .. kneel .. " kneels by the case, and '" .. f.text .. "'")
                    end
                end
            end
        elseif e.kind == "chain" then
            local a, b = string.match(e.text, "(%a+) went for the donation box's lock, so (%a+) ")
            if a and b ~= a and hero_in(b) then
                fail("B1", tag(T, e.w) .. ": the chain says '" .. e.text .. "'")
            end
        end
    end
end

-- Who the chain credits with the DM's own voice for Telpur (the table heard "[dm] The voice is terrible").
local function voice_owner(T)
    for _, e in ipairs(T) do
        if e.kind == "chain" and string.find(e.text, "did Telpur's voice", 1, true) then
            fail("B1", tag(T, e.w) .. ": the chain gives the DM's voice to a hero: '" .. e.text .. "'")
        elseif e.kind == "line" and string.find(e.text, "The voice is terrible", 1, true) then
            add("B1", "telpur_voice")
        end
    end
end

-- Praise only for what happened: a move together needs both to have landed something on a foe in the
-- fight (a swing that missed doesn't count); a plan needs the table to have settled on one its owner
-- wanted, in this room.
local KEY = { Thessaly = "mara", Brannoc = "dev", Pip = "jess", Oswin = "sam" }
local FRIEND = { mara = "Mara", dev = "Dev", jess = "Jess", sam = "Sam" }
local function praise_owner(T)
    local landed, last_decides, casting = {}, nil, {}
    for _, e in ipairs(T) do
        if e.kind == "battle" and e.phase == "start" then
            landed, casting = {}, {}
        elseif e.kind == "scene" then
            last_decides = nil
        elseif e.kind == "turn" and e.who then
            -- (A spell's damage on a foe counts, even when a card splits the turn between the spell and
            -- its damage: the early knockout card, round three, A5. A missed swing's Graze doesn't.)
            for _, st in ipairs(e.steps) do
                if st.kind == "attack" and st.id == e.who then
                    casting[e.who] = nil
                    if st.hit then
                        landed[e.who] = true
                    end
                elseif st.kind == "spell" and st.id == e.who then
                    casting[e.who] = true
                elseif st.kind == "damage" and st.src and casting[st.src] and string.find(tostring(st.id), "^f%d") then
                    landed[st.src] = true
                end
            end
        elseif e.kind == "line" and string.find(e.text, "The table decides", 1, true) then
            last_decides = e.text
        elseif e.kind == "line" then
            local a, b = string.match(e.text, "^(%a+) and (%a+) pulled off a move together")
            if a and KEY[a] then
                add("B1", "move_together")
                for _, h in ipairs({ a, b }) do
                    if not landed[KEY[h] or ""] then
                        fail("B1", tag(T, e.w) .. ": '" .. e.text .. "', and " .. h .. " landed nothing in that fight")
                    end
                end
            end
            local p, q = string.match(e.text, "^(%a+)'s plan, (%a+)'s timing")
            if p and KEY[p] then
                add("B1", "plan_timing")
                if not (last_decides and string.find(last_decides, FRIEND[KEY[p]], 1, true)) then
                    fail("B1", tag(T, e.w) .. ": '" .. e.text .. "', and the room's last choice was " .. tostring(last_decides))
                end
            end
        end
    end
end

-- The painted weapon is the one its puller has: one thing, theirs to put back.
local function paint_owner(T)
    local puller
    for _, e in ipairs(T) do
        if e.kind == "line" then
            local p = string.match(e.text, "^(%a+) pulls out .-, still wet")
            if p and KEY[p] then
                puller = p
            elseif string.find(e.text, "starting to drip", 1, true) then
                add("B1", "paint_drips")
                if string.find(e.text, "weapons", 1, true) then
                    fail("B1", tag(T, e.w) .. ": one weapon came out of the painting, and '" .. e.text .. "'")
                end
                local named = hero_in(e.text)
                if puller and named ~= puller then
                    fail("B1", tag(T, e.w) .. ": " .. puller .. " pulled it out, and '" .. e.text .. "'")
                end
            end
        end
    end
end

-- The Lecturer's notes and the archivist's notebook: whoever the report says came away with them was
-- seen picking them up, and whoever hands Euryale a page is the one carrying them.
local function notes_owner(T)
    local heard = {}            -- week -> text of every line, for "was it said"
    local pages_by, pending_page
    for _, e in ipairs(T) do
        if e.kind == "line" then
            heard[e.w] = (heard[e.w] or "") .. "\n" .. e.text
            local h = hero_in(e.text)
            if h and (string.find(e.text, "page", 1, true)) and (string.find(e.text, "gathers", 1, true)
                or string.find(e.text, "scoops", 1, true) or string.find(e.text, "picks the pages", 1, true)) then
                pages_by = h
                add("B1", "pages_picked_up")
            end
            if string.find(e.text, "The table decides: put her to sleep with the Lecturer's notes", 1, true) then
                pending_page = true
            elseif pending_page and e.who == "record" then
                pending_page = nil
                add("B1", "page_handed")
                if pages_by and hero_in(e.text) ~= pages_by then
                    fail("B1", tag(T, e.w) .. ": " .. pages_by .. " picked up the pages, and '" .. e.text .. "' hands Euryale one")
                end
            end
        elseif e.kind == "chain" then
            for h, what in string.gmatch(e.text, "(%a+) came away with the (%a+'s %a+)") do
                if KEY[h] and (what == "Lecturer's notes" or what == "archivist's notebook") then
                    add("B1", "chain_came_away")
                    local word = what == "Lecturer's notes" and "page" or "notebook"
                    local ok = false
                    for line in string.gmatch(heard[e.w] or "", "[^\n]+") do
                        ok = ok or (string.find(line, h, 1, true) and string.find(line, word, 1, true) and true)
                    end
                    if not ok then
                        fail("B1", tag(T, e.w) .. ": the chain says " .. h .. " came away with the " .. what .. ", and no line gave them to " .. h)
                    end
                end
            end
        end
    end
end

-- A rules question is asked by whoever the card says asks it (the line just before it is theirs), and
-- the potion question by whoever drank it (or gave it, and says so).
local KEY_OF_FRIEND = { Mara = "mara", Dev = "dev", Jess = "jess", Sam = "sam" }
local LEAD_IN = {}           -- every line a rules card's lead-in can be (table talk and the rules_lawyer barks)
do
    local f = io.open("game/data/dialogue/lines.json")
    local data = require("game.model.jsonlite").decode(f:read("*a"))
    f:close()
    for _, l in ipairs(data.lines or {}) do
        if l.trigger == "rules_lawyer" then
            LEAD_IN[l.text] = true
        end
    end
    for _, b in ipairs(require("game.model.content").table_behaviors or {}) do
        if b.when == "rules" then
            for _, l in ipairs(b.lines) do
                LEAD_IN[type(l) == "table" and l.text or l] = true
            end
        end
    end
end
local function asker_owner(T)
    local potions = {}
    for i, e in ipairs(T) do
        if e.kind == "battle" and e.phase == "start" then
            potions = {}
        elseif e.kind == "turn" then
            for _, st in ipairs(e.steps) do
                if st.kind == "feature" and st.name == "Potion of Healing" then
                    table.insert(potions, { by = st.id, to = st.target })
                end
            end
        elseif e.kind == "card" and e.card.type == "rules" then
            local who = KEY_OF_FRIEND[string.match(e.card.text or "", "^(%a+)") or ""]
            local before = T[i - 1]
            if who and before and before.kind == "line" and LEAD_IN[before.text] then
                add("B1", "rules_lead_in")
                if before.who ~= who then
                    fail("B1", tag(T, e.w) .. ": [" .. before.who .. "] '" .. before.text .. "', then '" .. e.text .. "'")
                end
            end
            local drank = string.match(e.card.text or "", "^(%a+) drank a healing potion")
            local gave = string.match(e.card.text or "", "^(%a+) gave %a+ a healing potion")
            if drank or gave then
                add("B1", "potion_card")
                local k = KEY_OF_FRIEND[drank or gave]
                local ok = false
                for _, pt in ipairs(potions) do
                    ok = ok or (pt.by == k and ((drank and (pt.to == k or pt.to == nil)) or (gave and pt.to ~= k)))
                end
                if not ok then
                    fail("B1", tag(T, e.w) .. ": '" .. e.card.text .. "', and the fight's potions were " .. #potions)
                end
            end
        end
    end
end

-- B2. Only what's owned fires; what's given is shown ----------------------------------------------

-- Telpur's slime bites only when they bought the arrows and the slime (the bucket said at the fight's
-- start); the quiver Pip lifted off his shelf isn't sold back to them while she has it, and Telpur
-- knows his own stock when he next sees it.
local function stock_owned(T)
    local bucket, lifted, lifted_w, used, spotted = false, false, nil, false, false
    for _, e in ipairs(T) do
        if e.kind == "battle" and e.phase == "end" then
            bucket = false          -- (said as the fight starts, before its first turn: good for that fight)
        elseif e.kind == "line" then
            if string.find(e.text, "bucket of slime", 1, true) and string.find(e.text, "Out come", 1, true) then
                bucket = true
            end
            if string.find(e.text, "quiver of Telpur's fire arrows", 1, true) and e.who ~= "narration"
                and (string.find(e.text, "pocket now", 1, true) or string.find(e.text, "changed hands", 1, true)
                     or string.find(e.text, "never feels a thing", 1, true)) then
                lifted, lifted_w = true, e.w
                add("B2", "quiver_lifted")
            end
            if string.find(e.text, "fire arrows nobody paid for", 1, true) then
                used = true
            end
            -- (The shop is the table's own choice: its card is read out, then they talk it over.)
            if lifted and not used and string.find(e.text, "buy the fire arrows and the slime", 1, true) then
                fail("B2", tag(T, e.w) .. ": '" .. e.text .. "', while Pip has the quiver she lifted off his shelf")
            end
            if lifted and not used and string.find(e.text, "pools its Flitwidget Francs on the counter", 1, true) and e.w > lifted_w
                and not spotted then
                fail("B2", tag(T, e.w) .. ": back at Telpur's counter with his stolen quiver on Pip's back, and he never notices")
            end
            if e.who == "Telpur" and (string.find(e.text, "my stock", 1, true) or string.find(e.text, "MY arrows", 1, true)
                or string.find(e.text, "own stock", 1, true)) then
                spotted = true
                add("B2", "telpur_spots")
            end
        elseif e.kind == "turn" then
            for _, st in ipairs(e.steps) do
                if st.kind == "feature" and string.find(st.name or "", "Telpur's slime", 1, true) then
                    add("B2", "slime_bites")
                    if not bucket then
                        fail("B2", tag(T, e.w) .. ": " .. st.name .. " on " .. tostring(st.id) .. ", and nobody brought the slime")
                    end
                end
            end
        elseif e.kind == "card" and e.card.title == "What do they buy?" and lifted and not used then
            for _, o in ipairs(e.card.options) do
                if string.find(o.label or "", "Fire arrows and a bucket of slime", 1, true) then
                    fail("B2", tag(T, e.w) .. ": Telpur offers the fire arrows while Pip has the quiver she lifted off his shelf")
                end
            end
            if e.w > lifted_w and not spotted then
                fail("B2", tag(T, e.w) .. ": back at Telpur's counter with his stolen quiver on Pip's back, and he never notices")
            end
        end
    end
end

-- Flitwidget's bracelet: the table saw him give it, to the hero whose wrist the lair names.
local function bracelet_given(T)
    local given_to
    for _, e in ipairs(T) do
        if e.kind == "line" and string.find(e.text, "thin silver bracelet", 1, true) then
            given_to = hero_in(e.text)
            add("B2", "bracelet_handed_over")
        elseif e.kind == "line" and string.find(e.text, "bracelet", 1, true) and string.find(e.text, "saves against her stare", 1, true) then
            add("B2", "bracelet_in_lair")
            local sentence = string.match(e.text, "([^.]*bracelet[^.]*)") or e.text
            if not given_to then
                fail("B2", tag(T, e.w) .. ": '" .. sentence .. "', and nobody saw Flitwidget hand it over")
            elseif hero_in(sentence) and hero_in(sentence) ~= given_to then     -- (a new hero in a fallen one's seat: not the four)
                fail("B2", tag(T, e.w) .. ": " .. given_to .. " was given the bracelet, and '" .. sentence .. "'")
            end
        end
    end
end

-- Promises kept: the vorpal sword the DM said Telpur stocks is on his shelf; the red switch they saved
-- for her is flipped in her lair; first pick goes to the friend it was promised to; what was pocketed
-- is named and comes back by the end; nobody counts loot there isn't.
local function promises_kept(T)
    local yes, shown, saved, switch, mech_in_lair, lair_fight = false, false, false, false, false, false
    local promised, kept, pockets, returned, thanks = 0, 0, {}, {}, false
    for _, e in ipairs(T) do
        if e.kind == "line" then
            local t = e.text
            if string.find(t, "the vorpal sword. The tag says forty Francs", 1, true) then
                shown = true
            end
            if string.find(t, "They saved the red switch", 1, true) or string.find(t, "snaps the panel shut. For the Gorgon", 1, true) then
                saved = true
            end
            if string.find(t, "red switch, saved for her", 1, true) or string.find(t, "flips", 1, true) and string.find(t, "red switch", 1, true)
                or string.find(t, "The red switch goes over", 1, true) then
                switch = true
                add("B2", "switch_flipped")
            end
            if e.room == "lair" and string.find(t, "clanks up the stairs behind them", 1, true) then
                mech_in_lair = true
            end
            if string.find(t, "have first pick of whatever the party finds next", 1, true) then
                promised = promised + 1
                add("B2", "first_pick_promised")
            elseif string.find(t, "first pick", 1, true) or string.find(t, "First pick", 1, true) then
                if not HERO[e.who] then
                    kept = kept + 1
                    add("B2", "first_pick_kept")
                end
            end
            local what = string.match(t, "^%a+ pockets (.-)%. 'Sorry, it's just what")
            if what then
                table.insert(pockets, what)
                add("B2", "pocketed_named")
            elseif string.find(t, "pockets something small", 1, true) then
                fail("B2", tag(T, e.w) .. ": '" .. t .. "' never says what")
            end
            for _, p in ipairs(pockets) do
                if not returned[p] and string.find(t, p, 1, true) and (string.find(t, "back", 1, true) or string.find(t, "across the counter", 1, true)) then
                    returned[p] = true
                    add("B2", "pocketed_back")
                end
            end
            if string.find(t, "counts the loot alone", 1, true) then
                fail("B2", tag(T, e.w) .. ": '" .. t .. "', with no loot to count")
            end
        elseif e.kind == "chat" and string.find(e.text or "", "", 1, true) then
            -- (nothing)
        elseif e.kind == "scene" and string.find(e.text or "", "gift shop", 1, true) and T.c.adv.ending and e.w == #T.reps then
            thanks = true
        elseif e.kind == "battle" and e.phase == "start" and e.room == "lair" then
            lair_fight = true
        end
    end
    local answered = T.c.adv.answered or {}
    if answered.vorpal == "yes" then
        add("B2", "vorpal_yes")
        if T.c.adv.done and T.c.adv.done.gift_shop and not shown and (T.c.adv.flags or {}).vorpal_price then
            -- (The yes came before a visit to the shop: it's on the shelf when they're there.)
            local after = false
            for _, e in ipairs(T) do
                -- (A visit to the shop itself, a week after the yes could have come: the room, not the thanks.)
                after = after or (e.kind == "scene" and e.room == "gift_shop" and e.w >= (T.vorpal_week or 99) and true)
            end
            if after then
                fail("B2", tag(T) .. ": the DM said Telpur stocks a vorpal sword, and it was never on his shelf")
            end
        end
    end
    if saved and mech_in_lair and lair_fight and not switch then
        fail("B2", tag(T) .. ": they saved the Mech's red switch for her, and it was never flipped in her lair")
    end
    if thanks and kept < promised then
        fail("B2", tag(T) .. ": first pick promised " .. promised .. " times, kept " .. kept)
    end
    for _, p in ipairs(pockets) do
        if thanks and not returned[p] then
            fail("B2", tag(T) .. ": " .. p .. " was pocketed, and never came back")
        end
    end
end

-- B3. Money adds up -------------------------------------------------------------------------------

-- The pool is what the log says went in and out tonight, every Franc that went in was heard going in,
-- and a Franc the chain credits to a hero was heard going to that hero.
-- (A line that says a Franc turned up: any said line with a Franc in it but the ones about spending
-- them, prices and the pool.)
local FRANC_NOT = { "Spend", "spend", "pools its", "One Franc per", "price", "Francs)" }
local function franc_line(text)
    if not string.find(text, "Franc", 1, true) then
        return false
    end
    for _, w in ipairs(FRANC_NOT) do
        if string.find(text, w, 1, true) then
            return false
        end
    end
    return true
end
local function money_heard(T)
    local events = require "game.model.events"
    local heard = {}
    for _, e in ipairs(T) do
        if e.kind == "line" and not HERO[e.who] and franc_line(e.text) then
            heard[e.w] = heard[e.w] or {}
            table.insert(heard[e.w], e.text)
        end
    end
    for w, pl in pairs(T.pool or {}) do
        if pl.after then
            local inn, out, finds = 0, 0, 0
            for _, ev in ipairs(events.find(T.c, { session = pl.week })) do
                if ev.kind == "find" and ev.thing == "francs" and not ev.between then
                    inn, finds = inn + (ev.n or 1), finds + 1
                elseif ev.kind == "spend" and not ev.between then
                    out = out + (ev.n or 0)
                end
            end
            add("B3", "nights")
            if pl.after - pl.before ~= inn - out then
                fail("B3", tag(T, w) .. ": the pool went from " .. pl.before .. " to " .. pl.after .. ", and the log has " .. inn
                    .. " in and " .. out .. " out")
            end
            if #(heard[w] or {}) < finds then
                fail("B3", tag(T, w) .. ": " .. finds .. " Franc finds in the log, and the table heard " .. #(heard[w] or {}))
            else
                add("B3", "finds_heard", finds)
            end
        end
    end
    for _, e in ipairs(T) do
        if e.kind == "chain" then
            for h in string.gmatch(e.text, "(%a+) found a Flitwidget Franc") do
                if KEY[h] then
                    local ok = false
                    for _, l in ipairs(heard[e.w] or {}) do
                        ok = ok or (string.find(l, h, 1, true) ~= nil)
                    end
                    if not ok then
                        fail("B3", tag(T, e.w) .. ": the chain says '" .. e.text .. "', and nobody heard a Franc go to " .. h)
                    end
                end
            end
        end
    end
end

-- The reward is one number: Flitwidget says it before anyone calls it low, the haggle starts from it
-- and moves it, and "They earn" pays it.
local NUM = { five = 5, ten = 10, fifteen = 15, twenty = 20, ["twenty-five"] = 25, thirty = 30, ["thirty-five"] = 35, forty = 40,
              ["forty-five"] = 45, fifty = 50, ["fifty-five"] = 55, sixty = 60 }
local function gold_in(text)
    local low = string.lower(text)
    local n = string.match(low, "(%d+) gold each") or string.match(low, "makes it (%d+) each")
    if n then
        return tonumber(n)
    end
    for w in string.gmatch(low, "([%a%-]+) gold each") do
        if NUM[w] then
            return NUM[w]
        end
    end
    for w in string.gmatch(low, "makes it ([%a%-]+) each") do
        if NUM[w] then
            return NUM[w]
        end
    end
    for w in string.gmatch(low, "\"([%a%-]+) each%.") do
        if NUM[w] then
            return NUM[w]
        end
    end
    for w in string.gmatch(low, "([%a%-]+) each[%.%?]") do
        if NUM[w] then
            return NUM[w]
        end
    end
    return nil
end
local function reward_number(T)
    -- (The report's "Picked up" is the same number the table heard, in real gold, with why it moved.)
    for w, night in pairs(T.nights) do
        for _, g in ipairs(night.mus and night.mus.got or {}) do
            local n = tonumber(string.match(g, "^(%d+) gold each"))
            if n then
                add("B3", "report_rewards")
                local paid = adventure.reward_gold(T.c)
                if n ~= paid then
                    fail("B3", tag(T, w) .. ": the report says '" .. g .. "', and Flitwidget pays " .. paid)
                end
                if not string.find(g, "not Francs", 1, true) then
                    fail("B3", tag(T, w) .. ": the report says '" .. g .. "', and never says it's gold, not Francs")
                end
                if T.c.adv.ending == "escape" and not string.find(g, "half", 1, true) then
                    fail("B3", tag(T, w) .. ": she got away, and the report says '" .. g .. "' without the half")
                end
            end
        end
    end
    local cur
    for _, e in ipairs(T) do
        local n = e.kind == "line" and gold_in(e.text)
        if n then
            local low = string.find(e.text, "seems low", 1, true) or string.find(e.text, "She's out of your museum", 1, true)
            if low then
                add("B3", "reward_haggled")
                if not cur then
                    fail("B3", tag(T, e.w) .. ": '" .. e.text .. "', before anyone said what the reward was")
                elseif n ~= cur then
                    fail("B3", tag(T, e.w) .. ": the reward was " .. cur .. " each, and '" .. e.text .. "'")
                end
            elseif string.find(e.text, "They earn", 1, true) then
                add("B3", "reward_paid")
                if cur and n ~= cur then
                    fail("B3", tag(T, e.w) .. ": the reward was " .. cur .. " each, and '" .. e.text .. "'")
                end
            elseif string.find(e.text, "makes it", 1, true) then
                if cur and n ~= cur + 10 and n ~= cur + 5 then
                    fail("B3", tag(T, e.w) .. ": talked up from " .. cur .. ", and '" .. e.text .. "'")
                end
                cur = n
            else
                if cur and string.find(e.text, "And a biscuit", 1, true) and n ~= cur then
                    fail("B3", tag(T, e.w) .. ": the reward was " .. cur .. " each, and '" .. e.text .. "'")
                end
                cur = n
            end
        end
    end
end

-- What Flitwidget says they broke, they broke: a garden only if it burned, a guardian only if it was smashed.
local function breakages_true(T)
    local marks = {}
    for _, id in ipairs(T.c.adv.mark_list or {}) do
        marks[id] = true
    end
    -- (A mark that came off her card after the lair, the scarabs killed, still happened: the log has it.)
    for _, ev in ipairs(require("game.model.events").find(T.c, { kind = "mark" })) do
        if ev.thing then
            marks[ev.thing] = true
        end
    end
    for _, e in ipairs(T) do
        if e.kind == "line" and (e.who == "Flitwidget" or string.find(e.who, "Flitwidget", 1, true)) then
            local low = string.lower(e.text)
            if (string.find(low, "garden", 1, true) or string.find(low, "set fire", 1, true)) and not marks.garden_burned then
                fail("B3", tag(T, e.w) .. ": '" .. e.text .. "', and the garden never burned")
            end
            if (string.find(low, "guardian", 1, true) or string.find(low, "bone construct", 1, true)) and not marks.scarabs then
                fail("B3", tag(T, e.w) .. ": '" .. e.text .. "', and nobody smashed the guardian")
            end
            if string.find(low, "breakages", 1, true) or string.find(low, "you also", 1, true) or string.find(low, "minus", 1, true) then
                add("B3", "breakages_said")
            end
        end
    end
end

-- B4. Memory and knowledge are true -------------------------------------------------------------

-- What the friends say they know, they heard: the Witness and the sunken city (the notebook read out),
-- the jugs (the ritual worked), the lady by the mountains (her painting was the one shown), the sign
-- (only "thinking about it" when they didn't use the water).
local FRIENDS = { mara = true, dev = true, jess = true, sam = true, Mara = true, Dev = true, Jess = true, Sam = true }
local function knowledge_true(T)
    local heard = ""
    local doused = false
    for _, e in ipairs(T) do
        local friend = (e.kind == "line" and FRIENDS[e.who]) or e.kind == "chat"
        local text = e.text or ""
        if e.kind == "line" and not FRIENDS[e.who] then
            heard = heard .. "\n" .. text
            doused = doused or string.find(text, "Helmets full of pond water", 1, true) ~= nil
        elseif friend then
            local low = string.lower(text)
            local function need(word, what, said)
                if string.find(low, word, 1, true) then
                    add("B4", "callbacks_checked")
                    if not string.find(heard, said, 1, true) then
                        fail("B4", tag(T, e.w) .. ": '" .. text .. "', and the table never heard " .. what)
                    end
                end
            end
            need("witness", "of the Witness", "Witness")
            need("sunken city", "of a sunken city", "city under the sea")
            need("city under the sea", "of a city under the sea", "city under the sea")
            need("gallons", "the ritual's measures", "Five gallons")
            need("lady by the mountains", "the lady's painting", "a lady by an icy mountain road")
            if string.find(low, "the sign said use water", 1, true) and doused then
                fail("B4", tag(T, e.w) .. ": '" .. text .. "', and they did use the water")
            end
        end
    end
end

-- What the museum's people remember is what happened: Flitwidget's draught gone only when it went (and
-- said when it did), robbed and not "tried", "his job" not as if stolen, "They'd been warned" only when
-- they were, Flitwidget not heard in her lair, and Session Zero's agreements heard before they're quoted.
local function memory_true(T)
    local events = require "game.model.events"
    local c = T.c
    local got = events.any(c, { kind = "steal", whom = "mus_flitwidget", outcome = "got" })
    local robbed = c.adv.marks.robbed or events.any(c, { kind = "mark", thing = "robbed" })
    local draught_said, thanks = false, false
    local s0_heard, alone_cost = false, false
    for _, e in ipairs(T) do
        local text = e.text or ""
        if e.kind == "line" or e.kind == "card" then
            if string.find(text, "My draught isn't", 1, true) or string.find(text, "I know where it went", 1, true)
                or string.find(text, "whoever has my draught", 1, true) or string.find(text, "draught's gone missing", 1, true)
                or string.find(text, "It's gone missing", 1, true) or string.find(text, "lost my healing draught", 1, true)
                or string.find(text, "my healing draught? It was in this pocket", 1, true) then
                draught_said = true
                add("B4", "draught_remembered")
                if not got then
                    fail("B4", tag(T, e.w) .. ": '" .. text .. "', and his draught never went (he caught them, or nobody tried)")
                end
            end
            if robbed and (string.find(text, "tried to rob", 1, true) or string.find(text, "tried the gnome's", 1, true)) then
                fail("B4", tag(T, e.w) .. ": they emptied the donation box, and '" .. text .. "'")
            end
            if string.find(text, "took his job", 1, true) then
                fail("B4", tag(T, e.w) .. ": '" .. text .. "' reads as if they stole it")
            end
            if e.kind == "line" and e.room == "lair" and string.find(e.who or "", "Flitwidget", 1, true) then
                fail("B4", tag(T, e.w) .. ": Flitwidget is heard in her lair: '" .. text .. "'")
            end
            if e.kind == "line" and string.find(text, "You nod: \"", 1, true) and e.w == 1 then
                s0_heard = true
            end
            if string.find(text, "at Session Zero.", 1, true) and (string.find(text, "as you agreed with", 1, true)
                or string.find(text, "as you promised", 1, true)) then
                add("B4", "session_zero_reminders")
                if not s0_heard then
                    fail("B4", tag(T, e.w) .. ": '" .. text .. "', and nobody said it at Session Zero")
                end
            end
            if string.find(text, "At the top of the stairs, bronze eyes", 1, true) then
                alone_cost = true
            elseif alone_cost and e.kind == "line" then
                alone_cost = false
                if string.find(text, "They'd been warned", 1, true) and not (c.adv.warned or {}).mus_alone then
                    fail("B4", tag(T, e.w) .. ": 'They'd been warned', and nobody warned them about the stairs")
                end
            end
        end
        if e.kind == "scene" and e.room == "thanks" then
            thanks = true
        end
    end
    if got and thanks and not draught_said then
        local ev = events.last(c, { kind = "steal", whom = "mus_flitwidget", outcome = "got" })
        if ev then
            fail("B4", tag(T) .. ": Pip lifted Flitwidget's draught, and at his thanks he never misses it")
        end
    end
end

-- Targeted cases ---------------------------------------------------------------------------------

local function fresh_campaign(seed)
    adventure.enter()
    local c = campaign_mod.new(seed or 5)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    return c
end

-- A live night stopped at its first room (the street), and a driver that collects what it says.
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
local function drive(fn)
    local out = {}
    local co = coroutine.create(fn)
    local answer
    while coroutine.status(co) ~= "dead" do
        local ok, e = coroutine.resume(co, answer)
        if not ok then
            error(e)
        end
        answer = nil
        if e then
            table.insert(out, e)
            if e.kind == "decision" or e.kind == "ruling" then
                answer = 1
            elseif e.kind == "roll_where" then
                answer = "open"
            elseif e.kind == "roll" then
                answer = 10
            end
        end
    end
    return out
end
local function said(out, pat)
    for _, e in ipairs(out) do
        if e.text and string.find(e.text, pat, 1, true) then
            return e
        end
    end
end

-- B2: Telpur knows his own stock when he sees it in a hero's hands, says so, and knows it from then on;
-- not in the same room the night it went (the case a run can't be counted on: Telpur along for a fight).
case("B2", function()
    CUR = "telpur_case"
    local events = require "game.model.events"
    local items = require "game.model.items"
    local people = require "game.model.people"
    local museum_night = require "game.model.museum_night"
    local c, night = street_night(21)
    local steal = events.add(c, { kind = "steal", who = "jess", whom = "mus_telpur", thing = "arrows_lifted", where = "gift_shop",
                                  outcome = "got", seen = {}, session = (c.week or 1) - 1 })
    events.set_cause(c, steal)
    items.give(c, "arrows_lifted", "jess", "stolen", { id = "mus_telpur", name = "Telpur" })
    events.set_cause(c, nil)
    if people.knows_of(c, "mus_telpur", "steal") then
        fail("B2", "Telpur knows of a theft nobody saw")
    end
    local out = drive(function()
        museum_night.owner_sees(night, "mus_telpur", night.scene)
    end)
    local line = nil
    for _, e in ipairs(out) do
        if e.kind == "npc" and e.cast == "mus_telpur" then
            line = e.text
        end
    end
    if not line or not string.find(line, "Pip", 1, true) then
        fail("B2", "Telpur sees his quiver on Pip and says " .. tostring(line))
    elseif not people.knows_of(c, "mus_telpur", "steal") then
        fail("B2", "Telpur saw his quiver, and doesn't know it was stolen")
    else
        add("B2", "telpur_spots_case")
    end
    local again = drive(function()
        museum_night.owner_sees(night, "mus_telpur", night.scene)
    end)
    if #again > 0 then
        fail("B2", "Telpur notices the same quiver twice")
    end
end)

-- B2: Flitwidget's bracelet goes to the hero he likes best (read from the log), and first pick goes
-- to the friend it was promised to, out loud.
case("B2", function()
    CUR = "gifts_case"
    local events = require "game.model.events"
    local items = require "game.model.items"
    local museum_night = require "game.model.museum_night"
    local c, night = street_night(22)
    for _ = 1, 3 do
        events.add(c, { kind = "help", who = "sam", whom = "mus_flitwidget", seen = { mus_flitwidget = true }, where = "street" })
    end
    local it = items.give(c, "bracelet", nil, "given")
    if not (it and it.holder == "sam") then
        fail("B2", "Flitwidget likes Oswin best, and the bracelet went to " .. tostring(it and it.holder))
    else
        add("B2", "bracelet_to_fondest")
    end
    c.adv.first_pick = { by = "dev", to = "jess", week = c.week }
    local got
    local out = drive(function()
        got = museum_night.first_pick(night)
    end)
    if not (got and got.key == "jess" and said(out, "Pip") and c.adv.first_pick == nil) then
        fail("B2", "first pick promised to Pip went to " .. tostring(got and got.key))
    else
        add("B2", "first_pick_case")
    end
end)

-- B4: Flitwidget's draught: missed when it went (he knows who, or only that it's gone), never when he
-- caught them at it; and Session Zero's lines and veils are said at the table.
case("B4", function()
    CUR = "draught_case"
    local events = require "game.model.events"
    local people = require "game.model.people"
    local intros = require "game.model.intros"
    local c, night = street_night(23)
    events.add(c, { kind = "steal", who = "jess", whom = "mus_flitwidget", thing = "potion_healing", outcome = "caught",
                    seen = { mus_flitwidget = true }, where = "street" })
    c.adv.ending = "bargain"
    local line = people.line(night, "mus_flitwidget", "thanks", night.players[3])
    if line and string.find(line, "draught", 1, true) then
        fail("B4", "Flitwidget caught Pip and got his draught back, and says '" .. line .. "'")
    else
        add("B4", "caught_not_missed")
    end
    events.add(c, { kind = "steal", who = "jess", whom = "mus_flitwidget", thing = "potion_healing", outcome = "got", seen = {},
                    where = "garden" })
    line = people.line(night, "mus_flitwidget", "thanks")
    if not (line and string.find(line, "draught", 1, true)) then
        fail("B4", "his draught really went, and his thanks says '" .. tostring(line) .. "'")
    else
        add("B4", "draught_missed")
    end
    CUR = "session_zero_case"
    local out = drive(function()
        intros.asks(night, function(l) return l[1] end)
    end)
    local asked = 0
    for _, e in ipairs(out) do
        if e.kind == "say" and (e.who == "mara" or e.who == "sam") then
            asked = asked + 1
        end
    end
    if asked < 2 or not said(out, "You nod") then
        fail("B4", "Session Zero's lines and veils weren't said at the table (" .. asked .. " asks)")
    else
        add("B4", "session_zero_said")
    end
end)

-- B3 (the engine review, item 16): the dice shown are the dice won. A friend who says in the chat
-- they bought new dice shows off those that week; the report's NEW DICE is this week's box.
case("B3", function()
    CUR = "dice"
    local dice_sets = require "game.model.dice_sets"
    local loot = require "game.model.loot"
    local c = fresh_campaign(11)
    c.week = 3
    local d = dice_sets.get(c)
    d.players.sam = "jade"
    d.bought = { key = "sam", set = "jade", week = 3 }
    local night = { campaign = c, players = c.players }
    for _, p in ipairs(c.players) do
        p.present = true
        p.commitment, p.last_tier = 99, "loved"
    end
    local q, sid = dice_sets.show_off(night)
    if not (q and q.key == "sam" and sid == "jade") then
        fail("B3", "Sam bought jade dice in the chat, and the night shows off " .. tostring(q and q.key) .. "'s " .. tostring(sid))
    else
        add("B3", "dice_bought_shown")
    end
    local bag = loot.bag(c)
    bag[1], bag[2], bag[3] = "rose_quartz", "ruby", "jade"
    d.opened = { set = "ruby", week = 3 }
    local i, new = loot.newest_index(c)
    if not (i == 2 and new) then
        fail("B3", "this week's box was the second set in the bag, and the report shows set " .. tostring(i))
    else
        add("B3", "dice_newest_shown")
    end
end)

-- B3: the reward in words and the report's reasons (the board's number, moved only for a reason said).
case("B3", function()
    CUR = "reward_words"
    local c = fresh_campaign(12)
    local st = c.adv
    st.gold, st.gold_docked, st.ending = 20, 10, nil
    local v = adventure.reward_vars(c)
    if v.gold_word ~= "twenty" or v.gold_up_word ~= "thirty" then
        fail("B3", "docked to twenty: the words are " .. tostring(v.gold_word) .. " and " .. tostring(v.gold_up_word))
    end
    adventure.apply(c, { gold_up = 10 })
    if st.gold ~= 30 then
        fail("B3", "talked up ten from twenty, and the reward is " .. tostring(st.gold))
    end
    st.ending = "escape"
    local paid = adventure.reward_gold(c)
    local why = adventure.reward_why(c)
    if paid ~= 15 or not string.find(why, "half of thirty", 1, true) or not string.find(why, "not Francs", 1, true) then
        fail("B3", "an escape after a dock and a haggle pays " .. tostring(paid) .. " (" .. tostring(why) .. ")")
    else
        add("B3", "reward_reasons")
    end
end)

-- Run everything ---------------------------------------------------------------------------------

-- (name, scan): a fail is counted under its scan's name, so the line per finding says which part failed.
local SCANS = { { "lock", lock_owner }, { "voice", voice_owner }, { "praise", praise_owner }, { "paint", paint_owner },
                { "notes", notes_owner }, { "asker", asker_owner },
                { "stock", stock_owned }, { "bracelet", bracelet_given }, { "promises", promises_kept }, { "pool", money_heard }, { "reward", reward_number },
                { "breakages", breakages_true }, { "knowledge", knowledge_true }, { "memory", memory_true } }
local t0 = os.clock()
local runs = 0
for _, style in ipairs(STYLES) do
    for seed = FIRST, LAST do
        local ok, T = pcall(play, seed, style)
        -- (DUMP=1: the transcript as the sim's log prints it, to compare with `lua tools/sim/museum.lua
        -- <seed> <style> log`.)
        if ok and os.getenv("DUMP") then
            for _, e in ipairs(T) do
                if e.kind == "line" then
                    print(string.format("  [%s] %s", e.who, e.text))
                elseif e.kind == "card" then
                    print("  >> " .. e.text)
                end
            end
        end
        if not ok then
            fail("B1", "seed " .. seed .. " " .. style .. ": error " .. tostring(T))
        else
            runs = runs + 1
            for _, sc in ipairs(SCANS) do
                CUR = sc[1]
                local ok2, err = pcall(sc[2], T)
                if not ok2 then
                    fail("B1", tag(T) .. ": scan error " .. tostring(err))
                end
            end
        end
    end
end

run_cases()

local total = 0
print(string.format("round three, batch B: %d prologues (seeds %d to %d, three DMs) in %.0fs", runs, FIRST, LAST, os.clock() - t0))
for _, item in ipairs(ITEMS) do
    local f = fails[item]
    local bits = {}
    for k, n in util.sorted_pairs(E[item] or {}) do
        table.insert(bits, k .. " " .. n)
    end
    local by = {}
    for k, n in util.sorted_pairs(f and f.by or {}) do
        table.insert(by, k .. " " .. n)
    end
    print(string.format("%s %s: %s%s", item, NAMES[item], #bits > 0 and table.concat(bits, ", ") or "-",
        f and ("  FAIL " .. f.n .. (#by > 0 and (" (" .. table.concat(by, ", ") .. ")") or "")) or ""))
    for _, m in ipairs(f or {}) do
        print("   FAIL " .. m)
        total = total + 1
    end
end
os.exit(total == 0 and 0 or 1)
