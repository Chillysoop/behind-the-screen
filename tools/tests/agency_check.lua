-- Players announce, the DM answers (game/model/agency.lua; Conner, November 6: "The DM should never say 'pip feels'
-- or 'jess wants' etc. hard rule"; root-causes class 2). Three parts:
--   CASES  the splitter on lines the November 6 playtest heard: a hero's move becomes their player's line, first
--          person and in character; an echo of what the player just said isn't said again; what happens to a
--          hero stays the DM's; a feeling, a want or a look is never said; a friend's words in the DM's line are
--          the friend's.
--   PLAY   whole prologues, three kinds of DM: nothing the DM says to the table has a hero doing something by
--          choice, or a hero or friend feeling, wanting or thinking, and nothing was left unsaid (a sentence the
--          guard had to drop is a line to rewrite where it's written).
--   SEATS  the tiles are in seat order, the table's left to right (Conner, November 6), for every adventure.
--     lua tools/tests/agency_check.lua [runs]
package.path = "./?.lua;" .. package.path
local agency = require "game.model.agency"
local players = require "game.data.players"

local RUNS = tonumber(arg[1]) or 2
local fails, E = {}, {}
local function fail(item, msg)
    fails[item] = fails[item] or {}
    table.insert(fails[item], msg)
end
local function add(item, key, n)
    E[item] = E[item] or {}
    E[item][key] = (E[item][key] or 0) + (n or 1)
end

local P = { { hero = "Thessaly", friend = "Mara", key = "mara", pronoun = "she" }, { hero = "Brannoc", friend = "Dev", key = "dev", pronoun = "he" },
            { hero = "Pip", friend = "Jess", key = "jess", pronoun = "she" }, { hero = "Oswin", friend = "Sam", key = "sam", pronoun = "he" } }

-- CASES ---------------------------------------------------------------------------------------------------------
local function said(text, last)
    local out = {}
    for _, l in ipairs((agency.split(text, P, last))) do
        table.insert(out, (l.who or "dm") .. (l.ic and "*" or "") .. ": " .. l.text)
    end
    return table.concat(out, " | ")
end
local CASES = {
    { "Thessaly unscrews a cupboard door and straps it to her pack.", "mara*: I'll unscrew a cupboard door and strap it to my pack." },
    { "Thessaly reaches in to the elbow. Nothing to take: the lady in the painting only looks back.",
      "mara*: I'll reach in to the elbow. | dm: Nothing to take: the lady in the painting only looks back." },
    { "A glass case of coins. Pip looks at the case, and then at its lock.", "dm: A glass case of coins. | jess*: I'll look at the case, and then at its lock." },
    { "Oswin sits down with Flitwidget and just listens for a while.", "sam*: I'll sit down with Flitwidget and just listen for a while." },
    { "Thessaly goes over the pond carefully.", "", { who = "mara", text = "There's something about the pond. I'm searching it." } },
    { "Thessaly takes 2 damage (12/14 HP).", "dm: Thessaly takes 2 damage (12/14 HP)." },
    { "The pedestal flares. Thessaly is flung across the room and lands hard.", "dm: The pedestal flares. Thessaly is flung across the room and lands hard." },
    { "Thessaly mutters something about Pip.", "" },
    { "Pip feels the floor shift.", "" },
    { "Jess wants the Hall of Paintings.", "" },
    { "The numbers get very large. Dev is delighted.", "dm: The numbers get very large." },
    { "Every beast seems to be looking at Oswin. His bad feeling is worse up here.", "dm: Every beast seems to be looking at Oswin." },
    { "Brannoc finds a Franc he's sure wasn't there.", "" },
    { "Pip pockets a brass label. 'Sorry, it's just what Pip would do,' Jess shrugs.",
      "jess*: I'll pocket a brass label. | jess: Sorry, it's just what Pip would do." },
    { 'Mara: "We\'ve got some of the tablet."', "mara: We've got some of the tablet." },
    { "Brannoc reads one line too many and has to sit down.", "dev*: I'll read one line too many and have to sit down." },
}
for _, c in ipairs(CASES) do
    add("CASES", "cases")
    local got = said(c[1], c[3])
    if got ~= c[2] then
        fail("CASES", "'" .. c[1] .. "' came out as '" .. got .. "', not '" .. c[2] .. "'")
    end
end

-- PLAY ----------------------------------------------------------------------------------------------------------
local DM = { narration = true, dm = true, good = true, bad = true, table = true, twist = true, thread = true, record = true,
             reward = true, opening = true, recap = true }
local NAMES = {}
for _, p in ipairs(P) do
    table.insert(NAMES, p.hero)
    table.insert(NAMES, p.friend)
end
for r = 1, RUNS do
    for _, style in ipairs({ "careful", "random", "careless" }) do
        local h = io.popen(string.format("lua tools/sim/museum.lua %d %s log 2>&1", 900 + r, style))
        local log = h:read("*a")
        h:close()
        local tag = style .. " " .. (900 + r)
        if not string.find(log, "museum seed", 1, true) then
            fail("PLAY", tag .. ": the prologue didn't finish: " .. string.sub(log, -200))
        end
        local prev
        for l in string.gmatch(log, "[^\n]+") do
            local who, text = string.match(l, "^  %[([^%]]+)%] (.*)$")
            if who and DM[who] then
                add("PLAY", "dm_lines")
                local parts = agency.split(text, P)
                if not (#parts == 1 and parts[1].kind == "dm" and parts[1].text == text) then
                    fail("PLAY", tag .. ": the DM said a hero's move or feeling for them: '" .. string.sub(text, 1, 140) .. "'")
                end
                local m = agency.mind_in(text, NAMES)
                if m then
                    fail("PLAY", tag .. ": the DM says '" .. m .. "': '" .. string.sub(text, 1, 140) .. "'")
                end
            elseif who and players[who] then
                if string.find(text, "^I'll ") then
                    add("PLAY", "announced")
                end
            end
            local u = string.match(l, "^  %-%- unsaid: (.*)$")
            if u then
                fail("PLAY", tag .. ": a line says what a hero or friend feels, wants or looks like (rewrite it): '" .. string.sub(u, 1, 140) .. "'")
            end
            prev = l
        end
    end
end

-- SEATS ---------------------------------------------------------------------------------------------------------
do
    local scene_ok, scene_src = pcall(function() return io.open("main/scene_data.lua"):read("*a") end)
    local xs = {}
    for who, x in string.gmatch(scene_ok and scene_src or "", "(%a+) = vmath%.vector3%((%-?[%d%.]+), 133") do
        xs[who] = tonumber(x)
    end
    local seats = players.seats or {}
    add("SEATS", "seats", #seats)
    for i = 2, #seats do
        if (xs[seats[i - 1]] or 0) >= (xs[seats[i]] or 0) then
            fail("SEATS", "the seats aren't the table's left to right: " .. table.concat(seats, ", "))
        end
    end
    if #seats ~= #players.order then
        fail("SEATS", "players.seats doesn't list every player")
    end
    local panels_src = io.open("game/ui/panels.lua"):read("*a")
    if not string.find(panels_src, "seated", 1, true) then
        fail("SEATS", "the tiles aren't drawn in seat order (game/ui/panels.lua: panels.seated)")
    end
end

local total = 0
for _, item in ipairs({ "CASES", "PLAY", "SEATS" }) do
    local bits = {}
    for k, v in pairs(E[item] or {}) do table.insert(bits, k .. " " .. v) end
    table.sort(bits)
    local f = fails[item] or {}
    print(string.format("%-6s %s%s", item, table.concat(bits, ", "), #f > 0 and ("  FAIL x" .. #f) or ""))
    for i, m in ipairs(f) do
        if i <= 15 then print("       FAIL: " .. m) end
    end
    total = total + #f
end
print(total == 0 and "agency check: all clear" or ("agency check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
