-- Rapport between players (A17: party tension). For each directed pair a->b ("how Dev feels
-- about Jess"): rapport (the friendship, slow), heat (recent irritation, fast), and base (what
-- rapport mends back to; a rift that goes live leaves a scar). One rub stays calm, a pattern
-- brews, a betrayal goes live; friends shrug off more, strained pairs read malice into
-- everything. Pure Lua. Data: game/data/friction.lua.

local content = require "game.model.content"
local score = require "game.model.score"
local util = require "game.model.util"

local M = {}

M.BASE = 60
M.SEED = { mara_jess = 52, jess_mara = 52, dev_sam = 54, sam_dev = 54 }
M.HEAT = { 6, 14, 30 }        -- heat per objecting witness by severity, times how much they mind
M.TARGET_MULT = 1.25          -- the one it was done to
M.GRACE = 15                  -- heat a friendship absorbs each week without lasting damage
M.BITE = 0.4                  -- rapport lost per point of heat above GRACE at week end
M.COOL = 0.6                  -- share of heat that survives a week
M.MEND = 2                    -- rapport back per calm week, up to base
M.SCAR = 4                    -- base lost when a rift goes live
M.ENJOY = 1.5                 -- rapport per severity point between a doer and someone who loved it
M.BREWING, M.ACTIVE = 40, 70  -- the table conflicts' stages

function M.get(campaign)
    if not campaign.rel then
        campaign.rel = {}
        for _, a in ipairs(campaign.players) do
            campaign.rel[a.key] = {}
            for _, b in ipairs(campaign.players) do
                if a ~= b then
                    local r = M.SEED[a.key .. "_" .. b.key] or M.BASE
                    campaign.rel[a.key][b.key] = { rapport = r, heat = 0, base = r }
                end
            end
        end
    end
    return campaign.rel
end

function M.rel(campaign, a, b)
    local row = M.get(campaign)[a]
    return row and row[b]
end

local function blend(p, t)
    local v = 0
    if t then
        v = (t[p.primary] or 0) * 2 / 3 + (t[p.secondary] or 0) / 3
    end
    return v
end

-- How a witness takes an act, -3..3 (research: tag tastes, plus who objects or enjoys, plus
-- being on the receiving end).
function M.reaction(w, act, target_key)
    local tt = content.friction.tag_taste
    local sum, n = 0, 0
    for _, tag in ipairs(act.tags or {}) do
        local row1, row2 = tt[w.primary] or {}, tt[w.secondary] or {}
        sum = sum + (row1[tag] or 0) * 2 / 3 + (row2[tag] or 0) / 3
        n = n + 1
    end
    local r = (n > 0 and sum / n or 0) + blend(w, act.enjoys) - blend(w, act.objects)
    if target_key == w.key then
        r = r - 1
    end
    return util.clamp(r, -3, 3)
end

local function forgiveness(rapport)
    return util.clamp(1.3 - rapport / 100, 0.45, 1.0)
end

-- One act, as the rest of the table sees it. heat_mult: how the DM handled it. Returns
-- { objectors = { players }, enjoyers = { players } }.
function M.on_act(campaign, doer, act, witnesses, target_key, heat_mult)
    local out = { objectors = {}, enjoyers = {} }
    local sev = util.clamp(act.severity or 1, 1, 3)
    for _, w in ipairs(witnesses) do
        if w ~= doer then
            local rel = M.rel(campaign, w.key, doer.key)
            local r = M.reaction(w, act, target_key)
            if rel and r <= -0.5 then
                local h = M.HEAT[sev] * -r * forgiveness(rel.rapport) * (heat_mult or 1)
                if target_key == w.key then
                    h = h * M.TARGET_MULT
                end
                rel.heat = util.clamp(rel.heat + h, 0, 100)
                rel.touched = true
                rel.last_act = act.id
                score.add(w, "fun", -2 * sev)
                score.add(w, "social", -sev)
                table.insert(out.objectors, w)
            elseif rel and r >= 0.5 then
                rel.rapport = util.clamp(rel.rapport + M.ENJOY * sev * math.min(r, 2) / 2, 0, 100)
                rel.heat = math.max(0, rel.heat - 3)
                score.add(w, "fun", 2 * sev)
                table.insert(out.enjoyers, w)
            end
        end
    end
    score.add(doer, "spotlight", 3 * sev)
    score.add(doer, "fun", 2 * sev)
    return out
end

-- The good side: a bond between two players (both ways), and amends cool the heat.
function M.bond(campaign, a, b, n, amends)
    for _, pair in ipairs({ { a, b }, { b, a } }) do
        local rel = M.rel(campaign, pair[1], pair[2])
        if rel then
            rel.rapport = util.clamp(rel.rapport + n, 0, 100)
            rel.heat = amends and rel.heat * 0.4 or math.max(0, rel.heat - 2)
            if amends and rel.base < M.BASE then
                rel.base = math.min(M.BASE, rel.base + M.SCAR)   -- amends heal a scar
            end
        end
    end
end

-- Pair pressure on the conflicts' 0..100 scale: recent heat, and how low the friendship is.
function M.pressure(campaign, a, b)
    local ab, ba = M.rel(campaign, a, b), M.rel(campaign, b, a)
    if not ab or not ba then
        return 0
    end
    local heat = math.max(ab.heat, ba.heat)
    local low = math.min(ab.rapport, ba.rapport)
    return util.clamp(heat * 0.6 + math.max(0, 60 - low) * 2, 0, 100)
end

function M.stage(campaign, a, b)
    local p = M.pressure(campaign, a, b)
    if p >= M.ACTIVE then
        return "live", p
    elseif p >= M.BREWING then
        return "brewing", p
    end
    return "calm", p
end

-- Week end: heat turns into lasting damage only above GRACE; calm weeks mend; a rift that
-- goes live leaves a scar.
function M.week_end(campaign)
    local rel = M.get(campaign)
    for a, row in pairs(rel) do
        for b, e in pairs(row) do
            local over = math.max(0, e.heat - M.GRACE)
            e.rapport = util.clamp(e.rapport - over * M.BITE, 0, 100)
            if e.heat < M.GRACE and not e.touched then
                e.rapport = math.min(e.base, e.rapport + M.MEND)
            end
            e.heat = e.heat * M.COOL
            e.touched = false
        end
    end
    for _, a in ipairs(campaign.players) do
        for _, b in ipairs(campaign.players) do
            if a.key < b.key then
                local st = M.stage(campaign, a.key, b.key)
                local ab, ba = M.rel(campaign, a.key, b.key), M.rel(campaign, b.key, a.key)
                if st == "live" and not ab.scarred then
                    ab.base, ba.base = ab.base - M.SCAR, ba.base - M.SCAR
                    ab.scarred, ba.scarred = true, true
                elseif st == "calm" then
                    ab.scarred, ba.scarred = nil, nil
                end
            end
        end
    end
end

-- The pairs under strain, worst first: { a, b, stage, pressure, hurt (who minds more), doer }.
function M.strained(campaign)
    local out = {}
    for _, a in ipairs(campaign.players) do
        for _, b in ipairs(campaign.players) do
            if a.key < b.key then
                local st, p = M.stage(campaign, a.key, b.key)
                if st ~= "calm" then
                    local ab, ba = M.rel(campaign, a.key, b.key), M.rel(campaign, b.key, a.key)
                    local hurt, doer = a, b
                    if ba.heat > ab.heat then
                        hurt, doer = b, a
                    end
                    table.insert(out, { a = a, b = b, stage = st, pressure = p, hurt = hurt, doer = doer })
                end
            end
        end
    end
    table.sort(out, function(x, y) return x.pressure > y.pressure end)
    return out
end

-- How a player feels about another, in a word, for the notebook's party page.
function M.word(campaign, a, b)
    local rel = M.rel(campaign, a, b)
    if not rel then
        return nil
    end
    local st = M.stage(campaign, a, b)
    if st == "live" then
        return "Rift", "red"
    elseif st == "brewing" then
        return "Strained", "orange"
    elseif rel.rapport >= 70 then
        return "Close", "green"
    end
    return "Fine", "dim"
end

-- The group chat between weeks: someone hurt vents (once per pair per stage change).
function M.chat(campaign, msgs)
    local data = content.friction
    for _, s in ipairs(M.strained(campaign)) do
        local key = s.a.key .. "_" .. s.b.key
        campaign.vented = campaign.vented or {}
        if campaign.vented[key] ~= s.stage and not s.hurt.on_break then
            campaign.vented[key] = s.stage
            local i = ((campaign.week or 1) % #data.vents) + 1
            table.insert(msgs, { who = s.hurt.name, key = s.hurt.key,
                                 text = util.fill(data.vents[i], { doer_char = s.doer.char }) })
            return
        end
    end
end

return M
