-- Roadmap phase 1, "Polish the words": the round-two playtest findings Conner said yes to, each kept
-- fixed. Whole prologues headless over several seeds and three kinds of DM, watching what the table
-- hears, plus targeted unit cases. Run from the project root:
--     lua tools/tests/roadmap_words_check.lua [runs per style]
-- Prints one line per item: what was seen, and FAIL lines where play contradicts the fix.
--
-- Items: F2 near misses, F6 F7 F8 F26 small moments, F9 the offices (and the shop, the paintings),
-- F15 Flitwidget's thanks, F16 Euryale in the room, F17 location slips, F21 behind your screen,
-- F22 looking round, F24 R2 R3 repeats and cool-downs, F25 chatter that fits.

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"
local util = require "game.model.util"

local RUNS = tonumber(arg[1]) or 4
local STYLES = { "careful", "random", "careless" }
local ITEMS = { "F2", "F6", "F7", "F8", "F9", "F15", "F16", "F17", "F21", "F22", "F24", "F25", "F26", "R2", "R3" }
local NAMES = {
    F2 = "near misses", F6 = "small moments: reactions", F7 = "small moments: the natural 1",
    F8 = "small moments: danger first", F9 = "the offices, shop, paintings", F15 = "Flitwidget's thanks",
    F16 = "Euryale in the room", F17 = "location slips", F21 = "behind your screen", F22 = "looking round",
    F24 = "lines every week", F25 = "chatter that fits", F26 = "small moments: variety", R2 = "catchphrase cool-downs",
    R3 = "variants for weekly lines", run = "whole prologues",
}

local fails = {}
local function fail(item, msg)
    fails[item] = fails[item] or { n = 0 }
    if #fails[item] < 6 then
        table.insert(fails[item], msg)
    end
    fails[item].n = fails[item].n + 1
end
local E = setmetatable({}, { __index = function(t, k)
    local v = {}
    rawset(t, k, v)
    return v
end })
local function add(item, key, n)
    E[item][key] = (E[item][key] or 0) + (n or 1)
end
local function has(s, pat)
    return type(s) == "string" and string.find(s, pat, 1, true) ~= nil
end

-- Playing ------------------------------------------------------------------------------------------

-- One prologue: every event the table sees, in order, with where it happened.
-- run.log = { { k, style, text, who, name, room, week, scene, card, opts, ... } }
local function play(seed, style, opts)
    opts = opts or {}
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    local s0 = social.default_choices()
    s0.rules = s0.rules or {}
    s0.rules.harsh = ({ careful = "fair", random = "gentle", careless = "brutal" })[style]
    if opts.chatter then
        s0.rules.chatter = opts.chatter
    end
    c:session_zero(s0)
    local rng = require("game.model.rng").new(seed * 31 + #style)
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = adventure.data.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    local run = { seed = seed, style = style, log = {}, c = c, chats = {} }
    for w = 1, adventure.data.MAX_WEEKS do
        local prep = c:start_week()
        for _, m in ipairs(c.chat or {}) do
            table.insert(run.chats, { week = w, who = m.key or m.who, text = m.text })
        end
        for _, m in ipairs(c.chat or {}) do
            if m.ask and not m.answered then
                museum_week.answer_chat(c, m, ({ careful = 1, random = rng:int(1, 3), careless = 3 })[style])
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
                adventure.answer_favor(c, pr.id, rng:int(1, 2), rng:int(1, 2))
            end
        end
        if style ~= "careless" then
            museum_week.prep_greedy(prep)
            for _, id in ipairs(prep.museum.ahead) do
                for _, kid in ipairs(adventure.data.rooms[id].knobs or {}) do
                    local k = adventure.data.knobs[kid]
                    museum_week.set_knob(prep, kid, k.pick_hero and "mara" or (rng:chance(0.6) or nil))
                end
            end
        end
        if prep.museum.boss then
            c.adv.boss = { opener = rng:chance(0.7) and "talk" or "ambush", style = rng:chance(0.6) and "yields" or "last" }
        end
        local night = c:start_night()
        run.night = night
        local ev = night:advance()
        local guard = 0
        while ev.kind ~= "done" and guard < 6000 do
            guard = guard + 1
            local sc = night.scene
            local rec = { k = ev.kind, style = ev.style, text = ev.text, who = ev.who, name = ev.name, week = w,
                          room = sc and sc.room, scene = sc and sc.index, fought = sc and sc.fought or nil,
                          epilogue = sc and sc.epilogue or nil, boss = sc and sc.boss or nil, ev = ev }
            table.insert(run.log, rec)
            local answer
            if ev.kind == "decision" then
                local o = ev.card.options
                rec.card = ev.card.id
                rec.title = ev.card.title
                rec.ctext = ev.card.text
                rec.opts = o
                local pick = (style == "careful") and 1 or rng:int(1, #o)
                if ev.card.id == "tl_crit" then
                    pick = #o           -- (the improvised option, to see what it does)
                end
                if opts.pick then
                    pick = opts.pick(ev, pick, rng) or pick
                end
                if o[pick] and o[pick].disabled then
                    pick = 1
                end
                rec.pick = pick
                answer = pick
            elseif ev.kind == "thought" then
                require("game.model.thoughts").bot_play(night, ev, style, rng)
            elseif ev.kind == "ruling" then
                answer = opts.ruling and opts.ruling(ev, rng) or 1
                rec.tier = ev.tier
            elseif ev.kind == "improv" then
                answer = { 1 }
            elseif ev.kind == "roll_where" then
                answer = (style == "careless") and "hidden" or "open"
            elseif ev.kind == "roll" then
                answer = opts.roll and opts.roll(ev, rng) or rng:d20()
            end
            ev = night:advance(answer)
        end
        if guard >= 6000 then
            fail("run", string.format("seed %d %s week %d: the night never ended", seed, style, w))
        end
        c:finish_night()
        c:level_up()
        if adventure.over(c) then
            break
        end
    end
    add("run", "prologues")
    -- DUMP=seed:style prints the run's log, to read round a failure.
    if os.getenv("DUMP") == (seed .. ":" .. style) then
        for i, r in ipairs(run.log) do
            if r.text or r.k == "tiny_roll" or r.k == "decision" or r.k == "scene" then
                print(string.format("%4d w%d %-10s %-9s %-8s %s", i, r.week, tostring(r.room), r.k, tostring(r.who or r.style or r.name or ""),
                    r.k == "tiny_roll" and (r.ev.who .. " " .. r.ev.total) or (r.k == "decision" and (r.card .. ": " .. tostring(r.title)) or tostring(r.text))))
            end
        end
    end
    return run
end

local function where(run, r)
    return string.format("seed %d %s week %d (%s)", run.seed, run.style, r.week or 0, tostring(r.room))
end

-- The items, over whole prologues ---------------------------------------------------------------------

local CHECKS = {}

-- F2: a near miss ruled "No, but..." is still a miss: no Franc promised or paid, no cheering, words
-- that fit any room, and the +1 it promises shows on that hero's next roll.
function CHECKS.F2(run)
    local log = run.log
    local owed = {}
    for i, r in ipairs(log) do
        if r.k == "ruling" then
            local o1 = r.ev.options and r.ev.options[1]
            if r.ev.tier == "near" then
                add("F2", "near_misses")
                if o1 and has(o1.label, "Franc") then
                    fail("F2", where(run, r) .. ": the near-miss ruling promises a Franc: " .. o1.label)
                end
                if r.ev.success == false then
                    owed[r.ev.actor or "?"] = true
                    for j = i + 1, math.min(#log, i + 14) do
                        local q = log[j]
                        if q.k == "ruling" or q.k == "decision" or q.k == "scene" then
                            break
                        end
                        if q.k == "say" and type(q.ev.line) == "string" and string.find(q.ev.line, "^ruling_good") then
                            fail("F2", where(run, q) .. ": cheered after a miss: " .. q.text)
                        elseif q.k == "say" and type(q.ev.line) == "string" and string.find(q.ev.line, "^ruling_rueful") then
                            add("F2", "rueful_after_a_miss")
                        end
                        if q.k == "narrate" and has(q.text, "Franc pops") then
                            fail("F2", where(run, q) .. ": a Franc for a miss: " .. q.text)
                        end
                    end
                end
            end
        elseif r.k == "narrate" and has(r.text, "Not quite") and has(r.text, "on the way down") then
            fail("F2", where(run, r) .. ": " .. r.text)
        elseif r.k == "roll_where" and r.ev.actor and owed[r.ev.actor] then
            owed[r.ev.actor] = nil
            if has(r.ev.text, "they learned from the last miss") then
                add("F2", "learned_plus_one_shown")
            end
        end
    end
end

-- Small moments (F6, F8, F26) -----------------------------------------------------------------------

local TL = adventure.data.table_life or require "game.data.museum.table_life"
local ROOM_ORDER = {}
local CURIO_BY_ASK, DULL, ANSWER_LEVEL = {}, {}, {}
for room, r in pairs(TL.rooms or {}) do
    for _, b in ipairs(r.curios or {}) do
        CURIO_BY_ASK[util.sentence_case(b.ask)] = { b = b, room = room }
        for _, lvl in ipairs({ "dull", "detail", "lore" }) do
            if b[lvl] then
                ANSWER_LEVEL[b.id .. "|" .. b[lvl]] = lvl
            end
        end
        DULL[b.dull] = true
    end
    for _, q in ipairs(r.npc_questions or {}) do
        CURIO_BY_ASK[util.sentence_case(q.ask)] = CURIO_BY_ASK[util.sentence_case(q.ask)] or { question = true }
    end
end
local HINTS = {}
for _, id in ipairs(adventure.data.companions and adventure.data.companions.order or {}) do
    local e = adventure.data.companions[id]
    for _, t in ipairs(e.lines and e.lines.hint or {}) do
        HINTS[t] = true
    end
end
local DANGER_CARDS = {}
for _, m in ipairs(adventure.data.moments or {}) do
    if m.danger then
        DANGER_CARDS[m.id] = true
    end
end
-- The board places' lines, by room: what looking round says when someone walks over to a place.
local PLACE_LINE = {}
do
    local lib = require "game.data.map_library"
    for _, b in pairs(lib.boards) do
        for _, pl in ipairs(b.places or {}) do
            if b.room then
                PLACE_LINE[b.room .. "|" .. pl.line] = pl.id
            end
        end
    end
end

-- Each small moment in a run: { i (index in the log), b, room, who, level, react (text or nil), scene }.
local function small_moments(run)
    local out = {}
    local log = run.log
    for i, r in ipairs(log) do
        if r.k == "tiny_roll" and i > 1 and log[i - 1].k == "say" then
            local hit = CURIO_BY_ASK[log[i - 1].text or ""]
            if hit and hit.b then
                local m = { i = i, b = hit.b, room = r.room, who = r.ev.who, scene = r.scene, week = r.week }
                for j = i + 1, math.min(#log, i + 6) do
                    local q = log[j]
                    if q.k == "narrate" and q.style == "dm" and not m.level then
                        m.level = ANSWER_LEVEL[hit.b.id .. "|" .. (q.text or "")]
                        m.answer_at = j
                    elseif q.k == "decision" and q.card == "tl_crit" then
                        m.crit = true
                        break
                    elseif q.k == "say" and m.answer_at and CURIO_BY_ASK[q.text or ""] then
                        break           -- (the next friend's poke, not a reaction)
                    elseif q.k == "say" and m.answer_at and q.ev.who ~= m.who then
                        m.react = q.text
                        break
                    elseif q.k == "tiny_roll" or (q.k == "narrate" and m.answer_at) then
                        break
                    elseif q.k == "scene_end" or q.k == "scene" then
                        break           -- (the room's over: its end card is up, and what's said next isn't about this)
                    end
                end
                table.insert(out, m)
            end
        end
    end
    return out
end

-- F6: the friend's reaction follows the answer you gave.
function CHECKS.F6(run)
    local tlm = require "game.model.table_life"
    for _, m in ipairs(small_moments(run)) do
        if m.level and m.react then
            local ok = false
            for _, t in ipairs(tlm.reactions({ campaign = run.c }, m.b, m.level)) do
                ok = ok or util.sentence_case(t) == m.react
            end
            -- (when-conditioned lines are checked against the end of the run: allow them too.)
            for _, l in ipairs((m.b.react or {})[m.level] or {}) do
                ok = ok or util.sentence_case(type(l) == "table" and l[1] or l) == m.react
            end
            for _, l in ipairs((m.b.react or {}).any or {}) do
                ok = ok or util.sentence_case(type(l) == "table" and l[1] or l) == m.react
            end
            if ok then
                add("F6", "reactions_that_follow_the_answer")
            else
                fail("F6", where(run, { week = m.week, room = m.room }) .. ": after the " .. m.level .. " answer on " .. m.b.id
                    .. ", \"" .. m.react .. "\"")
            end
        elseif m.level then
            add("F6", "answers_without_a_reaction")
        end
    end
end

-- F8: small moments wait until the room's danger is settled; curios that need the story wait for it.
function CHECKS.F8(run)
    local log = run.log
    local seen_text = {}
    for i, r in ipairs(log) do
        if r.k == "tiny_roll" then
            -- Nothing dangerous may still be coming in this room visit.
            for j = i + 1, #log do
                local q = log[j]
                if q.scene ~= r.scene or q.week ~= r.week or q.k == "scene" then
                    break
                end
                if (q.k == "battle" and q.ev.phase == "start") or (q.k == "decision" and DANGER_CARDS[q.card or ""]) then
                    fail("F8", where(run, r) .. ": a small moment before " .. (q.k == "battle" and "the room's fight" or ("the danger at " .. q.card)))
                    break
                end
            end
            add("F8", "small_moments")
        end
        if r.k == "say" and has(r.text, "tentacles under it") then
            if seen_text.tentacle then
                add("F8", "tentacle_joke_after_the_tentacle")
            else
                fail("F8", where(run, r) .. ": \"" .. r.text .. "\" before anyone saw a tentacle")
            end
        end
        if r.k == "say" and has(r.text, "How many eyes are drawn on these walls") then
            if run.c.adv.flags.door_open and seen_text.door_open_wk == r.week then
                add("F8", "eyes_after_the_door")
            else
                fail("F8", where(run, r) .. ": counting the archivist's eyes before the door's open")
            end
        end
        for _, ex in ipairs({ { "cat voice at the cat", "cat" }, { "nearest bust", "bust" }, { "bright fruits", "fruit" },
                              { "handful of the sand", "sand" }, { "out of the big window", "window" } }) do
            if r.k == "say" and has(r.text, ex[1]) then
                local said = false
                for j = math.max(1, i - 3), i - 1 do
                    said = said or (log[j].k == "narrate" and has(string.lower(log[j].text or ""), ex[2]))
                end
                local room_read = adventure.data.rooms[r.room or ""] and string.lower(adventure.data.rooms[r.room].read or "")
                if said or has(room_read, ex[2]) then
                    add("F8", "described_before_poked")
                else
                    fail("F8", where(run, r) .. ": \"" .. r.text .. "\" with nothing described")
                end
            end
        end
        if (r.k == "narrate" and has(r.text, "tentacle")) or (r.k == "decision" and has(r.ctext, "tentacle")) then
            seen_text.tentacle = true
        end
        if r.k == "decision" and r.card == "mus_office_door" then
            seen_text.door_open_wk = r.week
        end
    end
end

-- F26: about one table bit a night, a friend sits out after their beat, nothing poked twice in a
-- room, and the pet's hints lead somewhere.
function CHECKS.F26(run)
    local log = run.log
    local nights, with_bit, beats = {}, {}, {}
    local looked = {}
    local last_who, last_scene
    for i, r in ipairs(log) do
        nights[r.week] = true
        if r.k == "narrate" and r.style == "table" then
            with_bit[r.week] = (with_bit[r.week] or 0) + 1
        end
        if r.k == "narrate" and r.room and PLACE_LINE[r.room .. "|" .. (r.text or "")] then
            looked[r.room .. "/" .. PLACE_LINE[r.room .. "|" .. r.text]] = true
        end
        if r.k == "tiny_roll" then
            beats[r.week] = (beats[r.week] or 0) + 1
            local present = #(run.night and run.night.players or { 1, 2, 3, 4 })
            if last_scene == (r.week .. "/" .. tostring(r.scene)) and last_who == r.ev.who and present > 1 then
                fail("F26", where(run, r) .. ": " .. tostring(r.ev.who) .. " takes two small moments running")
            else
                add("F26", "small_moments_by_turns")
            end
            last_who, last_scene = r.ev.who, r.week .. "/" .. tostring(r.scene)
            local hit = i > 1 and log[i - 1].k == "say" and CURIO_BY_ASK[log[i - 1].text or ""]
            if hit and hit.b and hit.b.spot and looked[r.room .. "/" .. hit.b.spot] then
                fail("F26", where(run, r) .. ": " .. hit.b.id .. " pokes at a place someone just looked at")
            end
        elseif r.k == "decision" or r.k == "scene" or r.k == "battle" then
            last_who = nil
        end
        if r.k == "say" and HINTS[r.text or ""] then
            -- What comes next is a real find, or an answer worth the sniffing.
            local led = nil
            for j = i + 1, math.min(#log, i + 5) do
                local q = log[j]
                if q.k == "narrate" or q.k == "decision" then
                    led = not (q.k == "narrate" and DULL[q.text or ""])
                    break
                end
            end
            if led == false then
                fail("F26", where(run, r) .. ": \"" .. r.text .. "\", then nothing")
            else
                add("F26", "pet_hints_that_lead_somewhere")
            end
        end
    end
    for w in pairs(nights) do
        if (beats[w] or 0) >= 3 then
            add("F26", "nights_with_three_small_moments")
            if (with_bit[w] or 0) > 0 then
                add("F26", "of_them_with_a_table_bit")
            end
        end
        if (with_bit[w] or 0) > 6 then
            fail("F26", string.format("seed %d %s week %d: %d table-bit lines in one night", run.seed, run.style, w, with_bit[w]))
        end
    end
end

-- F7: a natural 1 poking at something is never a trap that hurts, and never a scare out in the street.
function CHECKS.F7(run)
    local log = run.log
    for i, r in ipairs(log) do
        if r.k == "decision" and r.card == "tl_crit" and has(r.title, "natural 1") then
            add("F7", "natural_one_cards")
            for _, o in ipairs(r.opts or {}) do
                if has(o.label, "trap") or has(o.sub or "", "damage") then
                    fail("F7", where(run, r) .. ": the natural 1 offers \"" .. o.label .. "\" (" .. tostring(o.sub) .. ")")
                end
                if r.room == "street" and has(o.label, "scare") then
                    fail("F7", where(run, r) .. ": a scare out in the street")
                end
            end
            for j = i + 1, math.min(#log, i + 3) do
                local q = log[j]
                if q.k == "narrate" and (has(q.text, "damage") or has(q.text, "A needle in")) then
                    fail("F7", where(run, q) .. ": " .. q.text)
                end
            end
        end
    end
end

-- F9: the offices as the book has them (the bird in the open study, the eyes behind the locked door),
-- and each painting's own danger.
local PORTRAIT_BY_PAINTING = {}
for key, port in pairs(adventure.data.portraits or {}) do
    PORTRAIT_BY_PAINTING[port.painting] = port
end
if adventure.data.portrait_default then
    PORTRAIT_BY_PAINTING[adventure.data.portrait_default.painting] = adventure.data.portrait_default
end
function CHECKS.F9(run)
    local log = run.log
    local door_open = {}
    local eye_line
    for _, b in pairs(require("game.data.map_library").boards) do
        if b.room == "offices" then
            for _, pl in ipairs(b.places) do
                if pl.id == "eyes" then
                    eye_line = pl.line
                end
            end
        end
    end
    for i, r in ipairs(log) do
        if r.k == "decision" and r.card == "mus_office_door" then
            door_open[r.week] = true
        end
        if r.k == "decision" and r.card == "mus_office_inside" then
            if has(r.ctext, "bird") then
                fail("F9", where(run, r) .. ": the locked study has the bird in it too: " .. r.ctext)
            else
                add("F9", "the_locked_study_without_the_bird")
            end
        end
        if (r.k == "narrate" or r.k == "say") and (has(r.text, "never seen a bird like it") or has(r.text, "archivist's shelves")) then
            fail("F9", where(run, r) .. ": " .. r.text)
        end
        if r.room == "offices" and r.k == "narrate" and eye_line and r.text == eye_line and not door_open[r.week] then
            fail("F9", where(run, r) .. ": the eyes on the walls before the locked door opens")
        end
        if r.k == "say" and r.room == "offices" and has(r.text, "the eye on every wall") and not door_open[r.week] then
            fail("F9", where(run, r) .. ": \"" .. r.text .. "\" before the locked door opens")
        end
        if r.k == "decision" and r.card == "mus_reach" then
            local port
            for painting, p in pairs(PORTRAIT_BY_PAINTING) do
                if has(r.ctext, painting) then
                    port = p
                end
            end
            if not port then
                fail("F9", where(run, r) .. ": a painting nobody knows: " .. tostring(r.ctext))
            else
                local rolls = false
                for _, o in ipairs(r.opts or {}) do
                    rolls = rolls or o.roll == true
                end
                if port.safe and (rolls or has(r.ctext, "rost")) then
                    fail("F9", where(run, r) .. ": a painting the book says is safe, made dangerous: " .. r.ctext)
                elseif not port.safe and not (rolls and has(r.ctext, port.hint or "?")) then
                    fail("F9", where(run, r) .. ": a dangerous painting without its danger: " .. r.ctext)
                else
                    add("F9", port.safe and "safe_paintings_reached" or "dangerous_paintings_reached")
                end
                -- A miss bites the way this painting bites, not the way another one does.
                for j = i + 1, math.min(#log, i + 8) do
                    local q = log[j]
                    if q.k == "narrate" and q.style == "bad" then
                        for _, other in pairs(PORTRAIT_BY_PAINTING) do
                            local stem = other.bite and string.match(other.bite, "^([^.]+%.)")
                            if other ~= port and stem and has(q.text, stem) then
                                fail("F9", where(run, q) .. ": " .. port.painting .. " bites like another painting: " .. q.text)
                            end
                        end
                        break
                    elseif q.k == "decision" then
                        break
                    end
                end
            end
        end
    end
end

-- F15: Flitwidget's thanks takes two different steps, the second about the reward.
function CHECKS.F15(run)
    local first
    for _, r in ipairs(run.log) do
        if r.k == "decision" and r.card == "talk_mus_flitwidget_1" then
            first = {}
            for _, o in ipairs(r.opts or {}) do
                first[o.label] = true
            end
        elseif r.k == "decision" and r.card == "talk_mus_flitwidget_2" and first then
            local same, reward = 0, 0
            for _, o in ipairs(r.opts or {}) do
                if first[o.label] then
                    same = same + 1
                end
                if has(string.lower(o.label), "reward") then
                    reward = reward + 1
                end
            end
            if same > 0 then
                fail("F15", where(run, r) .. ": Flitwidget's second card repeats " .. same .. " of his first lines")
            elseif reward == 0 and r.epilogue then
                fail("F15", where(run, r) .. ": asked about the reward, he doesn't answer it")
            else
                add("F15", "thanks_in_two_steps")
            end
            first = nil
        end
    end
end

-- F16: in the lair, lines remember Euryale is right there; her last words are last words.
local LAIR_NOT = { "Nobody to talk to", "Whatever's in here knows they're coming", "Big guy. Big sword", "Clever... but not clever enough" }
function CHECKS.F16(run)
    for _, r in ipairs(run.log) do
        if r.room == "lair" and r.text then
            for _, bad in ipairs(LAIR_NOT) do
                if has(r.text, bad) then
                    fail("F16", where(run, r) .. ": with Euryale right there, \"" .. r.text .. "\"")
                end
            end
            if r.k == "npc" and has(r.name, "Euryale") then
                add("F16", "euryale_speaks")
            end
        end
    end
end

-- F17: rests and travel name the room they're in, reinforcements fit the room and say who they are,
-- and one more room is a real scene.
function CHECKS.F17(run)
    local log = run.log
    local rooms_with = adventure.data.reinforcements or {}
    local prev_room, cur_room
    for i, r in ipairs(log) do
        if r.room and r.room ~= cur_room then
            prev_room, cur_room = cur_room, r.room     -- (a short room like the stairs has no scene card)
        end
        if r.k == "narrate" and has(r.text, "come crashing out of the exhibits") then
            fail("F17", where(run, r) .. ": nameless reinforcements: " .. r.text)
        end
        if r.k == "decision" and r.card == "boss_crit" then
            local offered
            for _, o in ipairs(r.opts or {}) do
                offered = offered or (has(o.label, "reinforcements") or has(o.label, "more") or has(o.label, "another")
                    or has(o.label, "scarabs") or has(o.label, "huntlings")) and o.label or nil
            end
            if offered and not rooms_with[r.room or ""] then
                fail("F17", where(run, r) .. ": reinforcements offered where nobody fits: " .. offered)
            elseif offered and has(offered, "reinforcements burst in") then
                fail("F17", where(run, r) .. ": reinforcements not named: " .. offered)
            else
                add("F17", "early_knockout_cards_that_fit_the_room")
            end
        end
        if r.k == "narrate" and has(r.text, "after a long rest in the gift shop") then
            for j = i + 1, math.min(#log, i + 40) do
                local q = log[j]
                local from = q.k == "narrate" and q.text and string.match(q.text, "^Out of (.-), ")
                if from then
                    if from ~= "the gift shop" and not has(r.text, "walk back up to") then
                        fail("F17", where(run, r) .. ": rested \"in the gift shop\", then " .. q.text)
                    else
                        add("F17", "rests_where_they_are")
                    end
                    break
                elseif q.k == "scene" then
                    break
                end
            end
        end
        if r.k == "narrate" and r.room == "stairs" and has(r.text, "Between the two studies") and prev_room == "gift_shop" then
            fail("F17", where(run, r) .. ": straight out of the gift shop, \"" .. r.text .. "\"")
        end
        if r.k == "decision" and r.card == "mus_wrap" and r.pick == 2 then
            local beats = 0
            local wraps = {}
            for _, t in ipairs(require("game.model.night").WRAP_LINES or { "That's a wrap. Chairs scrape, someone stacks the dice." }) do
                wraps[t] = true
            end
            for j = i + 1, #log do
                local q = log[j]
                if (q.k == "narrate" and (wraps[q.text or ""] or has(q.text, "That's a wrap"))) or (q.k == "decision" and q.card == "mus_wrap")
                    or q.week ~= r.week then
                    break
                end
                if q.k == "tiny_roll" or q.k == "decision" or (q.k == "narrate" and (q.style == "table" or q.style == "dm"))
                    or (q.k == "say" and q.ev.ic) then
                    beats = beats + 1
                end
            end
            if beats < 2 then
                fail("F17", where(run, r) .. ": one more room, and only " .. beats .. " beat(s) in it")
            else
                add("F17", "one_more_room_is_a_scene")
            end
        end
    end
end

-- F24, R2, R3: what's said every week or every fight comes three or more ways, never the same twice
-- running; catchphrases once a session and not from the same friend two talks running; a single foe
-- isn't "the last one"; a crit names the weapon in the hero's hand.
local function weekly_lists()
    local mn, nt = require "game.model.museum_night", require "game.model.night"
    local out = {}
    local function put(name, list, min)
        if type(list) == "table" then
            table.insert(out, { name = name, list = list, min = min or 3 })
        end
    end
    for k, l in pairs(mn.WEEKLY or {}) do
        -- (The first of a night is one line on purpose: the later ones vary.)
        put("WEEKLY." .. k, l)
    end
    for k, l in pairs(mn.BREAK_LOGS or {}) do
        put("BREAK_LOGS." .. k, l)
    end
    put("BREAK_START", mn.BREAK_START)
    put("BREAK_END", mn.BREAK_END)
    put("WRAP_LINES", nt.WRAP_LINES)
    put("FRANC_LINES", nt.FRANC_LINES)
    put("INSPIRE_LINES", nt.INSPIRE_LINES)
    for k, l in pairs(nt.FIGHT_CAPTIONS or {}) do
        put("FIGHT_CAPTIONS." .. k, l)
    end
    for k, l in pairs(nt.READY or {}) do
        put("READY." .. k, l)
    end
    for k, l in pairs(nt.REACTED or {}) do
        put("REACTED." .. k, l)
    end
    for k, l in pairs(mn.LEAN_WHY or {}) do
        put("LEAN_WHY." .. k, l)
    end
    return out
end

-- A line as said, back to its list's entry: names and numbers stand in for the fill-ins.
local function pattern_of(t)
    local p = string.gsub(t, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
    p = string.gsub(p, "{[%w_]+}", ".-")
    return "^" .. p .. "$"
end

function CHECKS.F24(run)
    local lists = weekly_lists()
    local pats = {}
    for _, L in ipairs(lists) do
        for _, t in ipairs(L.list) do
            table.insert(pats, { list = L.name, text = t, pat = pattern_of(t) })
        end
    end
    local last_of, uses = {}, 0
    local skim_n, item_n = {}, {}
    local holds = {}          -- hero -> the weapon item the table was told they fight with
    local foes_in_fight
    for _, r in ipairs(run.log) do
        if r.k == "battle" and r.ev.phase == "end" then
            local sm = r.ev.summary or {}
            foes_in_fight = #(sm.beaten or {}) + #(sm.ran or {})      -- (everyone who fought them, reinforcements too)
        end
        if (r.k == "narrate" or r.k == "say") and r.text and not (r.k == "say" and string.find(r.text, "^Let's ")) then
            -- (Its list: the line itself if it's said word for word, else the line whose fill-ins fit.)
            local hit
            for _, p in ipairs(pats) do
                if r.text == p.text then
                    hit = p
                end
            end
            for _, p in ipairs(pats) do
                if not hit and string.find(p.text, "{") and string.find(r.text, p.pat) then
                    hit = p
                end
            end
            if hit then
                uses = uses + 1
                if last_of[hit.list] == r.text then
                    fail("F24", where(run, r) .. ": the same " .. hit.list .. " line twice running: " .. r.text)
                end
                last_of[hit.list] = r.text
            end
        end
        local mn = require "game.model.museum_night"
        local first_of = nil
        for _, kind in ipairs({ "skim", "improv", "from_book" }) do
            for _, t in ipairs(mn.WEEKLY and mn.WEEKLY[kind] or {}) do
                if r.k == "narrate" and r.text == t then
                    first_of = kind
                end
            end
        end
        if r.k == "narrate" and (first_of or has(r.text, "You never read this room properly")) then
            local k = r.week .. (first_of or "skim")
            skim_n[k] = (skim_n[k] or 0) + 1
            if skim_n[k] > 1 then
                fail("F24", where(run, r) .. ": said again tonight: " .. r.text)
            end
        end
        if r.k == "narrate" and r.style == "good" and r.text then
            local who, item = string.match(r.text, "^(%a+) fights with the (.-) from")
            if who then
                holds[who] = item
                local k = r.week .. who .. item
                item_n[k] = (item_n[k] or 0) + 1
                if item_n[k] > 1 then
                    fail("F24", where(run, r) .. ": the item line again at another fight: " .. r.text)
                end
            end
            if (has(r.text, "The last one falls") or has(r.text, "The last of them goes down")) and foes_in_fight == 1 then
                fail("F24", where(run, r) .. ": \"" .. r.text .. "\" over a single foe")
            end
        end
        if r.k == "say" and r.text and has(r.text, "Crit with the ") then
            local p = run.c:player(r.ev.who)
            local item = p and holds[p.char]
            local ranged = has(string.lower(r.text), "bow") or has(string.lower(r.text), "sling") or has(string.lower(r.text), "dart")
            if item and not ranged and not has(string.lower(r.text), item) then
                fail("F24", where(run, r) .. ": " .. p.char .. " fights with the " .. item .. ", but \"" .. r.text .. "\"")
            else
                add("F24", "crits_that_name_the_weapon")
            end
        end
    end
    add("F24", "weekly_lines_said", uses)
end

-- R2: a friend's reason when the table talks it over: each line once a session, and never from the
-- same friend in two talks running.
function CHECKS.R2(run)
    local mn = require "game.model.museum_night"
    local talk, said, last = 1, {}, {}
    for _, r in ipairs(run.log) do
        if r.k == "narrate" and r.style == "aside" and has(r.text, "The table decides") then
            talk = talk + 1
        elseif r.k == "scene" then
            talk = talk + 1
        end
        if r.k == "say" and r.text and string.find(r.text, "^Let's ") then
            local p = run.c:player(r.ev.who)
            for arch, list in pairs(mn.LEAN_WHY or {}) do
                for _, line in ipairs(list) do
                    local t = util.fill(line, { char = p and p.char or "" })
                    if string.sub(r.text, -#t) == t then
                        local k = r.week .. "|" .. r.ev.who .. "|" .. t
                        if said[k] then
                            fail("R2", where(run, r) .. ": " .. r.ev.who .. " says it again tonight: " .. t)
                        end
                        said[k] = true
                        local lk = r.week .. "|" .. r.ev.who
                        if last[lk] and last[lk] == talk - 1 then
                            fail("R2", where(run, r) .. ": " .. r.ev.who .. " gives a reason two talks running: " .. r.text)
                        end
                        last[lk] = talk
                        add("R2", "reasons_given")
                    end
                end
            end
        end
    end
end

-- F25: chatter fits the moment: nothing claims a find that wasn't, no chips as the danger's announced,
-- the chat and the night agree on who's late and why, the loot isn't shared twice over, "your calls
-- for tonight" is true, and every card has at least two ways to go.
function CHECKS.F25(run)
    local log = run.log
    local late = {}
    for _, m in ipairs(run.chats) do
        local who = m.who and string.lower(m.who)
        if m.text and has(m.text, "late") then
            late[m.week] = late[m.week] or {}
            late[m.week][who or "?"] = m.text
        end
    end
    local shared_at
    local calls_out
    for i, r in ipairs(log) do
        if r.k == "decision" then
            local n = 0
            for _, o in ipairs(r.opts or {}) do
                if not o.disabled then
                    n = n + 1
                end
            end
            if n < 2 then
                fail("F25", where(run, r) .. ": a card with " .. n .. " way to go: " .. tostring(r.title))
            else
                add("F25", "cards_with_a_choice")
            end
            if calls_out == r.week and r.card ~= "tl_crit" and not string.find(r.card or "", "^table_") then
                -- (After "your calls on the big rolls", no more of those: roll cards.)
            end
        end
        if r.k == "narrate" and r.style == "system" and has(r.text, "That's your calls") then
            calls_out = r.week
            if not has(r.text, "big rolls") then
                fail("F25", where(run, r) .. ": \"" .. r.text .. "\" and more calls follow")
            end
        end
        if r.k == "say" and has(r.text, "i found it, but") then
            fail("F25", where(run, r) .. ": \"" .. r.text .. "\" with nothing looked up")
        end
        if r.k == "say" and has(r.text, "with the chips") then
            local room = adventure.data.rooms[r.room or ""] or {}
            if room.encounter and not r.fought then
                fail("F25", where(run, r) .. ": \"" .. r.text .. "\" with a fight still to come")
            end
        end
        if r.k == "say" and (has(r.text, "i'm late") or has(r.text, "traffic")) then
            local p = run.c:player(r.ev.who)
            local chat = late[r.week] and p and late[r.week][string.lower(p.name)]
            if not chat then
                fail("F25", where(run, r) .. ": " .. tostring(r.ev.who) .. " is late, and the chat never said so: " .. r.text)
            elseif has(r.text, "traffic") and has(chat, "bus") then
                fail("F25", where(run, r) .. ": late for traffic, but the chat said the bus")
            else
                add("F25", "late_as_the_chat_said")
            end
        end
        if r.k == "say" and (has(r.text, "will get more out of this than me") or has(r.text, "it's yours")) then
            shared_at = i
        end
        if r.k == "narrate" and has(r.text, "have first pick of whatever they find next") then
            if shared_at and i - shared_at < 12 then
                fail("F25", where(run, r) .. ": the loot shared twice running: " .. r.text)
            end
        end
    end
end

-- F21: notes only the DM knows have their own caption.
local SCREEN_NOTES = { "behind your screen", "You never prepped it", "You hadn't prepped this one", "off screen, as you agreed",
    "You leave the ", "You make a note", "You make a mental note", "Your rolls go back behind the screen" }
function CHECKS.F21(run)
    for _, r in ipairs(run.log) do
        if r.k == "narrate" then
            for _, pat in ipairs(SCREEN_NOTES) do
                if has(r.text, pat) or has(string.lower(r.text or ""), string.lower(pat)) then
                    if r.style == "screen" then
                        add("F21", "notes_behind_the_screen")
                    else
                        fail("F21", where(run, r) .. ": a note only you know, captioned " .. tostring(r.style) .. ": " .. r.text)
                    end
                    break
                end
            end
        end
    end
end

-- F22: what the friends say looking round fits what they're looking at.
function CHECKS.F22(run)
    local fought = {}
    for _, r in ipairs(run.log) do
        if r.k == "battle" and r.ev.phase == "start" and r.room then
            fought[r.week .. "/" .. r.room] = true
        end
        if r.k == "say" and has(r.text, "Where are the monsters?") then
            local room = adventure.data.rooms[r.room or ""] or {}
            if fought[r.week .. "/" .. tostring(r.room)] or room.encounter then
                fail("F22", where(run, r) .. ": \"" .. r.text .. "\" in a room with a fight in it")
            else
                add("F22", "where_are_the_monsters_in_a_quiet_room")
            end
        end
        for _, bad in ipairs({ "Is the shears", "Who left the front doors", "Who left the museum's doors", "has under the",
                               "hit the piles of books? I want to hit it.", "Does the cases", "Is the anatomy drawings",
                               "Is the piles", "Is the cases" }) do
            if r.k == "say" and has(r.text, bad) then
                fail("F22", where(run, r) .. ": \"" .. r.text .. "\"")
            end
        end
    end
end

-- Unit cases ----------------------------------------------------------------------------------------

local UNITS = {}

-- F21: the caption is its own, and quieter than the DM's voice.
function UNITS.F21()
    local real_gui, real_vmath = gui, vmath
    gui = setmetatable({}, { __index = function() return function() end end })
    vmath = vmath or { vector3 = function() return {} end, vector4 = function() return {} end }
    local ok, nv = pcall(require, "game.ui.night_view")
    gui, vmath = real_gui, real_vmath
    if not ok then
        fail("F21", "night_view didn't load: " .. tostring(nv))
        return
    end
    local v = nv.VOICE and nv.VOICE.screen
    if not v or v[1] ~= "BEHIND YOUR SCREEN" then
        fail("F21", "no BEHIND YOUR SCREEN caption (VOICE.screen)")
    else
        add("F21", "caption_behind_your_screen")
        local function lum(hex)
            local r, g, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
            return 0.2126 * r + 0.7152 * g + 0.0722 * b
        end
        if lum(v[2]) >= lum(nv.VOICE.dm[2]) then
            fail("F21", "the screen's caption isn't quieter than the DM's (" .. v[2] .. " vs " .. nv.VOICE.dm[2] .. ")")
        else
            add("F21", "quieter_than_speech")
        end
    end
    local theme = require "game.ui.theme"
    if not (theme.log and theme.log.screen) then
        fail("F21", "no log colour for notes behind your screen (theme.log.screen)")
    end
    local night_mod = require "game.model.night"
    if not (night_mod.screen_note and night_mod.screen_note("Behind your screen, you cross it out.")) then
        fail("F21", "night.screen_note doesn't know a note behind your screen")
    end
end

-- F22: every place the friends walk over to says what it is, and every line said of it fits.
function UNITS.F22()
    local mn = require "game.model.museum_night"
    local lib = require "game.data.map_library"
    if not mn.look_lines then
        fail("F22", "museum_night.look_lines (the lines that fit a place) is missing")
        return
    end
    for room, list in pairs(adventure.data.explore or {}) do
        local board
        for _, b in pairs(lib.boards) do
            if b.room == room then
                board = b
            end
        end
        local by = {}
        for _, pl in ipairs(board and board.places or {}) do
            by[pl.id] = pl
        end
        for _, pid in ipairs(list) do
            local pl = by[pid]
            if not pl then
                fail("F22", room .. ": no place " .. tostring(pid) .. " on its board")
            elseif not pl.kind then
                fail("F22", room .. "/" .. pid .. ": the place doesn't say what kind of thing it is")
            else
                add("F22", "places_with_a_form")
                for arch in pairs(mn.LOOK_SAY) do
                    local lines = mn.look_lines(arch, pl, { calm = false })
                    if #lines == 0 then
                        fail("F22", room .. "/" .. pid .. ": nothing a " .. arch .. " can say about " .. pl.name)
                    end
                    for _, t in ipairs(lines) do
                        local name = util.lower_first(pl.name)
                        add("F22", "lines_checked")
                        local low = string.lower(t)
                        local n = string.lower(name)
                        if pl.many and (has(low, "is " .. n) or has(low, "does " .. n) or has(low, n .. " is ")
                            or has(low, "hit it") or has(low, "lick it") or has(low, "sell it")) then
                            fail("F22", room .. "/" .. pid .. " (many): \"" .. t .. "\"")
                        elseif not pl.many and (has(low, "are " .. n) or has(low, "do " .. n) or has(low, "them")) then
                            fail("F22", room .. "/" .. pid .. " (one): \"" .. t .. "\"")
                        end
                        if pl.kind ~= "thing" and has(low, "who left") then
                            fail("F22", room .. "/" .. pid .. " (" .. pl.kind .. "): \"" .. t .. "\"")
                        end
                        if (pl.kind == "fixture" or pl.kind == "area" or pl.kind == "person") and (has(low, "take " .. n .. " home")
                            or has(low, "knock " .. n .. " over")) then
                            fail("F22", room .. "/" .. pid .. " (" .. pl.kind .. "): \"" .. t .. "\"")
                        end
                        if pl.kind == "area" and (has(low, "has " .. n) or has(low, "touch " .. n)) then
                            fail("F22", room .. "/" .. pid .. " (area): \"" .. t .. "\"")
                        end
                        if has(t, "Where are the monsters") then
                            fail("F22", "\"Where are the monsters?\" offered for a room that isn't calm")
                        end
                    end
                end
            end
        end
    end
end

-- A pretend night for calling the small moments' cards directly: records what's said and shown.
local function fake_night(room, pick)
    adventure.enter()
    local c = campaign_mod.new(7)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    local said, cards = {}, {}
    local night = { campaign = c, rng = require("game.model.rng").new(11), players = c.players, actor = c.players[1],
                    mus = {}, pcs = { mara = { hp = 10 } } }
    function night:decision(card)
        table.insert(cards, card)
        return card.options[pick or #card.options]
    end
    function night:say(text, style)
        table.insert(said, { text = text, style = style })
    end
    function night:emit(ev)
        table.insert(said, { text = ev.text, kind = ev.kind })
    end
    function night:react() end
    return night, { room = room }, said, cards
end

-- F6: every curio has a reaction for each answer it has, and none of them is about another answer.
function UNITS.F6()
    local tlm = require "game.model.table_life"
    for room, r in pairs(TL.rooms) do
        for _, b in ipairs(r.curios or {}) do
            for _, lvl in ipairs({ "dull", "detail", "lore" }) do
                if b[lvl] then
                    local own = (b.react or {})[lvl]
                    if not own or #own == 0 then
                        fail("F6", room .. "/" .. b.id .. ": no reaction of its own for the " .. lvl .. " answer")
                    else
                        add("F6", "answers_with_their_own_reactions")
                    end
                end
            end
            if b.react and b.react[1] then
                fail("F6", room .. "/" .. b.id .. ": reactions not sorted by answer")
            end
        end
    end
    if not tlm.reactions then
        fail("F6", "table_life.reactions is missing")
    end
end

-- F7: a natural 1's little trap is a scare in the room's own words, never hurts, never outside.
function UNITS.F7()
    local tlm = require "game.model.table_life"
    if not tlm.crit_card then
        fail("F7", "table_life.crit_card isn't there to check")
        return
    end
    for room, r in pairs(TL.rooms) do
        local b = (r.curios or {})[1]
        if b then
            local night, sc, said, cards = fake_night(room, 3)
            local hp = night.pcs.mara.hp
            tlm.crit_card(night, sc, night.players[1], b, 1)
            local card = cards[1]
            local labels = {}
            for _, o in ipairs(card and card.options or {}) do
                table.insert(labels, o.label)
                if has(o.label, "trap") or has(o.sub or "", "damage") then
                    fail("F7", room .. ": the natural 1 offers " .. o.label .. " (" .. tostring(o.sub) .. ")")
                end
            end
            if night.pcs.mara.hp ~= hp then
                fail("F7", room .. ": the natural 1 cost hit points")
            end
            for _, l in ipairs(said) do
                if has(l.text, "A needle in") then
                    fail("F7", room .. ": \"" .. l.text .. "\"")
                end
            end
            local scare = false
            for _, o in ipairs(card and card.options or {}) do
                scare = scare or o.scare ~= nil
            end
            if room == "street" or room == "lair" then
                if scare then
                    fail("F7", room .. ": a scare outside the museum's rooms")
                else
                    add("F7", "no_scare_outside")
                end
            elseif not scare then
                fail("F7", room .. ": no scare of its own (" .. table.concat(labels, " / ") .. ")")
            else
                add("F7", "rooms_with_their_own_scare")
            end
        end
    end
end

-- F26: a natural 20 or 1 on a question gives the DM a card too, the harmless answer first.
function UNITS.F26()
    local tlm = require "game.model.table_life"
    if not tlm.ask_crit then
        fail("F26", "table_life.ask_crit (a natural 20 or 1 on a question) is missing")
        return
    end
    for _, nat in ipairs({ 20, 1 }) do
        local night, sc, said, cards = fake_night("street", 2)
        local q = TL.rooms.street.npc_questions[1]
        local o = tlm.ask_crit(night, sc, night.players[1], q, "Formicarius Flitwidget, the curator", nat)
        local card = cards[1]
        if not card or #card.options < 2 then
            fail("F26", "a natural " .. nat .. " on a question: no card with a choice")
        else
            add("F26", "question_crit_cards")
            if has(card.text, ", the curator") then
                fail("F26", "the question card names him in full: " .. card.text)
            end
            if not (o and (o.slip or o.answer)) then
                fail("F26", "a natural " .. nat .. " on a question: the improvised option says nothing")
            end
        end
    end
end

-- F9: the shop's prices keep the book's order, and every painting's danger is the book's.
function UNITS.F9()
    local shop
    for _, m in ipairs(adventure.data.moments) do
        if m.id == "mus_shopping" then
            shop = m
        end
    end
    local price = {}
    for _, o in ipairs(shop and shop.options or {}) do
        if o.price then
            price[o.want] = o.price
            local said = tonumber(string.match(o.label, "%((%d+) Francs%)"))
            if said ~= o.price or (o.mus and o.mus.spend ~= o.price) then
                fail("F9", "the shop says " .. tostring(said) .. ", asks " .. o.price .. ", takes " .. tostring(o.mus and o.mus.spend) .. ": " .. o.label)
            end
        end
    end
    local tenets, manual, pair = price["buy the book on gorgon-worshippers"], price["buy the Mech manual"],
        price["buy the fire arrows and the slime"]
    if not (tenets and manual and pair) then
        fail("F9", "the shop's three goods aren't all there")
    elseif tenets ~= manual or pair <= tenets then
        fail("F9", string.format("the shop's prices aren't in the book's order (Tenets %d, manual %d, arrows and slime %d)", tenets, manual, pair))
    else
        add("F9", "shop_prices_in_the_books_order")
    end
    local P = adventure.data.portraits or {}
    local book = { mara = "safe", jess = "safe", sam = "safe", dev = "blade" }
    for key, want in pairs(book) do
        local port = P[key] or {}
        if want == "safe" and not port.safe then
            fail("F9", key .. "'s painting (" .. tostring(port.painting) .. ") has a danger the book doesn't give it")
        elseif want == "blade" and not (port.danger and port.bite and port.hurt and has(port.bite, "blade")) then
            fail("F9", key .. "'s painting (" .. tostring(port.painting) .. ") should cut, as the book's warrior does")
        else
            add("F9", "paintings_as_the_book_has_them")
        end
    end
    local d = adventure.data.portrait_default
    if not (d and d.danger and has(d.hint or "", "rost")) then
        fail("F9", "the elf in the snow's painting has no cold to it")
    end
end

-- F16: Euryale's last words aren't a victory taunt.
function UNITS.F16()
    local down = adventure.data.npc_lines and adventure.data.npc_lines.mus_euryale and adventure.data.npc_lines.mus_euryale.npc_down or {}
    for _, t in ipairs(down) do
        if has(t, "not clever enough") or has(t, "You'll make bigger") then
            fail("F16", "her last words are a taunt: " .. t)
        end
    end
    add("F16", "last_words", #down)
    local B = require "game.model.barks"
    if not B.context_fits then
        fail("F16", "barks.context_fits (lines that fit the room) is missing")
        return
    end
    if B.context_fits("Hm. Nobody to talk to. Pip will talk to the walls.", { someone = true }) then
        fail("F16", "\"Nobody to talk to\" fits a room with someone in it")
    end
    if B.context_fits("That's a big one. Let's see what it's got.", { big = false, foes = 4 }) then
        fail("F16", "\"a big one\" fits a fight against someone her size")
    end
end

-- F17: reinforcements only where someone fits, by name, and none of Sam's creepy-crawlies under a line.
function UNITS.F17()
    local fight = require "game.model.fight"
    if not fight.reinforcement then
        fail("F17", "fight.reinforcement is missing")
        return
    end
    adventure.enter()
    local c = campaign_mod.new(3)
    adventure.enter(c)
    local s0 = social.default_choices()
    c:session_zero(s0)
    local night = { mus = {}, campaign = c }
    for id, r in pairs(adventure.data.rooms) do
        if r.encounter then
            local rf = fight.reinforcement(night, { room = id })
            if rf then
                add("F17", "rooms_with_named_reinforcements")
                if not (rf.label and rf.log and rf.id) then
                    fail("F17", id .. ": reinforcements without a name or a line")
                end
            else
                add("F17", "rooms_with_nobody_to_send")
            end
        end
    end
    for _, id in ipairs({ "lecture", "entrance", "paintings" }) do
        if fight.reinforcement(night, { room = id }) then
            fail("F17", id .. ": reinforcements offered, though nobody there fits")
        end
    end
    c.table = c.table or {}
    c.table.lines = { bugs = "sam" }
    if fight.reinforcement(night, { room = "chamber" }) or fight.reinforcement(night, { room = "hunting" }) then
        fail("F17", "creepy-crawly reinforcements with a line drawn under them")
    end
    c.table.lines, c.table.veils = {}, { bugs = "sam" }
    local soft = fight.reinforcement(night, { room = "chamber" })
    if not (soft and has(soft.log, "shadows")) then
        fail("F17", "veiled creepy-crawlies come in plain view")
    end
end

-- R3: anything said every week comes three or more ways; R2: fresh() never says the same line twice
-- running, and once a session means once.
function UNITS.R3()
    for _, L in ipairs(weekly_lists()) do
        if #L.list < L.min then
            fail("R3", L.name .. ": only " .. #L.list .. " way(s) to say it")
        else
            add("R3", "weekly_lists_with_three_or_more")
        end
    end
    -- The chat's own weekly lines.
    local mw = require "game.model.museum_week"
    for k, l in pairs(mw.REPLY or {}) do
        if #l < 3 then
            fail("R3", "the chat's " .. k .. " replies: only " .. #l)
        end
    end
    if #(adventure.data.chat_banter or {}) < 3 then
        fail("R3", "the chat's banter: fewer than three")
    end
end

function UNITS.R2()
    local night_mod = require "game.model.night"
    adventure.enter()
    local c = campaign_mod.new(9)
    local fake = setmetatable({ campaign = c, rng = require("game.model.rng").new(3) }, { __index = night_mod })
    local list = { "one", "two", "three" }
    local prev
    for i = 1, 40 do
        c.week = 1 + math.floor(i / 7)
        local l = fake:fresh(list, "r2_test")
        if l == prev then
            fail("R2", "fresh() said \"" .. l .. "\" twice running")
            break
        end
        prev = l
    end
    c.week = 20
    local seen, n = {}, 0
    for _ = 1, 5 do
        local l = fake:fresh(list, "r2_once", true)
        if l then
            if seen[l] then
                fail("R2", "fresh(once) said \"" .. l .. "\" twice in a session")
            end
            seen[l], n = true, n + 1
        end
    end
    if n ~= 3 then
        fail("R2", "fresh(once) gave " .. n .. " lines from three in a session")
    else
        add("R2", "once_a_session_holds")
    end
    local mn = require "game.model.museum_night"
    for k, l in pairs(mn.LEAN_WHY or {}) do
        if #l < 3 then
            fail("R2", "LEAN_WHY." .. k .. ": fewer than three reasons")
        end
    end
end

-- Running -----------------------------------------------------------------------------------------------

for _, item in ipairs(ITEMS) do
    if UNITS[item] then
        local ok, err = pcall(UNITS[item])
        if not ok then
            fail(item, "unit case error: " .. tostring(err))
        end
    end
end
local base = tonumber(os.getenv("SEED_BASE") or "") or 500
for _, style in ipairs(STYLES) do
    for i = 1, RUNS do
        local seed = base + i * 23
        local ok, run = pcall(play, seed, style)
        if not ok then
            fail("run", "seed " .. seed .. " " .. style .. ": " .. tostring(run))
        else
            for _, item in ipairs(ITEMS) do
                if CHECKS[item] then
                    local ok2, err = pcall(CHECKS[item], run)
                    if not ok2 then
                        fail(item, "seed " .. seed .. " " .. style .. ": check error: " .. tostring(err))
                    end
                end
            end
        end
    end
end

-- F17's one more room, made to happen: a DM who always plays on when it's late.
if util.contains(ITEMS, "F17") then
    for i = 1, RUNS do
        local seed = base + 7 + i * 31
        local ok, run = pcall(play, seed, "random", { pick = function(ev, pick)
            return ev.card.id == "mus_wrap" and 2 or nil
        end })
        if ok then
            pcall(CHECKS.F17, run)
        else
            fail("run", "seed " .. seed .. " one more room: " .. tostring(run))
        end
    end
end

local total = 0
for _, item in ipairs({ "run", unpack(ITEMS) }) do
    local parts = {}
    for k, v in pairs(rawget(E, item) or {}) do
        table.insert(parts, k .. " " .. v)
    end
    table.sort(parts)
    local f = fails[item]
    print(string.format("%-4s %-30s %s%s", item, NAMES[item] or item, #parts > 0 and table.concat(parts, ", ") or "(nothing seen)",
        f and ("  FAILS " .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("       FAIL " .. m)
    end
    total = total + (f and f.n or 0)
end
print(total == 0 and "roadmap words check: every item holds" or ("roadmap words check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
