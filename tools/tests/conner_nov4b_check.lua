-- Conner's playtest of the November 4 build, the rest of his points (docs/playtests/2026-11-04/
-- conner-feedback/README.md; docs/design/2026-11-05-root-causes.md, classes 2 and 6 to 9). Whole
-- prologues (the museum sim in this process, three DMs) watched event by event, plus targeted cases.
-- Each item fails on 1ea3901. Run from the project root:
--     lua tools/tests/conner_nov4b_check.lua [seeds]
--   M   movement: every walk is a real one, a step at a time on open floor; a check rolled somewhere else
--       is walked to first; an ally the party brought rides back with them (C19, C24)
--   F   faces: the first night starts smiling; nobody looks cheerful while their hero is dying, stone or dead,
--       or the table grieves (C1, C27)
--   L   layout: every face at the table inside the Table view and under the top bar; a hero speaking in
--       character stands as tall as their player; the caption, the friends' speech and the tags each have their
--       own band; the death-save card on the dying hero's own tile (C2, C9, C27)
--   S   structure: a split party cuts to each one alone and regroups; the find card shows the poking hero's
--       Investigation total; a night opens on the board where they stopped; the snacks follow the clock
--       (C10, C11, C13, C18)

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local SEEDS = tonumber(arg[1]) or 4
local FIRST = 71
local STYLES = { "careful", "random", "careless" }
local ITEMS = { "run", "M", "F", "L", "S" }
local NAMES = { run = "whole prologues", M = "movement", F = "faces and moods", L = "layout", S = "structure" }

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

-- Every move a night makes, checked as it's made: where the mini was, and each step of the way.
local sight = require "game.model.sight"
local MV = { walks = 0, steps = 0, bad = {}, slides = 0, ally_fights = 0, rides = 0 }
local function bad_move(self, what)
    if #MV.bad < 8 then
        table.insert(MV.bad, string.format("week %s %s: %s", tostring(self.campaign and self.campaign.week),
            tostring(self.scene and self.scene.room), what))
    end
    MV.n_bad = (MV.n_bad or 0) + 1
end
local FX = { first_nights = 0, bad_first = 0, trouble = 0, cheerful = 0, msgs = {} }
local CHEERFUL = { beaming = true, grinning = true, ["leaning in"] = true, ["chatting away"] = true, ["in great spirits"] = true }
for _, m in pairs(require("game.data.moods")) do
    if type(m) == "table" and m.tell and (m.fun or 0) > 0 then
        CHEERFUL[m.tell] = true
    end
end
local real_emit = night_mod.emit
night_mod.emit = function(self, ev)
    local from = ev.actor and self.mini_pos and self.mini_pos[ev.actor]
    from = from and { from[1], from[2] }
    if ev.kind == "walk" and ev.path and from and self.scene then
        local st = sight.stage(self, self.scene)
        MV.walks = MV.walks + 1
        local last = from
        for k, sq in ipairs(ev.path) do
            MV.steps = MV.steps + 1
            local far = math.max(math.abs(sq[1] - last[1]), math.abs(sq[2] - last[2]))
            local final = k == #ev.path or (ev.path[k + 1][1] == sq[1] and ev.path[k + 1][2] == sq[2]) or k >= #ev.path - 2
            if far > 1 then
                bad_move(self, ev.actor .. " jumps " .. far .. " squares, " .. last[1] .. "," .. last[2] .. " to " .. sq[1] .. "," .. sq[2])
                break
            elseif st and not sight.walkable(st, sq[1], sq[2]) and not final then
                bad_move(self, ev.actor .. " walks through " .. sq[1] .. "," .. sq[2] .. ", a wall or a piece")
                break
            end
            last = sq
        end
    elseif ev.kind == "check" and ev.spot and from then
        if math.max(math.abs(ev.spot[1] - from[1]), math.abs(ev.spot[2] - from[2])) > 1 then
            MV.slides = MV.slides + 1
            bad_move(self, ev.actor .. " slides from " .. from[1] .. "," .. from[2] .. " to " .. ev.spot[1] .. "," .. ev.spot[2] .. " to roll a check")
        end
    elseif ev.kind == "battle" and ev.phase == "start" then
        for _, a in ipairs(ev.allies or {}) do
            if a.pilot then
                MV.ally_fights = MV.ally_fights + 1
                MV.rides = MV.rides + (a.rides_with and 1 or 0)
            end
        end
    end
    -- Faces (F): the first beat of the first night, and every beat where a friend's hero is in trouble.
    if self.players and self.tells then
        local able = require "game.model.able"
        local tells = self:tells()
        if (self.campaign and self.campaign.week == 1) and not FX.first_seen then
            FX.first_seen = true
            FX.first_nights = FX.first_nights + 1
            for _, p in ipairs(self.players) do
                local t = tells[p.key]
                if t and (t.pose == "frown" or t.pose == "arms" or (t.fun or 0) < 50) then
                    FX.bad_first = FX.bad_first + 1
                    if #FX.msgs < 6 then
                        table.insert(FX.msgs, string.format("the first night opens with %s %s (Fun %d)", p.key, tostring(t.pose), math.floor(t.fun or 0)))
                    end
                end
            end
        end
        for _, p in ipairs(self.players) do
            local st = able.state(self, p)
            if st == "down" or st == "dead" or st == "stone" then
                FX.trouble = FX.trouble + 1
                local t = tells[p.key]
                if t and (CHEERFUL[t.text] or t.pose == "lean" or t.pose == "cheer" or t.pose == "laugh" or t.pose == "neutral") then
                    FX.cheerful = FX.cheerful + 1
                    if #FX.msgs < 12 then
                        table.insert(FX.msgs, string.format("week %s: %s's hero is %s and their tile says \"%s\" (%s)",
                            tostring(self.campaign.week), p.key, st, tostring(t.text), tostring(t.pose)))
                    end
                end
            end
        end
    end
    if ev.kind == "done" then
        FX.first_seen = FX.first_seen and (self.campaign and self.campaign.week or 1) >= 1
    end
    return real_emit(self, ev)
end

local RUNS = {}
local real_exit, real_print = os.exit, print
local function sim(seed, style)
    FX.first_seen = nil
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

-- M: movement -----------------------------------------------------------------------------------------
E.M = { walks = MV.walks, steps = MV.steps, check_slides = MV.slides, companion_fights = MV.ally_fights }
for _, b in ipairs(MV.bad) do
    fail("M", b)
end
if (MV.n_bad or 0) > #MV.bad then
    fails.M.n = fails.M.n + (MV.n_bad - #MV.bad)
end
if MV.ally_fights > 0 and MV.rides < MV.ally_fights then
    fail("M", string.format("a companion fought %d times and was sent back to whoever carries them %d times (the table runs them off the edge)",
        MV.ally_fights, MV.rides))
end
-- The table: an ally never runs off the table, and a mini more than a step away is set down, not slid.
case("M", function()
    local f = io.open("main/table/table.script")
    local t = f:read("*a")
    f:close()
    local v = io.open("game/ui/night_view.lua")
    local nv = v:read("*a")
    v:close()
    if string.find(nv, 'for _, id in ipairs(app.ally_ids or {}) do\n                post("flee"', 1, true) then
        fail("M", "after a fight, every ally's mini runs off the edge of the table")
    end
    if not string.find(t, "never slides it across", 1, true) then
        fail("M", "a mini re-staged more than a step away slides straight across the map")
    end
end)

-- F: faces and moods ------------------------------------------------------------------------------------
E.F = { first_nights = FX.first_nights, frames_with_a_hero_in_trouble = FX.trouble }
for _, m in ipairs(FX.msgs) do
    fail("F", m)
end
if FX.bad_first + FX.cheerful > #FX.msgs then
    fails.F = fails.F or { n = 0 }
    fails.F.n = (fails.F.n or 0) + (FX.bad_first + FX.cheerful - #FX.msgs)
end

-- L: layout ---------------------------------------------------------------------------------------------
case("L", function()
    -- The Table view's camera (main/scene_data.lua), each face projected as the engine does (a vertical fov).
    local sd_src = io.open("main/scene_data.lua"):read("*a")
    local function vec(str)
        local x, y, z = string.match(str, "vmath%.vector3%(([%-%d%.]+), ([%-%d%.]+), ([%-%d%.]+)%)")
        return { tonumber(x), tonumber(y), tonumber(z) }
    end
    local eye_s, tgt_s, fov = string.match(sd_src, 'name = "Table", eye = (vmath%.vector3%b()), target = (vmath%.vector3%b()), fov = ([%d%.]+)')
    local eye, tgt = vec(eye_s), vec(tgt_s)
    fov = tonumber(fov)
    local function sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
    local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
    local function norm(a) local l = math.sqrt(dot(a, a)) return { a[1] / l, a[2] / l, a[3] / l } end
    local function cross(a, b) return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] } end
    local f = norm(sub(tgt, eye))
    local r = norm(cross(f, { 0, 1, 0 }))
    local u = cross(r, f)
    local t = math.tan(math.rad(fov) / 2)
    local function proj(p)
        local d = sub(p, eye)
        local z = dot(d, f)
        return 800 + dot(d, r) / z / t * 450, 450 - dot(d, u) / z / t * 450
    end
    for who, hs in string.gmatch(string.match(sd_src, "heads = (%b{})"), "(%a+) = (vmath%.vector3%b())") do
        local h = vec(hs)
        -- (Their face: a quarter of a head-height under the top of the head, and about 9 across.)
        local lx, fy = proj({ h[1] - 9, h[2] - 25, h[3] })
        local rx = proj({ h[1] + 9, h[2] - 25, h[3] })
        add("L", "faces_measured")
        if lx < 0 or rx > 1600 or fy < 80 or fy > 760 then
            fail("L", string.format("%s's face is outside the Table view or under the top bar (x %d to %d, y %d)", who,
                math.floor(lx), math.floor(rx), math.floor(fy)))
        end
    end
    local ps = io.open("main/people/person.script"):read("*a")
    if not string.find(ps, "self.lift", 1, true) then
        fail("L", "a friend speaking in character becomes a hero half their height, centred low: the head sinks below the table")
    end
    -- (Read off the screens' code: the GUI isn't loaded here.)
    local src = io.open("game/ui/night_view.lua"):read("*a")
    local psrc = io.open("game/ui/panels.lua"):read("*a")
    local PY, PW = string.match(psrc, "M%.Y, M%.W, M%.H = (%d+), (%d+), (%d+)")
    PY, PW = tonumber(PY), tonumber(PW)
    local RX, RW = string.match(psrc, "local ROLL_X, ROLL_W = (%d+), (%d+)")
    RX, RW = tonumber(RX), tonumber(RW)
    local tag_off = tonumber(string.match(psrc, "chip%.ic_x, chip%.ic_y = x %+ w, y %- (%d+)"))
    local cap = tonumber(string.match(src, "local CAPTION_BOTTOM, CAPTION_W = (%d+)"))
    local floor_s = string.match(src, "local floor = col_x and %(CHIP_Y %- ([%w_]+)%)")
    local floor_off = tonumber(floor_s) or tonumber(string.match(src, "local " .. tostring(floor_s) .. " = (%d+)"))
    add("L", "bands_measured")
    if not (PY and tag_off and cap and floor_off) then
        fail("L", "the screen's bands couldn't be read")
    else
        local tag_top, bubble_floor = PY - tag_off, PY - floor_off
        if bubble_floor > tag_top - 4 then
            fail("L", "a friend's speech above their tile reaches down over the IN/OUT OF CHARACTER tag")
        end
        if cap > bubble_floor - 66 then
            fail("L", "the DM's caption sits in the band the friends' speech above their tiles uses")
        end
    end
    local dy = string.match(src, "function M%.dying%(app, id%)(.-)\nend")
    if not (dy and string.find(dy, "panels.ROLL_X", 1, true) and RX and RX + RW <= PW) then
        fail("L", "the death-save card isn't on the dying hero's own tile: it sits on the DM screen and beside the next tile")
    end
end)

-- S: structure ------------------------------------------------------------------------------------------
do
    local splits, cut, regroup, finds, finds_rolled = 0, 0, 0, 0, 0
    for _, R in ipairs(RUNS) do
        for i, l in ipairs(R.L) do
            if string.find(l, "split up%. You'll cut") or string.find(l, "like a heist movie") then
                splits = splits + 1
                local saw_cut, saw_back = false, false
                for j = i + 1, math.min(#R.L, i + 400) do
                    local t = R.L[j]
                    if string.find(t, "Cut to ") or string.find(t, "Meanwhile, by ") or string.find(t, "Over by ") then
                        saw_cut = true
                    end
                    if string.find(t, "catch up with the others") or string.find(t, "catches up with the others") or string.find(t, "back to the group")
                        or string.find(t, "The party's back together") then
                        saw_back = true
                        break
                    end
                    if string.find(t, "^== Scene") and saw_cut then
                        break
                    end
                end
                cut = cut + (saw_cut and 1 or 0)
                regroup = regroup + (saw_back and 1 or 0)
                if not saw_cut then
                    fail("S", R.tag .. ": the party split, and nothing cut to the ones who went off")
                elseif not saw_back then
                    fail("S", R.tag .. ": the party split, and never regrouped by the scene's end")
                end
            end
            if string.find(l, "^  >> Something to find: ") then
                finds = finds + 1
                if string.find(l, "Investigation check", 1, true) then
                    finds_rolled = finds_rolled + 1
                else
                    fail("S", R.tag .. ": a find card with no roll of the poking hero's: " .. string.sub(l, 1, 160))
                end
            end
        end
    end
    E.S = { splits = splits, splits_cut = cut, splits_regrouped = regroup, find_cards = finds, find_cards_with_the_roll = finds_rolled }
end
-- The opening board: one UI run, the board on the table as each night starts.
case("S", function()
    local dir = os.tmpname()
    os.remove(dir)
    os.execute("mkdir -p " .. dir)
    local ok = os.execute("DUMP_DIR=" .. dir .. " lua tools/tests/museum_smoke.lua 3 > /dev/null 2>&1")
    local fh = io.open(dir .. "/board_minis.txt")
    local nights = 0
    for l in (fh and fh:lines() or function() return nil end) do
        local w, b = string.match(l, "^NIGHT (%d+) (%S+)")
        if w then
            nights = nights + 1
            if b == "nil" or b == "vignette" then
                fail("S", "night " .. w .. " opens on " .. b .. ", not the board where they stopped")
            end
        end
    end
    if fh then
        fh:close()
    end
    E.S.nights_opened = nights
    if nights == 0 then
        fail("S", "no night's opening board seen (the UI run: " .. tostring(ok) .. ")")
    end
end)
-- The snacks: eaten in chunks as the table's clock goes on, not by how many scenes have passed.
case("S", function()
    local posted = {}
    local real_msg = rawget(_G, "msg")
    msg = { post = function(url, id, m) table.insert(posted, { id = id, m = m }) end }
    vmath = vmath or { vector4 = function(...) return { ... } end, vector3 = function(...) return { ... } end }
    local ambience = require "game.ui.ambience"
    local app = { night = { table_min = 0, table_planned = 210 } }
    for m = 0, 240, 10 do
        app.night.table_min = m
        ambience.night_event(app, { kind = "narrate", style = "narration" })
    end
    msg = real_msg
    local amounts = {}
    for _, p in ipairs(posted) do
        if p.id == "eaten" then
            table.insert(amounts, p.m.amount)
        end
    end
    E.S.snack_steps = #amounts
    if #amounts < 4 then
        fail("S", "over an evening at the table the snacks went down " .. #amounts .. " times: they don't follow the clock")
    end
    local sc = io.open("main/snacks/snacks.script"):read("*a")
    if not string.find(sc, "DRINKS", 1, true) then
        fail("S", "the drinks never go down")
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
print(total == 0 and "conner nov4b check: all clear" or ("conner nov4b check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
