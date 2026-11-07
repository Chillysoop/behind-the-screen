-- Death in Space's fights on the grid (Death in Space core rules, pp. 52-54, in our own words), standing on the table's
-- grid (game/kit/grid.lua) with its own rules on top. Pure Lua, no 5e.
--
-- A round: everyone acts once. Whoever started the fight goes first; whoever has acted picks who's next, a friend while
-- any are left to act (the crew plan their turns together), and the last to act picks who starts the next round,
-- themselves included. A turn: a move (about 15 meters, MOVE squares) and an attack: a d20 plus Body in melee or Tech at
-- range, hitting on the target's defense rating or more. A hit rolls the weapon's damage off their hit points; a
-- natural 20 adds a die. A risky attack adds a die on a hit, and on a miss the target hits straight back and picks who
-- acts next. A gun fires its `uses` before it needs a reload, which takes the turn's action (p. 122). Shooting at
-- someone partly behind cover (a crate, a wall's corner) is at disadvantage. A hero who misses gains a void point, and
-- can spend one for advantage (the set's edge and after_check). At 0 hit points anyone rolls Body against 12 at once (a
-- hero's void point can help): made, they're stable and out cold; missed, they're dead. Foes test morale on 2d6 against
-- their morale when half their side is down, when a lone foe is at half their hit points, and when their leader falls:
-- over it, they surrender, run or ask to talk, as the DM says (b.on_morale; Conner, November 7). Not here yet: gear
-- wearing down (Conner: later), full cover, and splitting a shotgun's dice between targets.
--
--   local b = battle.new({ W, H, solid = { [x*1000+y] = true }, walls = { ["x,y"] = true }, cover = { ["x,y"] = what },
--                          doors = { ["x,y"] = { state, x, y, fid } }, rng, set, campaign, first = "party" | "foes" })
--   b:add(c, x, y)    c = { side = "party" | "foes", name, hp, hp_max, dr, bdy, dex, svy, tec, ml, weapons = { { name,
--                     damage = "1d6", ranged = true } }, pc = true, player_key, boss = true, risky = 0..1 }
--   b:run({ max_rounds })  -> { winner = "party" | "foes", rounds }
-- Every event goes to b.on_event(b, ev): turn, round, move, attack, reload, damage, down, death, death_check, stable,
-- void, morale, flee, yield. b.on_morale(b, c) says what a broken foe does: "surrender", "flee" or "parley".

local grid = require "game.kit.grid"
local dice = require "game.kit.dice"

local M = {}
M.__index = M
grid.mix(M)

M.MOVE = 10              -- squares a turn: about 15 meters, at a meter and a half a square
M.RANGE = 99             -- (the book gives guns no range: anything in sight. Conner, November 7)
M.MAX_ROUNDS = 12

function M.new(o)
    local b = setmetatable({ W = o.W, H = o.H, creatures = {}, solid = o.solid or {}, walls = o.walls or {}, cover = o.cover or {},
                             doors = o.doors, rng = o.rng, set = o.set, campaign = o.campaign, first = o.first or "party",
                             square_feet = 5, round = 0, on_event = o.on_event }, M)
    return b
end

-- (What the grid can't see through is the walls; what nobody walks through is the walls and everything solid.)
function M:opaque_at(x, y)
    local k = grid.key(x, y)
    local d = self.doors and self.doors[k]
    if d then
        return d.state ~= "open"
    end
    if self.walking then
        return self.walls[k] == true or self.solid[x * 1000 + y] == true
    end
    return self.walls[k] == true
end

function M:emit(ev)
    if self.on_event then
        self.on_event(self, ev)
    end
end

function M:add(c, x, y)
    c.x, c.y = x, y
    c.hp_max = c.hp_max or c.hp
    c.stats = c.stats or { hits = 0, misses = 0, dealt = 0, kills = 0, downs = 0 }
    table.insert(self.creatures, c)
    return c
end

local function standing(c)
    return not c.dead and not c.removed and not c.down
end

function M:side(name)
    local out = {}
    for _, c in ipairs(self.creatures) do
        if c.side == name and standing(c) then
            table.insert(out, c)
        end
    end
    return out
end

local function other(side)
    return side == "party" and "foes" or "party"
end

local function adjacent(a, b)
    return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) == 1
end

local function weapon(c, ranged)
    for _, w in ipairs(c.weapons or {}) do
        if (w.ranged and true or false) == ranged then
            if w.uses and w.left == nil then
                w.left = w.uses
            end
            return w
        end
    end
    return nil
end

-- Partly behind cover from where the shot comes: a piece of cover in the square beside them, on the shooter's side.
function M:cover_from(att, tgt)
    local dx = att.x > tgt.x and 1 or (att.x < tgt.x and -1 or 0)
    local dy = att.y > tgt.y and 1 or (att.y < tgt.y and -1 or 0)
    for _, d in ipairs({ { dx, dy }, { dx, 0 }, { 0, dy } }) do
        if d[1] ~= 0 or d[2] ~= 0 then
            local what = self.cover[grid.key(tgt.x + d[1], tgt.y + d[2])]
            if what then
                return what
            end
        end
    end
    return nil
end

-- The weapon's damage, and an extra die each for a natural 20 and a risky hit (one group of the weapon's dice each).
local function roll_damage(b, spec, extra)
    local total = 0
    for _ = 0, extra do
        total = total + dice.roll(b.rng, spec).total
    end
    return math.max(1, total)
end

-- One attack: the set's check against the target's defense rating, with the void's edge for a hero.
function M:attack(att, tgt, w, risky, counter)
    local ranged = w.ranged and true or false
    if w.left then
        w.left = w.left - 1
    end
    local mod = ranged and (att.tec or 0) or (att.bdy or 0)
    local edge, spent
    local cover = ranged and self:cover_from(att, tgt) or nil
    if att.pc and self.set.edge and not counter then
        local p = { key = att.player_key, char = att.name }
        local e, note = self.set.edge(self.campaign, p, { dc = tgt.dr, mod = mod, big = tgt.boss or risky or (att.hp <= att.hp_max / 2) })
        if e then
            edge, spent = e, note
            self:emit({ kind = "void", who = att, say = note })
        end
    end
    -- (Advantage and disadvantage cancel out: a void point spent against cover is one die.)
    local r1 = self.set.die(self.rng)
    local roll, other_die = r1, nil
    if edge == "adv" and not cover then
        other_die = self.set.die(self.rng)
        roll = math.max(r1, other_die)
    elseif cover and edge ~= "adv" then
        other_die = self.set.die(self.rng)
        roll = math.min(r1, other_die)
    end
    local total = roll + mod
    local hit = total >= tgt.dr
    local crit = roll == 20
    self:emit({ kind = "attack", att = att, tgt = tgt, roll = roll, other = other_die, bonus = mod, total = total, dr = tgt.dr,
                hit = hit, crit = crit, risky = risky or nil, counter = counter or nil, ranged = ranged, weapon = w.name,
                dmg = w.damage, cover = cover, edge = (edge == "adv" and not cover) and "adv" or ((cover and edge ~= "adv") and "dis" or nil) })
    if att.pc and self.set.after_check then
        local p = { key = att.player_key, char = att.name }
        for _, s in ipairs(self.set.after_check(self.campaign, p, { success = hit, roll = roll, total = total }, self.rng, spent)) do
            self:emit({ kind = "void", who = att, say = s })
        end
    end
    att.stats.hits = att.stats.hits + (hit and 1 or 0)
    att.stats.misses = att.stats.misses + (hit and 0 or 1)
    if hit then
        local extra = (crit and 1 or 0) + (risky and 1 or 0)
        local amount = roll_damage(self, w.damage, extra)
        self:hurt(tgt, amount, att, crit)
    elseif risky and standing(tgt) then
        -- (A risky miss: the target hits straight back, if they can reach.)
        local back = (adjacent(tgt, att) and weapon(tgt, false)) or (self:los(tgt, att) and weapon(tgt, true))
        if back and back.left == 0 then
            back = nil
        end
        if back then
            self:attack(tgt, att, back, false, true)
        end
        self.picks_next = tgt
    end
    return hit
end

function M:hurt(tgt, amount, src, crit)
    tgt.hp = tgt.hp - amount
    if src then
        src.stats.dealt = src.stats.dealt + amount
    end
    self:emit({ kind = "damage", tgt = tgt, src = src, amount = amount, hp = math.max(0, tgt.hp), hp_max = tgt.hp_max, crit = crit })
    if tgt.hp > 0 then
        return
    end
    tgt.hp = 0
    tgt.down = true
    tgt.stats.downs = tgt.stats.downs + 1
    if src and not tgt.pc then
        src.stats.kills = src.stats.kills + 1
    end
    self:emit({ kind = "down", who = tgt })
    -- At 0, anyone rolls Body against 12 at once; a hero's void point can give it advantage (p. 54).
    local p = tgt.pc and { key = tgt.player_key, char = tgt.name } or nil
    local edge, spent
    if p and self.set.edge then
        local e, note = self.set.edge(self.campaign, p, { dc = self.set.TARGET, mod = tgt.bdy or 0, big = true })
        if e then
            edge, spent = e, note
            self:emit({ kind = "void", who = tgt, say = note })
        end
    end
    local r = self.set.check(self.rng, { mod = tgt.bdy or 0, dc = self.set.TARGET, edge = edge })
    self:emit({ kind = "death_check", who = tgt, roll = r.roll, other = r.other, bonus = r.mod, total = r.total, ok = r.success })
    if p and self.set.after_check then
        for _, s in ipairs(self.set.after_check(self.campaign, p, r, self.rng, spent)) do
            self:emit({ kind = "void", who = tgt, say = s })
        end
    end
    if r.success then
        tgt.stable = true
        self:emit({ kind = "stable", who = tgt })
        -- (A foe out cold is beaten as surely as a dead one: the fight's over for them.)
        if not tgt.pc then
            tgt.dead, tgt.out_cold, tgt.dead_why = true, true, "out_cold"
        end
    else
        tgt.dead = true
        tgt.dead_why = "beaten"
        self:emit({ kind = "death", who = tgt })
    end
    if not tgt.pc then
        self:morale_after(tgt)
    end
end

-- Morale (p. 53): 2d6 against the foe's morale; over it, they're done. A leader yields; the rest run.
function M:test_morale(c, why)
    if c.ml == nil or not standing(c) or c.tested_for == why then
        return
    end
    c.tested_for = why
    local r = dice.roll(self.rng, dice.parse("2d6")).total
    local broke = r > c.ml
    self:emit({ kind = "morale", who = c, roll = r, ml = c.ml, broke = broke, why = why })
    if broke then
        local what = (self.on_morale and self.on_morale(self, c, why)) or (c.boss and "parley" or "flee")
        c.removed = true
        c.removed_why = what == "flee" and "morale" or "yield"
        c.gave_up = what
        self:emit({ kind = what == "flee" and "flee" or "yield", who = c, how = what })
        -- (A leader who gives up or asks to talk ends it for their side.)
        if c.boss and what ~= "flee" then
            self.yielded = c
            for _, o in ipairs(self:side("foes")) do
                o.removed, o.removed_why, o.gave_up = true, "yield", what
                self:emit({ kind = "yield", who = o, how = what })
            end
        end
    end
end

function M:morale_after(fallen)
    if fallen.side ~= "foes" then
        return
    end
    local all, left = 0, 0
    for _, c in ipairs(self.creatures) do
        if c.side == "foes" then
            all = all + 1
            if standing(c) then
                left = left + 1
            end
        end
    end
    for _, c in ipairs(self:side("foes")) do
        if fallen.boss then
            self:test_morale(c, "leader")
        elseif left * 2 <= all then
            self:test_morale(c, "half")
        end
    end
end

function M:los(a, b)
    return self:los_xy(a.x, a.y, b.x, b.y)
end

-- The nearest enemy, the weakest of them on a tie.
function M:pick_target(c)
    local best, bd
    for _, e in ipairs(self:side(other(c.side))) do
        local d = math.max(math.abs(e.x - c.x), math.abs(e.y - c.y))
        if not bd or d < bd or (d == bd and e.hp < best.hp) then
            best, bd = e, d
        end
    end
    return best
end

function M:walk(c, tgt)
    self.walking = true
    local path = self:path(c.x, c.y, tgt.x, tgt.y, { max = 40 })
    self.walking = false
    if not path or #path == 0 then
        return
    end
    -- (Up to the square beside them, as far as a turn's move goes.)
    local steps = {}
    for i, sq in ipairs(path) do
        if i > M.MOVE or (sq[1] == tgt.x and sq[2] == tgt.y) then
            break
        end
        table.insert(steps, sq)
    end
    if #steps == 0 then
        return
    end
    local last = steps[#steps]
    c.x, c.y = last[1], last[2]
    self:emit({ kind = "move", who = c, path = steps })
end

function M:take_turn(c)
    self:emit({ kind = "turn", who = c })
    local tgt = self:pick_target(c)
    if not tgt then
        return
    end
    local gun, blade = weapon(c, true), weapon(c, false)
    local risky = c.risky and self.rng:chance(c.risky) or false
    -- (Out of shots, with no one in reach of a hand weapon: the action is a reload.)
    if gun and gun.left == 0 and not (blade and adjacent(c, tgt)) then
        gun.left = gun.uses
        self:emit({ kind = "reload", who = c, weapon = gun.name })
        return
    end
    if adjacent(c, tgt) and blade then
        self:attack(c, tgt, blade, risky)
    elseif gun and self:los(c, tgt) and math.max(math.abs(c.x - tgt.x), math.abs(c.y - tgt.y)) <= M.RANGE then
        self:attack(c, tgt, gun, risky)
    else
        self:walk(c, tgt)
        if adjacent(c, tgt) and (blade or gun) then
            self:attack(c, tgt, blade or gun, risky)
        elseif gun and self:los(c, tgt) then
            self:attack(c, tgt, gun, false)
        end
    end
    -- (A lone foe at half their hit points tests morale.)
    local foes = self:side("foes")
    if #foes == 1 and foes[1].hp * 2 <= foes[1].hp_max then
        self:test_morale(foes[1], "alone")
    end
end

function M:over()
    if #self:side("foes") == 0 then
        return "party"
    elseif #self:side("party") == 0 then
        return "foes"
    end
    return nil
end

-- The turn order, one round: a side's turn passes within the side while any of it is left to act.
function M:next_up(acted, last, start_side)
    local function first_of(side)
        for _, c in ipairs(self:side(side)) do
            if not acted[c] then
                return c
            end
        end
        return nil
    end
    -- (After a risky miss, the one who hit back picks: their own side.)
    local picker = self.picks_next or last
    self.picks_next = nil
    local side = picker and picker.side or start_side
    return first_of(side) or first_of(other(side))
end

function M:run(opts)
    local max = (opts and opts.max_rounds) or M.MAX_ROUNDS
    local start_side = self.first
    local winner
    while self.round < max do
        self.round = self.round + 1
        self:emit({ kind = "round", round = self.round })
        local acted, last = {}, nil
        while true do
            local c = self:next_up(acted, last, start_side)
            if not c then
                break
            end
            acted[c] = true
            self:take_turn(c)
            last = c
            winner = self:over()
            if winner then
                break
            end
        end
        if winner then
            break
        end
        -- (The last to act picks who starts the next round: their own side.)
        start_side = last and last.side or start_side
    end
    winner = winner or self:over() or "foes"
    return { winner = winner, rounds = self.round }
end

return M
