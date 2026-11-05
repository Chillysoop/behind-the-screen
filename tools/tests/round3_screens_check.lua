-- The third playtest's screen findings (screens_newcomer.md, and the real-engine screenshots), played:
-- whole prologues through the real UI against the mock GUI (tools/tests/museum_smoke.lua with
-- SCREEN_CHECK=1, GLOSS_AUDIT=1 and DUMP_DIR), over a few seeds, and for each finding the evidence on
-- the screens it was seen on. Run from the project root:
--     lua tools/tests/round3_screens_check.lua [seed ...]      (default: 31 34 1 5; about a minute)
-- Prints one line per finding, what was seen, and FAIL lines where a screen contradicts the fix.
--
-- CUT    no text cut short ("...") without a hover over it that shows the whole of it
-- GLOSS  every game word on screen has its hover (tools/tests/gloss_words.lua), LOOSE END included
-- E11    the level-up cards: the ability raised, no "next session" after the last, nothing overlapping
-- E16    the report's NEW DICE is tonight's box (engine_screens 16)
-- E9     the wrap screen's quotes clear of their fun bars (engine_screens 9)
-- E3     game night's floating labels: the newest few, never a column of them (engine_screens 3)
-- S1     the prep board: the friends' forecasts, Euryale's marks, the rooms' summaries and Session Zero
--        asks, the boss night's choices and the spare hours, all in full
-- S2     the report's chain: every sentence of the night on the report, or on its "whole night" page
--        with a button to it
-- S6     a CARRYING list on the hero's sheet and the party page, with what they carry
-- S7     the table stats explained: what each is, which way it went, whether that's good; Goodwill and
--        the mood say what they are; no "Mood this week: ?"
-- S8     on game night a friend's face agrees with the words under it
-- S9     the thought card names the key and the button that are really there
-- S10    a read that falls short says why it still gets the gist
-- S12    the wrap screen's headline is the report's, and what it says of each friend is true
-- S13    the boss board says which wins when her card and the opening disagree
-- S14    the night's length is the same minute on the wrap card and the report
-- S16    the between-sessions screen promises only what it has, and the promise names its rule
-- S17    the journey's route never stops a room's story halfway
-- V      the camera sees the minis: every hero as a room opens and as they roll, the room's person, Euryale and
--        everyone through her talk, a fight's start (measured over many runs; walls and plinths by their height)
-- P      the polish list: one-of-a-kind minis by name, one colon to a voice, "has them", captions that
--        start with a capital, the People page, the session log on the newest, the map's labels, the
--        save slot, the death rule's note, the sheet's wish line, the last caption, no debug line

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path

local SEEDS = {}
for _, a in ipairs(arg or {}) do
    table.insert(SEEDS, tonumber(a))
end
if #SEEDS == 0 then
    SEEDS = { 31, 34, 1, 5 }
end

local fails, seen, order = {}, {}, {}
local function note(id)
    if not seen[id] then
        seen[id] = {}
        table.insert(order, id)
    end
end
local function fail(id, msg)
    note(id)
    fails[id] = fails[id] or {}
    if #fails[id] < 8 then
        table.insert(fails[id], msg)
    end
    fails[id].n = (fails[id].n or 0) + 1
end
local function add(id, key, n)
    note(id)
    seen[id][key] = (seen[id][key] or 0) + (n or 1)
end

local function norm(s)
    s = string.lower(string.gsub(s or "", "%s+", " "))
    return (string.gsub(string.gsub(s, "^ ", ""), " $", ""))
end
local function plain_find(hay, needle)
    return string.find(hay, needle, 1, true) ~= nil
end

-- One smoke run: its output lines and every screen it dumped.
local function run(seed)
    local dir = os.tmpname()
    os.remove(dir)
    os.execute("mkdir -p " .. dir)
    local fh = io.popen("SCREEN_CHECK=1 GLOSS_AUDIT=1 DUMP_DIR=" .. dir .. " lua tools/tests/museum_smoke.lua " .. seed .. " 2>&1")
    local out = fh:read("*a")
    fh:close()
    local r = { seed = seed, out = out, cuts = {}, gloss = {}, facts = {}, hovers = {}, dumps = {}, names = {} }
    for line in string.gmatch(out, "[^\n]+") do
        local f = {}
        for part in string.gmatch(line .. "\t", "(.-)\t") do
            table.insert(f, part)
        end
        if f[1] == "CUT_NO_HOVER" then
            table.insert(r.cuts, { dump = f[2], shown = f[3], full = f[4] })
        elseif string.find(line, "^GLOSS  ") then
            table.insert(r.gloss, line)
        elseif f[1] == "FACT" then
            -- (A screen dumped again under the same name, a second boss night's board: the file holds
            -- the last one, so the facts are the last one's too.)
            if r.last_fact ~= f[2] then
                r.facts[f[2]] = nil
            end
            r.last_fact = f[2]
            r.facts[f[2]] = r.facts[f[2]] or {}
            local key = f[3]
            r.facts[f[2]][key] = r.facts[f[2]][key] or {}
            table.insert(r.facts[f[2]][key], { (unpack or table.unpack)(f, 4) })
        elseif f[1] == "HOVER" then
            r.hovers[f[2]] = r.hovers[f[2]] or {}
            table.insert(r.hovers[f[2]], { label = f[3], at = f[4], said = f[5] })
        end
    end
    r.finished = string.find(out, "museum smoke " .. seed .. ":", 1, true) ~= nil
    r.problems = {}
    for p in string.gmatch(out, "PROBLEM: ([^\n]+)") do
        table.insert(r.problems, p)
    end
    local p = io.popen("ls " .. dir)
    for name in p:lines() do
        local base = string.match(name, "^(.+)%.txt$")
        if base and base ~= "board_minis" then
            local fd = io.open(dir .. "/" .. name)
            local texts, images, boxes = {}, {}, {}
            for line in fd:lines() do
                local f = {}
                for part in string.gmatch(line .. "\t", "(.-)\t") do
                    table.insert(f, part)
                end
                if f[1] == "box" and (f[12] or "-") ~= "-" and (tonumber(f[10]) or 1) > 0.01 then
                    table.insert(images, { x = tonumber(f[2]), y = 900 - tonumber(f[3]), image = f[12], w = tonumber(f[4]),
                                           h = tonumber(f[5]), pivot = f[6] })
                end
                if f[1] == "box" and (tonumber(f[10]) or 1) > 0.01 and f[6] == "nw" then
                    table.insert(boxes, { x = tonumber(f[2]), y = 900 - tonumber(f[3]), w = tonumber(f[4]), h = tonumber(f[5]) })
                end
                if f[1] == "text" and (f[15] or "") ~= "" and (tonumber(f[10]) or 1) > 0.01 then
                    table.insert(texts, { x = tonumber(f[2]), y = 900 - tonumber(f[3]), font = f[11], pivot = f[6],
                                          text = string.gsub(f[15], "\\n", "\n") })
                end
            end
            fd:close()
            local joined = {}
            for _, t in ipairs(texts) do
                table.insert(joined, t.text)
            end
            r.dumps[base] = { texts = texts, images = images, boxes = boxes, joined = norm(table.concat(joined, " ")) }
            table.insert(r.names, base)
        end
    end
    p:close()
    table.sort(r.names)
    os.execute("rm -r " .. dir)
    return r
end

local function facts(r, dump, key)
    return (r.facts[dump] or {})[key] or {}
end
local function has(r, dump, s)
    local d = r.dumps[dump]
    return d and plain_find(d.joined, norm(s))
end
local function each_dump(r, pattern, fn)
    for _, name in ipairs(r.names) do
        if string.find(name, pattern) then
            fn(name, r.dumps[name])
        end
    end
end
-- A text cut short on screen ("..." at the end of one of its lines).
local function is_cut(text)
    for line in string.gmatch(text .. "\n", "(.-)\n") do
        if string.find(line, "%.%.%.$") then
            return true
        end
    end
    return false
end

local FORECASTS = { "Will love it", "Should enjoy it", "Probably fine", "May be bored", "May check out" }

-- Two pieces of text drawn over each other on a screen with nothing over it (the real-engine run's
-- overlaps): by the fonts' own metrics (game/ui/metrics.lua), as the engine lays them out.
local metrics = dofile("game/ui/metrics.lua")
local PX = { nw = 0, w = 0, sw = 0, n = 0.5, c = 0.5, s = 0.5, ne = 1, e = 1, se = 1 }
local PY = { nw = 0, n = 0, ne = 0, w = 0.5, c = 0.5, e = 0.5, sw = 1, s = 1, se = 1 }
local function rect_of(t)
    local m = metrics[t.font]
    if not m then
        return nil
    end
    local w, h = 0, 0
    for line in string.gmatch(t.text .. "\n", "(.-)\n") do
        local lw = 0
        for i = 1, #line do
            local b = string.byte(line, i)
            if b < 32 or b > 126 then
                b = 32
            end
            lw = lw + m.adv[b - 31]
        end
        w, h = math.max(w, lw), h + m.line
    end
    local left, top = t.x - (PX[t.pivot] or 0) * w, t.y - (PY[t.pivot] or 0) * h
    return left, top, left + w, top + h
end
local function overlaps_in(d)
    local out = {}
    local rs = {}
    for _, t in ipairs(d.texts) do
        local l, tp, r, b = rect_of(t)
        if l then
            table.insert(rs, { l, tp, r, b, t.text })
        end
    end
    for i = 1, #rs do
        for j = i + 1, #rs do
            local a, b = rs[i], rs[j]
            if math.min(a[3], b[3]) - math.max(a[1], b[1]) > 4 and math.min(a[4], b[4]) - math.max(a[2], b[2]) > 6 then
                table.insert(out, string.sub(string.gsub(a[5], "\n", " "), 1, 50) .. "\" over \"" .. string.sub(string.gsub(b[5], "\n", " "), 1, 50))
            end
        end
    end
    return out
end

local runs = {}
for _, seed in ipairs(SEEDS) do
    io.write("smoke " .. seed .. "... ")
    io.flush()
    local r = run(seed)
    print(r.finished and (#r.names .. " screens") or "did not finish")
    table.insert(runs, r)
    if not r.finished then
        fail("RUN", "seed " .. seed .. ": the smoke run didn't finish: " .. string.sub(r.out, -400))
    end
    for _, p in ipairs(r.problems) do
        fail("RUN", "seed " .. seed .. ": " .. p)
    end
end

for _, r in ipairs(runs) do
    local S = "seed " .. r.seed .. " "

    -- CUT: every text cut short has a hover with the whole of it. -------------------------------------
    add("CUT", "screens", #r.names)
    for _, cut in ipairs(r.cuts) do
        fail("CUT", S .. cut.dump .. ": \"" .. cut.shown .. "\" is cut, and nothing over it shows \"" .. string.sub(cut.full, 1, 90) .. "\"")
    end

    -- GLOSS: every game word has its hover. --------------------------------------------------------------
    for _, g in ipairs(r.gloss) do
        fail("GLOSS", S .. g)
    end
    if string.find(r.out, "0 game words on screen without a hover", 1, true) then
        add("GLOSS", "runs_clean")
    end

    -- S1: the prep board in full. ---------------------------------------------------------------------------
    each_dump(r, "^4", function(name, d)
        local board = name:find("^4_prep") or name:find("^4c_") or name:find("^4t_board") or name:find("^4b_")
        for _, t in ipairs(d.texts) do
            if is_cut(t.text) and t.x >= 1196 then
                local stem = string.gsub(t.text, "%.%.%.$", "")
                for _, f in ipairs(FORECASTS) do
                    if stem ~= "" and string.sub(f, 1, #stem) == stem then
                        fail("S1", S .. name .. ": a friend's forecast is cut: \"" .. t.text .. "\"")
                    end
                end
            end
            if t.x >= 1196 and t.y > 100 and board then
                for _, f in ipairs(FORECASTS) do
                    if t.text == f then
                        add("S1", "forecasts_whole")
                    end
                end
            end
        end
        if not board then
            return
        end
        -- Her marks: what each changes, in full, on the board's UPSTAIRS card (unless it says there are more).
        local more = plain_find(d.joined, "more: notes, upstairs")
        for _, m in ipairs(facts(r, name, "mark")) do
            if has(r, name, m[1]) then
                add("S1", "marks_whole")
            elseif not more then
                fail("S1", S .. name .. ": Euryale's mark isn't there in full: \"" .. m[1] .. "\"")
            end
        end
        -- Tonight's rooms on this page: the summary and every Session Zero ask in full.
        for _, rm in ipairs(facts(r, name, "room")) do
            local on_page = false
            for _, t in ipairs(d.texts) do
                on_page = on_page or (t.text == rm[1] and t.font == "ui18b")
            end
            if on_page and not name:find("^4b_") then
                if has(r, name, rm[2]) then
                    add("S1", "room_summaries_whole")
                else
                    fail("S1", S .. name .. ": " .. rm[1] .. "'s summary is cut: \"" .. rm[2] .. "\"")
                end
                for _, a in ipairs(facts(r, name, "ask")) do
                    if a[1] == rm[1] then
                        if has(r, name, a[2]) then
                            add("S1", "asks_whole")
                        else
                            fail("S1", S .. name .. ": a Session Zero ask is cut: \"" .. a[2] .. "\"")
                        end
                    end
                end
            end
        end
        if has(r, name, "SPARE HOURS") then
            for _, sp in ipairs(facts(r, name, "spare")) do
                if has(r, name, sp[1]) then
                    add("S1", "spare_hours_whole")
                else
                    fail("S1", S .. name .. ": a spare-hours line is cut: \"" .. sp[1] .. "\"")
                end
            end
        end
        for _, b in ipairs(facts(r, name, "blurb")) do
            if has(r, name, b[1]) then
                add("S1", "boss_choices_whole")
            else
                fail("S1", S .. name .. ": a boss-night choice is cut: \"" .. b[1] .. "\"")
            end
        end
        -- The map's marks (stairs, their arrows, the party's dots) never on a room's name (the engine run).
        if name:find("^4_prep") or name:find("^4b_") then
            for _, im in ipairs(d.images) do
                local mark = string.find(im.image, "^icon_stairs") or string.find(im.image, "^icon_up") or string.find(im.image, "^icon_down")
                    or (im.image == "dot" and im.w == 8)
                if mark and im.y < 420 then
                    local il = im.x - (PX[im.pivot] or 0) * im.w
                    local it = im.y - (PY[im.pivot] or 0) * im.h
                    for _, t in ipairs(d.texts) do
                        if t.font == "ui14" and t.pivot == "n" and t.y < 420 and t.x > 420 then
                            local l, tp, rr, b = rect_of(t)
                            if il < rr - 1 and il + im.w > l + 1 and it < b - 2 and it + im.h > tp + 2 then
                                fail("P", S .. name .. ": " .. im.image .. " on the map lands on \"" .. t.text .. "\"")
                            end
                        end
                    end
                    add("P", "map_marks")
                end
            end
        end
        -- The map's labels on the prep board.
        if name:find("^4_prep") then
            for _, t in ipairs(d.texts) do
                if t.y > 80 and t.y < 300 and t.x > 420 and t.x < 1180 and is_cut(t.text) then
                    fail("P", S .. name .. ": a room's name on the map is cut: \"" .. t.text .. "\"")
                end
            end
        end
    end)

    -- S2: the report's chain, all of it. --------------------------------------------------------------------
    each_dump(r, "^6_report_w", function(name, d)
        local week = string.match(name, "_w(%d+)$")
        local page = r.dumps["6c_chain_w" .. week]
        local missing, on_report = 0, 0
        for _, line in ipairs(facts(r, name, "chain")) do
            local s = norm(line[1])
            if plain_find(d.joined, s) then
                on_report = on_report + 1
            elseif page and plain_find(page.joined, s) then
                add("S2", "on_the_whole_night_page")
            else
                missing = missing + 1
                fail("S2", S .. name .. ": the chain's \"" .. line[1] .. "\" is on neither the report nor its whole-night page")
            end
        end
        add("S2", "on_the_report", on_report)
        if on_report < #facts(r, name, "chain") and not plain_find(d.joined, "the whole night") then
            fail("S2", S .. name .. ": the chain doesn't all fit, and nothing says there's more")
        end
        if page then
            add("S2", "whole_night_pages")
        end
        -- E16: "NEW DICE" is tonight's box, by name, or it isn't said (the engine run: Rose quartz every week).
        local nd = facts(r, name, "new_dice")[1]
        if nd then
            for i, t in ipairs(d.texts) do
                if t.text == "NEW DICE" then
                    local next_t = d.texts[i + 1]
                    if nd[1] == "-" then
                        fail("E16", S .. name .. ": \"NEW DICE\" with no box opened tonight")
                    elseif not (next_t and string.find(next_t.text, nd[1], 1, true)) then
                        fail("E16", S .. name .. ": \"NEW DICE\" shows \"" .. tostring(next_t and next_t.text) .. "\", tonight's box was " .. nd[1])
                    else
                        add("E16", "new_dice_right")
                    end
                end
            end
        end
        -- The wrap-up's "+N" says where the rest is, truly.
        if plain_find(d.joined, "in your notes") then
            fail("S2", S .. name .. ": the wrap-up says \"in your notes\", and the notes don't have it")
        end
        -- P: no debug line; a pick-up of several things "has them"; snapshot captions start with a capital.
        if plain_find(d.joined, "playtest notes are saved") then
            fail("P", S .. name .. ": the debug line \"Playtest notes are saved after every week\" is still there")
        end
        for _, t in ipairs(d.texts) do
            if string.find(t.text, "^Picked up: .- and .-%(%u%l+ has it%)") then
                fail("P", S .. name .. ": \"" .. t.text .. "\" (several things, \"has it\")")
            end
            if t.font == "ui14" and t.y > 500 and t.y < 640 and string.find(t.text, "^%l") and string.find(t.text, "%.$")
                and t.x > 30 and t.x < 760 then
                fail("P", S .. name .. ": a snapshot caption starts small: \"" .. t.text .. "\"")
            end
        end
    end)

    -- S6: CARRYING on the sheet and the party page. ----------------------------------------------------------
    each_dump(r, "^4h_hero_sheet", function(name, d)
        if not plain_find(d.joined, "carrying") then
            fail("S6", S .. name .. ": the hero sheet has no CARRYING list")
        else
            add("S6", "sheets_with_carrying")
        end
        for key, list in pairs(r.facts[name] or {}) do
            if string.find(key, "^carry_") then
                for _, it in ipairs(list) do
                    if it[1] ~= "-" then
                        if has(r, name, it[1]) then
                            add("S6", "things_listed")
                        else
                            fail("S6", S .. name .. ": the sheet doesn't list \"" .. it[1] .. "\"")
                        end
                    end
                end
            end
        end
    end)
    each_dump(r, "^4n_notes_party", function(name, d)
        local n = 0
        for _, t in ipairs(d.texts) do
            if t.text == "CARRYING" then
                n = n + 1
            end
        end
        if n == 0 then
            fail("S6", S .. name .. ": the party page has no CARRYING list")
        end
        add("S6", "party_page_lists", n)
        for key, list in pairs(r.facts[name] or {}) do
            if string.find(key, "^carry_") then
                for _, it in ipairs(list) do
                    if it[1] ~= "-" then
                        if has(r, name, it[1]) then
                            add("S6", "things_listed")
                        else
                            fail("S6", S .. name .. ": the party page doesn't list \"" .. it[1] .. "\"")
                        end
                    end
                end
            end
        end
    end)

    -- S7: the table stats explained. -------------------------------------------------------------------------
    for _, name in ipairs(r.names) do
        if r.dumps[name] and plain_find(r.dumps[name].joined, "mood this week: ?") then
            fail("S7", S .. name .. ": \"Mood this week: ?\" says nothing")
        end
        for _, h in ipairs(r.hovers[name] or {}) do
            local said = norm(h.said)
            if h.label == "Commitment" or h.label == "Investment" or h.label == "Trust" or h.label == "Suspicion" then
                if not (plain_find(said, "is better") and plain_find(said, string.lower(h.label))) then
                    fail("S7", S .. name .. ": " .. h.label .. "'s hover doesn't say what it is and which way is good: " .. string.sub(h.said, 1, 120))
                else
                    add("S7", "stat_hovers")
                end
                if string.find(name, "^6_report") and not plain_find(said, "tonight") then
                    fail("S7", S .. name .. ": " .. h.label .. "'s row on the report doesn't say how it moved tonight")
                end
            elseif string.find(h.label, "^[%+%-=]") and string.find(name, "^6_report") then
                if not (plain_find(said, "tonight") and (plain_find(said, "good") or plain_find(said, "worry") or plain_find(said, "same"))) then
                    fail("S7", S .. name .. ": a \"" .. h.label .. "\" mark's hover doesn't say if that's good: " .. string.sub(h.said, 1, 120))
                else
                    add("S7", "mark_hovers")
                end
            elseif h.label == "Goodwill" then
                if plain_find(said, "how fond") then
                    add("S7", "goodwill_hovers")
                else
                    fail("S7", S .. name .. ": Goodwill's hover doesn't say what it is: " .. string.sub(h.said, 1, 120))
                end
            elseif string.find(h.label, "^Mood: ") then
                if h.said ~= "-" and plain_find(said, "week") then
                    add("S7", "mood_hovers")
                else
                    fail("S7", S .. name .. ": \"" .. h.label .. "\" has no hover saying what it is")
                end
            end
        end
    end

    -- S9: the thought card's key. -----------------------------------------------------------------------------
    each_dump(r, "^5t_thought", function(name, d)
        if plain_find(d.joined, "table sidebar tonight (s)") then
            fail("S9", S .. name .. ": the tip sends you to \"the Table sidebar tonight (S)\"")
        end
        if plain_find(d.joined, "s recap") then
            fail("S9", S .. name .. ": the key strip says \"S recap\" for the Story and Table sidebars")
        end
        if plain_find(d.joined, "table button") then
            add("S9", "tips_naming_the_button")
        end
    end)

    -- S10: a read that falls short. ---------------------------------------------------------------------------
    each_dump(r, "^5t_thought_read", function(name, d)
        for _, rd in ipairs(facts(r, name, "read")) do
            local result, dc, total = rd[1], tonumber(rd[2]), tonumber(rd[3])
            add("S10", "reads_" .. result)
            if result ~= "asked" and not plain_find(d.joined, "needing " .. dc) then
                fail("S10", S .. name .. ": the read's line doesn't give the total it needed (" .. dc .. ")")
            end
            if result == "gist" and not plain_find(d.joined, "gets the gist") then
                fail("S10", S .. name .. ": a total of " .. total .. " against " .. dc .. " still answers, and nothing says why")
            end
        end
    end)

    -- S12: the wrap screen's headline. ------------------------------------------------------------------------
    each_dump(r, "^6r_rewards_w", function(name, d)
        local hl = facts(r, name, "headline")[1]
        if hl and hl[1] ~= "" then
            if has(r, name, hl[1]) then
                add("S12", "headlines_as_the_report")
            else
                fail("S12", S .. name .. ": the wrap screen's headline isn't the report's (\"" .. hl[1] .. "\")")
            end
        end
        local loved = false
        for _, t in ipairs(facts(r, name, "tier")) do
            loved = loved or t[2] == "loved"
        end
        if not loved and plain_find(d.joined, "some loved it") then
            fail("S12", S .. name .. ": \"some loved it\", and nobody did")
        end
        local last = facts(r, name, "last")[1]
        if last and last[1] == "yes" and plain_find(d.joined, "next week") then
            fail("S12", S .. name .. ": the last night's wrap talks about next week")
        end
        for _, t in ipairs(facts(r, name, "tier")) do
            if t[2] ~= "nil" and has(r, name, t[1]) then
                add("S12", "friends_named")
            end
        end
    end)

    -- S13: her card against the opening. ---------------------------------------------------------------------
    each_dump(r, "^4b_showdown", function(name, d)
        local op, burned = facts(r, name, "opener")[1], facts(r, name, "garden_burned")[1]
        if op and burned and op[1] == "talk" and burned[1] == "yes" then
            if plain_find(d.joined, "her card wins") then
                add("S13", "boards_that_say_which_wins")
            else
                fail("S13", S .. name .. ": \"She skips the drink\" beside \"a drink, some questions\", and nothing says which wins")
            end
        else
            add("S13", "boards_with_no_clash")
        end
    end)

    -- S14: the night's length, to the minute. -----------------------------------------------------------------
    each_dump(r, "^5_night_end_w", function(name, d)
        local week = string.match(name, "_w(%d+)$")
        local rep = r.dumps["6_report_w" .. week]
        local wrap = string.match(d.joined, "(%d+h ?%d*m?) at the table") or string.match(d.joined, "(%d+m) at the table")
        local said = rep and (string.match(rep.joined, "time %((%d+h[^,%)]*)") or string.match(rep.joined, "long %((%d+h[^,%)]*)")
            or string.match(rep.joined, "early %((%d+h[^,%)]*)") or string.match(rep.joined, "time %((%d+m)%)")
            or string.match(rep.joined, "early %((%d+m)%)")
            -- (Run long past the end agreed at Session Zero, batch A's words: "Ran 30m past the 10:00 pm
            -- you agreed at Session Zero (3h 30m at the table).")
            or string.match(rep.joined, "%((%d+h ?%d*m?) at the table%)") or string.match(rep.joined, "%((%d+m) at the table%)"))
        if wrap and rep and not said then
            fail("S14", S .. name .. ": the report doesn't say how long the night ran (" .. wrap .. ") where you can see it")
        end
        if wrap and said then
            wrap = string.gsub(string.gsub(wrap, " 0(%d)m", " %1m"), " 00m", "")
            if wrap == said then
                add("S14", "lengths_that_agree")
            else
                fail("S14", S .. name .. ": " .. wrap .. " at the table, and the report says " .. said)
            end
        end
    end)

    -- S16: between sessions. ------------------------------------------------------------------------------------
    each_dump(r, "^3_between", function(name, d)
        add("S16", "screens")
        if plain_find(d.joined, "what's changed since last time") then
            fail("S16", S .. name .. ": the subtitle promises \"what's changed since last time\", and there's no such part")
        end
        if plain_find(d.joined, "quick call on that rule") then
            fail("S16", S .. name .. ": the promise doesn't say which rule")
        end
    end)

    -- S17: the journey's route. ---------------------------------------------------------------------------------
    each_dump(r, "^7_journey", function(name, d)
        for _, t in ipairs(d.texts) do
            if string.find(t.text, "^%d+%. ") and t.x > 400 and t.x < 1000 then
                add("S17", "route_rows")
                if is_cut(t.text) then
                    fail("S17", S .. name .. ": a room's story on the route is cut: \"" .. t.text .. "\"")
                end
            end
        end
    end)

    -- P: nothing drawn over anything else on the screens with no overlay. --------------------------------------
    for _, name in ipairs(r.names) do
        local d = r.dumps[name]
        local bare = name:find("^4_prep_w") or name:find("^4b_") or name:find("^4c_") or name:find("^6c_")
            or name:find("^6r_rewards_w%d+$") or name:find("^7_journey") or name:find("^3_between")
            or (name:find("^6_report_w") and not plain_find(d.joined, "as everyone packs up"))
        -- (A first-session tip is a panel over the screen on purpose.)
        if bare and not plain_find(d.joined, "hide tips") then
            add("P", "screens_free_of_overlaps")
            for _, o in ipairs(overlaps_in(d)) do
                fail("P", S .. name .. ": text drawn over text: \"" .. o .. "\"")
            end
        end
    end

    -- E3: the words rising off the minis never pile up (the engine run, 8_51: eighteen in a column).
    for _, fl in ipairs(facts(r, "night", "floaters")) do
        local all, one = tonumber(fl[1]), tonumber(fl[2])
        add("E3", "most_at_once", all)
        if all > 6 or one > 2 then
            fail("E3", S .. "game night had " .. all .. " floating labels at once, " .. one .. " on one mini")
        end
    end

    -- E11: the level-up cards name what went up; no "next session" once the prologue's over (8_56, 8_28).
    each_dump(r, "^6b_levelup", function(name, d)
        local lv, last = facts(r, name, "level")[1], facts(r, name, "last")[1]
        if lv and lv[1] == "4" then
            add("E11", "level_4_screens")
            for _, t in ipairs(d.texts) do
                if t.text == "+2 to their best ability" then
                    fail("E11", S .. name .. ": a level-4 card says only \"+2 to their best ability\"")
                end
            end
            local named = 0
            for _, ab in ipairs({ "STRENGTH", "DEXTERITY", "CONSTITUTION", "INTELLIGENCE", "WISDOM", "CHARISMA" }) do
                for _, t in ipairs(d.texts) do
                    if t.text == "+2 " .. ab then
                        named = named + 1
                    end
                end
            end
            add("E11", "abilities_named", named)
        end
        if last and last[1] == "yes" and plain_find(d.joined, "for next session") then
            fail("E11", S .. name .. ": the last level-up says \"for next session\"")
        end
        -- The headline clear of the line under it (on top of the report, so only these two).
        local head, sub
        for _, t in ipairs(d.texts) do
            if string.find(t.text, "^LEVEL %d!$") then
                head = t
            elseif string.find(t.text, "^Everyone picks a subclass") or string.find(t.text, "^Everyone takes an Ability") then
                sub = t
            end
        end
        if head and sub then
            local _, _, _, hb = rect_of(head)
            local _, st = rect_of(sub)
            if st < hb - 2 then
                fail("E11", S .. name .. ": \"" .. head.text .. "\" sits on \"" .. sub.text .. "\"")
            else
                add("E11", "headlines_clear")
            end
        end
    end)

    -- E9: on the wrap screen a friend's quote never runs into their fun bar (the engine run, 8_15).
    each_dump(r, "^6r_rewards_w%d+$", function(name, d)
        for _, t in ipairs(d.texts) do
            if string.sub(t.text, 1, 1) == "\"" and t.x > 300 and t.x < 340 then
                local l, tp, rr, b = rect_of(t)
                add("E9", "quotes")
                for _, bx in ipairs(d.boxes) do
                    if bx.h == 10 and bx.w > 100 and bx.x < rr and bx.x + bx.w > l and bx.y < b and bx.y + bx.h > tp then
                        fail("E9", S .. name .. ": a quote runs into its fun bar: " .. string.sub(t.text, 1, 60))
                    end
                end
            end
        end
    end)

    -- S8: on game night a friend's face agrees with the words under it (no frown beside "listening").
    each_dump(r, "^5", function(name, d)
        for _, im in ipairs(d.images) do
            if string.find(im.image, "^face_%a+_frown$") then
                for _, t in ipairs(d.texts) do
                    if (t.text == "listening" or t.text == "grinning" or t.text == "leaning in") and t.x > im.x and t.x - im.x < 330
                        and math.abs(t.y - im.y) < 80 then
                        fail("S8", S .. name .. ": " .. im.image .. " beside \"" .. t.text .. "\"")
                    end
                end
            elseif string.find(im.image, "^face_%a+") then
                add("S8", "faces")
            end
        end
    end)

    -- P: the polish list. ---------------------------------------------------------------------------------------
    for _, name in ipairs(r.names) do
        local d = r.dumps[name]
        if plain_find(d.joined, "minis: 1 the ") then
            fail("P", S .. name .. ": \"Minis: 1 the ...\" for a one-of-a-kind foe")
        end
        for _, t in ipairs(d.texts) do
            if string.find(t.text, "Voice: %u%l+: ") then
                fail("P", S .. name .. ": two colons in \"" .. string.sub(t.text, 1, 60) .. "\"")
            end
            if string.find(t.text, "^The prologue is over: your table's%.%.%.") then
                fail("P", S .. name .. ": the finished save's label is cut")
            end
        end
        if plain_find(d.joined, "each player can still ask for their own") then
            fail("P", S .. name .. ": the death rule's note is cryptic (\"Each player can still ask for their own.\")")
        end
        if plain_find(d.joined, "would rather: their choice") then
            fail("P", S .. name .. ": \"would rather: their choice.\"")
        end
        for _, t in ipairs(d.texts) do
            if (string.find(t.text, " would rather: ") or string.find(t.text, " wants: ") or string.find(t.text, " wants it to be "))
                and is_cut(t.text) then
                fail("P", S .. name .. ": the sheet's wish line is cut: \"" .. t.text .. "\"")
            end
        end
    end
    each_dump(r, "^4n_notes_people", function(name, d)
        local n = 0
        for _, t in ipairs(d.texts) do
            if t.text == "Someone they haven't met" then
                n = n + 1
            end
        end
        if n > 1 then
            fail("P", S .. name .. ": \"Someone they haven't met\" " .. n .. " times")
        end
        add("P", "people_pages")
    end)
    each_dump(r, "^4n_notes_log", function(name, d)
        local newest = facts(r, name, "newest")[1]
        if newest and newest[1] ~= "-" then
            if has(r, name, "SESSION " .. newest[1]) then
                add("P", "logs_on_the_newest")
            else
                fail("P", S .. name .. ": the session log doesn't open on the newest session (" .. newest[1] .. ")")
            end
        end
    end)
    -- The night's last caption isn't under the wrap card.
    each_dump(r, "^5_night_end_w", function(name, d)
        local card
        for _, t in ipairs(d.texts) do
            if t.text == "That's a wrap for tonight." then
                card = t
            end
        end
        if card then
            local cy = card.y - 18
            for _, t in ipairs(d.texts) do
                if t.font == "story22" or t.font == "read26" then
                    local lines = select(2, string.gsub(t.text, "\n", "")) + 1
                    local top = t.pivot == "n" and t.y or t.y
                    local bottom = top + lines * 30
                    if top < cy + 132 and bottom > cy and t.x > 300 and t.x < 1300 then
                        fail("P", S .. name .. ": the night's last caption is under the wrap card: \"" .. string.sub(t.text, 1, 60) .. "\"")
                    end
                end
            end
            add("P", "wrap_cards")
        end
    end)
end

-- V: what the camera sees of the minis (the confirming playtest's real-engine run: Euryale and Pip missing
-- from the boss night's frame, three of four heroes hidden behind the offices' partitions, Thessaly behind a
-- cabinet). Measured in the model over many runs (tools/sim/museum.lua with VIEW=1, tools/tests/view_watch.lua:
-- its own geometry from main/scene_data.lua's Table camera and every piece's height in game/data/props.lua):
-- each hero as a room opens, the hero rolling a check, the room's person when they speak, Euryale and every
-- hero through her talk, and everyone as a fight starts. On bfa5157 (these six seeds, three DMs each): the hero
-- rolling 56% seen, boss night's talk 80% (Mara behind the landing's wall), a room opening 96%, a fight's start 97%.
local VIEW_RUNS = os.getenv("VIEW_SEEDS") or "51 52 53 54 1 5"
do
    local n, ok, misses, measured = {}, {}, {}, 0
    for seed in string.gmatch(VIEW_RUNS, "%d+") do
        for _, style in ipairs({ "careful", "random", "careless" }) do
            local fh = io.popen("VIEW=1 lua tools/sim/museum.lua " .. seed .. " " .. style .. " 2>&1")
            for line in fh:lines() do
                local kind, good, all = string.match(line, "^VIEW\t(%a+)\t(%d+)\t(%d+)$")
                if kind then
                    measured = measured + 1
                    n[kind] = (n[kind] or 0) + tonumber(all)
                    ok[kind] = (ok[kind] or 0) + tonumber(good)
                end
                local miss = string.match(line, "^VIEW_MISS\t(.+)$")
                if miss and #misses < 12 then
                    table.insert(misses, "seed " .. seed .. " " .. style .. ": " .. string.gsub(miss, "\t", " "))
                end
            end
            fh:close()
        end
    end
    if measured == 0 then
        fail("V", "the sim measured nothing (VIEW=1 tools/sim/museum.lua prints no VIEW lines)")
    end
    -- Every kind of moment, each nearly always seen (and the boss's talk always).
    local NEED = { stage = 0.98, acting = 0.98, speaks = 0.98, boss = 1.0, fight = 0.98 }
    for _, kind in ipairs({ "stage", "acting", "speaks", "boss", "fight" }) do
        local share = (n[kind] or 0) > 0 and ok[kind] / n[kind] or 0
        add("V", kind .. "_seen_pct", math.floor(share * 1000 + 0.5) / 10)
        if (n[kind] or 0) == 0 then
            fail("V", "no " .. kind .. " moments measured")
        elseif share < NEED[kind] then
            fail("V", kind .. ": " .. ok[kind] .. " of " .. n[kind] .. " minis seen by the camera (" .. string.format("%.1f%%", share * 100)
                .. "), and " .. math.floor(NEED[kind] * 100) .. "% are wanted")
        end
    end
    if fails.V then
        for _, m in ipairs(misses) do
            fail("V", "missed: " .. m)
        end
    end
    -- The model's camera (game/model/sight.lua) is the game's: main/scene_data.lua's Table preset and grid.
    local sight = require "game.model.sight"
    local W = dofile("tools/tests/view_watch.lua").scene
    if not sight.EYE_H then
        fail("V", "game/model/sight.lua has no camera (EYE_H, EYE_Z, EYE_X): placing a mini doesn't ask what the camera sees")
    else
        local eh = W.eye[2] - W.y
        local ez = W.eye[3] - (W.z0 - W.size / 2)
        local ex = (W.eye[1] - W.x0) / W.size + 0.5
        if math.abs(sight.EYE_H - eh) > 0.05 or math.abs(sight.EYE_Z - ez) > 0.05 or math.abs(sight.EYE_X - ex) > 0.05
            or math.abs(sight.MINI_H - W.mini_h) > 0.01 then
            fail("V", string.format("sight.lua's camera (%.2f, %.2f, %.2f) isn't main/scene_data.lua's (%.2f, %.2f, %.2f)",
                sight.EYE_H, sight.EYE_Z, sight.EYE_X, eh, ez, ex))
        else
            add("V", "camera_matches_scene_data")
        end
        -- Cases: the offices' partitions hide the next two rows (8_36), the lair's landing wall the next two
        -- (8_53), and a square three rows back shows.
        local board = require "game.model.board"
        local off = board.compile("museum_offices").occ
        local lair = board.compile("museum_lair").occ
        local cases = {
            { off, 4, 8, false, "the offices' hall, straight behind the south partition" },
            { off, 4, 7, false, "the offices' hall, two rows behind the partition" },
            { off, 8, 6, true, "the offices' hall, three rows back from the partition" },
            { off, 10, 3, false, "the archivist's desk, behind the north partition" },
            { lair, 4, 9, false, "the lair's landing, behind its south wall" },
            { lair, 14, 9, true, "in front of Euryale's couch" },
        }
        for _, cs in ipairs(cases) do
            local seen = sight.shows(cs[1], cs[2], cs[3])
            local truth = W and dofile("tools/tests/view_watch.lua").shows(cs[1] == off and "museum_offices" or "museum_lair", cs[2], cs[3])
            if seen ~= cs[4] or truth ~= cs[4] then
                fail("V", cs[5] .. " (" .. cs[2] .. "," .. cs[3] .. "): the game says " .. (seen and "seen" or "hidden") .. ", the measure "
                    .. (truth and "seen" or "hidden") .. ", and it should be " .. (cs[4] and "seen" or "hidden"))
            else
                add("V", "cases")
            end
        end
    end
end

-- What each finding saw, and the failures. -------------------------------------------------------------------
local IDS = { "RUN", "CUT", "GLOSS", "E3", "E9", "E11", "E16", "S1", "S2", "S6", "S7", "S8", "S9", "S10", "S12", "S13", "S14", "S16", "S17", "P", "V" }
for _, id in ipairs(IDS) do
    note(id)
end
local nfail = 0
for _, id in ipairs(IDS) do
    local bits = {}
    local keys = {}
    for k in pairs(seen[id] or {}) do
        table.insert(keys, k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        table.insert(bits, k .. " " .. seen[id][k])
    end
    print(string.format("%-6s %s", id, #bits > 0 and table.concat(bits, ", ") or "-"))
    for _, m in ipairs(fails[id] or {}) do
        print("  FAIL " .. m)
    end
    if fails[id] then
        nfail = nfail + fails[id].n
        if fails[id].n > #fails[id] then
            print("  ... and " .. (fails[id].n - #fails[id]) .. " more")
        end
    end
end
-- Evidence that each finding was really looked at, not just never seen.
local need = { CUT = "screens", S2 = "on_the_report", S6 = "things_listed", S7 = "stat_hovers", S12 = "headlines_as_the_report",
               S16 = "screens", S17 = "route_rows", S1 = "marks_whole", V = "cases" }
for id, k in pairs(need) do
    if not (seen[id] and seen[id][k]) then
        print("  FAIL " .. id .. ": never saw " .. k)
        nfail = nfail + 1
    end
end
print(nfail == 0 and "round3 screens: all clear" or ("round3 screens: " .. nfail .. " failures"))
os.exit(nfail == 0 and 0 or 1)
