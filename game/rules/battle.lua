-- The headless combat engine: SRD 5.2.1 combat rules on a 5-foot grid.
-- Rules sources are cited by page (System Reference Document 5.2.1).
--
--   local battle = require "game.rules.battle"
--   local b = battle.new({ seed = 7 })
--   b:add(pc, 2, 5); b:add(goblin, 12, 5)
--   local result = b:run()
--
-- Simplifications (all creatures take one square, open ground, everyone can see
-- everyone unless a condition says otherwise) are listed in README "Rules engine".
--
-- Game night hooks (all optional, off in the headless sims):
--   b.on_event(b, ev)     structured events for the table: turn, round, move, attack,
--                         damage, down, death, up, heal, save, spell, condition, flee
--   b.hooks.before_damage(b, src, tgt, total, info) -> total   change damage before it lands
--   b.hooks.before_pc_death(b, c, why) -> "stable" | "revive"   overrule a hero's death
--   b.gentle_deaths = true   a hero at 0 Hit Points always gets their death saves (no massive-damage
--                            death); game night sets it
--   b.hooks.before_turn(b, c)   the DM runs a creature's turn (sets c.dm_target or c.dm_skip)
--   b.blocked[x * 1000 + y] = true                              terrain squares nobody can enter
--   b.force_end = "party" | "foes"                              end the fight after this turn
--   b.hooks.before_join(b, c)   a creature is about to join mid-fight (a swarm bursting out)
--   b.paint, b.mirror, b.averted, b.drowsy, b.earplugs          The Museum of Nightmares' options
--                                                               (game/rules/museum.lua)
--
-- A creature on the party's side that isn't a hero (an ally, c.ally) fights with them but isn't
-- counted among the heroes. An effect with out_of_fight (turned to stone, sitting through a
-- lecture) takes its holder out: nobody targets them and they don't keep their side standing.

local dice_mod = require "game.rules.dice"
local creature = require "game.rules.creature"
local museum = require "game.rules.museum"

local M = {}
local B = {}
B.__index = B

local abmod = creature.abmod

function M.new(opts)
    opts = opts or {}
    local b = setmetatable({
        dice = opts.dice or dice_mod.new(opts.seed or 1),
        W = opts.width or 24, H = opts.height or 16,
        creatures = {}, zones = {}, round = 0, active = nil,
        lines = {}, verbose = opts.verbose or false,
        max_rounds = opts.max_rounds or 30,
        ai = opts.ai,                       -- module with take_turn(b, c) and reaction hooks
        events = { pc_downs = 0, pc_deaths = 0 },
        hooks = opts.hooks or {},
        on_event = opts.on_event,
        blocked = opts.blocked,
    }, B)
    return b
end

-- Structured events for game night (no-op unless someone listens).
function B:emit(ev)
    if self.on_event then
        self.on_event(self, ev)
    end
end

-- Logging --------------------------------------------------------------------------------

function B:log(fmt, ...)
    if self.verbose or self.keep_log then
        local ok, s = pcall(string.format, fmt, ...)
        table.insert(self.lines, ok and s or fmt)
        if self.verbose == "print" then
            print(ok and s or fmt)
        end
    end
end

-- Creatures and the grid ------------------------------------------------------------------

function B:add(c, x, y)
    c.x, c.y = x, y
    c.battle = self
    c.turn = {}
    c.reaction_used = false
    table.insert(self.creatures, c)
    return c
end

function B:alive(c)
    return not c.dead and not (c.down)
end

function B:enemies_of(c, include_down)
    local out = {}
    for _, o in ipairs(self.creatures) do
        if o.side ~= c.side and not o.dead and (include_down or not o.down) and not o.removed
            and not self:any_effect(o, "out_of_fight") then
            table.insert(out, o)
        end
    end
    return out
end

function B:allies_of(c, include_self, include_down)
    local out = {}
    for _, o in ipairs(self.creatures) do
        if o.side == c.side and not o.dead and (include_down or not o.down) and (include_self or o ~= c) then
            table.insert(out, o)
        end
    end
    return out
end

-- Distance in feet: the grid counts diagonals as 5 feet (p. 16 "Grid" optional rule style).
function B:dist_xy(x1, y1, x2, y2)
    return 5 * math.max(math.abs(x1 - x2), math.abs(y1 - y2))
end

function B:dist(a, b)
    return self:dist_xy(a.x, a.y, b.x, b.y)
end

function B:occupant(x, y)
    for _, o in ipairs(self.creatures) do
        if not o.dead and o.x == x and o.y == y then
            return o
        end
    end
    return nil
end

function B:in_bounds(x, y)
    return x >= 1 and y >= 1 and x <= self.W and y <= self.H
end

-- Effects and conditions ------------------------------------------------------------------

local effect_seq = 0

-- When does "the start/end of <who>'s next turn" arrive? Counted in turn boundaries.
function B:next_turn(who, at)
    if who == self.active and at == "end" then
        return { who = who, at = at, n = 2 }
    end
    return { who = who, at = at, n = 1 }
end

local function cond_names(eff)
    local names = {}
    for k in pairs(eff.conds or {}) do
        table.insert(names, k)
    end
    table.sort(names)
    return names
end

function B:add_effect(c, eff)
    effect_seq = effect_seq + 1
    eff.seq = effect_seq
    eff.holder = c
    if eff.conds then
        for cond in pairs(eff.conds) do
            if c.condition_immune[cond] then
                eff.conds[cond] = nil
            end
        end
    end
    table.insert(c.effects, eff)
    -- A tag on the mat: a condition, or an effect that wants showing on its own (Burning, Targeted).
    if self.on_event and ((eff.conds and next(eff.conds)) or eff.tag) then
        self:emit({ kind = "condition", who = c, name = eff.name, conds = cond_names(eff) })
    end
    if eff.conc_of and eff.conc_of.conc then
        table.insert(eff.conc_of.conc.effects, eff)
    end
    -- Incapacitated breaks Concentration (p. 184).
    if c.conc and self:incapacitated(c) then
        self:end_concentration(c, "incapacitated")
    end
    return eff
end

function B:remove_effect(c, eff, why)
    for i = #c.effects, 1, -1 do
        if c.effects[i] == eff then
            table.remove(c.effects, i)
            if eff.on_end then
                eff.on_end(self, c, why)
            end
            if self.on_event and ((eff.conds and next(eff.conds)) or eff.tag) then
                self:emit({ kind = "condition_end", who = c, name = eff.name, conds = cond_names(eff) })
            end
            return true
        end
    end
    return false
end

function B:find_effect(c, name)
    for _, e in ipairs(c.effects) do
        if e.name == name then
            return e
        end
    end
    return nil
end

function B:has(c, cond)
    if c.dead then
        return cond == "dead"
    end
    if c.down then
        if cond == "unconscious" or cond == "incapacitated" or cond == "prone" then
            return true
        end
    end
    for _, e in ipairs(c.effects) do
        if e.conds then
            if e.conds[cond] then
                return true
            end
            if cond == "incapacitated" and (e.conds.paralyzed or e.conds.unconscious or e.conds.stunned) then
                return true
            end
            if cond == "prone" and e.conds.unconscious then
                return true
            end
        end
    end
    return false
end

function B:incapacitated(c)
    return c.dead or self:has(c, "incapacitated")
end

function B:sum_effect(c, field)
    local total = 0
    for _, e in ipairs(c.effects) do
        if e[field] then
            total = total + e[field]
        end
    end
    return total
end

function B:any_effect(c, field)
    for _, e in ipairs(c.effects) do
        if e[field] then
            return e
        end
    end
    return nil
end

-- Concentration (p. 179) ------------------------------------------------------------------

function B:start_concentration(c, spell_id, extra)
    if c.conc then
        self:end_concentration(c, "new spell")
    end
    c.conc = { spell = spell_id, effects = {}, extra = extra or {} }
    return c.conc
end

function B:end_concentration(c, why)
    local conc = c.conc
    if not conc then
        return
    end
    c.conc = nil
    for _, eff in ipairs(conc.effects) do
        if eff.holder then
            self:remove_effect(eff.holder, eff, "concentration")
        end
    end
    for i = #self.zones, 1, -1 do
        if self.zones[i].conc == conc then
            local z = table.remove(self.zones, i)
            self:emit({ kind = "zone_end", zone = z.uid, what = z.kind })
            for _, o in ipairs(self.creatures) do
                for j = #o.effects, 1, -1 do
                    if o.effects[j].zone == z then
                        self:remove_effect(o, o.effects[j], "zone gone")
                    end
                end
            end
        end
    end
    if conc.extra.summon then
        conc.extra.summon.gone = true
    end
    self:log("%s loses Concentration on %s (%s).", c.name, conc.spell, why or "ended")
end

-- Armor Class -----------------------------------------------------------------------------

function B:ac(c)
    local ac = creature.base_ac(c) + self:sum_effect(c, "ac") + (c.item_ac or 0)
    -- Hold Fast (Banner Captain): +1 AC within 5 feet of the captain.
    if c.side == "party" then
        for _, o in ipairs(self.creatures) do
            if o ~= c and o.side == c.side and o.sub and o.sub.hold_fast and not o.dead and not o.down
                and not self:incapacitated(o) and self:dist(o, c) <= 5 then
                ac = ac + 1
                break
            end
        end
    end
    return ac
end

-- Speed (p. 15) -----------------------------------------------------------------------------

function B:speed(c)
    if c.dead or c.down or self:has(c, "paralyzed") or self:has(c, "restrained") or self:has(c, "grappled")
        or self:has(c, "unconscious") then
        return 0
    end
    if self:any_effect(c, "speed_zero") then
        return 0
    end
    local s = c.speed + self:sum_effect(c, "speed_bonus")
    -- Slow (mastery, p. 90) doesn't stack past 10 feet; Ray of Frost is separate.
    local slow = 0
    for _, e in ipairs(c.effects) do
        if e.slow then
            slow = 10
        end
    end
    s = s - slow - self:sum_effect(c, "speed_minus")
    return math.max(0, s)
end

-- Can a creature see another? Blinded and Invisible matter; on a staged board, so do walls (Total
-- Cover) and the dark (SRD 5.2.1 "Light": Darkness is Heavily Obscured, and a creature trying to
-- see into it is effectively Blinded, unless Darkvision or Blindsight reaches).
function B:can_see(a, b)
    if self:has(a, "blinded") then
        return false
    end
    if self:has(b, "invisible") then
        return false
    end
    if a.x and b.x then
        if not self:los_xy(a.x, a.y, b.x, b.y) then
            return false
        end
        if self.light and not self:sees_square(a, b.x, b.y) then
            return false
        end
    end
    return true
end

-- The stage (Set the stage): what the board's pieces do in a fight, by SRD 5.2.1.
--   b.opaque[k]  squares nobody sees through (a wall, a shut door): Total Cover. k = "x,y"
--   b.cover[k]   cover pieces and what they're called; b.deg[k] = "half" | "three_quarters"
--   b.doors[k]   { state = "closed" | "open" | "locked", x, y, fid }
--   b.light      nil (everyone sees), or { ambient = "bright" | "dim" | "dark", sources = { { x, y, bright, dim } } }
local function sqk(x, y)
    return x .. "," .. y
end

function B:opaque_at(x, y)
    local k = sqk(x, y)
    local d = self.doors and self.doors[k]
    if d then
        return d.state ~= "open"
    end
    return self.opaque ~= nil and self.opaque[k] == true
end

-- The squares a straight line from the middle of one square to the middle of another crosses,
-- neither end counted. A line exactly through a corner passes between the two squares there:
-- { corner = { a, b } }.
function B:line(x1, y1, x2, y2)
    local out = {}
    local dx, dy = x2 - x1, y2 - y1
    local sx = dx > 0 and 1 or (dx < 0 and -1 or 0)
    local sy = dy > 0 and 1 or (dy < 0 and -1 or 0)
    local adx, ady = math.abs(dx), math.abs(dy)
    local tx = adx > 0 and 0.5 / adx or math.huge
    local ty = ady > 0 and 0.5 / ady or math.huge
    local ddx = adx > 0 and 1 / adx or math.huge
    local ddy = ady > 0 and 1 / ady or math.huge
    local x, y, guard = x1, y1, 0
    while (x ~= x2 or y ~= y2) and guard < 100 do
        guard = guard + 1
        if math.abs(tx - ty) < 1e-9 then
            table.insert(out, { corner = { { x + sx, y }, { x, y + sy } } })
            x, y = x + sx, y + sy
            tx, ty = tx + ddx, ty + ddy
        elseif tx < ty then
            x, tx = x + sx, tx + ddx
        else
            y, ty = y + sy, ty + ddy
        end
        if x ~= x2 or y ~= y2 then
            table.insert(out, { x, y })
        end
    end
    return out
end

-- Line of sight between two squares: nothing opaque in the way (a corner blocks only when both
-- squares beside it do). Cached until a door opens or shuts.
function B:los_xy(x1, y1, x2, y2)
    if (not self.opaque and not self.doors) or (x1 == x2 and y1 == y2) then
        return true
    end
    local ck = self.los_cache
    if not ck or ck.v ~= (self.stage_v or 0) then
        ck = { v = self.stage_v or 0 }
        self.los_cache = ck
    end
    local key = ((x1 * 64 + y1) * 64 + x2) * 64 + y2
    local v = ck[key]
    if v ~= nil then
        return v
    end
    v = true
    for _, s in ipairs(self:line(x1, y1, x2, y2)) do
        if s.corner then
            if self:opaque_at(s.corner[1][1], s.corner[1][2]) and self:opaque_at(s.corner[2][1], s.corner[2][2]) then
                v = false
                break
            end
        elseif self:opaque_at(s[1], s[2]) then
            v = false
            break
        end
    end
    ck[key] = v
    return v
end

-- How lit a square is: "bright", "dim" or "dark" (the map's light, its fires and lamps, and the
-- torches heroes without Darkvision carry; light doesn't go through walls).
function B:light_at(x, y)
    local L = self.light
    if not L then
        return "bright"
    end
    local best = L.ambient == "bright" and 3 or (L.ambient == "dim" and 2 or 1)
    if best == 3 then
        return "bright"
    end
    local function from(sx, sy, bright, dim)
        local d = self:dist_xy(sx, sy, x, y)
        if d <= bright + dim and self:los_xy(math.floor(sx + 0.5), math.floor(sy + 0.5), x, y) then
            best = math.max(best, d <= bright and 3 or 2)
        end
    end
    for _, src in ipairs(L.sources or {}) do
        from(src.x, src.y, src.bright, src.dim)
    end
    for _, o in ipairs(self.creatures) do
        if o.torch and not o.dead and not o.removed then
            from(o.x, o.y, 20, 20)       -- a Torch: Bright Light 20 ft, Dim Light 20 ft more
        end
    end
    return best == 3 and "bright" or (best == 2 and "dim" or "dark")
end

-- Can this creature make out what's on that square, by the light?
function B:sees_square(a, x, y)
    local d = self:dist_xy(a.x, a.y, x, y)
    local bs = a.data and a.data.blindsight
    if bs and d <= bs then
        return true
    end
    if self:light_at(x, y) ~= "dark" then
        return true
    end
    local dv = a.darkvision or (a.data and a.data.darkvision)
    return dv ~= nil and d <= dv
end

-- Can this creature open a door? Heroes, and monsters with hands to do it.
local HANDS = { humanoid = true, fey = true, undead = true, giant = true, fiend = true, construct = true, celestial = true }
function B:opens_doors(c)
    if c.pc or c.side == "party" then
        return true
    end
    local d = c.data
    return d ~= nil and HANDS[d.type or ""] == true and not d.no_hands
end

-- A door opens (someone walked through it) or a lock gives.
function B:set_door(x, y, state, who)
    local d = self.doors and self.doors[sqk(x, y)]
    if not d or d.state == state then
        return
    end
    d.state = state
    self.stage_v = (self.stage_v or 0) + 1
    self:emit({ kind = "door", x = x, y = y, state = state, fid = d.fid, who = who })
end

-- Attack rolls (pp. 7-8, 14-15, Rules Glossary) -------------------------------------------------

-- Returns mode (+1 advantage, -1 disadvantage, 0) and a list of reasons.
function B:attack_mode(att, tgt, prof, opts)
    opts = opts or {}
    local adv, dis = {}, {}
    local close = self:dist(att, tgt) <= 5
    -- Attacker's conditions.
    if self:has(att, "blinded") then table.insert(dis, "attacker Blinded") end
    if self:has(att, "poisoned") then table.insert(dis, "attacker Poisoned") end
    if self:has(att, "prone") then table.insert(dis, "attacker Prone") end
    if self:has(att, "restrained") then table.insert(dis, "attacker Restrained") end
    if self:has(att, "frightened") then table.insert(dis, "attacker Frightened") end
    if self:has(att, "invisible") then table.insert(adv, "attacker Invisible") end
    -- Grappled (Rules Glossary): Disadvantage on attacks against anyone but the grappler.
    local held = self:find_grapple(att)
    if held and held.grapple_by ~= tgt then table.insert(dis, "attacker Grappled") end
    if prof.adv_vs_grappled then
        local g = self:find_grapple(tgt)
        if g and g.grapple_by == att then table.insert(adv, "target Grappled") end
    end
    for _, e in ipairs(att.effects) do
        if e.sapped then table.insert(dis, "Sap") end
        if e.enfeeble_dis_next then table.insert(dis, "Ray of Enfeeblement") end
        if e.steady_aim then table.insert(adv, "Steady Aim") end
        if e.feint_vs == tgt then table.insert(adv, "Feint") end
        if e.vex_vs == tgt then table.insert(adv, "Vex") end
        if e.reckless then table.insert(adv, "Reckless") end
        if e.enfeebled and (prof.ability_name == "str" or (prof.kind == "melee" and not prof.ability_name)) then
            table.insert(dis, "Ray of Enfeeblement (Str)")
        end
    end
    -- Target's conditions.
    if self:has(tgt, "blinded") then table.insert(adv, "target Blinded") end
    if self:has(tgt, "paralyzed") then table.insert(adv, "target Paralyzed") end
    if self:has(tgt, "restrained") then table.insert(adv, "target Restrained") end
    if self:has(tgt, "unconscious") then table.insert(adv, "target Unconscious") end
    if self:has(tgt, "invisible") then table.insert(dis, "target Invisible") end
    if self:has(tgt, "prone") and not self:has(tgt, "unconscious") then
        if close then table.insert(adv, "target Prone (close)") else table.insert(dis, "target Prone (far)") end
    end
    for _, e in ipairs(tgt.effects) do
        if e.dodge and self:can_see(tgt, att) and not self:incapacitated(tgt) then table.insert(dis, "Dodge") end
        if e.blur then table.insert(dis, "Blur") end
        if e.marked_adv then table.insert(adv, e.name or "Marked") end
        if e.reckless then table.insert(adv, "target Reckless") end
    end
    -- Unseen Attackers and Targets (p. 14): in the dark (a staged board's light), a target you
    -- can't see means Disadvantage; an attacker the target can't see has Advantage.
    if self.light then
        if not self:can_see(att, tgt) then table.insert(dis, "can't see the target") end
        if not self:can_see(tgt, att) then table.insert(adv, "unseen attacker") end
    end
    -- Ranged attacks in close combat (p. 15): Disadvantage within 5 feet of a visible, active enemy.
    if prof.kind == "ranged" or prof.spell_ranged then
        for _, o in ipairs(self:enemies_of(att)) do
            if self:dist(att, o) <= 5 and not self:incapacitated(o) and self:can_see(o, att) then
                table.insert(dis, "ranged attack in melee")
                break
            end
        end
        if prof.range and self:dist(att, tgt) > prof.range[1] then
            table.insert(dis, "long range")
        end
    end
    if prof.heavy_disadvantage then table.insert(dis, "Heavy weapon") end
    -- Hazards (A10): a gale spoils ranged weapons (p. 195); deep water is underwater combat (p. 16).
    if self.wind and prof.kind == "ranged" and prof.is_weapon then table.insert(dis, "Strong wind") end
    if self.hazard and prof.is_weapon and require("game.rules.hazards").deep(self, att) then
        local piercing = prof.damage and prof.damage[1] and prof.damage[1][4] == "piercing"
        if prof.kind == "ranged" or (not piercing and not (att.data and att.data.swim)) then
            table.insert(dis, "underwater")
        end
    end
    -- Pack Tactics.
    if att.traits.pack_tactics then
        for _, o in ipairs(self:allies_of(att)) do
            if self:dist(o, tgt) <= 5 and not self:incapacitated(o) then
                table.insert(adv, "Pack Tactics")
                break
            end
        end
    end
    -- Ambusher's Opening Strike.
    if att.sub and att.sub.opening_strike and self.round == 1 and not tgt.has_acted then
        table.insert(adv, "Opening Strike")
    end
    if opts.adv then table.insert(adv, opts.adv) end
    if opts.dis then table.insert(dis, opts.dis) end
    local mode = 0
    if #adv > 0 and #dis == 0 then mode = 1 elseif #dis > 0 and #adv == 0 then mode = -1 end
    return mode, adv, dis
end

local function consume_once(b, c, field, match)
    for i = #c.effects, 1, -1 do
        local e = c.effects[i]
        if e[field] and (match == nil or e[field] == match) then
            b:remove_effect(c, e, "used")
            return true
        end
    end
    return false
end

-- d4 riders from Bless and Bane on attack rolls and saves.
function B:d4_riders(c)
    local bonus = 0
    for _, e in ipairs(c.effects) do
        if e.bless then bonus = bonus + self.dice:d(4) end
        if e.bane then bonus = bonus - self.dice:d(4) end
    end
    return bonus
end

-- Roll damage parts. parts: { {count, die, bonus, type}, ... }. Doubling dice on a crit.
function B:roll_parts(parts, crit, opts)
    opts = opts or {}
    local out = {}
    for i, p in ipairs(parts) do
        local count = p[1] * (crit and 2 or 1)
        local amount = p[3] or 0
        if count > 0 then
            local rolled = self.dice:roll(count, p[2], { gwf = opts.gwf and i == 1 })
            if opts.savage and i == 1 then
                -- Savage Attacker (p. 87): roll the weapon dice twice, keep the better.
                local again = self.dice:roll(count, p[2], { gwf = opts.gwf })
                rolled = math.max(rolled, again)
            end
            amount = amount + rolled
        end
        table.insert(out, { math.max(0, amount), p[4] })
    end
    return out
end

-- "1d8+3 slashing" for the table (the real-session pass shows the damage dice).
local function dice_text(parts)
    local out = {}
    for _, p in ipairs(parts or {}) do
        local t = ""
        if (p[1] or 0) > 0 then
            t = tostring(p[1]) .. "d" .. tostring(p[2])
        end
        local b = p[3] or 0
        if b > 0 then
            t = t .. (t ~= "" and "+" or "") .. tostring(b)
        elseif b < 0 then
            t = t .. tostring(b)
        end
        if t ~= "" then
            table.insert(out, t .. (p[4] and (" " .. p[4]) or ""))
        end
    end
    return table.concat(out, " + ")
end

local SIZE_RANK = creature.SIZE_RANK

-- Make an attack. prof: an attack profile (creature.weapon_attack / monster_attack / spell).
-- opts: adv/dis (extra reasons), extra_parts (added on hit), on_hit(b, att, tgt, res), no_sneak,
--       opportunity (true for OAs), reaction (made with a Reaction).
-- Returns { hit, crit, roll, total, damage, target }.
-- Someone else this attacker can actually see and reach with this attack (for a target that
-- turned out to be behind Total Cover).
function B:visible_alternative(att, tgt, prof)
    local reach = prof.kind == "ranged" and prof.range and prof.range[2] or (prof.reach or 5)
    local best
    for _, o in ipairs(self:enemies_of(att)) do
        if o ~= tgt and self:dist(att, o) <= reach and self:los_xy(att.x, att.y, o.x, o.y)
            and (not best or self:dist(att, o) < self:dist(att, best)) then
            best = o
        end
    end
    return best
end

function B:attack(att, tgt, prof, opts)
    opts = opts or {}
    local res = { hit = false, crit = false, damage = 0, target = tgt }
    if tgt.dead then
        return res
    end
    -- Total Cover (Rules Glossary): nobody targets a creature directly through a wall or a shut
    -- door. The attacker goes for someone they can see, or the attack doesn't happen.
    if att.x and tgt.x and not self:los_xy(att.x, att.y, tgt.x, tgt.y) then
        local alt = self:visible_alternative(att, tgt, prof)
        if alt then
            self:log("%s can't see %s from there, and goes for %s instead.", att.name, tgt.name, alt.name)
            tgt = alt
            res.target = alt
        else
            self:log("%s has no line to %s (Total Cover).", att.name, tgt.name)
            res.blocked = "no_line"
            self:emit({ kind = "attack", att = att, tgt = tgt, weapon = prof.name, dmg = dice_text(prof.damage), to_hit = prof.to_hit,
                        hit = false, blocked = "no_line", ranged = prof.kind == "ranged" })
            return res
        end
    end
    -- Sanctuary (p. 159): Wisdom save or lose the attack.
    local sanct = self:any_effect(tgt, "sanctuary_dc")
    if sanct and att.side ~= tgt.side then
        if not self:save(att, "wis", sanct.sanctuary_dc, { kind = "sanctuary" }) then
            self:log("%s can't bring itself to attack %s (Sanctuary).", att.name, tgt.name)
            res.blocked = true
            self:emit({ kind = "attack", att = att, tgt = tgt, weapon = prof.name, dmg = dice_text(prof.damage), to_hit = prof.to_hit, hit = false, blocked = "sanctuary",
                        ranged = prof.kind == "ranged" })
            return res
        end
    end
    -- Goblin Boss Redirect Attack (p. 290): swap with an ally, who becomes the target.
    if tgt.reactions and tgt.reactions.redirect_attack and not tgt.reaction_used and not self:incapacitated(tgt)
        and self:can_see(tgt, att) then
        local best
        for _, o in ipairs(self:allies_of(tgt)) do
            if self:dist(o, tgt) <= 5 and SIZE_RANK[o.size] <= 3 and not self:incapacitated(o) and o ~= att then
                if not best or o.hp > best.hp then
                    best = o
                end
            end
        end
        if best and best.hp > 0 then
            tgt.reaction_used = true
            tgt.x, tgt.y, best.x, best.y = best.x, best.y, tgt.x, tgt.y
            self:log("%s yanks %s into the way (Redirect Attack).", tgt.name, best.name)
            tgt = best
            res.target = tgt
        end
    end
    -- Mischief Domain Tricky Decoy: attacks near the decoy may go to the decoy instead.
    if tgt.side == "party" then
        for _, o in ipairs(self:allies_of(tgt, true)) do
            local decoy = o.decoy
            if decoy and (o.dead or self:incapacitated(o) or (self.round or 1) > decoy.last_round) then
                o.decoy, decoy = nil, nil
            end
            -- Blindsight isn't fooled by an illusory double (the crab and the armor feel where you are).
            local sees_true = att.data and att.data.blindsight and self:dist_xy(att.x, att.y, decoy and decoy.x or 0,
                decoy and decoy.y or 0) <= att.data.blindsight
            if decoy and not sees_true and (tgt == o or self:dist_xy(tgt.x, tgt.y, decoy.x, decoy.y) <= 10) then
                if not self:save(att, "wis", creature.spell_dc(o), { kind = "decoy" }) then
                    -- Swinging at the illusion: an ordinary roll against the decoy's AC (A13 retune:
                    -- with the bestiary's dim, many-armed monsters it outlasted its SRD sibling).
                    local roll = self.dice:d20(0)
                    local total = roll + prof.to_hit
                    local popped = roll == 20 or (roll ~= 1 and total >= creature.spell_dc(o))
                    if popped then
                        self:log("%s attacks the decoy instead and it pops like a soap bubble.", att.name)
                        o.decoy = nil
                    else
                        self:log("%s swings at the decoy and misses.", att.name)
                    end
                    res.decoyed = true
                    self:emit({ kind = "attack", att = att, tgt = tgt, weapon = prof.name, dmg = dice_text(prof.damage), to_hit = prof.to_hit, hit = false, roll = roll,
                                total = total, blocked = popped and "decoy_popped" or "decoy", ranged = prof.kind == "ranged" })
                    return res
                end
                break
            end
        end
    end
    local mode, adv, dis = self:attack_mode(att, tgt, prof, opts)
    -- Mirror Mage Shimmer: impose Disadvantage as a Reaction.
    if tgt.sub and tgt.sub.shimmer and (tgt.res.shimmer or 0) > 0 and not tgt.reaction_used
        and not self:incapacitated(tgt) and mode >= 0 and self:can_see(tgt, att) then
        if self.ai and self.ai.want_shimmer and self.ai.want_shimmer(self, tgt, att, prof) then
            tgt.reaction_used = true
            tgt.res.shimmer = tgt.res.shimmer - 1
            table.insert(dis, "Shimmer")
            mode = (#adv > 0) and 0 or -1
            self:log("%s shimmers out of focus.", tgt.name)
        end
    end
    local luck = att.traits and att.traits.halfling_luck
    local roll = self.dice:d20(mode, luck)
    local total = roll + prof.to_hit + self:d4_riders(att)
    res.roll, res.total, res.mode = roll, total, mode
    -- Consume one-shot modifiers used by this roll.
    consume_once(self, att, "sapped")
    consume_once(self, att, "enfeeble_dis_next")
    consume_once(self, att, "steady_aim")
    consume_once(self, att, "feint_vs", tgt)
    consume_once(self, att, "vex_vs", tgt)
    consume_once(self, tgt, "marked_adv")
    -- Ending hidden/invisible from attacking (Invisibility spell, p. 141).
    local inv = self:any_effect(att, "ends_on_attack")
    if inv then
        self:remove_effect(att, inv, "attacked")
    end
    local sanct_own = self:any_effect(att, "sanctuary_dc")
    if sanct_own then
        self:remove_effect(att, sanct_own, "attacked")
    end
    local crit_range = prof.is_weapon and (prof.crit_range or att.crit_range or 20) or 20
    local cover, cover_what = self:cover_bonus(att, tgt)
    local ac = self:ac(tgt) + cover
    res.cover = cover > 0 or nil
    -- Heroic Inspiration on a miss that matters: against the boss.
    local rerolled
    if att.heroic and roll < crit_range and (roll == 1 or total < ac) and tgt.boss then
        local riders = total - roll
        rerolled = roll
        roll = self:heroic_reroll(att, roll, true, "attack", mode, luck)
        total = roll + riders
        res.roll, res.total = roll, total
    end
    local crit = roll >= crit_range
    local hit
    if roll == 1 then
        hit = false
    elseif crit then
        hit = true
    else
        hit = total >= ac
    end
    -- Reactions that can turn a hit into a miss.
    if hit and not crit then
        -- Shield (p. 161): +5 AC until the start of your next turn, including against this attack.
        if self.ai and self.ai.try_shield and total < ac + 5 then
            if self.ai.try_shield(self, tgt, att) then
                ac = self:ac(tgt) + cover
                hit = total >= ac
                if not hit then
                    res.blocked = "shield"
                end
            end
        end
        -- Spellguard Warding Flash (original): +5 AC against this one attack.
        if hit and tgt.sub and tgt.sub.warding_flash and (tgt.res.warding_flash or 0) > 0 and not tgt.reaction_used
            and not self:incapacitated(tgt) and total < ac + 5 then
            tgt.reaction_used = true
            tgt.res.warding_flash = tgt.res.warding_flash - 1
            hit = false
            res.blocked = "warding_flash"
            self:log("%s turns the blow with a Warding Flash.", tgt.name)
        end
        -- Bandit Captain Parry (p. 261): +2 AC against a melee hit.
        if hit and prof.kind == "melee" and tgt.reactions and tgt.reactions.parry and not tgt.reaction_used
            and not self:incapacitated(tgt) and total < ac + 2 then
            tgt.reaction_used = true
            hit = false
            res.blocked = "parry"
            self:log("%s parries.", tgt.name)
        end
    end
    -- Mirror Image (p. 150): a duplicate may take the hit.
    if hit then
        local mi = self:any_effect(tgt, "mirror_images")
        if mi and not self:has(att, "blinded") then
            local diverted = false
            for _ = 1, mi.mirror_images do
                if self.dice:d(6) >= 3 then
                    diverted = true
                end
            end
            if diverted then
                mi.mirror_images = mi.mirror_images - 1
                self:log("%s hits a mirror image of %s. %d left.", att.name, tgt.name, mi.mirror_images)
                if mi.mirror_images <= 0 then
                    self:remove_effect(tgt, mi, "images gone")
                end
                res.mirror = true
                self:emit({ kind = "attack", att = att, tgt = tgt, weapon = prof.name, dmg = dice_text(prof.damage), to_hit = prof.to_hit, hit = false, roll = roll, total = total,
                            ac = ac, blocked = "mirror_image", ranged = prof.kind == "ranged", mode = mode, cover = cover })
                return res
            end
        end
    end
    -- Automatic critical hits against Paralyzed or Unconscious targets within 5 feet.
    if hit and not crit and self:dist(att, tgt) <= 5
        and (self:has(tgt, "paralyzed") or self:has(tgt, "unconscious")) then
        crit = true
    end
    res.hit, res.crit = hit, crit
    att.stats.hits = att.stats.hits + (hit and 1 or 0)
    att.stats.misses = att.stats.misses + (hit and 0 or 1)
    if crit then
        att.stats.crits = att.stats.crits + 1
    end
    -- A miss the cover made: the shot hits the crate instead (the table says so).
    if not hit and cover > 0 and not res.blocked and roll ~= 1 and total >= ac - cover then
        res.blocked = "cover"
        res.cover_what = type(cover_what) == "string" and cover_what or nil
    end
    if not hit then
        self:log("%s misses %s with %s (%d vs AC %d%s).", att.name, tgt.name, prof.name, total, ac,
            mode > 0 and ", Advantage" or (mode < 0 and ", Disadvantage" or ""))
        self:emit({ kind = "attack", att = att, tgt = tgt, weapon = prof.name, dmg = dice_text(prof.damage), to_hit = prof.to_hit, hit = false, roll = roll, total = total,
                    ac = ac, mode = mode, blocked = res.blocked, ranged = prof.kind == "ranged",
                    opportunity = opts.opportunity, spell = prof.spell, cover = cover,
                    cover_what = type(cover_what) == "string" and cover_what or nil,
                    heroic = rerolled })
        -- Graze (p. 90): miss still deals the ability modifier.
        if prof.mastery == "graze" and (prof.ability or 0) > 0 then
            self:deal(att, tgt, { { prof.ability, prof.damage[1][4] } }, { graze = true, weapon = prof.name })
        end
        if opts.on_miss then
            opts.on_miss(self, att, tgt, res)
        end
        return res
    end
    -- Damage.
    local savage = prof.is_weapon and att.feats.savage_attacker and not att.turn.savage_used and att.pc
    if savage then
        att.turn.savage_used = true
    end
    local dmg_parts = prof.damage
    if prof.bloodied_damage and att.hp <= att.hp_max / 2 then
        dmg_parts = prof.bloodied_damage           -- a swarm half gone bites half as hard
    end
    local parts = self:roll_parts(dmg_parts, crit, { gwf = prof.gwf, savage = savage })
    if prof.adv_bonus and mode > 0 then
        local extra = self:roll_parts({ prof.adv_bonus }, crit)
        table.insert(parts, extra[1])
    end
    -- Sneak Attack (pp. 61-62): once per turn, Finesse or Ranged weapon, Advantage or an ally
    -- next to the target (and no Disadvantage).
    if att.sneak_dice and not att.turn.sneak_used and prof.is_weapon and not opts.no_sneak
        and (prof.finesse or prof.kind == "ranged") then
        local ok = mode > 0
        if not ok and mode == 0 then
            for _, o in ipairs(self:allies_of(att)) do
                if self:dist(o, tgt) <= 5 and not self:incapacitated(o) then
                    ok = true
                    break
                end
            end
        end
        if ok then
            att.turn.sneak_used = true
            local n = att.sneak_dice
            if att.sub and att.sub.opening_strike and self.round == 1 and not att.turn.opening_used then
                att.turn.opening_used = true
                n = n + 1
            end
            local sneak = self:roll_parts({ { n, 6, 0, prof.damage[1][4] } }, crit)
            table.insert(parts, sneak[1])
            res.sneak = true
        end
    end
    for _, extra in ipairs(opts.extra_parts or {}) do
        local r = self:roll_parts({ extra }, crit)
        table.insert(parts, r[1])
    end
    -- Ray of Enfeeblement: subtract 1d8 from damage rolls.
    if self:any_effect(att, "enfeebled") then
        local cut = self.dice:d(8)
        local i = 1
        while cut > 0 and i <= #parts do
            local take = math.min(cut, parts[i][1])
            parts[i][1] = parts[i][1] - take
            cut = cut - take
            i = i + 1
        end
    end
    self:log("%s %s %s with %s (%d vs AC %d%s).", att.name, crit and "CRITS" or "hits", tgt.name, prof.name, total, ac,
        mode > 0 and ", Advantage" or (mode < 0 and ", Disadvantage" or ""))
    self:emit({ kind = "attack", att = att, tgt = tgt, weapon = prof.name, dmg = dice_text(prof.damage), to_hit = prof.to_hit, hit = true, crit = crit, roll = roll,
                total = total, ac = ac, mode = mode, ranged = prof.kind == "ranged", sneak = res.sneak,
                opportunity = opts.opportunity, spell = prof.spell, cover = cover,
                cover_what = type(cover_what) == "string" and cover_what or nil, heroic = rerolled })
    -- A charge (the briars' tusks): closing at least `feet` on the target this turn before the hit.
    local ch = prof.charge
    if ch and att.turn and att.turn.start_x and not att.turn.charged and self.active == att
        and self:dist_xy(att.turn.start_x, att.turn.start_y, tgt.x, tgt.y) - self:dist(att, tgt) >= ch.feet then
        att.turn.charged = true
        table.insert(parts, self:roll_parts({ ch.extra }, crit)[1])
        res.charge = true
        self:log("  It's a charge!")
    end
    local bloodied_before = tgt.hp <= tgt.hp_max / 2 and tgt.hp > 0
    local hp_before = tgt.hp
    -- Magic in the blow: a magic weapon, or (The Museum of Nightmares) a paint-touched one.
    local paint = self.paint and att.side == "party" and prof.is_weapon or nil
    local magical = prof.magical or (att.magic_weapon or 0) > 0 or paint or nil
    res.damage = self:deal(att, tgt, parts, { crit = crit, melee = prof.kind == "melee", weapon = prof.is_weapon,
                                              magical = magical, paint = paint, nonlethal = prof.nonlethal })
    if res.charge and not tgt.dead and not tgt.down and ch.save
        and not self:save(tgt, ch.save, ch.dc, { kind = "prone" }) then
        self:knock_prone(tgt, att.name .. "'s charge")
    end
    self:bestiary_on_hit(att, tgt, prof, res, bloodied_before, hp_before)
    -- Monster riders.
    if prof.prone_max_size and not tgt.dead and SIZE_RANK[tgt.size] <= SIZE_RANK[prof.prone_max_size] then
        self:knock_prone(tgt, att.name .. "'s bite")
    end
    if prof.rider and not tgt.dead then
        local r = prof.rider
        local immune = (r.not_types and tgt.type and false)
        for _, t in ipairs(r.not_types or {}) do
            if tgt.type == t then immune = true end
        end
        for _, t in ipairs(r.not_traits or {}) do
            if tgt.traits and tgt.traits[t] then immune = true end
            if t == "elf" and tgt.species == "elf" then immune = true end
        end
        if tgt.condition_immune and tgt.condition_immune[r.condition] then
            immune = true
        end
        if not immune and (not r.save or not self:save(tgt, r.save, r.dc, { kind = r.condition })) then
            local whose, at = tgt, "end"
            if r.lasts == "end_of_attacker_next_turn" then
                whose = att
            elseif r.lasts == "start_of_attacker_next_turn" then
                whose, at = att, "start"
            end
            self:add_effect(tgt, { name = r.condition, conds = { [r.condition] = true },
                                   expires = self:next_turn(whose, at) })
            self:log("%s is %s until the %s of %s next turn.", tgt.name, r.condition, at, whose == tgt and "its" or (att.name .. "'s"))
        end
    end
    -- Weapon mastery on a hit (p. 90).
    if prof.mastery and not tgt.dead then
        self:apply_mastery(att, tgt, prof, res)
    end
    if opts.on_hit then
        opts.on_hit(self, att, tgt, res)
    end
    -- Champion Remarkable Athlete: half Speed of free movement after a crit.
    if crit and att.sub and att.sub.crit_move then
        att.turn.free_move = math.floor(att.speed / 2)
    end
    return res
end

function B:apply_mastery(att, tgt, prof, res)
    local m = prof.mastery
    if m == "sap" then
        self:add_effect(tgt, { name = "Sapped", sapped = true, expires = self:next_turn(att, "start") })
    elseif m == "vex" and res.damage > 0 then
        self:add_effect(att, { name = "Vex", vex_vs = tgt, expires = self:next_turn(att, "end") })
    elseif m == "slow" and res.damage > 0 then
        self:add_effect(tgt, { name = "Slowed", slow = true, expires = self:next_turn(att, "start") })
    elseif m == "topple" then
        local dc = 8 + (prof.ability or 0) + att.pb
        if not self:save(tgt, "con", dc, { kind = "prone" }) then
            self:knock_prone(tgt, "Topple")
        end
    elseif m == "push" and SIZE_RANK[tgt.size] <= 4 then
        self:push(att, tgt, 10)
    elseif m == "cleave" and prof.kind == "melee" and not att.turn.cleave_used then
        for _, o in ipairs(self:enemies_of(att)) do
            if o ~= tgt and self:dist(o, tgt) <= 5 and self:dist(att, o) <= (prof.reach or 5) then
                att.turn.cleave_used = true
                local p2 = {}
                for k, v in pairs(prof) do p2[k] = v end
                p2.damage = { { prof.damage[1][1], prof.damage[1][2], math.min(0, prof.ability or 0), prof.damage[1][4] } }
                p2.mastery = nil
                self:log("%s cleaves into %s.", att.name, o.name)
                self:attack(att, o, p2, { no_sneak = true })
                break
            end
        end
    end
end

-- The Vale Bestiary (A13) -------------------------------------------------------------------

local SIZE_ORDER = { tiny = 1, small = 2, medium = 3, large = 4, huge = 5, gargantuan = 6 }

-- The Grappled effect on c, if any (its grapple_by is the grappler).
function B:find_grapple(c)
    for _, e in ipairs(c.effects) do
        if e.grapple_by then
            return e
        end
    end
    return nil
end

-- A grapple ends when the grappler is down, dead or Incapacitated, or the two are out of reach.
function B:sweep_grapples()
    for _, c in ipairs(self.creatures) do
        for i = #c.effects, 1, -1 do
            local e = c.effects[i]
            if e and e.grapple_by then
                local g = e.grapple_by
                if c.dead or g.dead or g.down or self:incapacitated(g) or self:dist(g, c) > (e.reach or 5) then
                    self:remove_effect(c, e, "released")
                    self:log("  %s is free of %s's grip.", c.name, g.name)
                end
            end
        end
    end
end

-- Escape a grapple: an Athletics or Acrobatics check against the escape DC, as an action.
function B:escape_grapple(c)
    local e = self:find_grapple(c)
    if not e then
        return false
    end
    local prof = c.class and require("game.rules.skills").PROFICIENT[c.class] or {}
    local str = self:check(c, "str", prof.athletics and (c.pb or 0) or 0)
    local dex = self:check(c, "dex", prof.acrobatics and (c.pb or 0) or 0)
    local total = math.max(str, dex)
    if c.turn then
        c.turn.action = false
    end
    if total >= e.escape_dc then
        self:remove_effect(c, e, "escaped")
        self:log("%s breaks free of %s's grip (%d vs DC %d).", c.name, e.grapple_by.name, total, e.escape_dc)
        self:emit({ kind = "feature", who = c, name = "Breaks free" })
        return true
    end
    self:log("%s strains against %s's grip and fails (%d vs DC %d).", c.name, e.grapple_by.name, total, e.escape_dc)
    return false
end

-- Hack a way out of a giant spider's web (AC 10, 5 HP, Vulnerability to Fire): an attack as an action.
function B:cut_web(c, prof)
    local e = self:find_effect(c, "Spider web")
    if not e then
        return false
    end
    if c.turn then
        c.turn.action = false
    end
    local roll = self.dice:d20(0)
    if roll == 1 or roll + (prof and prof.to_hit or 0) < e.web.ac then
        self:log("%s hacks at the web and misses.", c.name)
        return false
    end
    local parts = self:roll_parts((prof and prof.damage) or { { 1, 4, 0, "slashing" } }, roll == 20)
    local dmg = 0
    for _, p in ipairs(parts) do
        local n = p[1]
        if p[2] == "fire" then n = n * 2 end
        if p[2] == "poison" or p[2] == "psychic" then n = 0 end
        dmg = dmg + n
    end
    e.web.hp = e.web.hp - dmg
    if e.web.hp <= 0 then
        self:remove_effect(c, e, "cut free")
        self:log("%s cuts through the web.", c.name)
        self:emit({ kind = "feature", who = c, name = "Cuts free" })
        return true
    end
    self:log("%s hacks at the web (%d left).", c.name, e.web.hp)
    return false
end

-- What a bestiary attack does after it lands: grab, pull, mark, drain, and the gnoll's Rampage.
function B:bestiary_on_hit(att, tgt, prof, res, bloodied_before, hp_before)
    if tgt.dead then
        return
    end
    local g = prof.grapple
    if g and (res.damage or 0) >= 0 and SIZE_ORDER[tgt.size or "medium"] <= SIZE_ORDER[g.max_size or "medium"]
        and not (tgt.condition_immune and tgt.condition_immune.grappled) and not self:find_grapple(tgt) then
        local holding = 0
        for _, o in ipairs(self.creatures) do
            local e = self:find_grapple(o)
            if e and e.grapple_by == att then holding = holding + 1 end
        end
        if holding < (g.hands or 1) then
            self:add_effect(tgt, { name = "Grappled", conds = { grappled = true }, grapple_by = att, escape_dc = g.dc,
                                   reach = prof.reach or 5 })
            self:log("  %s has %s in its grip (escape DC %d).", att.name, tgt.name, g.dc)
            self:emit({ kind = "feature", who = att, name = "Grabs", target = tgt })
        end
    end
    if prof.pull and SIZE_ORDER[tgt.size or "medium"] <= SIZE_ORDER[prof.pull.max_size or "large"] then
        local before = self:dist(att, tgt)
        for _ = 1, math.floor(prof.pull.feet / 5) do
            if self:dist(att, tgt) <= 5 then break end
            local sx = att.x > tgt.x and 1 or (att.x < tgt.x and -1 or 0)
            local sy = att.y > tgt.y and 1 or (att.y < tgt.y and -1 or 0)
            local nx, ny = tgt.x + sx, tgt.y + sy
            if not self:in_bounds(nx, ny) or self:occupant(nx, ny) then break end
            tgt.x, tgt.y = nx, ny
        end
        if self:dist(att, tgt) < before then
            self:log("  %s hauls %s in on the line.", att.name, tgt.name)
            self:emit({ kind = "move", who = tgt, path = { { tgt.x, tgt.y } }, forced = true })
        end
    end
    if prof.mark then
        self:add_effect(tgt, { name = att.name .. "'s bite", marked_adv = true, expires = self:next_turn(att, "start") })
    end
    if prof.drain and (res.damage or 0) > 0 then
        local taken = math.max(0, hp_before - math.max(0, tgt.hp))
        if tgt.down then taken = hp_before end
        if taken > 0 then
            tgt.hp_max = math.max(0, tgt.hp_max - taken)
            tgt.drained = (tgt.drained or 0) + taken
            self:log("  %s's Hit Point maximum drops by %d (%d).", tgt.name, taken, tgt.hp_max)
            if tgt.hp_max <= 0 then
                self:kill(tgt, att, "drained")
            end
        end
    end
    if bloodied_before and att.bonus_actions and att.bonus_actions.rampage and not att.rampage_used
        and att.turn and att.turn.bonus and not tgt.dead and prof.kind == "melee" then
        att.rampage_used = true
        att.turn.bonus = false
        self:log("%s goes on a Rampage.", att.name)
        self:emit({ kind = "feature", who = att, name = "Rampage" })
        for _, a in ipairs(att.attacks or {}) do
            if a.id == "rend" then
                local t = tgt
                if t.dead or t.down then
                    for _, o in ipairs(self:enemies_of(att)) do
                        if self:dist(att, o) <= 5 then t = o break end
                    end
                end
                if t and not t.dead and not t.down and self:dist(att, t) <= 5 then
                    self:attack(att, t, creature.monster_attack(att, a))
                end
            end
        end
    end
end

function B:knock_prone(c, why)
    if c.dead or self:has(c, "prone") then
        return
    end
    self:add_effect(c, { name = "Prone", conds = { prone = true }, prone = true })
    self:log("%s is knocked Prone (%s).", c.name, why or "")
end

function B:stand_up(c)
    for i = #c.effects, 1, -1 do
        if c.effects[i].prone then
            table.remove(c.effects, i)
        end
    end
end

-- Push a creature straight away from a point, stopping at obstacles.
function B:push(from, c, feet)
    local dx = c.x - from.x
    local dy = c.y - from.y
    local sx = dx > 0 and 1 or (dx < 0 and -1 or 0)
    local sy = dy > 0 and 1 or (dy < 0 and -1 or 0)
    if sx == 0 and sy == 0 then
        return
    end
    for _ = 1, math.floor(feet / 5) do
        local nx, ny = c.x + sx, c.y + sy
        if not self:in_bounds(nx, ny) or self:occupant(nx, ny) then
            break
        end
        c.x, c.y = nx, ny
    end
end

-- Damage (pp. 16-18) -------------------------------------------------------------------------

-- parts: { {amount, type}, ... } already rolled. info: crit, melee, weapon, spell, magical.
-- Applies Immunity, Resistance and Vulnerability per part, Temporary Hit Points, 0 HP rules,
-- Concentration saves and effects that end on damage. Returns the damage taken.
function B:deal(src, tgt, parts, info)
    info = info or {}
    if tgt.dead then
        return 0
    end
    local bond = self:any_effect(tgt, "warding_bond")
    local total, radiant = 0, false
    for _, p in ipairs(parts) do
        local amount, dtype = p[1], p[2]
        if dtype == "radiant" then
            radiant = true
        end
        if tgt.immune[dtype] then
            amount = 0
        else
            -- Adjustments first (Resistance cantrip), then Resistance, then Vulnerability.
            local resist_spell = self:any_effect(tgt, "resistance_type")
            if resist_spell and resist_spell.resistance_type == dtype and not tgt.turn_resisted then
                amount = math.max(0, amount - self.dice:d(4))
            end
            local under = dtype == "fire" and self.hazard and require("game.rules.hazards").deep(self, tgt)
            -- (The Museum of Nightmares: Resistance to blows that aren't magical, and a Petrified
            -- creature resists everything.)
            local mundane = tgt.resist_nonmagical and info.weapon and not info.magical and tgt.resist_nonmagical[dtype]
            if tgt.resist[dtype] or bond or under or mundane or (tgt.effects[1] and self:any_effect(tgt, "stone")) then
                amount = math.floor(amount / 2)            -- (anything underwater resists fire, p. 16)
            end
            if tgt.vulnerable[dtype] or (info.paint and tgt.paint_vulnerable) then
                amount = amount * 2
            end
        end
        total = total + amount
    end
    if total > 0 and self.hooks.before_damage then
        total = self.hooks.before_damage(self, src or tgt, tgt, total, info) or total
    end
    if total <= 0 then
        return 0
    end
    src = src or tgt
    -- Temporary Hit Points absorb first.
    local absorbed = 0
    if tgt.temp > 0 then
        absorbed = math.min(tgt.temp, total)
        tgt.temp = tgt.temp - absorbed
    end
    local through = total - absorbed
    if src.stats then
        src.stats.dealt = src.stats.dealt + total
    end
    tgt.stats.taken = tgt.stats.taken + total
    if through <= 0 then
        self:log("  %s's Temporary Hit Points soak %d.", tgt.name, absorbed)
        self:emit({ kind = "damage", src = src, tgt = tgt, amount = total, absorbed = absorbed, hp = tgt.hp,
                    hp_max = tgt.hp_max, crit = info.crit, graze = info.graze })
        self:after_damage(tgt, total, info)
        return total
    end
    -- Damage at 0 Hit Points (p. 18).
    if tgt.down then
        self:emit({ kind = "damage", src = src, tgt = tgt, amount = total, absorbed = absorbed, hp = 0,
                    hp_max = tgt.hp_max, crit = info.crit, spell = info.spell, graze = info.graze })
        if through >= tgt.hp_max and not (tgt.pc and self.gentle_deaths) then
            self:kill(tgt, src, "massive damage")
        else
            self:death_failure(tgt, info.crit and 2 or 1, src)
        end
        return total
    end
    tgt.hp = tgt.hp - through
    self:log("  %s takes %d damage (%d/%d).", tgt.name, total, math.max(tgt.hp, 0), tgt.hp_max)
    self:emit({ kind = "damage", src = src, tgt = tgt, amount = total, absorbed = absorbed, hp = math.max(tgt.hp, 0),
                hp_max = tgt.hp_max, crit = info.crit, spell = info.spell, graze = info.graze })
    if tgt.hp <= 0 then
        local overflow = -tgt.hp
        tgt.hp = 0
        if tgt.pc then
            -- (Game night keeps heroes to their death saves: no one-hit deaths, October 17.)
            if info.nonlethal and info.melee then
                -- Knocking Out a Creature: Unconscious and Stable, no death saves (the Sentinel).
                self:drop(tgt, src)
                tgt.stable = true
                tgt.knocked_out = true
                self:log("  %s is knocked out cold.", tgt.name)
                museum.feature(self, tgt, "Knocked out", "knocked_out", { by = src })
            elseif overflow >= tgt.hp_max and not self.gentle_deaths then
                self:kill(tgt, src, "massive damage")
            else
                self:drop(tgt, src)
            end
        else
            -- Undead Fortitude (Zombie, p. 343).
            if tgt.traits.undead_fortitude and not radiant and not info.crit
                and self:save(tgt, "con", 5 + total, { kind = "fortitude" }) then
                tgt.hp = 1
                self:log("  %s refuses to stay down (Undead Fortitude).", tgt.name)
                self:emit({ kind = "fortitude", who = tgt })
            else
                self:kill(tgt, src)
            end
        end
    end
    if tgt.data and tgt.data.source or tgt.effects[1] then
        museum.on_damaged(self, src, tgt, total, info)   -- a charm breaks, the scarabs pour out
    end
    if bond and not tgt.dead and bond.source and not bond.source.dead then
        -- Warding Bond: the caster takes the same damage.
        self:deal(tgt, bond.source, { { total, "force" } }, { bond = true })
    end
    if not tgt.dead then
        self:after_damage(tgt, total, info)
    end
    return total
end

function B:after_damage(tgt, amount, info)
    -- Concentration save: DC 10 or half the damage, up to 30 (p. 179).
    if tgt.conc and not tgt.down and not tgt.dead then
        local dc = math.min(30, math.max(10, math.floor(amount / 2)))
        if not self:save(tgt, "con", dc, { kind = "concentration" }) then
            self:end_concentration(tgt, "damage")
        end
    end
    for i = #tgt.effects, 1, -1 do
        local e = tgt.effects[i]
        if e and e.ends_on_damage then
            self:remove_effect(tgt, e, "damage")
            self:log("  %s shakes off %s.", tgt.name, e.name)
        elseif e and e.save_on_damage then
            -- Hideous Laughter: save again with Advantage when damaged.
            local s = e.save_on_damage
            if self:save(tgt, s.ab, s.dc, { adv = true, kind = e.name }) then
                self:remove_effect(tgt, e, "saved")
                self:log("  %s shakes off %s.", tgt.name, e.name)
            end
        end
    end
end

function B:drop(c, src)
    c.down = true
    c.stable = false
    c.ds = { s = 0, f = 0 }
    c.stats.downs = c.stats.downs + 1
    self.events.pc_downs = self.events.pc_downs + 1
    if c.conc then
        self:end_concentration(c, "dropped")
    end
    self:log("  %s drops to 0 Hit Points and falls Unconscious!", c.name)
    self:emit({ kind = "down", who = c, src = src })
    museum.on_drop(self, c)                    -- a Steam Mech whose commander this was powers down
    if src and src.stats and src ~= c then
        src.stats.kills = src.stats.kills + 0
    end
end

function B:kill(c, src, why)
    -- Game night: the DM may overrule a hero's death (hooks.before_pc_death -> "stable" | "revive").
    if c.pc and self.hooks.before_pc_death then
        local verdict = self.hooks.before_pc_death(self, c, why)
        if verdict == "stable" then
            c.down = true
            c.ds = { s = 0, f = 0 }
            c.stable = true
            self:log("  %s is Stable.", c.name)
            self:emit({ kind = "stable", who = c })
            return
        elseif verdict == "revive" then
            c.down = true
            self:heal(nil, c, 1)
            return
        end
    end
    c.dead = true
    c.down = false
    if c.conc then
        self:end_concentration(c, "died")
    end
    if src and src.stats and src ~= c then
        src.stats.kills = src.stats.kills + 1
    end
    if c.pc then
        self.events.pc_deaths = self.events.pc_deaths + 1
        self:log("  %s dies%s.", c.name, why and (" (" .. why .. ")") or "")
    else
        self:log("  %s is defeated.", c.name)
    end
    self:emit({ kind = "death", who = c, src = src, why = why })
    museum.on_kill(self, c)                    -- whatever they held up ends: Petrify, a charm, a lecture
end

-- Death Saving Throws (p. 18).
function B:death_failure(c, n, src)
    c.stable = false
    c.ds.f = c.ds.f + n
    self:log("  %s suffers %d Death Saving Throw failure%s (%d/3).", c.name, n, n > 1 and "s" or "", math.min(3, c.ds.f))
    if c.ds.f >= 3 then
        self:kill(c, src, "failed death saves")
    end
end

-- Heroic Inspiration (SRD 5.2.1, Rules Glossary): the holder can expend it to reroll any die
-- right after rolling it, and must use the new roll (M8, B4). c.heroic is the token; want says
-- whether this roll is worth it (the simulated players spend it on rolls that matter).
function B:heroic_reroll(c, roll, want, what, mode, luck)
    if not (c and c.heroic and want) then
        return roll
    end
    c.heroic = nil
    local new = self.dice:d20(mode or 0, luck)
    self:log("  %s spends Heroic Inspiration to reroll the %s: %d becomes %d.", c.name, what or "die", roll, new)
    self:emit({ kind = "feature", who = c, name = "Heroic Inspiration", from = roll, to = new })
    self.heroic_used = (self.heroic_used or 0) + 1
    return new
end

function B:death_save(c)
    local roll = self.dice:d20(0, c.traits.halfling_luck)
    roll = self:heroic_reroll(c, roll, roll < 10, "Death Saving Throw", 0, c.traits.halfling_luck)
    if c.wound_closure and roll <= 9 then
        self:log("%s's Periapt of Wound Closure turns a %d into a 10.", c.name, roll)
        roll = 10                                  -- Periapt of Wound Closure (A13)
    end
    self:emit({ kind = "death_save", who = c, roll = roll })
    if roll == 20 then
        self:log("%s rolls a natural 20 on a Death Saving Throw and regains 1 Hit Point!", c.name)
        self:revive(c, 1)
        return
    elseif roll == 1 then
        self:death_failure(c, 2)
        return
    elseif roll >= 10 then
        c.ds.s = c.ds.s + 1
        self:log("%s succeeds on a Death Saving Throw (%d/3).", c.name, c.ds.s)
        if c.ds.s >= 3 then
            c.stable = true
            self:log("%s is Stable.", c.name)
        end
    else
        self:death_failure(c, 1)
    end
end

function B:revive(c, hp)
    c.down = false
    c.stable = false
    c.ds = { s = 0, f = 0 }
    c.hp = math.min(c.hp_max, hp)
    -- Still Prone after waking.
    self:add_effect(c, { name = "Prone", conds = { prone = true }, prone = true })
    self:emit({ kind = "up", who = c, hp = c.hp })
end

-- Healing (p. 18) -------------------------------------------------------------------------------

function B:heal(src, tgt, amount, info)
    if tgt.dead or amount <= 0 then
        return 0
    end
    if self:any_effect(tgt, "no_healing") then
        self:log("  %s can't regain Hit Points right now.", tgt.name)
        return 0
    end
    local before = tgt.hp
    if tgt.down then
        self:revive(tgt, amount)
        self:log("  %s is back up with %d Hit Points.", tgt.name, tgt.hp)
    else
        tgt.hp = math.min(tgt.hp_max, tgt.hp + amount)
        self:log("  %s regains %d Hit Points (%d/%d).", tgt.name, tgt.hp - before, tgt.hp, tgt.hp_max)
    end
    local gained = tgt.hp - before
    if src and src.stats then
        src.stats.healed = src.stats.healed + gained
    end
    self:emit({ kind = "heal", src = src, tgt = tgt, amount = gained, hp = tgt.hp, hp_max = tgt.hp_max })
    return gained
end

function B:give_temp(c, amount)
    if amount > c.temp then
        c.temp = amount       -- Temporary Hit Points don't stack (p. 18)
        self:emit({ kind = "temp", who = c, amount = amount })
    end
end

function B:stabilize(c)
    if c.down and not c.dead then
        c.stable = true
        c.ds = { s = 0, f = 0 }
        self:log("%s is Stable.", c.name)
    end
end

-- Saving throws (p. 7) --------------------------------------------------------------------------

-- info: kind (condition or effect name), adv, dis, magical. Returns success, total, roll.
function B:save(c, ab, dc, info)
    info = info or {}
    if c.dead then
        return false, 0, 0
    end
    if (ab == "str" or ab == "dex") and (self:has(c, "paralyzed") or self:has(c, "unconscious")) then
        self:log("  %s automatically fails the %s save.", c.name, string.upper(ab))
        return false, 0, 0
    end
    local adv, dis = info.adv or false, info.dis or false
    if ab == "dex" and self:any_effect(c, "dodge") and not self:incapacitated(c) then adv = true end
    if ab == "dex" and self:has(c, "restrained") then dis = true end
    if ab == "str" and self:any_effect(c, "enfeebled") then dis = true end
    local kind = info.kind
    if kind == "frightened" then
        if c.traits.brave then adv = true end
        for _, o in ipairs(self:allies_of(c, true)) do
            if o.sub and o.sub.kindled_courage and self:dist(o, c) <= 10 then adv = true end
        end
    end
    if kind == "poisoned" and c.traits.dwarven_resilience then adv = true end
    if kind == "charmed" and c.traits.fey_ancestry then adv = true end
    if self.drowsy or self.averted or self.earplugs then
        local a2, d2 = museum.save_mods(self, c, ab, info)
        adv, dis = adv or a2 or false, dis or d2 or false
    end
    local mode = 0
    if adv and not dis then mode = 1 elseif dis and not adv then mode = -1 end
    local roll = self.dice:d20(mode, c.traits.halfling_luck)
    local bonus = creature.save_bonus(c, ab) + self:d4_riders(c)
    if self:any_effect(c, "warding_bond") then
        bonus = bonus + 1
    end
    roll = self:heroic_reroll(c, roll, roll + bonus < dc, string.upper(ab) .. " save", mode, c.traits.halfling_luck)
    local total = roll + bonus
    local ok = total >= dc
    self:log("  %s %s a DC %d %s save (%d).", c.name, ok and "makes" or "fails", dc, string.upper(ab), total)
    self:emit({ kind = "save", who = c, ab = ab, dc = dc, ok = ok, roll = roll, total = total, what = info.kind })
    return ok, total, roll
end

-- Ability check (used for Feint, Web escapes). prof_bonus: added proficiency/expertise.
function B:check(c, ab, prof_bonus, info)
    info = info or {}
    local mode = 0
    if self:has(c, "poisoned") or self:has(c, "frightened") then mode = -1 end
    if info.adv and mode == 0 then mode = 1 elseif info.adv and mode < 0 then mode = 0 end
    local roll = self.dice:d20(mode, c.traits and c.traits.halfling_luck)
    return roll + abmod(c, ab) + (prof_bonus or 0) + (c.item_checks or 0), roll
end

-- Movement and Opportunity Attacks (p. 15, p. 185) ------------------------------------------------------------------------------

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

-- Cover from the board's pieces (Set the stage). SRD 5.2.1, Rules Glossary "Cover": Half Cover
-- (a table, a low wall, a crate) is +2 to AC and Dexterity saves, Three-Quarters Cover (a pillar,
-- a thick tree trunk, an arrow slit) +5, and Total Cover (a wall, a shut door) can't be targeted
-- directly at all (line of sight, above). Against attacks from more than 5 feet away; creatures
-- in the way don't count here, and the save bonus isn't modelled. Also returns what the piece is
-- called, when the board says ("crate").
local DEG = { half = 2, three_quarters = 5 }

function B:cover_bonus(att, tgt)
    if not self.cover or not tgt or not tgt.x then
        return 0
    end
    if att and att.x and self:dist(att, tgt) <= 5 then
        return 0
    end
    if self.cover[tgt.x .. "," .. tgt.y] then
        return 2, self.cover[tgt.x .. "," .. tgt.y]
    end
    if not (att and att.x) then
        return 0
    end
    -- Every piece of cover the line crosses counts, the best one only (the degrees don't add);
    -- what's right beside the attacker doesn't (they lean over or around it). Through a corner,
    -- the shooter takes the clearer side.
    local function deg(x, y)
        if math.max(math.abs(x - att.x), math.abs(y - att.y)) <= 1 then
            return 0
        end
        local k = x .. "," .. y
        if self.cover[k] and self.blocked and self.blocked[x * 1000 + y] then
            return DEG[self.deg and self.deg[k] or "half"] or 2, self.cover[k]
        end
        return 0
    end
    local best, name = 0, nil
    for _, s in ipairs(self:line(att.x, att.y, tgt.x, tgt.y)) do
        local v, nm
        if s.corner then
            local a, an = deg(s.corner[1][1], s.corner[1][2])
            local b2, bn = deg(s.corner[2][1], s.corner[2][2])
            if a <= b2 then
                v, nm = a, an
            else
                v, nm = b2, bn
            end
        else
            v, nm = deg(s[1], s[2])
        end
        if v > best then
            best, name = v, nm
        end
    end
    return best, name
end

function B:zone_at(x, y)
    for _, z in ipairs(self.zones) do
        if z.cells[x .. "," .. y] then
            return z
        end
    end
    return nil
end

function B:step_cost(x, y)
    local z = self:zone_at(x, y)
    if z and z.difficult then
        return 10
    end
    return 5
end

-- Shortest paths (in feet) from c over open squares; allies can be passed through,
-- enemies can't. Costs are multiples of 5, so a bucket queue does the job.
-- Returns dist and parent tables keyed by x * 1000 + y.
local TERRAIN = { side = "terrain", name = "terrain" }

function B:occupancy()
    local occ = {}
    if self.blocked then
        for k in pairs(self.blocked) do
            occ[k] = TERRAIN
        end
    end
    for _, o in ipairs(self.creatures) do
        if not o.dead and not o.removed then
            occ[o.x * 1000 + o.y] = o
        end
    end
    return occ
end

function B:paths(c, max_ft, occ)
    occ = occ or self:occupancy()
    local start = c.x * 1000 + c.y
    local dist, parent = { [start] = 0 }, {}
    local buckets = { [0] = { start } }
    local W, H = self.W, self.H
    local zones = #self.zones > 0
    local doors = self.doors
    local opener = doors and self:opens_doors(c)
    for d = 0, max_ft, 5 do
        local bucket = buckets[d]
        if bucket then
            for _, k in ipairs(bucket) do
                if dist[k] == d then
                    local x = math.floor(k / 1000)
                    local y = k - x * 1000
                    for _, dir in ipairs(DIRS) do
                        local nx, ny = x + dir[1], y + dir[2]
                        if nx >= 1 and ny >= 1 and nx <= W and ny <= H then
                            local nk = nx * 1000 + ny
                            local o = occ[nk]
                            local dr = doors and doors[nx .. "," .. ny]
                            if dr and dr.state ~= "open" and (dr.state == "locked" or not opener) then
                                o = TERRAIN         -- a locked door, or a shut one for a wolf
                            end
                            if not (o and o.side ~= c.side and not o.down) then
                                local nd = d + ((zones and self:step_cost(nx, ny)) or 5)
                                if nd <= max_ft and (dist[nk] == nil or nd < dist[nk]) then
                                    dist[nk] = nd
                                    parent[nk] = k
                                    buckets[nd] = buckets[nd] or {}
                                    table.insert(buckets[nd], nk)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return dist, parent
end

-- Pick the reachable, unoccupied square that best satisfies score(x, y) (higher is better),
-- using at most max_ft of movement. Returns x, y, cost (or nil).
function B:best_square(c, max_ft, score)
    local occ = self:occupancy()
    local dist = self:paths(c, max_ft, occ)
    local bx, by, bcost, bscore = nil, nil, nil, -math.huge
    for k, d in pairs(dist) do
        local o = occ[k]
        if not o or o == c then
            local x = math.floor(k / 1000)
            local y = k - x * 1000
            local s = score(x, y) - d * 0.001 - (x * 0.00001 + y * 0.0000001)
            if s > bscore then
                bx, by, bcost, bscore = x, y, d, s
            end
        end
    end
    return bx, by, bcost
end

-- Move along the shortest path to (tx, ty). Provokes Opportunity Attacks unless
-- disengaged (p. 15, p. 186) and triggers zones. Returns false if the move was cut short.
function B:move_to(c, tx, ty, opts)
    opts = opts or {}
    if c.x == tx and c.y == ty then
        return true
    end
    local budget = opts.budget or c.turn.move or 0
    local dist, parent = self:paths(c, budget)
    local goal = tx * 1000 + ty
    if not dist[goal] then
        return false
    end
    local path = {}
    local k = goal
    local here = c.x * 1000 + c.y
    while k and k ~= here do
        table.insert(path, 1, k)
        k = parent[k]
    end
    local walked = {}
    local function flush()
        if #walked > 0 then
            self:emit({ kind = "move", who = c, path = walked })
            walked = {}
        end
    end
    for _, step in ipairs(path) do
        local x = math.floor(step / 1000)
        local y = step - x * 1000
        local cost = self:step_cost(x, y)
        -- Opportunity Attacks from enemies whose reach we leave.
        if not opts.no_oa and not c.turn.disengaged then
            for _, e in ipairs(self:enemies_of(c)) do
                if self:can_make_oa(e, c) then
                    local reach = self:melee_reach(e)
                    if self:dist(e, c) <= reach and self:dist_xy(e.x, e.y, x, y) > reach then
                        flush()
                        self:opportunity_attack(e, c)
                        if c.dead or c.down or self:speed(c) == 0 then
                            return false
                        end
                    end
                end
            end
        end
        -- A shut door on the way opens as they go (a free interaction, p. 13).
        local dr = self.doors and self.doors[x .. "," .. y]
        if dr and dr.state == "closed" then
            flush()
            self:set_door(x, y, "open", c)
            self:log("  %s opens the door.", c.name)
        end
        c.x, c.y = x, y
        table.insert(walked, { x, y })
        if not opts.budget then
            c.turn.move = math.max(0, (c.turn.move or 0) - cost)
        end
        c.turn.moved = true
        -- Entering a zone.
        local z = self:zone_at(x, y)
        if z and z.on_enter then
            flush()
            z.on_enter(self, z, c)
            if self:speed(c) == 0 or c.dead or c.down then
                return false
            end
        end
    end
    flush()
    return true
end

function B:melee_reach(c)
    if c.pc then
        local w = c.weapons and c.weapons.main
        if w then
            local prof = creature.weapon_attack(c, w)
            return prof.kind == "melee" and prof.reach or 5
        end
        return 5
    end
    local r = 0
    for _, a in ipairs(c.attacks or {}) do
        if a.kind == "melee" or a.kind == "both" then
            r = math.max(r, a.reach or 5)
        end
    end
    return r
end

function B:can_make_oa(e, mover)
    if e.reaction_used or self:incapacitated(e) or e.down or e.dead then
        return false
    end
    if self:any_effect(e, "no_oa") then
        return false
    end
    -- Charmed (Rules Glossary): no attacking the one who charmed you, not even in passing.
    for _, x in ipairs(e.effects) do
        if x.charmed_by == mover then
            return false
        end
    end
    if not self:can_see(e, mover) then
        return false
    end
    return self:melee_reach(e) > 0
end

function B:opportunity_attack(e, c)
    e.reaction_used = true
    self:log("%s takes an Opportunity Attack at %s.", e.name, c.name)
    local prof = self.ai and self.ai.melee_profile and self.ai.melee_profile(self, e)
    if prof then
        -- Briar Hooks (The Museum of Nightmares): the thorns catch whoever pulls away.
        local hooks = e.data and e.data.briar_hooks
        self:attack(e, c, prof, { opportunity = true, extra_parts = hooks and { hooks } or nil })
    end
end

-- Zones (Web, Grease) ----------------------------------------------------------------------------

local zone_seq = 0

function B:add_zone(z)
    table.insert(self.zones, z)
    -- The table shows the zone on the mat while it lasts.
    zone_seq = zone_seq + 1
    z.uid = zone_seq
    local cells = {}
    for k in pairs(z.cells or {}) do
        local x, y = string.match(k, "^(%-?%d+),(%-?%d+)$")
        if x then
            table.insert(cells, { tonumber(x), tonumber(y) })
        end
    end
    table.sort(cells, function(a, b) return a[1] * 1000 + a[2] < b[1] * 1000 + b[2] end)
    self:emit({ kind = "zone", zone = z.uid, what = z.kind, cells = cells })
    return z
end

-- Initiative and turns (p. 13) --------------------------------------------------------------------

function B:roll_initiative()
    for _, c in ipairs(self.creatures) do
        local mode = 0
        if (c.sub and c.sub.init_advantage) or c.item_init_adv then
            mode = 1                       -- (and the Sentinel Shield, A13)
        end
        -- Surprise (p. 13): Disadvantage on Initiative.
        if c.surprised then
            mode = mode - 1
        end
        local roll = self.dice:d20(mode, c.traits and c.traits.halfling_luck)
        local bonus = abmod(c, "dex")
        if c.feats and c.feats.alert then
            bonus = bonus + c.pb         -- Alert (p. 87)
        end
        c.init = roll + bonus
        c.init_roll, c.init_bonus = roll, bonus
        c.init_tiebreak = abmod(c, "dex") + self.dice.rng:next()
    end
    self.order = {}
    for _, c in ipairs(self.creatures) do
        table.insert(self.order, c)
    end
    table.sort(self.order, function(a, b)
        if a.init ~= b.init then
            return a.init > b.init
        end
        return a.init_tiebreak > b.init_tiebreak
    end)
    -- The table sees everyone's initiative (the real-session pass draws the turn order).
    local list = {}
    for _, c in ipairs(self.order) do
        table.insert(list, { who = c, roll = c.init_roll, bonus = c.init_bonus, total = c.init })
    end
    self:emit({ kind = "initiative", order = list })
end

function B:process_expiry(who, at)
    for _, c in ipairs(self.creatures) do
        for i = #c.effects, 1, -1 do
            local e = c.effects[i]
            if e and e.expires and e.expires.who == who and e.expires.at == at then
                e.expires.n = e.expires.n - 1
                if e.expires.n <= 0 then
                    self:remove_effect(c, e, "expired")
                end
            end
        end
    end
end

function B:start_turn(c)
    self.active = c
    self.turn_counter = (self.turn_counter or 0) + 1
    c.turn = { action = true, bonus = true, move = self:speed(c), moved = false, attacks = 0, start_x = c.x, start_y = c.y }
    c.reaction_used = false
    self:process_expiry(c, "start")
    self:sweep_grapples()
    if self.hazard then
        require("game.rules.hazards").start_turn(self, c)   -- Burning (p. 178)
    end
    if c.sands_spent then
        museum.start_turn(self, c)
    end
    if c.web_spent and self.dice:d(6) >= ((c.data and c.data.web and c.data.web.recharge) or 5) then
        c.web_spent = nil
        self:log("%s's web is ready again.", c.name)
    end
    c.turn.move = self:speed(c)
    -- Web: starting a turn in the webs means a save (p. 174).
    local z = self:zone_at(c.x, c.y)
    if z and z.on_start then
        z.on_start(self, z, c)
    end
end

function B:end_turn(c)
    -- Repeat saves at the end of the creature's turn (Hold Person, Blindness/Deafness...).
    for i = #c.effects, 1, -1 do
        local e = c.effects[i]
        if e and e.save_end and not c.dead and e.save_end.skip_now then
            e.save_end.skip_now = nil          -- (it started this turn: the save comes at the end of the next)
        elseif e and e.save_end and not c.dead then
            local s = e.save_end
            if self:save(c, s.ab, s.dc, { kind = s.kind or e.name, adv = s.adv }) then
                self:remove_effect(c, e, "saved")
                self:log("  %s shakes off %s.", c.name, e.name)
                if e.on_save then
                    e.on_save(self, c)
                end
            elseif e.on_fail_repeat then
                e.on_fail_repeat(self, c, e)
            end
        end
    end
    -- Delayed damage (Acid Arrow) and end-of-turn zone effects.
    for i = #c.effects, 1, -1 do
        local e = c.effects[i]
        if e and e.end_turn_damage and not c.dead then
            local dmg = self:roll_parts({ e.end_turn_damage })
            self:remove_effect(c, e, "done")
            self:deal(e.source, c, dmg, { spell = e.name })
        end
    end
    local z = self:zone_at(c.x, c.y)
    if z and z.on_end_turn and not c.dead then
        z.on_end_turn(self, z, c)
    end
    -- Effects that act at the end of their holder's turn (the Steam Mech's overheat check).
    for i = #c.effects, 1, -1 do
        local e = c.effects[i]
        if e and e.on_end_turn and not c.dead then
            e.on_end_turn(self, c, e)
        end
    end
    for _, o in ipairs(self.creatures) do
        local sphere = o.conc and o.conc.extra.sphere
        if sphere and not sphere.gone and o ~= c and o.side ~= c.side and not c.dead
            and self:dist_xy(c.x, c.y, sphere.x, sphere.y) <= 5 and sphere.damage_on_end then
            sphere.damage_on_end(self, o, c)
        end
    end
    self:process_expiry(c, "end")
    c.has_acted = true
    self.active = nil
end

function B:outcome()
    local party, foes = false, false
    for _, c in ipairs(self.creatures) do
        if not c.dead and not c.down and not c.removed and not (c.effects[1] and self:any_effect(c, "out_of_fight")) then
            if c.side == "party" then party = true else foes = true end
        end
    end
    if not foes then
        return "party"
    end
    if not party then
        return "foes"
    end
    return nil
end

function B:take_turn(c)
    if c.dead or c.removed then
        return
    end
    self:start_turn(c)
    self:emit({ kind = "turn", who = c, round = self.round })
    if c.down then
        if not c.stable then
            self:death_save(c)
        end
        if c.down or c.dead then
            self:end_turn(c)
            return
        end
    end
    if not self:incapacitated(c) and self.ai then
        -- Game night (B8): the DM can run this turn: who it goes for (c.dm_target), or a speech
        -- instead of an attack (c.dm_skip).
        if self.hooks.before_turn then
            self.hooks.before_turn(self, c)
        end
        if c.dm_skip then
            c.dm_skip = nil
            self:log("%s stops to gloat.", c.name)
            self:emit({ kind = "feature", who = c, name = c.dm_skip_name or "Gloats" })
        elseif not c.dead and not c.removed then
            self.ai.take_turn(self, c)
        end
        c.dm_target, c.dm_finish = nil, nil
    end
    if not c.dead then
        self:end_turn(c)
    else
        self.active = nil
    end
end

-- A creature joining mid-fight (reinforcements): rolls initiative and acts at the end of the round order.
function B:join(c, x, y)
    self:add(c, x, y)
    local roll = self.dice:d20(0)
    c.init = roll + abmod(c, "dex")
    c.init_tiebreak = abmod(c, "dex") + self.dice.rng:next()
    if self.order then
        table.insert(self.order, c)
    end
    if self.hooks.before_join then
        self.hooks.before_join(self, c)       -- game night names its mini
    end
    self:emit({ kind = "join", who = c })
    return c
end

-- A creature leaving the fight (fleeing, or written out by the DM).
function B:remove(c, why)
    c.removed = true
    c.removed_why = why
    if c.conc then
        self:end_concentration(c, "left")
    end
    self:emit({ kind = "flee", who = c, why = why })
end

-- Run the fight. opts.before_round(b, r) runs at the start of each round and
-- opts.after_turn(b, c) after every turn (game night uses them for decisions).
function B:run(opts)
    opts = opts or {}
    self:roll_initiative()
    if self.ai and self.ai.on_initiative then
        self.ai.on_initiative(self)
    end
    self:log("Initiative: %s", (function()
        local t = {}
        for _, c in ipairs(self.order) do
            table.insert(t, c.name .. " " .. c.init)
        end
        return table.concat(t, ", ")
    end)())
    local result
    for r = 1, self.max_rounds do
        self.round = r
        self:log("-- Round %d --", r)
        self:emit({ kind = "round", round = r })
        if self.hazard then
            require("game.rules.hazards").round(self)     -- the hazard acts first (A10)
        end
        if opts.before_round then
            opts.before_round(self, r)
        end
        result = self.force_end or self:outcome()
        local i = 1
        while not result and i <= #self.order do
            local c = self.order[i]
            self:take_turn(c)
            if opts.after_turn and not c.removed then
                opts.after_turn(self, c)
            end
            result = self.force_end or self:outcome()
            i = i + 1
        end
        if result then
            break
        end
    end
    -- If the party wins, anyone dying but not dead is stabilized after the fight.
    result = result or "timeout"
    return self:summary(result)
end

function B:summary(result)
    local s = { winner = result, rounds = self.round, pcs = {}, foes = {},
                pc_downs = self.events.pc_downs, pc_deaths = self.events.pc_deaths }
    local hp_lost, hp_max = 0, 0
    -- (The Museum of Nightmares: allies, foes that ran, and anyone left as stone.)
    local allies, fled, stone = {}, {}, {}
    for _, c in ipairs(self.creatures) do
        if c.effects[1] and self:any_effect(c, "stone") then
            table.insert(stone, c.name)
        end
        if c.removed and c.side ~= "party" and not c.dead and c.removed_why ~= "surrender" then
            table.insert(fled, c.name)
        end
        if c.ally then
            table.insert(allies, { name = c.name, monster = c.monster_id, dead = c.dead, hp = c.hp, hp_max = c.hp_max,
                                   shut_down = c.shut_down, powered_down = c.powered_down, stats = c.stats })
        elseif c.side == "party" then
            hp_max = hp_max + c.hp_max
            local lost = c.hp_max - (c.dead and 0 or c.hp)
            hp_lost = hp_lost + math.max(0, lost)
            table.insert(s.pcs, { name = c.name, class = c.class, subclass = c.subclass, hp = c.hp, hp_max = c.hp_max,
                                  dead = c.dead, down = c.down, stats = c.stats })
        else
            table.insert(s.foes, { name = c.name, dead = c.dead, hp = c.hp, hp_max = c.hp_max, stats = c.stats })
        end
    end
    s.hp_lost_frac = hp_max > 0 and hp_lost / hp_max or 0
    if #allies > 0 then s.allies = allies end
    if #fled > 0 then s.fled = fled end
    if #stone > 0 then s.petrified = stone end
    return s
end

M.B = B
return M
