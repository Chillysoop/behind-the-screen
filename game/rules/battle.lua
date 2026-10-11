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
--   b.blocked[x * 1000 + y] = true                              terrain squares nobody can enter
--   b.force_end = "party" | "foes"                              end the fight after this turn

local dice_mod = require "game.rules.dice"
local creature = require "game.rules.creature"

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
        if o.side ~= c.side and not o.dead and (include_down or not o.down) and not o.removed then
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
    if self.on_event and eff.conds and next(eff.conds) then
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
            if self.on_event and eff.conds and next(eff.conds) then
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
    local ac = creature.base_ac(c) + self:sum_effect(c, "ac")
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

-- Can a creature see another? Open ground; Blinded and Invisible matter.
function B:can_see(a, b)
    if self:has(a, "blinded") then
        return false
    end
    if self:has(b, "invisible") then
        return false
    end
    return true
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
    for _, e in ipairs(att.effects) do
        if e.sapped then table.insert(dis, "Sap") end
        if e.enfeeble_dis_next then table.insert(dis, "Ray of Enfeeblement") end
        if e.steady_aim then table.insert(adv, "Steady Aim") end
        if e.feint_vs == tgt then table.insert(adv, "Feint") end
        if e.vex_vs == tgt then table.insert(adv, "Vex") end
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
        if e.marked_adv then table.insert(adv, "Guiding Bolt") end
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
function B:attack(att, tgt, prof, opts)
    opts = opts or {}
    local res = { hit = false, crit = false, damage = 0, target = tgt }
    if tgt.dead then
        return res
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
            if decoy and (tgt == o or self:dist_xy(tgt.x, tgt.y, decoy.x, decoy.y) <= 10) then
                if not self:save(att, "wis", creature.spell_dc(o), { kind = "decoy" }) then
                    -- Swinging at a shifting illusion: Disadvantage (cancels any Advantage).
                    local mode = self:attack_mode(att, tgt, prof, opts)
                    local roll = self.dice:d20(mode > 0 and 0 or -1)
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
    local crit = roll >= crit_range
    local ac = self:ac(tgt)
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
                ac = self:ac(tgt)
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
                            ac = ac, blocked = "mirror_image", ranged = prof.kind == "ranged", mode = mode })
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
    if not hit then
        self:log("%s misses %s with %s (%d vs AC %d%s).", att.name, tgt.name, prof.name, total, ac,
            mode > 0 and ", Advantage" or (mode < 0 and ", Disadvantage" or ""))
        self:emit({ kind = "attack", att = att, tgt = tgt, weapon = prof.name, dmg = dice_text(prof.damage), to_hit = prof.to_hit, hit = false, roll = roll, total = total,
                    ac = ac, mode = mode, blocked = res.blocked, ranged = prof.kind == "ranged",
                    opportunity = opts.opportunity, spell = prof.spell })
        -- Graze (p. 90): miss still deals the ability modifier.
        if prof.mastery == "graze" and (prof.ability or 0) > 0 then
            self:deal(att, tgt, { { prof.ability, prof.damage[1][4] } }, { graze = true })
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
    local parts = self:roll_parts(prof.damage, crit, { gwf = prof.gwf, savage = savage })
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
                opportunity = opts.opportunity, spell = prof.spell })
    res.damage = self:deal(att, tgt, parts, { crit = crit, melee = prof.kind == "melee", weapon = prof.is_weapon })
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
        if not immune and not self:save(tgt, r.save, r.dc, { kind = r.condition }) then
            self:add_effect(tgt, { name = r.condition, conds = { [r.condition] = true },
                                   expires = self:next_turn(tgt, "end") })
            self:log("%s is %s until the end of its next turn.", tgt.name, r.condition)
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
            if tgt.resist[dtype] or bond then
                amount = math.floor(amount / 2)
            end
            if tgt.vulnerable[dtype] then
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
                    hp_max = tgt.hp_max, crit = info.crit })
        self:after_damage(tgt, total, info)
        return total
    end
    -- Damage at 0 Hit Points (p. 18).
    if tgt.down then
        self:emit({ kind = "damage", src = src, tgt = tgt, amount = total, absorbed = absorbed, hp = 0,
                    hp_max = tgt.hp_max, crit = info.crit, spell = info.spell })
        if through >= tgt.hp_max then
            self:kill(tgt, src, "massive damage")
        else
            self:death_failure(tgt, info.crit and 2 or 1, src)
        end
        return total
    end
    tgt.hp = tgt.hp - through
    self:log("  %s takes %d damage (%d/%d).", tgt.name, total, math.max(tgt.hp, 0), tgt.hp_max)
    self:emit({ kind = "damage", src = src, tgt = tgt, amount = total, absorbed = absorbed, hp = math.max(tgt.hp, 0),
                hp_max = tgt.hp_max, crit = info.crit, spell = info.spell })
    if tgt.hp <= 0 then
        local overflow = -tgt.hp
        tgt.hp = 0
        if tgt.pc then
            if overflow >= tgt.hp_max then
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

function B:death_save(c)
    local roll = self.dice:d20(0, c.traits.halfling_luck)
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
    local mode = 0
    if adv and not dis then mode = 1 elseif dis and not adv then mode = -1 end
    local roll = self.dice:d20(mode, c.traits.halfling_luck)
    local bonus = creature.save_bonus(c, ab) + self:d4_riders(c)
    if self:any_effect(c, "warding_bond") then
        bonus = bonus + 1
    end
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
    return roll + abmod(c, ab) + (prof_bonus or 0), roll
end

-- Movement and Opportunity Attacks (p. 15, p. 185) ------------------------------------------------------------------------------

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

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
        self:attack(e, c, prof, { opportunity = true })
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
        if c.sub and c.sub.init_advantage then
            mode = 1
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
    c.turn = { action = true, bonus = true, move = self:speed(c), moved = false, attacks = 0 }
    c.reaction_used = false
    self:process_expiry(c, "start")
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
        if e and e.save_end and not c.dead then
            local s = e.save_end
            if self:save(c, s.ab, s.dc, { kind = e.name }) then
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
        if not c.dead and not c.down and not c.removed then
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
        self.ai.take_turn(self, c)
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
    self:emit({ kind = "join", who = c })
    return c
end

-- A creature leaving the fight (fleeing, or written out by the DM).
function B:remove(c, why)
    c.removed = true
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
    for _, c in ipairs(self.creatures) do
        if c.side == "party" then
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
    return s
end

M.B = B
return M
