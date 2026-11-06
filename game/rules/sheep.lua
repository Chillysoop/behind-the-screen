-- The Wild Sheep Chase's creatures' own turns (the book's stat blocks, page 5): the bed dragon's Splinter Breath, and
-- Ahmed Noke's Thunderwave from his spell list. A stat block names its turn: `rules = "sheep"`, `rules_turn` (the
-- adventure's creatures in game/data/sheep/module.lua, through game/model/standard.lua). Our words for what happens.
-- Engine-free, like the rest of game/rules/.

local M = {}

-- (The foes in a cone in front of it: within its length, and no more than 45 degrees off the line to the one it aims at.)
local function in_cone(b, c, aim, length)
    local ax, ay = aim.x - c.x, aim.y - c.y
    local al = math.sqrt(ax * ax + ay * ay)
    local out = {}
    for _, o in ipairs(b:enemies_of(c)) do
        if b:dist(c, o) <= length + 5 then
            local ox, oy = o.x - c.x, o.y - c.y
            local ol = math.sqrt(ox * ox + oy * oy)
            if al == 0 or ol == 0 or (ax * ox + ay * oy) / (al * ol) >= 0.70 then
                table.insert(out, o)
            end
        end
    end
    return out
end

-- An area that calls for a save: half on a success when `half`. Returns how many it caught.
local function area(b, c, targets, p, label)
    b:log("%s: %s!", c.name, label)
    b:emit({ kind = "feature", who = c, name = label })
    for _, o in ipairs(targets) do
        local ok = b:save(o, p.save, p.dc, { kind = p.kind or "area" })
        local parts = b:roll_parts(p.damage)
        if ok and p.half then
            for _, part in ipairs(parts) do
                part[1] = math.floor(part[1] / 2)
            end
        end
        if not ok or p.half then
            b:deal(c, o, parts, { spell = p.id })
        end
    end
    return #targets
end

-- Its rider (p5: Noke on its back): a Ray of Frost each turn at whoever's furthest off within range, the one backing away.
local function rider(b, c, H)
    local rd = c.data.rider
    if not (rd and rd.attack) or c.dead or c.down then
        return
    end
    local best, bd
    for _, e in ipairs(H.enemies(b, c)) do
        local d = b:dist(c, e)
        if d <= rd.attack.range[1] and H.in_shot(b, c.x, c.y, e, rd.attack.range[1]) and (not bd or d > bd) then
            best, bd = e, d
        end
    end
    if best then
        b:log("  %s, on its back, points a finger.", rd.name)
        H.attack_with(b, c, best, rd.attack, true)
    end
end

-- The bed dragon (p5): Splinter Breath when it's ready (back on a 5 or 6 at the start of its turn), at whoever it can
-- catch two of if it can; otherwise it bites like anything else. Then its rider's ray.
function M.bed_dragon(b, c, H)
    if not M.breathe(b, c, H) then
        H.standard(b, c)
    end
    rider(b, c, H)
    return true
end
function M.breathe(b, c, H)
    local br = c.data.breath
    if not br then
        return false
    end
    if c.breath_spent then
        local r = b.dice:d(6)
        if r >= ((br.recharge and br.recharge[1]) or 5) then
            c.breath_spent = nil
            b:log("  %s's breath is back (%d).", c.name, r)
        end
    end
    if c.breath_spent then
        return false
    end
    local best, bn
    for _, e in ipairs(H.by_distance(b, c, H.enemies(b, c))) do
        local n = #in_cone(b, c, e, br.cone or 15)
        if b:dist(c, e) <= (br.cone or 15) + 5 and (not bn or n > bn) then
            best, bn = e, n
        end
    end
    if not best then
        return false
    end
    c.breath_spent = true
    c.turn.action = false
    area(b, c, in_cone(b, c, best, br.cone or 15), br, br.name or "Breath")
    return true
end

-- Noke (p5): Thunderwave when someone's right up close and he has a first-level slot (a 15-foot cube from him:
-- everyone within 10 feet of him), then he steps back. Otherwise his dagger and Ray of Frost, and running when it's lost
-- (flees_below, ai.lua).
function M.noke(b, c, H)
    local tw = c.data.thunderwave
    c.slots1 = c.slots1 or (tw and tw.slots) or 0
    if not tw or c.slots1 <= 0 then
        return false
    end
    local close = {}
    for _, e in ipairs(H.enemies(b, c)) do
        if b:dist(c, e) <= 10 then
            table.insert(close, e)
        end
    end
    if #close == 0 then
        return false
    end
    c.slots1 = c.slots1 - 1
    c.turn.action = false
    area(b, c, close, tw, "Thunderwave")
    H.back_off(b, c, 15)
    return true
end

local TURNS = { bed_dragon = M.bed_dragon, noke = M.noke }

-- A Sheep Chase creature's turn. Returns true when the turn is done, false for the usual monster turn.
function M.turn(b, c, H)
    local f = c.data and TURNS[c.data.rules_turn]
    if not f then
        return false
    end
    return f(b, c, H)
end

return M
