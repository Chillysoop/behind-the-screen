-- The story playtest (Oct 12): can the table follow the story the DM tells? Fights say who
-- the party is up against, a hero who fell stops coming up in the table talk, wants don't
-- repeat and happen where they belong, a cliffhanger ends the night, and the bridges between
-- scenes read as narration. Then the storylines (game/model/storylines.lua): several at once,
-- a loose end that wears the table down a little each week to a floor and comes back with a
-- surprise, the table losing the thread when too many run at once, and handouts that keep a
-- story warm. Run from the project root: lua tools/tests/story_check.lua

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path
unpack = unpack or table.unpack

local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local bots = require "slice_bots"
local storylines = require "game.model.storylines"
local handouts = require "game.model.handouts"
local content = require "game.model.content"

local ok_all = true
local function check(cond, what, detail)
    print(string.format("  [%s] %s  -  %s", cond and "PASS" or "FAIL", what, detail or ""))
    ok_all = ok_all and cond
end

-- Play whole slices with each simulated DM and read every night the way the table hears it.
local T = { fights = 0, named = 0, bridges = 0, bad_bridges = 0, cliff_after = 0, cliffs = 0, dead_talk = 0,
            want_repeat = 0, loose = {}, noticed = {}, back = 0, handouts = 0, thin = 0, nights = 0, first_week_back = 0 }
for _, dmk in ipairs({ "careful", "plain", "careless" }) do
    local dm = bots.DMS[dmk]
    T.loose[dmk], T.noticed[dmk] = 0, 0
    for ci = 1, 5 do
        local seed = 4100 + ci * 29 + #dmk
        local c = campaign_mod.new(seed)
        local rng = rng_mod.new(seed + 1)
        c:session_zero(dm.s0)
        local wants_played = {}
        for w = 1, 4 do
            local prep = c:start_week()
            bots.prep(dm, c, prep, rng)
            local night = c:start_night()
            local last_dm, cliff_seen = nil, false
            local fallen = {}
            for _, f in ipairs(c.fallen or {}) do
                fallen[f.char] = true
            end
            bots.play_night(night, rng, dm, function(ev)
                if ev.kind == "narrate" and ev.style == "dm" and (ev.text == "Roll initiative!" or ev.text == "Weapons out. Here we go."
                    or ev.text == "Everyone grab a d20.") then
                    T.fights = T.fights + 1
                    if night.scene and night.scene.foes_said then
                        T.named = T.named + 1
                    end
                end
                if ev.kind == "narrate" and ev.style == "bridge" then
                    T.bridges = T.bridges + 1
                    if string.find(ev.text, "next job", 1, true) or string.find(ev.text, "(", 1, true) then
                        T.bad_bridges = T.bad_bridges + 1
                    end
                end
                if ev.kind == "narrate" and string.find(ev.text or "", "where we leave it for tonight", 1, true) then
                    cliff_seen = true
                    T.cliffs = T.cliffs + 1
                elseif cliff_seen and ev.kind == "scene" then
                    T.cliff_after = T.cliff_after + 1
                end
                if ev.kind == "say" and ev.who then
                    for name in pairs(fallen) do
                        if string.find(ev.text or "", "%f[%a]" .. name .. "%f[%A]") then
                            T.dead_talk = T.dead_talk + 1
                        end
                    end
                    if w == 1 and string.find(string.lower(ev.text or ""), "last week", 1, true) then
                        T.first_week_back = T.first_week_back + 1
                    end
                end
            end)
            for _, sc in ipairs(night.scenes) do
                local g = sc.comps.goal
                if sc.terrain and g and g.agenda and g.agenda_kind == "warm" then
                    if wants_played[g.agenda] then
                        T.want_repeat = T.want_repeat + 1
                    end
                    wants_played[g.agenda] = true
                end
            end
            c:finish_night()
            T.nights = T.nights + 1
            local sl = c.report.storylines
            T.noticed[dmk] = T.noticed[dmk] + #sl.noticed
            T.back = T.back + #sl.back
            T.handouts = T.handouts + #(c.report.handouts or {})
            T.thin = T.thin + (sl.thin and 1 or 0)
        end
        T.loose[dmk] = T.loose[dmk] + #storylines.loose(c)
    end
end
check(T.fights > 20 and T.named == T.fights, "Every fight says who the party is up against before anyone rolls",
    string.format("%d of %d fights", T.named, T.fights))
check(T.bridges > 20 and T.bad_bridges == 0, "Scenes hand over in the DM's words, not \"the next job (...)\"",
    string.format("%d bridges, %d awkward", T.bridges, T.bad_bridges))
check(T.cliff_after == 0, "A cliffhanger is the last thing that happens that night", string.format("%d cliffhangers", T.cliffs))
check(T.dead_talk == 0, "Nobody talks about a fallen hero as if they're still at the table", string.format("%d slips", T.dead_talk))
check(T.want_repeat == 0, "Nobody asks the party for the same favour twice", string.format("%d repeats", T.want_repeat))
check(T.first_week_back == 0, "Nobody mentions \"last week\" in the first session", string.format("%d", T.first_week_back))
check(T.loose.careful < T.loose.careless and T.noticed.careful < T.noticed.careless,
    "A DM who tends the storylines leaves fewer loose ends than one who doesn't",
    string.format("loose at the end: careful %d, plain %d, careless %d (noticed %d / %d / %d)", T.loose.careful, T.loose.plain,
        T.loose.careless, T.noticed.careful, T.noticed.plain, T.noticed.careless))
check(T.handouts > 0 and T.back > 0, "Handouts land, and dropped storylines come back now and then",
    string.format("%d handouts, %d comebacks over %d nights", T.handouts, T.back, T.nights))

-- A loose end, by hand: Mara's story dropped. It wears her down a little each week, to a floor,
-- and comes back with a surprise and everything it cost.
do
    local c = campaign_mod.new(91)
    c:session_zero(bots.DMS.careful.s0)
    require("game.model.planner").apply(c, { threads = { "mara", "dev" } })   -- featured: noticed after two weeks
    local s = storylines.get(c)
    local mara = c:player("mara")
    local start_i, start_t = mara.investment, mara.trust
    local noticed_at
    local fake = { scenes = {} }
    for w = 1, 7 do
        c.week = w
        local out = storylines.after_night(c, fake)
        if not noticed_at and storylines.get(c).bs_mara.loose then
            noticed_at = w
        end
    end
    local got = storylines.get(c).bs_mara.eroded.mara
    local drop_i, drop_t = got.investment, got.trust
    local e = storylines.data.ERODE.backstory
    local all_i = start_i - mara.investment
    check(noticed_at == 3, "A featured backstory nobody touches is noticed after two weeks", "noticed in week " .. tostring(noticed_at))
    check(drop_i > 0 and drop_i <= e.floor_investment + 0.01 and drop_t > 0 and drop_t <= e.floor_trust + 0.01
        and drop_i > e.investment and all_i <= storylines.data.ERODE_TOTAL.investment + 0.01,
        "It wears Investment and Trust down a little each week, never past the floor",
        string.format("-%.1f Investment, -%.1f Trust over %d loose weeks (%.1f from every loose end)", drop_i, drop_t,
            7 - noticed_at + 1, all_i))
    -- It comes back.
    for _, sid in ipairs({ "bells" }) do
        local bst = storylines.get(c)[sid]
        storylines.come_back({ campaign = c, players = {}, emit = function() end, react = function() end,
            highlight = function() end, fresh = function(_, l) return l[1] end, pick_actor = function() end },
            storylines.def(c, sid), bst)
    end
    start_i, start_t = mara.investment + got.investment, mara.trust + got.trust
    c:start_week()
    c:start_night()
    local said = {}
    local night = { campaign = c, players = c:present(), emit = function(_, ev) table.insert(said, ev) end,
                    react = function() end, highlight = function() end, fresh = function(_, l) return l[1] end,
                    pick_actor = function() end }
    local before_fun = mara.fun_bonus
    local card = content.components.corin
    local d = storylines.def(c, "bs_mara")
    local st = storylines.get(c).bs_mara
    storylines.come_back(night, d, st)
    check(math.abs(mara.investment - start_i) < 0.6 and math.abs(mara.trust - start_t) < 0.6 and mara.fun_bonus > before_fun
        and not st.loose, "When it comes back she's surprised and glad, and gets back what it cost",
        string.format("Investment %.0f (was %.0f), Trust %.0f (was %.0f)", mara.investment, start_i, mara.trust, start_t))
    check(#storylines.of_card(c, card) >= 2, "One card can move two storylines at once (Corin: the bells and Mara's story)",
        table.concat(storylines.of_card(c, card), ", "))
end

-- Prep: a cliffhanger only closes the last scene; a want happens where it belongs; handouts cost
-- an hour, two a week, and keep a storyline warm.
do
    local c = campaign_mod.new(17)
    c:session_zero(bots.DMS.careful.s0)
    local prep = c:start_week()
    prep:set_type(1, "social")
    prep:set_type(3, "social")
    local ok1 = prep:can_place(1, "cliffhanger")
    local ok3 = prep:can_place(3, "cliffhanger")
    check(not ok1 and ok3, "A cliffhanger can only close the last scene", tostring(ok1) .. " / " .. tostring(ok3))
    -- The abbot's wish happens in the chapel.
    local ledger = require "game.model.ledger"
    ledger.person(c, "abbot_ghost").att = 2
    local wish = ledger.agenda_card(c, "abbot_ghost")
    prep:place(1, "tavern")
    local ok_tavern, why = prep:can_place(1, wish.id)
    check(wish and not ok_tavern and string.find(why or "", "chapel", 1, true) ~= nil,
        "The abbot's candles happen in the chapel, not the Kettle", tostring(why))
    -- Handouts.
    prep:place(1, "gus")
    local spent = prep:spent()
    local made = handouts.toggle(prep, "gus")
    check(made and prep:spent() == spent + handouts.data.COST, "A handout costs an hour of prep",
        string.format("%d -> %d", spent, prep:spent()))
    prep:place(3, "stranger")
    handouts.toggle(prep, "stranger")
    prep:place(1, "tavern")
    local third = handouts.toggle(prep, "tavern")
    check(not third and handouts.count(prep) == 2, "Two handouts a week", "count " .. handouts.count(prep))
    local st = storylines.get(c).bells
    st.kept = 3
    st.last = 1
    c.week = 3
    local heat = storylines.heat(c, "bells", 3)
    check(heat == "warm", "A storyline with a handout on the table stays warm a week longer", heat)
end

os.exit(ok_all and 0 or 1)
