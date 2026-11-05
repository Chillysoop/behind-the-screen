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
    local landed, last_decides = {}, nil
    for _, e in ipairs(T) do
        if e.kind == "battle" and e.phase == "start" then
            landed = {}
        elseif e.kind == "scene" then
            last_decides = nil
        elseif e.kind == "turn" and e.who then
            for i, st in ipairs(e.steps) do
                if st.kind == "attack" and st.hit and st.id == e.who then
                    landed[e.who] = true
                elseif st.kind == "spell" and st.id == e.who then
                    local nx = e.steps[i + 1]
                    if nx and nx.kind == "damage" and nx.src == e.who then
                        landed[e.who] = true
                    end
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
            if h and (string.find(e.text, "pages", 1, true)) and (string.find(e.text, "gathers", 1, true)
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
                    local word = what == "Lecturer's notes" and "pages" or "notebook"
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

-- Targeted cases ---------------------------------------------------------------------------------

-- Run everything ---------------------------------------------------------------------------------

-- (name, scan): a fail is counted under its scan's name, so the line per finding says which part failed.
local SCANS = { { "lock", lock_owner }, { "voice", voice_owner }, { "praise", praise_owner }, { "paint", paint_owner },
                { "notes", notes_owner }, { "asker", asker_owner } }
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
