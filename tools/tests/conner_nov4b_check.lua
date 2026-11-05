-- Conner's playtest of the November 4 build, the rest of his points (docs/playtests/2026-11-04/
-- conner-feedback/README.md; docs/design/2026-11-05-root-causes.md, classes 2 and 6 to 9). Whole
-- prologues (the museum sim in this process, three DMs) watched event by event, plus targeted cases.
-- Each item fails on 1ea3901. Run from the project root:
--     lua tools/tests/conner_nov4b_check.lua [seeds]
--   M   movement: every walk is a real one, a step at a time on open floor; a check rolled somewhere else
--       is walked to first; an ally the party brought rides back with them (C19, C24)

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local SEEDS = tonumber(arg[1]) or 4
local FIRST = 71
local STYLES = { "careful", "random", "careless" }
local ITEMS = { "run", "M" }
local NAMES = { run = "whole prologues", M = "movement" }

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
    return real_emit(self, ev)
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
