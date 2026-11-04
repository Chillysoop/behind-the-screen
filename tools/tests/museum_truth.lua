-- The truth test (November 2): what the table hears has to be true, and what happens has to be
-- heard. Two halves. Run from the project root:  lua tools/tests/museum_truth.lua [runs]
--
-- 1. The adventure's data, read cold:
--    - every flag something sets is read by something (a condition, an item, a callback, an aside,
--      what someone remembers, the code): a pickup that does nothing is a broken promise;
--    - every mark something adds is on Euryale's card and changes her fight or her talk;
--    - a log that says someone got hurt hurts them; one that says a Franc appeared pays one; one
--      that says someone pockets, takes or pulls something out sets what they now have;
--    - no shared moment names a hero (whoever's at the table, or a replacement, may be the one).
-- 2. Whole prologues, headless, several seeds and three kinds of DM, watching what's said against
--    what happened:
--    - Euryale dead means the ending is "fallen", and she never yields after she's dead;
--    - a boss that ran (or yielded) is never "the last one falls";
--    - every mark that lands gets her line upstairs, that night or the next;
--    - an item picked up is on someone's sheet;
--    - every line fits the adventure (adventure.fits): nothing from the old story;
--    - a hero who's been replaced isn't named doing things afterwards.

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local MODULE = require "game.data.museum.module"
local cards = require "game.data.museum.cards"

local failures = 0
local function fail(msg)
    failures = failures + 1
    if failures <= 60 then
        print("FAIL: " .. msg)
    end
end

-- Part 1: the data ------------------------------------------------------------------------------

local sets, reads = {}, {}          -- flag -> where
local marks_set = {}

-- Walk a table: a `flag`/`mark` in a `mus` table is something set; anywhere else (when, needs,
-- has, unless, states, memory, items...) it's something read.
local function walk(t, path, in_mus, seen)
    if type(t) ~= "table" or seen[t] then
        return
    end
    seen[t] = true
    for k, v in pairs(t) do
        local p = path .. "." .. tostring(k)
        if k == "flag" and type(v) == "string" then
            if in_mus then
                sets[v] = sets[v] or p
            else
                reads[v] = reads[v] or p
            end
        elseif k == "needs_flag" and type(v) == "string" then
            reads[v] = reads[v] or p
        elseif k == "mark" and type(v) == "string" and in_mus then
            marks_set[v] = marks_set[v] or p
        end
        if type(v) == "table" then
            walk(v, p, in_mus or k == "mus", seen)
        end
    end
end
walk(MODULE, "MODULE", false, {})
walk(cards, "cards", false, {})

-- What the code reads and sets directly.
local code_reads, code_sets = {}, {}
for _, f in ipairs({ "game/model/museum_night.lua", "game/model/adventure.lua", "game/model/museum_week.lua",
                     "game/model/standing.lua", "game/model/takeover.lua", "game/model/night.lua" }) do
    local fh = io.open(f, "r")
    local src = fh:read("*a")
    fh:close()
    for name in string.gmatch(src, "flags%.([%w_]+)%s*=%s*true") do
        code_sets[name] = f
    end
    for name in string.gmatch(src, "flags%.([%w_]+)") do
        code_reads[name] = code_reads[name] or f
    end
    for name in string.gmatch(src, "flags%[\"([%w_]+)\"%]") do
        code_reads[name] = code_reads[name] or f
    end
end
-- (A `flags.x = true` line is a set, not a read: count only reads that aren't the set itself.)
local function code_read(name)
    for _, f in ipairs({ "game/model/museum_night.lua", "game/model/adventure.lua", "game/model/museum_week.lua",
                         "game/model/standing.lua", "game/model/takeover.lua", "game/model/night.lua" }) do
        local fh = io.open(f, "r")
        local src = fh:read("*a")
        fh:close()
        for line in string.gmatch(src, "[^\n]+") do
            if string.find(line, "flags%." .. name .. "%f[^%w_]") and not string.find(line, "flags%." .. name .. "%s*=%s*true") then
                return true
            end
        end
    end
    return false
end
-- The battle options a flag hands its own room's fight (museum_night's FLAG_OPT).
do
    local fh = io.open("game/model/museum_night.lua", "r")
    local src = fh:read("*a")
    fh:close()
    local body = string.match(src, "local FLAG_OPT = (%b{})") or ""
    for name in string.gmatch(body, "([%w_]+)%s*=") do
        code_reads[name] = "museum_night FLAG_OPT"
        reads[name] = reads[name] or "museum_night FLAG_OPT"
    end
end
-- A flag the DM's ties can wait on (MODULE.outs, the tie-and-lock editor) is read there.
for name in pairs(MODULE.outs or {}) do
    reads[name] = reads[name] or "MODULE.outs"
end
for name, where in pairs(code_sets) do
    sets[name] = sets[name] or where
end
for name, where in pairs(sets) do
    if not reads[name] and not code_read(name) then
        fail("flag '" .. name .. "' is set (" .. where .. ") but nothing reads it: what does it do?")
    end
end

-- Every mark added is on her card and does something there.
for name, where in pairs(marks_set) do
    local m = MODULE.marks[name]
    if not m then
        fail("mark '" .. name .. "' (" .. where .. ") isn't one of Euryale's marks")
    elseif not (m.foe or m.ally or m.opt or m.talk) then
        -- (A mark the talk or a moment reads is still an effect.)
        local read = false
        local function find(t, seen)
            if type(t) ~= "table" or seen[t] then
                return
            end
            seen[t] = true
            for k, v in pairs(t) do
                if (k == "when" or k == "needs" or k == "alt_needs" or k == "has" or k == "unless") and type(v) == "table" and v.mark == name then
                    read = true
                end
                find(v, seen)
            end
        end
        find(MODULE, {})
        find(cards, {})
        if not read then
            fail("mark '" .. name .. "' changes nothing on boss night (no foe, ally, option, talk, or anything that reads it)")
        end
    end
end

-- Words that promise an effect, on every option and roll outcome.
local HURT = { "barely breathing", "cut and", "bleeding", "numb", "frostbite", "lands hard", "bites%.", "flung" }
local TAKE = { "{actor_char} pockets", "straps it to", "{actor_char} pulls out", "fishes out", "unscrews a" }
local HEROES = { "Brannoc", "Thessaly", "Pip", "Oswin" }
local function each_outcome(card, fn)
    for _, o in ipairs(card.options or {}) do
        fn(o, o.log, o.mus)
        if o.roll then
            fn(o, o.roll.success and o.roll.success.log, o.roll.success and o.roll.success.mus)
            fn(o, o.roll.fail and o.roll.fail.log, o.roll.fail and o.roll.fail.mus)
        end
    end
end
local moment_cards = {}
for _, m in ipairs(MODULE.moments) do
    table.insert(moment_cards, m)
end
for _, k in ipairs({ "drink", "talk", "yield" }) do
    table.insert(moment_cards, MODULE.showdown[k])
end
for _, card in ipairs(moment_cards) do
    -- (The friends' own table moments may name their own hero: Pip going off alone is Jess's thing.)
    local own = card.type == "table" and card.actor and #card.actor == 1
    each_outcome(card, function(o, log, mus)
        if type(log) ~= "string" then
            return
        end
        local low = string.lower(log)
        for _, w in ipairs(HURT) do
            if string.find(low, w) and not (mus and mus.hurt) then
                fail(card.id .. ": '" .. log .. "' says someone's hurt, but nobody takes damage (mus.hurt)")
                break
            end
        end
        if string.find(low, "franc") and (string.find(low, "appears") or string.find(low, "materialises") or string.find(low, "pops into"))
            and not (mus and mus.francs) then
            fail(card.id .. ": '" .. log .. "' says a Franc appears, but none is paid (mus.francs)")
        end
        for _, w in ipairs(TAKE) do
            if string.find(low, w, 1, true) and not (mus and (mus.flag or mus.mark)) then
                fail(card.id .. ": '" .. log .. "' says they took something, but it sets nothing they now have")
                break
            end
        end
        if not own then
            for _, h in ipairs(HEROES) do
                if string.find(log, "%f[%a]" .. h .. "%f[%A]") or string.find(o.label or "", "%f[%a]" .. h .. "%f[%A]") then
                    fail(card.id .. ": names " .. h .. " ('" .. log .. "'): whoever is at the table might be someone else")
                end
            end
        end
    end)
end

-- Every item's effect is real: an option the rules know, a magic item that exists.
local museum_rules = require "game.rules.museum"
for _, it in ipairs(MODULE.items or {}) do
    if it.opt and not (function()
        for _, o in ipairs(museum_rules.OPTIONS) do
            if o == it.opt then
                return true
            end
        end
    end)() then
        fail("item " .. it.id .. ": battle option '" .. it.opt .. "' isn't one the rules know")
    end
    if it.magic and not (MODULE.magic_items or {})[it.magic] then
        fail("item " .. it.id .. ": magic item '" .. it.magic .. "' isn't defined")
    end
end

-- A line that names who has something reads the inventory (the second playtest review, F10): every
-- item line with {holder} is a thing someone carries (`carry`), or the charm (who drank her wine).
for _, it in ipairs(MODULE.items or {}) do
    if it.line and string.find(it.line, "{holder}", 1, true) and not it.carry and not it.charm then
        fail("item " .. it.id .. ": '" .. it.line .. "' names who has it, but it isn't in anyone's pack (carry)")
    end
end

local static_failures = failures
print(string.format("museum truth, the data: %d flags set, %d marks added, %d failures", (function()
    local n = 0
    for _ in pairs(sets) do
        n = n + 1
    end
    return n
end)(), (function()
    local n = 0
    for _ in pairs(marks_set) do
        n = n + 1
    end
    return n
end)(), static_failures))

-- Part 2: whole prologues ----------------------------------------------------------------------

local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"
local items_mod = require "game.model.items"

local runs = tonumber(arg[1]) or 4
local styles = { "careful", "random", "careless" }
local endings = {}

local function play(seed, style)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    local rng = require("game.model.rng").new(seed + 501)
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = MODULE.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    local tag = "seed " .. seed .. " " .. style
    local owed_marks = {}           -- marks on her card nobody's heard her line for yet
    for w = 1, MODULE.MAX_WEEKS do
        local prep = c:start_week()
        for _, pr in ipairs(c.adv.prompts) do
            if pr.kind == "request" then
                adventure.answer_request(c, pr.id, MODULE.ANSWERS[rng:int(1, 4)])
            elseif pr.kind == "loose" then
                adventure.answer_loose(c, pr.id, rng:int(1, #pr.def.options))
            elseif pr.kind == "ruling" then
                adventure.answer_ruling(c, pr.id, rng:chance(0.5))
            elseif pr.kind == "favor" then
                adventure.answer_favor(c, pr.id, rng:int(1, 2), rng:int(1, 2))
            end
        end
        if style ~= "careless" then
            museum_week.prep_greedy(prep)
        end
        if prep.museum.boss then
            c.adv.boss = { opener = rng:chance(0.7) and "talk" or "ambush", style = rng:chance(0.6) and "yields" or "last" }
        end
        local marks_before = {}
        for _, id in ipairs(c.adv.mark_list) do
            marks_before[id] = true
        end
        for _, id in ipairs(c.adv.unannounced or {}) do
            owed_marks[id] = true
        end
        local night = c:start_night()
        local heard = {}
        local yield_played_dead = false
        local found_tonight = false
        local old_names = {}
        for _, p in ipairs(c.players) do
            if p.old_char then
                old_names[p.old_char] = true
            end
        end
        local ev = night:advance()
        local guard = 0
        while ev.kind ~= "done" and guard < 5000 do
            guard = guard + 1
            local answer
            local text = (ev.kind == "narrate" or ev.kind == "say" or ev.kind == "npc") and ev.text or nil
            if text then
                if not adventure.fits(text) then
                    fail(tag .. " week " .. w .. ": a line from outside the adventure: '" .. text .. "'")
                end
                local m = string.match(text, "^Upstairs, Euryale: ")
                if m then
                    heard[#heard + 1] = text
                end
                local low = string.lower(text)
                if string.find(low, "the last one falls", 1, true) and night.scene and night.scene.foes_ran and #night.scene.foes_ran > 0 then
                    fail(tag .. ": 'the last one falls' after a foe ran")
                end
                for name in pairs(old_names) do
                    if string.find(text, "%f[%a]" .. name .. "%f[%A]") and not string.find(low, "died")
                        and not string.find(low, "fell") and not string.find(low, "place") and not string.find(low, "pack")
                        and not string.find(low, "wake") and not string.find(low, "last time") then
                        fail(tag .. ": " .. name .. " was replaced, but a line still has them doing things: '" .. text .. "'")
                    end
                end
            end
            if ev.kind == "scene_end" and ev.reward then
                found_tonight = true
            end
            if ev.kind == "decision" and string.find(ev.card.id or "", "^mus_fork_") then
                -- A fork describes where the party is standing, nowhere else.
                local here = c.adv.pos or c.adv.last_room
                for room, at in pairs(MODULE.fork_at or {}) do
                    for _, t in ipairs({ at.text, at.after and at.after.text or false }) do
                        if t and string.find(ev.card.text or "", t, 1, true) and room ~= here then
                            fail(tag .. " week " .. w .. ": a fork in " .. tostring(here) .. " describes " .. room .. ": '" .. t .. "'")
                        end
                    end
                end
                -- The reasons the friends give for a vote are true (the playtest, Nov 2: votes said
                -- nothing about why; now they do, and the why has to hold).
                for _, p in ipairs(night.players) do
                    local pc = night.pcs and night.pcs[p.key]
                    local ft = ev.card.text or ""
                    if string.find(ft, p.char .. "'s hurt", 1, true) and pc
                        and not ((pc.hp or 0) > 0 and pc.hp / math.max(1, pc.hp_max) <= 0.6001) then
                        fail(tag .. " week " .. w .. ": a fork says " .. p.char .. "'s hurt, at " .. tostring(pc.hp) .. "/" .. tostring(pc.hp_max))
                    end
                    if string.find(ft, p.char .. " went down in", 1, true) then
                        local down = false
                        for _, e in ipairs(night.ledger or {}) do
                            down = down or (e.ev == "down" and e.who == p.key)
                        end
                        if not down then
                            fail(tag .. " week " .. w .. ": a fork says " .. p.char .. " went down, and nobody did")
                        end
                    end
                    local h = adventure.hook(c, p.key)
                    local why = string.find(ft, "it's why " .. p.char .. " came", 1, true)
                    if why and not (h and h.room and string.find(ft, (MODULE.pull[h.room] or {}).want or "?", 1, true)) then
                        fail(tag .. " week " .. w .. ": a fork says it's why " .. p.char .. " came, for a room that isn't their reason")
                    end
                end
            end
            if ev.kind == "decision" then
                if ev.card.id == "mus_yield" and night.scene and night.scene.boss_dead then
                    yield_played_dead = true
                end
                local opts = ev.card.options
                local pick = (style == "careful") and 1 or rng:int(1, #opts)
                if opts[pick].disabled then
                    pick = 1
                end
                answer = pick
            elseif ev.kind == "thought" then
                require("game.model.thoughts").bot_play(night, ev, style, rng)
            elseif ev.kind == "ruling" then
                answer = 1
            elseif ev.kind == "improv" then
                answer = { 1 }
            elseif ev.kind == "roll_where" then
                answer = "open"
            elseif ev.kind == "roll" then
                answer = rng:d20()
            end
            ev = night:advance(answer)
        end
        if guard >= 5000 then
            fail(tag .. ": a night never ended")
        end
        local rep = c:finish_night()
        -- (Something found means the report says so; nobody ends the night on 0 HP or as stone.)
        if found_tonight and rep and rep.museum and #(rep.museum.got or {}) == 0 and (rep.museum.francs_tonight or 0) == 0 then
            fail(tag .. " week " .. w .. ": a prize was found tonight, but the report says nothing was picked up")
        end
        for _, pc in ipairs(night.pc_list or {}) do
            if not pc.dead and (pc.hp or 0) <= 0 then
                fail(tag .. " week " .. w .. ": " .. pc.name .. " ends the night on 0 hit points, unmentioned")
            end
            for _, e in ipairs(pc.effects or {}) do
                if e.stone or e.petrifying then
                    fail(tag .. " week " .. w .. ": " .. pc.name .. " is still stone after the night")
                end
            end
        end
        if yield_played_dead then
            fail(tag .. ": Euryale yielded after she was dead")
        end
        -- What happened in the lair, against how it ended.
        for _, sc in ipairs(night.scenes or {}) do
            if sc.showdown and sc.fought and not sc.extras_only then
                local e = c.adv.ending
                if sc.boss_dead and e ~= "fallen" then
                    fail(tag .. ": Euryale died in the fight, but the ending is " .. tostring(e))
                end
                if sc.boss_ran and e and e ~= "escape" then
                    fail(tag .. ": Euryale ran, but the ending is " .. tostring(e))
                end
                if sc.boss_yielded and sc.boss_dead then
                    fail(tag .. ": Euryale both yielded and died")
                end
            end
        end
        -- Every new mark got her line (tonight, or owed from the week between and said tonight).
        for _, id in ipairs(c.adv.mark_list) do
            if not marks_before[id] or owed_marks[id] then
                local m = MODULE.marks[id]
                local found = false
                for _, h in ipairs(heard) do
                    found = found or string.find(h, adventure.mark_thought(c, id), 1, true) ~= nil or string.find(h, m.thought, 1, true) ~= nil
                end
                if found then
                    owed_marks[id] = nil
                elseif not marks_before[id] and not (c.adv.unannounced and #c.adv.unannounced > 0) then
                    fail(tag .. " week " .. w .. ": mark '" .. id .. "' landed on her card without her line")
                end
            end
        end
        if adventure.over(c) then
            break
        end
        c:level_up()
    end
    -- Anything they picked up, bought or were given is in one hero's pack (or was used up there).
    for _, it in ipairs(MODULE.items or {}) do
        if it.carry and not it.magic and adventure.test(c, it.when, {}) then
            local had = false
            for _, e in ipairs(items_mod.list(c)) do
                had = had or ((e.thing == it.id or e.id == it.id) and e.holder ~= nil)
            end
            if not had then
                fail(tag .. ": they got " .. it.id .. ", and it's in nobody's pack")
            end
        end
    end
    -- Anything picked up is on someone's sheet.
    for _, it in ipairs(MODULE.items or {}) do
        if it.magic and adventure.test(c, it.when, {}) then
            local held = false
            for _, e in ipairs(items_mod.list(c)) do
                held = held or (e.id == it.magic and e.holder ~= nil)
            end
            if not held then
                fail(tag .. ": they picked up " .. it.id .. ", but it's on nobody's sheet")
            end
        end
    end
    local e = c.adv.ending or "none"
    endings[e] = (endings[e] or 0) + 1
end

for s = 1, runs do
    for _, style in ipairs(styles) do
        play(s, style)
    end
end
local et = {}
for k, n in pairs(endings) do
    table.insert(et, k .. " " .. n)
end
table.sort(et)
print(string.format("museum truth, the prologues: %d runs, endings %s, %d failures", runs * #styles, table.concat(et, ", "),
    failures - static_failures))
os.exit(failures == 0 and 0 or 1)
