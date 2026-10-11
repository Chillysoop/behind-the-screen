-- The A16 gate: rests at the table. Plays campaigns with three DM policies and checks that
-- the players ask, that resting matters (no rest, fewer resources at the next fight), that a
-- cliffhanger night's state carries into the next, and that the table remembers how you rule.
-- Run from the project root:   texlua tools/sim/rests.lua [campaigns] [weeks]

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local rest_rules = require "game.rules.rest"
local bots = require "slice_bots"

local RUNS = tonumber(arg and arg[1]) or 15
local WEEKS = tonumber(arg and arg[2]) or 4

local POLICIES = {
    kind = function(card) return 1 end,                                      -- first offer: usually a yes
    hard = function(card)                                                    -- a no, else an interruption
        for _, want in ipairs({ "can't rest", "until", "clock" }) do
            for i, o in ipairs(card.options) do
                if o.label:find(want, 1, true) then
                    return i
                end
            end
        end
        return #card.options
    end,
    mixed = nil,
}

local res = {}
for _, pol in ipairs({ "kind", "hard", "mixed" }) do
    local r = { asks = 0, nights = 0, rests = 0, fight_hp = {}, carried_ok = 0, carried_n = 0, trust = 0, players = 0 }
    res[pol] = r
    for run = 1, RUNS do
        local c = campaign_mod.new(3000 + run * 11)
        local rng = rng_mod.new(3100 + run)
        c:session_zero(bots.DMS.careful.s0)
        for w = 1, WEEKS do
            local prep = c:start_week()
            bots.prep(bots.DMS.careful, c, prep, rng)
            local carried = c.party_state and not c.party_state.rested and c.party_state.level == (c.level or 2)
            local expect = carried and {} or nil
            if carried then
                for k, s in pairs(c.party_state.pcs) do
                    expect[k] = s.hp
                end
            end
            local night = c:start_night()
            -- The carry itself: tonight's party starts as last week's ended.
            if expect then
                require("game.model.fight").party(night)
                r.carried_n = r.carried_n + 1
                local same = true
                for _, pc in ipairs(night.pc_list) do
                    if expect[pc.player_key] and pc.hp ~= math.min(pc.hp_max, math.max(1, expect[pc.player_key])) then
                        same = false
                    end
                end
                r.carried_ok = r.carried_ok + (same and 1 or 0)
                expect = nil
            end
            local first_battle = true
            local ev = night:advance()
            while ev.kind ~= "done" do
                local a
                if ev.kind == "decision" then
                    if ev.card.id == "rest_request" then
                        r.asks = r.asks + 1
                        local f = POLICIES[pol]
                        a = f and f(ev.card) or rng:int(1, #ev.card.options)
                    else
                        a = rng:int(1, #ev.card.options)
                    end
                elseif ev.kind == "improv" then a = 1
                elseif ev.kind == "roll_where" then a = "open"
                elseif ev.kind == "roll" then a = rng:d20()
                elseif ev.kind == "cook" then a = false
                elseif ev.kind == "battle" and ev.phase == "start" then
                    local st = rest_rules.state(night.pc_list)
                    if not first_battle then
                        table.insert(r.fight_hp, st.hp)
                    end
                    -- A carried night's first fight starts from where they left off.
                    if first_battle and expect then
                        r.carried_n = r.carried_n + 1
                        local same = true
                        for _, p in ipairs(ev.party or {}) do
                            if expect[p.id] and p.hp > expect[p.id] then
                                same = false
                            end
                        end
                        r.carried_ok = r.carried_ok + (same and 1 or 0)
                    end
                    first_battle = false
                end
                ev = night:advance(a)
            end
            r.rests = r.rests + #(night.rests or {})
            r.nights = r.nights + 1
            c:finish_night()
        end
        for _, p in ipairs(c.players) do
            r.trust = r.trust + p.trust
            r.players = r.players + 1
        end
    end
end

local function avg(t)
    local s = 0
    for _, v in ipairs(t) do
        s = s + v
    end
    return #t > 0 and s / #t or 0
end
for _, pol in ipairs({ "kind", "hard", "mixed" }) do
    local r = res[pol]
    print(string.format("%-6s asks %.2f a night, rests %.2f a night, later fights start at %.0f%% HP, trust %.0f, carried %d/%d",
        pol, r.asks / r.nights, r.rests / r.nights, 100 * avg(r.fight_hp), r.trust / r.players, r.carried_ok, r.carried_n))
end
local k, h = res.kind, res.hard
local gates = {
    { "The players ask to rest, about one to two times a night", (res.mixed.asks / res.mixed.nights) >= 0.5 and (res.mixed.asks / res.mixed.nights) <= 2 },
    { "Resting matters: a party you never let rest meets later fights weaker", avg(h.fight_hp) < avg(k.fight_hp) - 0.05 },
    { "No rest since last week: the night picks up where it stopped", k.carried_n + h.carried_n > 0 and k.carried_ok + h.carried_ok == k.carried_n + h.carried_n },
    { "The table remembers: a DM who never lets them rest loses trust", h.trust / h.players < k.trust / k.players },
}
local ok = true
for _, g in ipairs(gates) do
    print(string.format("  [%s] %s", g[2] and "PASS" or "FAIL", g[1]))
    ok = ok and g[2]
end
os.exit(ok and 0 or 1)
