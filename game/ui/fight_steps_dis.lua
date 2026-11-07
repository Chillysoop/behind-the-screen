-- rules: dis   (Death in Space's own screen, reached through the rule set's screens, game/ui/sets.lua)
-- A Death in Space grid fight's steps on game night (game/rules/dis/battle.lua): attacks of Body or Tech against a
-- defense rating, damage off hit points, a natural 20's or a risky attack's extra die, cover, the Body check at zero,
-- morale, and the void points it all costs. Each is told on the board and in the log. night_view binds its own pieces in
-- (bind) and calls play_step for every step, the same as for any grid fight.

local M          -- (game/ui/night_view.lua's module: push, float, caption, refresh_hp...)
local SPARK
local battle_hud, name_of, pacing, panels, post, spark, speed, theme, util

local F = {}

function F.bind(ctx)
    M = ctx.M
    battle_hud = ctx.battle_hud
    name_of = ctx.name_of
    pacing = ctx.pacing
    panels = ctx.panels
    post = ctx.post
    spark = ctx.spark
    speed = ctx.speed
    theme = ctx.theme
    util = ctx.util
    SPARK = ctx.SPARK
    F.bound = true
end

local ABILITY = { bdy = "Body", tec = "Tech" }

local function is_party(app, id)
    return app.hp and app.hp[id] ~= nil and app.campaign:player(id) ~= nil
end

local function set_hp(app, id, hp, max)
    if app.hp[id] and hp then
        app.hp[id] = { hp, max or app.hp[id][2] }
        M.refresh_hp(app)
    end
end

local function weapon_of(app, s)
    return (name_of(app, s.id) .. "'s " .. string.lower(s.weapon or "attack"))
end

local function left_of(s)
    if not s.hp or not s.hp_max then
        return ""
    end
    if s.hp <= 0 then
        return " Down to 0."
    end
    return " " .. util.int(s.hp) .. " of " .. util.int(s.hp_max) .. " left."
end

-- "Body 14+3 = 17 against defense rating 13"
local function versus(s)
    local what = s.ranged and ABILITY.tec or ABILITY.bdy
    local sign = (s.bonus or 0) < 0 and "-" or "+"
    return what .. " " .. util.int(s.roll) .. sign .. util.int(math.abs(s.bonus or 0)) .. " = " .. util.int(s.total)
        .. " against defense rating " .. util.int(s.dr or 0)
end

local function edge_said(s)
    if s.edge == "adv" then
        return " (two dice, the better counts: a void point)"
    elseif s.edge == "dis" then
        return " (two dice, the worse counts: " .. (s.cover_what and ("behind the " .. s.cover_what) or "partly in cover") .. ")"
    end
    return ""
end

function F.play_step(app, s, pace)
    local k = s.kind
    local sp = speed(app) / (pace or 1)
    if k == "move" then
        if s.path and #s.path > 0 then
            post("walk", { id = s.id, path = s.path, step = pacing.PER_SQUARE / sp })
        end
    elseif k == "initiative" then
        battle_hud.initiative(app, s.order)
    elseif k == "attack" then
        if s.target then
            post("lunge", { id = s.id, target = s.target, ranged = s.ranged, time = 0.32 / sp })
        end
        M.add_die(app, { roll = s.roll, success = s.hit, crit = s.crit, dm = s.dm })
        app.last_attack = s
        if s.risky then
            M.float(app, s.id, "Risky!", theme.orange)
        end
        if is_party(app, s.id) and s.roll then
            panels.roll(app, s.id, { roll = s.roll, mod = s.bonus or 0, total = s.total,
                                     against = "DR " .. util.int(s.dr or 0), what = s.weapon or "Attack",
                                     success = s.hit, crit = s.crit, fumble = s.roll == 1 })
        end
        if not s.hit then
            M.float(app, s.target, "miss", theme.dim)
            local back = s.counter and (name_of(app, s.id) .. " hits straight back. ") or ""
            M.push(app, back .. util.capitalize(weapon_of(app, s)) .. " misses " .. name_of(app, s.target) .. ": " .. versus(s)
                .. edge_said(s) .. "." .. (s.risky and " A risky miss: they get to hit straight back." or ""), "system")
        end
    elseif k == "damage" then
        post("hit", { id = s.id })
        M.float(app, s.id, "-" .. util.int(s.amount or 0), s.crit and theme.gold or theme.red, s.crit)
        set_hp(app, s.id, s.hp, s.hp_max)
        local a = app.last_attack
        local amount = util.int(s.amount or 0)
        if a and a.target == s.id and a.hit then
            local extra = {}
            if a.crit then
                table.insert(extra, "an extra die for the natural 20")
            end
            if a.risky then
                table.insert(extra, "an extra die for the risk")
            end
            local dice = " (" .. (a.dmg or "") .. (#extra > 0 and (", " .. util.join_names(extra)) or "") .. ")"
            M.push(app, (a.counter and (name_of(app, a.id) .. " hits straight back. ") or "") .. util.capitalize(weapon_of(app, a))
                .. " hits " .. name_of(app, s.id) .. ": " .. versus(a) .. edge_said(a) .. ". " .. amount .. " damage" .. dice .. "."
                .. left_of(s), a.crit and "good" or "system")
            app.last_attack = nil
        else
            M.push(app, name_of(app, s.id) .. " takes " .. amount .. " damage." .. left_of(s), "system")
        end
    elseif k == "void" then
        if s.text and s.text ~= "" then
            spark(app, s.id, SPARK.crit)
            M.push(app, s.text, "dice")
        end
    elseif k == "down" then
        post("down", { id = s.id })
        M.float(app, s.id, "Down!", theme.orange, true)
        set_hp(app, s.id, 0)
        post("pose", { who = s.id, pose = "gasp", hold = true })
        M.push(app, name_of(app, s.id) .. " goes down at 0 hit points, and rolls Body against 12 at once to stay alive.", "bad")
    elseif k == "death_check" then
        M.add_die(app, { roll = s.roll, success = s.ok })
        if is_party(app, s.id) then
            panels.roll(app, s.id, { roll = s.roll, mod = s.bonus or 0, total = s.total, against = "12", what = "Body",
                                     success = s.ok, crit = s.roll == 20, fumble = s.roll == 1 })
        end
        local sign = (s.bonus or 0) < 0 and "-" or "+"
        M.push(app, name_of(app, s.id) .. " rolls Body: " .. util.int(s.roll) .. sign .. util.int(math.abs(s.bonus or 0)) .. " = "
            .. util.int(s.total) .. " against 12. " .. (s.ok and "Made it: stable, but out cold until they rest."
                or "Missed it."), s.ok and "good" or "bad")
    elseif k == "stable" then
        M.float(app, s.id, "Stable", theme.teal)
    elseif k == "death" then
        if is_party(app, s.id) then
            post("down", { id = s.id })
            M.float(app, s.id, "Dead", theme.red, true)
            M.push(app, name_of(app, s.id) .. " is dead.", "bad")
        else
            M.float(app, s.id, "Beaten!", theme.gold, true)
            spark(app, s.id, SPARK.crit)
            post("die", { id = s.id })
            battle_hud.gone(app, s.id)
            M.push(app, name_of(app, s.id) .. " is beaten: out of the fight.", "good")
        end
    elseif k == "morale" then
        M.push(app, name_of(app, s.id) .. " tests morale: 2d6 = " .. util.int(s.roll or 0) .. " against "
            .. util.int(s.ml or 0) .. ". " .. (s.broke and "They've had enough." or "They hold."), "system")
    elseif k == "flee" then
        post("flee", { id = s.id })
        battle_hud.gone(app, s.id)
        M.push(app, name_of(app, s.id) .. " runs for it.", "system")
    elseif k == "yield" then
        local talk = s.how == "parley"
        M.float(app, s.id, talk and "Wants to talk" or "Surrenders", theme.teal)
        battle_hud.gone(app, s.id)
        M.push(app, name_of(app, s.id) .. (talk and " lowers their weapon: they want to talk." or " throws down their weapon and surrenders."), "good")
    elseif k == "reload" then
        M.float(app, s.id, "Reload", theme.dim)
        M.push(app, name_of(app, s.id) .. " is out of shots, and spends the turn slapping in a new clip.", "system")
    end
end

return F
