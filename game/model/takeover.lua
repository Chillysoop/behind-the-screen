-- Taking over (M8, B8; the GDD's "Decision points: Taking over"). Most of game night runs on its
-- own, the way a table does. Once a night the game hands the DM a key person's voice (talk as the
-- NPC: three lines a turn, warm, guarded or a lie, for two turns), and once a night the boss's
-- turn in a fight's key round (who it goes for, or a speech instead). Each stands in for a card,
-- so the night's 8 to 15 decisions hold. The lines come from the dialogue library (talk_open,
-- talk_ask, talk_reply); the table's reactions are in game/data/takeover.lua. Pure Lua.

local content = require "game.model.content"
local score = require "game.model.score"
local util = require "game.model.util"
local ledger = require "game.model.ledger"
local skills = require "game.rules.skills"
local data = require "game.data.takeover"

local M = {}
M.data = data

M.STANCES = { "warm", "guarded", "lie" }
M.STANCE_NAME = { warm = "Warm", guarded = "Guarded", lie = "A lie" }
-- People whose voice sheet goes by another name (Wren is the hooded stranger until she isn't).
M.VOICE_ALIAS = { wren = "stranger" }
-- Before a fight, it's the villain having their say before the dice come out.
M.TALK_SCENES = { social = true, mystery = true, downtime = true, exploration = true, puzzle = true, combat = true,
                  set_piece = true }

-- Who voices this person: their own voice sheet if the library has their lines, else the plain one.
function M.speaker(lib, cast)
    local id = M.VOICE_ALIAS[cast.id] or cast.id
    local t = lib.trigger and lib.trigger.talk_open
    if t and t.speaker_set and t.speaker_set[id] then
        return id
    end
    return "anyone"
end

-- A line for this person, stance and step, fresh if possible (said lines rest for three weeks; a
-- person met every week falls back to an older line rather than go quiet). Not remembered yet:
-- only the line the DM picks is.
local function line_for(night, trigger, speaker, stance, vars)
    local tk = night.talk
    local ctx = { split = stance, recent = tk:skip(), rng = night.rng }
    local l = tk.lib:pick(trigger, speaker, ctx) or tk.lib:pick(trigger, speaker, { split = stance, rng = night.rng })
    if not l and speaker ~= "anyone" then
        return line_for(night, trigger, "anyone", stance, vars)
    end
    if not l then
        return nil
    end
    return util.fill(l.text, vars), l
end

-- What fits who they are: a villain lies, a Friendly person is warm, a Hostile one guarded.
function M.in_character(cast, att)
    if cast.villain or (cast.foe and cast.talks ~= false) then
        return "lie"
    elseif att >= 1 then
        return "warm"
    elseif att <= -1 then
        return "guarded"
    end
    return nil
end

-- Talk as the NPC ------------------------------------------------------------------------------

-- Is this the scene for it? A key person (anyone the scene's cast card is, but not a pack of
-- monsters), once a night, and only with room for it under the night's decisions.
function M.talk_ready(night, sc)
    if night.took_talk or night.no_takeover or not M.TALK_SCENES[sc.type] then
        return false
    end
    local cast = night:shown_cast(sc)
    if not cast or cast.talks == false or (cast.foe and not cast.villain) then
        return false
    end
    -- Before a fight it's the villain's say, nobody else's.
    if (sc.type == "combat" or sc.type == "set_piece") and not cast.villain then
        return false
    end
    if not night:room(13) then
        return false
    end
    return night.rng:chance(data.TALK_CHANCE)
end

-- Who walks up to them: the hero whose story this is, else whoever at the table talks to everyone.
local function talker(night, sc, cast)
    for _, c in util.sorted_pairs(sc.comps) do
        if c.thread and not night:muted(c) then
            for _, p in ipairs(night.players) do
                if p.key == c.thread then
                    return p
                end
            end
        end
    end
    -- The one you just turned to ("What are you doing while this happens?") walks up.
    local owed = night.take_owed and night:take_owed("cards")
    if owed then
        return owed
    end
    -- Whoever likes talking to people, the ones short on the spotlight tonight first: the same
    -- player doing every voice is how one player ends up running the show.
    local list, weights = {}, {}
    for _, p in ipairs(night.players) do
        local like = 0.4 + score.arch(p, "method_actor") * 1.2 + score.arch(p, "storyteller") + score.arch(p, "instigator") * 0.5
            + score.arch(p, "casual") * 0.3
        local short = math.max(0.2, (110 - (p.m and p.m.spotlight or 50)) / 60)
        table.insert(list, p)
        table.insert(weights, like * short * short)
    end
    if #list == 0 then
        return nil
    end
    return night.rng:weighted(list, weights)
end

-- What the party calls them now: their own name once they've given it (playtest, October 13:
-- "the hooded stranger" after she'd said she was Wren).
local function talk_name(night, info)
    local c = info.cast
    if c.named and night:cast_label(c) == c.named then
        return string.match(c.named, "^([^,]+)") or c.named
    end
    return info.name
end

-- One turn: three lines, the DM picks one. Returns the stance picked.
local function turn(night, step, info)
    local trigger = step == 1 and "talk_open" or "talk_ask"
    local vars = { char = info.p.char }
    local card = { id = "talk_" .. info.id .. "_" .. step, type = "talk", cast = info.cast.id, options = {} }
    local name = talk_name(night, info)
    if step == 1 then
        card.title = "Talk as " .. name
        card.text = info.p.char .. " walks up to " .. name .. ". " .. info.feel
            .. (info.knows and " They know something the party needs." or "")
            .. " You speak for them: what are their first words?"
    else
        card.title = info.p.char .. " asks"
        -- A goal card's name is an instruction ("Find old Dunnet"), not a topic: say it as the goal.
        card.text = info.p.char .. " asks " .. name .. " what they know"
            .. (info.goal and (", for the party's goal: " .. util.lower_first(info.goal) .. ". ") or " about what's going on. ")
            .. (info.knows and "Warm, and they point the party the right way: the scene's final roll gets easier. Guarded keeps it "
                .. "back for now. A lie sends them the wrong way, unless someone sees through it."
                or "Warm, and they open up. Guarded keeps their secrets. A lie might get caught.")
    end
    local fits = info.fits
    for i, stance in ipairs(M.STANCES) do
        local text, l = line_for(night, trigger, info.speaker, stance, vars)
        text = text or data.FALLBACK[trigger][stance]
        local effects = {}
        for _, e in ipairs(data.EFFECTS[trigger][stance]) do
            table.insert(effects, e)
        end
        if stance == fits then
            for _, e in ipairs(data.IN_CHARACTER) do
                table.insert(effects, e)
            end
        end
        card.options[i] = { label = M.STANCE_NAME[stance] .. (stance == fits and " (in character)" or "") .. ': "' .. text .. '"',
                            effects = effects, stance = stance, said = text, line = l }
    end
    local o = night:decision(card)
    o = o or card.options[1]
    if o.line then
        night.talk:remember(o.line.id)
    end
    night:emit({ kind = "npc", name = night:cast_label(info.cast), cast = info.cast.id, text = o.said, line = o.line and o.line.id, voiced = true })
    return o.stance
end

-- The hero answers, in character.
local function reply(night, p, mood)
    local text, l = night.talk:line("talk_reply", p, { split = mood, must = true })
    if text then
        night:emit({ kind = "say", who = p.key, text = text, ic = true, line = l and l.id })
    end
end

-- Did anyone see through the lie? The best Insight at the table against the liar's Deception.
local function insight(night, sc, cast)
    local p = night:pick_roller({ "insight" }, sc) or night.actor
    local mod = night:mod_for(p, "insight")
    local dc = data.LIE_DC + (cast.villain and 2 or 0) + util.clamp((sc.difficulty or 2) - 2, -1, 2)
    local roll = night.rng:d20()
    local total = roll + mod
    local ok = total >= dc
    local name = skills.name("insight")
    night:emit({ kind = "check", text = p.char .. ": " .. name .. " " .. util.int(roll) .. skills.signed(mod) .. " = "
                     .. util.int(total) .. " vs DC " .. util.int(dc) .. ", " .. (ok and "sees through it" or "believes it"),
                 roll = roll, bonus = mod, total = total, dc = dc, success = ok, actor = p.key, char = p.char,
                 skill = "insight", skill_name = name, crit = roll == 20, fumble = roll == 1 })
    return ok, p
end

-- The whole conversation. Returns true when it played (the scene's card and the usual chat are
-- then skipped: it stands in for them).
function M.talk(night, sc)
    local cast = night:shown_cast(sc)
    if not cast then
        return false
    end
    local campaign = night.campaign
    local pid = ledger.person_of(cast)
    -- A villain doesn't chat: they remember (the monologue, game/model/villains.lua).
    local villains = require "game.model.villains"
    local vp = villains.present(night, sc)
    if vp then
        night.took_talk = true
        sc.card_done = true
        sc.talked = true
        return villains.monologue(night, sc, cast, vp)
    end
    local p = talker(night, sc, cast)
    if not p then
        return false
    end
    night.took_talk = true
    sc.card_done = true
    sc.talked = true
    night.actor, night.other = p, nil
    local att = pid and ledger.att(campaign, pid, night) or 0
    local feel = pid and (util.capitalize(cast.short or cast.name) .. " is " .. string.lower(ledger.label(att)) .. " toward the party.")
        or (cast.villain and "They're no friend of the party." or "They don't know the party yet.")
    local goal = sc.comps.goal and not night:muted(sc.comps.goal) and sc.comps.goal
    local info = {
        id = pid or cast.id, cast = cast, p = p, name = cast.short or cast.name, speaker = M.speaker(night.talk.lib, cast),
        feel = feel, knows = sc.goal_clue ~= nil, fits = M.in_character(cast, att),
        about = goal and util.lower_first(goal.short or goal.name) or "what's going on",
        goal = goal and goal.name or nil,
    }
    -- The hero opens, the DM answers as them, twice.
    night:bark(p, "npc_talk")
    local first = turn(night, 1, info)
    if first == "warm" then
        reply(night, p, "warm")
    end
    local second = turn(night, 2, info)
    -- One card's worth: the second turn doesn't count as another decision.
    night.counts.decision = night.counts.decision - 1
    if night.decisions[#night.decisions] and night.decisions[#night.decisions].card == "talk_" .. info.id .. "_2" then
        table.remove(night.decisions)
    end
    local entry = { who = p.key, to = pid or cast.id, voiced = true }
    if second == "warm" then
        reply(night, p, "warm")
        entry.did, entry.d = "talk_warm", (first == "lie" and 0 or 1)
        sc.talked_warm = true                -- (nobody "catches them in a lie" after this)
        if sc.goal_clue then
            -- They point the way; the scene's final roll finds it, as the lore screen said (the card-led
            -- playtest, October 16: the map went into the notes before a single roll, then was found
            -- again at the end).
            sc.warm_lead = util.capitalize(info.name)
            night:say(util.capitalize(info.name) .. " tells " .. p.char .. " where to look. The scene's final roll will be easier.",
                "good")
            night:progress_event(sc)     -- the top bar says so at once
        end
        night:highlight(6, util.capitalize(info.name) .. " told " .. p.char .. " the truth", { p }, "talk")
    elseif second == "guarded" then
        reply(night, p, "guarded")
        entry.did, entry.d = "talk_guarded", 0
    else
        local caught, by = insight(night, sc, cast)
        if caught then
            reply(night, by, "lie_caught")
            night:apply(data.CAUGHT)
            score.add(by, "investment", 1)
            entry.did, entry.d = "talk_caught", -1
            night:react({ [by.key] = "lean" })
            night:highlight(7, by.char .. " caught " .. info.name .. " in a lie", { by }, "talk")
        else
            reply(night, p, "lie_believed")
            night:apply(data.BELIEVED)
            entry.did, entry.d = "talk_lie", 0
            -- What they knew stays hidden tonight; it's still out there.
            if sc.goal_clue then
                sc.goal_clue = nil
                entry.hid = true
            end
            table.insert(night.canon, util.capitalize(info.name) .. " lied to " .. p.char .. ", and got away with it")
        end
    end
    -- The person's last word, when the talk went their way.
    if (second == "warm" or entry.did == "talk_caught") and night.rng:chance(0.6) then
        night:npc_line(second == "warm" and "good" or "bad")
    end
    entry.stances = { first, second }
    night:note(sc, entry)
    night.took_talk_with = { pid = pid, cast = cast.id, first = first, second = second, did = entry.did }
    return true
end

-- Run the boss's turn ----------------------------------------------------------------------------

local function player_of(night, c)
    if not c or c.side ~= "party" then
        return nil
    end
    for _, p in ipairs(night.players) do
        if p.key == c.mini then
            return p
        end
    end
    return nil
end

local function attack_words(c)
    local a = c.attacks and c.attacks[1]
    local n = c.multiattack and c.multiattack.count or 1
    if not a then
        return ""
    end
    return " with its " .. string.lower(a.name) .. (n > 1 and (", " .. util.int(n) .. " attacks") or "")
end

-- Will this fight's boss turn be the DM's? Decided as the fight starts, so it can stand in for
-- the fight's card.
function M.plan_boss(night, sc)
    if night.took_boss or night.no_takeover or sc.talked or not night:room(13) then
        return false         -- one takeover a fight: a word before it, or the boss's turn in it
    end
    return night.rng:chance(data.BOSS_FIRST_CHANCE)
end

-- The boss's key round: its first turn when planned, or (rarely, with room) the first turn it
-- takes with a hero down. The DM picks who it goes for, or a speech; the rules engine resolves
-- the turn as usual.
function M.boss_turn(night, f, b, c)
    if night.took_boss or night.no_takeover or f.used.boss_turn then
        return
    end
    local planned = night.scene and night.scene.boss_turn_planned
    f.boss_acted = true
    local downed, weakest, threat
    local standing = {}
    for _, e in ipairs(b.creatures) do
        if e.side == "party" and not e.dead and not e.removed then
            if e.down then
                downed = downed or e
            else
                table.insert(standing, e)
                local fe, fw = e.hp / e.hp_max, weakest and weakest.hp / weakest.hp_max
                if not weakest or fe < fw or (fe == fw and e.hp < weakest.hp) then
                    weakest = e
                end
            end
        end
    end
    if #standing == 0 then
        return
    end
    if not planned and not (downed and night:room(12)) then
        return
    end
    if (f.cards or 0) >= (f.max_cards or 3) then
        return
    end
    -- The biggest threat: whoever has hurt it most, else the hardest hitter on its feet.
    local hurt = f.hurt_by or {}
    for _, e in ipairs(standing) do
        if not threat or (hurt[e] or 0) > (hurt[threat] or 0) or ((hurt[e] or 0) == (hurt[threat] or 0) and e.hp_max > threat.hp_max) then
            threat = e
        end
    end
    night.took_boss = true
    f.used.boss_turn = true
    f.used.tactics = true            -- it stands in for the tactics card
    f.cards = (f.cards or 0) + 1
    night:flush_turn()
    local boss = f.boss_name or c.name
    local cruel = downed or weakest
    local cruel_p = player_of(night, cruel)
    local threat_p = player_of(night, threat)
    local piled = cruel_p and M.piled(night.campaign, cruel_p.key) or 0
    local opts = {}
    -- Say only what's true (playtest, October 13: "who's been hurting it most" before anyone had
    -- touched it, and "barely standing" at full hit points).
    local why_threat = (hurt[threat] or 0) > 0 and ", who's been hurting it most" or ", the biggest threat on their feet"
    table.insert(opts, { label = "Go for " .. threat.name .. why_threat .. attack_words(c) .. ".",
                         effects = data.BOSS.clever, target = threat, kind = "clever", who = threat_p })
    local frac = weakest and weakest.hp / math.max(1, weakest.hp_max) or 1
    local how_weak = (frac <= 0.34 and ", who's barely standing") or (frac < 1 and ", who's already hurt")
        or ", who has the fewest hit points"
    if threat ~= cruel then
        table.insert(opts, { label = downed and ("Stand over " .. downed.name .. " and strike while they're down.")
                                 or ("Go after " .. weakest.name .. how_weak .. "."),
                             effects = downed and data.BOSS.finish or data.BOSS.cruel, target = cruel, kind = "cruel", who = cruel_p })
    end
    table.insert(opts, { label = "Whoever's closest. No plan, just fury.", effects = data.BOSS.closest, kind = "closest" })
    table.insert(opts, { label = "Stop and gloat. " .. util.capitalize(boss) .. " has a speech ready.", effects = data.BOSS.gloat,
                         kind = "gloat" })
    -- turn_of: the turn order lights the boss while you decide (the newcomer playtest, October 16:
    -- it still lit whoever went before).
    local card = { id = "boss_turn", type = "boss", title = "The boss's turn", monster = c.monster_id, turn_of = c.mini,
                   text = util.capitalize(boss) .. "'s turn, and you're running it. " .. util.int(c.hp) .. " of "
                       .. util.int(c.hp_max) .. " hit points left." .. (downed and (" " .. downed.name .. " is down.") or "")
                       .. " Who does it go for?",
                   options = opts }
    -- How bad its turn could be (the newcomer playtest, October 16): one turn of its attacks
    -- when they hit, and who that could drop.
    local per = math.floor(require("game.model.matchup").round_damage(c.monster_id) + 0.5)
    local danger
    if per > 0 then
        local low = {}
        for _, e in ipairs(standing) do
            if e.hp <= per then
                table.insert(low, e.name .. " (" .. util.int(e.hp) .. " left)")
            end
        end
        local who
        if #low > 1 and #low == #standing then
            who = "That's enough to drop any of them."
        elseif #low > 0 then
            who = "Enough to drop " .. util.join_names(low) .. "."
        else
            who = "Nobody on their feet is that low yet."
        end
        danger = "One turn of its attacks does about " .. util.int(per) .. " damage when they all hit. " .. who
        if downed then
            danger = danger .. " A hit on " .. downed.name .. " while they're down counts as a failed death save."
        end
    end
    night.actor = threat_p or night.actor
    local o = night:decision(card, { boss = boss, danger = danger }) or opts[1]
    -- The one it goes for is in the middle of it: the spotlight, if they're short of it tonight.
    if o.who then
        local sum = 0
        for _, q in ipairs(night.players) do
            sum = sum + (q.m and q.m.spotlight or 0)
        end
        if o.who.m and o.who.m.spotlight < sum / math.max(1, #night.players) then
            score.add(o.who, "spotlight", 5)
        end
    end
    -- The table reacts.
    if o.kind == "clever" then
        c.dm_target = o.target
        if threat_p then
            score.add(threat_p, "challenge", 4)   -- the boss knows who's dangerous: a test, not a spotlight
        end
        M.react(night, "clever", { "tactician", "power_gamer" })
    elseif o.kind == "cruel" then
        c.dm_target = o.target
        c.dm_finish = o.target.down or nil
        if cruel_p then
            M.pile(night.campaign, cruel_p.key)
            if piled >= 1 then
                -- The same player, again: everyone notices.
                score.add(cruel_p, "fun", data.PILED_FUN)
                score.add(cruel_p, "trust", -2)
                for _, q in ipairs(night.players) do
                    if q ~= cruel_p then
                        score.add(q, "trust", -1)
                    end
                end
                local q = night:pick_actor({ "casual", "storyteller", "tactician" }, cruel_p)
                if q then
                    night:emit({ kind = "say", who = q.key, text = util.fill(night.rng:pick(data.PILED_LINES), { char = cruel.name }), ic = false })
                end
                night:event("unfair", { who = cruel_p.key, text = "The table noticed the monsters always going for " .. cruel_p.name .. ".", weight = 3 })
            else
                M.react(night, downed and "finish" or "cruel", { "butt_kicker", "tactician" }, cruel_p)
            end
        end
    elseif o.kind == "gloat" then
        c.dm_skip = true
        c.dm_skip_name = "Gloats"
        -- The speech the card promised, even from someone with no lines of their own (the second
        -- card-led playtest, October 17: "Chief Nettle: Gloats." and nothing else).
        if not night:npc_line("taunt") then
            local cast = night.scene and night.scene.comps.cast
            night:emit({ kind = "npc", name = cast and night:cast_label(cast) or util.capitalize(boss),
                         text = night.rng:pick(data.GLOAT_LINES) })
        end
        M.react(night, "gloat", { "storyteller", "method_actor" })
        if downed then
            local dp = player_of(night, downed)
            if dp then
                score.add(dp, "fun", 3)    -- a breather for whoever's making death saves
            end
        end
    else
        M.react(night, "closest", { "casual", "butt_kicker" })
    end
    night:event("boss_turn", { who = (o.who and o.who.key) or "party", kind = o.kind, weight = 3,
                               text = util.fill(data.BOSS_LOG[o.kind] or "{boss} took its turn.", { boss = util.capitalize(boss),
                                   char = o.target and o.target.name or "" }) })
end

-- Who the monsters have gone for, over the last few weeks.
function M.pile(campaign, key)
    campaign.piled = campaign.piled or {}
    campaign.piled[key] = campaign.piled[key] or {}
    table.insert(campaign.piled[key], campaign.week)
end

function M.piled(campaign, key)
    local n = 0
    for _, w in ipairs(campaign.piled and campaign.piled[key] or {}) do
        if (campaign.week or 0) - w <= data.PILE_WEEKS then
            n = n + 1
        end
    end
    return n
end

-- Someone at the table says what they think of the DM's call.
function M.react(night, kind, archetypes, about)
    local q = night:pick_actor(archetypes, nil)
    local lines = data.REACT[kind]
    if not (q and lines) then
        return
    end
    local text = util.fill(night.rng:pick(lines), { char = about and about.char or "" })
    night:emit({ kind = "say", who = q.key, text = text, ic = false })
end

return M
