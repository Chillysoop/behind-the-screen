-- The tie-and-lock editor's model (v2, October 30: game/model/ties.lua), headless. Run from the
-- project root:
--   lua tools/tests/ties_check.lua
-- Checks: the outs are named in words (never their ids); a locked door and a locked room keep the
-- party out, say so at the fork, and open with a line when their condition comes true; a lock that
-- could never open, or could leave the lair out of reach, is refused with a reason; a tie puts a
-- mark on her card on game night (the usual event and her thought); a cut moment and a hidden
-- person are skipped; a tie moves a hero's reason for coming; a save keeps all of it; and whole
-- prologues still finish with a few locks and ties set, by every kind of DM.

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"
local ties = require "game.model.ties"
local save = require "game.model.save"

local MODULE = adventure.data

local fails, checks = 0, 0
local function check(cond, msg)
    checks = checks + 1
    if not cond then
        fails = fails + 1
        print("FAIL: " .. msg)
    end
end

local function has(t, v)
    for _, x in ipairs(t or {}) do
        if x == v then
            return true
        end
    end
    return false
end

local function new_campaign(seed)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        adventure.set_hook(c, key, MODULE.hooks[key][1].id)
    end
    return c
end

-- Walk the party through rooms by hand (no night).
local function walk(c, ids, week)
    for _, id in ipairs(ids) do
        adventure.enter_room(c, id, week or 1)
        adventure.leave_room(c, id, "win", week or 1)
        ties.open_locks(c)
    end
end

-- Play one night, the DM taking the first option (or a random one); returns every event.
local function play(night, rng)
    local evs = {}
    local ev = night:advance()
    local guard = 0
    while ev.kind ~= "done" and guard < 5000 do
        guard = guard + 1
        table.insert(evs, ev)
        local answer
        if ev.kind == "decision" then
            local opts = ev.card.options
            answer = rng and rng:int(1, #opts) or 1
            if opts[answer].disabled then
                answer = 1
            end
        elseif ev.kind == "ruling" then
            answer = 1
        elseif ev.kind == "improv" then
            answer = { 1 }
        elseif ev.kind == "roll_where" then
            answer = "open"
        elseif ev.kind == "roll" then
            answer = rng and rng:d20() or 15
        elseif ev.kind == "thought" then
            local th = require "game.model.thoughts"
            th.respond(night, ev.id, "let_be")
        end
        ev = night:advance(answer)
    end
    check(guard < 5000, "a night finished")
    return evs
end

local function said(evs, fragment)
    for _, ev in ipairs(evs) do
        if ev.text and string.find(ev.text, fragment, 1, true) then
            return true
        end
        if ev.kind == "decision" and ev.card and ev.card.text and string.find(ev.card.text, fragment, 1, true) then
            return true
        end
    end
    return false
end

local function screen_text_ok(s, where)
    check(type(s) == "string" and s ~= "", where .. ": has words")
    check(not string.find(s or "", "{[%w_]+}"), where .. ": no fill-ins left: " .. tostring(s))
    check(not adventure.foreign(s), where .. ": nothing from the old story: " .. tostring(s))
    check(not string.find(s or "", "[%w]_[%w]"), where .. ": no ids on screen: " .. tostring(s))
end

-- 1. The outs and the chips, in words. ----------------------------------------------------------
local c = new_campaign(21)
local cat = ties.catalog()
check(#cat.flag_order >= 10, "the cards' outs are listed (" .. #cat.flag_order .. ")")
for _, id in ipairs(cat.flag_order) do
    local name = ties.flag_name(id)
    check(name and name ~= id, "an out is named in words, not by its id: " .. id)
    screen_text_ok(name, "out " .. id)
end
for _, tab in ipairs(ties.cond_tabs(c)) do
    screen_text_ok(tab.name, "a tab")
    for _, chip in ipairs(tab.chips) do
        screen_text_ok(chip.label, "a chip")
        screen_text_ok(ties.clause(chip.cond), "a condition")
    end
end
for _, m in ipairs(MODULE.moments) do
    for _, line in ipairs(ties.moment_ins(c, m)) do
        screen_text_ok(line, "the ins of " .. m.id)
    end
    for _, o in ipairs(ties.moment_outs(m)) do
        screen_text_ok(o.label, "an option of " .. m.id)
        for _, w in ipairs(o.words) do
            screen_text_ok(w, "the outs of " .. m.id)
        end
    end
end

-- 2. A locked door keeps them out, says so, and opens. -------------------------------------------
local lock, why = ties.add_lock(c, { kind = "door", a = "entrance", b = "paintings", cond = { kind = "room", room = "chamber" } })
check(lock ~= nil, "a door locks until a room is done (" .. tostring(why) .. ")")
screen_text_ok(ties.describe(lock), "the lock's sentence")
walk(c, { "street", "garden", "entrance" })
local st = c.adv
check(st.at == "chamber" and not st.choices, "past the entrance, only the open wing (" .. tostring(st.at) .. ")")
local shut = ties.shut_line(c, "entrance")
check(shut and shut:find("Hall of Paintings", 1, true), "the shut way is named: " .. tostring(shut))
check(adventure.ahead(c)[1] == "chamber", "prep starts with the open wing")
adventure.enter_room(c, "chamber", 1)
adventure.leave_room(c, "chamber", "win", 1)
local opened = ties.open_locks(c)
check(#opened == 1 and opened[1].id == lock.id, "the lock opens when the chamber is done")
check(ties.open_line(opened[1]):find("swings open", 1, true), "and the table hears it")
check(has(st.choices, "paintings") and has(st.choices, "gift_shop"), "the other wing is on the way again")
check(#ties.shut_ways(c, "chamber") == 0, "nothing's shut once it's open")
check(not adventure.way_closed(c, "entrance", "paintings"), "an open lock stays open")

-- 3. A locked room, and what's refused. ----------------------------------------------------------
local c2 = new_campaign(22)
local function refused(l, what, fragment)
    local ok, w = ties.add_lock(c2, l)
    check(not ok, what .. " is refused")
    check(type(w) == "string" and w ~= "", what .. " says why")
    if fragment and w then
        check(w:find(fragment, 1, true), what .. ": '" .. w .. "' mentions '" .. fragment .. "'")
    end
    if w then
        screen_text_ok(w, what)
    end
end
refused({ kind = "room", room = "street", cond = { kind = "room", room = "garden" } }, "locking the start")
refused({ kind = "room", room = "lecture", cond = { kind = "flag", flag = "deaf" } }, "a room only its own card can open",
    "lecture theatre")
refused({ kind = "room", room = "paintings", cond = { kind = "room", room = "paintings" } }, "a room until itself")
refused({ kind = "room", room = "stairs", cond = { kind = "flag", flag = "paint" } }, "the only way up behind something that may never happen",
    "out of reach")
refused({ kind = "door", a = "gift_shop", b = "hunting", cond = { kind = "mark", mark = "topiary" } }, "the way upstairs behind a maybe",
    "out of reach")
refused({ kind = "person", person = "mus_telpur", cond = { kind = "flag", flag = "arrows" } }, "Telpur until something only Telpur sells",
    "Telpur")
refused({ kind = "person", person = "mus_euryale", cond = { kind = "room", room = "garden" } }, "hiding the boss")
refused({ kind = "moment", moment = "mus_hyper", cond = { kind = "flag", flag = "mech_burnt" } }, "a card only if itself",
    "this card")
refused({ kind = "moment", moment = "mus_tidy", cond = { kind = "room", room = "chamber" } }, "a card only after its own room")
refused({ kind = "door", a = "street", b = "lair", cond = { kind = "room", room = "garden" } }, "a door that isn't there")
-- Two locks that would wait on each other.
local l1 = ties.add_lock(c2, { kind = "room", room = "chamber", cond = { kind = "flag", flag = "paint" } })
check(l1 ~= nil, "the chamber can wait on the paintings")
refused({ kind = "room", room = "paintings", cond = { kind = "flag", flag = "daggers" } }, "two locks waiting on each other")
ties.remove(c2, l1.id)
check(#ties.locks(c2) == 0, "a lock comes off")
-- The lair stays in reach when a tie makes the mark sure to come.
refused({ kind = "room", room = "stairs", cond = { kind = "mark", mark = "knight" } }, "the stairs until a mark that may never come")
local t0 = ties.add_tie(c2, { cond = { kind = "room", room = "lecture" }, effect = { kind = "mark", mark = "knight" } })
check(t0 ~= nil, "a tie: after the lecture theatre, the knight")
local l2, w2 = ties.add_lock(c2, { kind = "room", room = "stairs", cond = { kind = "mark", mark = "knight" } })
check(l2 ~= nil, "with that tie, the stairs can wait on the knight (" .. tostring(w2) .. ")")
check(ties.add_tie(c2, { cond = { kind = "room", room = "lecture" }, effect = { kind = "mark", mark = "knight" } }) == nil,
    "the same tie twice is refused")
-- A room locked until a session: shut, and open when the week comes.
c2.week = 1
local l3 = ties.add_lock(c2, { kind = "room", room = "hunting", cond = { kind = "session", n = 2 } })
check(l3 ~= nil, "upstairs can wait for session 2")
check(adventure.room_closed(c2, "hunting"), "and it's shut in session 1")
refused({ kind = "room", room = "garden", cond = { kind = "session", n = 1 } }, "a lock that's already open", "already")
c2.week = 2
ties.week(c2)
check(not adventure.room_closed(c2, "hunting"), "the new session opens it")
check(#ties.news(c2) == 1, "with a line for the night")
check(#ties.news(c2) == 0, "said once")

-- Nowhere to go next session is refused; a room behind a lock drops out of tonight's rooms.
local c6 = new_campaign(27)
walk(c6, { "street", "garden", "entrance", "chamber", "paintings", "gift_shop" })
local ok6, w6 = ties.add_lock(c6, { kind = "room", room = "hunting", cond = { kind = "session", n = 3 } })
check(not ok6 and w6 and w6:find("nowhere", 1, true), "a lock that leaves them nowhere to go is refused (" .. tostring(w6) .. ")")
local c8 = new_campaign(29)
local ok8, w8 = ties.add_lock(c8, { kind = "door", a = "street", b = "garden", cond = { kind = "session", n = 3 } })
check(not ok8 and w8 and w8:find("nowhere", 1, true), "a lock that leaves only the first room is refused (" .. tostring(w8) .. ")")
local c7 = new_campaign(28)
walk(c7, { "street", "garden", "entrance", "chamber", "gift_shop" })
check(has(adventure.ahead(c7), "hunting"), "upstairs is on tonight's way")
local l7 = ties.add_lock(c7, { kind = "room", room = "hunting", cond = { kind = "room", room = "paintings" } })
check(l7 ~= nil, "upstairs can wait for the other wing")
check(not has(adventure.ahead(c7), "hunting") and has(adventure.ahead(c7), "paintings"), "prep doesn't look past a locked room")
check(c7.adv.at == "paintings", "the way on is the other wing")
ties.remove(c7, l7.id)
check(has(adventure.frontier(c7), "hunting"), "taking the lock off opens the way again")

-- Her lair locked: the stairs don't lead to her until it opens, then she's next wherever they are.
local c9 = new_campaign(30)
walk(c9, { "street", "garden", "entrance", "chamber", "paintings", "gift_shop", "hunting", "offices" })
local l9, w9 = ties.add_lock(c9, { kind = "room", room = "lair", cond = { kind = "room", room = "lecture" } })
check(l9 ~= nil, "her lair can wait for the lecture theatre (" .. tostring(w9) .. ")")
c9.adv.at, c9.adv.choices = "stairs", nil
check(not adventure.boss_week(c9), "no boss night while her lair is shut")
walk(c9, { "stairs" })
check(c9.adv.at ~= "lair" and not adventure.boss_week(c9), "the stairs don't lead to her yet (" .. tostring(c9.adv.at) .. ")")
walk(c9, { "lecture" })
check(c9.adv.at == "lair" and adventure.boss_week(c9), "once it opens she's next (" .. tostring(c9.adv.at) .. ")")

-- 4. A tie puts a mark on her card on game night. -------------------------------------------------
local c3 = new_campaign(23)
local t = ties.add_tie(c3, { cond = { kind = "room", room = "garden" }, effect = { kind = "mark", mark = "mirror" } })
check(t ~= nil, "a tie: after the garden, the mirror")
screen_text_ok(ties.describe(t), "the tie's sentence")
local cut = ties.add_lock(c3, { kind = "moment", moment = "mus_francs_intro", cond = { kind = "never" } })
check(cut ~= nil, "a moment can be cut")
local prep = c3:start_week()
museum_week.prep_greedy(prep)
local evs = play(c3:start_night())
c3:finish_night()
local mark_ev
for _, ev in ipairs(evs) do
    if ev.kind == "mark" and ev.id == "mirror" then
        mark_ev = ev
    end
end
check(c3.adv.done.garden, "the garden was played")
check(mark_ev ~= nil, "the tie's mark lands on game night as the usual event")
check(said(evs, "Upstairs, Euryale: \"" .. MODULE.marks.mirror.thought), "with her thought")
check(c3.adv.marks.mirror and t.fired, "the mark is on her card and the tie has fired")
check(not c3.adv.seen.mus_francs_intro, "the cut moment never played")
check(ties.add_tie(c3, { cond = { kind = "room", room = "entrance" }, effect = { kind = "mark", mark = "mirror" } }) == nil,
    "a mark she already has can't be tied again")

-- 5. A hidden person, a moment only if, a hook moved. ---------------------------------------------
local c4 = new_campaign(24)
local hid = ties.add_lock(c4, { kind = "person", person = "mus_telpur", cond = { kind = "session", n = 6 } })
check(hid ~= nil, "Telpur can keep out of sight")
check(adventure.person_hidden(c4, "mus_telpur"), "and is hidden")
local only = ties.add_lock(c4, { kind = "moment", moment = "mus_tidy", cond = { kind = "flag", flag = "water" } })
check(only ~= nil, "a moment can play only if something happened")
local mv = ties.add_tie(c4, { cond = { kind = "session", n = 1 }, effect = { kind = "hook", key = "mara", room = "gift_shop" } })
check(mv ~= nil, "a hero's reason for coming can move")
screen_text_ok(ties.describe(mv), "the hook tie's sentence")
local shop_seen, shop_cast, tidy_ok = false, nil, true
for w = 1, 3 do
    local p4 = c4:start_week()
    museum_week.prep_greedy(p4)
    local n4 = c4:start_night()
    local ev4 = play(n4)
    for _, sc in ipairs(n4.scenes or {}) do
        if sc.room == "gift_shop" and not sc.revisit then
            shop_seen = true
            shop_cast = sc.comps.cast
        end
    end
    if c4.adv.seen.mus_tidy and not c4.adv.flags.water then
        tidy_ok = false
    end
    c4:finish_night()
    if c4.adv.done.gift_shop then
        break
    end
end
check(shop_seen, "the gift shop played")
check(shop_cast == nil, "without Telpur")
check(not c4.adv.seen.mus_shopping and not c4.adv.seen.mus_telpur_bit, "Telpur's moments were skipped")
check(tidy_ok, "the moment only played if its condition held")
check(adventure.hook(c4, "mara").room == "gift_shop", "Thessaly's reason for coming moved to the gift shop")
check(mv.fired, "the hook tie fired")

-- 6. A save keeps them. ---------------------------------------------------------------------------
local c5 = new_campaign(25)
ties.add_lock(c5, { kind = "door", a = "entrance", b = "chamber", cond = { kind = "room", room = "paintings" } })
ties.add_lock(c5, { kind = "moment", moment = "mus_dice_painting", cond = { kind = "never" } })
ties.add_lock(c5, { kind = "person", person = "mus_mech", cond = { kind = "mark", mark = "pack" } })
ties.add_tie(c5, { cond = { kind = "flag", flag = "paint" }, effect = { kind = "mark", mark = "know" } })
ties.add_tie(c5, { cond = { kind = "room", room = "garden" }, effect = { kind = "hook", key = "dev", room = "chamber" } })
check(#ties.locks(c5) == 3 and #ties.ties(c5) == 2, "three locks and two ties set")
c5:start_week()
local text = save.dump(c5)
local back = assert(save.load(text))
adventure.enter(back)
check(#ties.locks(back) == 3 and #ties.ties(back) == 2, "they come back from a save")
check(adventure.way_closed(back, "entrance", "chamber"), "the locked door is still locked")
check(not adventure.moment_open(back, ties.moment("mus_dice_painting")), "the cut moment is still cut")
check(adventure.person_hidden(back, "mus_mech"), "the Mech still keeps out of sight")
for i, x in ipairs(ties.ties(c5)) do
    check(ties.describe(ties.ties(back)[i]) == ties.describe(x), "a tie reads the same after loading")
end
check(save.dump(back) == text, "and saves the same again")
-- An old save (before the editor) loads with none.
local old = new_campaign(26)
old.adv.locks, old.adv.ties, old.adv.hook_room, old.adv.lock_news, old.adv.tie_seq = nil, nil, nil, nil, nil
local old_back = assert(save.load(save.dump(old)))
adventure.enter(old_back)
check(#ties.locks(old_back) == 0 and #ties.ties(old_back) == 0, "an old save loads with no locks")

-- 7. Whole prologues finish with a few locks and ties set. -----------------------------------------
local function util_before(path, a, b)
    local ia, ib
    for i, step in ipairs(path) do
        if step.room == a and not ia then
            ia = i
        end
        if step.room == b and not ib then
            ib = i
        end
    end
    return ia ~= nil and (ib == nil or ia < ib)
end
local function prologue(seed, style)
    local cc = new_campaign(seed)
    local rng = require("game.model.rng").new(seed + 300)
    local set = {
        ties.add_lock(cc, { kind = "door", a = "entrance", b = "paintings", cond = { kind = "room", room = "chamber" } }),
        ties.add_lock(cc, { kind = "room", room = "stairs", cond = { kind = "room", room = "lecture" } }),
        ties.add_lock(cc, { kind = "door", a = "hunting", b = "lecture", cond = { kind = "room", room = "offices" } }),
        ties.add_lock(cc, { kind = "moment", moment = "mus_dice_painting", cond = { kind = "never" } }),
        ties.add_lock(cc, { kind = "person", person = "mus_telpur", cond = { kind = "room", room = "paintings" } }),
        ties.add_tie(cc, { cond = { kind = "room", room = "garden" }, effect = { kind = "mark", mark = "mirror" } }),
        ties.add_tie(cc, { cond = { kind = "session", n = 1 }, effect = { kind = "hook", key = "sam", room = "lecture" } }),
    }
    for i, x in ipairs(set) do
        check(x ~= nil, "prologue " .. seed .. " " .. style .. ": lock or tie " .. i .. " set")
    end
    local nights, empty = 0, 0
    local opened_line, shut_said = false, false
    for _ = 1, MODULE.MAX_WEEKS do
        local p = cc:start_week()
        for _, pr in ipairs(cc.adv.prompts) do
            if pr.kind == "request" then
                adventure.answer_request(cc, pr.id, MODULE.ANSWERS[rng:int(1, 4)])
            elseif pr.kind == "loose" then
                adventure.answer_loose(cc, pr.id, 1)
            elseif pr.kind == "favor" then
                adventure.answer_favor(cc, pr.id, 1, 1)
            end
        end
        museum_week.sync_ties(p, cc)
        if style ~= "careless" then
            museum_week.prep_greedy(p)
        end
        if p.museum.boss then
            cc.adv.boss = { opener = "talk", style = "yields" }
        end
        local n = cc:start_night()
        local e = play(n, style == "random" and rng or nil)
        opened_line = opened_line or said(e, "swings open") or said(e, "steps out of hiding")
        shut_said = shut_said or said(e, "won't open yet")
        if #(n.scenes or {}) == 0 then
            empty = empty + 1
        end
        cc:finish_night()
        nights = nights + 1
        cc:level_up()
        if adventure.over(cc) then
            break
        end
    end
    local s = cc.adv
    check(s.ending ~= nil and s.ending ~= "timeout", "prologue " .. seed .. " " .. style .. " reaches a real ending ("
        .. tostring(s.ending) .. ", " .. nights .. " nights)")
    check(empty == 0, "prologue " .. seed .. " " .. style .. ": no empty nights (" .. empty .. ")")
    check(s.done.lecture, "prologue " .. seed .. " " .. style .. ": the lecture theatre came before the stairs")
    check(s.marks.mirror, "prologue " .. seed .. " " .. style .. ": the tied mark is on her card")
    check(not s.seen.mus_dice_painting, "prologue " .. seed .. " " .. style .. ": the cut moment never played")
    check(opened_line, "prologue " .. seed .. " " .. style .. ": a lock opened with a line")
    check(shut_said, "prologue " .. seed .. " " .. style .. ": the table heard which way won't open yet")
    check(not s.done.lecture or (s.done.offices and util_before(s.path, "offices", "lecture")),
        "prologue " .. seed .. " " .. style .. ": the lecture theatre's door stayed shut until the offices were done")
    check(adventure.hook(cc, "sam").room == "lecture", "prologue " .. seed .. " " .. style .. ": Oswin's reason moved")
    -- The paintings never came before the chamber.
    local first_ch, first_pa
    for i, step in ipairs(s.path) do
        if step.room == "chamber" and not first_ch then
            first_ch = i
        end
        if step.room == "paintings" and not first_pa then
            first_pa = i
        end
    end
    check(not first_pa or (first_ch and first_ch < first_pa), "prologue " .. seed .. " " .. style
        .. ": the Hall of Paintings stayed shut until the chamber was done")
    return nights, s.ending
end
for _, style in ipairs({ "careful", "random", "careless" }) do
    for seed = 1, 3 do
        local n, e = prologue(seed, style)
        print(string.format("  prologue %d %s: %d nights, %s", seed, style, n, tostring(e)))
    end
end

print(string.format("ties and locks: %d checks, %d failed", checks, fails))
os.exit(fails == 0 and 0 or 1)
