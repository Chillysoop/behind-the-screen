-- The table matches the story: a place goes down with its floor and walls, and every other piece
-- drops in when the DM's words name it (the place's own line, then a line setting out the rest);
-- the person in the scene steps onto the mat when they're named or speak; a fight has the whole
-- board. Plays whole nights headlessly. Run from the project root:
--   lua tools/tests/board_story_check.lua [campaigns] [weeks]     (BOARD_SHOW=1 prints scene openings)

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path
unpack = unpack or table.unpack

local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local styles = require "tools.sim.dm_styles"
local board = require "game.model.board"

local CAMPAIGNS = tonumber(arg and arg[1]) or 4
local WEEKS = tonumber(arg and arg[2]) or 4
local SHOW = os.getenv("BOARD_SHOW")

local T = { scenes = 0, features = 0, by_words = 0, by_dressing = 0, late = 0, bad_word = 0, npc_scenes = 0,
            npc_named = 0, npc_late = 0, fights = 0, fights_full = 0, boards = {} }
local problems = {}
local function problem(s)
    if #problems < 20 then
        table.insert(problems, s)
    end
end

local function answer(ev, rng, style)
    local k = ev.kind
    if k == "decision" then
        return rng:int(1, #ev.card.options)
    elseif k == "improv" then
        return { 1 }
    elseif k == "roll_where" then
        return style.roll_where(ev, rng)
    elseif k == "roll" then
        return rng:d20()
    elseif k == "ruling" then
        return rng:int(1, #ev.options)
    end
end

for ci = 1, CAMPAIGNS do
    for _, skey in ipairs({ "balanced", "story_threads", "random" }) do
        local style = styles[skey]
        local seed = 9100 + ci * 31 + #skey
        local c = campaign_mod.new(seed)
        local rng = rng_mod.new(seed + 5)
        for w = 1, WEEKS do
            local prep = c:start_week()
            style.prep(prep, rng, c)
            local night = c:start_night()
            local cur, shown, prompted, npc_wait, shown_lines
            local function close()
                if cur then
                    local all = board.compile(cur)
                    for _, f in ipairs(all.features) do
                        if not shown[f.id] then
                            -- never shown in this scene: it came down when play started (counted late)
                        end
                    end
                end
            end
            local ev = night:advance()
            while ev.kind ~= "done" do
                if ev.kind == "scene" or (ev.kind == "stage" and ev.terrain ~= cur) then
                    close()
                    local same = ev.terrain == cur
                    cur = ev.terrain
                    prompted = false
                    T.scenes = T.scenes + 1
                    T.boards[cur] = (T.boards[cur] or 0) + 1
                    if not same then
                        -- (the same place again keeps what's already on the table)
                        shown, shown_lines = {}, {}
                        for _, id in ipairs(board.base_ids(cur)) do
                            shown[id] = true
                        end
                        T.features = T.features + #board.compile(cur).features - #board.base_ids(cur)
                    end
                    npc_wait = ev.npc_hidden and ev.npc ~= nil
                    if npc_wait then
                        T.npc_scenes = T.npc_scenes + 1
                    end
                    if SHOW then
                        print(string.format("== %s (%s)", ev.title or "?", cur))
                    end
                end
                if ev.reveal and cur then
                    local c2 = board.compile(cur)
                    for _, r in ipairs(ev.reveal) do
                        shown[r.id] = true
                        local feat = c2.by_id[r.id]
                        if ev.dressing then
                            T.by_dressing = T.by_dressing + 1
                        elseif ev.kind == "narrate" or ev.kind == "npc" then
                            T.by_words = T.by_words + 1
                            if not (feat and board.mention(feat, ev.text)) then
                                T.bad_word = T.bad_word + 1
                                problem("revealed " .. r.id .. " on a line that doesn't name it: " .. tostring(ev.text))
                            end
                        else
                            T.late = T.late + 1
                            if ev.kind == "battle" then
                                -- fights get the whole board: fine, but still counted as late
                            end
                        end
                    end
                    if SHOW and (ev.kind == "narrate" or ev.kind == "npc") then
                        local ids = {}
                        for _, r in ipairs(ev.reveal) do
                            table.insert(ids, r.id)
                        end
                        print("   [" .. table.concat(ids, ", ") .. "]  " .. tostring(ev.text))
                    end
                end
                if ev.npc_show then
                    if prompted or not (ev.kind == "narrate" or ev.kind == "npc") then
                        T.npc_late = T.npc_late + 1
                        if SHOW then
                            local cs = night.scene and night.scene.comps.cast
                            print("   <npc late on " .. ev.kind .. "> cast " .. tostring(cs and cs.id) .. " type "
                                .. tostring(night.scene and night.scene.type) .. " fits " .. tostring(night:fits_here(cs)))
                        end
                    else
                        T.npc_named = T.npc_named + 1
                    end
                    npc_wait = false
                    if SHOW then
                        print("   <npc steps in>  " .. tostring(ev.text or ev.kind))
                    end
                end
                if ev.kind == "battle" and ev.phase == "start" and cur then
                    T.fights = T.fights + 1
                    local all = true
                    for _, f in ipairs(board.compile(cur).features) do
                        all = all and shown[f.id] == true
                    end
                    T.fights_full = T.fights_full + (all and 1 or 0)
                end
                if ev.kind == "decision" or ev.kind == "ruling" or ev.kind == "roll_where" then
                    prompted = true
                end
                ev = night:advance(answer(ev, rng, style))
            end
            c:finish_night()
        end
    end
end

local function pct(a, b)
    return b > 0 and math.floor(100 * a / b + 0.5) or 100
end
local used = 0
for _ in pairs(T.boards) do
    used = used + 1
end
print(string.format("%d scenes on %d boards; %d pieces to set out: %d named in the narration, %d in the DM's setting-out line, "
    .. "%d put down when play started", T.scenes, used, T.features, T.by_words, T.by_dressing, T.late))
print(string.format("people: %d scenes with someone to meet, %d stepped in when named or speaking, %d only once play started",
    T.npc_scenes, T.npc_named, T.npc_late))
for _, p in ipairs(problems) do
    print("  " .. p)
end
local ok = true
local function check(cond, what, detail)
    print(string.format("  [%s] %s  -  %s", cond and "PASS" or "FAIL", what, detail))
    ok = ok and cond
end
check(T.bad_word == 0 and T.by_words > 0,
    "A piece drops in only on words that name it", string.format("%d named, %d on the wrong words", T.by_words, T.bad_word))
check(T.features > 0 and (T.by_words + T.by_dressing) >= 0.9 * T.features,
    "The DM sets out 90% of every board in words before play starts",
    string.format("%d%% in words", pct(T.by_words + T.by_dressing, T.features)))
check(T.npc_scenes == 0 or T.npc_named >= 0.8 * T.npc_scenes,
    "The person in the scene steps in when they're named or speak", string.format("%d of %d", T.npc_named, T.npc_scenes))
check(T.fights == T.fights_full, "Every fight has the whole board", string.format("%d of %d fights", T.fights_full, T.fights))
os.exit(ok and 0 or 1)
