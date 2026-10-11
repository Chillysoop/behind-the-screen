-- Death at the table (M8, B3). "The last death save" is the way in: fudge it (the existing
-- cooked roll), or let it ride, and then this flow: what happens next, filtered by what Session
-- Zero agreed and what each player asked for; the goodbye; a new character next week, or the way
-- back at a cost; and the shelf of fallen heroes. game/data/death.lua has the words and numbers.
-- Pure Lua.

local content = require "game.model.content"
local score = require "game.model.score"
local util = require "game.model.util"
local data = require "game.data.death"

local M = {}
M.data = data

-- The table's default, and this player's own setting if the DM honours their preference.
function M.table_mode(campaign)
    local r = campaign.table and campaign.table.rules
    return (r and r.death) or data.DEFAULT
end

function M.mode_for(campaign, key)
    local o = campaign.death_overrides and campaign.death_overrides[key]
    return o or M.table_mode(campaign)
end

-- Honour (or stop honouring) a player's own preference: from their character sheet.
function M.set_override(campaign, key, mode)
    campaign.death_overrides = campaign.death_overrides or {}
    campaign.death_overrides[key] = mode
end

function M.pref(key)
    return data.PREF[key]
end

-- The options for this death, by the mode that applies to them. Each: { label, outcome }.
--   goodbye   they're gone: last words and a wake, a new character next week
--   quick     gone, without the goodbye (a small cost)
--   scar      back now, with a scar in canon
--   quest     a way back, next week, through a quest
--   ask       the player decides (by who they are)
function M.options(campaign, p)
    local mode = M.mode_for(campaign, p.key)
    local opts = {}
    local function add(label, outcome)
        table.insert(opts, { label = label, outcome = outcome })
    end
    if mode == "permanent" or mode == "meaningful" then
        add("Say goodbye. {actor_char} gets last words, and the table holds a wake.", "goodbye")
        add("Move on quickly. A new character joins next week.", "quick")
    elseif mode == "cost" then
        add("Bring {actor_char} back, and it leaves a mark.", "scar")
        add("There's a way back: a quest, next week.", "quest")
        add("Let {actor_char} go. Say goodbye.", "goodbye")
    else
        add("Ask {actor}. It's their call.", "ask")
        add("Say goodbye. {actor_char} gets last words, and the table holds a wake.", "goodbye")
    end
    return opts, mode
end

-- What a player picks when it's their call.
function M.player_choice(p)
    local a = p.primary
    if a == "method_actor" or a == "storyteller" then
        return "goodbye"
    elseif a == "casual" or a == "instigator" then
        return "scar"
    end
    return "quest"
end

-- Did this outcome honour what they wanted? 1 yes, -1 no, 0 neither.
local function honoured(pref, outcome, asked)
    if asked then
        return 1
    end
    local gone = outcome == "goodbye" or outcome == "quick"
    if pref == "permanent" then
        return gone and 1 or -1
    elseif pref == "meaningful" then
        return outcome == "goodbye" and 1 or (outcome == "quick" and -1 or 0)
    elseif pref == "cost" then
        return gone and -1 or 1
    elseif pref == "choice" then
        return -1      -- they wanted a say and didn't get one
    end
    return 0
end

-- A hero has died on game night. Deals the card, plays what follows, and records it.
function M.on_death(night, p, c, sc)
    local campaign = night.campaign
    local opts, mode = M.options(campaign, p)
    local card = { id = "hero_dies", type = "screen", title = p.char .. " is dead",
                   text = "By the rules and the dice, {actor_char} is dead. Session Zero said: "
                       .. string.lower(data.MODE[mode].name) .. ". {actor} is waiting to see what you do.",
                   options = {} }
    for i, o in ipairs(opts) do
        card.options[i] = { label = o.label, log = nil, effects = {}, outcome = o.outcome }
    end
    night.actor = p
    local o = night:decision(card)
    -- The last death save and what follows are one moment at the table: one decision.
    if night.last_save_for == p.key then
        night.counts.decision = night.counts.decision - 1
        night.last_save_for = nil
    end
    local outcome = o and o.outcome or opts[1].outcome
    local asked = outcome == "ask"
    if asked then
        outcome = M.player_choice(p)
        night:emit({ kind = "say", who = p.key, text = outcome == "goodbye" and "Let them go. It's a good ending."
            or (outcome == "scar" and "Bring them back. I don't care what it costs." or "Is there a way back? I want to earn it."), ic = false })
    end
    local h = honoured(M.pref(p.key), outcome, asked)
    local fair = h >= 0 and outcome ~= "quick"           -- a death the villain can be taunted about
    score.add(p, "trust", h > 0 and data.HONOURED or (h < 0 and data.IGNORED or 0))
    if h < 0 then
        score.add(p, "fun", -6)
    end
    campaign.deaths = campaign.deaths or {}
    local rec = { key = p.key, char = p.char, class = p.class, level = campaign.level or 2, week = campaign.week,
                  slain_by = night.villain_here, at = sc and sc.comps.location and sc.comps.location.id,
                  how = "fell at " .. ((sc and sc.comps.location and (sc.comps.location.short or util.lower_first(sc.comps.location.name))) or "the table")
                      .. ((night.battle_boss_name and (" to " .. night.battle_boss_name)) or ""),
                  outcome = outcome, mini = p.mini or nil }
    rec.rep = require("game.model.fails").reputation(campaign, p.key)
    rec.fair = fair
    table.insert(campaign.deaths, rec)
    night:event("death", { who = p.key, text = p.char .. " died. " .. util.capitalize(rec.how) .. ".", weight = 10 })
    if outcome == "goodbye" or outcome == "quick" then
        M.fall(night, p, rec, outcome == "goodbye")
    elseif outcome == "scar" then
        local scar = util.fill(data.SCARS[night.rng:int(1, #data.SCARS)], { char = p.char })
        p.scar = scar
        table.insert(night.canon, scar)
        night:say(scar, "narration")
        night:highlight(9, p.char .. " came back", { p }, "back")
        rec.back = campaign.week
    elseif outcome == "quest" then
        campaign.death_quest = campaign.death_quest or {}
        campaign.death_quest[p.key] = { week = campaign.week, char = p.char }
        night:say(util.fill(data.QUEST.line, { char = p.char }), "narration")
    end
    return outcome
end

-- They're gone: the goodbye (or not), the shelf, and a new character next week.
function M.fall(night, p, rec, goodbye)
    local campaign = night.campaign
    if goodbye then
        local lines = data.LAST_WORDS[p.class] or data.LAST_WORDS.fighter
        night:emit({ kind = "say", who = p.key, text = lines[night.rng:int(1, #lines)], ic = true })
        night:say(util.fill(data.WAKE, { char = p.char }), "narration")
        score.add(p, "spotlight", data.GOODBYE.spotlight)
        score.add(p, "story", data.GOODBYE.story)
        for _, q in ipairs(night.players) do
            score.add(q, "social", data.GOODBYE.social)
            score.add(q, "story", 4)
        end
        local poses = {}
        for _, q in ipairs(night.players) do
            poses[q.key] = "gasp"
        end
        night:react(poses)
        night:highlight(10, p.char .. "'s last words", { p }, "goodbye")
    else
        score.add(p, "fun", data.GOODBYE.skip_fun)
    end
    campaign.fallen = campaign.fallen or {}
    table.insert(campaign.fallen, rec)
    campaign.new_char = campaign.new_char or {}
    campaign.new_char[p.key] = { week = campaign.week, was = p.char }
    table.insert(night.canon, p.char .. " " .. rec.how)
end

-- A fudged last save. The second and later ones cost Trust with the players who came for stakes.
function M.fudged(night)
    local campaign = night.campaign
    campaign.death_fudges = (campaign.death_fudges or 0) + 1
    if campaign.death_fudges >= 2 then
        night:apply({ { "arch:tactician", trust = data.FUDGE_STAKES }, { "arch:butt_kicker", trust = data.FUDGE_STAKES },
                      { "arch:power_gamer", trust = data.FUDGE_STAKES } })
        local q = night:pick_actor(data.STAKES)
        if q then
            night:emit({ kind = "say", who = q.key, text = "Does anyone actually die in this game?", ic = false })
        end
    end
end

-- The start of a week: whoever fell rolls up a new character (the next pregen of their class),
-- and a way back that went unused closes.
function M.start_week(campaign)
    local out = {}
    for key, nc in pairs(campaign.new_char or {}) do
        local p = campaign:player(key)
        if p and not nc.done then
            local used = campaign.pregens_used or {}
            campaign.pregens_used = used
            local pick
            for _, g in ipairs(data.PREGENS[p.class] or {}) do
                if not pick and not used[g.id] then
                    pick = g
                end
            end
            pick = pick or (data.PREGENS[p.class] or data.PREGENS.fighter)[1]
            used[pick.id] = true
            -- The fallen hero's sheet goes on the shelf; the new character starts fresh.
            if campaign.party_state and campaign.party_state.pcs then
                campaign.party_state.pcs[key] = nil
            end
            p.old_char = p.char
            p.char = pick.name
            p.pregen = pick.id
            p.mini = pick.mini
            p.hook = pick.hook
            nc.done = true
            nc.joins = campaign.week
            nc.pregen = pick.id
            table.insert(out, { key = key, pregen = pick, was = nc.was })
        end
    end
    return out
end

-- The night a new character joins: their introduction, a Spotlight spike and a warm-up.
function M.intro(night)
    local campaign = night.campaign
    for key, nc in pairs(campaign.new_char or {}) do
        if nc.joins and nc.joins <= campaign.week and not nc.introduced then
            local p = night.campaign:player(key)
            local g
            for _, x in ipairs(data.PREGENS[p.class] or {}) do
                if x.id == nc.pregen then
                    g = x
                end
            end
            if p and g and p.present then
                nc.introduced = true
                night:say(util.fill(data.INTRO[g.intro] or data.INTRO.hired, { new = p.char, old = nc.was }), "opening")
                score.add(p, "spotlight", data.INTRO_SPOTLIGHT)
                score.add(p, "fun", 4)
                night:react({ [p.key] = "lean" })
                night:event("new_character", { who = p.key, text = p.char .. " joins the party, in " .. nc.was .. "'s place.", weight = 7 })
            end
        end
    end
end

-- A way back (the quest): the scene with "The way back" decides it. win: back with a scar.
function M.quest_card(campaign, key)
    local q = campaign.death_quest and campaign.death_quest[key]
    if not q or q.card then
        return nil
    end
    local p = campaign:player(key)
    local c = content.register({
        runtime = true, id = "way_back_" .. key .. "_" .. util.int(campaign.week), kind = "goal",
        name = data.QUEST.name .. " (" .. q.char .. ")", cost = 1, difficulty = 2,
        fits = { "exploration", "puzzle", "set_piece", "mystery" }, tags = { "heart", "danger" },
        meters = { story = 6, challenge = 4 },
        line = util.fill(data.QUEST.line, { char = q.char }),
        win = util.fill(data.QUEST.win, { char = q.char }), lose = util.fill(data.QUEST.lose, { char = q.char }),
        thread = key, way_back = key,
    })
    campaign.registered = campaign.registered or {}
    table.insert(campaign.registered, c)
    q.card = c.id
    return c, p
end

-- After the night: a way-back scene that played brings them back, or closes the door.
function M.after_night(campaign, night)
    for key, q in pairs(campaign.death_quest or {}) do
        if q.card and not q.done then
            for _, sc in ipairs(night.scenes or {}) do
                if sc.comps.goal and sc.comps.goal.id == q.card and sc.outcome then
                    q.done = true
                    local p = campaign:player(key)
                    if sc.outcome == "win" then
                        p.scar = util.fill(data.SCARS[1], { char = q.char })
                    else
                        local rec = { key = key, char = q.char, class = p.class, level = campaign.level or 2, week = campaign.week,
                                      how = "never came back from the dark", outcome = "lost" }
                        campaign.fallen = campaign.fallen or {}
                        table.insert(campaign.fallen, rec)
                        campaign.new_char = campaign.new_char or {}
                        campaign.new_char[key] = { week = campaign.week, was = q.char }
                    end
                end
            end
        end
    end
end

return M
