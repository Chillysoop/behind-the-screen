-- Behavioral checks for the separate guided campaign. No Defold runtime required.
-- Run from the repository root: lua tools/tests/guided_check.lua
package.path = "./?.lua;" .. package.path

local guided = require "game.model.guided"
local json = require "game.model.jsonlite"
local boards = require "game.data.boards"
local sprites = {}
do
    local file = assert(io.open("assets/sprites/sprites.atlas"))
    for name in file:read("*a"):gmatch('/assets/sprites/([%w_]+)%.png') do sprites[name] = true end
    file:close()
end
local checks, campaigns, battles, rolls = 0, 0, 0, 0

local function expect(ok, message)
    checks = checks + 1
    assert(ok, message)
end

local function copy(value)
    return json.decode(json.encode(value))
end

local function check_round_trip(state)
    local before = guided.dump(state)
    local snap = guided.snapshot(state)
    expect(type(snap) == "table" and type(snap.phase) == "string", "snapshot must describe its phase")
    expect(guided.dump(state) == before, "reading a snapshot must not consume dice or mutate the story")
    local restored, reason = guided.restore(before)
    expect(restored ~= nil, "valid save rejected: " .. tostring(reason))
    expect(guided.dump(restored) == before, "save round trip changed campaign state")
    expect(json.encode(guided.snapshot(restored)) == json.encode(snap), "resume changed the current screen")
    expect(type(snap.title) == "string" and #snap.title > 0, "every screen needs a title")
    expect(type(snap.text) == "string", "every screen needs readable context")
    expect(boards[snap.board] ~= nil, "scene references a missing tabletop board")
    if snap.npc then expect(sprites[snap.npc], "scene references a missing NPC sprite") end
    if snap.battle then
        for _, actor in ipairs(snap.battle.actors) do
            expect(sprites[actor.sprite], "battle references a missing miniature sprite: " .. tostring(actor.sprite))
        end
    end
    local ids = {}
    for _, card in ipairs(snap.cards or {}) do
        expect(type(card.id) == "string" and #card.id > 0, "choice needs an id")
        expect(not ids[card.id], "duplicate choice id on a screen")
        expect(type(card.title) == "string" and #card.title > 0, "choice needs an intention")
        expect(type(card.body) == "string" and #card.body > 0, "choice needs context or stakes")
        ids[card.id] = true
    end
    expect(#(snap.cards or {}) <= 3, "a screen offers more than three decisions")
    return restored, snap
end

-- An invalid input must not advance the episode, spend a choice, or alter the RNG.
local function check_invalid(state)
    local before = guided.dump(state)
    local ok, reason = guided.choose(state, "not-a-real-choice")
    expect(not ok and type(reason) == "string", "invalid choice should be rejected with a reason")
    expect(guided.dump(state) == before, "invalid choice mutated the campaign")
    if state.phase == "prep_focus" or state.phase == "prep_twist" or state.phase == "decision" or state.phase == "hook" then
        ok, reason = guided.advance(state)
        expect(not ok, "advance bypassed a required meaningful decision")
        expect(guided.dump(state) == before, "invalid advance mutated the campaign")
    end
end

local function run(seed, policy)
    local state = guided.new(seed)
    local counts = { prep_focus = 0, prep_twist = 0, decision = 0, hook = 0 }
    local visited, saw_roll, saw_battle = {}, false, false
    local transitions = 0
    while state.phase ~= "complete" do
        transitions = transitions + 1
        expect(transitions <= 80, "campaign is stuck or requires too many screens")
        local snap
        state, snap = check_round_trip(state)
        check_invalid(state)
        expect(state.episode >= 1 and state.episode <= 4, "episode escaped the authored campaign")
        if snap.roll then
            rolls = rolls + 1
            saw_roll = true
            expect(snap.roll.d20 >= 1 and snap.roll.d20 <= 20, "invalid d20")
            expect(snap.roll.total == snap.roll.d20 + snap.roll.modifier, "displayed total disagrees with die")
            expect(snap.roll.success == (snap.roll.total >= snap.roll.dc), "displayed die outcome is inconsistent")
        end
        if snap.battle then
            battles = battles + 1
            saw_battle = true
            expect(type(snap.battle.events) == "table" and #snap.battle.events > 0, "combat has no rules-engine replay")
            expect(type(snap.battle.actors) == "table" and #snap.battle.actors >= 4, "combat lost the party")
            expect(type(snap.battle.summary) == "string" and #snap.battle.summary > 0, "combat needs a readable result")
            expect(snap.battle.rounds and snap.battle.rounds <= 30, "combat failed to terminate promptly")
        end
        if counts[snap.phase] ~= nil then
            counts[snap.phase] = counts[snap.phase] + 1
            expect(#snap.cards >= 2, "a meaningful choice must offer alternatives")
            local index = policy == 1 and 1 or policy == 2 and #snap.cards
                or ((seed + state.episode * 3 + (state.scene_index or 1)) % #snap.cards + 1)
            local card = snap.cards[index]
            visited[#visited + 1] = snap.phase .. ":" .. card.id
            -- Every sibling is executable from the exact same state; none relies on a UI-only precondition.
            for _, alternative in ipairs(snap.cards) do
                local sibling = assert(guided.restore(guided.dump(state)))
                local ok, reason = guided.choose(sibling, alternative.id)
                expect(ok, "unplayable offered choice " .. alternative.id .. ": " .. tostring(reason))
                local _, other = check_round_trip(sibling)
                expect(other.phase ~= snap.phase or other.episode ~= snap.episode, "choice failed to leave its prompt")
            end
            local encoded = guided.dump(state)
            local twin = assert(guided.restore(encoded))
            local ok, reason = guided.choose(state, card.id)
            expect(ok, "choice failed: " .. tostring(reason))
            expect(guided.choose(twin, card.id), "identical restored choice failed")
            expect(guided.dump(twin) == guided.dump(state), "save/reload changed a choice or rerolled its outcome")
        else
            expect(snap.continue_label ~= nil, "non-choice phase has no continuation")
            local ok, reason = guided.advance(state)
            expect(ok, "continue failed: " .. tostring(reason))
        end
    end
    check_round_trip(state)
    expect(counts.prep_focus == 4 and counts.prep_twist == 4, "campaign must have exactly two prep choices per episode")
    expect(counts.decision == 16, "campaign must have four live calls per episode")
    expect(counts.hook == 3, "only the first three episodes should ask what comes next")
    expect(state.level >= 3 and state.level <= 4, "automatic progression did not happen")
    expect(#state.keepsakes > 0, "campaign did not earn a keepsake")
    expect(#state.history >= 16, "completed campaign lost its played moments")
    local again = guided.dump(state)
    local ok = guided.advance(state)
    expect(not ok, "completed campaign should wait for explicit replay")
    expect(guided.dump(state) == again, "completion unexpectedly created another episode")
    campaigns = campaigns + 1
    return state, visited, saw_roll, saw_battle
end

local a, route_a = run(41, 1)
local b, route_b = run(41, 2)
expect(json.encode(a.flags) ~= json.encode(b.flags), "different DM decisions produced identical persistent consequences")
expect(json.encode(a.history) ~= json.encode(b.history), "different choices produced the same remembered campaign")
expect(table.concat(route_a, ",") ~= table.concat(route_b, ","), "test routes were not distinct")
for seed = 1, 12 do
    run(seed * 7919, 3)
end
expect(rolls > 0, "sample campaigns never resolved a visible check")
expect(battles > 0, "sample campaigns never used the combat rules engine")

-- The alternate format must reject the classic format and truncated/foreign saves.
for _, raw in ipairs({ "", "{", "[]", "null", "{}", '{"kind":"classic","version":1}',
    '{"kind":"behind_the_screen_guided","version":999}' }) do
    local ok, restored = pcall(guided.restore, raw)
    expect(ok and restored == nil, "malformed or foreign save escaped validation")
end
local broken = copy(guided.new(7))
broken.phase = "unknown"
expect(guided.restore(json.encode(broken)) == nil, "unknown phase accepted")
broken = copy(guided.new(7))
broken.episode = 99
expect(guided.restore(json.encode(broken)) == nil, "out-of-range episode accepted")

for _, name in ipairs({ "game.model.prep", "game.model.social", "game.model.storylines", "game.model.empathy" }) do
    expect(package.loaded[name] == nil, "guided loop still depends on removed obligation model " .. name)
end

print(string.format("GUIDED MODEL PASS: %d checks, %d complete campaigns, %d visible rolls, %d battle replays", checks, campaigns, rolls, battles))
