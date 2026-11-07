-- rules: 5e   (5e's own, reached through the rule set's screens, game/ui/sets.lua: docs/design/rule-sets.md)
-- A 5e grid fight's steps on game night (moved out of game/ui/night_view.lua): attacks against AC, crits, damage,
-- healing in hit points, death saves, spells, Heroic Inspiration's reroll, each told on the board and in the caption.
-- night_view binds its own pieces in (bind) and calls play_step for every step of the fight.

local M          -- (game/ui/night_view.lua's module: push, float, caption, refresh_hp...)
local BLOCKED, CLASS_SPRITE, MUSEUM_SAY, SPARK
local battle_hud, mid, monster_sprite, name_of, pacing, panels, post, post_board, rgba, ruleset, spark, speed, stage, theme, util

local F = {}

function F.bind(ctx)
    M = ctx.M
    battle_hud = ctx.battle_hud
    mid = ctx.mid
    monster_sprite = ctx.monster_sprite
    name_of = ctx.name_of
    pacing = ctx.pacing
    panels = ctx.panels
    post = ctx.post
    post_board = ctx.post_board
    rgba = ctx.rgba
    ruleset = ctx.ruleset
    spark = ctx.spark
    speed = ctx.speed
    stage = ctx.stage
    theme = ctx.theme
    util = ctx.util
    BLOCKED = ctx.BLOCKED
    CLASS_SPRITE = ctx.CLASS_SPRITE
    MUSEUM_SAY = ctx.MUSEUM_SAY
    SPARK = ctx.SPARK
    F.bound = true
end

local function set_hp(app, id, hp, max)
    if app.hp[id] and hp then
        app.hp[id] = { hp, max or app.hp[id][2] }
        M.refresh_hp(app)
    end
    battle_hud.set_hp(app, id, hp, max)
end

-- Whose turn: the mini acting, for the turn order.
local function is_party(app, id)
    return type(id) == "string" and app.campaign:player(id) ~= nil
end

-- Why an attack landed or didn't, in one line anyone can follow (the newcomer playtest, October
-- 16: "a 9 against 15 both missed and hit", three ACs for one bandit, no reason given).
-- "Thessaly's Fire Bolt" / "the road's bandit chief's scimitar"
-- A spell's name from its id ("sacred_flame" is Sacred Flame); a name stays as it is.
local function spell_name(id)
    local ok, spells = pcall(ruleset.engine, "spells")
    local sp = ok and spells.list and spells.list[id]
    return (type(sp) == "table" and sp.name) or (string.gsub(tostring(id), "_", " "))
end

local spell_names
local function is_spell(name)
    if not spell_names then
        spell_names = {}
        local ok, spells = pcall(ruleset.engine, "spells")
        for _, sp in pairs(ok and spells.list or {}) do
            if type(sp) == "table" and sp.name then
                spell_names[sp.name] = true
            end
        end
    end
    return spell_names[name] or false
end

local function weapon_of(app, a)
    local who = name_of(app, a.id)
    local w = a.weapon or "attack"
    if not (a.spell or is_spell(w)) then
        w = string.lower(w)
    end
    return who .. (string.sub(who, -1) == "s" and "' " or "'s ") .. w
end

local function target_of(app, id)
    return mid(name_of(app, id))
end

-- "8 + 5 = 13 against AC 20 (15, +5 behind the boulder), with Advantage"
local function versus(a)
    local bonus = (a.total or a.roll or 0) - (a.roll or 0)
    local out = util.int(a.roll or 0) .. " " .. (bonus < 0 and "- " or "+ ") .. util.int(math.abs(bonus)) .. " = "
        .. util.int(a.total or 0) .. " against AC " .. util.int(a.ac or 0)
    if a.cover then
        out = out .. " (" .. util.int((a.ac or 0) - a.cover) .. ", +" .. util.int(a.cover)
            .. (a.cover_what and (" behind the " .. a.cover_what) or " for cover") .. ")"
    end
    if (a.mode or 0) > 0 then
        out = out .. ", with Advantage"
    elseif (a.mode or 0) < 0 then
        out = out .. ", with Disadvantage"
    end
    if a.heroic then
        out = out .. " (a reroll: Heroic Inspiration)"
    end
    return out
end

-- "45 of 52 left", or "down to 0"
local function left_of(s)
    if not s.hp or not s.hp_max then
        return ""
    end
    if s.hp <= 0 then
        return " Down to 0."
    end
    return " " .. util.int(s.hp) .. " of " .. util.int(s.hp_max) .. " left."
end

-- One step of a combat turn on the mat.
function F.play_step(app, s, pace)
    local k = s.kind
    local sp = speed(app) / (pace or 1)
    if k == "move" then
        if s.path and #s.path > 0 then
            post("walk", { id = s.id, path = s.path, step = pacing.PER_SQUARE / sp })
        end
    elseif k == "initiative" then
        -- Everyone rolls initiative: the heroes' dice show on their panels, the order along the top.
        for _, o in ipairs(s.order or {}) do
            if o.pc and is_party(app, o.id) then
                panels.roll(app, o.id, { roll = o.roll, mod = o.bonus, total = o.total, what = "Initiative" })
            end
        end
        battle_hud.initiative(app, s.order)
        local first = s.order and s.order[1]
        if first then
            M.push(app, "Initiative: " .. (function()
                local parts = {}
                for _, o in ipairs(s.order) do
                    table.insert(parts, (o.name or "?") .. " " .. util.int(o.total or 0))
                end
                return table.concat(parts, ", ")
            end)(), "system")
        end
    elseif k == "attack" then
        if s.target then
            post("lunge", { id = s.id, target = s.target, ranged = s.ranged, time = 0.32 / sp })
        end
        M.add_die(app, { roll = s.roll, success = s.hit, crit = s.crit, dm = s.dm, hidden = s.hidden })
        app.last_attack = s
        if is_party(app, s.id) and s.roll then
            panels.roll(app, s.id, { roll = s.roll, mod = (s.total or s.roll) - s.roll, total = s.total,
                                     against = s.ac and ("AC " .. util.int(s.ac)) or nil, what = s.weapon or "Attack",
                                     success = s.hit, crit = s.crit, fumble = s.roll == 1 })
        end
        if not s.hit then
            M.float(app, s.target, s.blocked and (BLOCKED[s.blocked] or "Blocked") or "miss", theme.dim)
            local tgt = target_of(app, s.target)
            if s.blocked == "no_line" then
                M.push(app, name_of(app, s.id) .. " can't see " .. tgt .. " from there: there's a wall in the way.", "system")
            elseif s.hidden then
                M.push(app, util.capitalize(weapon_of(app, s)) .. " misses " .. tgt .. " (you rolled it behind your screen).", "system")
            elseif s.blocked == "cover" then
                -- The board earning its keep: the shot that would have landed hits the scenery.
                M.push(app, util.capitalize(tgt) .. " ducks behind " .. (s.cover_what and ("the " .. s.cover_what) or "cover")
                    .. ", and " .. mid(weapon_of(app, s)) .. " hits that instead: " .. versus(s) .. ".", "system")
            elseif s.blocked then
                M.push(app, util.capitalize(weapon_of(app, s)) .. " would have hit " .. tgt .. " (" .. versus(s) .. "), but it's stopped: "
                    .. (BLOCKED[s.blocked] or "blocked") .. ".", "system")
            elseif s.roll == 1 then
                M.push(app, util.capitalize(weapon_of(app, s)) .. " misses " .. tgt .. ": a natural 1 always misses.", "system")
            else
                M.push(app, util.capitalize(weapon_of(app, s)) .. " misses " .. tgt .. ": " .. versus(s) .. ".", "system")
            end
        end
    elseif k == "damage" then
        post("hit", { id = s.id })
        M.float(app, s.id, "-" .. util.int(s.amount or 0), s.crit and theme.gold or theme.red, s.crit)
        set_hp(app, s.id, s.hp, s.hp_max)
        local a = app.last_attack
        local amount = util.int(s.amount or 0)
        if s.graze and a and a.target == s.id then
            -- A miss that still hurts: say it's the weapon's trick, not a hit.
            M.push(app, "Even missing, " .. mid(weapon_of(app, a)) .. " grazes " .. target_of(app, s.id) .. " for " .. amount
                .. " (the weapon's Graze trick: a miss still nicks)." .. left_of(s), "system")
            app.last_attack = nil
        elseif a and a.target == s.id and a.hit then
            -- (Damage past what the dice can do says why: a crit, or a weakness.)
            local weak = s.weak and (s.weak == "paint" and ", doubled: painted things fear it" or (", doubled: weak to " .. s.weak)) or ""
            local dice = (a.dmg and a.dmg ~= "") and (" (" .. a.dmg .. (s.crit and ", doubled" or "") .. weak .. ")") or ""
            if a.hidden then
                M.push(app, util.capitalize(weapon_of(app, a)) .. " hits " .. target_of(app, s.id) .. " (your roll, behind the screen): "
                    .. amount .. " damage" .. dice .. "." .. left_of(s), "system")
            elseif s.crit then
                M.push(app, util.capitalize(weapon_of(app, a)) .. " crits " .. target_of(app, s.id) .. ": a natural 20, so the damage "
                    .. "dice double. " .. amount .. " damage" .. dice .. "!" .. left_of(s), "good")
            else
                local tie = (a.total and a.ac and a.total == a.ac) and " (matching the AC is enough)" or ""
                M.push(app, util.capitalize(weapon_of(app, a)) .. " hits " .. target_of(app, s.id) .. ": " .. versus(a) .. tie .. ". "
                    .. amount .. " damage" .. dice .. "." .. left_of(s), "system")
            end
            app.last_attack = nil
        else
            local from = s.spell and (" from " .. spell_name(s.spell)) or ""
            M.push(app, name_of(app, s.id) .. " takes " .. amount .. " damage" .. from .. "." .. left_of(s), "system")
        end
    elseif k == "heal" then
        M.float(app, s.id, "+" .. util.int(s.amount or 0), theme.green)
        spark(app, s.id, SPARK.heal)
        set_hp(app, s.id, s.hp, s.hp_max)
        -- Healing shows in the log (A7).
        if (s.amount or 0) > 0 then
            local hp = s.hp and s.hp_max and (" (" .. util.int(s.hp) .. "/" .. util.int(s.hp_max) .. ")") or ""
            if s.by and s.by ~= s.id then
                M.push(app, name_of(app, s.by) .. " heals " .. name_of(app, s.id) .. " for " .. util.int(s.amount) .. hp .. ".", "good")
            else
                M.push(app, name_of(app, s.id) .. " regains " .. util.int(s.amount) .. " hit points" .. hp .. ".", "good")
            end
        end
    elseif k == "temp" then
        M.float(app, s.id, "+" .. util.int(s.amount or 0) .. " temp", theme.teal)
        M.push(app, name_of(app, s.id) .. " gains " .. util.int(s.amount or 0) .. " temporary hit points.", "good")
    elseif k == "down" then
        post("down", { id = s.id })
        M.float(app, s.id, "Down!", theme.orange, true)
        set_hp(app, s.id, 0)
        -- A hero at 0: a moment the whole table feels (the playtest, November 3: "a more pronounced
        -- downed scene"). Over their tile until they're up, stable or gone: their death saves.
        if is_party(app, s.id) then
            app.ds = app.ds or {}
            app.ds[s.id] = { s = 0, f = 0 }
            M.dying(app, s.id)
            post("pose", { who = s.id, pose = "gasp", hold = true })
        end
        -- The first time, what it means (a newcomer thinks "down" is "dead").
        if is_party(app, s.id) and not app.down_said then
            app.down_said = true
            M.push(app, name_of(app, s.id) .. " goes down! At 0 health a hero isn't dead yet: they roll each turn to stay "
                .. "alive, and any healing brings them back up.", "bad")
        else
            M.push(app, name_of(app, s.id) .. " goes down!", "bad")
        end
    elseif k == "up" then
        post("up", { id = s.id })
        M.float(app, s.id, "Back up!", theme.green, true)
        M.drop_dying(app, s.id)
    elseif k == "death" then
        if app.hp[s.id] then
            post("down", { id = s.id })
        else
            -- A beat for it before the mini goes (the newcomer playtest, October 16: the wolf just vanished).
            M.float(app, s.id, "Beaten!", theme.gold, true)
            spark(app, s.id, SPARK.crit)
            post("die", { id = s.id })
            battle_hud.gone(app, s.id)
            M.push(app, name_of(app, s.id) .. " is beaten: out of the fight.", "good")
        end
    elseif k == "spell" then
        local col = SPARK[s.spell] or rgba(1.0, 0.8, 0.5)
        -- The caster's hands light up, then the spell lands: on a target, or across an area.
        spark(app, s.id, col)
        if s.area then
            battle_hud.area(app, s.area, col)
        else
            spark(app, s.target or s.id, col)
        end
        if s.name then
            M.float(app, s.id, s.name, theme.purple)
            M.push(app, name_of(app, s.id) .. " casts " .. s.name .. ((s.level or 0) > 0 and (" (level " .. util.int(s.level)
                .. (s.free and (", free: " .. s.free) or "") .. ")") or "")
                .. (s.area and (", " .. util.int(#s.area) .. " squares") or "") .. ".", "system")
        end
    elseif k == "hazard" then
        M.push(app, "Hazard: " .. (s.name or "") .. (s.from and (", from the " .. s.from) or "") .. ". " .. (s.about or ""),
            "system")
    elseif k == "hazard_act" then
        M.push(app, (s.name or "The hazard acts") .. ".", "bad")
    elseif k == "zone" then
        local col = SPARK[s.what] or rgba(0.9, 0.9, 0.9)
        battle_hud.area(app, s.cells, col, s.zone)
    elseif k == "zone_end" then
        battle_hud.zone_end(app, s.zone)
    elseif k == "door" then
        -- Set the stage: a door swings open on the mat as someone walks through, or a lock gives.
        post_board("door", { fid = s.fid, state = s.state })
        if s.state == "open" then
            M.push(app, (s.id and name_of(app, s.id) or "Someone") .. " opens the door.", "system")
        elseif s.state == "closed" then
            M.push(app, "The lock gives.", "good")
        end
    elseif k == "feature" then
        if s.name == "Potion of Healing" then
            M.float(app, s.id, "Potion!", theme.teal)
            if s.target and s.target ~= s.id and type(s.target) ~= "table" then
                M.push(app, name_of(app, s.id) .. " pours a Potion of Healing into " .. name_of(app, s.target) .. ".", "good")
            else
                M.push(app, name_of(app, s.id) .. " drinks a Potion of Healing.", "good")
            end
        elseif s.name == "Heroic Inspiration" and s.from and s.to then
            M.float(app, s.id, s.name, theme.gold)
            M.push(app, name_of(app, s.id) .. " spends Heroic Inspiration to reroll the die: " .. util.int(s.from) .. " becomes "
                .. util.int(s.to) .. ".", "good")
        elseif s.museum and MUSEUM_SAY[s.museum] then
            -- The museum's big moments (v2, game/rules/museum.lua), said the way the DM would.
            local say = MUSEUM_SAY[s.museum]
            local function nm(id)
                return (type(id) == "string" and name_of(app, id)) or "someone"
            end
            local text = say[1]
            if say.soft and app.campaign and app.campaign.adv then
                local adv = require "game.model.adventure"
                for tag, alt in pairs(say.soft) do
                    if adv.test(app.campaign, { soft = tag }) then
                        text = alt
                    end
                end
            end
            M.float(app, s.id, s.name, say[2] or theme.teal)
            M.push(app, (string.gsub(text, "{(%w+)}", { who = nm(s.id), target = nm(s.target), by = nm(s.by) })), say[3] or "system")
        elseif s.name then
            M.float(app, s.id, s.name, theme.teal)
            M.push(app, name_of(app, s.id) .. ": " .. s.name .. ".", "system")
        end
    elseif k == "condition" then
        if s.name then
            M.float(app, s.id, s.name, theme.purple)
        end
        battle_hud.condition(app, s.id, s.name, s.conds, true)
    elseif k == "condition_end" then
        battle_hud.condition(app, s.id, s.name, s.conds, false)
    elseif k == "save" then
        M.add_die(app, { roll = s.roll, success = s.ok, dm = s.dm, hidden = s.hidden })
        M.float(app, s.id, s.ok and "Saved" or "Failed save", s.ok and theme.teal or theme.orange)
        -- A roll to resist, said in the log like an attack (the newcomer playtest, October 16).
        local ab = s.ab and (string.upper(s.ab) .. " save") or "save"
        -- (Rolled twice, and why: "with Disadvantage: the drone left them half asleep".)
        if s.mode then
            ab = ab .. ((s.mode == "adv" and ", with Advantage") or (s.mode == "dis" and ", with Disadvantage")
                or ", Advantage and Disadvantage cancel out") .. (s.why_mode and (": " .. s.why_mode) or "")
        end
        if s.hidden or not (s.roll and s.total and s.dc) then
            M.push(app, name_of(app, s.id) .. (s.ok and " resists it" or " fails to resist") .. " (a " .. ab
                .. (s.hidden and ", behind your screen)." or ")."), "system")
        else
            M.push(app, name_of(app, s.id) .. (s.ok and " resists it" or " fails to resist") .. " (a " .. ab .. "): "
                .. util.int(s.roll) .. " " .. ((s.total - s.roll) < 0 and "- " or "+ ") .. util.int(math.abs(s.total - s.roll))
                .. " = " .. util.int(s.total) .. " against DC " .. util.int(s.dc) .. ".", "system")
        end
        if is_party(app, s.id) and s.roll then
            panels.roll(app, s.id, { roll = s.roll, mod = (s.total or s.roll) - s.roll, total = s.total,
                                     against = s.dc and ("DC " .. util.int(s.dc)) or nil,
                                     what = (s.ab and string.upper(s.ab) or "") .. " save", success = s.ok })
        end
    elseif k == "death_save" then
        M.add_die(app, { roll = s.roll, success = (s.roll or 0) >= 10, crit = s.roll == 20, fumble = s.roll == 1 })
        local t = app.ds and app.ds[s.id]
        if t then
            local r = s.roll or 0
            if r == 1 then
                t.f = t.f + 2
            elseif r >= 10 and r < 20 then
                t.s = t.s + 1
            elseif r < 10 then
                t.f = t.f + 1
            end
            if r == 20 then
                M.drop_dying(app, s.id)
            else
                M.dying(app, s.id)
            end
        end
        M.float(app, s.id, "Death save: " .. util.int(s.roll or 0), (s.roll or 0) >= 10 and theme.teal or theme.red)
        if is_party(app, s.id) then
            panels.roll(app, s.id, { roll = s.roll, total = s.roll, against = "DC 10", what = "Death save",
                                     success = (s.roll or 0) >= 10, crit = s.roll == 20 })
        end
    elseif k == "stable" then
        M.float(app, s.id, "Stable", theme.teal)
        if app.ds and app.ds[s.id] then
            app.ds[s.id].stable = true
            M.dying(app, s.id)
        end
    elseif k == "fortitude" then
        M.float(app, s.id, "Undead Fortitude", theme.purple)
    elseif k == "flee" and s.why == "yield" then
        -- Standing down with a boss who yielded: her line says it, once (fight.lua's yield).
        M.float(app, s.id, "Stands down", theme.teal)
        battle_hud.gone(app, s.id)
    elseif k == "flee" then
        post("flee", { id = s.id })
        battle_hud.gone(app, s.id)
        M.push(app, name_of(app, s.id) .. " runs for it.", "system")
    elseif k == "join" and s.pc then
        -- A hero who split off comes running back into the fight (the split party, November 3).
        local pl = app.campaign:player(s.id)
        local sprite = (pl and pl.mini) or CLASS_SPRITE[s.class] or "fighter"
        post("spawn", { list = { { id = s.id, sprite = sprite, x = s.x, y = s.y, side = "party" } } })
        app.hp[s.id] = { s.hp, s.hp_max }
        M.refresh_hp(app)
        M.push(app, (s.name or "Someone") .. " is back, and in the fight.", "good")
    elseif k == "join" then
        app.names[s.id] = s.name
        app.join_n = (app.join_n or 0) + 1
        local sprite = monster_sprite(s.monster, app.join_n)
        post("spawn", { list = { { id = s.id, sprite = sprite, x = s.x, y = s.y } } })
        battle_hud.join(app, s.id, s.name, sprite, s.hp, s.hp_max)
        app.hp[s.id] = nil
        M.push(app, (s.name or "Someone") .. " joins the fight!", "twist")
    end
end

return F
