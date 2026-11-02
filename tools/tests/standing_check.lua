-- The DM's recap (v2, November 1), headless. Run from the project root:
--   lua tools/tests/standing_check.lua
-- Checks: every person the rooms put on the table belongs to a side, each person's line follows the
-- story (rooms done, marks, things found, favors), Euryale's line counts her marks and who's with her,
-- who's drawn to whom follows their kind of player, their reason for coming and what happens at the
-- table, the Table rows say why each friend came and what they're after, nothing from the old story
-- shows, and a whole prologue's recap reads right at the end.

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local standing = require "game.model.standing"
local score = require "game.model.score"

local fails, checks = 0, 0
local function check(cond, msg)
    checks = checks + 1
    if not cond then
        fails = fails + 1
        print("FAIL: " .. msg)
    end
end

local function new_campaign(seed)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        adventure.set_hook(c, key, adventure.data.hooks[key][1].id)
    end
    return c
end

local function text_ok(s, where)
    check(type(s) == "string" and not s:find("{[%w_]+}") and not s:find("nil"), where .. ": '" .. tostring(s) .. "'")
    check(not adventure.foreign(s or ""), where .. ": the old story in '" .. tostring(s) .. "'")
end

local MOD = adventure.data
local c = new_campaign(41)
check(standing.has(c), "the museum has a recap")

-- 1. Every room's person is on a side; every side has people.
local on_side = {}
for _, side in ipairs(MOD.sides) do
    check(#side.members > 0, side.name .. " has people")
    for _, m in ipairs(side.members) do
        on_side[m.id] = side.id
        check(m.room == nil or MOD.rooms[m.room] ~= nil, m.name .. "'s room exists")
        for _, s in ipairs(m.states or {}) do
            local w = s.when or {}
            check(not w.done or MOD.rooms[w.done], m.name .. ": a state's room exists")
            check(not w.mark or MOD.marks[w.mark], m.name .. ": a state's mark exists (" .. tostring(w.mark) .. ")")
        end
    end
end
for id, r in pairs(MOD.rooms) do
    local cast = r.comps and r.comps.cast
    if cast and not r.epilogue then
        check(on_side[cast] ~= nil, "the " .. id .. "'s person (" .. cast .. ") is on a side")
    end
end

-- 2. Lines follow the story.
local function line_of(id)
    for _, s in ipairs(standing.story(c)) do
        for _, list in ipairs({ s.people, s.ahead }) do
            for _, r in ipairs(list) do
                if r.id == id then
                    return r
                end
            end
        end
    end
end
check(line_of("mus_knight").line == "Still ahead", "the Knight is still ahead at the start")
c.adv.done.paintings = "win"
check(line_of("mus_knight").line == "Beaten" and line_of("mus_knight").tone == "good", "once through the hall, he's beaten")
adventure.add_mark(c, "knight", "paintings")
check(line_of("mus_knight").tone == "bad", "his mark says he's waiting for her: " .. line_of("mus_knight").line)
local eu = line_of("mus_euryale")
check(eu.line:find("1 mark") and eu.with and eu.with:find("Knight"), "Euryale counts her mark and who's with her: " .. eu.line .. " " .. eu.with)
c.adv.favors.flitwidget = 2
check(line_of("mus_flitwidget").line:find("Delighted"), "a good word with Flitwidget shows")
c.adv.flags.telpur_along = true
check(line_of("mus_telpur").line:find("Coming along"), "Telpur coming along shows")
for _, s in ipairs(standing.story(c)) do
    text_ok(s.name, "side")
    for _, r in ipairs(s.people) do
        text_ok(r.line, r.name)
    end
end

-- 3. Who's drawn to whom.
local function find(key)
    for _, p in ipairs(c.players) do
        if p.key == key then
            return p
        end
    end
end
local member = {}
for _, side in ipairs(MOD.sides) do
    for _, m in ipairs(side.members) do
        member[m.id] = m
    end
end
local jess, dev = find("jess"), find("dev")
check(standing.affinity(c, member.mus_telpur, jess) > standing.affinity(c, member.mus_telpur, dev),
    "a talking boot draws Jess more than Dev")
check(standing.affinity(c, member.mus_mech, dev) > standing.affinity(c, member.mus_mech, jess), "a war machine draws Dev more")
local h = adventure.hook(c, "mara")
local in_hook
for _, m in pairs(member) do
    if m.room == h.room then
        in_hook = m
    end
end
if in_hook then
    check(standing.feeling(standing.affinity(c, in_hook, find("mara"))) ~= nil,
        "Mara cares about who's in the room she came for (" .. in_hook.name .. ")")
end
-- What happens at the table moves it.
local fake = { campaign = c, players = c.players }
local a0 = standing.affinity(c, member.mus_lecturer, dev)
local before = { dev = score.fun(dev) }
score.add(dev, "fun", 10)
standing.note(fake, { "mus_lecturer" }, before)
check(standing.affinity(c, member.mus_lecturer, dev) > a0, "a moment Dev loved draws him to the Lecturer")
before = { dev = score.fun(dev) }
for _ = 1, 3 do
    score.add(dev, "fun", -10)
    standing.note(fake, { "mus_lecturer" }, before)
    before = { dev = score.fun(dev) }
end
check(standing.feeling(standing.affinity(c, member.mus_lecturer, dev)) == "put_off", "and moments he hated put him off")

-- 4. The Table rows.
local rows = standing.table(c, nil)
check(#rows == #c.players, "a row for each friend")
for _, r in ipairs(rows) do
    check(r.hook and r.hook.name and r.hook.room, r.name .. " says why they came")
    text_ok(r.hook.room, r.name .. "'s room")
    check(r.known and r.level >= 1, r.name .. " says how well you know them")
    for _, n in ipairs(r.drawn) do
        text_ok(n, r.name .. " drawn to")
    end
end

-- 5. A whole prologue: the recap reads at every night's end.
local c2 = new_campaign(43)
local museum_week = require "game.model.museum_week"
for _ = 1, 8 do
    if c2.adv.ending then
        break
    end
    local prep = c2:start_week()
    museum_week.prep_greedy(prep)
    local night = c2:start_night()
    local ev = night:advance()
    local g = 0
    while ev.kind ~= "done" and g < 5000 do
        g = g + 1
        local a
        if ev.kind == "decision" or ev.kind == "ruling" then
            a = 1
        elseif ev.kind == "improv" then
            a = { 1 }
        elseif ev.kind == "roll_where" then
            a = "open"
        elseif ev.kind == "roll" then
            a = 15
        elseif ev.kind == "scene" and night.scene and night.scene.index == 2 then
            -- Mid-night, as the DM would open it.
            for _, r in ipairs(standing.table(c2, night)) do
                check(r.tonight == nil or (r.tonight.tell and r.tonight.engagement), r.name .. "'s night shows")
            end
        end
        ev = night:advance(a)
    end
    c2:finish_night()
    for _, s in ipairs(standing.story(c2)) do
        for _, r in ipairs(s.people) do
            text_ok(r.line, "after a night: " .. r.name)
        end
    end
end
check(c2.adv.ending ~= nil, "the prologue still ends")
local drawn_any = false
for _, r in ipairs(standing.table(c2, nil)) do
    if #r.drawn > 0 then
        drawn_any = true
    end
end
check(drawn_any, "by the end, someone at the table is drawn to someone in the story")

print(string.format("the DM's recap: %d checks, %d failed", checks, fails))
os.exit(fails == 0 and 0 or 1)
