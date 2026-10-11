-- The A17 gate: party tension. Plays campaigns where the DM lets everything ride and where the
-- DM uses the ladder (the party reacts, a pause, a reminder), and checks that a single rub never
-- becomes a rift, that a pattern left alone does, that the ladder calms it, and that bonds help.
-- Run from the project root:   texlua tools/sim/tension.lua [campaigns] [weeks]

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local content = require "game.model.content"
local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local rapport = require "game.model.rapport"
local bots = require "slice_bots"

local RUNS = tonumber(arg and arg[1]) or 15
local WEEKS = tonumber(arg and arg[2]) or 8

-- One act from scratch: a single sour act must stay calm.
local single_ok = true
do
    local c = campaign_mod.new(1)
    local doer = c:player("jess")
    for _, def in ipairs(content.friction.acts) do
        c.rel = nil
        rapport.on_act(c, doer, def, c.players, "dev", 1)
        for _, p in ipairs(c.players) do
            if p ~= doer and rapport.stage(c, p.key, doer.key) ~= "calm" then
                single_ok = false
                print("  one act made a rift: " .. def.id .. " " .. p.key)
            end
        end
    end
end

local POL = {
    ride = function(card) return 1 end,
    ladder = function(card)
        for i, o in ipairs(card.options) do
            if o.label:find("Ask ", 1, true) or o.label:find("Pause", 1, true) or o.label:find("Remind", 1, true) then
                return i
            end
        end
        return 2
    end,
}

local res = {}
for _, pol in ipairs({ "ride", "ladder" }) do
    local r = { acts = 0, bonds = 0, nights = 0, live = 0, brewing = 0, pairs = 0, rapport = 0, bonded_rap = 0, bonded_n = 0,
                vents = 0 }
    res[pol] = r
    for run = 1, RUNS do
        local c = campaign_mod.new(5000 + run * 17)
        local rng = rng_mod.new(5100 + run)
        c:session_zero(bots.DMS.careful.s0)
        local bonded = {}
        for w = 1, WEEKS do
            local prep = c:start_week()
            for _, m in ipairs(c.chat or {}) do
                for _, v in ipairs(content.friction.vents) do
                    if m.text and m.text:sub(1, 12) == v:sub(1, 12) then r.vents = r.vents + 1 end
                end
            end
            bots.prep(bots.DMS.careful, c, prep, rng)
            local night = c:start_night()
            local ev = night:advance()
            while ev.kind ~= "done" do
                local a
                if ev.kind == "decision" then
                    if ev.card.id:sub(1, 9) == "friction_" then
                        a = POL[pol](ev.card)
                    else
                        a = rng:int(1, #ev.card.options)
                    end
                elseif ev.kind == "improv" then a = 1
                elseif ev.kind == "roll_where" then a = "open"
                elseif ev.kind == "roll" then a = rng:d20()
                elseif ev.kind == "cook" then a = false end
                ev = night:advance(a)
            end
            r.acts = r.acts + #(night.frictions or {})
            r.bonds = r.bonds + #(night.bonds or {})
            for _, b in ipairs(night.bonds or {}) do
                bonded[b.a .. b.b] = true
                bonded[b.b .. b.a] = true
            end
            r.nights = r.nights + 1
            c:finish_night()
        end
        for _, a in ipairs(c.players) do
            for _, b in ipairs(c.players) do
                if a.key < b.key then
                    local st = rapport.stage(c, a.key, b.key)
                    r.pairs = r.pairs + 1
                    if st == "live" then r.live = r.live + 1 elseif st == "brewing" then r.brewing = r.brewing + 1 end
                end
                if a ~= b then
                    local rel = rapport.rel(c, a.key, b.key)
                    r.rapport = r.rapport + rel.rapport
                    local start = rapport.SEED[a.key .. "_" .. b.key] or rapport.BASE
                    if bonded[a.key .. b.key] then
                        r.bonded_rap = r.bonded_rap + (rel.rapport - start)
                        r.bonded_n = r.bonded_n + 1
                    else
                        r.other_rap = (r.other_rap or 0) + (rel.rapport - start)
                        r.other_n = (r.other_n or 0) + 1
                    end
                end
            end
        end
    end
end

for _, pol in ipairs({ "ride", "ladder" }) do
    local r = res[pol]
    print(string.format("%-7s %.2f acts and %.2f bonds a night; pairs strained %d, in a rift %d of %d; avg rapport %.1f (bonded %.1f); vents %d",
        pol, r.acts / r.nights, r.bonds / r.nights, r.brewing, r.live, r.pairs, r.rapport / (r.pairs * 2),
        r.bonded_n > 0 and r.bonded_rap / r.bonded_n or 0, r.vents))
end
local ride, lad = res.ride, res.ladder
local gates = {
    { "A single act never makes a rift on its own", single_ok },
    { "Acts and bonds come up now and then (0.3 to 1.5 a night each)",
      ride.acts / ride.nights >= 0.3 and ride.acts / ride.nights <= 1.5 and ride.bonds / ride.nights >= 0.3 and ride.bonds / ride.nights <= 1.5 },
    { "Left alone, a pattern strains friendships", ride.brewing + ride.live > 0 },
    { "The DM's ladder keeps the table closer than letting it ride",
      (lad.brewing + 2 * lad.live) < (ride.brewing + 2 * ride.live) and lad.rapport >= ride.rapport },
    { "Bonds help: pairs who bonded gain more than pairs who didn't",
      ride.bonded_rap / math.max(1, ride.bonded_n) > (ride.other_rap or 0) / math.max(1, ride.other_n or 0) },
    { "A strained table vents in the group chat", ride.vents > 0 },
}
local ok = true
for _, g in ipairs(gates) do
    print(string.format("  [%s] %s", g[2] and "PASS" or "FAIL", g[1]))
    ok = ok and g[2]
end
os.exit(ok and 0 or 1)
