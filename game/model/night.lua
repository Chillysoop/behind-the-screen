-- Game night: the director. Plays the three prepped scenes as a stream of beats
-- for the table (scenery, minis, speech bubbles, dice), runs fights on the M3
-- rules engine, and pauses for the DM: decision cards of six kinds, improv hands,
-- big rolls in front of or behind the screen, and rulings on how they land. Pure Lua.
--
-- The screen calls night:advance(answer) and gets the next beat back. Every beat
-- carries t, its playing time in seconds at normal speed (game/model/pacing.lua).
--   scene      { index, total, title, type, type_name, terrain, party, npc, cast, goal, story }
--   narrate    { text, style }                            a caption (narration, goal, twist...)
--   npc        { name, text, cast, line }                 the DM voicing a character
--   say        { who, text, ic, line, part }              a speech bubble over a player (line: its id in
--                                                         the dialogue library; part "reply" for banter replies)
--   react      { poses = { key = pose } }                 players lean in, cheer, gasp...
--   check      { actor, char, skill, skill_name, roll, bonus, total, dc, success, crit, fumble, text }
--                the player rolls d20 + their modifier for the skill against the DC
--   clue       { text, id }                                  the party learns something (DM's notes)
--   battle     { phase = "start", party, foes, terrain, danger } / { phase = "end", winner }
--   round      { round }
--   turn       { who, side, steps = { move, attack, damage, down, ... }, say, brisk }
--   decision   { card = { id, type, type_name, title, text, options } }    answer = option index
--   improv     { prompt, cards, pick = { 1, 3 }, slot, drift }            answer = { indices } or index
--   roll_where { text, dc, actor, char, skill_name, mod, by }            answer = "open" | "hidden"
--                by = "player": the player rolls their own check; "open" says the DC out loud,
--                "hidden" keeps it behind the screen. by = "dm": a secret check the DM rolls for
--                them, in the open or behind the screen.
--   roll       { where, dc, actor, by }                                  answer = the d20 value
--   cook       { value, total, mod, dc, success, by }                    answer = true to cook it
--                (a player's roll: move the secret DC; the DM's own roll: misreport the die)
--   ruling     { tier, prompt, value, total, mod, dc, options }          answer = option index
--   done       {}
-- Unanswered questions (nil) take a sensible default, so a headless run never stalls.

local content = require "game.model.content"
local score = require "game.model.score"
local prep_mod = require "game.model.prep"
local util = require "game.model.util"
local talk_mod = require "game.model.talk"
local pacing = require "game.model.pacing"
local fight = require "game.model.fight"
local social = require "game.model.social"
local seeds = require "game.model.seeds"
local story = require "game.model.story"
local ledger = require "game.model.ledger"
local places = require "game.model.places"
local rest_rules = require "game.rules.rest"
local rapport = require "game.model.rapport"
local rests = require "game.data.rests"
local deck = require "game.model.deck"
local fails_mod = require "game.model.fails"
local death_mod = require "game.model.death"
local takeover = require "game.model.takeover"
local maps = require "game.model.maps"
local villains = require "game.model.villains"
local intros = require "game.model.intros"
local dice_sets = require "game.model.dice_sets"
local recap_mod = require "game.model.recap"
local board_mod = require "game.model.board"

-- Skills for talking to someone: a hero who uses one walks over to the person (A9).
local SOCIAL_SKILL = { persuasion = true, deception = true, intimidation = true, insight = true, performance = true }
local skills = require "game.rules.skills"

local M = {}
M.__index = M

local CHECKS_PER_SCENE = 4
local HAND_SIZE = 5
local LATE_AFTER = 15.5 * 60      -- seconds of watching before "It's getting late" comes up anyway

-- "The old bridge" -> "the old bridge", but leave names like "Ilsa's ring" alone.
local function find_present(players, key)
    for _, p in ipairs(players) do
        if p.key == key then
            return p
        end
    end
end

local function soft_lower(text)
    for _, w in ipairs({ "A ", "An ", "The ", "Fresh " }) do
        if string.sub(text, 1, #w) == w then
            return string.lower(string.sub(text, 1, 1)) .. string.sub(text, 2)
        end
    end
    return text
end

-- Snapshot long-term bars so the report can show changes.
local function snapshot(players)
    local s = {}
    for _, p in ipairs(players) do
        s[p.key] = {}
        for _, k in ipairs(score.LONG) do
            s[p.key][k] = p[k]
        end
    end
    return s
end

function M.new(campaign, prep, opts)
    opts = opts or {}
    local self = setmetatable({}, M)
    self.campaign = campaign
    self.rng = campaign.rng
    self.prep = prep
    self.players = campaign:present()
    self.before = snapshot(campaign.players)
    self.highlights = {}
    self.canon = {}
    self.decisions = {}
    self.rulings = {}
    self.rolls = { open = 0, hidden = 0, cooked = 0 }
    self.callouts = 0
    self.cooks = 0
    self.used_cards = {}
    self.table_card_used = false
    self.drift_used = false
    -- The first weeks after a change of course (A18).
    require("game.model.styles").night_start(campaign, self.players)
    -- Where the party left off (A16): fights since their last Long Rest carry over.
    do
        local ps = campaign.party_state
        self.fights_since_long = (ps and not ps.rested and ps.fights_since_long) or 0
    end
    -- The table clock (A14): starts at seven; Session Zero said how long you play.
    self.table_min, self.table_start = 0, 19 * 60
    do
        local tbl = campaign.table
        local len = tbl and tbl.rules and tbl.rules.length
        local opt = len and content.session_zero.rules.length[len]
        self.table_planned = ((opt and opt.hours) or 3.5) * 60
    end
    self.checks = {}
    self.behaviors = {}      -- table behaviors tonight, by id (A12)
    self.unused = prep:unused()
    self.improvised = {}
    self.talk = talk_mod.new(self.rng)
    self.talk:set_present(self.players)
    self.talk:remember_weeks(campaign, 3)   -- a speaker doesn't repeat a line for three weeks (A5)
    self.clock = 0
    self.counts = { decision = 0, improv = 0, ruling = 0 }
    self.fights = 0
    -- "Every roll in the open" at Session Zero covers the DM's own combat rolls too.
    local open_table = campaign.table and campaign.table.rules.dice == "open"
    self.dm_rolls = opts.dm_rolls or campaign.dm_rolls or (open_table and "open") or "hidden"
    self.hidden_dm_rolls, self.open_dm_rolls = 0, 0
    self.lucky_streak = 0
    -- M6: the table conflicts, Session Zero promises, seeds.
    self.conflict_moves = {}   -- { id, pressure, progress, resolve, promise, topic } from conflict cards
    self.rules_calls = {}      -- { card, leans, topic } for every rules card
    self.conflict_dealt = {}   -- conflict id -> true once its card came up tonight
    self.safety = {}           -- what happened with lines and veils tonight
    self.planted = prep.planted
    self.payoffs = {}          -- seeds paid off tonight
    self.promise_noted = {}
    for _, p in ipairs(self.players) do
        score.reset_session(p)
    end
    -- Build the scenes from the board.
    self.scenes = {}
    for i, s in ipairs(prep.scenes) do
        local comps = {}
        for k, c in pairs(s.slots) do
            comps[k] = c
        end
        local missing = {}
        for _, kind in ipairs(prep_mod.IMPROV_ORDER) do
            if not comps[kind] then
                table.insert(missing, kind)
            end
        end
        self.scenes[i] = {
            index = i,
            type = s.type,
            comps = comps,
            missing = missing,
            quality = prep_mod.quality(s.type, comps, prep.inspired),
            difficulty = prep_mod.difficulty(comps),
            encounter = s.encounter,   -- the fight the DM built in prep (combat and set pieces)
            module = s.module and s.module.id,                       -- a published adventure (A13)
            hazard = s.hazard,                                       -- a hazard on the mat (A10)
            module_custom = s.module and next(s.module.swaps) ~= nil or nil,
            open = s.open,             -- the players choose where (A15)
            spots = s.open and util.copy(s.spots or {}) or nil,
        }
    end
    -- Cards on tonight's board: improv draws from the rest of the story deck.
    self.on_board = {}
    for _, s in ipairs(prep.scenes) do
        for _, c in pairs(s.slots) do
            self.on_board[c.id] = true
        end
    end
    self.revealed = {}        -- story cards that told their part tonight (deck.lua remembers)
    self.ledger = {}          -- the notebook's entries tonight (ledger.lua files them after the night)
    self.pacing = prep_mod.pacing(prep.scenes, self.players)
    self.co = coroutine.create(function()
        self:run()
    end)
    return self
end

function M:advance(answer)
    if coroutine.status(self.co) == "dead" then
        return { kind = "done", t = 0 }
    end
    local ok, ev = coroutine.resume(self.co, answer)
    if not ok then
        error(ev)
    end
    return ev or { kind = "done", t = 0 }
end

-- The DM can flip where their own combat rolls land at any time.
function M:set_dm_rolls(mode)
    self.dm_rolls = (mode == "open") and "open" or "hidden"
    self.campaign.dm_rolls = self.dm_rolls
end

-- Every beat goes out through here: timed, counted, and yielded to the screen.
-- The table clock (A14): minutes of real table time, apart from the screen's playback time.
-- Only what happens moves it: a fight's rounds, each check and call, a lookup, a break.
M.TABLE_MIN = { scene = 7, narrate = 0.45, npc = 0.7, say = 0.2, check = 4.5, decision = 4, improv = 3.5, ruling = 2.5,
                roll_where = 1.5, cook = 1, turn = 1.0, clue = 0.6, round = 0.6, dice = 1, intro = 0.5 }

function M:emit(ev)
    if self.board_id then
        self:board_hear(ev)
    end
    if ev.kind == "say" and ev.ic then
        require("game.model.awards").heard(self, ev)   -- in character, toward the table awards
    end
    ev.t = pacing.duration(ev)
    self.clock = self.clock + ev.t
    -- The table clock moves with the session being played, never while a choice waits for you:
    -- a call's minutes are the table playing it out, so they land once you've made it.
    local minutes = (M.TABLE_MIN[ev.kind] or 0) + (ev.table_min or 0)
    local prompt = pacing.DECISION_KINDS[ev.kind] or ev.kind == "roll_where"
    if not prompt then
        self.table_min = (self.table_min or 0) + minutes
    end
    if pacing.DECISION_KINDS[ev.kind] then
        self.counts[ev.kind] = self.counts[ev.kind] + 1
    end
    if prompt then
        self.last_input = self.clock
    end
    local answer = coroutine.yield(ev)
    if prompt then
        self.table_min = (self.table_min or 0) + minutes
    end
    return answer
end

-- Seconds since the DM last had a choice to make.
function M:idle()
    return self.clock - (self.last_input or 0)
end

function M:decision_count()
    return self.counts.decision + self.counts.improv + self.counts.ruling
end

-- Room for one more optional call under this cap? Before the last scene, two calls are kept
-- back for it: a last scene with nothing for the DM to decide runs long.
function M:room(cap)
    local last = self.scenes[#self.scenes]
    local reserve = (last and self.scene ~= last) and 2 or 0
    return self:decision_count() < cap - reserve
end

-- The board (the story-matched table) --------------------------------------------
-- The place goes down with its floor and walls; every other piece drops in when the DM's words
-- name it (game/model/board.lua), and the scene's person appears when they're named or speak.

-- Narration styles that don't set the scene (asides, dice, the system's own lines).
local NOT_SCENERY = { aside = true, system = true, dice = true, warn = true, recap = true, check = true, reaction = true,
                      thread = true, scene = true, good = true, bad = true, dm = true }

function M:board_set(id, sc)
    -- The same place again (two scenes there tonight): what's on the table stays on it.
    if id ~= self.board_id or not self.board_shown then
        self.board_id = id
        self.board_shown = {}
        for _, fid in ipairs(board_mod.base_ids(id)) do
            self.board_shown[fid] = true
        end
    end
    local cast = sc and sc.comps.cast
    self.npc_words = cast and board_mod.person_words(cast) or nil
    self.npc_pending = nil
end

-- What this event puts on the table.
function M:board_hear(ev)
    local k = ev.kind
    if ev.reveal then
        for _, r in ipairs(ev.reveal) do
            self.board_shown[r.id] = true
        end
    elseif (k == "narrate" and not NOT_SCENERY[ev.style or ""]) or k == "npc" then
        local hits = board_mod.mentioned(self.board_id, ev.text, self.board_shown)
        if #hits > 0 then
            ev.reveal = hits
            for _, h in ipairs(hits) do
                self.board_shown[h.id] = true
            end
        end
    elseif (pacing.DECISION_KINDS[k] and k ~= "improv") or k == "roll_where" or k == "check" or k == "battle" then
        -- Play has started: anything the DM hasn't set out goes down now. (An improv card is the
        -- DM still making the place up, so it waits for the words.)
        local rest = board_mod.hidden(self.board_id, self.board_shown)
        if #rest > 0 then
            ev.reveal = {}
            for _, f in ipairs(rest) do
                self.board_shown[f.id] = true
                table.insert(ev.reveal, { id = f.id, at = 0 })
            end
            self.board_late = (self.board_late or 0) + #rest
        end
    end
    if self.npc_pending and (k == "npc" or self.npc_cue or (k == "narrate" and board_mod.names(self.npc_words, ev.text))
        or (pacing.DECISION_KINDS[k] and k ~= "improv") or k == "check") then
        ev.npc_show = true
        self.npc_pending = nil
    end
end

-- The DM sets out the rest of the place in a line, so every piece comes in on a word.
function M:dress_board()
    if not self.board_id then
        return
    end
    local text, list = board_mod.dressing(self.board_id, self.board_shown, 5)
    if text then
        self:emit({ kind = "narrate", text = text, style = "narration", reveal = list, dressing = true })
    end
end

-- Helpers ---------------------------------------------------------------------

function M:vars(extra)
    local v = {}
    if self.actor then
        v.actor, v.actor_char = self.actor.name, self.actor.char
    end
    if self.other then
        v.other, v.other_char, v.other_key = self.other.name, self.other.char, self.other.key
    end
    local low = self:lowest()
    if low then
        v.lowest, v.lowest_char = low.name, low.char
    end
    v.time = self:clock_text()           -- the table clock, "10:05 pm"
    local sc = self.scene
    if sc then
        -- A card that was veiled or X-carded isn't named either.
        local function shown(c)
            return c and not self:muted(c) and c or nil
        end
        local cast = shown(sc.comps.cast)
        v.cast = cast and soft_lower(cast.short or cast.name) or "the locals"
        v.Cast = util.capitalize(v.cast)
        v.they_want = (cast and cast.group) and "they actually want"
            or ((cast and cast.pronoun == "he") and "he actually wants" or ((cast and cast.pronoun == "she") and "she actually wants"
            or "they actually want"))
        -- Who's behind it (a mystery's culprit, a traitor): someone in the scene, never a
        -- mentor's ghost; else whoever this week's story points at.
        local beat = self.campaign:arc_beat() or content.arc.beats[#content.arc.beats]
        local person = cast and not cast.revered and cast.talks ~= false
        local cul = beat and beat.culprit or {}
        v.culprit = person and soft_lower(cast.short or cast.name) or cul.name or "someone nobody suspected"
        v.Culprit = util.capitalize(v.culprit)
        v.secret = person and cast.secret or cul.secret or "they've been covering for someone"
        v.deal = cast and cast.deal or "safe passage, for now"
        local last = content.arc.beats[#content.arc.beats]
        v.lead = beat and beat.lead or (last and last.lead) or "Kessrick the Wolf"
        -- A group acts as a group (A3): {one|many} picks the verb.
        v.plural = cast and cast.group and true or false
        -- Who gets caught in a lie: the scene's person, or someone the place would have (A2).
        local loc = sc.comps.location
        local by = "a stallholder who saw too much"
        for _, set in ipairs(loc and loc.setting or {}) do
            local b = M.BYSTANDER[set]
            if b then
                by = b
                break
            end
        end
        v.witness = person and soft_lower(cast.short or cast.name) or by
        v.Witness = util.capitalize(v.witness)
        -- What the big moment turns up when no goal says (A2): the scene's reward, or the lead.
        local reward = shown(sc.comps.reward)
        v.found = reward and soft_lower(reward.got or reward.name) or ("a fresh trail, and a name: " .. v.lead)
        v.location = shown(sc.comps.location) and soft_lower(sc.comps.location.name) or "this place"
        v.goal = shown(sc.comps.goal) and soft_lower(sc.comps.goal.name) or "what they came for"
        v.boss = sc.boss_name or "the villain"
        v.Boss = util.capitalize(v.boss)
    end
    for k, val in pairs(extra or {}) do
        v[k] = val
    end
    return v
end

-- Skill checks (real-session pass) ---------------------------------------------------------

-- A hero's modifier for a skill, from their character sheet at the party's level.
function M:mod_for(p, skill)
    local c = self.campaign
    local sub = c.subclasses and c.subclasses[p.class]
    -- Magic items: the Luckstone, the Gloves when there's climbing or swimming (A13).
    return skills.mod(p.class, skill, c.level or 2, sub)
        + require("game.model.items").check_bonus(c, p.key, skill, self.scene and self.scene.comps.location)
end

-- A hero's best skill from a list (or the one skill): skill, modifier.
function M:best_skill(p, list)
    if type(list) == "string" then
        return list, self:mod_for(p, list)
    end
    local best, bm
    for _, sk in ipairs(list or { "perception" }) do
        local m = self:mod_for(p, sk)
        if not bm or m > bm then
            best, bm = sk, m
        end
    end
    return best, bm
end

-- The location's settings, for "where" checks.
function M:location()
    local sc = self.scene
    return sc and sc.comps.location
end

-- Who's there to be caught in a lie, by the kind of place (A2: never "the witness" with
-- nobody there).
M.BYSTANDER = {
    tavern = "the barman", market = "a stallholder", shop = "the shopkeeper", crowd = "a gossip in the crowd",
    town = "a shopkeeper", road = "a carter on the road", forest = "a woodcutter", camp = "a camp follower",
    bells = "the bell-ringers' old porter", ruin = "a scavenger in the ruins", wild = "a shepherd",
    under = "a tunnel rat", indoor = "a servant", outdoor = "a passer-by", water = "a boatman",
}

-- A caption. Every sentence starts with a capital, whatever was substituted (A3).
function M:say(text, style, extra)
    return self:emit({ kind = "narrate", text = util.sentence_case(util.fill(text, self:vars(extra))),
                       style = style or "narration" })
end

-- A line from a list that hasn't been said tonight (A5): each one once before any repeats.
function M:fresh(list, key)
    if type(list) ~= "table" then
        return list
    end
    self.fresh_used = self.fresh_used or {}
    local used = self.fresh_used[key or tostring(list)] or {}
    self.fresh_used[key or tostring(list)] = used
    local free = {}
    for i, l in ipairs(list) do
        if not used[i] then
            table.insert(free, i)
        end
    end
    if #free == 0 then
        for i in pairs(used) do
            used[i] = nil
        end
        for i = 1, #list do
            free[i] = i
        end
    end
    local i = self.rng:pick(free)
    used[i] = true
    return list[i]
end

-- A speech bubble from a player, picked from the table talk for this trigger.
-- What the table calls a person now: a stranger who has given their name goes by it
-- ("A hooded stranger" becomes Wren once she lowers her hood).
function M:cast_label(cast)
    if cast.named and ((self.revealed and self.revealed[cast.id]) or story.has_clue(self.campaign, cast.id)) then
        return cast.named
    end
    return cast.name
end

function M:bark(p, trigger, extra)
    if not p then
        return
    end
    local v = self:vars(extra)
    local text, line = self.talk:line(trigger, p, v)
    if text then
        self:emit({ kind = "say", who = p.key, text = text, ic = talk_mod.in_character(trigger), line = line.id })
    end
    return text
end

-- The DM voicing the scene's cast.
function M:npc_line(what, extra)
    local sc = self.scene
    local cast = sc and sc.comps.cast
    if not cast then
        return
    end
    local text, line = self.talk:npc(cast.id, what, self:vars(extra))
    if text then
        self:emit({ kind = "npc", name = self:cast_label(cast), cast = cast.id, text = text, line = line.id })
    end
end

-- A published adventure's person says their lines from the book ({npc}: whoever plays them).
function M:module_line(sc, i)
    local m = sc.module and require("game.model.books").module(sc.module)
    local cast = sc.comps.cast
    local line = m and m.lines and m.lines[i]
    if not (line and cast) or self:muted(cast) then
        return
    end
    local who = cast.short or cast.name
    local text = util.capitalize(util.fill(line, { npc = who }))
    self:emit({ kind = "npc", name = self:cast_label(cast), cast = cast.id, text = text })
end

-- After a module scene: run straight from the book, the storyteller notices it didn't touch the
-- campaign; customized (their own reward, someone from the notebook), it did.
function M:module_verdict(sc)
    for _, p in ipairs(self.players) do
        if score.arch(p, "storyteller") >= 1 then
            if sc.module_custom then
                score.add(p, "investment", 1)
            else
                score.add(p, "investment", -1)
                if self:idle() < 120 then
                    self:emit({ kind = "say", who = p.key, text = "That was fun. Didn't really connect to anything, though." })
                end
            end
            break
        end
    end
end

function M:react(poses)
    if next(poses) then
        self:emit({ kind = "react", poses = poses })
    end
end

function M:lowest()
    local low
    for _, p in ipairs(self.players) do
        if not low or p.engagement < low.engagement then
            low = p
        end
    end
    return low
end

-- Pick a present player, preferring these archetypes (primary first).
-- Who rolls a big moment (A4): the thread owner in their own story scene first; otherwise the
-- best modifier among players at or below the table's average Spotlight, never a negative
-- modifier while someone good at it is here, and nobody past 40% of tonight's big rolls.
function M:pick_roller(skill_list, sc, prefer)
    local players = self.players
    self.big_rolls = self.big_rolls or {}
    local total = 0
    for _, n in pairs(self.big_rolls) do
        total = total + n
    end
    local function capped(p)
        return total >= 3 and (self.big_rolls[p.key] or 0) / total >= 0.4
    end
    -- Their story, their roll: once a scene.
    sc = sc or self.scene
    if sc then
        sc.owners_rolled = sc.owners_rolled or {}
        local kinds = {}
        for kind in pairs(sc.comps) do
            table.insert(kinds, kind)
        end
        table.sort(kinds)
        -- With two stories in one scene, whoever has rolled least tonight goes first.
        local pick_owner, fewest
        for _, kind in ipairs(kinds) do
            local c = sc.comps[kind]
            if c.thread and not self:muted(c) and not sc.owners_rolled[c.thread] then
                local owner = find_present(players, c.thread)
                if owner and not capped(owner) then
                    local _, m = self:best_skill(owner, skill_list)
                    local n = self.big_rolls[owner.key] or 0
                    if m >= 0 and (not fewest or n < fewest) then
                        pick_owner, fewest = owner, n
                    end
                end
            end
        end
        if pick_owner then
            sc.owners_rolled[pick_owner.key] = true
            return pick_owner
        end
    end
    local avg = 0
    for _, p in ipairs(players) do
        avg = avg + p.m.spotlight
    end
    avg = avg / math.max(1, #players)
    local best_mod = -99
    for _, p in ipairs(players) do
        local _, m = self:best_skill(p, skill_list)
        best_mod = math.max(best_mod, m)
    end
    -- The two best at it (by modifier) are in the running; of those, whoever has rolled least
    -- tonight gets it, the better one on a tie.
    local function pick(pool)
        local cands = {}
        for _, p in ipairs(pool) do
            local _, m = self:best_skill(p, skill_list)
            if not capped(p) and not (m < 0 and best_mod >= 2) then
                table.insert(cands, { p = p, m = m + (util.contains(prefer or {}, p.class) and 0.5 or 0) })
            end
        end
        if #cands == 0 then
            return nil
        end
        table.sort(cands, function(a, b) return a.m > b.m end)
        local cut = cands[math.min(2, #cands)].m
        -- Someone well behind tonight gets a look-in when they're decent at it, not just the two
        -- best (the fighter's skills would leave him out of most talking and sleuthing).
        local function behind(p)
            return total >= 4 and (self.big_rolls[p.key] or 0) / total < 1 / #players - 0.1
        end
        local best, bw
        for _, cd in ipairs(cands) do
            if cd.m >= cut or (cd.m >= 2 and behind(cd.p)) then
                local share = total > 0 and (self.big_rolls[cd.p.key] or 0) / total or 0
                local w = -share * 10 + cd.m * 0.1 + self.rng:next() * 0.5
                if not bw or w > bw then
                    best, bw = cd.p, w
                end
            end
        end
        return best
    end
    local low = {}
    for _, p in ipairs(players) do
        local share = total > 0 and (self.big_rolls[p.key] or 0) / total or 0
        if p.m.spotlight <= avg + 0.01 or share < 1 / #players - 0.04 then
            table.insert(low, p)
        end
    end
    return pick(low) or pick(players) or players[1]
end

function M:pick_actor(prefs, exclude)
    for _, pass in ipairs({ "primary", "secondary" }) do
        for _, a in ipairs(prefs or {}) do
            local found = {}
            for _, p in ipairs(self.players) do
                if p ~= exclude and p[pass] == a then
                    table.insert(found, p)
                end
            end
            if #found > 0 then
                return self.rng:pick(found)
            end
        end
    end
    local others = {}
    for _, p in ipairs(self.players) do
        if p ~= exclude then
            table.insert(others, p)
        end
    end
    if #others == 0 then
        return self.players[1]
    end
    return self.rng:pick(others)
end

-- A moment for the scrapbook from a log line: its first sentence, or the first two when the first
-- is only a word or two ("Click. The lock gives." is the lock giving, not "Click").
function M.moment_of(text)
    local out, words = "", 0
    for sentence in string.gmatch(text .. " ", "(.-[%.!?]+[\"']?)%s+") do
        out = out == "" and sentence or (out .. " " .. sentence)
        for _ in string.gmatch(sentence, "%a+") do
            words = words + 1
        end
        if words >= 4 then
            break
        end
    end
    if out == "" then
        return text
    end
    return (string.gsub(out, "[%.!]+$", ""))
end

function M:highlight(score_value, text, who, ev)
    table.insert(self.highlights, { score = score_value, text = text })
    -- Every moment worth a highlight is in the event log too (M8, B1).
    local keys = {}
    for _, p in ipairs(who or {}) do
        table.insert(keys, p.key)
    end
    self:event(ev or "moment", { who = #keys == 1 and keys[1] or "party", keys = keys, text = text, weight = score_value })
    for _, p in ipairs(who or {}) do
        if not p.best or score_value > p.best.score then
            p.best = { score = score_value, text = text }
        end
    end
end

-- Targets for an effect selector, as { player, scale } pairs.
function M:targets(sel)
    local out = {}
    if sel == "all" then
        for _, p in ipairs(self.players) do
            table.insert(out, { p, 1 })
        end
    elseif sel == "actor" then
        if self.actor then
            table.insert(out, { self.actor, 1 })
        end
    elseif sel == "other" then
        if self.other then
            table.insert(out, { self.other, 1 })
        end
    elseif sel == "others" then
        for _, p in ipairs(self.players) do
            if p ~= self.actor then
                table.insert(out, { p, 1 })
            end
        end
    elseif sel == "lowest" then
        local low = self:lowest()
        if low then
            table.insert(out, { low, 1 })
        end
    elseif string.sub(sel, 1, 4) == "key:" then
        local key = string.sub(sel, 5)
        for _, p in ipairs(self.players) do
            if p.key == key then
                table.insert(out, { p, 1 })
            end
        end
    elseif sel == "perceptive" then
        for _, p in ipairs(self.players) do
            table.insert(out, { p, p.perception })
        end
    elseif string.sub(sel, 1, 5) == "arch:" then
        local key = string.sub(sel, 6)
        for _, p in ipairs(self.players) do
            local w = score.arch(p, key)
            if w > 0 then
                table.insert(out, { p, w })
            end
        end
    end
    return out
end

-- Every consequence has a cause (A11): suspicion goes up with a reason, kept for the night so a
-- callout and the report can name it ("Sam noticed the cooked roll").
function M:suspect(p, amount, why)
    score.add(p, "suspicion", amount)
    if amount > 0 then
        self.suspicion_log = self.suspicion_log or {}
        local log = self.suspicion_log[p.key] or {}
        self.suspicion_log[p.key] = log
        why = why or "something behind the screen"
        log[why] = (log[why] or 0) + amount
        -- Suspicion carries over from week to week, and so does what started it.
        local camp = self.campaign
        camp.suspicion_last = camp.suspicion_last or {}
        camp.suspicion_last[p.key] = why
    end
end

-- What made p most suspicious tonight, or else the last thing that did, or nil.
function M:suspicion_cause(p)
    local best, amt
    for why, a in pairs((self.suspicion_log or {})[p.key] or {}) do
        if not amt or a > amt or (a == amt and why < best) then
            best, amt = why, a
        end
    end
    return best or (self.campaign.suspicion_last or {})[p.key]
end

-- Apply a list of effects and nudge engagement for everyone touched. An effect's why says what
-- caused it (suspicion keeps it); else the card being answered.
function M:apply(effects)
    local touched = {}
    for _, eff in ipairs(effects or {}) do
        for _, t in ipairs(self:targets(eff[1])) do
            local p, scale = t[1], t[2]
            local g = {}
            for k, v in pairs(eff) do
                if k == "suspicion" then
                    self:suspect(p, v * scale, eff.why or self.why)
                    g[k] = v * scale
                elseif k ~= 1 and k ~= "why" then
                    score.add(p, k, v * scale)
                    g[k] = v * scale
                end
            end
            touched[p] = touched[p] or {}
            for k, v in pairs(g) do
                touched[p][k] = (touched[p][k] or 0) + v
            end
        end
    end
    for p, g in pairs(touched) do
        score.nudge_engagement(p, score.enjoyment(p, g) + 6)
    end
end

function M:apply_meters(sel, meters)
    local eff = { sel }
    for k, v in pairs(meters) do
        eff[k] = v
    end
    self:apply({ eff })
end

-- Where everyone's at: a pose for each player's mini-me at the table.
-- lean (into it), neutral, arms (crossed), yawn, phone.
function M:poses()
    local out = {}
    for _, p in ipairs(self.players) do
        local e = p.engagement
        local pose = "neutral"
        if e >= 0.68 then
            pose = "lean"
        elseif e < 0.2 then
            pose = "phone"
        elseif e < 0.3 then
            pose = "yawn"
        elseif e < 0.42 and score.fun(p) < 45 then
            pose = "arms"
        end
        out[p.key] = pose
    end
    return out
end

-- Live view for the screen: everyone's tell and rough Fun right now.
function M:tells()
    local out = {}
    local tells = content.chat.tells
    local poses = self:poses()
    for _, p in ipairs(self.players) do
        local text = tells[#tells].text
        for _, t in ipairs(tells) do
            if p.engagement >= t.at then
                text = t.text
                break
            end
        end
        local mood = score.mood(p)
        if mood.tell and p.engagement < 0.5 then
            text = mood.tell
        end
        out[p.key] = { text = text, engagement = p.engagement, fun = score.fun(p), pose = poses[p.key] }
    end
    return out
end

-- Scenes --------------------------------------------------------------------------

-- A scene is called by where it happens (the location is always settled before it starts).
function M:scene_title(sc)
    local loc = sc.comps.location
    if not loc then
        return content.scenes[sc.type].name
    end
    return util.capitalize(loc.name)
end

-- Does this card make sense where the scene is? (An improvised place at a stretch can leave
-- a floor to give way on a forest road; then it simply doesn't happen.)
function M:fits_here(c)
    local sc = self.scene
    return not c or c.kind == "location" or content.fits_setting(c, sc and sc.comps.location)
end

-- The story (real-session pass): describe a card on the scene, the way this week's story
-- tells it if it's one of the story cards, and note the clue it gives the party.
function M:describe(c, style)
    local sc = self.scene
    if not c or self:muted(c) or not self:fits_here(c) then
        return
    end
    -- A story card tells its part the first time it plays (whichever week's beat it's from);
    -- a recurring card that's been here before remembers it.
    local rev, clue
    if not self.revealed[c.id] then
        rev, clue = story.pending_reveal(self.campaign, c)
    end
    local text = rev
    -- A place the world changed off screen (S7) is described as it is now.
    local state = not text and c.kind == "location" and ledger.place_state(self.campaign, c.id)
    if state then
        text = state.line
    end
    -- Back somewhere they were earlier tonight (a place on two scenes, A6). Straight after a
    -- scene there, they never left: the place isn't described again.
    self.described = self.described or {}
    if not text and c.kind == "location" and self.described[c.id] then
        if self.last_location == c.id then
            return
        end
        text = "Back at " .. soft_lower(c.name) .. "."
    end
    if not text then
        if c.again and deck.returning(self.campaign, c) then
            text = c.again
        else
            text = content.line_for(c, sc and sc.comps.location)
        end
    end
    self.described[c.id] = true
    if c.kind == "location" then
        self.last_location = c.id
    end
    self:say(text, style or "narration")
    if rev then
        self.revealed[c.id] = true
        if clue and not story.has_clue(self.campaign, c.id) then
            if c.kind == "goal" and sc then
                -- A goal's answer comes when the scene pays it off, never in its first line.
                sc.goal_clue = { id = c.id, text = clue }
            else
                self:found_clue(c.id, clue)
            end
        end
    end
    if c.kind == "cast" then
        self.met = self.met or {}
        self.met[c.id] = rev and "revealed" or (self.met[c.id] or true)
    end
end

-- The party learns something: into the DM's notes (once a night).
function M:found_clue(id, text)
    self.story_found = self.story_found or {}
    for _, f in ipairs(self.story_found) do
        if f.id == id then
            return
        end
    end
    table.insert(self.story_found, { id = id, text = text })
    self:event("clue", { who = self.actor and self.actor.key or "party", clue = id, text = "They found out: " .. text })
    self:emit({ kind = "clue", id = id, text = text })
end

-- The terrain set on the table: the place's map if the DM drew one (B9), else the place's own set,
-- else one borrowed by what the place is, else by the scene (game/model/maps.lua).
function M:terrain_for(sc)
    return maps.template(self.campaign, sc.comps.location, sc.type)
end

-- The board the table sets out for a scene: the place's map when the DM drew one on this
-- template (Set the stage: the DM's pieces are part of the place), else the template itself.
function M:board_for(sc, t)
    t = t or sc.terrain or self:terrain_for(sc)
    local map = self:map_for(sc)
    if map and map.template == t then
        return maps.board_id(map)
    end
    return t
end

-- The place's map, if there is one (B9).
function M:map_for(sc)
    local loc = sc and sc.comps.location
    return loc and maps.get(self.campaign, loc.id) or nil
end

-- Where the party stands when a scene opens, and who the DM is voicing.
function M:staging(sc)
    local blocked, layout = fight.blocked_set(sc.terrain, self:map_for(sc))
    local taken = {}
    local party = {}
    local spots = fight.squares_near(blocked, taken, layout.party[1], layout.party[2], #self.players, 1,
        content.terrain_layout.W, content.terrain_layout.H)
    for i, p in ipairs(self.players) do
        local sq = spots[i] or { 2, i + 3 }
        table.insert(party, { id = p.key, class = p.class, x = sq[1], y = sq[2] })
    end
    local npc
    local cast = sc.comps.cast
    if cast and not (sc.type == "combat" or sc.type == "set_piece") then
        -- Where this person would be: the board can say (the stranger in the corner, Gus behind the bar).
        local at = (layout.npc_at and layout.npc_at[cast.id]) or layout.npc
        local sq = fight.squares_near(blocked, taken, at[1], at[2], 1, 1,
            content.terrain_layout.W, content.terrain_layout.H)[1]
        if sq then
            npc = { id = "npc", cast = cast.id, name = cast.name, x = sq[1], y = sq[2] }
        end
    end
    -- Where the person stands, so a hero talking to them walks over (A9).
    sc.npc_at = npc and { npc.x, npc.y } or nil
    return party, npc
end

-- Improv -------------------------------------------------------------------------------

local FIT_SCORE = { great = 2, good = 1, poor = -1 }

local function stock_cards(self, n, fit_fn)
    local stock = {}
    local loc = self:location()
    for _, s in ipairs(content.improv.stock) do
        if content.fits_setting(s, loc) then
            table.insert(stock, s)
        end
    end
    self.rng:shuffle(stock)
    local out = {}
    for i = 1, math.min(n, #stock) do
        local s = stock[i]
        table.insert(out, { stock = s, name = s.name, kind_name = "Stock move", fit = fit_fn and fit_fn(s.tags) or "good" })
    end
    return out
end

-- Score a combination of 1 to 3 cards: the best card counts fully, the others half;
-- a card that doesn't fit always hurts. Returns "great", "good" or "poor".
function M.combo_fit(cards)
    if #cards == 0 then
        return "poor", -1
    end
    local scores = {}
    for _, c in ipairs(cards) do
        table.insert(scores, FIT_SCORE[c.fit] or 0)
    end
    table.sort(scores, function(a, b) return a > b end)
    local total = scores[1]
    for i = 2, #scores do
        total = total + (scores[i] > 0 and scores[i] * 0.5 or scores[i])
    end
    if total >= 2.5 then
        return "great", total
    elseif total >= 1 then
        return "good", total
    end
    return "poor", total
end

local function picks_from(answer, cards)
    local picks = {}
    local seen = {}
    if type(answer) == "number" then
        answer = { answer }
    end
    if type(answer) == "table" then
        for _, i in ipairs(answer) do
            i = math.floor(tonumber(i) or 0)
            if cards[i] and not seen[i] and #picks < 3 then
                seen[i] = true
                table.insert(picks, cards[i])
            end
        end
    end
    if #picks == 0 then
        -- Nothing picked before the timer ran out: the best single card in the hand.
        local best, bs = cards[1], -9
        for _, c in ipairs(cards) do
            if (FIT_SCORE[c.fit] or 0) > bs then
                best, bs = c, FIT_SCORE[c.fit] or 0
            end
        end
        picks = { best }
    end
    return picks
end

-- The story deck's cards that aren't on tonight's board (the slice rework: improv draws from
-- the same deck as prep), with the hand's leftovers first. Backstory cards of someone who
-- isn't here stay out.
function M:improv_pool()
    local present = {}
    for _, p in ipairs(self.players) do
        present[p.key] = true
    end
    local pool, seen = {}, {}
    local function add(c)
        if c and not seen[c.id] and not self.improvised[c.id] and not self.on_board[c.id]
            and (not c.thread or present[c.thread]) and deck.thread_live(self.campaign, c)
            and not deck.is_spent(self.campaign, c.id) then
            seen[c.id] = true
            table.insert(pool, c)
        end
    end
    for _, c in ipairs(self.unused) do
        add(c)
    end
    for _, c in ipairs(deck.cards(self.campaign)) do
        add(c)
    end
    return pool
end

-- How much a card belongs on an improv hand: this week's story first, then whatever just
-- joined the deck, then backstory, then the rest.
function M:improv_rank(c)
    if self.prep.arc_cards and self.prep.arc_cards[c.id] or story.pending_reveal(self.campaign, c) then
        return 1
    elseif deck.is_new(self.campaign, c.id) then
        return 2
    elseif c.thread then
        return 3
    end
    return 4
end

function M:improv_cards(kind)
    local sc = self.scene
    local cards = {}
    -- Only what could happen here: a location has to suit what's already on the scene,
    -- anything else has to suit the location.
    local function fits(c)
        -- A cliffhanger only closes the night's last scene.
        if c.cliffhanger and sc.index < #self.scenes then
            return false
        end
        if c.kind == "location" then
            if content.setting_clash(c, sc.comps) ~= nil then
                return false
            end
            -- A place has to suit the story already on the scene (the goal tied to the chapel).
            for _, other in pairs(sc.comps) do
                if other.kind ~= "location" and not content.belongs_at(other, c) then
                    return false
                end
            end
            return true
        end
        return content.fits_setting(c, sc.comps.location) and content.belongs_at(c, sc.comps.location)
    end
    local all = self:improv_pool()
    local pool = {}
    for _, c in ipairs(all) do
        if c.kind == kind and fits(c) then
            -- Within a rank, what suits this kind of scene and this place comes first.
            local score = content.affinity(c, sc.comps, sc.type)
            table.insert(pool, { c = c, rank = self:improv_rank(c), r = self.rng:next() - score })
        end
    end
    table.sort(pool, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        return a.r < b.r
    end)
    -- A goal ("what are we doing here?") and a cast ("who do we talk to?") want answers from the
    -- story: up to three of those. Anything else: two, then stock moves.
    local want = (kind == "goal" or kind == "cast" or kind == "location") and 3 or 2
    for i = 1, math.min(want, #pool) do
        local c = pool[i].c
        local fit = util.contains(c.fits, sc.type) and "great" or "poor"
        local flag = social.content_flags(self.campaign, { c })[1]
        local warn
        if flag and find_present(self.players, flag.key) then
            local who = find_present(self.players, flag.key).name
            warn = flag.kind == "line" and (who .. "'s line") or (flag.kind == "veil" and (who .. "'s veil") or (who .. " asked"))
        end
        table.insert(cards, { comp = c, name = c.name, kind_name = content.kind_names[c.kind], fit = fit,
                              payoff = c.payoff_of ~= nil, warn = warn, story = pool[i].rank == 1 })
    end
    if kind == "location" or kind == "cast" then
        -- Somewhere to be, or someone to talk to: no stock moves. Short of three, any place or
        -- person that suits the scene and isn't spent will do, at a stretch.
        if #cards < 3 then
            local have = {}
            for _, card in ipairs(cards) do
                have[card.comp.id] = true
            end
            -- First pass: everyday places and people that suit the scene; second: anything not
            -- spent that suits it; last: anything not spent at all, at a stretch.
            for pass = 1, 3 do
                local extra = {}
                for _, c in ipairs(content.by_kind[kind]) do
                    local everyday = not c.thread and (c.deck or "start") ~= "follow"
                    if not have[c.id] and not self.improvised[c.id] and not self.on_board[c.id] and (pass == 3 or fits(c))
                        and not deck.is_spent(self.campaign, c.id) and (pass >= 2 or everyday) then
                        table.insert(extra, c)
                    end
                end
                table.sort(extra, function(a, b) return a.id < b.id end)
                self.rng:shuffle(extra)
                for i = 1, math.min(3 - #cards, #extra) do
                    local c = extra[i]
                    have[c.id] = true
                    table.insert(cards, { comp = c, name = c.name, kind_name = content.kind_names[c.kind],
                                          fit = (pass < 3 and util.contains(c.fits, sc.type)) and "good" or "poor" })
                end
                if #cards >= 3 then
                    break
                end
            end
        end
        return cards
    end
    -- A recurring face or place from the deck can join the mix.
    local extra = {}
    for _, c in ipairs(all) do
        if (c.kind == "cast" or c.kind == "location") and c.kind ~= kind and deck.returning(self.campaign, c)
            and not sc.comps[c.kind] and fits(c) then
            table.insert(extra, c)
        end
    end
    if #extra > 0 then
        local c = self.rng:pick(extra)
        local fit = util.contains(c.fits, sc.type) and "good" or "poor"
        table.insert(cards, { comp = c, name = c.name, kind_name = content.kind_names[c.kind], fit = fit, extra = true })
    end
    for _, st in ipairs(stock_cards(self, HAND_SIZE - #cards)) do
        table.insert(cards, st)
    end
    return cards
end

-- Play the picked cards: fill the slot, add stock moves, write canon.
function M:play_improv(picks, kind, replace)
    local sc = self.scene
    -- One card per kind: a second goal on top of the first makes no sense.
    local seen, kept = {}, {}
    for _, card in ipairs(picks) do
        local k = card.comp and card.comp.kind or (card.quantum and "quantum") or (card.stock and card.stock.id)
        if not seen[k] then
            seen[k] = true
            table.insert(kept, card)
        end
    end
    picks = kept
    local fit = M.combo_fit(picks)
    local moved, new_cast = false, false
    for _, card in ipairs(picks) do
        if card.comp then
            local ck = card.comp.kind
            self.improvised[card.comp.id] = true
            if ck == "cast" or ck == "location" then
                table.insert(self.canon, card.comp.name)
            end
            self:say("You improvise: " .. card.comp.name .. ".", "dm")
            -- Mid-scene cards get the same Session Zero care as prepped ones.
            local mid = replace or not (sc and ck == kind)
            if sc and mid then
                self:safety_check(sc, { card.comp })
            end
            local function describe()
                self:describe(card.comp, "narration")
            end
            if sc and (ck == kind or replace) and (ck == kind or ck == "location" or ck == "cast") then
                sc.comps[ck] = card.comp
                if ck == "location" then
                    moved = true
                end
                new_cast = new_cast or ck == "cast"
                -- The scene narrates its own slots once it's set up; mid-scene, say it now.
                if replace then
                    describe()
                end
            elseif sc and not sc.comps[ck] and (ck == "cast" or ck == "location") then
                sc.comps[ck] = card.comp
                moved = moved or ck == "location"
                new_cast = new_cast or ck == "cast"
                describe()
            else
                describe()
            end
        elseif card.quantum then
            self.quantum = (self.quantum or 0) + 1
            self:say(card.line, "narration")
        else
            self:apply_meters("all", card.stock.meters)
            self:say(card.stock.line, "narration")
        end
    end
    if (moved or new_cast) and sc and not self.pre_scene and sc.terrain then
        -- A person made up mid-scene gets a mini on the board too (A9).
        self:restage(sc, new_cast)
    end
    return fit
end

-- The scenery changes mid-scene (an improvised location, or they wandered off).
function M:restage(sc, force)
    local t = self:terrain_for(sc)
    if t == sc.terrain and not force then
        return
    end
    local shifted = t ~= sc.terrain
    sc.terrain = t
    local party, npc = self:staging(sc)
    self.stage_now = { terrain = t, board = self:board_for(sc, t), party = party, npc = npc }
    if shifted then
        self:board_set(self:board_for(sc, t), sc)
    end
    -- The DM's map for this place stays on the table through the whole scene (B9).
    local map = self:map_for(sc)
    self:emit({ kind = "stage", terrain = t, board = self:board_for(sc, t), party = party, npc = npc,
                title = shifted and self:scene_title(sc) or nil,
                pieces = map and map.template == t and maps.cells(map) or nil })
    if shifted then
        self:dress_board()
    end
end

function M:improvise(kind)
    local sc = self.scene
    local cards = self:improv_cards(kind)
    local prompt = util.fill(content.improv.sketched[kind], self:vars())
    local answer = self:emit({ kind = "improv", prompt = prompt, cards = cards, slot = content.kind_names[kind],
                               pick = { 1, 3 } })
    local picks = picks_from(answer, cards)
    local fit = self:play_improv(picks, kind)
    if fit == "great" then
        sc.quality = sc.quality + 0.06
    elseif fit == "good" then
        sc.quality = sc.quality + 0.03
    end
    local critic
    local poses = {}
    if fit == "poor" then
        critic = self:pick_actor({ "storyteller", "tactician" })
        self:apply({ { "arch:storyteller", fun = -3 }, { "arch:tactician", fun = -2 } })
        if critic then
            poses[critic.key] = "arms"
        end
    else
        local fan = self:pick_actor({ "storyteller", "method_actor", "explorer" })
        if fan then
            poses[fan.key] = "lean"
        end
    end
    self:say(self:fresh(content.improv.outcomes[fit], "improv_" .. fit), fit == "poor" and "warn" or "aside",
        { critic = critic and critic.name or "Someone" })
    self:react(poses)
    if fit == "great" or (fit == "poor" and critic) then
        self:bark(critic or self:pick_actor({ "storyteller", "method_actor" }), fit == "great" and "improv_great" or "improv_poor")
    end
    self.improv_count = (self.improv_count or 0) + 1
end

-- The party goes off-script.
function M:drift()
    self.drift_used = true
    self.actor = self:pick_actor({ "instigator", "explorer", "method_actor" })
    self.other = nil
    local loc = self.scene and self.scene.comps.location
    local fitting = {}
    for _, d in ipairs(content.improv.drift) do
        if type(d) == "string" then
            table.insert(fitting, d)
        elseif loc and not (d.unnamed_keeper and loc.keeper) then
            for _, w in ipairs(d.where or {}) do
                if util.contains(loc.setting or {}, w) then
                    table.insert(fitting, d[1])
                    break
                end
            end
        end
    end
    local prompt = util.fill(self.rng:pick(fitting), self:vars())
    local actor = self.actor
    local function fit_for(tags)
        local best = 0
        for _, t in ipairs(tags) do
            best = best + score.like(actor, t)
        end
        if best >= 1 then
            return "great"
        elseif best < 0 then
            return "poor"
        end
        return "good"
    end
    local pool = {}
    local loc = self:location()
    for _, c in ipairs(self:improv_pool()) do
        if (c.kind == "location" or (c.kind == "cast" and not c.foe and not c.villain and content.fits_setting(c, loc))) then
            table.insert(pool, c)
        end
    end
    self.rng:shuffle(pool)
    local cards = {}
    for i = 1, math.min(2, #pool) do
        local c = pool[i]
        table.insert(cards, { comp = c, name = c.name, kind_name = content.kind_names[c.kind], fit = fit_for(c.tags) })
    end
    -- The quantum ogre: move an unused fight onto their new path.
    for _, c in ipairs(self:improv_pool()) do
        if c.kind == "cast" and content.encounters.by_cast[c.id] then
            table.insert(cards, { quantum = true, comp_id = c.id, name = "Quantum ogre: " .. c.name, kind_name = "Unused encounter",
                                  fit = "good", line = "Wherever they go, " .. soft_lower(c.name) .. " turns out to be there too." })
            break
        end
    end
    for _, s in ipairs(stock_cards(self, HAND_SIZE - #cards, fit_for)) do
        table.insert(cards, s)
    end
    self:say(prompt, "twist")
    self:react({ [actor.key] = "lean" })
    local answer = self:emit({ kind = "improv", prompt = "They're off your map. Where does it lead?", cards = cards,
                               drift = true, pick = { 1, 3 } })
    local picks = picks_from(answer, cards)
    local fit = self:play_improv(picks, nil, true)
    local used_quantum = false
    for _, c in ipairs(picks) do
        if c.quantum then
            used_quantum = true
            self.improvised[c.comp_id] = true
            -- The prepped fight moves onto their new path.
            if self.scene then
                self.scene.comps.cast = content.components[c.comp_id]
            end
        end
    end
    if used_quantum then
        -- Cheap and often invisible. Explorers notice when their choices stop mattering.
        self:apply({ { "arch:explorer", trust = -3 * (self.campaign.quantum_ogres or 0) - 1 } })
        self.campaign.quantum_ogres = (self.campaign.quantum_ogres or 0) + 1
    end
    if fit == "poor" then
        self:apply({ { "actor", spotlight = 6, fun = -2 }, { "all", story = 2 } })
        self:say(util.fill(self:fresh(content.improv.outcomes.poor, "improv_poor"), { critic = actor.name }), "warn")
    else
        self:apply({ { "actor", spotlight = 10, fun = fit == "great" and 6 or 3 }, { "arch:explorer", story = 4 },
                     { "arch:instigator", fun = 3 }, { "all", story = 2 } })
        self:say(self:fresh(content.improv.outcomes[fit], "improv_" .. fit), "aside")
        self:highlight(fit == "great" and 7 or 4, actor.char .. " drags everyone off the map", { actor }, "curveball")
        self:bark(actor, "improv_great")
    end
    self.improv_count = (self.improv_count or 0) + 1
end

-- Quick checks: fast rolls that stream into the dice strip, moving the scene's
-- progress track toward its big moment ----------------------------------------------------------

-- A hero in character, talking to another (the scene's little back-and-forths).
function M:banter()
    -- A long stretch without a call: the table keeps it moving (the nights gate).
    if self:idle() > 80 then
        return
    end
    local l, p = self.talk:banter(self.players)
    if not l then
        return
    end
    local q
    for _, x in ipairs(self.players) do
        if x.key == l.to then
            q = x
        end
    end
    local v = self:vars({ char = p.char, name = p.name })
    self:emit({ kind = "say", who = p.key, text = util.fill(l.text, v), ic = true, line = l.id })
    self:emit({ kind = "say", who = q.key, text = util.fill(l.reply, self:vars({ char = q.char, name = q.name })), ic = true,
                line = l.id, part = "reply" })
    score.add(p, "social", 3)
    score.add(q, "social", 3)
end

-- Actions the hero could take here: the scene type's list, minus what doesn't fit the
-- location, needs a cast that isn't there, or was already done this scene.
function M:actions_for(sc, used)
    local list = content.actions[sc.type] or {}
    local loc = sc.comps.location
    local cast = sc.comps.cast and not self:muted(sc.comps.cast)
    local out = {}
    -- Nobody talks a wolf into anything, or threatens, robs or lies to a mentor's ghost (A3).
    local c = sc.comps.cast
    local function suits(a)
        if a.cast and c and c.talks == false then
            return false
        end
        if c and c.revered and (a.skill == "intimidation" or a.skill == "sleight_of_hand" or a.skill == "deception") then
            return false
        end
        return content.fits_setting(a, loc) and (not a.cast or cast) and (not a.other or #self.players > 1)
    end
    for i, a in ipairs(list) do
        if not used[i] and suits(a) then
            table.insert(out, { i = i, a = a })
        end
    end
    if #out == 0 then
        -- Everything's been tried: let the table repeat the ones that fit.
        for i, a in ipairs(list) do
            if suits(a) then
                table.insert(out, { i = i, a = a })
            end
        end
    end
    return out
end

-- One hero's go: they say what they try, the DM calls the check, they roll, the DM says how it lands.
function M:hero_action(sc, used, dc, need, spots)
    local st = content.scenes[sc.type]
    -- Players who shine here act more; quiet players get a turn too.
    local weights = {}
    for j, p in ipairs(self.players) do
        local shine = st.shine[p.class] or 0
        weights[j] = 1 + 2 * shine + math.max(0, (40 - p.m.spotlight) / 20)
            + ((self.prep and self.prep.spot == p.key) and 1.5 or 0)   -- this session is for them (S6)
    end
    local p = self.rng:weighted(self.players, weights)
    self.actor = p
    self.other = self:pick_actor(nil, p)
    -- What they'd try: whatever they're good at, mostly.
    local options = self:actions_for(sc, used)
    local aw = {}
    for k, o in ipairs(options) do
        local m = self:mod_for(p, o.a.skill)
        aw[k] = 2 ^ (util.clamp(m, -2, 8) / 2)
        -- People play to type (A12): a Butt-Kicker kicks the door in, a Method Actor does the voice.
        local arch = o.a.archetype
        if arch and (p.primary == arch) then
            aw[k] = aw[k] * 3
        elseif arch and p.secondary == arch then
            aw[k] = aw[k] * 2
        end
    end
    local pick = self.rng:weighted(options, aw)
    local a = pick and pick.a
    if not a then
        return nil
    end
    used[pick.i] = true
    local vars = self:vars({ char = p.char, other_char = self.other and self.other.char or "" })
    -- The player says it, in character (in a long stretch without a call, the table just rolls).
    if self:idle() < 90 then
        self:emit({ kind = "say", who = p.key, text = util.capitalize(util.fill(a.say, vars)), ic = true })
    end
    local mod = self:mod_for(p, a.skill)
    -- Aimed at someone in the scene: how they feel about the party counts (SRD 5.2.1 attitudes).
    local pid = (a.cast or a.skill == "deception") and self:cast_person(sc) or nil
    local edge = ledger.influence(self.campaign, pid, a.skill, self)
    -- An item's Advantage (Boots of Elvenkind, Eyes of the Eagle, A13) cancels out a disadvantage.
    local iedge, iname = require("game.model.items").check_edge(self.campaign, p.key, a.skill)
    local item_edge
    if iedge then
        if edge == "dis" then
            edge = nil
        elseif edge ~= "adv" then
            edge, item_edge = "adv", iname
        end
    end
    local roll = self.rng:d20()
    local other_roll
    if edge then
        other_roll = self.rng:d20()
        if (edge == "adv" and other_roll > roll) or (edge == "dis" and other_roll < roll) then
            roll, other_roll = other_roll, roll
        end
    end
    -- Last time was a near miss (B2): they know the trick of it now.
    local near_bonus = self.edge_next and self.edge_next[p.key]
    if near_bonus then
        mod = mod + near_bonus
        self.edge_next[p.key] = nil
    end
    local total = roll + mod
    local success = total >= dc
    local name = skills.name(a.skill)
    local result
    if roll == 20 then
        result = "natural 20"
    elseif roll == 1 then
        result = "natural 1"
    else
        result = success and "success" or "miss"
    end
    local text = p.char .. ": " .. name .. " " .. util.int(roll) .. skills.signed(mod) .. " = " .. util.int(total)
        .. " vs DC " .. util.int(dc) .. ", " .. result
    if edge and item_edge then
        text = text .. " (advantage: " .. item_edge .. "; the other die was " .. util.int(other_roll) .. ")"
    elseif edge and pid then
        local cast = sc.comps.cast
        text = text .. " (" .. (edge == "adv" and "advantage" or "disadvantage") .. ": " .. ledger.about(pid).name
            .. ((cast and cast.group) and " are " or " is ") .. ledger.label(ledger.att(self.campaign, pid, self))
            .. "; the other die was " .. util.int(other_roll) .. ")"
    end
    table.insert(self.checks, success)
    if success then
        local big = roll == 20
        sc.progress.wins = sc.progress.wins + (big and 2 or 1)
        score.add(p, "spotlight", big and 10 or 5)
        score.add(p, "fun", big and 4 or 1)
        if big then
            self:highlight(8, p.char .. " rolls a natural 20 on " .. name, { p }, "crit")
        end
    else
        sc.progress.setbacks = sc.progress.setbacks + 1
        score.add(p, "spotlight", 1)
        for _, q in ipairs(self.players) do
            score.add(q, "story", 1)
        end
        if roll == 1 then
            self:highlight(3, p.char .. " rolls a 1 at the worst possible moment", { p }, "fumble")
        end
    end
    score.nudge_engagement(p, success and 14 or 6)
    local spot = #spots > 0 and self.rng:pick(spots) or nil
    -- Everything happens on the board (A9): a hero talking to someone walks over to them.
    if sc.npc_at and SOCIAL_SKILL[a.skill] then
        spot = { sc.npc_at[1] - 1, sc.npc_at[2] }
    end
    self:emit({ kind = "check", text = text, roll = roll, bonus = mod, total = total, dc = dc, success = success,
                actor = p.key, char = p.char, skill = a.skill, skill_name = name, crit = roll == 20,
                fumble = roll == 1, spot = spot, edge = edge, other_roll = other_roll,
                progress = { wins = math.min(sc.progress.wins, need), setbacks = sc.progress.setbacks, need = need,
                             max = content.scene_beats.setbacks } })
    -- The notebook remembers what they did to whom.
    if pid then
        local act = ledger.ACTS[a.skill]
        self:note(sc, { who = p.key, to = pid, did = a.skill, ok = success, d = act and (success and act[1] or act[2]) or 0 })
    end
    -- How it lands in the story, then at the table.
    self:say(util.capitalize(util.fill(success and a.win or a.lose, vars)), success and "good" or "bad")
    if roll == 20 then
        local poses = { [p.key] = "cheer" }
        for _, q in ipairs(self.players) do
            if q ~= p then
                poses[q.key] = "lean"
            end
        end
        self:react(poses)
        self:bark(p, "crit")
        self:table_behavior("after_crit", p)
    elseif roll == 1 then
        self:react({ [p.key] = "gasp" })
        self:bark(p, "fumble")
        self:table_behavior("after_fail", p)
        fails_mod.jail(self, p)   -- B2: into dice jail with it
    elseif not success and self:table_behavior("after_fail", p) then
        -- (they said something already)
    elseif self.rng:chance(self:idle() > 75 and 0.1 or 0.22) then
        self:bark(p, success and "check_win" or "check_lose")
    elseif self.rng:chance(0.22) and #self.players > 1 then
        local q = self:pick_actor(nil, p)
        self:bark(q, success and "cheer_other" or "groan_other", { other = p.name, other_char = p.char, other_key = p.key })
    end
    if sc.comps.cast and not self:muted(sc.comps.cast) and self.rng:chance(self:idle() > 75 and 0.12 or 0.25) then
        self:npc_line(success and "good" or "bad")
    end
    return success
end

-- The heroes work the scene: one check at a time, each moving its progress track toward the
-- big moment (or a setback away from it).
function M:quick_checks(sc)
    local beats = content.scene_beats
    local need = beats.track[sc.type] or 3
    local comp = sc.comps.complication
    if comp and comp.difficulty > 0 then
        need = need + 1
    end
    local max_checks = sc.cut and 2 or (need + 3)
    -- Out of calls for the night: the scene gets to the point (the table can feel the clock).
    if self:decision_count() >= 14 then
        max_checks = math.min(max_checks, need + 1)
    end
    local dc = (content.actions.DC[util.clamp(sc.difficulty, 1, 3)] or 12) + ((comp and comp.difficulty > 0) and 1 or 0)
    sc.dc = dc
    local layout = board_mod.layout(self:board_for(sc))
    local spots = layout.spots or {}
    sc.progress = { wins = 0, setbacks = 0, need = need }
    -- What the heroes have already tried tonight, by scene type: nobody repeats a move until
    -- the rest have been used (A5).
    self.actions_used = self.actions_used or {}
    self.actions_used[sc.type] = self.actions_used[sc.type] or {}
    local used = self.actions_used[sc.type]
    local i = 0
    while i < max_checks and sc.progress.wins < need and sc.progress.setbacks < beats.setbacks do
        i = i + 1
        -- In a social scene with someone to talk to, the cast speaks up first now and then.
        if i == 1 and sc.comps.cast and not self:muted(sc.comps.cast) and not sc.talked
            and (sc.type == "social" or sc.type == "mystery" or sc.type == "downtime") then
            self:npc_line("greet")
            self:table_behavior("social")
        end
        if self:hero_action(sc, used, dc, need, spots) == nil then
            break
        end
        if i == 3 then
            self:table_behavior("long_scene")
            if not sc.cut then
                self:curveball(sc)
            end
        end
        if i == 1 and comp and not comp.cliffhanger and not self:muted(comp) and self:fits_here(comp) then
            self:say(content.line_for(comp, sc.comps.location), "twist")
        elseif i == 2 then
            self:banter()
            if not sc.cut and not self.end_early then
                self:moment(sc)
            end
        elseif i == 4 then
            self:scene_card(sc)
            if self.rng:chance(0.6) then
                self:banter()
            end
        end
        self:table_life()
    end
    self:scene_card(sc)
    -- The track sets up the big moment: ahead makes it easier, behind makes it harder.
    sc.edge = (sc.progress.wins >= need) and -2 or ((sc.progress.setbacks >= beats.setbacks) and 2 or 0)
    -- Your own read on the scene: an aside for the log, not something the table hears (A2).
    if sc.edge < 0 then
        self:say("They've done the groundwork. The big moment is within reach.", "aside")
    elseif sc.edge > 0 then
        self:say("Too many setbacks. The big moment will be hard now.", "aside")
    end
end

-- Little things that happen around the table between beats: snacks, phones, yawns.
function M:table_life()
    if not self.rng:chance(0.3) then
        return
    end
    if self:table_behavior("idle") then
        return
    end
    local low = self:lowest()
    if low and low.engagement < 0.25 and self.rng:chance(0.6) then
        self:react({ [low.key] = "phone" })
        self:bark(low, "phone")
    elseif low and low.engagement < 0.38 and self.rng:chance(0.5) then
        self:bark(low, "bored")
    else
        local p = self.rng:pick(self.players)
        self:bark(p, "snack")
    end
end

-- Players being players (A12) -----------------------------------------------------------------
-- What real players do out of character at the table, at the moment it fits (the research in
-- game/data/table_behaviors.lua): one line, from whoever at the table would do it, now and
-- then. A few a night, never the same behavior twice in a night, never the same line twice
-- in three weeks.
local TB_CHANCE = { start = 0.8, idle = 0.45, after_crit = 0.55, after_fail = 0.3, combat = 0.35, social = 0.35,
                    rules = 0.6, long_scene = 0.4, late = 0.5, ["end"] = 0.6 }
local TB_MAX = 7
local TB_POSE = { rules_lookup = "think", technically_actually = "arms", analysis_paralysis = "think",
                  theory_build = "think", plan_overload = "think", map_drawer = "think", note_taker = "think",
                  in_character_spat = "arms", dont_split_party = "arms", meme_share = "phone", stretch_break = "yawn",
                  getting_late = "yawn", wild_theory = "think", hp_fishing = "think", check_dm_math = "think",
                  spell_lookup_midturn = "phone", teach_new_player = "lean" }
M.TB_MAX = TB_MAX

local function class_ok(b, p)
    if b.not_class and p.class == b.not_class then
        return false
    end
    if not b.class then
        return true
    end
    if type(b.class) == "table" then
        return util.contains(b.class, p.class)
    end
    return p.class == b.class
end

local function arch_weight(arch, p)
    if not arch or arch == "any" then
        return 1
    elseif p.primary == arch then
        return 3
    elseif p.secondary == arch then
        return 1.5
    end
    return 0
end

-- Does this behavior fit the moment (the scene, the place, who's in it)?
function M:behavior_fits(b, sc, week)
    if b.min_week and week < b.min_week then
        return false
    end
    if b.scenes and not (sc and util.contains(b.scenes, sc.type)) then
        return false
    end
    if b.where and not content.fits_setting(b, sc and sc.comps.location) then
        return false
    end
    if b.needs == "cast" or b.needs == "met_before" then
        local cast = sc and sc.comps.cast
        if not cast or self:muted(cast) or cast.talks == false or cast.revered then
            return false
        end
        if b.needs == "met_before" then
            local lp = ledger.person(self.campaign, ledger.person_of(cast))
            local met = lp and lp.met
            if not (met == true or (type(met) == "number" and met < week)) then
                return false
            end
        end
    elseif b.needs == "cliff" then
        return self.ended_on_cliff or self.end_early or false
    end
    return true
end

function M:table_behavior(when, roller, sure)
    self.tb = self.tb or { n = 0, used = {}, hooks = {} }
    local tb = self.tb
    local sc = self.scene
    local hook = when .. ":" .. (sc and sc.index or 0)
    if tb.n >= TB_MAX or tb.hooks[hook] or #self.players == 0 then
        return nil
    end
    if not sure and not self.rng:chance(TB_CHANCE[when] or 0.3) then
        return nil
    end
    -- A long stretch with nothing for the DM to do: table chatter keeps it brisk (the nights gate).
    if self:idle() > 75 and when ~= "start" and when ~= "rules" then
        return nil
    end
    -- Out of calls for the night: the last stretch runs without you, so keep it short.
    if self:decision_count() >= 13 and when ~= "after_crit" and when ~= "rules" then
        return nil
    end
    local camp = self.campaign
    camp.tb_said = camp.tb_said or {}
    local week = camp.week or 1
    local cands, weights = {}, {}
    for _, b in ipairs(content.table_behaviors) do
        if b.when == when and not tb.used[b.id] and self:behavior_fits(b, sc, week)
            and (not b.style or b.style == (self.campaign.style or "frontier")) then
            local free = {}
            for i in ipairs(b.lines) do
                local last = camp.tb_said[b.id .. "#" .. i]
                if not last or week - last >= 3 then
                    table.insert(free, i)
                end
            end
            if #free > 0 then
                for _, p in ipairs(self.players) do
                    local w = arch_weight(b.archetype, p)
                    if not class_ok(b, p) then
                        w = 0
                    elseif b.by == "roller" and p ~= roller then
                        w = 0
                    elseif b.by == "other" and (not roller or p == roller) then
                        w = 0
                    elseif b.mood == "engaged" and p.engagement < 0.4 then
                        w = 0
                    elseif b.mood == "bored" and p.engagement >= 0.45 then
                        w = 0
                    end
                    if w > 0 then
                        table.insert(cands, { b = b, p = p, free = free })
                        table.insert(weights, w)
                    end
                end
            end
        end
    end
    if #cands == 0 then
        return nil
    end
    local c = self.rng:weighted(cands, weights)
    local b, p = c.b, c.p
    local i = self.rng:pick(c.free)
    tb.n = tb.n + 1
    tb.used[b.id] = true
    tb.hooks[hook] = true
    camp.tb_said[b.id .. "#" .. i] = week
    local text = util.fill(b.lines[i], self:vars({ other_char = roller and roller.char or "" }))
    local pose = TB_POSE[b.id] or (b.mood == "bored" and "yawn")
        or (string.find(b.effect or "", "^fun%+") and "laugh") or (b.by == "other" and "cheer") or "lean"
    self:react({ [p.key] = pose })
    self:emit({ kind = "say", who = p.key, text = text, ic = false, line = "tb_" .. b.id, behavior = b.id })
    -- What it does to the table.
    local meter, sign, target = string.match(b.effect or "", "^(%a+)([%+%-]) (%a+)$")
    if meter then
        local amount = (target == "speaker" and 3 or 2) * (sign == "+" and 1 or -1)
        if target == "speaker" then
            score.add(p, meter, amount)
        else
            for _, q in ipairs(self.players) do
                if not (meter == "boredom" and q == p) then
                    score.add(q, meter, amount)
                end
            end
        end
    end
    table.insert(self.behaviors, b.id)
    return b.id
end

-- The players go off the map (A12): a curveball card, at most one a night, when someone at the
-- table is the type to do it and the scene allows it.
local FOE_KIND = { goblin_boss = "humanoid", goblin_warrior = "humanoid", bandit_captain = "humanoid", bandit = "humanoid",
                   tough = "humanoid", cultist = "humanoid", dire_wolf = "beast", wolf = "beast", ghoul = "undead",
                   skeleton = "undead", zombie = "undead", ogre = "giant" }
M.FOE_KIND = FOE_KIND

function M:foe_kind(sc)
    local ids = sc and sc.plan and sc.plan.ids
    return ids and FOE_KIND[ids[1]] or nil
end

function M:curveball(sc, chance)
    if self.curveball_done or self.end_early or self:decision_count() >= 13 or not self.rng:chance(chance or 0.25) then
        return false
    end
    local camp = self.campaign
    local week = camp.week or 1
    local eligible, weights = {}, {}
    for _, card in ipairs(content.curveballs) do
        local ok = not (camp.cards_once and camp.cards_once[card.id]) and not self.used_cards[card.id]
            and (card.scenes == nil or util.contains(card.scenes, sc.type))
            and content.fits_setting(card, sc.comps.location)
            and (not card.foes or card.foes == self:foe_kind(sc))
            and self:behavior_fits({ needs = card.needs }, sc, week)
        if ok then
            local w = 0
            for _, p in ipairs(self.players) do
                w = math.max(w, arch_weight(card.actor[1], p))
            end
            if w >= 1.5 then
                table.insert(eligible, card)
                table.insert(weights, w)
            end
        end
    end
    if #eligible == 0 then
        return false
    end
    self.curveball_done = true
    self.actor = nil
    self:decision(self.rng:weighted(eligible, weights))
    return true
end

-- Before a fight, a hero tries something flashy (A12): a quick check; a win gives the party the
-- first move. Which stunt depends on what they're up against and who's at the table.
function M:stunt(sc)
    local camp = self.campaign
    camp.stunts_said = camp.stunts_said or {}
    local week = camp.week or 1
    local kind = self:foe_kind(sc)
    local cands, weights = {}, {}
    for i, st in ipairs(content.stunts) do
        local last = camp.stunts_said[i]
        if (not st.foes or st.foes == kind) and content.fits_setting(st, sc.comps.location) and (not last or week - last >= 3) then
            for _, p in ipairs(self.players) do
                local w = arch_weight(st.archetype, p)
                if w > 0 and class_ok(st, p) then
                    table.insert(cands, { st = st, p = p, i = i })
                    table.insert(weights, w * 2 ^ (util.clamp(self:mod_for(p, st.skill), -2, 8) / 4))
                end
            end
        end
    end
    if #cands == 0 then
        return nil
    end
    local c = self.rng:weighted(cands, weights)
    local st, p = c.st, c.p
    camp.stunts_said[c.i] = week
    self.actor = p
    self.other = st.other and self:pick_actor(nil, p) or nil
    local vars = self:vars({ char = p.char, other_char = self.other and self.other.char or "" })
    self:emit({ kind = "say", who = p.key, text = util.capitalize(util.fill(st.say, vars)), ic = true })
    local mod = self:mod_for(p, st.skill)
    local dc = 12 + util.clamp((sc.difficulty or 2) - 2, -1, 2)
    local roll = self.rng:d20()
    local total = roll + mod
    local success = total >= dc
    local name = skills.name(st.skill)
    local result = roll == 20 and "natural 20" or (roll == 1 and "natural 1" or (success and "success" or "miss"))
    self:emit({ kind = "check", text = p.char .. ": " .. name .. " " .. util.int(roll) .. skills.signed(mod) .. " = "
                    .. util.int(total) .. " vs DC " .. util.int(dc) .. ", " .. result,
                roll = roll, bonus = mod, total = total, dc = dc, success = success, actor = p.key, char = p.char,
                skill = st.skill, skill_name = name, crit = roll == 20, fumble = roll == 1 })
    self:say(util.capitalize(util.fill(success and st.win or st.lose, vars)), success and "good" or "bad")
    if success then
        sc.surprise = (sc.surprise == "party") and nil or "foes"
        score.add(p, "spotlight", 6)
        score.add(p, "fun", 3)
        self:react({ [p.key] = "cheer" })
        if roll == 20 then
            self:highlight(7, p.char .. " pulls off a stunt nobody will forget", { p }, "stunt")
        end
    else
        score.add(p, "spotlight", 2)
        for _, q in ipairs(self.players) do
            score.add(q, "fun", 1)
        end
        self:react({ [p.key] = "gasp" })
    end
    table.insert(self.checks, success)
    return success
end

-- Heroic Inspiration (M8, B4): one token a night, flicked across the table after a great
-- moment. Giving it to the same player twice inside three sessions, the rest of the table
-- notices.
M.FAIR_WINDOW = 3
function M:give_inspiration(p)
    self.inspiration_given = p.key
    p.heroic = true
    local camp = self.campaign
    camp.inspired_log = camp.inspired_log or {}
    local again = false
    for _, e in ipairs(camp.inspired_log) do
        again = again or (e.key == p.key and camp.week - e.week < M.FAIR_WINDOW)
    end
    table.insert(camp.inspired_log, { key = p.key, week = camp.week })
    score.add(p, "spotlight", 6)
    score.add(p, "fun", 4)
    self:react({ [p.key] = "cheer" })
    self:emit({ kind = "token", who = p.key, what = "inspiration" })
    self:say("You flick the Heroic Inspiration token across the table. It lands in front of " .. p.name .. ".", "dm")
    self:event("inspiration", { who = p.key, text = p.char .. " earned Heroic Inspiration." })
    if again then
        self:fairness_noticed(p, "inspiration")
    end
end

-- The killing blow (M8, B4). Who's waited longest for one: the player with the fewest killing
-- blows in the window, not counting whoever landed this one.
function M:killing_blow_other(actor, villain)
    local camp = self.campaign
    -- The one who wants this villain most (Vendetta 3 or more) gets first refusal.
    local wants = villains.wants_it(self, villain, actor)
    if wants then
        return wants
    end
    local count = {}
    for _, e in ipairs(camp.killing_blows or {}) do
        if camp.week - e.week < content.killing_blows.WINDOW then
            count[e.key] = (count[e.key] or 0) + 1
        end
    end
    local best
    for _, p in ipairs(self.players) do
        if p ~= actor and (not best or (count[p.key] or 0) < (count[best.key] or 0)
            or ((count[p.key] or 0) == (count[best.key] or 0) and p.m.spotlight < best.m.spotlight)) then
            best = p
        end
    end
    return best
end

function M:killing_blow(p, tgt, boss_name)
    local camp = self.campaign
    camp.killing_blows = camp.killing_blows or {}
    if not p then
        self:event("villain_falls", { who = "party", text = boss_name .. " falls.", weight = 8 })
        return
    end
    local kb = content.killing_blows
    local again = false
    for _, e in ipairs(camp.killing_blows) do
        again = again or (e.key == p.key and camp.week - e.week < kb.WINDOW)
    end
    table.insert(camp.killing_blows, { key = p.key, week = camp.week, boss = boss_name })
    -- The line: their class's, flavoured for their kind of player when there's one.
    local lines = kb[p.class] or kb.fighter
    local pool = {}
    for _, l in ipairs(lines) do
        if l.arch == p.primary or l.arch == p.secondary then
            table.insert(pool, l)
        end
    end
    if #pool == 0 or self.rng:chance(0.3) then
        pool = lines
    end
    local line = util.fill(pool[self.rng:int(1, #pool)][1], self:vars({ boss = boss_name, char = p.char }))
    -- The final hit answers the villain's taunt, if they taunted this player (the retort).
    local pid = tgt and tgt.person
    local retort = pid and villains.retort(self, pid, p)
    if retort then
        line = retort
    end
    -- A villain with a Grudge falls harder (B6), and harder still for whoever wants them most.
    local grudge = ledger.grudge_level and ledger.grudge_level(camp, pid) or 0
    local vscale, waive = villains.vendetta_blow(self, pid, p)
    local scale = (1 + 0.25 * grudge) * vscale
    if waive then
        again = false        -- the table understands: it was theirs to take
    end
    score.add(p, "spotlight", kb.SPOTLIGHT * scale)
    score.add(p, "fun", kb.FUN * scale)
    self:react({ [p.key] = "cheer" })
    self:emit({ kind = "say", who = p.key, text = line, ic = true })
    self:highlight(math.min(10, 8 + grudge), p.char .. " lands the killing blow on " .. boss_name, { p }, "killing_blow")
    if again then
        self:fairness_noticed(p, "killing_blow")
    end
end

-- Favouring one player in a short window (the killing blow, Inspiration): the others notice.
function M:fairness_noticed(p, what)
    local q = self:pick_actor({ "casual", "tactician", "storyteller" }, p)
    for _, o in ipairs(self.players) do
        if o ~= p then
            score.add(o, "fun", -2)
            score.add(o, "trust", -1)
        end
    end
    if q then
        self:emit({ kind = "say", who = q.key, text = what == "inspiration" and ("Again? " .. p.char .. " got it last time too.")
            or ("That's " .. p.char .. "'s second big finish in a row, just saying."), ic = false })
    end
    self:event("unfair", { who = p.key, text = "The table noticed " .. p.name .. " getting the " .. (what == "inspiration"
        and "Inspiration" or "killing blow") .. " again.", weight = 3 })
end

-- Has a headache's situation actually happened (M8, B4)? needs:
--   been = settings     a scene at a place like that tonight (or now);  or_type = scene types
--   players = n         at least n at the table;  archetype = { ... } someone like that here
--   setbacks = n        this scene has gone wrong n times;  first_scene: the night's start
--   after_break         a break (pizza, snacks) happened tonight;  before_fight: a fight's coming
function M:headache_ok(needs, sc)
    if needs.players and #self.players < needs.players then
        return false
    end
    if needs.archetype then
        local any = false
        for _, p in ipairs(self.players) do
            any = any or util.contains(needs.archetype, p.primary) or util.contains(needs.archetype, p.secondary)
        end
        if not any then
            return false
        end
    end
    if needs.setbacks and not (sc and sc.progress and sc.progress.setbacks >= needs.setbacks) then
        return false
    end
    if needs.first_scene and not (sc and sc.index == 1) then
        return false
    end
    if needs.after_break and not self.had_break then
        return false
    end
    if needs.before_fight and not (sc and (sc.type == "combat" or sc.type == "set_piece") and not sc.result) then
        return false
    end
    if needs.been then
        local ok = false
        for _, s2 in ipairs(self.scenes) do
            if s2 == sc or s2.outcome then
                local loc = s2.comps and s2.comps.location
                for _, set in ipairs(loc and loc.setting or {}) do
                    ok = ok or util.contains(needs.been, set)
                end
                ok = ok or (needs.or_type and util.contains(needs.or_type, s2.type))
            end
        end
        if not ok then
            return false
        end
    end
    return true
end

-- What a person in a scene is, from their card's data (A11: roles come from the cast data, so the
-- abbot is never "the villain"): "hostile" is someone set against the party, a villain or a foe,
-- who can talk.
function M.cast_is(cast, what)
    if not cast then
        return false
    end
    if what == "hostile" then
        return (cast.villain or cast.foe) and cast.talks ~= false and not cast.revered and true or false
    end
    return false
end

function M:shown_cast(sc)
    local c = sc and sc.comps and sc.comps.cast
    return c and not self:muted(c) and c or nil
end

function M:pick_decision(sc, kinds)
    local eligible, weights = {}, {}
    local last = self.campaign.last_cards or {}
    for _, d in ipairs(content.decisions) do
        local camp = self.campaign
        local settled = (d.type == "rules" and camp.house_rules and camp.house_rules[d.id])   -- A5: asked once
            or (d.once and camp.cards_once and camp.cards_once[d.id])
        if not settled and not d.table_only and not self.used_cards[d.id] and (d.scenes == nil or util.contains(d.scenes, sc.type))
            and (not kinds or kinds[d.type]) and content.fits_setting(d, sc.comps.location)
            and not (d.unnamed_keeper and sc.comps.location and sc.comps.location.keeper)
            and (not d.actor_class or self:by_class(d.actor_class))
            and (not d.needs_class or self:by_class(d.needs_class))
            and (not d.needs_cast or M.cast_is(self:shown_cast(sc), d.needs_cast))
            and (not d.needs or self:headache_ok(d.needs, sc)) then
            local w = last[d.id] and 0.3 or 1
            -- Prefer cards whose actor is actually at the table.
            for _, a in ipairs(d.actor or {}) do
                for _, p in ipairs(self.players) do
                    if p.primary == a then
                        w = w + 0.5
                    end
                end
            end
            table.insert(eligible, d)
            table.insert(weights, w)
        end
    end
    if #eligible == 0 then
        return nil
    end
    return self.rng:weighted(eligible, weights)
end

-- Big rolls and rulings -----------------------------------------------------------------------

-- How a check landed: a natural 20 or beating the DC by 5 is a triumph, a natural 1 or
-- missing by 5 a flop.
local function tier_of(total, dc, natural)
    if natural == 20 or total >= dc + 5 then
        return "triumph"
    elseif total >= dc then
        return "success"
    elseif natural == 1 or total <= dc - 5 then
        return "flop"
    end
    return "near"
end

-- Big rolls are checks the table stops for. Raw DCs in the card data are on the old d20-only
-- scale; a hero adds their modifier now, so the DC the DM sets is this much higher.
M.DC_SHIFT = 4

-- A big moment's check. Normally the hero's player rolls it themselves, in front of everyone:
-- the DM decides whether to say the DC out loud or keep it behind the screen, where it could
-- quietly move after the die lands (that's cooking it). spec.secret: a secret check the DM
-- rolls for them behind the screen (a Perception check they mustn't know about); then the DM
-- rolls it in the open or hidden, and a hidden die can be misread.
function M:big_roll(spec, record)
    local p = self.actor or self:pick_actor(nil)
    self.actor = p
    self.big_rolls = self.big_rolls or {}
    if p then
        self.big_rolls[p.key] = (self.big_rolls[p.key] or 0) + 1
    end
    local skill, mod = self:best_skill(p, spec.skill or { "perception" })
    local near_bonus = p and self.edge_next and self.edge_next[p.key]
    if near_bonus then
        mod = mod + near_bonus   -- last time was a near miss (B2)
        self.edge_next[p.key] = nil
    end
    local dc = spec.dc + M.DC_SHIFT
    local by = spec.secret and "dm" or "player"
    local name = skills.name(skill)
    local text
    if by == "player" then
        text = util.fill("{actor_char} rolls " .. name .. " (" .. skills.signed(mod) .. "). You'd set the DC at {dc}.",
            self:vars({ dc = util.int(dc) }))
    else
        text = util.fill("A secret " .. name .. " check for {actor_char} (" .. skills.signed(mod) .. "), DC {dc}. You roll it for them.",
            self:vars({ dc = util.int(dc) }))
    end
    local where = self:emit({ kind = "roll_where", dc = dc, text = text, actor = p and p.key, char = p and p.char,
                              skill = skill, skill_name = name, mod = mod, by = by })
    if where ~= "hidden" then
        where = "open"
    end
    if where == "open" and self.rng:chance(0.35) then
        self:bark(self:pick_actor(nil), "open_roll")
    end
    local value = self:emit({ kind = "roll", where = where, dc = dc, actor = p and p.key, by = by,
                              skill_name = name, mod = mod })
    value = util.clamp(math.floor(tonumber(value) or self.rng:d20()), 1, 20)
    -- Advantage from an item the hero carries (A13): a second die, the better one counts.
    if p then
        local iedge, iname = require("game.model.items").check_edge(self.campaign, p.key, skill)
        if iedge then
            local second = self.rng:d20()
            if second > value then
                self:say(util.fill("{actor_char} rolls again with Advantage (" .. iname .. "): " .. util.int(second)
                    .. " beats " .. util.int(value) .. ".", self:vars()), "aside")
                value = second
            end
        end
    end
    -- Heroic Inspiration (B4): a player holding the token rerolls a miss and keeps the new roll.
    if p and p.heroic and by == "player" and value + mod < dc then
        local new = self.rng:d20()
        p.heroic = nil
        self:emit({ kind = "say", who = p.key, text = "Wait, I've got inspiration. I'm using it.", ic = false })
        self:say(util.fill("{actor_char} spends Heroic Inspiration: the " .. util.int(value) .. " becomes a " .. util.int(new)
            .. ", and that's the roll.", self:vars()), "dice")
        self:event("inspiration", { who = p.key, text = p.char .. " spent Heroic Inspiration on a big roll.", spent = true })
        self:emit({ kind = "token", who = p.key, what = "inspiration", spent = true })
        value = new
    end
    local total = value + mod
    local success = total >= dc
    local reported, shown_dc = value, dc
    local cooked = false
    if where == "hidden" then
        self.rolls.hidden = self.rolls.hidden + 1
    else
        self.rolls.open = self.rolls.open + 1
        -- Doing it in the open builds Trust, less so when the table expects nothing else.
        local dice = self.campaign.table and self.campaign.table.rules.dice
        local gain = dice == "open" and 0.5 or 1
        for _, q in ipairs(self.players) do
            score.add(q, "trust", (1 + q.perception) * gain)
            score.add(q, "suspicion", -3)
        end
    end
    if where == "hidden" and self.campaign.table and self.campaign.table.rules.dice == "open" then
        -- Session Zero said everything happens in the open.
        for _, q in ipairs(self.players) do
            score.add(q, "trust", -1.5)
            self:suspect(q, 2 * q.perception, "a hidden roll when you'd agreed to roll in the open")
        end
        if not self.promise_noted.dice then
            self.promise_noted.dice = true
            self:say("A few eyebrows go up. You agreed everything would happen in the open.", "warn")
        end
    end
    -- The ruling, on one card (A11, B2's fold): the die sets the tier and the DM decides how generous
    -- to be. Behind the screen the same card offers to overrule the die (cooking it), so nobody asks
    -- "how close" twice. Answer a ruling option's number, or "cook".
    local tier = tier_of(total, dc, value)
    local rule = content.rulings[tier]
    local opts = {}
    for i, o in ipairs(rule.options) do
        opts[i] = { label = o.label, tone = o.tone }
    end
    -- A miss deals the fail fan (M8, B2): three cards fitted to the scene, the flat fail, and the
    -- player's own idea when they trust you enough. Success rulings stay as they were.
    local fan
    if (tier == "near" or tier == "flop") and p then
        fan = fails_mod.fan(self, p, skill, self.scene, tier, spec.act)
        opts = {}
        for i, c in ipairs(fan) do
            opts[i] = { label = c.label, tone = c.tone, kind = c.kind }
        end
    end
    -- A great roll can earn Heroic Inspiration (B4): the token, flicked across the table, one a
    -- night, folded into this card rather than a card of its own.
    local inspire_at
    if tier == "triumph" and p and by == "player" and not self.inspiration_given and not p.heroic then
        table.insert(opts, { label = "Yes, and... flick " .. p.char .. " the Heroic Inspiration token.", tone = "good" })
        inspire_at = #opts
    end
    local cook_offer
    if where == "hidden" then
        local to = success and "a miss" or "a success"
        cook_offer = {
            to_success = not success,
            label = by == "player" and ("Move the DC: say it was " .. (success and "higher. A miss." or "lower. A success."))
                or ("Cook it: call it " .. to .. "."),
            note = by == "player" and "Nobody else knows the DC. Someone might wonder." or "Nobody else saw the die. Someone might notice.",
        }
    end
    local pick
    if self:decision_count() >= 15 and not inspire_at then
        -- Out of calls for the night (the 8-to-15 budget): the die decides, plainly, with no card.
        pick = 1
        self.auto_rulings = (self.auto_rulings or 0) + 1
    else
        pick = self:emit({ kind = "ruling", tier = tier, prompt = fan and "How does it go wrong?" or rule.prompt, value = value,
                           total = total, fan = fan ~= nil,
                           mod = mod, dc = dc, options = opts, where = where, by = by, success = success,
                           cook = cook_offer, cooks = self.cooks,
                           char = p and p.char, skill_name = name, actor = p and p.key })
    end
    if cook_offer and (pick == "cook" or pick == true) then
        cooked = true
        success = not success
        if by == "player" then
            -- Everyone saw the die. What moves is the DC nobody heard.
            if success then
                shown_dc = math.max(1, total - self.rng:int(0, 2))
            else
                shown_dc = total + self.rng:int(1, 3)
            end
        else
            if success then
                reported = util.clamp(dc - mod + self.rng:int(0, 3), 1, 20)
            else
                reported = util.clamp(dc - mod - self.rng:int(1, 4), 1, 20)
            end
        end
        -- A cooked result lands plainly on the side the DM chose.
        tier = success and "success" or "near"
        rule = content.rulings[tier]
        pick = 1
        for i, o in ipairs(rule.options) do
            if o.success == success and not o.tone then
                pick = i
            end
        end
        fan = nil
    end
    local card
    if fan then
        card = fan[util.clamp(math.floor(tonumber(pick) or 1), 1, #fan)]
        pick = 1
    end
    if inspire_at and tonumber(pick) == inspire_at then
        self:give_inspiration(p)
        pick = 1
    end
    pick = util.clamp(math.floor(tonumber(pick) or 1), 1, #rule.options)
    local reported_total = reported + mod
    local line
    if by == "player" then
        line = (p and p.char or "They") .. " rolls a " .. util.int(value) .. ", " .. skills.signed(mod) .. ": "
            .. util.int(reported_total) .. ". " .. (where == "open" and ("You said DC " .. util.int(shown_dc) .. ".")
            or ("Behind the screen, the DC was " .. util.int(shown_dc) .. "."))
    else
        line = (where == "open" and "Everyone watches the die land on " or "Behind the screen, the die says ")
            .. util.int(reported) .. ": " .. util.int(reported_total) .. " against DC " .. util.int(dc) .. "."
    end
    self:say(line, "dice")
    if cooked then
        self.rolls.cooked = self.rolls.cooked + 1
        self.cooks = self.cooks + 1
        self:event("cooked", { who = p and p.key or "party", text = "You cooked " .. ((p and by == "player") and (p.char .. "'s ") or "a ")
            .. name .. " roll behind the screen." })
        local convenient = (success and spec.convenient == "success") or (not success and spec.convenient == "fail")
        self:add_cook_suspicion(convenient, skill and (skills.name(skill) .. " roll") or "roll")
    end
    -- A third lucky break in a row looks convenient even when it's honest.
    if success and where == "hidden" then
        self.lucky_streak = self.lucky_streak + 1
        if self.lucky_streak >= 3 then
            for _, q in ipairs(self.players) do
                self:suspect(q, 2 * q.perception, "three lucky breaks in a row behind the screen")
            end
        end
    elseif not success then
        self.lucky_streak = 0
    end
    local ro = rule.options[pick]
    if card then
        -- The fail card picked: it says which branch plays, and how the table takes it.
        success = fails_mod.play(self, p, card, fan, tier)
        ro = { tone = card.kind ~= "flat" and card.tone ~= "twist" and card.tone or nil, effects = {},
               fail_line = card.kind ~= "flat" and card.text or nil }
    end
    table.insert(self.rulings, { tier = tier, option = pick, cooked = cooked, fail = card and card.kind })
    if ro.success ~= nil and ro.success ~= success then
        -- "Yes, at a cost" on a near miss: the success branch plays.
        success = ro.success
    end
    local branch = success and spec.success or spec.fail
    -- How the fail card says it went, then what it means (the story playtest: "They've been seen"
    -- followed by a near-miss line read as two different stories). A plain check's fail line says
    -- it all on its own.
    if ro.fail_line and not success then
        self:say(ro.fail_line, "bad")
        if not spec.fail_replaces then
            self:say(branch.log, "bad")
        end
    else
        self:say(branch.log, success and "good" or "bad")
        if ro.fail_line then
            self:say(ro.fail_line, "twist")
        end
    end
    self:apply(branch.effects)
    self:apply(ro.effects)
    if ro.tone == "good" then
        self:react({ [self.actor and self.actor.key or self.players[1].key] = "cheer" })
        self:bark(self.actor, "ruling_good")
    elseif ro.tone == "bad" then
        local poses = {}
        for _, q in ipairs(self.players) do
            poses[q.key] = "gasp"
        end
        self:react(poses)
        self:bark(self:pick_actor({ "butt_kicker", "instigator" }), "ruling_bad")
    elseif ro.tone == "twist" then
        self:say(ro.log, "twist")
    end
    if success and self.actor and not spec.quiet then
        self:highlight(6, M.moment_of(util.fill(branch.log, self:vars())), { self.actor })
    end
    local rec = record or (self.decisions[#self.decisions] and self.decisions[#self.decisions].rolls)
    if rec then
        table.insert(rec, { where = where, value = value, cooked = cooked, success = success, tier = tier, ruling = pick,
                            skill = skill, mod = mod, dc = shown_dc, by = by })
    end
    if by == "player" and p then
        if reported == 20 then
            self:table_behavior("after_crit", p)
        elseif not success and (reported == 1 or tier == "flop") then
            self:table_behavior("after_fail", p)
        end
        if value == 1 then
            fails_mod.jail(self, p)   -- B2: the die that rolled a 1 goes to dice jail
        end
    end
    if cooked then
        self:maybe_callout(0.35)
    end
    return success
end

function M:add_cook_suspicion(convenient, what)
    local why = convenient and ("the cooked " .. (what or "roll") .. " that went the party's way")
        or ("the " .. (what or "roll") .. " you cooked behind the screen")
    for _, p in ipairs(self.players) do
        local s = 8 * p.perception * (convenient and 1.6 or 1) * (1 + 0.3 * (self.cooks - 1))
        self:suspect(p, s, why)
    end
    -- The sharpest eye at the table might say it under their breath.
    local sharp
    for _, p in ipairs(self.players) do
        if not sharp or p.perception > sharp.perception then
            sharp = p
        end
    end
    if sharp and sharp.suspicion > 30 and self.rng:chance(0.5) then
        self:react({ [sharp.key] = "arms" })
        self:bark(sharp, "suspicious")
    end
end

-- Someone suspicious enough says it out loud.
function M:maybe_callout(base)
    local worst
    for _, p in ipairs(self.players) do
        if not worst or p.suspicion > worst.suspicion then
            worst = p
        end
    end
    if not worst or worst.suspicion < 45 then
        return
    end
    local chance = base + (worst.suspicion - 45) / 50
    if not self.rng:chance(chance) then
        return
    end
    self.callouts = self.callouts + 1
    self:react({ [worst.key] = "arms" })
    if not self:bark(worst, "callout") then
        self:emit({ kind = "say", who = worst.key, text = "Hang on. Can we see that roll?", ic = false })
    end
    -- It names its cause (A11): what they noticed.
    local why = self:suspicion_cause(worst)
    self:event("callout", { who = worst.key, text = worst.name .. " called out " .. (why or "a roll behind the screen") .. "." })
    self:say((why and (worst.name .. " noticed " .. why .. ". ") or "") .. "The table goes quiet. A few people look at your screen.",
        "warn")
    score.add(worst, "trust", -15)
    score.add(worst, "fun", -6)
    worst.suspicion = worst.suspicion * 0.5
    for _, p in ipairs(self.players) do
        if p ~= worst then
            score.add(p, "trust", -5)
        end
    end
    score.nudge_engagement(worst, -10)
end

-- Decision cards ---------------------------------------------------------------------------

-- Who at the table would enjoy these effects, and who wouldn't: { key = 1 | -1 }, the DM's
-- read of the table (strong feelings only).
function M:leans(effects)
    local gain = {}
    for _, eff in ipairs(effects or {}) do
        for _, t in ipairs(self:targets(eff[1])) do
            local p, scale = t[1], t[2]
            local g = gain[p] or {}
            for k, v in pairs(eff) do
                if k ~= 1 and type(v) == "number" then
                    g[k] = (g[k] or 0) + v * scale
                end
            end
            gain[p] = g
        end
    end
    local out = {}
    for p, g in pairs(gain) do
        local e = score.enjoyment(p, g)
        if e >= 4 then
            out[p.key] = 1
        elseif e <= -3 then
            out[p.key] = -1
        end
    end
    return out
end

-- The present player whose character has this class, if any.
function M:by_class(cls)
    for _, p in ipairs(self.players) do
        if p.class == cls then
            return p
        end
    end
end

-- Show a card, take the DM's pick, play it out. Returns the chosen option.
function M:decision(card, extra)
    self.used_cards[card.id] = true
    if card.actor_class and self:by_class(card.actor_class) then
        self.actor = self:by_class(card.actor_class)
        self.other = card.other and self:pick_actor(card.other, self.actor) or nil
    elseif not self.actor or not card.trigger then
        self.actor = self:pick_actor(card.actor)
        self.other = card.other and self:pick_actor(card.other, self.actor) or nil
    end
    -- A card with a roll in someone's own story scene goes to them first (A4); and nobody
    -- hogs the big rolls just because the card suits their style.
    if not card.actor_class and self.scene then
        local has_roll, roll_skill = false, nil
        for _, o in ipairs(card.options) do
            if o.roll then
                has_roll = true
                roll_skill = roll_skill or o.roll.skill
            end
        end
        if has_roll and self.actor then
            local br = self.big_rolls or {}
            local total = 0
            for _, n in pairs(br) do
                total = total + n
            end
            if total >= 3 and (br[self.actor.key] or 0) / total > 1 / #self.players + 0.06 then
                self.actor = self:pick_roller(roll_skill or { "perception" }, self.scene)
                if self.other == self.actor then
                    self.other = self:pick_actor(card.other, self.actor)
                end
            end
        end
        if has_roll then
            self.scene.owners_rolled = self.scene.owners_rolled or {}
            for _, c in pairs(self.scene.comps) do
                local owner = c.thread and not self:muted(c) and not self.scene.owners_rolled[c.thread]
                    and find_present(self.players, c.thread)
                if owner then
                    self.actor = owner
                    self.scene.owners_rolled[c.thread] = true
                    if self.other == owner then
                        self.other = self:pick_actor(card.other, owner)
                    end
                    break
                end
            end
        end
    end
    local vars = self:vars(extra)
    local view = {
        id = card.id,
        type = card.type,
        cast = card.cast, monster = card.monster,      -- who's speaking or acting (B8): their mini on the card
        type_name = content.decision_types[card.type],
        title = util.sentence_case(util.fill(card.title, vars)),
        text = util.sentence_case(util.fill(card.text, vars)),
        options = {},
    }
    for i, o in ipairs(card.options) do
        view.options[i] = { label = util.sentence_case(util.fill(o.label, vars)), roll = o.roll ~= nil, cooked = o.cooked,
                            skill = o.roll and o.roll.skill and skills.name(select(1, self:best_skill(self.actor or self.players[1], o.roll.skill))),
                            leans = self:leans(o.preview or o.effects) }
    end
    if card.type == "rules" and not self:table_behavior("rules") and self.rng:chance(0.7) then
        self:bark(self:pick_actor({ "tactician", "power_gamer" }), "rules_lawyer")
    end
    local pick = self:emit({ kind = "decision", card = view, actor = self.actor and self.actor.key })
    pick = util.clamp(math.floor(tonumber(pick) or 1), 1, #card.options)
    local o = card.options[pick]
    table.insert(self.decisions, { card = card.id, option = pick, rolls = {} })
    self.why = "your call on \"" .. card.title .. "\""
    if o.log then
        self:say(o.log, "dm", extra)
    end
    -- Breaks and lookups take real time at the table (A14).
    self.table_min = (self.table_min or 0) + (o.table_min or 0) + (o.looked and 8 or 0)
    if (o.table_min or 0) >= 10 then
        self.had_break = true   -- for the headaches that follow a break (B4)
    end
    if o.canon then
        table.insert(self.canon, util.fill(o.canon, self:vars(extra)))
    end
    if o.spotlight_lowest then
        local low = self:lowest()
        if low then
            if low.shy then
                score.add(low, "fun", -5)
                if not self:bark(low, "spotlight_shy") then
                    self:emit({ kind = "say", who = low.key, text = "Uh. I guess " .. low.char .. "... waves?", ic = false })
                end
            else
                score.add(low, "fun", 8)
                self:react({ [low.key] = "lean" })
                self:highlight(5, low.char .. " steals the scene", { low })
            end
        end
    end
    self:apply(o.effects)
    if o.cooked then
        -- Overruling a hidden die is cooking it.
        self.rolls.cooked = self.rolls.cooked + 1
        self.cooks = self.cooks + 1
        self:add_cook_suspicion(o.convenient, "ruling")
        self:maybe_callout(0.3)
    end
    -- A curveball before a fight (A12): talked out of it, or the party moves first.
    if o.skip_fight and self.scene then
        self.scene.skip_fight = true
    end
    if o.surprise and self.scene then
        self.scene.surprise = o.surprise
    end
    if o.cut and self.scene then
        self.scene.cut = true
        self:keep_promise("no_cut")
    end
    if o.cooked and (card.id == "death_roll" or card.id == "last_save") then
        self:keep_promise("open_death", self.actor)
        local tbl = self.campaign.table
        if tbl and tbl.rules.dice == "big_open" then
            -- You said the big moments happen in the open.
            for _, p in ipairs(self.players) do
                score.add(p, "trust", -2 * p.perception)
            end
        end
    end
    if card.conflict and o.conflict then
        local mv = { id = card.conflict }
        for k, v in pairs(o.conflict) do
            mv[k] = v
        end
        mv.topic = extra and extra.topic
        table.insert(self.conflict_moves, mv)
    end
    if card.type == "rules" and o.leans then
        table.insert(self.rules_calls, { card = card.id, leans = o.leans, looked = o.looked,
                                         topic = content.conflicts.rules_topics[card.id] })
    end
    -- A ruling becomes a house rule (A5): the question never comes back, and the notes list it.
    if card.type == "rules" then
        self.house_rules = self.house_rules or {}
        self.house_rules[card.id] = { title = card.title, ruling = util.fill(o.label or "", self:vars(extra)) }
    end
    if card.once then
        self.cards_once = self.cards_once or {}
        self.cards_once[card.id] = true
    end
    if o.cliffhanger then
        self.end_early = true
    end
    if o.roll then
        self:big_roll(o.roll)
    end
    if card.type == "rules" then
        self:conflict_rules(card)
    end
    return o
end

-- Session Zero promises (M6) ------------------------------------------------------------------

-- The DM just did something a player asked them not to at Session Zero.
function M:keep_promise(id, who)
    local tbl = self.campaign.table
    local key = tbl and tbl.promises[id]
    if not key then
        return
    end
    local p
    for _, q in ipairs(self.players) do
        if q.key == key then
            p = q
        end
    end
    if not p or (who and who ~= p) then
        return
    end
    if id == "open_death" then
        score.add(p, "trust", -8)
        self:suspect(p, 10, "a death save made behind the screen")
        self:react({ [p.key] = "arms" })
        self:say(p.name .. " noticed. At Session Zero he asked you never to save him behind the screen.", "warn")
    elseif id == "no_cut" then
        score.add(p, "trust", -4)
        score.add(p, "fun", -3)
        self:react({ [p.key] = "arms" })
        self:say(p.name .. "'s face falls. You promised not to cut her scenes short.", "warn")
    end
    table.insert(self.safety, { kind = "promise", id = id, key = p.key })
end

-- Lines and veils: a card on the table touches something a player raised at Session Zero.
-- Runs before any of the scene's cards are described (and again for anything improvised
-- mid-scene). A veiled card plays off screen and an X-carded one is skipped: either way its
-- description is muted. cards: the cards to check (default: the whole scene).
function M:safety_check(sc, cards)
    local tbl = self.campaign.table
    if not tbl or not sc then
        return
    end
    if not cards then
        cards = {}
        for _, kind in ipairs(content.kinds) do
            if sc.comps[kind] then
                table.insert(cards, sc.comps[kind])
            end
        end
    end
    sc.muted = sc.muted or {}
    sc.safety_done = sc.safety_done or {}
    local xcard = tbl.rules.xcard == "on"
    for _, f in ipairs(social.content_flags(self.campaign, cards)) do
        local p
        for _, q in ipairs(self.players) do
            if q.key == f.key then
                p = q
            end
        end
        if p then
            local done = sc.safety_done[f.tag]
            local outcome
            if f.kind == "veil" then
                outcome = "veil"
            elseif xcard then
                outcome = "xcard"
            else
                outcome = "hurt"
            end
            if outcome ~= "hurt" then
                sc.muted[f.card.id] = true
            end
            if not done then
                sc.safety_done[f.tag] = outcome
                local what = f.tag == "kids" and "the kids" or f.tag
                if outcome == "veil" then
                    -- Agreed at Session Zero: it happens off screen.
                    self:say("You keep " .. what .. " off screen, like you promised " .. p.name .. ".", "dm")
                    score.add(p, "trust", 1)
                    table.insert(self.safety, { kind = "veil", key = p.key, tag = f.tag })
                elseif outcome == "xcard" then
                    self:react({ [p.key] = "arms" })
                    self:say(p.name .. " taps the X-card. You skip it, no questions asked, and the scene moves on.", "system")
                    score.add(p, "fun", -2)
                    score.add(p, "trust", f.kind == "line" and -3 or 1)
                    table.insert(self.safety, { kind = "xcard", key = p.key, tag = f.tag, broke = f.kind == "line" })
                else
                    self:react({ [p.key] = "arms" })
                    if f.kind == "line" then
                        self:say(p.name .. " goes quiet. She drew a line at this at Session Zero.", "warn")
                        score.add(p, "trust", -10)
                        score.add(p, "commitment", -3)
                    else
                        self:say(p.name .. " goes quiet. They asked you about this at Session Zero.", "warn")
                        score.add(p, "trust", -4)
                        score.add(p, "commitment", -2)
                    end
                    score.add(p, "fun", -8)
                    score.add(p, "boredom", 6)
                    table.insert(self.safety, { kind = "hurt", key = p.key, tag = f.tag, broke = f.kind == "line" })
                end
            end
        end
    end
end

-- Is this card's description skipped tonight (veiled or X-carded)?
function M:muted(c)
    local sc = self.scene
    return c ~= nil and sc ~= nil and sc.muted ~= nil and sc.muted[c.id] == true
end

-- Table conflicts at the table (M6) -------------------------------------------------------

local function find(players, key)
    for _, p in ipairs(players) do
        if p.key == key then
            return p
        end
    end
end

local function live(self, id)
    local c = self.campaign.conflicts and self.campaign.conflicts[id]
    return c and social.is_live(c) and not self.conflict_dealt[id] and c
end

-- Pip fills a scene: the spotlight conflict's card.
function M:conflict_spotlight(sc)
    local c = live(self, "spotlight")
    local jess = find(self.players, "jess")
    if not c or not jess or #self.players < 3 or not self:room(13) then
        return
    end
    if not self.rng:chance(c.state == "active" and 0.9 or 0.65) then
        return
    end
    self.conflict_dealt.spotlight = true
    self.actor, self.other = jess, nil
    self:decision(content.triggered.conflict_spotlight)
end

-- A joke lands in Mara's serious moment: the tone conflict's card.
function M:conflict_tone(sc)
    local c = live(self, "tone")
    local mara, jess = find(self.players, "mara"), find(self.players, "jess")
    if not c or not mara or not jess or not self:room(13) then
        return
    end
    if not self.rng:chance(c.state == "active" and 0.95 or 0.8) then
        return
    end
    self.conflict_dealt.tone = true
    self.actor, self.other = mara, jess
    self:decision(content.triggered.conflict_tone)
end

-- After a rules call: Dev and Sam start arguing about it.
function M:conflict_rules(card)
    local c = live(self, "rules")
    local dev, sam = find(self.players, "dev"), find(self.players, "sam")
    if not c or not dev or not sam or not self:room(13) then
        return
    end
    if not self.rng:chance(c.state == "active" and 0.85 or 0.5) then
        return
    end
    self.conflict_dealt.rules = true
    local topic = content.conflicts.rules_topics[card.id] or "the rules"
    self.actor, self.other = dev, sam
    self:decision(content.triggered.conflict_rules, { topic = topic })
end

-- Seeds (M6) -----------------------------------------------------------------------------------

function M:plant_seed()
    local def = self.planted and content.seeds[self.planted]
    if not def then
        return
    end
    self:say(def.plant, "seed")
    local poses = {}
    local fans = {}
    for _, p in ipairs(self.players) do
        if seeds.is_fan(p, def) then
            poses[p.key] = "lean"
            table.insert(fans, p)
            score.add(p, "story", 3)
        end
    end
    self:react(poses)
    if #fans > 0 then
        self:bark(self.rng:pick(fans), "seed_planted", { seed = def.theory })
    end
end

-- This week's story cards (M7): the arc moves when one hits the table.
function M:story_beat(sc)
    local arc_cards = self.prep and self.prep.arc_cards
    if not arc_cards then
        return
    end
    self.story_hits = self.story_hits or {}
    for _, kind in ipairs(content.kinds) do
        local c = sc.comps[kind]
        if c and arc_cards[c.id] and not self:muted(c) and not util.contains(self.story_hits, c.id) then
            table.insert(self.story_hits, c.id)
            if #self.story_hits == 1 then
                -- The first one each night: the people who came for the story notice.
                local fans = {}
                for _, p in ipairs(self.players) do
                    if score.arch(p, "storyteller") + score.arch(p, "explorer") > 0 then
                        score.add(p, "investment", content.arc.STORY_INVESTMENT)
                        score.add(p, "story", 4)
                        table.insert(fans, p)
                    end
                end
                self:highlight(5, "The story moves: " .. c.name, fans)
            end
        end
    end
end

function M:pay_off(c)
    local s = seeds.pay_off(self.campaign, c)
    if not s then
        return
    end
    local def = content.seeds[s.id]
    table.insert(self.payoffs, s.id)
    local weeks = self.campaign.week - s.week
    self:say("The seed from " .. (weeks == 1 and "last week" or (util.int(weeks) .. " weeks ago")) .. " pays off: "
        .. string.lower(string.sub(def.name, 1, 1)) .. string.sub(def.name, 2) .. ".", "thread")
    local poses, fans = {}, {}
    for _, p in ipairs(self.players) do
        local fan = seeds.is_fan(p, def)
        poses[p.key] = fan and "cheer" or "lean"
        score.add(p, "story", fan and 10 or 6)
        score.add(p, "fun", fan and 4 or 2)
        score.add(p, "investment", (fan and 3 or 1) + (s.hype or 0))
        if fan then
            table.insert(fans, p)
        end
    end
    self:react(poses)
    local who = self.rng:pick(fans) or self.rng:pick(self.players)
    self:bark(who, "seed_payoff", { seed = def.theory })
    self:highlight(9, def.name .. " paid off", fans, "payoff")
    table.insert(self.canon, def.name .. " paid off")
    -- A stolen theory (B5): the payoff reveals the theorist was right all along.
    local st = s.stolen
    local theorist = st and find_present(self.players, st.key)
    if st then
        local claim = seeds.claim({ seed = s.id, claim = st.claim })
        local p = theorist or self.campaign:player(st.key)
        if claim and p then
            self:say(util.fill(claim.truth, self:vars({ char = p.char })), "narration")
            if theorist then
                score.add(p, "fun", 10)
                score.add(p, "spotlight", 12)
                score.add(p, "investment", 6)
                -- A moment like this fills their heart (game/model/keepsakes.lua).
                self.heart_moments = self.heart_moments or {}
                self.heart_moments[p.key] = (self.heart_moments[p.key] or 0) + 1   -- their theory came true
                self:react({ [p.key] = "cheer" })
                self:emit({ kind = "say", who = p.key, text = "I KNEW it. I said this. It's in the group chat. Scroll up.", ic = false })
            end
            self:highlight(10, p.char .. "'s theory comes true", { p }, "theory")
            table.insert(self.canon, p.char .. "'s theory was right")
        end
    end
end

function M:table_check(sc)
    if self.table_card_used or not self:room(14) then
        return
    end
    local low = self:lowest()
    if not low then
        return
    end
    local by_id = {}
    for _, d in ipairs(content.decisions) do
        if d.table_only then
            by_id[d.id] = d
        end
    end
    local card
    if low.engagement < 0.22 then
        card = by_id.phone              -- someone has checked out
    elseif low.engagement < 0.4 then
        card = by_id.voices             -- two people are running the show
    elseif sc and sc.index == 1 and self.rng:chance(0.3) and self:room(12) then
        card = by_id.pizza              -- real life knocks on the door
    end
    -- Or a running joke whose moment has come (B5).
    local joke = not card and require("game.model.jokes").ripe(self.campaign)
    if joke and self.rng:chance(0.5) then
        self.table_card_used = true
        self.actor = nil
        local jokes = require "game.model.jokes"
        local o = self:decision(jokes.card(joke))
        if o and o.callback then
            jokes.called(self, joke)
        end
        return
    end
    -- Or a headache whose moment has come (B4): the forgotten sheet, the food coma.
    if not card then
        local last = self.campaign.last_cards or {}
        for _, id in ipairs({ "forgot_sheet", "food_coma" }) do
            local d = by_id[id]
            if not card and d and not last[id] and self:headache_ok(d.needs, sc) and self.rng:chance(0.3) then
                card = d
            end
        end
    end
    if not card then
        return
    end
    self.table_card_used = true
    self.actor = nil
    self:decision(card)
end

-- Fights ---------------------------------------------------------------------------------

-- Hand the turn's collected engine events to the table as one beat.
function M:flush_turn()
    local steps = self.turn_steps
    if not steps or #steps == 0 then
        return steps
    end
    self.turn_steps = {}
    local who = self.turn_who
    local ev = { kind = "turn", steps = steps, who = who and who.mini, side = who and who.side }
    -- Once the DM has been watching a while, the table plays the fight briskly (and after a
    -- long while, faster still: everyone knows their turn by now).
    -- Out of calls for the night, the table speeds up sooner (everyone can feel the clock).
    local spent = self:decision_count() >= 14
    if self:idle() > 85 or (spent and self:idle() > 60) then
        ev.brisk = "very"
    elseif self:idle() > 50 or (spent and self:idle() > 30) then
        ev.brisk = true
    end
    -- Now and then a player says something about their turn: what they're about to
    -- do, or how it went (a hit, a whiff, a big number, a spell).
    if who and who.pc and self.rng:chance(ev.brisk and 0.12 or 0.22) then
        local p
        for _, q in ipairs(self.players) do
            if q.key == who.player_key then
                p = q
            end
        end
        local trigger, at, target = self:turn_trigger(steps, who)
        if p and trigger then
            local text, line = self.talk:line(trigger, p, self:vars({ target = target }))
            if text then
                ev.say = { who = p.key, text = text, ic = talk_mod.in_character(trigger), line = line.id, at = at }
            end
        end
    end
    self:emit(ev)
    return steps
end

-- Which line fits a hero's turn: "turn" (said as it starts) or how it went
-- (said once it's done). Crits and takedowns get their own reactions instead.
function M:turn_trigger(steps, who)
    local hits, misses, damage, spell, heal, target_id = 0, 0, 0, nil, false, nil
    for _, s in ipairs(steps) do
        if s.kind == "attack" and s.id == who.mini then
            if s.crit then
                return nil
            end
            target_id = target_id or s.target
            if s.hit then
                hits = hits + 1
            else
                misses = misses + 1
            end
        elseif s.kind == "damage" and s.id ~= who.mini then
            damage = damage + (s.amount or 0)
        elseif s.kind == "death" then
            return nil
        elseif s.kind == "spell" and s.id == who.mini then
            spell = true
        elseif s.kind == "heal" and s.by == who.mini then
            heal = true
        end
    end
    local target
    if type(target_id) == "string" and self.battle then
        for _, c in ipairs(self.battle.creatures) do
            if c.mini == target_id then
                target = c.name
            end
        end
    end
    if heal then
        return "heal_cast", "end", target
    elseif spell and self.rng:chance(0.6) then
        return "spell", "start", target
    elseif damage >= 12 then
        return "big_hit", "end", target
    elseif hits > 0 then
        return "hit", "end", target
    elseif misses > 0 then
        return "miss", "end", target
    end
    return "turn", "start", target
end

function M:combat_scene(sc)
    fight.party(self)
    if #self.pc_list == 0 then
        return
    end
    local plan = fight.plan(self, sc)
    sc.boss_name = plan.boss_name
    self.battle_boss_name = plan.boss_name
    sc.plan = plan
    -- A card for this fight: a rules question waits for round two, anything else comes first.
    -- Or the boss's turn is yours to run (B8), in place of that card.
    sc.boss_turn_planned = takeover.plan_boss(self, sc)
    local card = ((not sc.boss_turn_planned and not sc.talked) or self:idle() > 75) and self:pick_decision(sc)
    if card and card.type == "rules" then
        sc.rules_card = card
    elseif card then
        self:decision(card)
    end
    -- Who sees whom first: a paused roll before the fight. A hero whose story this fight is
    -- always gets it (A4: their story, their roll).
    sc.surprise = nil
    local owner_here = false
    for _, c in pairs(sc.comps) do
        owner_here = owner_here or (c.thread ~= nil and find_present(self.players, c.thread) ~= nil and not self:muted(c))
    end
    local scouted = false
    if ((owner_here and self.rng:chance(0.5)) or self.rng:chance(0.45) or self:idle() > 50) and self:decision_count() < 13 then
        self:scout(sc)
        scouted = true
    end
    -- Who they're up against, out loud, before anyone tries anything (the story playtest: "Roll
    -- initiative!" with no name left the table guessing who the enemy was).
    self:say(self:foe_line(plan, sc), "narration")
    -- Somebody at the table has other ideas (A12): talk it down, or a flashy opening move.
    if self:curveball(sc, 0.2) and sc.skip_fight then
        sc.result = { winner = "party", rounds = 0, pc_downs = 0, talked = true }
        sc.outcome = "win"
        for _, p in ipairs(self.players) do
            score.add(p, "story", 4)
            score.add(p, "fun", 2)
        end
        self:apply({ { "arch:method_actor", fun = 4 }, { "arch:storyteller", fun = 2 }, { "arch:butt_kicker", fun = -3 } })
        self:highlight(7, "a fight that ended before it started", self.players)
        return
    end
    if not scouted and self:idle() < 60 and self.rng:chance(0.4) then
        self:stunt(sc)
    end
    self:say(self.talk:fight("start", self:vars()), "dm")
    local boss_fan = self:pick_actor({ "butt_kicker", "tactician", "storyteller" })
    self:bark(boss_fan, "boss_appears")
    if sc.comps.cast and content.encounters.by_cast[sc.comps.cast.id] then
        self:npc_line("taunt")
    end
    local result, f = fight.run(self, sc, plan)
    sc.result = result
    sc.outcome = result.winner == "party" and "win" or "lose"
    -- A foe who surrenders stays surrendered, and talks (A7): a name from the story.
    if f and f.surrendered then
        self:say(self:fresh(M.SURRENDER_TALK, "surrender_talk"), "goal")
        local beat = self.campaign:arc_beat()
        if beat and beat.lead then
            self:found_clue("surrender_" .. tostring(self.campaign.week), util.fill("{Boss} named {lead}.", self:vars()))
        end
    end
    -- A hero died (B3): what happens next, by what Session Zero agreed.
    self.dead_handled = self.dead_handled or {}
    for _, c in ipairs(self.pc_list or {}) do
        local p = c.dead and c.player_key and find_present(self.players, c.player_key)
        if p and not self.dead_handled[p.key] then
            self.dead_handled[p.key] = true
            local outcome = death_mod.on_death(self, p, c, sc)
            if outcome == "scar" then
                c.dead, c.down = false, false
                c.hp = 1
            end
        end
    end
    -- A villain (or a fighting cast) who got away comes back another week (the story deck).
    local cast = sc.comps.cast
    if cast and (cast.villain or cast.foe) and f and f.fled then
        sc.escaped = { [cast.id] = true }
    end
    if result.winner == "party" then
        self:say(self.talk:fight("party_win", self:vars()), "good")
        local poses = {}
        for _, p in ipairs(self.players) do
            poses[p.key] = "cheer"
        end
        self:react(poses)
        -- The table talk reads the fight (A7): no "Too easy." after someone dropped.
        local close = (result.pc_downs or 0) >= 1
        for _, c in ipairs(self.pc_list or {}) do
            close = close or (not c.dead and c.hp_max and c.hp <= c.hp_max * 0.35)
        end
        self:bark(self:pick_actor({ "butt_kicker", "casual", "tactician" }), close and "victory_close" or "victory")
        for _, p in ipairs(self.players) do
            score.add(p, "challenge", 6)
            score.add(p, "fun", 2)
        end
    else
        self:say(self.talk:fight("party_lose", self:vars()), "bad")
        -- A defeat scene (B2): the party loses without anyone dying, and it leaves them something.
        local d = fails_mod.defeat(self, sc)
        sc.defeat = d.id
        self:say(d.line, "narration")
        self:apply(d.effects or {})
        self:event("defeat", { who = "party", text = d.line, weight = 7 })
        villains.bark(self, "defeat")
        local poses = {}
        for _, p in ipairs(self.players) do
            poses[p.key] = "gasp"
            score.add(p, "challenge", 10)
            score.add(p, "fun", -4)
        end
        self:react(poses)
        self:bark(self:pick_actor(nil), "defeat")
    end
    -- Tactical fun: close fights thrill Tacticians, stomps bore them.
    local downs = result.pc_downs or 0
    if downs == 0 and (result.rounds or 0) <= 2 then
        self:apply({ { "arch:tactician", fun = -3, challenge = -4 } })
    elseif downs >= 1 and result.winner == "party" then
        self:apply({ { "arch:tactician", fun = 4 }, { "arch:butt_kicker", fun = 3 } })
        self:highlight(6, "a fight that came down to the wire", self.players)
    end
    -- No automatic patch-up after a fight any more (A16): rests are the players' to ask for.
    self.fights_since_long = (self.fights_since_long or 0) + 1
    for _, c in ipairs(self.pc_list or {}) do
        if c.down and not c.dead then
            c.down, c.hp = false, math.max(1, c.hp)    -- stabilized after the fight, back on their feet at 1
        end
    end
end

-- The foes a fight puts on the mat, said the way a DM would: "The pack leader, with four wolves
-- behind them." The first id is the boss (the scene's villain when there is one).
local NUMBERS = { "a", "two", "three", "four", "five", "six", "seven", "eight" }
local function plural(name)
    if string.match(name, "wolf$") then
        return string.sub(name, 1, -2) .. "ves"
    end
    return name .. "s"
end
local function a_an(name)
    return (string.match(name, "^[aeiou]") and "an " or "a ") .. name
end
M.FOE_LINES = {
    "{Boss}, with {rest} behind them.",
    "Out of hiding comes {boss}, with {rest}.",
    "It's {boss}, with {rest} at their back.",
    "{Boss} steps into the open, {rest} close behind.",
}
M.FOE_ALONE = { "{Boss}, alone, and not worried about it.", "Just {boss}. That's plenty." }

function M:foe_line(plan, sc)
    local monsters = require "game.rules.data.monsters"
    local counts, order = {}, {}
    for i, id in ipairs(plan.ids or {}) do
        if i > 1 and monsters[id] then
            if not counts[id] then
                table.insert(order, id)
            end
            counts[id] = (counts[id] or 0) + 1
        end
    end
    local parts = {}
    if plan.crew and #order > 0 then
        -- The place's own people (a tavern's drinking pals, not "bandits").
        local n = #(plan.ids or {}) - 1
        table.insert(parts, n == 1 and a_an(plan.crew) or ((NUMBERS[n] or tostring(n)) .. " " .. plural(plan.crew)))
    else
        for _, id in ipairs(order) do
            local name = string.lower(monsters[id].name)
            local n = counts[id]
            table.insert(parts, n == 1 and a_an(name) or ((NUMBERS[n] or tostring(n)) .. " " .. plural(name)))
        end
    end
    local boss = plan.boss_name or "their leader"
    sc.foes_said = { boss = boss, rest = util.join_names(parts) }
    local v = { boss = boss, Boss = util.capitalize(boss), rest = util.join_names(parts) }
    if #parts == 0 then
        return util.fill(self:fresh(M.FOE_ALONE, "foe_alone"), v)
    end
    return util.fill(self:fresh(M.FOE_LINES, "foe_lines"), v)
end

-- Before a fight: someone scouts ahead (or tries to talk first). The result sets who's surprised.
local SCOUT = {
    rogue = { "{actor_char} creeps ahead to scout.", "{actor_char} slips away to see what's waiting.",
              "{actor_char} goes on ahead, quiet as a cat." },
    fighter = { "{actor_char} stands watch at the front.", "{actor_char} takes the lead, shield up.",
                "{actor_char} plants their feet and watches the dark." },
    wizard = { "{actor_char} sends a light ahead to check the way.", "{actor_char} mutters a cantrip and peers ahead.",
               "{actor_char} sends a spark skittering along the ground ahead." },
    cleric = { "{actor_char} listens hard for trouble.", "{actor_char} closes their eyes and listens.",
               "{actor_char} murmurs a prayer and watches the shadows." },
}
local SPOTTED = {
    success = { "They spot the enemy first. Weapons out, quietly.", "Movement up ahead. They see it before it sees them.",
                "A glint of steel in the dark. They're ready first." },
    fail = { "A twig snaps. Every head turns their way.", "Something clatters underfoot. So much for surprise.",
             "Too late: they've been seen." },
    -- Under a roof (the story playtest: twigs in a tavern).
    fail_in = { "A floorboard creaks. Every head turns their way.", "Something clatters underfoot. So much for surprise.",
                "Too late: they've been seen." },
}
local INDOORS = { indoor = true, tavern = true, shop = true, under = true }

M.SURRENDER_TALK = {
    "{Boss} drops to their knees and talks fast. It was {lead}. It's always been {lead}.",
    "In exchange for their life, {boss} gives up a name: {lead}.",
    "'All right! All right.' {Boss} sits down hard and tells them everything they know about {lead}.",
}

-- Open scenes (A15: player agency) -------------------------------------------------------------
-- "What do you do?" The players pitch where to go (their type, their story, the notebook, a
-- wild idea), back each other's pitches, and the DM decides: follow the table, go with
-- someone's idea, split the party, move the prepped hook to where they went (the quantum ogre),
-- or steer them to the hook.

local HOOK_KINDS = { "cast", "goal", "complication", "reward" }

-- How much this player wants to go to this place, and why.
function M:pitch_weight(p, id, sc)
    local c = content.components[id]
    local w, why = 0, nil
    for _, f in ipairs(c.fits or {}) do
        w = math.max(w, score.taste(p, f))
    end
    for _, t in ipairs(c.tags or {}) do
        w = w + 0.3 * score.like(p, t)
    end
    if c.thread == p.key then
        w, why = w + 1.1, "thread"
    end
    -- Someone they like from the notebook was last seen there.
    for _, pid in ipairs(ledger.people(self.campaign)) do
        if ledger.met(self.campaign, pid) then
            local last = ledger.history(self.campaign, pid)[1]
            local lp = ledger.person(self.campaign, pid)
            if last and last.at == id and lp and (lp.warm and (lp.warm[p.key] or 0) > 0 or (lp.att or 0) > 0) then
                w, why = w + 0.5, why or ("person:" .. pid)
            end
        end
    end
    local known = places.get(self.campaign)[id]
    if known and (known.visits or 0) > 0 then
        w, why = w + 0.25, why or "again"
    end
    if util.contains(sc.spots or {}, id) then
        w = w + 0.2
    end
    return w, why
end

function M:open_scene(sc)
    local os = content.open_scenes
    local camp = self.campaign
    sc.chosen = true
    -- Where they could go: the spots you sketched, and every place that's already yours.
    local options = {}
    for _, id in ipairs(sc.spots or {}) do
        if content.components[id] then
            table.insert(options, id)
        end
    end
    local first = content.components[options[1] or "tavern"] or content.components.tavern
    -- Where they are: town if any spot you sketched is in town, the wilds if any is out there.
    local area = {}
    for _, id in ipairs(options) do
        local st = content.components[id].setting or {}
        area.town = area.town or util.contains(st, "town")
        area.wild = area.wild or util.contains(st, "wild")
    end
    if not area.town and not area.wild then
        area.town = true
    end
    local in_town = area.town
    local function nearby(card)
        local st = card.setting or {}
        return (area.town and util.contains(st, "town")) or (area.wild and util.contains(st, "wild"))
    end
    for _, pl in ipairs(places.list(camp)) do
        -- Your places nearby, always on the map.
        if nearby(pl.card) and not util.contains(options, pl.id) and not self:muted(pl.card) then
            table.insert(options, pl.id)
        end
    end
    local hub = in_town and "Millbrook" or "the hills around Millbrook"
    self:say(self:fresh(os.arrive, "open_arrive"), "opening", { hub = hub, Hub = util.capitalize(hub) })
    -- The pitches.
    local pitches, by_spot = {}, {}
    for _, p in ipairs(self.players) do
        local best, bw, bwhy
        for _, id in ipairs(options) do
            local w, why = self:pitch_weight(p, id, sc)
            w = w + self.rng:next() * 0.6
            if not bw or w > bw then
                best, bw, bwhy = id, w, why
            end
        end
        -- A wild idea nobody prepped, now and then, from the type who'd have it.
        local wild
        for _, wd in ipairs(os.wild) do
            if (p.primary == wd.archetype or p.secondary == wd.archetype) and content.components[wd.place]
                and nearby(content.components[wd.place]) then
                wild = wd
            end
        end
        local say
        if wild and (not bw or self.rng:chance(0.25)) and wild.place ~= best and not util.contains(options, wild.place) then
            best, bwhy, say = wild.place, "wild", wild.say
        end
        if best and by_spot[best] then
            -- Someone already said it: they back it instead.
            table.insert(by_spot[best].backers, p)
            local c = content.components[best]
            local v = { place = soft_lower(c.short or c.name), Place = util.capitalize(soft_lower(c.short or c.name)) }
            self:emit({ kind = "say", who = p.key, text = util.fill(self:fresh(os.back, "open_back"), v), ic = false })
        elseif best then
            local c = content.components[best]
            local v = { place = soft_lower(c.short or c.name), Place = util.capitalize(soft_lower(c.short or c.name)),
                        char = p.char, Char = p.char }
            if not say then
                if bwhy == "thread" then
                    say = self:fresh(os.thread, "open_thread")
                elseif bwhy and string.sub(bwhy, 1, 7) == "person:" then
                    local pid = string.sub(bwhy, 8)
                    v.person = soft_lower(ledger.about(pid).name)
                    v.Person = util.capitalize(v.person)
                    say = self:fresh(os.person, "open_person")
                elseif bwhy == "again" then
                    say = self:fresh(os.again, "open_again")
                else
                    local t = (c.fits or { "social" })[1]
                    say = self:fresh(os.pitch[t] or os.pitch.social, "open_pitch_" .. t)
                end
            end
            local pitch = { who = p, id = best, why = bwhy, backers = { p } }
            table.insert(pitches, pitch)
            self:emit({ kind = "say", who = p.key, text = util.fill(say, v), ic = false })
            by_spot[best] = by_spot[best] or pitch
        end
    end
    -- For the report and the sims: who pitched what, and why.
    sc.pitches = {}
    for _, pt in ipairs(pitches) do
        table.insert(sc.pitches, { who = pt.who.key, id = pt.id, why = pt.why, backers = #pt.backers })
    end
    -- Who backs what: whoever pitched it, and whoever seconded it.
    local ranked = {}
    for id, pitch in pairs(by_spot) do
        table.insert(ranked, { id = id, who = pitch.backers, pitch = pitch })
    end
    table.sort(ranked, function(a, b)
        if #a.who ~= #b.who then
            return #a.who > #b.who
        end
        return a.id < b.id
    end)
    local top, second = ranked[1], ranked[2]
    if not top then
        -- Nobody had an idea: the first spot it is.
        sc.comps.location = first
        self:finish_open(sc, first.id, nil)
        return
    end
    -- The DM's hook waits at the first spot you sketched.
    local hook_id = sc.spots and sc.spots[1]
    local has_hook = false
    for _, k in ipairs(HOOK_KINDS) do
        has_hook = has_hook or sc.comps[k] ~= nil
    end
    local function name_of(id)
        local c = content.components[id]
        return soft_lower(c.short or c.name)
    end
    local function names(list)
        local n = {}
        for _, p in ipairs(list) do
            table.insert(n, p.name)
        end
        return table.concat(n, ", ")
    end
    local L, G = os.labels, os.logs
    local card = { id = "open_choice", type = "agency", title = "Where to?", options = {},
                   text = "The table has ideas. You can go with them, or not." }
    local function opt(mode, id, extra)
        local v = { place = name_of(id), Place = util.capitalize(name_of(id)), who = names((extra and extra.who) or top.who),
                    name = extra and extra.name or "", other_place = extra and extra.other and name_of(extra.other) or "",
                    hook = hook_id and name_of(hook_id) or "" }
        table.insert(card.options, { label = util.fill(L[mode], v), log = util.fill(G[mode], v), mode = mode, spot = id,
                                     other = extra and extra.other, effects = {} })
    end
    opt("follow", top.id, { who = top.who })
    if has_hook and hook_id and top.id ~= hook_id then
        opt("quantum", top.id, { who = top.who })
    end
    if second then
        opt("other", second.id, { name = second.pitch.who.name })
        if #self.players >= 3 then
            opt("split", top.id, { other = second.id })
        end
    end
    if has_hook and hook_id and top.id ~= hook_id then
        opt("steer", hook_id)
    end
    while #card.options > 4 do
        table.remove(card.options, #card.options - 1)
    end
    self.actor = top.pitch.who
    local o = self:decision(card)
    local chosen = (o and o.spot) or top.id
    -- What the table makes of it.
    local winners = {}
    if o and o.mode == "steer" then
        for _, r in ipairs(ranked) do
            for _, p in ipairs(r.who) do
                score.add(p, "trust", -3)
                score.add(p, "fun", -2)
            end
        end
        self:react((function()
            local poses = {}
            for _, p in ipairs(self.players) do
                poses[p.key] = "arms"
            end
            return poses
        end)())
    else
        local r = (o and o.mode == "other") and second or top
        winners = r.who
        for _, p in ipairs(r.who) do
            score.add(p, "fun", 5)
            score.add(p, "spotlight", 4)
            score.add(p, "investment", 2)
        end
        if r.pitch and r.pitch.who then
            score.add(r.pitch.who, "fun", 2)
            self:react({ [r.pitch.who.key] = "cheer" })
            self:highlight(5, r.pitch.who.char .. "'s idea takes the party to " .. name_of(chosen), { r.pitch.who })
        end
        if o and o.mode == "quantum" then
            for _, p in ipairs(self.players) do
                self:suspect(p, 3 * (p.perception or 0.5), "the place being wherever they went")
            end
        end
        if o and o.mode == "split" and second then
            for _, p in ipairs(second.who) do
                score.add(p, "spotlight", 4)
                score.add(p, "fun", 3)
            end
            local v = { place = name_of(second.id), who = names(#second.who > 0 and second.who or { second.pitch.who }) }
            self:say(self:fresh(os.meanwhile, "open_meanwhile"), "narration", v)
            places.visit(camp, second.id)
        end
    end
    self:finish_open(sc, chosen, o and o.mode, hook_id)
end

-- Set the scene up at the chosen place: the hook stays only where it was prepped (or where you
-- moved it); anything missing gets improvised as usual.
function M:finish_open(sc, chosen, mode, hook_id)
    local c = content.components[chosen]
    sc.comps.location = c
    sc.chosen_spot = chosen
    local keep_hook = (chosen == hook_id) or mode == "quantum" or mode == "steer"
    if not keep_hook then
        sc.hook_skipped = {}
        for _, k in ipairs(HOOK_KINDS) do
            if sc.comps[k] then
                table.insert(sc.hook_skipped, sc.comps[k].id)
                self.on_board[sc.comps[k].id] = nil
                sc.comps[k] = nil
            end
        end
    end
    local goal = sc.comps.goal
    sc.type = (goal and goal.fits and goal.fits[1]) or (c.fits and c.fits[1]) or "social"
    if not content.scenes[sc.type] then
        sc.type = "social"
    end
    sc.missing = {}
    for _, kind in ipairs(prep_mod.IMPROV_ORDER) do
        if not sc.comps[kind] then
            table.insert(sc.missing, kind)
        end
    end
    local sketched = util.contains(sc.spots or {}, chosen) or places.is_known(self.campaign, chosen)
    sc.quality = prep_mod.quality(sc.type, sc.comps, self.prep.inspired) - (sketched and 0 or 0.05)
    sc.difficulty = prep_mod.difficulty(sc.comps)
    sc.encounter = keep_hook and sc.encounter or nil
    self.on_board[chosen] = true
end

-- Party tension (A17) -------------------------------------------------------------------------------
-- Characters sometimes do things that land on each other: a needless scrap, pocketing a
-- friend's prize, a joke in someone's big moment. Each act lands differently on each player,
-- moves the rapport between them, and you answer it the way real DMs do. Bonds go the other way.

function M:scene_moments(sc)
    local m = { any = true }
    m.fight = sc.result ~= nil and sc.result.winner == "party"
    m.loot = sc.comps.reward ~= nil and sc.outcome == "win"
    m.social = sc.type == "social" or sc.type == "mystery" or sc.type == "downtime"
    m.explore = sc.type == "exploration" or sc.type == "puzzle"
    for _, c in pairs(sc.comps) do
        m.story = m.story or (c.thread ~= nil and find_present(self.players, c.thread) ~= nil)
    end
    return m
end

local function doer_weight(def, p)
    if def.class and p.class ~= def.class then
        return 0
    end
    local d = def.doers
    if not d then
        return 1
    end
    return (d[p.primary] or 0) + (d[p.secondary] or 0) * 0.5
end

function M:party_moment(sc)
    if #self.players < 2 or self.end_early then
        return
    end
    local moments = self:scene_moments(sc)
    local fr = content.friction
    local function eligible(list)
        local cands, w = {}, {}
        for _, def in ipairs(list) do
            if moments[def.when or "any"] and (def.needs ~= "cast" or (sc.comps.cast and not self:muted(sc.comps.cast)))
                and not (self.friction_done and self.friction_done[def.id]) then
                for _, p in ipairs(self.players) do
                    local dw = doer_weight(def, p)
                    if dw > 0 then
                        table.insert(cands, { def = def, p = p })
                        table.insert(w, dw)
                    end
                end
            end
        end
        return cands, w
    end
    self.friction_done = self.friction_done or {}
    local roll = self.rng:next()
    if roll < 0.32 then
        local cands, w = eligible(fr.acts)
        if #cands > 0 then
            local pick = self.rng:weighted(cands, w)
            self:friction_act(sc, pick.def, pick.p)
        end
    elseif roll < 0.62 then
        local cands, w = eligible(fr.bonds)
        if #cands > 0 then
            local pick = self.rng:weighted(cands, w)
            self:bond_act(sc, pick.def, pick.p)
        end
    end
end

function M:friction_act(sc, def, doer)
    self.friction_done[def.id] = true
    local target = def.target and self:pick_actor(nil, doer) or nil
    local v = { actor_char = doer.char, actor = doer.name, target_char = target and target.char or "",
                target = target and target.name or "" }
    self:say(util.capitalize(util.fill(def.line, self:vars(v))), "twist")
    -- How you answer it: a quick card when there's room for one, otherwise you let it ride.
    local fr = content.friction
    local resp
    if self:room(13) then
        local opts = {}
        local order = { "let_it_ride", target and "party_reacts" or "world_reacts",
                        self.rng:chance(0.5) and "pause" or "session_zero", "outlet" }
        for _, id in ipairs(order) do
            for _, r in ipairs(fr.responses) do
                if r.id == id and (not r.needs_target or target) then
                    table.insert(opts, { label = util.fill(r.label, v), log = util.fill(r.log, v), resp = r })
                end
            end
        end
        -- The card says who's unhappy (A11: every consequence names its cause).
        local names = {}
        for _, p in ipairs(rapport.objectors(self.campaign, doer, def, self.players, target and target.key)) do
            table.insert(names, p.name)
        end
        local text = #names > 0 and (doer.name .. " is having fun. " .. util.join_names(names) .. (#names == 1 and " isn't." or " aren't."))
            or (doer.name .. " is having fun. The rest of the table is watching to see what you do.")
        local card = { id = "friction_" .. def.id, type = "table", title = "At the table", text = text, options = opts }
        self.actor = doer
        local o = self:decision(card)
        resp = o and o.resp
    end
    resp = resp or fr.responses[1]
    local out = rapport.on_act(self.campaign, doer, def, self.players, target and target.key, resp.heat)
    -- The response's own effects.
    local fx = resp.effects or {}
    local function add(p, t)
        for k, n in pairs(t or {}) do
            score.add(p, k, n)
        end
    end
    add(doer, fx.doer)
    if target then
        add(target, fx.target)
    end
    for _, p in ipairs(out.objectors) do
        add(p, fx.objectors)
    end
    for _, p in ipairs(self.players) do
        add(p, fx.all)
    end
    -- It shows at the table.
    local poses = {}
    for _, p in ipairs(out.objectors) do
        poses[p.key] = "arms"
    end
    for _, p in ipairs(out.enjoyers) do
        poses[p.key] = "laugh"
    end
    self:react(poses)
    if #out.objectors > 0 and self:idle() < 80 then
        local who = out.objectors[1]
        self:say(self:fresh(fr.jabs, "jab"), "narration", { char = who.char, doer_char = doer.char })
    end
    if def.feeds then
        require("game.model.social").push(self.campaign, def.feeds, 4 * (def.severity or 1))
    end
    self.frictions = self.frictions or {}
    table.insert(self.frictions, { id = def.id, doer = doer.key, target = target and target.key, response = resp.id,
                                   objectors = #out.objectors })
end

function M:bond_act(sc, def, doer)
    local target
    if def.amends then
        -- Amends come from someone others are hot with.
        local best, bh
        for _, p in ipairs(self.players) do
            if p ~= doer then
                local rel = rapport.rel(self.campaign, p.key, doer.key)
                if rel and rel.heat > 10 and (not bh or rel.heat > bh) then
                    best, bh = p, rel.heat
                end
            end
        end
        if not best then
            return
        end
        target = best
    else
        target = self:pick_actor(nil, doer)
    end
    if not target then
        return
    end
    self.friction_done[def.id] = true
    local v = { actor_char = doer.char, actor = doer.name, target_char = target.char, target = target.name }
    self:say(util.capitalize(util.fill(def.line, self:vars(v))), "good")
    rapport.bond(self.campaign, doer.key, target.key, def.rapport or 3, def.amends)
    self:react({ [doer.key] = "cheer", [target.key] = "laugh" })
    self.bonds = self.bonds or {}
    table.insert(self.bonds, { id = def.id, a = doer.key, b = target.key })
end

-- Rests (A16) ---------------------------------------------------------------------------------------
-- The players ask; you rule. What comes back follows SRD 5.2.1 (game/rules/rest.lua).

local function place_kind(loc)
    local st = loc and loc.setting or {}
    if loc and loc.haven then
        return util.contains(st, "ship") and "ship" or "inn"   -- a style's safe home base (A18)
    elseif util.contains(st, "ship") then
        return "ship"
    elseif util.contains(st, "tavern") then
        return "inn"
    elseif util.contains(st, "camp") then
        return "camp"
    elseif util.contains(st, "water") and not util.contains(st, "under") then
        return "ship"
    elseif util.contains(st, "under") or util.contains(st, "ruin") then
        return "dungeon"
    elseif util.contains(st, "town") then
        return "town"
    end
    return "wilderness"
end
M.place_kind = place_kind

function M:pc_of(p)
    return self.pcs and self.pcs[p.key]
end

-- Does this request's "when" hold for this player right now?
function M:rest_fits(rq, p, sc)
    local w = rq.when or {}
    local c = self:pc_of(p)
    if not c then
        return false
    end
    local fought = sc.result ~= nil
    local st = rest_rules.state(self.pc_list)
    if w.after_fight and not fought then
        return false
    end
    if w.own_hp_below and c.hp / c.hp_max >= w.own_hp_below then
        return false
    end
    if w.party_hp_below and st.hp >= w.party_hp_below then
        return false
    end
    if w.any_down and not (sc.result and (sc.result.pc_downs or 0) > 0) then
        return false
    end
    if w.own_spent then
        for _, r in ipairs(w.own_spent) do
            if (c.res[r] or 0) > 0 or c.res[r] == nil then
                return false
            end
        end
    end
    if w.own_slots_below then
        local s = rest_rules.state({ c })
        if not c.slots_max or s.slots >= w.own_slots_below then
            return false
        end
    end
    if w.hit_dice_left and not (c.hd and c.hd.left >= w.hit_dice_left) then
        return false
    end
    if w.fights_since_long and (self.fights_since_long or 0) < w.fights_since_long then
        return false
    end
    if w.next_is then
        local nx = self.scenes[sc.index + 1]
        if not nx or nx.type ~= w.next_is then
            return false
        end
    end
    if w.late and self.table_min < self.table_planned * 0.7 then
        return false
    end
    if w.where then
        local loc = sc.comps.location
        local ok = false
        for _, s in ipairs(w.where) do
            ok = ok or util.contains(loc and loc.setting or {}, s) or place_kind(loc) == s
        end
        if not ok then
            return false
        end
    end
    if w.scene_types and not util.contains(w.scene_types, sc.type) then
        return false
    end
    if w.exhausted then
        return false     -- nothing causes Exhaustion yet
    end
    return true
end

function M:rest_request(sc)
    if not self.pc_list or #self.pc_list == 0 or self.end_early then
        return
    end
    self.rest_asks = self.rest_asks or 0
    -- A second ask in one night waits for a quiet night.
    if self.rest_asks >= 2 or not self:room(13) or (self.rest_asks >= 1 and not self:room(12)) then
        return
    end
    local st = rest_rules.state(self.pc_list)
    -- Nobody asks when they're fresh.
    if st.hp > 0.85 and st.slots > 0.7 then
        return
    end
    local cands, weights = {}, {}
    for _, rq in ipairs(rests.requests) do
        for _, p in ipairs(self.players) do
            local aw = rq.archetype == "any" and 1 or ((p.primary == rq.archetype and 1) or (p.secondary == rq.archetype and 0.5) or 0)
            if aw > 0 and self:rest_fits(rq, p, sc) then
                local prof = rests.profiles[p.primary] or {}
                table.insert(cands, { rq = rq, p = p })
                table.insert(weights, (rq.weight or 1) * aw * (prof.asks or 1))
            end
        end
    end
    if #cands == 0 then
        return
    end
    local need = (1 - st.hp) * 0.9 + (1 - st.slots) * 0.3
    if not self.rng:chance(math.min(0.9, 0.3 + need)) then
        return
    end
    local pick = self.rng:weighted(cands, weights)
    local rq, p = pick.rq, pick.p
    self.rest_asks = self.rest_asks + 1
    self:emit({ kind = "say", who = p.key, text = self:fresh(rq.lines, "rest_" .. rq.id), ic = false })
    -- The card: what this place allows.
    self.actor = p
    local loc = sc.comps.location
    local kind = place_kind(loc)
    local data = rests.card
    local card = { id = "rest_request", type = "pacing", title = data.title,
                   text = util.fill(data.text, self:vars({ kind = rq.kind, location = loc and soft_lower(loc.short or loc.name) or "the road" })),
                   options = {} }
    for _, oid in ipairs(data.offer[kind] or data.offer.wilderness) do
        for _, o in ipairs(data.options) do
            if o.id == oid and #card.options < 4 then
                local oo = {}
                for k2, v2 in pairs(o) do
                    oo[k2] = v2
                end
                if o.say_reason then
                    oo.log = (rests.places[kind] and rests.places[kind].reason) or o.log
                elseif rq.kind == "short" and (o.id == "allow" or o.id == "allow_scene") then
                    oo.label = o.id == "allow" and "Sure. Take an hour." or "Take an hour. Let's play it out."
                    oo.log = o.id == "allow" and "An hour of quiet: bandages, water, a breather." or o.log
                end
                table.insert(card.options, oo)
            end
        end
    end
    self.actor = p
    local o = self:decision(card)
    if not o then
        return
    end
    -- How each kind of player takes the ruling.
    for arch, prof in pairs(rests.profiles) do
        local fx = prof.on and prof.on[o.id]
        if fx then
            local e = { "arch:" .. arch }
            for k2, v2 in pairs(fx) do
                e[k2] = v2
            end
            self:apply({ e })
        end
    end
    local needy = st.hp < 0.4 or st.slots < 0.2
    local fresh = st.hp > 0.75 and st.slots > 0.5
    local ctx = rests.context
    if needy and ctx.needy[o.id] then
        self:apply(ctx.needy[o.id])
    elseif fresh and ctx.fresh[o.id] then
        self:apply(ctx.fresh[o.id])
    end
    self:fairness(o.id, kind)
    self:do_rest(o, rq.kind, kind, sc)
end

-- What the table remembers: a run of "no" stings; a run of easy long rests bores the planners.
function M:fairness(rid, kind)
    local camp = self.campaign
    camp.rest_log = camp.rest_log or {}
    local no = rid == "deny_reason" or rid == "interrupt"
    table.insert(camp.rest_log, { week = camp.week, ruling = rid, place = kind, no = no })
    while #camp.rest_log > 12 do
        table.remove(camp.rest_log, 1)
    end
    local streak = 0
    for i = #camp.rest_log, 1, -1 do
        if camp.rest_log[i].no then
            streak = streak + 1
        else
            break
        end
    end
    local f = rests.fairness
    if no and streak >= f.streak_hurt then
        self:apply(f.streak_effects)
    end
    if no and streak >= f.streak_warn then
        local q = self:pick_actor({ "casual", "tactician", "power_gamer" })
        if q then
            self:emit({ kind = "say", who = q.key, text = self:fresh(rests.table_lines.streak_warn, "rest_streak"), ic = false })
        end
    end
end

-- Apply the ruling: who rests how, what turns up, and the scene it plays.
function M:do_rest(o, asked, kind, sc)
    local how = o.rest
    local long = asked == "long"
    local interrupted
    if how == "none" then
        return
    elseif how == "short" or how == "player_choice" then
        long = false
    elseif how == "roll" or how == "interrupt" then
        local pl = rests.places[kind] or rests.places.wilderness
        local chance = long and pl.long or pl.short
        local events = {}
        local w = {}
        for _, ev in ipairs(pl.events) do
            if how == "roll" or ev.interrupts then
                table.insert(events, ev)
                table.insert(w, ev.w or 1)
            end
        end
        if (how == "interrupt" or self.rng:chance(chance * 1.5)) and #events > 0 then
            local ev = self.rng:weighted(events, w)
            self:say(ev.line, ev.interrupts and "bad" or "narration")
            if ev.interrupts then
                interrupted = true
                -- A skirmish or a hazard in the night: a few bruises, and the rest is cut short.
                for _, c in ipairs(self.pc_list) do
                    if ev.kind == "fight" or ev.damage then
                        c.hp = math.max(1, c.hp - self.rng:int(1, 6))
                    end
                end
                for _, q in ipairs(self.players) do
                    score.add(q, "challenge", 3)
                end
            elseif ev.story then
                for _, q in ipairs(self.players) do
                    score.add(q, "story", 2)
                end
            end
            if ev.poor_rest then
                long = false
            end
        end
    elseif how == "travel" then
        self.table_min = self.table_min + 20
    end
    local mins = long and 15 or 8
    self.table_min = self.table_min + mins
    if interrupted then
        -- Broken before an hour had passed (always, when you planned it): no benefit at all. After
        -- an hour, an interrupted Long Rest still counts as a Short Rest (SRD 5.2.1).
        if how == "interrupt" or not self.rng:chance(0.5) then
            self:say("Nobody got any real rest.", "aside")
            self.rests = self.rests or {}
            table.insert(self.rests, { kind = "none", interrupted = true, place = kind })
            return
        end
        long = false
    end
    local spend = rest_rules.SPEND
    local healed = 0
    for _, c in ipairs(self.pc_list) do
        local p = self.campaign:player(c.player_key)
        if long then
            local before = c.hp
            rest_rules.long(c)
            healed = healed + (c.hp - before)
        else
            local got = rest_rules.short(c, self.rng, spend[p and p.primary] or spend.default)
            healed = healed + got.hp
        end
    end
    if long then
        self.fights_since_long = 0
        -- A new day: items' charges and daily uses come back (A13), then Mage Armor and Aid.
        local items = require "game.model.items"
        for _, c in ipairs(self.pc_list) do
            items.settle(c)
        end
        items.dawn(self.campaign, self.rng)
        for _, c in ipairs(self.pc_list) do
            items.apply(self.campaign, c.player_key, c)
        end
        fight.prebuff(self)
    end
    self:say(long and "A full night's rest. Everyone wakes whole, spells back, ready." or
        (healed > 0 and ("An hour's rest: Hit Dice spent, " .. util.int(healed) .. " HP back across the party.")
         or "An hour's rest. Nobody had Hit Dice left to spend, but the features are back."), "aside")
    self.rests = self.rests or {}
    table.insert(self.rests, { kind = long and "long" or "short", interrupted = interrupted, place = kind })
    if not interrupted and (o.beat or self:arch_present("storyteller") or self:arch_present("method_actor")) and self:idle() < 80 then
        self:rest_beat(kind)
    end
end

function M:arch_present(a)
    for _, p in ipairs(self.players) do
        if p.primary == a then
            return true
        end
    end
    return false
end

-- A little scene while they rest: a pair at the fire, a dream, someone cooking.
function M:rest_beat(kind)
    local camp = self.campaign
    camp.beats_seen = camp.beats_seen or {}
    local cands, w = {}, {}
    for _, b in ipairs(rests.beats) do
        local ok = not camp.beats_seen[b.id] and (util.contains(b.where or { "any" }, "any") or util.contains(b.where, kind))
        for _, who in ipairs(b.pair or {}) do
            local k, id = string.match(who, "^(%a+):(.+)$")
            if k == "pc" and not find_present(self.players, id) then
                ok = false
            end
        end
        if ok then
            table.insert(cands, b)
            table.insert(w, b.mend and 2 or 1)
        end
    end
    if #cands == 0 then
        return
    end
    local b = self.rng:weighted(cands, w)
    camp.beats_seen[b.id] = camp.week
    self.table_min = self.table_min + 5
    self:say(b.line, "narration")
    self:apply(b.effects or {})
    if b.thread then
        local p = find_present(self.players, b.thread)
        if p then
            p.thread_hits = p.thread_hits + 1
        end
    end
end

-- The table clock (A14) --------------------------------------------------------------------------
-- Each player has their own ideal length (players.lua), moved by their mood this week and by
-- how into it they are: when they're hooked, time flies; when they're bored, it drags.
local MOOD_HOURS = { tired = -0.75, stressed = -0.5, distracted = -0.5, celebrating = 0.5, chatty = 0.5 }
M.FADING = { "is it ten already? sorry. is it?", "i have work tomorrow, just saying.", "one more scene and then i'm out.",
             "sorry, i'm fading. keep going without me if i doze off." }

function M:ideal_minutes(p)
    local d = content.players[p.key]
    local h = (d and d.hours or 3.5) + (MOOD_HOURS[p.mood] or 0) + ((p.engagement or 0.5) - 0.5) * 1.2
    return h * 60
end

function M:clock_text(min)
    local t = (self.table_start or 19 * 60) + math.floor(min or self.table_min or 0)
    local h, m = math.floor(t / 60), t % 60
    local ampm = (h >= 12 and h < 24) and "pm" or "am"
    local h12 = h % 12
    if h12 == 0 then
        h12 = 12
    end
    return util.int(h12) .. ":" .. string.format("%02d", m) .. " " .. ampm
end

-- Between scenes: anyone past their limit says so (once a night).
function M:clock_tells()
    self.fading = self.fading or {}
    for _, p in ipairs(self.players) do
        if not self.fading[p.key] and self.table_min > self:ideal_minutes(p) then
            self.fading[p.key] = self.table_min
            self:react({ [p.key] = "yawn" })
            if self:idle() < 75 then
                self:emit({ kind = "say", who = p.key, text = self:fresh(M.FADING, "fading"), ic = false })
            end
        end
    end
end

-- How the length landed for each of them (and whether you kept to the time you all agreed).
function M:table_verdicts()
    local mins = self.table_min
    local soft = (self.ended_on_cliff or self.end_early) and 0.5 or 1   -- a cliffhanger softens both
    local out = { minutes = mins, planned = self.table_planned, players = {} }
    for _, p in ipairs(self.players) do
        local ideal = self:ideal_minutes(p)
        local v
        if mins > ideal + 15 then
            local over = (mins - ideal) / 60
            score.add(p, "fun", -math.min(10, 7 * over) * soft)
            if over > 0.75 then
                score.add(p, "commitment", -1.5 * soft)
            end
            v = "long"
        elseif mins < ideal - 45 then
            score.add(p, "fun", -math.min(6, 3 * (ideal - mins) / 60) * soft)
            v = "short"
        else
            score.add(p, "fun", 1)
            v = "right"
        end
        out.players[p.key] = { verdict = v, ideal = ideal, fading_at = self.fading and self.fading[p.key] }
        if mins > self.table_planned + 15 and ideal < mins then
            score.add(p, "trust", -1)   -- "you said half ten"
        end
    end
    self.table_report = out
end

-- The report's line about the night's length: "Ran 40 minutes long. Sam was fading by 10:15;
-- Dev wanted more."
function M:length_text()
    local r = self.table_report
    if not r then
        return nil
    end
    local function hm(m)
        local h = math.floor(m / 60)
        local mm = math.floor(m % 60 + 0.5)
        return util.int(h) .. "h" .. (mm > 0 and (" " .. util.int(mm) .. "m") or "")
    end
    local diff = r.minutes - r.planned
    local head
    if diff > 15 then
        head = "Ran " .. hm(diff) .. " long (" .. hm(r.minutes) .. ", planned " .. hm(r.planned) .. ")."
    elseif diff < -30 then
        head = "Finished " .. hm(-diff) .. " early (" .. hm(r.minutes) .. ")."
    else
        head = "Right on time (" .. hm(r.minutes) .. ")."
    end
    local parts = {}
    for _, p in ipairs(self.players) do
        local v = r.players[p.key]
        if v and v.verdict == "long" then
            table.insert(parts, p.name .. " was fading" .. (v.fading_at and (" by " .. self:clock_text(v.fading_at)) or ""))
        elseif v and v.verdict == "short" then
            table.insert(parts, p.name .. " wanted more")
        end
    end
    if #parts == 0 then
        return head .. " It suited everyone."
    end
    return head .. " " .. table.concat(parts, "; ") .. "."
end

-- Who leads the way takes turns over the campaign (A4): among those decent at it, whoever has
-- led least lately goes first, unless it's someone's own story.
function M:scout_roller(sc)
    local list = { "stealth", "perception", "survival", "athletics" }
    local camp = self.campaign
    camp.scouted = camp.scouted or {}
    local best = self:pick_roller(list, sc)
    local owner = sc and sc.owners_rolled and sc.owners_rolled[best.key]
    if not owner then
        local least, ln
        for _, p in ipairs(self.players) do
            local _, m = self:best_skill(p, list)
            local n = camp.scouted[p.key] or 0
            if m >= 3 and (not ln or n < ln) then
                least, ln = p, n
            end
        end
        if least and ln < (camp.scouted[best.key] or 0) then
            best = least
        end
    end
    camp.scouted[best.key] = (camp.scouted[best.key] or 0) + 1
    return best
end

function M:scout(sc)
    local indoors = false
    for _, set in ipairs(sc.comps.location and sc.comps.location.setting or {}) do
        indoors = indoors or INDOORS[set] or false
    end
    local best = self:scout_roller(sc)
    self.actor = best
    self.other = nil
    self:say(self:fresh(SCOUT[best.class] or SCOUT.rogue, "scout_" .. best.class), "goal")
    self:react({ [best.key] = "lean" })
    local spec = { dc = 12 + (sc.difficulty - 2), convenient = "success", skill = { "stealth", "perception" },
                   act = "scout", fail_replaces = true, quiet = true,     -- (spotting them first isn't a recap beat)
                   success = { log = self:fresh(SPOTTED.success, "spot_yes"),
                               effects = { { "actor", spotlight = 8 }, { "arch:tactician", fun = 4 } } },
                   fail = { log = self:fresh(indoors and SPOTTED.fail_in or SPOTTED.fail, "spot_no"),
                            effects = { { "all", challenge = 6 }, { "arch:butt_kicker", fun = 2 } } } }
    table.insert(self.decisions, { card = "scout", option = 0, rolls = {} })
    local ok = self:big_roll(spec)
    sc.surprise = ok and "foes" or "party"
end

-- The scene's decision card (once per scene), dealt partway through the checks.
function M:scene_card(sc)
    if sc.card_done then
        return
    end
    sc.card_done = true
    local card = self:pick_decision(sc)
    if card then
        self:decision(card)
        local rec = self.decisions[#self.decisions]
        if rec and #rec.rolls > 0 then
            sc.had_roll = true
        end
    end
end

-- A short back-and-forth with the scene's cast, the DM doing the voice.
function M:conversation(sc)
    if not sc.comps.cast then
        return
    end
    local talkers = {}
    for _, p in ipairs(self.players) do
        local w = score.arch(p, "method_actor") * 2 + score.arch(p, "storyteller") + score.arch(p, "casual") * 0.5
            + self.rng:next()
        table.insert(talkers, { p, w })
    end
    table.sort(talkers, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(2, #talkers) do
        local p = talkers[i][1]
        self.actor = p
        self:bark(p, "npc_talk")
        self:npc_line(self.rng:chance(0.6) and "good" or "greet")
        score.add(p, "social", 4)
        score.add(p, "spotlight", 2)
    end
end

-- Halfway through a scene: one moment worth a paused roll, and the DM's ruling on it.
function M:moment(sc)
    local beats = content.scene_beats.moment
    local comp = sc.comps.complication
    local m = (comp and not comp.cliffhanger and not self:muted(comp) and self:fits_here(comp) and beats.complication)
        or beats[sc.type]
    if not m or not self:room(12) then
        return
    end
    local skill = (m == beats.complication and comp and comp.skill) or m.skill
    -- Who rolls (A4): their story, or the best at it among those who've had less of the spotlight.
    local best = self:pick_roller(skill, sc)
    self.actor = best
    self.other = nil
    local extra = { complication = comp and soft_lower(comp.name) or "" }
    self:say(m.text, "goal", extra)
    self:react({ [best.key] = "lean" })
    table.insert(self.decisions, { card = "moment_" .. sc.type, option = 0, rolls = {} })
    local ok = self:big_roll({ dc = m.dc + (sc.difficulty - 2), convenient = "success", success = m.success, fail = m.fail,
                               skill = skill })
    if ok then
        sc.progress.wins = sc.progress.wins + 1
    else
        sc.progress.setbacks = sc.progress.setbacks + 1
    end
end

-- A non-combat scene's big moment: one paused roll, then the DM's ruling.
-- Traps (A10): in a puzzle or exploration scene, a trap card is the scene's whole encounter.
-- The DM calls how they go in; a search can find it (SRD 5.2.1's DCs), it's disarmed or stepped
-- around, or it springs and the heroes take it on their sheets (HP carries on, A16).
local TRAP_PICK = {
    under = { "spiked_pit", "poisoned_darts", "collapsing_roof", "hidden_pit" },
    ruin = { "collapsing_roof", "poisoned_darts", "fire_statue", "hidden_pit" },
    indoor = { "poisoned_needle", "poisoned_darts", "fire_statue", "falling_net" },
    wild = { "falling_net", "hidden_pit" },
}

function M:trap_for(sc)
    local comp = sc.comps.complication
    if not comp or not (comp.trap or comp.id == "trap") or self:muted(comp) then
        return nil
    end
    if sc.type ~= "puzzle" and sc.type ~= "exploration" and sc.type ~= "mystery" then
        return nil
    end
    if sc.trap_id then
        return sc.trap_id
    end
    if comp.trap and comp.trap ~= true then
        sc.trap_id = comp.trap
        return sc.trap_id
    end
    local loc = sc.comps.location
    local pool
    for _, s in ipairs({ "under", "ruin", "indoor", "wild" }) do
        if not pool and loc and util.contains(loc.setting or {}, s) then
            pool = TRAP_PICK[s]
        end
    end
    pool = pool or TRAP_PICK.ruin
    sc.trap_id = pool[self.rng:int(1, #pool)]
    return sc.trap_id
end

local function roll_dice(rng, d)
    local n = d[3] or 0
    for _ = 1, d[1] do
        n = n + rng:int(1, d[2])
    end
    return n
end

-- Whoever walks into it takes what the SRD says.
function M:spring_trap(sc, t)
    local fight = require "game.model.fight"
    local creature = require "game.rules.creature"
    fight.party(self)
    local sp = t.sprung
    local victims = { self.actor or self.players[1] }
    if sp.who == "near" then
        local other = self:pick_actor(nil, victims[1])
        if other then
            table.insert(victims, other)
        end
    end
    self:say("The " .. string.lower(t.name) .. " goes off.", "bad")
    local poses = {}
    for _, q in ipairs(self.players) do
        poses[q.key] = "gasp"
    end
    self:react(poses)
    for _, p in ipairs(victims) do
        local c = self.pcs and self.pcs[p.key]
        if c and not c.dead then
            local saved = false
            if sp.save then
                local roll = self.rng:d20()
                local total = roll + creature.save_bonus(c, sp.save[1])
                saved = total >= sp.save[2]
                self:say(p.char .. " makes a " .. string.upper(sp.save[1]) .. " save: " .. util.int(total) .. " against DC "
                    .. util.int(sp.save[2]) .. (saved and ". Made it." or ". Failed."), "dice")
            end
            local dmg = 0
            if sp.damage and not (saved and not sp.half) then
                if sp.darts then
                    local n = self.rng:int(sp.darts[1], sp.darts[2])
                    for _ = 1, n do
                        dmg = dmg + roll_dice(self.rng, sp.damage)
                    end
                else
                    dmg = roll_dice(self.rng, sp.damage) + (sp.extra and roll_dice(self.rng, sp.extra) or 0)
                end
                if saved and sp.half then
                    dmg = math.floor(dmg / 2)
                end
            end
            if dmg > 0 then
                c.hp = c.hp - dmg
                self:say(p.char .. " takes " .. util.int(dmg) .. " damage (" .. util.int(math.max(0, c.hp)) .. "/"
                    .. util.int(c.hp_max) .. " HP).", "bad")
                if c.hp <= 0 then
                    -- Down outside a fight: the others get them breathing again (a Healing Word, a potion, a slap).
                    c.hp = 1
                    self:say(p.char .. " drops. The others get " .. p.char .. " back on their feet with 1 HP.", "bad")
                end
            end
            if sp.condition == "restrained" and not saved then
                self:say(p.char .. " is tangled in the net until someone cuts " .. p.char .. " free (an action, Strength (Athletics) DC "
                    .. util.int(sp.escape[3]) .. ").", "bad")
            elseif sp.condition == "poisoned" and not saved then
                c.poisoned_hour = true
                self:say(p.char .. " is Poisoned for the next hour.", "bad")
            end
            if sp.climb then
                self:say("Getting out of the pit takes rope and a hand up.", "aside")
            end
            score.add(p, "fun", -2)
            score.add(p, "challenge", 3)
        end
    end
end

function M:trap_scene(sc, tid)
    local hz = require "game.rules.data.hazards"
    local t = hz.traps[tid]
    local find_skill, dc = t.find[2], t.find[3]
    local scout = self:pick_roller({ find_skill }, sc, { "explorer", "tactician" })
    self.actor, self.other = scout, nil
    local passive_ok = find_skill == "perception"
    local card = {
        id = "trap_" .. tid, type = "rules",
        title = "A " .. string.lower(t.name) .. " ahead",
        text = "Only you know it's there: " .. t.about .. " (" .. t.src .. ") How do they go in?",
        options = {
            { label = "{actor_char} checks ahead (" .. skills.name(find_skill) .. ", DC " .. util.int(dc) .. ")",
              log = "{actor_char} goes first, slowly, looking at everything.", mode = "search",
              effects = { { "arch:tactician", fun = 3 }, { "arch:explorer", fun = 3 } } },
            { label = passive_ok and "Everyone watches where they step (passive Perception)" or "Everyone just walks carefully",
              log = "You ask what everyone's watching, and check it against the trap.", mode = "passive",
              effects = { { "arch:casual", fun = 2 } } },
            { label = "Keep it moving: they walk right in",
              log = "No time for poking at floors. In they go.", mode = "rush",
              effects = { { "arch:butt_kicker", fun = 3 }, { "arch:tactician", trust = -2 } } },
        },
    }
    local o = self:decision(card)
    local found = false
    if o.mode == "search" then
        self.actor = scout
        found = self:big_roll({ dc = dc - M.DC_SHIFT, skill = { find_skill }, convenient = "success",
                                success = { log = "{actor_char} stops dead. There: " .. string.lower(t.about), effects = { { "actor", spotlight = 8 } } },
                                fail = { log = "Nothing looks wrong. {actor_char} steps forward." } })
    elseif o.mode == "passive" and passive_ok then
        local best, bv
        for _, p in ipairs(self.players) do
            local v = 10 + self:mod_for(p, "perception")
            if not bv or v > bv then
                best, bv = p, v
            end
        end
        found = bv >= dc
        self.actor = best
        self:say(best.char .. "'s passive Perception is " .. util.int(bv) .. " against DC " .. util.int(dc) .. ". "
            .. (found and (best.char .. " spots it.") or "Nobody notices a thing."), "dice")
    end
    local sprung = not found
    if found then
        local d = t.disarm
        if d.none then
            self:say(d.text, "good")
        else
            self.actor = self:pick_roller({ d[2] }, sc)
            local ok = self:big_roll({ dc = d[3] - M.DC_SHIFT, skill = { d[2] }, convenient = "success",
                                       success = { log = d.text .. " Done.", effects = { { "actor", spotlight = 6 } } },
                                       fail = { log = "{actor_char} can't make it work." } })
            if not ok and tid == "poisoned_needle" then
                sprung = true                          -- (a failed disarm sets the needle off, p. 200)
            elseif not ok then
                self:say("They give it a wide berth instead.", "aside")
            end
        end
    end
    if sprung then
        self:spring_trap(sc, t)
    else
        self:highlight(5, "The party gets past the " .. string.lower(t.name), { self.actor })
    end
    sc.trap_sprung = sprung
    sc.outcome = sprung and "lose" or "win"
    sc.had_roll = true
end

function M:climax(sc)
    local st = content.scenes[sc.type]
    local cl = st.climax
    if not cl or sc.cut or sc.had_roll then
        return
    end
    local trap = self:trap_for(sc)
    if trap then
        return self:trap_scene(sc, trap)
    end
    -- The same big moment, told the way it fits this place (and whether anyone's there to talk to).
    local loc = sc.comps.location
    local has_cast = sc.comps.cast and not self:muted(sc.comps.cast)
    local function ok(v)
        return content.fits_setting(v, loc) and (not v.cast or has_cast)
    end
    if not ok(cl) then
        for _, v in ipairs(cl.variants or {}) do
            if ok(v) then
                cl = { text = v.text, dc = cl.dc, prefer = cl.prefer, skill = v.skill or cl.skill,
                       success = cl.success, fail = cl.fail }
                break
            end
        end
    end
    -- Whoever this scene is made for steps up (and is good at what it asks) (A4).
    local best = self:pick_roller(cl.skill, sc, cl.prefer)
    self.actor = best
    self.other = nil
    self:say(cl.text, "goal")
    self:react({ [best.key] = "lean" })
    -- The goal pays off in its own words (the slice rework): the map found, the culprit named.
    local success, fail = cl.success, cl.fail
    local goal = sc.comps.goal
    if goal and goal.win and not self:muted(goal) then
        success = { log = goal.win, effects = cl.success.effects }
        fail = { log = goal.lose or cl.fail.log, effects = cl.fail.effects }
    end
    local spec = { dc = cl.dc + (sc.difficulty - 2) + (sc.edge or 0), convenient = "success", success = success,
                   fail = fail, skill = cl.skill }
    table.insert(self.decisions, { card = "climax_" .. sc.type, option = 0, rolls = {} })
    local ok = self:big_roll(spec)
    sc.outcome = ok and "win" or "lose"
    sc.goal_said = true
    self:goal_event(sc)
    self:pay_goal_clue(sc)
end

-- What the scene's goal came to, for the recap ("In the scramble, the relic is gone").
function M:goal_event(sc)
    local goal = sc.comps.goal
    if goal and goal.win and not self:muted(goal) then
        local text = sc.outcome == "win" and goal.win or (goal.lose or goal.win)
        text = util.sentence_case(util.fill(text, self:vars()))     -- as it was said ({Cast}, {deal}...)
        self:event("goal", { who = "party", text = text, weight = sc.outcome == "win" and 6 or 7 })
    end
end

-- The goal's story clue, held back from the scene's first line, lands now: when it pays off,
-- or (the story still moving) when it doesn't.
function M:pay_goal_clue(sc)
    local gc = sc.goal_clue
    if gc then
        sc.goal_clue = nil
        self:found_clue(gc.id, gc.text)
    end
end

-- A scene that settled without its big moment (the scene card's own roll, a cut, a fight):
-- how it went, and its goal's payoff in its own words.
function M:settle_scene(sc)
    if not sc.outcome then
        local pr = sc.progress
        if sc.result then
            sc.outcome = sc.result.winner == "party" and "win" or "lose"
        elseif pr then
            sc.outcome = (pr.wins >= pr.setbacks) and "win" or "lose"
        else
            sc.outcome = "win"
        end
    end
    local goal = sc.comps.goal
    if goal and goal.win and not sc.goal_said and not self:muted(goal) and not self.end_early then
        sc.goal_said = true
        self:say(sc.outcome == "win" and goal.win or (goal.lose or goal.win), sc.outcome == "win" and "good" or "bad")
        self:goal_event(sc)
    end
    self:pay_goal_clue(sc)
    self:note_outcome(sc)
end

-- The notebook (the slice rework, S5) -----------------------------------------------------------

-- The person in this scene the notebook keeps a card for (not a beast, not muted).
function M:cast_person(sc)
    local cast = sc and sc.comps.cast
    if not cast or self:muted(cast) then
        return nil
    end
    return ledger.person_of(cast), cast
end

function M:note(sc, entry)
    entry.s = sc and sc.index
    entry.at = entry.at or (sc and sc.comps.location and sc.comps.location.id)
    table.insert(self.ledger, entry)
    return entry
end

-- The night's events (M8, B1). The notebook's ledger is the one event log: besides who did
-- what to whom, it keeps the moments a table talks about afterwards. Recaps, running jokes,
-- awards, Grudge and the report all read these; nothing reads the raw night.
--   ev     the kind: moment, crit, fumble, down, death, killing_blow, inspiration, clue, payoff,
--          cooked, callout, fail_card, jail, joke, theory, escape, villain_falls, stunt, curveball
--   who    the player it's about (a key), or "party"; keys: everyone in it
--   to     a person or faction it touched, if any;  text: a line for the recap
--   weight how big a moment it was, 1 to 10;  tags: anything a reader filters on
M.EVENT_WEIGHT = { moment = 4, crit = 6, fumble = 5, down = 6, death = 10, killing_blow = 8, inspiration = 5,
                   clue = 5, payoff = 8, cooked = 3, callout = 6, fail_card = 4, jail = 3, joke = 4, theory = 7,
                   escape = 7, villain_falls = 9, stunt = 5, curveball = 5, talk = 6, boss_turn = 3, taunt = 6, interrupt = 6,
                   retort = 9 }

function M:event(ev, fields)
    local e = fields or {}
    e.ev = ev
    e.weight = e.weight or M.EVENT_WEIGHT[ev] or 3
    e.clock = self.clock
    e.who = e.who or "party"
    -- Who it was, and which villain saw it (the villain's ledger reads these).
    if e.who ~= "party" and not e.char then
        local p = self.campaign:player(e.who)
        e.char = p and p.char or nil
    end
    if self.villain_here and e.villain == nil then
        e.villain = self.villain_here
    end
    if M.SNAP_KINDS[ev] and (e.weight or 0) >= 6 then
        self:snapshot(e.text, e.weight, e.who)
    end
    return self:note(self.scene, e)
end

-- Snapshots (M8, B1): a key moment kept as a scene description, not a picture: the terrain set,
-- every mini and its square, the camera, a caption in the DM's hand and who was in it. The
-- report re-stages one on the table to show it. Six a night at most catch themselves; the DM can
-- take three more with the camera button.
M.SNAP_KINDS = { death = true, killing_blow = true, villain_falls = true, theory = true, crit = true, escape = true,
                 goodbye = true, payoff = true, defeat = true, new_character = true }
M.SNAP_AUTO, M.SNAP_DM = 6, 3

function M:snapshot(caption, weight, who, by_dm)
    self.snapshots = self.snapshots or {}
    self.snaps_auto, self.snaps_dm = self.snaps_auto or 0, self.snaps_dm or 0
    if by_dm then
        if self.snaps_dm >= M.SNAP_DM then
            return nil, "Three a night: that's your camera roll."
        end
        self.snaps_dm = self.snaps_dm + 1
    else
        if self.snaps_auto >= M.SNAP_AUTO then
            return nil
        end
        self.snaps_auto = self.snaps_auto + 1
    end
    local st = self.stage_now or {}
    local minis = {}
    for _, p in ipairs(st.party or {}) do
        table.insert(minis, { id = p.id, class = p.class, x = p.x, y = p.y, side = "party" })
    end
    if st.npc then
        table.insert(minis, { id = "npc", cast = st.npc.cast, x = st.npc.x, y = st.npc.y, side = "npc" })
    end
    -- Mid-fight, the mat as it stands: heroes and monsters where they are now.
    if self.battle and self.battle.creatures then
        minis = {}
        for _, c in ipairs(self.battle.creatures) do
            if not c.removed and c.x then
                table.insert(minis, { id = c.mini, class = c.class, monster = c.monster_id, x = c.x, y = c.y,
                                      side = c.side == "party" and "party" or "foe", down = c.dead or c.down or nil })
            end
        end
    end
    local snap = { week = self.campaign.week, scene = self.scene and self.scene.index, terrain = st.board or st.terrain, minis = minis,
                   camera = 2, caption = caption or "", weight = weight or 5, who = who, by_dm = by_dm or nil,
                   title = self.scene and self.scene.title }
    table.insert(self.snapshots, snap)
    return snap
end

-- Tonight's events of a kind (or all of them), in order.
function M:events(ev)
    local out = {}
    for _, e in ipairs(self.ledger) do
        if e.ev and (not ev or e.ev == ev) then
            table.insert(out, e)
        end
    end
    return out
end

-- First time the party meets someone, the notebook starts their card.
function M:note_meeting(sc)
    local pid = self:cast_person(sc)
    if not pid or ledger.met(self.campaign, pid) then
        return
    end
    for _, e in ipairs(self.ledger) do
        if e.to == pid then
            return
        end
    end
    self:note(sc, { who = "party", to = pid, did = "met", d = 0 })
end

-- How the scene went for the person in it: a fight, a deal, a secret out, or help given.
function M:note_outcome(sc)
    local pid, cast = self:cast_person(sc)
    if not pid or not sc.outcome or self.end_early and not sc.terrain then
        return
    end
    local goal = sc.comps.goal
    local win = sc.outcome == "win"
    local fought = (sc.type == "combat" or sc.type == "set_piece") and content.encounters.by_cast[cast.id] ~= nil
    local villain = cast.villain or cast.foe
    local e = { who = "party", to = pid }
    local gwin = goal and not self:muted(goal) and goal.win or ""
    if fought then
        if sc.escaped and sc.escaped[cast.id] then
            e.did, e.d, e.status = "escaped", 0, "got away"
        elseif win then
            e.did, e.d = "beat", villain and 0 or -1
            if villain then
                e.status = "beaten"
                -- A villain with a Grudge falls at last (B6): the payoff is as big as the Grudge.
                local g = ledger.grudge_level(self.campaign, pid)
                if g >= 2 then
                    for _, p in ipairs(self.players) do
                        score.add(p, "story", 3 * g)
                        score.add(p, "investment", g)
                        score.add(p, "fun", g)
                    end
                    self:highlight(10, util.capitalize(cast.short or cast.name) .. " falls at last, after everything", self.players,
                        "villain_falls")
                end
            end
        else
            e.did, e.d = "lost_to", 0
        end
    elseif string.find(gwin, "{deal}", 1, true) then
        e.did, e.d = win and "deal" or "no_deal", win and 1 or 0
        if win and cast.deal then
            e.know = "Agreed: " .. cast.deal .. "."
        end
    elseif string.find(gwin, "{culprit}", 1, true) and not cast.revered and cast.talks ~= false then
        if win then
            e.did, e.d = "exposed", -2
            if cast.secret then
                e.know = util.capitalize(cast.secret) .. "."
            end
        else
            e.did, e.d = "outplayed", 0
        end
    elseif villain then
        e.did, e.d = win and "outplayed" or "lost_to", 0
    else
        e.did, e.d = win and "helped" or "let_down", win and 1 or 0
    end
    self:note(sc, e)
end

-- The bridge out of a scene (A2): what they got, and where they go next.
function M:bridge(sc)
    if self.end_early or sc.index >= #self.scenes then
        return
    end
    local lines = content.scene_beats.bridge
    local nxt = self.scenes[sc.index + 1]
    -- Where they're headed, when the board says (an open scene or an improvised place: nowhere yet).
    local next_place
    local nl = nxt.comps.location
    if nl and not self:muted(nl) and not nxt.open then
        next_place = soft_lower(nl.short or nl.name)
    end
    local loc = sc.comps.location
    local here = loc and soft_lower(loc.short or loc.name) or "this place"
    local got, set
    if sc.outcome == "win" then
        local goal, reward = sc.comps.goal, sc.comps.reward
        if reward and not self:muted(reward) then
            got, set = soft_lower(reward.got or reward.name), "got"
        elseif goal and goal.got and not self:muted(goal) then
            got, set = goal.got, "goal"
        end
    end
    set = set or (sc.outcome == "win" and "won" or "lost")
    local key = next_place and set or (set .. "_here")
    local text = util.fill(self:fresh(lines[key], "bridge_" .. key),
        { got = got or "", Got = util.capitalize(got or ""), next = next_place or "", here = here })
    self:say(text, "bridge")
end

function M:play_scene(sc)
    self.scene = sc
    self.actor, self.other = nil, nil
    if sc.open and not sc.chosen then
        self:open_scene(sc)
    end
    -- Nobody wrote down where this happens: the DM makes it up before anyone asks. That's
    -- the scene's one improvised slot; anything else left empty just plays thinner.
    local improvised_first = false
    if not sc.comps.location then
        self.pre_scene = true
        self:improvise("location")
        self.pre_scene = false
        improvised_first = true
        for k, kind in ipairs(sc.missing) do
            if kind == "location" then
                table.remove(sc.missing, k)
                break
            end
        end
    end
    sc.terrain = self:terrain_for(sc)
    sc.title = self:scene_title(sc)
    self.villain_here = villains.present(self, sc)     -- the villain who remembers this scene
    if self.villain_here then
        villains.state(self.campaign, self.villain_here).seen = self.campaign.week
    end
    local party, npc = self:staging(sc)
    local cast = sc.comps.cast
    local goal = sc.comps.goal
    local is_story = false
    for _, kind in ipairs(content.kinds) do
        local c = sc.comps[kind]
        if c and self.prep.arc_cards and self.prep.arc_cards[c.id] then
            is_story = true
        end
    end
    self.stage_now = { terrain = sc.terrain, board = self:board_for(sc), party = party, npc = npc }
    local map = self:map_for(sc)
    self:board_set(self:board_for(sc), sc)
    self:emit({ kind = "scene", index = sc.index, total = #self.scenes, title = sc.title, type = sc.type, board = self:board_for(sc),
                type_name = content.scenes[sc.type].name, terrain = sc.terrain, party = party, npc = npc,
                npc_hidden = npc ~= nil,
                pieces = map and map.template == sc.terrain and maps.cells(map) or nil,
                cast = cast and cast.name, goal = goal and goal.name, story = is_story })
    -- An empty slot is improvised once the scene is set (the place described, the person named),
    -- never before the table knows where they are (the October 12 UI playtest).
    local improv_slot
    if improvised_first then
        sc.quality = sc.quality - 0.03 * #sc.missing
    elseif #sc.missing > 0 then
        improv_slot = sc.missing[1]
        sc.quality = sc.quality - 0.03 * (#sc.missing - 1)
    end
    self:safety_check(sc)
    local module = sc.module and require("game.model.books").module(sc.module)
    -- The person in the scene appears on the mat when the DM names them (or they speak).
    self.npc_pending = npc ~= nil or nil
    if module then
        self:say(module.read_aloud, "narration")      -- the book's own boxed text, read out
    else
        self:describe(sc.comps.location, "narration")
    end
    self:dress_board()
    if improv_slot == "cast" then
        self:improvise("cast")
        improv_slot = nil
    end
    self:note_meeting(sc)
    -- Taking over (B8): a key person's first big scene tonight, and the DM speaks for them.
    local talk_now = takeover.talk_ready(self, sc)
    if sc.comps.cast and not self:muted(sc.comps.cast) then
        self.npc_cue = true
        self:describe(sc.comps.cast, "narration")
        self.npc_cue = nil
        if not (sc.type == "combat" or sc.type == "set_piece") and not talk_now then
            self:npc_line("greet")
        end
    end
    self:describe(sc.comps.goal, "goal")
    if improv_slot then
        self:improvise(improv_slot)
    end
    if sc.index == 1 then
        self:plant_seed()
    end
    for _, kind in ipairs(content.kinds) do
        local c = sc.comps[kind]
        if c and c.payoff_of and kind ~= "reward" then
            self:pay_off(c)
        end
    end
    self:story_beat(sc)
    -- The storylines this scene moves (game/model/storylines.lua): a dropped one coming back,
    -- two scenes on the same one, or more than the table can follow tonight.
    require("game.model.storylines").on_scene(self, sc)
    require("game.model.handouts").on_scene(self, sc)        -- a handout you made lands now
    -- Backstory threads in this scene.
    local announced = {}
    for _, kind in ipairs(content.kinds) do
        local c = sc.comps[kind]
        if c and c.thread then
            for _, p in ipairs(self.players) do
                if p.key == c.thread then
                    p.thread_hits = p.thread_hits + 1
                    self.thread_said = self.thread_said or {}
                    if not announced[p.key] and not self.thread_said[p.key] then
                        announced[p.key] = true
                        self.thread_said[p.key] = true
                        self:react({ [p.key] = "lean" })
                        self:say(p.name .. " sits up. This is about " .. p.char .. "'s past.", "thread")
                        self:bark(p, "thread")
                        self:highlight(7, p.char .. "'s backstory finally comes up", { p }, "thread")
                        if p.key == "mara" then
                            self:conflict_tone(sc)
                        end
                    end
                end
            end
        end
    end
    -- What the scene gives everyone, and who's into it.
    local fans, grumps = {}, {}
    for _, p in ipairs(self.players) do
        local g = score.scene_gains(p, sc, score.mood(p))
        for _, k in ipairs(score.METERS) do
            score.add(p, k, g[k])
        end
        p.fun_bonus = p.fun_bonus + g.fun
        score.add(p, "boredom", g.boredom)
        score.nudge_engagement(p, score.enjoyment(p, g))
        local taste = score.taste(p, sc.type)
        if taste >= 1.3 then
            table.insert(fans, p)
        elseif taste <= 0.7 then
            table.insert(grumps, p)
        end
    end
    local poses = {}
    for _, p in ipairs(fans) do
        poses[p.key] = "lean"
    end
    self:react(poses)
    if #fans > 0 then
        self:bark(self.rng:pick(fans), "scene_like")
    end
    if #grumps > 0 and self.rng:chance(0.6) then
        -- "Another fight?" only when there's been one: earlier tonight, or last week.
        local last = self.campaign.last_scene_types
        local before = (self.types_seen and self.types_seen[sc.type]) or (last ~= nil and util.contains(last, sc.type))
        self:bark(self.rng:pick(grumps), "scene_dislike", { again = before and true or false })
    end
    self.types_seen = self.types_seen or {}
    self.types_seen[sc.type] = true
    if not self.drift_used and sc.index >= 2 and self:room(12) then
        local pull = 0.2
        for _, p in ipairs(self.players) do
            pull = pull + 0.1 * (score.arch(p, "instigator") + score.arch(p, "explorer"))
        end
        if self.rng:chance(pull) then
            self:drift()
        end
    end
    if module then
        self:module_line(sc, 1)
    end
    if sc.type == "combat" or sc.type == "set_piece" then
        if module then
            self:module_line(sc, 2)
        end
        if talk_now then
            takeover.talk(self, sc)        -- a word before the fight (B8), in place of the fight's card
        end
        self:combat_scene(sc)
    else
        if module then
            self:module_line(sc, 2)
        end
        if not (talk_now and takeover.talk(self, sc)) then
            self:conversation(sc)
        end
        self:conflict_spotlight(sc)
        self:quick_checks(sc)
        if not self.end_early then
            self:climax(sc)
        end
    end
    self:settle_scene(sc)
    if module then
        if sc.outcome == "win" then
            self:module_line(sc, 3)
        end
        self:module_verdict(sc)
    end
    if sc.comps.reward and not self.end_early and sc.outcome == "lose" then
        -- A reward they didn't win is still out there (it stays in the story deck).
        local r = sc.comps.reward
        if not self:muted(r) then
            self:say("Not tonight: " .. soft_lower(r.got or r.name) .. " stays out of reach. It's still out there.", "bad")
        end
    elseif sc.comps.reward and not self.end_early then
        local r = sc.comps.reward
        if not self:muted(r) then
            local rev = story.pending_reveal(self.campaign, r)
            if rev and not self.revealed[r.id] then
                self:describe(r, "reward")
            else
                self:say("They earn " .. soft_lower(r.line), "reward")
            end
        end
        if r.payoff_of then
            self:pay_off(r)
        end
        local fans2 = {}
        local rposes = {}
        for _, p in ipairs(self.players) do
            local like = 0
            for _, t in ipairs(r.tags) do
                like = like + score.like(p, t)
            end
            if like >= 1.2 or r.thread == p.key then
                table.insert(fans2, p)
                score.add(p, "fun", 3)
                rposes[p.key] = "cheer"
            end
        end
        self:react(rposes)
        if #fans2 > 0 then
            self:bark(self.rng:pick(fans2), "reward_like")
        end
    end
    -- A cliffhanger is the last thing that happens in its scene.
    if sc.comps.complication and sc.comps.complication.cliffhanger and not self:muted(sc.comps.complication) then
        self:describe(sc.comps.complication, "twist")
        -- And the last thing tonight (the story playtest: two more scenes after the horns sounded
        -- made the cliffhanger a shrug). The rest of the plan keeps for next week.
        self.ended_on_cliff = true
        if sc.index < #self.scenes then
            self.cliff_stop = true
            self:say("You stop right there. \"And that's where we leave it for tonight.\" The groan is the best review you'll get.", "dm")
            return
        end
    end
    -- What the characters do to each other (A17): a rub, or a bond.
    self:party_moment(sc)
    -- The players may ask to rest (A16).
    self:rest_request(sc)
    self:bridge(sc)
    if sc.index < #self.scenes then
        self:table_check(sc)
        -- Between scenes the table chats while you reset the terrain.
        local p = self.rng:pick(self.players)
        self:bark(p, "between")
    end
    self:maybe_callout(0)
end

function M:intro()
    local who = {}
    for _, p in ipairs(self.players) do
        table.insert(who, p)
    end
    self.rng:shuffle(who)
    for i = 1, math.min(2, #who) do
        self:bark(who[i], "arrive")
    end
    -- Before the session starts: new dice (a gift from last week, or a set someone treated
    -- themselves to and has to show everyone).
    self:dice_moment()
    require("game.model.keepsakes").at_night(self)   -- the gifts on your side of the table
    self:say("Everyone's here. Dice out.", "system")
    self:table_behavior("start")
    if self.campaign.week == 1 then
        -- The first session: everyone introduces themselves and their hero.
        intros.run(self)
    else
        -- The DM's opening: last session's big beats, then where they are and what they're after.
        local recap = recap_mod.last_session(self.campaign) or story.recap(self.campaign)
        if recap then
            local last = story.init(self.campaign).weeks[self.campaign.week - 1]
            if last and last.cliff and not string.find(recap, "cliffhanger") then
                recap = recap .. " And it ended on a cliffhanger."
            end
            self:say(recap, "recap")
        end
        local here = self:here_today()
        if here then
            self:say(here, "recap")
        end
    end
    -- Where they left off, if they haven't rested since (A16): what the sheets say.
    local ps = self.campaign.party_state
    if ps and not ps.rested and ps.level == (self.campaign.level or 2) then
        fight.party(self)
        local hurt = {}
        for _, c in ipairs(self.pc_list or {}) do
            local bits = {}
            if c.hp < c.hp_max then
                table.insert(bits, util.int(c.hp) .. "/" .. util.int(c.hp_max) .. " HP")
            end
            local s = rest_rules.state({ c })
            if c.slots_max and s.slots < 1 then
                local left = 0
                for _, n in ipairs(c.res.slots or {}) do
                    left = left + n
                end
                table.insert(bits, util.int(left) .. (left == 1 and " spell slot" or " spell slots") .. " left")
            end
            if #bits > 0 then
                table.insert(hurt, c.name .. " " .. table.concat(bits, ", "))
            end
        end
        if #hurt > 0 then
            self:say("Where we left off, no rest since: " .. table.concat(hurt, "; ") .. ".", "recap")
        end
    end
    local beat = self.campaign:arc_beat()
    if beat and beat.open then
        local open = beat.open
        local hit = beat.open_if and story.has_clue(self.campaign, beat.open_if.clue)
        if hit then
            open = beat.open_if.text
        end
        -- The opening agrees with the board (A11): it only names a place if scene 1 is there.
        local first = self.scenes[1]
        local loc = first and first.comps.location
        local places = type(beat.open_place) == "table" and beat.open_place or { beat.open_place }
        if beat.open_place and not (loc and util.contains(places, loc.id)) then
            open = (hit and beat.open_else_if) or beat.open_else or open
        elseif beat.open_place and deck.returning(self.campaign, loc) then
            -- They've been there: the opening doesn't present it as new; the place's own "again"
            -- line follows when the scene starts.
            open = (hit and beat.open_again_if) or beat.open_again or (hit and beat.open_else_if) or beat.open_else or open
        end
        self:say(open, "opening")
    end
    death_mod.intro(self)   -- a new character joins (B3)
end

-- "And here we are today: you're at <place>, and you're out to <objective>." Where scene 1 is,
-- and what this week's story is after (game/data/arc.lua objective; objective_if once they know
-- the clue it hangs on).
function M:here_today()
    local first = self.scenes[1]
    local loc = first and first.comps.location
    local beat = self.campaign:arc_beat()
    local obj = beat and beat.objective
    if beat and beat.objective_if and story.has_clue(self.campaign, beat.objective_if.clue) then
        obj = beat.objective_if.text
    end
    if not loc then
        return obj and ("And here we are today: you're out to " .. obj .. ".") or nil
    end
    local set = loc.setting or {}
    local prep = "at"
    if util.contains(set, "road") then
        prep = "on"
    elseif util.contains(set, "under") or (util.contains(set, "indoor") and not util.contains(set, "tavern")
        and not util.contains(set, "crowd")) then
        prep = "in"
    end
    local text = "And here we are today: you're " .. (loc.here or (prep .. " " .. (loc.short or util.lower_first(loc.name))))
    if obj then
        text = text .. ", and you're out to " .. obj
    end
    return text .. "."
end

-- New dice before the session (game/model/dice_sets.lua): last week's gift rolls for the first
-- time, or someone who's all in turns up with a set they bought and shows it off.
function M:dice_moment()
    local dd = dice_sets.data
    local camp = self.campaign
    local p, id = dice_sets.gifted(self)
    if p then
        self:emit({ kind = "dice", who = p.key, set = id, name = dice_sets.name(id), sets = dice_sets.by_tray(camp), gift = true })
        self:emit({ kind = "say", who = p.key, text = dice_sets.line(camp, dd.FIRST_ROLL_LINES, 23), ic = false })
        score.add(p, "fun", dd.GIFT.fun_next)
        for _, q in ipairs(self.players) do
            score.add(q, "social", dd.GIFT.social_all)
        end
    end
    local q, sid = dice_sets.show_off(self)
    if q then
        self:emit({ kind = "dice", who = q.key, set = sid, name = dice_sets.name(sid), sets = dice_sets.by_tray(camp), show = true })
        self:emit({ kind = "say", who = q.key, text = dice_sets.line(camp, dd.SHOW_LINES, 29), ic = false })
        local poses = { [q.key] = "cheer" }
        local others = {}
        for _, r in ipairs(self.players) do
            if r ~= q then
                table.insert(others, r)
            end
        end
        if #others > 0 then
            local r = others[(camp.week % #others) + 1]
            self:emit({ kind = "say", who = r.key, text = dice_sets.line(camp, dd.REACT_LINES, 31), ic = false })
            poses[r.key] = "lean"
        end
        self:react(poses)
        score.add(q, "fun", dd.SHOW_OFF.fun)
        for _, r in ipairs(self.players) do
            score.add(r, "social", dd.SHOW_OFF.social_all)
        end
        self:event("moment", { who = q.key, text = q.name .. " showed off a new set of dice: " .. dice_sets.name(sid), weight = 3 })
    end
end

function M:run()
    self:intro()
    for i, sc in ipairs(self.scenes) do
        if self.end_early or self.cliff_stop then
            break
        end
        -- The escape valve: running long before the last scene.
        -- (By the table clock: it's late when the agreed end is near with a whole scene to go. The
        -- watching clock only backs it up on a very long evening, so the card stays an occasional one.)
        if i == #self.scenes and i > 1 and (self.table_min > self.table_planned - 30 or self.clock > LATE_AFTER)
            and not self.used_cards.running_late
            and self:decision_count() < 13 then
            self.actor = nil
            self:decision(content.triggered.late)
            if self.end_early then
                local prev = self.scenes[i - 1]
                prev.ended_on_cliffhanger = true
                self.ended_on_cliff = true
                break
            end
        end
        if i == #self.scenes and i > 1 then
            self:table_behavior("late")
        end
        self:play_scene(sc)
        if i < #self.scenes then
            self:clock_tells()
        end
    end
    self:table_verdicts()
    -- Where the party is at, for next week (A16): a night that ends in town rests; a cliffhanger
    -- or a night out in the wild picks up exactly where it stopped.
    if self.pc_list then
        local last
        for _, sc in ipairs(self.scenes) do
            if sc.terrain then
                last = sc
            end
        end
        local loc = last and last.comps.location
        local safe = loc and (util.contains(loc.setting or {}, "town") or util.contains(loc.setting or {}, "tavern"))
        local rested = safe and not (self.ended_on_cliff or self.end_early)
        fight.save_state(self, rested)
        if rested then
            self.campaign.party_state.fights_since_long = 0
        end
    end
    -- You asked what they wanted, then gave it to them (A6: the one-on-one).
    local notes = self.prep and self.prep.talk_notes or {}
    for _, p in ipairs(self.players) do
        local n = notes[p.key]
        if n then
            local got = false
            for _, sc in ipairs(self.scenes) do
                if sc.terrain and ((n.want_type and sc.type == n.want_type) or (n.want_thread and p.thread_hits > 0)) then
                    got = true
                end
            end
            if got then
                score.add(p, "fun", 4)
                score.add(p, "trust", 1)
                self:highlight(4, p.char .. " gets what " .. p.name .. " asked for", { p })
            end
        end
    end
    -- How the shape of the night landed.
    local pv = self.pacing
    for _, p in ipairs(self.players) do
        p.fun_bonus = p.fun_bonus + pv.fun_all
        if pv.repeat_type and score.taste(p, pv.repeat_type) < 1 then
            score.add(p, "boredom", 10)
        end
    end
    local played = {}
    for _, sc in ipairs(self.scenes) do
        if sc.terrain then
            table.insert(played, sc)
        end
    end
    local last = played[#played]
    if self.end_early then
        self:say("Groans all round. Nobody wants to wait a whole week.", "good")
    elseif last and last.comps.complication and last.comps.complication.cliffhanger then
        self:say("Groans all round. Nobody wants to wait a whole week.", "good")
    elseif pv.finish_high and next(self.dead_handled or {}) then
        -- Not "applause" after someone's hero died tonight (the story playtest).
        self:say("Nobody's in a hurry to pack up. It was a big night, and a sad one.", "good")
    elseif pv.finish_high and last and last.outcome == "lose" then
        self:say("It ends on a loss, and somehow nobody's sorry they came.", "good")
    elseif pv.finish_high then
        self:say("It ends on a high. Somebody actually applauds.", "good")
    elseif pv.flat then
        self:say("The night never quite catches fire.", "warn")
    end
    self:table_behavior("end")
    -- A couple of goodbyes, not a speech from everyone.
    local leaving = {}
    for _, p in ipairs(self.players) do
        table.insert(leaving, p)
    end
    self.rng:shuffle(leaving)
    for i = 1, math.min(self:idle() > 60 and 1 or 2, #leaving) do
        self:bark(leaving[i], "wrap")
    end
    self:say("That's a wrap. Chairs scrape, someone stacks the dice.", "system")
    self:emit({ kind = "done" })
end

return M
