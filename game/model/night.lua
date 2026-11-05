-- Game night: the director. The adventure's night (game/model/museum_night.lua) walks its map and
-- plays each room through here as a stream of beats for the table (scenery, minis, speech bubbles,
-- dice), runs fights on the M3 rules engine, and pauses for the DM: decision cards, big rolls in
-- front of or behind the screen, and rulings on how they land. Pure Lua.
--
-- The screen calls night:advance(answer) and gets the next beat back. Every beat
-- carries t, its playing time in seconds at normal speed (game/model/pacing.lua).
--   scene      { index, title, type, type_name, terrain, party, npc, cast, goal }
--   narrate    { text, style }                            a caption (narration, goal, twist...)
--   npc        { name, text, cast, line }                 the DM voicing a character
--   say        { who, text, ic, line, part }              a speech bubble over a player (line: its id in
--                                                         the dialogue library; part "reply" for banter replies)
--   react      { poses = { key = pose } }                 players lean in, cheer, gasp...
--   check      { actor, char, skill, skill_name, roll, bonus, total, dc, success, crit, fumble, text }
--                the player rolls d20 + their modifier for the skill against the DC
--   battle     { phase = "start", party, foes, terrain, danger } / { phase = "end", winner }
--   round      { round }
--   turn       { who, side, steps = { move, attack, damage, down, ... }, say, brisk }
--   decision   { card = { id, type, type_name, title, text, options } }    answer = option index
--   roll_where { text, dc, actor, char, skill_name, mod, by }            answer = "open" | "hidden"
--                by = "player": the player rolls their own check; "open" says the DC out loud,
--                "hidden" keeps it behind the screen. by = "dm": a secret check the DM rolls for
--                them, in the open or behind the screen.
--   roll       { where, dc, actor, by }                                  answer = the d20 value
--   ruling     { tier, prompt, value, total, mod, dc, options, cook }    answer = option index, or "cook"
--                (behind the screen: a player's roll moves the secret DC; the DM's own misreports the die)
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
local rest_rules = require "game.rules.rest"
local rapport = require "game.model.rapport"
local rests = require "game.data.rests"
local fails_mod = require "game.model.fails"
local death_mod = require "game.model.death"
local takeover = require "game.model.takeover"
local barks = require "game.model.barks"
local maps = require "game.model.maps"
local dice_sets = require "game.model.dice_sets"
local board_mod = require "game.model.board"
local thoughts = require "game.model.thoughts"
local events = require "game.model.events"
local able = require "game.model.able"
local BARKS = require "game.data.barks"

-- Skills for talking to someone: a hero who uses one walks over to the person (A9).
local SOCIAL_SKILL = { persuasion = true, deception = true, intimidation = true, insight = true, performance = true }
local skills = require "game.rules.skills"

local M = {}
M.__index = M


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
    self.talk = talk_mod.new(self.rng)
    self.talk.openers = {}      -- lines that open alike, once a night (dialogue.opener)
    self.talk:set_present(self.players)
    self.talk:remember_weeks(campaign, 3)   -- a speaker doesn't repeat a line for three weeks (A5)
    self.clock = 0
    self.counts = { decision = 0, ruling = 0 }
    self.fights = 0
    -- A gentler first night (R6, the round-two review: "night 1 hands a newcomer most systems at
    -- once"): on an adventure's first night the DM gets the story's own calls, one big roll to rule on,
    -- one thought and one rules call, each with its tip; the fight's calls, the finds behind the
    -- screen, the table asking you and the rest wait for next week. Off once the tips are off.
    self.gentle = campaign.adv ~= nil and (campaign.week or 1) <= 1 and not (campaign.guide and campaign.guide.off) or nil
    -- "Every roll in the open" at Session Zero covers the DM's own combat rolls too.
    local open_table = campaign.table and campaign.table.rules.dice == "open"
    self.dm_rolls = opts.dm_rolls or campaign.dm_rolls or (open_table and "open") or "hidden"
    self.hidden_dm_rolls, self.open_dm_rolls = 0, 0
    self.lucky_streak = 0
    -- M6: the table conflicts, Session Zero promises.
    self.conflict_moves = {}   -- { id, pressure, progress, resolve, promise, topic } from conflict cards
    self.rules_calls = {}      -- { card, leans, topic } for every rules card
    self.conflict_dealt = {}   -- conflict id -> true once its card came up tonight
    self.safety = {}           -- what happened with lines and veils tonight
    self.promise_noted = {}
    for _, p in ipairs(self.players) do
        score.reset_session(p)
        score.start_carry(p)     -- (how they came in: last session's mood, a week softer)
    end
    self.scenes = {}           -- the rooms, as they're played (museum_night.play)
    self.ledger = {}          -- tonight's events (M:event), for the recap, the awards and the report
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
M.TABLE_MIN = { scene = 7, narrate = 0.45, npc = 0.7, say = 0.2, check = 4.5, decision = 4, ruling = 2.5,
                roll_where = 1.5, turn = 1.0, round = 0.6, dice = 1, intro = 0.5, cinematic = 3 }

function M:emit(ev)
    -- What you did about a friend's thought (game/model/thoughts.lua) lands at the next beat.
    if self.th and not self.th.flushing and #self.th.queue > 0 then
        self.th.flushing = true
        for _, q in ipairs(thoughts.take_queue(self) or {}) do
            self:emit(q)
        end
        self.th.flushing = false
    end
    -- What you did from the screen between beats (the token from a tile): its moment at the table now.
    if self.ui_later and #self.ui_later > 0 and not self.ui_flushing then
        self.ui_flushing = true
        local list = self.ui_later
        self.ui_later = {}
        for _, fn in ipairs(list) do
            fn(self)
        end
        self.ui_flushing = false
    end
    if self.board_id then
        self:board_hear(ev)
    end
    ev.t = pacing.duration(ev)
    self.clock = self.clock + ev.t
    -- Where each hero's mini stands now: a fight starts from there, not from a huddle at the
    -- board's start (the playtest, November 3).
    if ev.kind == "scene" and ev.party then
        self.mini_pos = {}
        for _, q in ipairs(ev.party) do
            if q.id and q.x then
                self.mini_pos[q.id] = { q.x, q.y }
            end
        end
    elseif ev.kind == "walk" and ev.actor and ev.path and #ev.path > 0 then
        self.mini_pos = self.mini_pos or {}
        local last = ev.path[#ev.path]
        self.mini_pos[ev.actor] = { last[1], last[2] }
    elseif ev.kind == "check" and ev.actor and ev.spot then
        self.mini_pos = self.mini_pos or {}
        self.mini_pos[ev.actor] = { ev.spot[1], ev.spot[2] }
    end
    -- How far into the evening: the mood they came in with gives way to tonight (score.fun).
    if self.players and self.table_planned then
        local t = (self.table_min or 0) / math.max(60, self.table_planned)
        for _, p in ipairs(self.players) do
            p.carry_t = t
        end
    end
    -- Each player's night as the table saw it (their tells), for the report's verdict.
    if ev.t > 0 and self.players then
        local lived = self.lived or { time = 0, sum = {}, low = {} }
        self.lived = lived
        lived.time = lived.time + ev.t
        for _, p in ipairs(self.players) do
            local e = p.engagement or 0.5
            lived.sum[p.key] = (lived.sum[p.key] or 0) + e * ev.t
            -- A bad tell on show: drifting, or a bad mood showing (see M:tells).
            if e < M.LOW_TELL or (e < M.MOOD_TELL and ((score.mood(p).fun or 0) < 0)) then
                lived.low[p.key] = (lived.low[p.key] or 0) + ev.t
            end
        end
    end
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
    -- The calls you've answered, as the screen counts them (the newcomer playtest, October 16: the
    -- counter went up when a card came up, and once went down).
    if pacing.DECISION_KINDS[ev.kind] then
        self.answered = (self.answered or 0) + 1
    end
    return answer
end

-- Seconds since the DM last had a choice to make.
function M:idle()
    return self.clock - (self.last_input or 0)
end

function M:decision_count()
    return self.counts.decision + self.counts.ruling
end

-- Room for one more optional call under this cap? Before the last scene, two calls are kept
-- back for it: a last scene with nothing for the DM to decide runs long.
function M:room(cap)
    if self.gentle then
        return false        -- (the first night's optional calls wait for next week: R6)
    end
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
    elseif pacing.DECISION_KINDS[k] or k == "roll_where" or k == "check" or k == "battle" then
        -- Play has started: anything the DM hasn't set out goes down now.
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
        or pacing.DECISION_KINDS[k] or k == "check") then
        -- (Out of sight: the party walks in first, then they're there. sight.lua)
        if not self.seeing then
            self.seeing = true
            self.npc_pending = nil
            self:come_into_view(self.scene)
            self.seeing = nil
        end
        ev.npc_show = true
        self.npc_pending = nil
    elseif self.npc_pending and k == "walk" and not self.seeing and self.scene and self.scene.npc_at then
        -- A hero walked round the corner and can see them now.
        local sight = require "game.model.sight"
        local st = sight.stage(self, self.scene)
        local last = ev.path and ev.path[#ev.path]
        if st and last and sight.los(st, last, self.scene.npc_at) then
            ev.npc_show = true
            self.npc_pending = nil
        end
    end
end

-- The DM sets out the rest of the place in a line, so every piece comes in on a word.
function M:dress_board()
    if not self.board_id then
        return
    end
    local text, list = board_mod.dressing(self.board_id, self.board_shown, 5)
    if text and self.scene and self.scene.room then
        self:emit({ kind = "stage_dress", reveal = list })
        return
    end
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
        -- mentor's ghost; else the Gorgon upstairs.
        local person = cast and not cast.revered and cast.talks ~= false
        v.culprit = person and soft_lower(cast.short or cast.name) or "Euryale"
        v.Culprit = util.capitalize(v.culprit)
        v.secret = person and cast.secret or "they've been covering for someone"
        v.deal = cast and cast.deal or "safe passage, for now"
        v.lead = "the Gorgon upstairs"
        -- A group acts as a group (A3): {one|many} picks the verb.
        v.plural = cast and cast.group and true or false
        -- Who gets caught in a lie: the scene's person, or someone the place would have (A2).
        local loc = sc.comps.location
        local by = M.bystander(loc)
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
    v.question = self.rules_question     -- (what someone wants to look up: fight.lua QUESTIONS)
    for k, val in pairs(self.mus_vars or {}) do
        v[k] = val          -- v2: the museum's own fill-ins (the painting, the Mech's name)
    end
    for k, val in pairs(extra or {}) do
        v[k] = val
    end
    return v
end

-- Skill checks (real-session pass) ---------------------------------------------------------

-- A hero's modifier for a skill, from their character sheet at the party's level.
-- The break's homework (museum_night.maybe_break: "they read up"): +2 on the next rolls tonight.
function M:take_research(p)
    if (self.research or 0) <= 0 then
        return 0
    end
    self.research = self.research - 1
    self:say(util.fill("{char} remembers something from the break's reading: +2.", { char = p.char }), "aside")
    return 2
end

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

-- Who's there to be caught in a lie, by the kind of place (A2: never "the witness" with
-- nobody there).
M.BYSTANDER = {
    tavern = "the barman", market = "a stallholder", shop = "the shopkeeper", crowd = "a gossip in the crowd",
    town = "a shopkeeper", road = "a carter on the road", forest = "a woodcutter", camp = "a camp follower",
    bells = "the bell-ringers' old porter", ruin = "a scavenger in the ruins", wild = "a shepherd",
    under = "a tunnel rat", indoor = "a servant", outdoor = "a passer-by", water = "a boatman",
}
-- The most telling kind of place first: "town" says least (the newcomer playtest, October 16: "a
-- shopkeeper" caught in a lie in Ilsa's empty room, a town place).
M.BYSTANDER_ORDER = { "tavern", "market", "crowd", "shop", "camp", "ruin", "bells", "water", "under", "road", "forest",
                      "wild", "indoor", "outdoor", "town" }

-- Who's around to be caught in a lie at a place: the place's own (its bystander), else the
-- likeliest someone for the kind of place it is.
function M.bystander(loc)
    if loc and loc.bystander then
        return loc.bystander
    end
    local has = {}
    for _, set in ipairs(loc and loc.setting or {}) do
        has[set] = true
    end
    for _, set in ipairs(M.BYSTANDER_ORDER) do
        if has[set] and M.BYSTANDER[set] then
            return M.BYSTANDER[set]
        end
    end
    return "a stallholder who saw too much"
end

-- A caption. Every sentence starts with a capital, whatever was substituted (A3).
-- A line to the table that's really a note only the DM knows ("Behind your screen, you move a note")
-- gets the screen's own caption (the second playtest review).
function M.screen_note(text)
    return type(text) == "string" and string.find(string.lower(text), "behind your screen", 1, true) ~= nil
end

function M:say(text, style, extra)
    if style == "dm" and M.screen_note(text) then
        style = "screen"
    end
    return self:emit({ kind = "narrate", text = util.sentence_case(util.fill(text, self:vars(extra))),
                       style = style or "narration" })
end

-- A line from a list that hasn't been said tonight (A5): each one once before any repeats. With a
-- key, the memory lasts across weeks (November 3: lines repeated from one session to the next):
-- a line said in the last three sessions waits, and when every one has been said lately, the
-- one said longest ago comes back first. Never the same line twice in a row (R2, the second
-- playtest review), and with `once`, never twice in one session: nil once every line has been said
-- tonight.
M.FRESH_WEEKS = 3

function M:fresh(list, key, once)
    if type(list) ~= "table" then
        return list
    end
    local camp = self.campaign
    if key and camp then
        camp.fresh_said = camp.fresh_said or {}
        local said = camp.fresh_said[key] or {}
        camp.fresh_said[key] = said
        camp.fresh_last = camp.fresh_last or {}
        local last = camp.fresh_last[key]
        local week = camp.week or 0
        local free, oldest, ow = {}, nil, nil
        for i, l in ipairs(list) do
            local w = type(l) == "string" and said[l] or nil
            if (#list > 1 and l == last) or (once and w == week) then
                -- (just said, or said tonight already)
            elseif not w or week - w >= M.FRESH_WEEKS then
                table.insert(free, i)
            elseif not ow or w < ow then
                oldest, ow = i, w
            end
        end
        -- (Said tonight beats said last week: tonight's never repeats while anything else is left.)
        local i = (#free > 0 and self.rng:pick(free)) or oldest
        if not i then
            if once then
                return nil
            end
            i = 1
            for j, l in ipairs(list) do
                if l ~= last then
                    i = j
                    break
                end
            end
        end
        local l = list[i]
        if type(l) == "string" then
            said[l] = week
            camp.fresh_last[key] = l
        end
        -- (Forget what's long past, so the save stays small.)
        for t, w in pairs(said) do
            if week - w >= 2 * M.FRESH_WEEKS then
                said[t] = nil
            end
        end
        return l
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
        if once then
            return nil
        end
        local was = used.last
        for i in pairs(used) do
            used[i] = nil
        end
        for i = 1, #list do
            if i ~= was or #list == 1 then
                table.insert(free, i)
            end
        end
    end
    local i = self.rng:pick(free)
    used[i] = true
    used.last = i
    return list[i]
end

-- What the table calls a person: their card's name.
function M:cast_label(cast)
    return cast.name
end

-- A speech bubble from a player, picked from the table talk for this trigger.
-- extra.moment (a fight's moment, game/model/barks.lua): the line has to be true in it, and may
-- be one made from it.
function M:bark(p, trigger, extra)
    if not p then
        return
    end
    -- (While the table grieves, nobody whoops; a hero back up after a death is said quietly. Round
    -- three, A1: game/model/able.lua.)
    if able.hush(self, trigger) then
        return
    end
    if trigger == "up_again" and able.somber(self) == "death" then
        local lost = {}
        for _, pc in ipairs(self.pc_list or {}) do
            if pc.dead then
                table.insert(lost, pc.name)
            end
        end
        self:say(self:fresh(able.UP_QUIET, "up_quiet"), "narration", { char = p.char, lost = util.join_names(lost) })
        return
    end
    local v = self:vars(extra)
    local text, id
    if extra and extra.moment then
        text, id = barks.pick(self, trigger, p, extra.moment, v)
    else
        -- (A line has to fit the room it's said in: barks.context_fits.)
        local ctx = self:bark_context(extra and extra.ctx)
        local line
        text, line = self.talk:line(trigger, p, v, function(l)
            return barks.context_fits(l.text, ctx)
        end)
        id = line and line.id
    end
    if text then
        self:emit({ kind = "say", who = p.key, text = text, ic = talk_mod.in_character(trigger), line = id })
    end
    return text
end

-- Who's in front of them as a fight starts: the leader's size, how many, whether it's a person.
function M:boss_context(plan, sc)
    local ok, mons = pcall(require, "game.rules.data.monsters")
    local foes = (plan and plan.ids) or (sc and sc.encounter) or {}
    local id = foes[1]
    local m = ok and type(mons) == "table" and type(id) == "string" and mons[id] or nil
    local size = m and m.size
    local big = size == "large" or size == "huge" or size == "gargantuan"
    local person = m and (m.type == "humanoid" or id == "euryale" or m.person)
    return { big = big and true or false, foes = #foes, thing = not person }
end

-- What the room holds, for a line said outside a fight's turns (barks.context_fits): someone to talk
-- to, a fight, danger, something learned tonight. more: facts the caller knows (a boss's size).
function M:bark_context(more)
    local sc = self.scene
    local ctx = {}
    if sc then
        local cast = sc.comps and sc.comps.cast
        ctx.someone = (cast ~= nil and not cast.foe and not self:muted(cast)) or (cast ~= nil and cast.villain == true) or nil
        if self.mus then
            local mus = util.lazy("game.model.museum_night")
            local r = util.lazy("game.model.adventure").data.rooms[sc.room or ""]
            ctx.fight = (r and r.encounter ~= nil) or mus.has_fight(sc) or nil
            ctx.calm = not util.lazy("game.model.table_life").danger_ahead(self, sc) or sc.fought == true or nil
        else
            ctx.fight = sc.type == "combat" or sc.type == "set_piece" or nil
            ctx.calm = not ctx.fight or nil
        end
    end
    ctx.clue = self.heard_lore or nil
    -- (The clock: a night run past the time agreed at Session Zero, and past midnight. Round three, A8.)
    ctx.late = (self.table_min or 0) > (self.table_planned or 210) + 15 or nil
    ctx.midnight = ((self.table_start or 19 * 60) + (self.table_min or 0)) >= 23 * 60 + 30 or nil
    ctx.died = able.somber(self) == "death" or nil
    for k, val in pairs(more or {}) do
        ctx[k] = val
    end
    return ctx
end

-- The DM voicing the scene's cast.
function M:npc_line(what, extra)
    local sc = self.scene
    local cast = sc and sc.comps.cast
    if not cast then
        return
    end
    local text, line
    -- (v2: someone greets the party once a scene, and someone who's met them before greets them as
    -- people they know, never with their first-meeting line: the playtest, Nov 2, had Flitwidget
    -- say hello three ways in the thanks scene, the last as if they'd never met.)
    local again = false
    if what == "greet" then
        sc.greeted = sc.greeted or {}
        if sc.greeted[cast.id] then
            return nil
        end
        sc.greeted[cast.id] = true
        local adv = util.lazy("game.model.adventure")
        again = adv.met(self.campaign, cast.id) and (adv.meet(self.campaign, cast.id).week or 0) < (self.campaign.week or 0)
        -- (Someone who remembers what the party did says so first: R11, people.lua.)
        local own = again and util.lazy("game.model.people").line(self, cast.id, "again")
        if own then
            self:emit({ kind = "npc", name = self:cast_label(cast), cast = cast.id, text = own })
            return own
        end
        if again then
            text, line = self.talk:npc(cast.id .. "@again", what, self:vars(extra))
        end
    end
    if not text and not again then
        text, line = self.talk:npc(cast.id, what, self:vars(extra))
    end
    if text then
        self:emit({ kind = "npc", name = self:cast_label(cast), cast = cast.id, text = text, line = line.id })
    end
    return text
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

-- The spotlight you handed someone (a "Turn to them" call): the next roll or card is theirs, until
-- it's used or the scene after next. kind is "rolls" or "cards".
function M:take_owed(kind)
    local o = self.owed
    if not o then
        return nil
    end
    if self.scene and o.scene and self.scene.index > o.scene + 1 then
        self.owed = nil
        return nil
    end
    if (o[kind] or 0) <= 0 then
        return nil
    end
    local p = find_present(self.players, o.key)
    if not p then
        self.owed = nil
        return nil
    end
    o[kind] = o[kind] - 1
    if (o.rolls or 0) <= 0 and (o.cards or 0) <= 0 then
        self.owed = nil
    end
    return p
end

-- Who rolls a big moment (A4): the best modifier among players at or below the table's average
-- Spotlight, never a negative modifier while someone good at it is here, and nobody past 40% of
-- tonight's big rolls.
function M:pick_roller(skill_list, sc, prefer)
    local players = self:at_hand()
    -- (A roll you promised someone waits while their hero's off elsewhere: F11.)
    local owed_here = not self.owed or util.contains(players, find_present(self.players, self.owed.key) or false)
    local owed = owed_here and self:take_owed("rolls") or nil
    if owed then
        return owed
    end
    self.big_rolls = self.big_rolls or {}
    local total = 0
    for _, n in pairs(self.big_rolls) do
        total = total + n
    end
    local function capped(p)
        return total >= 3 and (self.big_rolls[p.key] or 0) / total >= 0.4
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

-- The friends whose heroes are in this scene: a hero who split off (split_party) is elsewhere until
-- it's over, and doesn't act in it (F11, the second playtest review: "Brannoc heads off the other
-- way", then Dev: "Get behind me! I'll hold the line!"). Everyone, when nobody's away.
-- And only the ones who can act (round three, A1, game/model/able.lua): a hero who's dead, down or
-- stone (or out of it in a fight) is in nobody's pick; their player still talks, as themselves.
-- Empty when nobody can.
function M:at_hand(fight_move)
    local split = self.scene and self.scene.split
    local here = self.players
    if split and split.away then
        here = {}
        for _, p in ipairs(self.players) do
            if not split.away[p.key] then
                table.insert(here, p)
            end
        end
        if #here == 0 then
            here = self.players
        end
    end
    return able.only(self, here, fight_move)
end

-- Pick a present player, preferring these archetypes (primary first).
function M:pick_actor(prefs, exclude)
    local players = self:at_hand()
    for _, pass in ipairs({ "primary", "secondary" }) do
        for _, a in ipairs(prefs or {}) do
            local found = {}
            for _, p in ipairs(players) do
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
    for _, p in ipairs(players) do
        if p ~= exclude then
            table.insert(others, p)
        end
    end
    if #others == 0 then
        return players[1]
    end
    return self.rng:pick(others)
end

-- Who steps up for a card: whoever the card suits, weighed against who's had the spotlight, who
-- led the last one, whose hero is down, and who's checked out. The playtest, Nov 2: the first
-- friend on the card's list took it every run (the plaque was always Mara's).
function M:pick_lead(prefs, exclude)
    local pool = {}
    for _, p in ipairs(self:at_hand()) do
        if p ~= exclude then
            table.insert(pool, p)
        end
    end
    if #pool == 0 then
        return self.players[1]
    end
    local avg = 0
    for _, p in ipairs(pool) do
        avg = avg + (p.m.spotlight or 0)
    end
    avg = avg / #pool
    self.leads = self.leads or {}
    local weights = {}
    for i, p in ipairs(pool) do
        local w = (prefs and #prefs > 0) and 0.3 or 1
        for k, a in ipairs(prefs or {}) do
            if p.primary == a then
                w = math.max(w, 3 - 0.6 * (k - 1))
            elseif p.secondary == a then
                w = math.max(w, 1.5 - 0.3 * (k - 1))
            end
        end
        -- (Behind on the spotlight, they lean in; led the last one, they sit this out.)
        w = w * (1 + math.max(0, avg - (p.m.spotlight or 0)) / 15)
        w = w / (1 + 0.35 * (self.leads[p.key] or 0))
        if self.last_lead == p.key then
            w = w * 0.4
        end
        local pc = self:pc_of(p)
        if pc and (pc.hp or 1) <= 0 then
            w = w * 0.15
        end
        if (p.boredom or 0) >= 30 then
            w = w * 0.7
        end
        weights[i] = w * (0.7 + 0.6 * self.rng:next())
    end
    return self.rng:weighted(pool, weights)
end

-- Note who took a card, for pick_lead.
function M:note_lead(p)
    if p then
        self.leads = self.leads or {}
        self.leads[p.key] = (self.leads[p.key] or 0) + 1
        self.last_lead = p.key
    end
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

-- Where everyone's at: a pose for each player's mini-me at the table, and their face on their tile.
-- lean (into it, smiling), neutral, frown (not enjoying it), arms (crossed), yawn, phone. Fun sets
-- the face (the playtest, November 3: "match their smile/mood"); engagement the rest.
function M:poses()
    local out = {}
    for _, p in ipairs(self.players) do
        local e = p.engagement
        local fun = score.fun(p)
        local pose = "neutral"
        if e >= 0.68 or (fun >= 72 and e >= 0.5) then
            pose = "lean"
        elseif e < 0.2 then
            pose = "phone"
        elseif e < 0.3 then
            pose = "yawn"
        elseif e < 0.42 and fun < 45 then
            pose = "arms"
        elseif fun < 38 then
            pose = "frown"
        end
        out[p.key] = pose
    end
    return out
end

-- Below LOW_TELL a player is visibly drifting (doodling, on their phone); a bad mood's tell shows
-- below MOOD_TELL.
M.LOW_TELL = 0.32
M.MOOD_TELL = 0.42

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
        -- Their mood shows when it agrees with how they're doing (playtest, October 13: a
        -- Distracted player was "eyeing their phone" half the night while having a great time).
        local mood = score.mood(p)
        if mood.tell then
            if (mood.fun or 0) < 0 and p.engagement < M.MOOD_TELL then
                text = mood.tell
            elseif (mood.fun or 0) >= 0 and p.engagement >= 0.5 then
                text = mood.tell
            end
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

-- Does this card make sense where the scene is? (One whose setting doesn't fit simply doesn't happen.)
function M:fits_here(c)
    local sc = self.scene
    return not c or c.kind == "location" or content.fits_setting(c, sc and sc.comps.location)
end

-- Describe a card on the scene, in its own words: someone the party has met before as someone they
-- know, a card's words for how things stand (line_if), a place they were at earlier tonight as such.
function M:describe(c, style)
    local sc = self.scene
    if not c or self:muted(c) or not self:fits_here(c) then
        return
    end
    local adv = util.lazy("game.model.adventure")
    local text
    -- Back somewhere they were earlier tonight (a place on two scenes, A6). Straight after a
    -- scene there, they never left: the place isn't described again.
    self.described = self.described or {}
    if c.kind == "location" and self.described[c.id] then
        if self.last_location == c.id then
            return
        end
        text = "Back at " .. soft_lower(c.name) .. "."
    end
    if not text then
        -- (The museum's people, met before, are described as people the party knows.)
        if c.again and c.kind == "cast" and adv.met(self.campaign, c.id) then
            text = c.again
        else
            text = content.line_for(c, sc and sc.comps.location)
        end
        -- (A card's words for how things stand, line_if: a table that veiled what's in it.)
        if c.line_if then
            util.lazy("game.model.museum_night").soft_check(self, c.line_if)
            for _, alt in ipairs(c.line_if) do
                if adv.test(self.campaign, alt.when) then
                    text = alt.text
                    break
                end
            end
        end
    end
    self.described[c.id] = true
    if c.kind == "location" then
        self.last_location = c.id
    end
    self:say(text, style or "narration")
    if c.kind == "cast" then
        self.met = self.met or {}
        self.met[c.id] = self.met[c.id] or true
        adv.meet(self.campaign, c.id, sc and sc.room)
    end
end

-- The terrain set on the table: the place's map if the DM drew one (B9), else the place's own set,
-- else one borrowed by what the place is, else by the scene (game/model/maps.lua).
function M:terrain_for(sc)
    if sc.board_override then
        return sc.board_override        -- (v2: a map the DM picked from the map repository)
    end
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

-- The places on this scene's board (map_library `places`: the lettered spots and what's there),
-- by id. A DM's own map keeps its template's places, less any whose feature they took off it.
function M:board_places(sc)
    if not sc then
        return {}, {}
    end
    local id = self:board_for(sc) or ""
    local base = string.match(id, "^map:([^:]+):") or id
    local def = require("game.data.boards")[base]
    local list = def and def.places or {}
    local ok, c = pcall(board_mod.compile, id)
    local base_feats = {}
    for _, f in ipairs(def and def.features or {}) do
        base_feats[f.id] = true
    end
    local out, by_id = {}, {}
    for _, pl in ipairs(list) do
        local gone = false
        local first = pl.near and pl.near[1]
        if first and base_feats[first] and ok and c and not c.by_id[first] then
            gone = true
        end
        if not gone then
            table.insert(out, pl)
            by_id[pl.id] = pl
        end
    end
    return out, by_id
end

-- A hero walks over to something on the mat (the playtest, November 3: "minis should move
-- more"). `to` is a place id on this scene's board, or a square { x, y }; `path` adds the squares
-- after it (dragged into the pond and back out). Returns the square, or nil when there's nowhere.
function M:walk(p, to, path, sc)
    if not p then
        return nil
    end
    sc = sc or self.scene
    local sq = to
    if type(to) == "string" then
        local _, by_id = self:board_places(sc)
        local pl = by_id[to]
        sq = pl and { pl.x, pl.y } or nil
    end
    if not sq then
        return nil
    end
    -- Round the walls and through the doors, not through them (game/model/sight.lua): the squares
    -- of the way there, a door opening as they reach it.
    local pts
    local sight = require "game.model.sight"
    local st = sight.stage(self, sc)
    local from = self.mini_pos and self.mini_pos[p.key]
    if st and from then
        local route = sight.path(st, from, sq)
        if route and #route > 0 and #route <= 40 then
            self:open_doors(st, route)
            pts = route
        end
    end
    pts = pts or { { sq[1], sq[2] } }
    for _, s in ipairs(path or {}) do
        table.insert(pts, { s[1], s[2] })
    end
    self:emit({ kind = "walk", actor = p.key, path = pts })
    return sq
end

-- Is the scene's person in plain view of the party where they stand? (Then they're on the mat
-- from the start, not waiting to be named: the playtest, November 3.)
function M:npc_in_view(sc, party, npc)
    if not npc then
        return false
    end
    local sight = require "game.model.sight"
    local st = sight.stage(self, sc)
    if not st then
        return false
    end
    local froms = {}
    for _, q in ipairs(party or {}) do
        table.insert(froms, { q.x, q.y })
    end
    return sight.seen(st, froms, { npc.x, npc.y })
end

-- The doors a walk goes through open, and stay open tonight (the board swaps the piece).
function M:open_doors(st, route)
    local sight = require "game.model.sight"
    for _, d in ipairs(sight.doors_on(st, route)) do
        self.doors_open = self.doors_open or {}
        self.doors_open[st.id] = self.doors_open[st.id] or {}
        self.doors_open[st.id][d.x .. "," .. d.y] = true
        self:emit({ kind = "door", x = d.x, y = d.y, fid = d.fid, state = "open" })
    end
end

-- Before the person in the scene comes on the mat: if no hero can see where they are (a wall, a
-- shut door), the party walks in until someone can (the playtest, November 3: "check sightlines;
-- they need to move through doors to see the room and the NPCs inside it").
function M:come_into_view(sc)
    local at = sc and sc.npc_at
    if not (at and self.mini_pos) then
        return
    end
    local sight = require "game.model.sight"
    local st = sight.stage(self, sc)
    if not st then
        return
    end
    local froms = {}
    for _, p in ipairs(self.players) do
        if self.mini_pos[p.key] then
            table.insert(froms, self.mini_pos[p.key])
        end
    end
    if #froms == 0 or sight.seen(st, froms, at) then
        return
    end
    local taken = { [at[1] .. "," .. at[2]] = true }
    for _, p in ipairs(self.players) do
        local from = self.mini_pos[p.key]
        if from then
            local route = sight.path(st, from, nil, function(x, y)
                return sight.walkable(st, x, y) and not taken[x .. "," .. y] and sight.los(st, { x, y }, at)
            end)
            if route and #route > 0 and #route <= 40 then
                local last = route[#route]
                taken[last[1] .. "," .. last[2]] = true
                self:open_doors(st, route)
                self:emit({ kind = "walk", actor = p.key, path = route })
            end
        end
    end
end

-- The place's map, if there is one (B9).
function M:map_for(sc)
    if sc and sc.custom_map then
        return sc.custom_map            -- (v2: one of the DM's own maps)
    end
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
    -- (A fight's one figure who's there from the start, the Lecturer at his lectern, Euryale on her
    -- couch, is on the mat before the fight: cast.visible. The playtest, November 3.)
    if cast and (not (sc.type == "combat" or sc.type == "set_piece") or cast.visible) then
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

-- Quick checks: fast rolls that stream into the dice strip, moving the scene's
-- progress track toward its big moment ----------------------------------------------------------

-- A hero in character, talking to another (the scene's little back-and-forths).
function M:banter()
    -- A long stretch without a call: the table keeps it moving (the nights gate).
    if self:idle() > 80 then
        return
    end
    -- (Between heroes in this scene: one who wandered off isn't here to bicker with. F11.)
    local l, p = self.talk:banter(self:at_hand())
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

-- How the heroes play the scene's goal card (the card-led night, October 16; the adventure's own in
-- game/data/museum/cards.lua): its entry (or the default), and the fill-ins it uses.
function M:goal_play(sc)
    local goal = sc and sc.comps.goal
    if not goal or self:muted(goal) then
        return nil
    end
    local gp = content.goal_play
    local name = soft_lower(goal.name)
    return gp[goal.id] or gp.default, { goal = name, Goal = util.capitalize(name) }
end

-- Could the heroes try this here? Nobody talks a wolf into anything, or threatens, robs or lies to a
-- mentor's ghost (A3); a line aimed at someone needs someone there.
function M:action_suits(sc, a)
    local loc = sc.comps.location
    local c = sc.comps.cast
    local cast = c and not self:muted(c)
    if a.cast and c and c.talks == false then
        return false
    end
    if c and c.revered and (a.skill == "intimidation" or a.skill == "sleight_of_hand" or a.skill == "deception") then
        return false
    end
    if a.suspect and sc.talked_warm then
        return false
    end
    return content.fits_setting(a, loc) and (not a.cast or cast) and (not a.other or #self.players > 1)
end

-- A player says what they're there to do, in character, as the scene starts (the card-led night):
-- whoever leads.
function M:say_intent(sc)
    if not sc or sc.intent_said or self.end_early then
        return
    end
    local gp, gvars = self:goal_play(sc)
    if not gp or not gp.intent then
        return
    end
    local goal = sc.comps.goal
    -- Someone who likes a plan: not the same voice every scene (the card-led playtest, October 16:
    -- Mara said all three).
    local p = self:pick_lead({ "storyteller", "tactician", "method_actor" }, self.intent_by)
    if not p then
        return
    end
    -- (Not a line about a hero who fell: "Brannoc wants a name", with Brannoc gone.)
    local lines = self:without_fallen(gp.intent)
    if #lines == 0 then
        return
    end
    self.intent_by = p
    sc.intent_said = true
    local line = self:fresh(lines, "intent_" .. goal.id)
    self:emit({ kind = "say", who = p.key, ic = true, intent = true,
                text = util.capitalize(util.fill(line, self:vars(gvars))) })
end

-- Lines that don't name a hero who has fallen.
function M:without_fallen(list)
    local fallen = self.campaign and self.campaign.fallen or {}
    if #fallen == 0 then
        return list
    end
    local out = {}
    for _, l in ipairs(list or {}) do
        local ok = true
        for _, f in ipairs(fallen) do
            if f.char and string.find(l, "%f[%a]" .. f.char .. "%f[%A]") then
                ok = false
            end
        end
        if ok then
            table.insert(out, l)
        end
    end
    return out
end

-- The table talks about what's in front of them (the card-led night): a player, out of character,
-- about the scene's goal.
function M:card_talk(sc)
    if self:idle() > 80 then
        return false
    end
    local gp, gvars = self:goal_play(sc)
    if not gp or not gp.talk then
        return false
    end
    local goal = sc.comps.goal
    local pool = {}
    for _, p in ipairs(self.players) do
        if p ~= self.actor then
            table.insert(pool, p)
        end
    end
    if #pool == 0 then
        return false
    end
    local lines = self:without_fallen(gp.talk)
    if #lines == 0 then
        return false
    end
    local p = self.rng:pick(pool)
    local line = self:fresh(lines, "talk_" .. goal.id)
    self:emit({ kind = "say", who = p.key, ic = false, card_talk = true,
                text = util.capitalize(util.fill(line, self:vars(gvars))) })
    return true
end

-- The squares beside someone the heroes talk to, one per seat.
local NPC_SIDE = { { -1, 0 }, { -1, 1 }, { -1, -1 }, { 0, 1 }, { 0, -1 } }

local function layout_blocked(night, sc)
    local ok, layout = pcall(board_mod.layout, night:board_for(sc))
    return ok and layout and layout.blocked or {}
end

-- Another go at one of the goal's moves that missed.
local RETRY = { "Let me try that. Fresh eyes.", "My turn. I'll do it differently.", "Again. Slower this time.",
                "Move over. Let me have a go.", "Once more, properly this time." }
local RETRY_LOSE = { "Second try, same answer. Not this way.", "{char} gives it everything. It still won't come.",
                     "No better the second time. Time to think of something else.",
                     "{char} gets further than the first try, and no further than that." }

-- One hero's go: they say what they try, the DM calls the check, they roll, the DM says how it lands.
function M:hero_action(sc, dc, spots)
    local st = content.scenes[sc.type]
    -- Players who shine here act more; quiet players get a turn too.
    local weights = {}
    local here = self:at_hand()
    for j, p in ipairs(here) do
        local shine = st.shine[p.class] or 0
        weights[j] = 1 + 2 * shine + math.max(0, (40 - p.m.spotlight) / 20)
    end
    local p = self.rng:weighted(here, weights)
    self.actor = p
    self.other = self:pick_actor(nil, p)
    -- What they'd try: what the goal asks of them first (the card-led night: every scene played
    -- the scene type's stock moves, whatever the card said), then whatever they're good at.
    local gp, gvars = self:goal_play(sc)
    local options
    local retry
    if gp and gp.approaches then
        sc.goal_used = sc.goal_used or {}
        sc.goal_missed = sc.goal_missed or {}
        local gopts = {}
        -- (An approach can wait on what's happened, `when`: nobody asks about the news before
        -- it's been told.)
        local adv = util.lazy("game.model.adventure")
        for i, a in ipairs(gp.approaches) do
            if not sc.goal_used[i] and self:action_suits(sc, a) and (not a.when or adv.test(self.campaign, a.when))
                and #self:without_fallen({ a.say .. " " .. a.win .. " " .. a.lose }) > 0 then
                table.insert(gopts, { i = i, a = a, goal = true })
            end
        end
        -- Every approach tried: one that missed gets another go, by someone else, before anyone
        -- wanders off to look at ferns (the card-led playtest, October 16: the tangents came once
        -- the goal's moves ran out).
        if #gopts == 0 then
            for i, a in ipairs(gp.approaches) do
                local by = sc.goal_missed[i]
                if by and by ~= p.key and self:action_suits(sc, a) then
                    table.insert(gopts, { i = i, a = a, goal = true, retry = true })
                end
            end
        end
        if #gopts > 0 then
            options = gopts
        end
    end
    if not options then
        return nil      -- a room's checks are its goal's own approaches, nothing generic
    end
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
    if pick.retry then
        sc.goal_missed[pick.i] = nil
        retry = true
    else
        sc.goal_used[pick.i] = true
    end
    local vx = { char = p.char, other_char = self.other and self.other.char or "" }
    for k, v in pairs(gvars or {}) do
        vx[k] = v
    end
    local vars = self:vars(vx)
    -- The player says it, in character: what they're trying is the roll's whole point (the card-led
    -- playtest, October 16: "I never saw what Pip was trying"). Another go at a move that missed is
    -- said as one.
    local said = a.say
    if retry then
        said = self:fresh(RETRY, "retry")
    end
    self:emit({ kind = "say", who = p.key, text = util.capitalize(util.fill(said, vars)), ic = true })
    local mod = self:mod_for(p, a.skill)
    -- An item's Advantage (Boots of Elvenkind, Eyes of the Eagle, A13): a second die, the better counts.
    local iedge, item_edge = require("game.model.items").check_edge(self.campaign, p.key, a.skill, a.topic)
    local edge = iedge and "adv" or nil
    local roll = self.rng:d20()
    local other_roll
    if edge then
        other_roll = self.rng:d20()
        if other_roll > roll then
            roll, other_roll = other_roll, roll
        end
    end
    -- Last time was a near miss (B2): they know the trick of it now.
    local near_bonus = self.edge_next and self.edge_next[p.key]
    if near_bonus then
        mod = mod + near_bonus
        self.edge_next[p.key] = nil
    end
    mod = mod + self:take_research(p)
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
    if edge then
        text = text .. " (advantage: " .. item_edge .. "; the other die was " .. util.int(other_roll) .. ")"
    end
    table.insert(self.checks, success)
    -- Stared down before a fight: whoever they faced goes for them first, for a few rounds (the
    -- playtest, November 3: "successful intimidates should taunt the target"). fight.lua applies it.
    if success and a.skill == "intimidation" then
        sc.taunt = { key = p.key, rounds = 3 }
    end
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
        if not retry then
            sc.goal_missed[pick.i] = p.key      -- someone else can have another go at it
        end
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
    -- Each to their own square beside them (the card-led playtest, October 16: three minis on one
    -- square, and two of them looked gone).
    if sc.npc_at and SOCIAL_SKILL[a.skill] then
        spot = { sc.npc_at[1] - 1, sc.npc_at[2] }
        local blocked = {}
        for _, b in ipairs(layout_blocked(self, sc)) do
            blocked[b[1] .. "," .. b[2]] = true
        end
        local j = 1
        for k, q in ipairs(self.players) do
            if q == p then
                j = k
            end
        end
        local off = NPC_SIDE[(j - 1) % #NPC_SIDE + 1]
        local x, y = sc.npc_at[1] + off[1], sc.npc_at[2] + off[2]
        if x >= 1 and y >= 1 and x <= (board_mod.W or 12) and y <= (board_mod.H or 8) and not blocked[x .. "," .. y] then
            spot = { x, y }
        end
    end
    self:emit({ kind = "check", text = text, roll = roll, bonus = mod, total = total, dc = dc, success = success,
                actor = p.key, char = p.char, skill = a.skill, skill_name = name, crit = roll == 20,
                fumble = roll == 1, spot = spot, edge = edge, other_roll = other_roll,
                progress = self:progress_view(sc) })
    -- How it lands in the story, then at the table.
    -- (A second miss at the same move isn't the first miss again, word for word: the second playtest.)
    local landed = success and a.win or ((retry and self:fresh(RETRY_LOSE, "retry_lose")) or a.lose)
    -- (A miss that can't unknow what they know: lose_if, the first whose `when` holds.)
    if not success then
        for _, alt in ipairs(a.lose_if or {}) do
            if util.lazy("game.model.adventure").test(self.campaign, alt.when) then
                landed = alt.text
                break
            end
        end
    end
    self:say(util.capitalize(util.fill(landed, vars)), success and "good" or "bad")
    -- A natural 20 is a moment the token's made for, if you want to give it (offer_inspiration).
    if roll == 20 then
        self:offer_inspiration(p, p.char .. " rolled a natural 20.")
    end
    -- (What it changes in the adventure, as a moment's option would: a bigger reward, a flag.)
    local am = success and a.mus_win or (not success and a.mus_lose)
    if am then
        util.lazy("game.model.museum_night").handle(self, am, sc)
    end
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
    -- The dots are up from the scene's start, not its first roll (the second playtest, October 17).
    self:progress_event(sc)
    local i = 0
    while i < max_checks and sc.progress.wins < need and sc.progress.setbacks < beats.setbacks do
        i = i + 1
        -- In a social scene with someone to talk to, the cast speaks up first now and then.
        if i == 1 and sc.comps.cast and not self:muted(sc.comps.cast) and not sc.talked
            and (sc.type == "social" or sc.type == "mystery" or sc.type == "downtime") then
            self:npc_line("greet")
            self:table_behavior("social")
        end
        if self:hero_action(sc, dc, spots) == nil then
            break
        end
        if i == 3 then
            self:table_behavior("long_scene")
        end
        if i == 1 and comp and not comp.cliffhanger and not self:muted(comp) and self:fits_here(comp) then
            self:say(content.line_for(comp, sc.comps.location), "twist")
        elseif i == 2 then
            if not (self.rng:chance(0.6) and self:card_talk(sc)) then
                self:banter()
            end
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
    -- (Said the way the dots on the top bar show it, so it reads as the same thing: the newcomer
    -- playtest, October 16, read "the big moment" as the big roll they had just made.)
    -- (The open log keeps it; the header's dots and the final roll's card say it where it counts:
    -- the card-led playtest, October 16, read it twice at once.)
    if sc.edge < 0 then
        self:say("They've done the groundwork: the scene's final roll will be easier (DC -2).", "record")
    elseif sc.edge > 0 then
        self:say("Too many setbacks: the scene's final roll will be harder (DC +2).", "record")
    end
end

-- Little things that happen around the table between beats: snacks, phones, yawns.
function M:table_life()
    -- What someone's thinking and not saying (v2): a want that's been nagging at them.
    if thoughts.brew(self, false) then
        return
    end
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
    if b.needs == "cast" then
        local cast = sc and sc.comps.cast
        if not cast or self:muted(cast) or cast.talks == false or cast.revered then
            return false
        end
    elseif b.needs == "cliff" then
        -- (A session the DM ended in a lull or after a fight isn't a cliffhanger: museum_night.end_session.)
        if self.dm_ended then
            return self.dm_ended == "cliff"
        end
        return self.ended_on_cliff or self.end_early or false
    elseif b.needs == "not_first" then
        return (self.campaign.week or 1) > 1      -- (no "last time" on the first night)
    end
    return true
end

-- Is this player's hero hurt (under 60% of their hit points) right now?
function M:hurt(p)
    local c = self.pcs and p and self.pcs[p.key]
    return c ~= nil and not c.dead and (c.hp or 0) < (c.hp_max or 1) * 0.6
end

-- A table habit's line that has a condition: late = a reason, true only for the friend the group chat
-- said would be late this week, for that reason (or any reason: "any").
function M.behavior_line_ok(night, line, p)
    if type(line) ~= "table" then
        return true
    end
    if line.late then
        local late = night.campaign.adv and night.campaign.adv.late
        local why = late and late.week == night.campaign.week and late[p.key]
        return why ~= nil and (line.late == "any" or line.late == why)
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
    -- (No fist bumps while the table grieves: round three, A1.)
    if able.somber(self) and when ~= "rules" and when ~= "start" then
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
        if b.when == when and not tb.used[b.id] and self:behavior_fits(b, sc, week) then
            local free = {}
            for i in ipairs(b.lines) do
                local last = camp.tb_said[b.id .. "#" .. i]
                if not last or week - last >= 3 then
                    table.insert(free, i)
                end
            end
            if #free > 0 then
                for _, p in ipairs(self.players) do
                    -- (A line with a condition only for the friend it's true of: late as the chat said.)
                    local pfree = {}
                    for _, i in ipairs(free) do
                        if M.behavior_line_ok(self, b.lines[i], p) then
                            table.insert(pfree, i)
                        end
                    end
                    local w = arch_weight(b.archetype, p)
                    if not class_ok(b, p) then
                        w = 0
                    elseif b.by == "roller" and p ~= roller then
                        w = 0
                    elseif b.by == "other" and (not roller or p == roller) then
                        w = 0
                    elseif b.mood == "engaged" and p.engagement < 0.4 then
                        w = 0
                    elseif b.hurt and not self:hurt(p) then
                        w = 0      -- "please heal me" from someone at full health (the newcomer playtest)
                    elseif b.mood == "bored" and p.engagement >= 0.45 then
                        w = 0
                    end
                    if w > 0 and #pfree > 0 then
                        table.insert(cands, { b = b, p = p, free = pfree })
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
    local raw = b.lines[i]
    local text = util.fill(type(raw) == "table" and raw[1] or raw, self:vars({ other_char = roller and roller.char or "" }))
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

-- Before a fight, a hero tries something flashy (A12): a quick check; a win gives the party the
-- first move. Which stunt depends on who's at the table and where they are.
function M:stunt(sc)
    local camp = self.campaign
    camp.stunts_said = camp.stunts_said or {}
    local week = camp.week or 1
    local cands, weights = {}, {}
    for _, st in ipairs(content.stunts) do
        local last = camp.stunts_said[st.id]
        if content.fits_setting(st, sc.comps.location) and (not last or week - last >= 3) then
            for _, p in ipairs(self:at_hand()) do
                local w = arch_weight(st.archetype, p)
                if w > 0 and class_ok(st, p) then
                    table.insert(cands, { st = st, p = p })
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
    camp.stunts_said[st.id] = week
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
    -- A stunt that says who the foe goes for makes it so: drawing its fire taunts it (fight.lua),
    -- for the first few rounds (F12: "goes for Brannoc", then it hit someone else).
    if success and st.taunt then
        sc.taunt = { key = p.key, rounds = 3 }
    elseif not success and st.taunt_other and self.other then
        sc.taunt = { key = self.other.key, rounds = 2 }
    end
    if success then
        -- (A stunt that spots an ambush cancels it; otherwise the foes are the ones caught out.)
        if sc.surprise == "party" then
            sc.surprise = nil
        else
            sc.surprise = "foes"
        end
        score.add(p, "spotlight", 6)
        score.add(p, "fun", 3)
        self:react({ [p.key] = "cheer" })
        if roll == 20 then
            self:highlight(7, p.char .. " pulls off a stunt nobody will forget", { p }, "stunt")
            self:offer_inspiration(p, p.char .. " just pulled off a stunt nobody will forget.")
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
function M:give_inspiration(p, by_tile)
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
    self:say(util.fill(self:fresh(M.INSPIRE_LINES, "inspire_line"), { name = p.name, char = p.char }), "dm")
    self:event("inspiration", { who = p.key, text = p.char .. " earned Heroic Inspiration." })
    if again then
        self:fairness_noticed(p, "inspiration")
    end
end

-- Heroic Inspiration is the DM's to give (the playtest, November 3: "the DM should be prompted to
-- give it or not, not given freely"). A great moment offers it as a call: the token, or not this
-- time. One offer a night, never to someone already holding one, and only while the night has
-- calls to spare. why: what they did, said on the card.
function M:offer_inspiration(p, why)
    if not p or p.heroic or self.inspiration_given or self.inspiration_offered or not self:room(13) then
        return false
    end
    self.inspiration_offered = true
    local prev_actor = self.actor
    self.actor = p
    local card = { id = "inspire_offer", type = "table", trigger = "museum_fixed", fixed_actor = true,
                   title = "Heroic Inspiration?",
                   text = (why and (why .. " ") or "") .. "Flick {actor_char} the Heroic Inspiration token? One reroll, whenever {actor_they} needs it. "
                       .. "You can also give it any time from their tile.",
                   options = {
                       { label = "Yes: flick {actor_char} the token.", inspire = true,
                         effects = { { "actor", fun = 2 } } },
                       { label = "Not this time.", log = "You keep the token behind your screen for now.",
                         effects = { { "arch:power_gamer", fun = -1 } } },
                   } }
    local o = self:decision(card)
    if o and o.inspire then
        self:give_inspiration(p)
    end
    self.actor = prev_actor or self.actor
    return o and o.inspire or false
end

-- The token from their tile (the playtest, November 3): the DM's own call, any time. The UI sets
-- it at once; the table's reaction plays at the next beat (the night is mid-step when you click).
function M:inspire_from_tile(p)
    if not p or p.heroic then
        return false
    end
    p.heroic = true
    self.ui_later = self.ui_later or {}
    table.insert(self.ui_later, function(night)
        night:give_inspiration(p, true)
    end)
    return true
end

-- The killing blow (M8, B4). Who's waited longest for one: the player with the fewest killing
-- blows in the window, not counting whoever landed this one.
function M:killing_blow_other(actor)
    local camp = self.campaign
    local count = {}
    for _, e in ipairs(camp.killing_blows or {}) do
        if camp.week - e.week < content.killing_blows.WINDOW then
            count[e.key] = (count[e.key] or 0) + 1
        end
    end
    local best
    -- (A friend whose hero is down or gone doesn't tell it: round three, A1.)
    for _, p in ipairs(self:at_hand()) do
        if p ~= actor and (not best or (count[p.key] or 0) < (count[best.key] or 0)
            or ((count[p.key] or 0) == (count[best.key] or 0) and p.m.spotlight < best.m.spotlight)) then
            best = p
        end
    end
    return best
end

-- What handing the killing blow to the table is worth now: 1 fresh, less for each one handed over
-- in the last few sessions, more for a big one. Returns worth, big, handed (count in the window).
function M:kb_worth(tgt)
    local camp = self.campaign
    local kb = content.killing_blows
    local n = 0
    for _, e in ipairs(camp.kb_handed or {}) do
        if camp.week - e.week < kb.WINDOW then
            n = n + 1
        end
    end
    local big = tgt and (tgt.villain or (self.scene and self.scene.boss and tgt.boss)) and true or false
    local worth = math.max(kb.FLOOR, (kb.FRESH or 0.7) ^ n) * (big and (kb.BIG or 1.8) or 1)
    return worth, big, n
end

-- The one who landed it may pass the telling to a friend who's waited (their idea, from who they
-- are: a storyteller or an easy-going player more, someone who came to hit things less); the DM
-- only says whether that works at the table. Returns who tells it.
-- lander_name: who landed it, when it's an ally the actor plays (Telpur's toe, not their hero's blow).
function M:kb_share(actor, other, tgt, boss_name, lander_name)
    if not (actor and other and other ~= actor) then
        return actor
    end
    local chance = 0.12 + 0.35 * score.arch(actor, "storyteller") + 0.3 * score.arch(actor, "casual")
        + 0.2 * score.arch(actor, "method_actor") - 0.3 * score.arch(actor, "butt_kicker") - 0.3 * score.arch(actor, "power_gamer")
    if (other.m.spotlight or 0) < (actor.m.spotlight or 0) - 10 then
        chance = chance + 0.15
    end
    if not self.rng:chance(util.clamp(chance, 0, 0.7)) then
        return actor
    end
    local card = content.triggered and content.triggered.kb_share
    if not card then
        return actor
    end
    local was_a, was_o = self.actor, self.other
    self.actor, self.other = actor, other
    local copy = {}
    for k, v in pairs(card) do
        copy[k] = v
    end
    copy.fixed_actor = true
    self.kb_lander = lander_name or actor.char
    local o = self:decision(copy, { boss = boss_name, actor_char = lander_name })
    self.kb_lander = nil
    self.actor, self.other = was_a, was_o
    if o and o.share then
        return other
    end
    return actor
end

-- p: who describes it. by: the player whose hero landed it (the dice log's), when that's someone
-- else: then p tells the moment, and the blow stays the one who landed it.
-- by: the friend whose blow it was; by_name: who landed it, when it wasn't their hero (an ally they play).
function M:killing_blow(p, tgt, boss_name, by, by_name)
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
    -- (A line about a spell they can't cast yet is left out: Shatter at level 2, the review found.)
    local lines = {}
    for _, l in ipairs(kb[p.class] or kb.fighter) do
        if (l.level or 0) <= (camp.level or 2) then
            table.insert(lines, l)
        end
    end
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
    -- Told for someone else's blow: the teller's words about it, never a swing of their own. (An ally's
    -- blow is told that way too, by whoever plays it: Telpur's toe, not Brannoc's sword.)
    local told = (by and by ~= p) or by_name ~= nil
    local hero = by_name or (by and by.char)
    if told then
        local tl = (kb.told and (kb.told[p.key] or kb.told.mara)) or {}
        local pick = tl[self.rng:int(1, math.max(1, #tl))]
        line = pick and util.fill(pick[1], self:vars({ boss = boss_name, char = p.char, hero = hero }))
            or (hero .. "'s blow lands, and " .. boss_name .. " falls.")
    end
    -- Handed over: worth less each time it's handed over lately, more on a big one (kb_worth).
    local worth = self:kb_worth(tgt)
    camp.kb_handed = camp.kb_handed or {}
    table.insert(camp.kb_handed, { week = camp.week, key = p.key })
    score.add(p, "spotlight", kb.SPOTLIGHT * math.max(0.5, worth))
    score.add(p, "fun", kb.FUN * worth)
    if told and by and by ~= p then
        score.add(by, "fun", 2)        -- (it was their idea to share it)
    end
    self:react({ [p.key] = "cheer" })
    self:emit({ kind = "say", who = p.key, text = line, ic = true })
    if told then
        -- (The blow is the lander's in the log; the telling is the teller's best moment too.)
        local text = hero .. " brings down " .. boss_name .. ", and " .. p.name .. " tells it"
        self:highlight(8, text, { by or p }, "killing_blow")
        if not p.best or 8 > p.best.score then
            p.best = { score = 8, text = text }
        end
    else
        self:highlight(8, p.char .. " lands the killing blow on " .. boss_name, { p }, "killing_blow")
    end
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
    if needs.after_break and not (self.had_break or self.snacked) then
        return false
    end
    if needs.question and not self.rules_question then
        return false              -- (nothing's come up yet worth reaching for the book over)
    end
    -- calm: nothing dangerous in the room (a fight still to come, a boss, the wrap-up), the party
    -- can afford to wander off (F11: the party split as the Knight climbed out of its frame, and in
    -- the thanks scene). every = n: at most once in n sessions.
    if needs.calm and sc and (sc.boss or sc.showdown or sc.epilogue
        or (sc.encounter and not sc.no_fight and not sc.resolved and not sc.result)
        or (sc.comps and M.cast_is(sc.comps.cast, "hostile"))) then
        return false
    end
    if needs.every and self.campaign.headache_week then
        local last = self.campaign.headache_week[needs.every_key or "?"]
        if last and (self.campaign.week or 0) - last < needs.every then
            return false
        end
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
            and (not d.needs or self:headache_ok(d.needs, sc))
            and (not self.gentle or (d.type == "rules" and not self.gentle_rules))   -- (night 1: one rules call, R6)
            and d.type ~= "story" and d.type ~= "screen" then   -- (the rooms bring their own)
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
    local d = self.rng:weighted(eligible, weights)
    if self.gentle and d and d.type == "rules" then
        self.gentle_rules = true
    end
    return d
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

-- What a DC means for this roller, in words a newcomer can weigh: the number they need on the
-- d20 and how often that comes up. (A natural 20 always makes it: tier_of.)
function M.odds_line(dc, mod)
    local need = dc - (mod or 0)
    if need <= 2 then
        return "They make it on almost any roll."
    elseif need >= 20 then
        return "Only a natural 20 makes it (1 in 20)."
    end
    local chance = (21 - need) / 20
    -- (40% isn't "a coin flip": the card-led playtest, October 16.)
    local word = (chance >= 0.85 and "very likely") or (chance >= 0.6 and "likely") or (chance >= 0.45 and "a coin flip")
        or (chance >= 0.3 and "less likely than not") or (chance >= 0.15 and "unlikely") or "a long shot"
    return "They need " .. util.int(need) .. " or more on the d20: about " .. util.int(math.floor(chance * 100 + 0.5))
        .. "%, " .. word .. "."
end

-- What the table agreed about your screen at Session Zero, said on the card where it matters
-- (the newcomer playtest, October 16: "did I promise something about this?").
function M:dice_promise()
    return M.dice_promise_for(self.campaign)
end

function M.dice_promise_for(campaign)
    local dice = campaign.table and campaign.table.rules.dice
    if dice == "open" then
        return "You agreed at Session Zero: everything in the open. A roll behind your screen will raise eyebrows."
    elseif dice == "big_open" then
        return "You agreed at Session Zero: big moments in the open, when a life is on the line. A roll like this is your call."
    elseif dice == "screen" then
        return "You agreed at Session Zero: behind the screen is fine. This table trusts you."
    end
    return nil
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
    -- A near miss you ruled "No, but...": they learned from it, +1 on this roll.
    local learned = p and self.learned and self.learned[p.key]
    if learned then
        mod = mod + learned
        self.learned[p.key] = nil
    end
    if p then
        mod = mod + self:take_research(p)
    end
    -- (v2: in a museum room the checks are pitched at the book's level: a smaller shift.)
    local dc = spec.dc + ((spec.true_dc and 0) or ((self.scene and self.scene.room) and 2) or M.DC_SHIFT)
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
    -- The odds, beside the DC (the newcomer playtest, October 16: "is 16 a lot?").
    text = text .. " " .. M.odds_line(dc, mod)
    if learned then
        text = text .. " (That includes +" .. util.int(learned) .. ": they learned from the last miss.)"
    end
    -- The scene's final roll says so, and what it's for (the card-led playtest, October 16:
    -- "nothing says this is the goal roll").
    if spec.final then
        text = "The scene's final roll" .. (spec.final.goal and (": " .. spec.final.goal) or "") .. ". " .. text
        local e = spec.final.edge or 0
        if e > 0 then
            text = text .. " The DC is " .. util.int(e) .. " higher: too many setbacks."
        elseif e < 0 then
            text = text .. " The DC is " .. util.int(-e) .. " lower: " .. (spec.final.why or "they did the groundwork") .. "."
        end
    end
    -- What you agreed at Session Zero, on the night's first big roll (on every one it was the same
    -- paragraph four times a night: the card-led playtest, October 16).
    local promise = not self.promise_told and self:dice_promise() or nil
    self.promise_told = self.promise_told or promise ~= nil
    -- Out of calls for the night (the 8-to-15 budget): say so, once, and don't ask how to roll a
    -- die nobody will rule on (the playtest, Nov 2: asked "open or hidden?", then no card came).
    local where
    if spec.secret then
        -- (The card already said "behind the screen": no asking where to roll it.)
        where = "hidden"
    elseif self.gentle and self.gentle_rolled then
        -- (The first night rules on one big roll: the rest land as the dice say, out in the open. R6.)
        if not self.gentle_said then
            self.gentle_said = true
            self:say("From here tonight, the big rolls land as the dice say, out in the open. From next week, how each one lands is your call too.",
                "system")
        end
        where = "open"
    elseif self:decision_count() >= 15 then
        if not self.calls_out_said then
            self.calls_out_said = true
            -- (Only the big rolls stop asking: other calls still come. The second playtest review.)
            self:say("That's your calls on the big rolls for tonight. From here those dice decide, out in the open, and you narrate what they say.",
                "system")
        end
        where = "open"
    else
        where = self:emit({ kind = "roll_where", dc = dc, text = text, actor = p and p.key, char = p and p.char,
                            skill = skill, skill_name = name, mod = mod, by = by, promise = promise,
                            final = spec.final })
    end
    -- Your own DC, said out loud (the playtest, November 3): "dc:16" from the card.
    local own_dc = type(where) == "string" and tonumber(string.match(where, "^dc:(%d+)$")) or nil
    if where ~= "hidden" then
        where = "open"
    end
    if own_dc and by == "player" then
        own_dc = util.clamp(own_dc, 2, 30)
        local diff = own_dc - dc
        self:say(util.fill("\"DC " .. util.int(own_dc) .. ".\" You set it yourself and say it out loud. {actor_char} knows what {actor_they} needs.",
            self:vars()), "dm")
        -- (Much easier than the book's: the ones here for a challenge feel it. Much harder: everyone does.)
        if diff <= -4 then
            self:apply({ { "arch:butt_kicker", challenge = -2 }, { "arch:power_gamer", challenge = -1 }, { "arch:casual", fun = 1 } })
        elseif diff >= 4 then
            self:apply({ { "all", challenge = 2 }, { "arch:casual", fun = -1 } })
        end
        dc = own_dc
    end
    -- (A harsh result from a die everyone saw is fair on its own: warnings.judge.)
    self.last_roll_where, self.last_roll_fresh = where, true
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
        local label = o.label
        if o.adventure_label and p then
            label = util.fill(o.adventure_label, { char = p.char })
        end
        opts[i] = { label = label, tone = o.tone }
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
    if (self:decision_count() >= 15 and not inspire_at) or (self.gentle and self.gentle_rolled) then
        -- Out of calls for the night (the 8-to-15 budget), or past the first night's one roll to rule
        -- on: the die decides, plainly, with no card.
        pick = 1
        inspire_at = nil
        self.auto_rulings = (self.auto_rulings or 0) + 1
    else
        self.gentle_rolled = self.gentle and true or nil
        pick = self:emit({ kind = "ruling", tier = tier, prompt = rule.prompt, value = value, total = total,
                           mod = mod, dc = dc, options = opts, where = where, by = by, success = success,
                           cook = cook_offer, cooks = self.cooks,
                           char = p and p.char, skill_name = name, actor = p and p.key, final = spec.final })
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
        -- A cooked result lands plainly on the side the DM chose. (And it's no triumph any more: the
        -- token's offer goes with it. The playtest, Nov 2: a DC moved to make a miss handed out
        -- Heroic Inspiration, because the plain miss sat where the token's option had been.)
        tier = success and "success" or "near"
        rule = content.rulings[tier]
        inspire_at = nil
        pick = 1
        for i, o in ipairs(rule.options) do
            if o.success == success and not o.tone then
                pick = i
            end
        end
    end
    local inspired = false
    if inspire_at and tonumber(pick) == inspire_at then
        self:give_inspiration(p)
        pick = 1
        inspired = true   -- the token is the extra
    end
    pick = util.clamp(math.floor(tonumber(pick) or 1), 1, #rule.options)
    local reported_total = reported + mod
    local line
    -- The sum, spelled out the way the roll box shows it (the playtest, November 3: "13 + 5 = 18").
    local function sum(die)
        return util.int(die) .. (mod < 0 and " - " or " + ") .. util.int(math.abs(mod)) .. " = " .. util.int(die + mod)
    end
    if by == "player" then
        line = (p and p.char or "They") .. " rolls " .. sum(value) .. ". " .. (where == "open" and ("You said DC " .. util.int(shown_dc) .. ".")
            or ("Behind the screen, the DC was " .. util.int(shown_dc) .. "."))
    else
        line = (where == "open" and "Everyone watches the die: " or "Behind the screen, the die says ")
            .. sum(reported) .. ", against DC " .. util.int(dc) .. "."
    end
    -- The card the DM just ruled on showed these numbers, and so does the die: said again as a
    -- caption it was the third telling of one roll (the card-led playtest, October 16). Cooked,
    -- it's news: what the table hears isn't what the die said.
    self:say(line, cooked and "dice" or "record")
    if cooked then
        self.rolls.cooked = self.rolls.cooked + 1
        self.cooks = self.cooks + 1
        self:event("cooked", { who = p and p.key or "party", text = "You cooked " .. ((p and by == "player") and (p.char .. "'s ") or "a ")
            .. name .. " roll behind the screen." })
        local convenient = (success and spec.convenient == "success") or (not success and spec.convenient == "fail")
        self:add_cook_suspicion(convenient, skill and (skills.name(skill) .. " roll") or "roll", by == "player" and value or nil)
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
    table.insert(self.rulings, { tier = tier, option = pick, cooked = cooked })
    if ro.success ~= nil and ro.success ~= success then
        -- "Yes, at a cost" on a near miss: the success branch plays.
        success = ro.success
    end
    local branch = success and spec.success or spec.fail
    -- A triumph never reads as a near thing (playtest, October 13: a natural 20 came out
    -- "Handled. Barely").
    local branch_log = (success and tier == "triumph" and branch.big) or branch.log
        or (branch.fresh and self:fresh(branch.fresh[1], branch.fresh[2]))
    self:say(branch_log, success and "good" or "bad")
    self:apply(branch.effects)
    self:apply(ro.effects)
    -- What the DM's call added: the extra, the cost or the new problem, by name.
    local ruled = ro.lines and self.rng:pick(ro.lines) or ro.log
    if ro.tone == "good" and self.campaign.adv and not inspired and success then
        -- The extra that falls their way on a great roll is a Flitwidget Franc (the book's own reward).
        -- Not on a miss: a Franc is for a beaten exhibit, a solved puzzle or a clever trick, as
        -- Flitwidget says (the playtest review, November 4: one on nearly every miss).
        self.campaign.adv.francs = (self.campaign.adv.francs or 0) + 1
        if self.mus then
            self.mus.francs_earned = (self.mus.francs_earned or 0) + 1      -- (the report counts it)
        end
        ruled = util.fill(self:fresh(M.FRANC_LINES, "franc_line"), { char = p and p.char or "someone" })
    end
    if ro.tone == "good" and not success then
        -- Failing forward: still a miss, so no cheering (the second playtest review: "Yes! Pip loves
        -- you!" right after a failed roll). What they learned is real: +1 on that hero's next roll.
        if ruled then
            self:say(ruled, "good")
        end
        if p then
            self.learned = self.learned or {}
            self.learned[p.key] = 1
        end
        self:bark(self.actor, "ruling_rueful")
    elseif ro.tone == "good" then
        if ruled and not inspired then
            self:say(ruled, "good")
        end
        self:react({ [self.actor and self.actor.key or self.players[1].key] = "cheer" })
        self:bark(self.actor, "ruling_good")
    elseif ro.tone == "bad" then
        if ruled then
            self:say(ruled, "bad")
        end
        if self.mus then
            util.lazy("game.model.museum_night").harsh(self, self.scene)
        end
        local poses = {}
        for _, q in ipairs(self.players) do
            poses[q.key] = "gasp"
        end
        self:react(poses)
        self:bark(self:pick_actor({ "butt_kicker", "instigator" }), "ruling_bad")
    elseif ro.tone == "twist" then
        self:say(ruled, "twist")
        -- (A cost is a cost: the hero who paid it takes the damage the line describes.)
        if self.mus and p then
            local was = self.actor
            self.actor = p
            util.lazy("game.model.museum_night").handle(self, { hurt = { 1, 4 } }, self.scene)
            self.actor = was
        end
    end
    if success and self.actor and not spec.quiet then
        self:highlight(6, M.moment_of(util.fill(branch_log, self:vars())), { self.actor })
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

-- die: the number on a die the whole table saw (a player's own roll), for what the sharpest eye
-- thinks; nil when the die was behind the screen.
function M:add_cook_suspicion(convenient, what, die)
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
    elseif sharp then
        thoughts.doubt(self, sharp, die and { die = util.int(die) } or nil)      -- they don't say it; they think it
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
    -- How everyone felt going in, for what they think of the call afterwards (game/model/thoughts.lua).
    local fun_before = {}
    for _, p in ipairs(self.players) do
        fun_before[p.key] = score.fun(p)
    end
    if card.actor_class and self:by_class(card.actor_class) then
        self.actor = self:by_class(card.actor_class)
        self.other = card.other and self:pick_actor(card.other, self.actor) or nil
    elseif not self.actor or not card.trigger then
        self.actor = self:pick_lead(card.actor)
        self.other = card.other and self:pick_lead(card.other, self.actor) or nil
    end
    -- The spotlight you handed someone: the next card that could be anyone's is theirs.
    local owed_card = false
    -- (A museum moment counts: the adventure's own calls are where the spotlight is in v2.)
    if not card.actor_class and (not card.trigger or card.trigger == "museum") and card.type ~= "table"
        and card.type ~= "boss" and card.type ~= "talk" then
        local owed = self:take_owed("cards")
        if owed then
            self.actor = owed
            if self.other == owed then
                self.other = card.other and self:pick_actor(card.other, owed) or nil
            end
            owed_card = true
        end
    end
    -- You promised a friend the next one would go to someone else (a thought you answered).
    if self.spare and self.actor and self.actor.key == self.spare and not card.actor_class and not owed_card
        and card.trigger ~= "museum_fixed" and not card.fixed_actor then
        local other = self:pick_actor(card.actor, self.actor)
        if other and other ~= self.actor then
            if self.other == other then
                self.other = self.actor
            end
            self.actor = other
        end
        self.spare = nil
    end
    -- Nobody hogs the big rolls just because the card suits their style (A4).
    if not card.actor_class and self.scene and not owed_card and not card.fixed_actor then
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
    end
    if card.options and #card.options > 1 then
        self:note_lead(self.actor)
    end
    -- A card about something on the map: whoever it's about walks over to it first.
    if card.spot and self.actor and not card.walked then
        self:walk(self.actor, card.spot)
    end
    local vars = self:vars(extra)
    local view = {
        id = card.id,
        type = card.type,
        cast = card.cast, monster = card.monster,      -- who's speaking or acting (B8): their mini on the card
        turn_of = card.turn_of,                         -- whose turn it is in the fight, when it's someone's
        danger = extra and extra.danger,                -- how bad a fight call could get (fight.danger_line)
        type_name = content.decision_types[card.type],
        title = util.sentence_case(util.fill(card.title, vars)),
        text = util.sentence_case(util.fill(card.text, vars)),
        options = {},
    }
    -- A rules call says what you agreed at Session Zero, and which answer keeps to it (the
    -- newcomer playtest, October 16).
    local rul = card.type == "rules" and self.campaign.table and self.campaign.table.rules.rulings
    local rul_def = rul and content.session_zero.rules.rulings[rul]
    if rul_def then
        view.promise = "You agreed at Session Zero: " .. string.lower(string.sub(rul_def.name, 1, 1)) .. string.sub(rul_def.name, 2) .. "."
            .. (rul == "quick" and " A quick call now means looking it up before next session." or "")
    end
    -- The killing blow says what handing it over is worth now (kb_worth): fresh, worn thin, or big.
    local kb_note
    if card.id == "killing_blow" and extra and extra.kb_target then
        local worth, big, n = self:kb_worth(extra.kb_target)
        if big then
            kb_note = n == 0 and "A big one: they'll remember this for weeks." or "A big one: it'll land even after the others."
        elseif n == 0 then
            kb_note = "They'd love it: nobody's had one of these lately."
        elseif worth <= (content.killing_blows.FLOOR + 0.05) then
            kb_note = "They've had a lot of these lately: it barely lands now. Save them for the big ones."
        else
            kb_note = "Nice, but it means a little less each time you hand one over (" .. util.int(n) .. " lately)."
        end
    end
    for i, o in ipairs(card.options) do
        local keeps = (rul == "book" and (o.leans == "book" or o.leans == "strict")) or (rul == "cool" and o.leans == "cool")
        view.options[i] = { label = util.sentence_case(util.fill(o.label, vars)), roll = o.roll ~= nil, cooked = o.cooked,
                            skill = o.roll and o.roll.skill and skills.name(select(1, self:best_skill(self.actor or self.players[1], o.roll.skill))),
                            leans = self:leans(o.preview or o.effects), promise = keeps or nil,
                            sub = (o.kb == "actor" and kb_note) or o.sub, sub_tone = o.sub_tone,
                            disabled = o.disabled, cost = o.cost }
    end
    view.who = card.who
    view.intermission = card.intermission       -- (the break: night_view draws the table getting up)
    if card.type == "rules" and not self:table_behavior("rules") and self.rng:chance(0.7) then
        self:bark(self:pick_actor({ "tactician", "power_gamer" }), "rules_lawyer")
    end
    -- A choice that's the players' to make (museum_night.table_pick: they talk it over, and the DM
    -- only nudges when asked) arrives already made: no card for the DM.
    local auto = card.party_pick
    local pick
    if auto then
        pick = auto
    else
        pick = self:emit({ kind = "decision", card = view, actor = self.actor and self.actor.key })
    end
    pick = util.clamp(math.floor(tonumber(pick) or 1), 1, #card.options)
    -- (An answer that can't be given here is never taken: the first one that can.)
    if card.options[pick].disabled then
        for i, oo in ipairs(card.options) do
            if not oo.disabled then
                pick = i
                break
            end
        end
    end
    local o = card.options[pick]
    table.insert(self.decisions, { card = card.id, option = pick, rolls = {}, table = auto and true or nil })
    self.why = auto and ("the table's choice at \"" .. card.title .. "\"") or ("your call on \"" .. card.title .. "\"")
    if o.log then
        self:say(o.log, o.screen and "screen" or "dm", extra)
    end
    -- Breaks and lookups take real time at the table (A14).
    self.table_min = (self.table_min or 0) + (o.table_min or 0) + (o.looked and 8 or 0)
    -- (A long option isn't the night's break: Pip's ten minutes alone on the stairs took the break
    -- card's place, the second playtest review. Only museum_night.maybe_break sets had_break.)
    if o.canon then
        table.insert(self.canon, util.fill(o.canon, self:vars(extra)))
    end
    if o.spotlight_lowest then
        local low = self:lowest()
        if low then
            -- You turned to them: the next big roll and the next card are theirs (playtest, October
            -- 13: "Turn to Oswin", then Pip got the next two rolls).
            if not low.shy then
                self.owed = { key = low.key, rolls = 1, cards = 1, scene = self.scene and self.scene.index or 0 }
            end
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
    -- A call before a fight that has the party move first.
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
    -- The party splits for real (the playtest, November 3: "all minis are still here and in initiative,
    -- and no cutting back and forth"): for the rest of this scene the ones who wandered off are
    -- elsewhere. A fight here starts without them, and the DM cuts to them between rounds until they
    -- come running (fight.lua).
    if card.needs and card.needs.every then
        self.campaign.headache_week = self.campaign.headache_week or {}
        self.campaign.headache_week[card.needs.every_key or card.id] = self.campaign.week or 0
    end
    if o.split and self.scene then
        local away = {}
        local names = {}
        for _, q in ipairs({ self.actor, self.other }) do
            if q then
                away[q.key] = true
                table.insert(names, q.char)
            end
        end
        self.scene.split = { away = away }
        -- (In the log, R7: a hero going off alone, and who.)
        for _, q in ipairs({ self.actor, self.other }) do
            if q then
                events.add(self.campaign, { kind = "alone", who = q.key, where = self.scene.room, from = events.cause(self.campaign),
                                            beat = (q == self.actor) or nil,
                                            text = (q == self.actor) and util.fill(M.ALONE_TEXT[#names > 1 and 2 or 1], { names = util.join_names(names) }) or nil })
            end
        end
    end
    self.last_roll = nil
    if o.roll then
        self.last_roll = self:big_roll(o.roll)
    end
    if card.type == "rules" then
        self:conflict_rules(card)
    end
    -- What the call did to each of them, for the room's card and the report (the playtest, Nov 2:
    -- "The table:" said how they felt, never which call did it).
    if card.options and #card.options > 1 and not auto then
        local deltas, size = {}, 0
        for _, p in ipairs(self.players) do
            local d = score.fun(p) - (fun_before[p.key] or score.fun(p))
            if math.abs(d) >= 1.5 then
                deltas[p.key] = d
                size = size + math.abs(d)
            end
        end
        self.call_log = self.call_log or {}
        table.insert(self.call_log, { title = util.sentence_case(util.fill(card.title or "", self:vars(extra))),
                                      label = util.fill(o.label or "", self:vars(extra)),
                                      scene = self.scene and self.scene.index or 0, deltas = deltas, size = size })
    end
    -- How it landed, on their faces and at the table (the playtest, November 3): a good call gets a
    -- grin or hands in the air, a bad one a frown or crossed arms, before they settle back.
    if card.options and #card.options > 1 then
        local poses = {}
        for _, p in ipairs(self.players) do
            local d = score.fun(p) - (fun_before[p.key] or score.fun(p))
            if d >= 6 then
                poses[p.key] = "cheer"
            elseif d >= 3 then
                poses[p.key] = "laugh"
            elseif d <= -6 then
                poses[p.key] = "arms"
            elseif d <= -3 then
                poses[p.key] = "frown"
            end
        end
        self:react(poses)
    end
    -- What someone thought of that, and didn't say. (Not of the table's own choice: it wasn't yours.)
    if not auto then
        thoughts.after(self, fun_before, card, o)
    end
    return o
end

-- A call, said as what it did: "\"Let them reach in\": Mara +6, Dev -3." (by their fun this night).
-- A call as the table heard it: the card, what you said, and whose Fun it moved.
local function call_label(c)
    local label = (string.gsub(c.label or "", "%s*%b[]", ""))
    label = (string.gsub(label, "%s*%(you prepped it%)", ""))
    return (string.gsub(label, "\"", "'"))
end

local function call_words(c)
    return (c.title or "A call") .. ", \"" .. call_label(c) .. "\""
end

local function signed(d)
    return (d > 0 and "+" or "-") .. util.int(math.floor(math.abs(d) + 0.5))
end

function M:call_text(c)
    local bits = {}
    for _, p in ipairs(self.players) do
        local d = c.deltas[p.key]
        if d then
            table.insert(bits, p.name .. " " .. signed(d))
        end
    end
    if #bits == 0 then
        return nil
    end
    return call_words(c) .. " (Fun: " .. table.concat(bits, ", ") .. ")."
end

-- The call that moved the table most in this scene.
function M:scene_call(sc)
    local best
    for _, c in ipairs(self.call_log or {}) do
        if c.scene == (sc and sc.index) and c.size > 0 and (not best or c.size > best.size) then
            best = c
        end
    end
    return best and self:call_text(best) or nil
end

-- Tonight's calls that moved the table most, biggest first (n of them).
function M:top_calls(n)
    local list = {}
    for _, c in ipairs(self.call_log or {}) do
        if c.size > 0 then
            table.insert(list, c)
        end
    end
    table.sort(list, function(a, b) return a.size > b.size end)
    local out = {}
    for i = 1, math.min(n or 5, #list) do
        table.insert(out, self:call_text(list[i]))
    end
    return out
end

-- The call of yours that moved one player most tonight, for their row on the report.
function M:player_call(key)
    local best, bd
    for _, c in ipairs(self.call_log or {}) do
        local d = c.deltas[key]
        if d and (not bd or math.abs(d) > math.abs(bd)) then
            best, bd = c, d
        end
    end
    if not best or math.abs(bd) < 3 then
        return nil
    end
    -- (The number first: a long call is cut at the end of the row, not its point.)
    return signed(bd) .. " Fun from your call \"" .. call_label(best) .. "\" (" .. (best.title or "a call") .. ")."
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
-- Runs before any of the scene's cards are described. A veiled card plays off screen and an
-- X-carded one is skipped: either way its description is muted.
function M:safety_check(sc)
    local tbl = self.campaign.table
    if not tbl or not sc then
        return
    end
    local cards = {}
    for _, kind in ipairs(content.kinds) do
        if sc.comps[kind] then
            table.insert(cards, sc.comps[kind])
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
                    self:say("You keep " .. what .. " off screen, like you promised " .. p.name .. ".", "screen")
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
                        self:say(util.fill("{name} goes quiet. {Name_they} drew a line at this at Session Zero.", { name = p.name }), "warn")
                        score.add(p, "trust", -10)
                        score.add(p, "commitment", -3)
                    else
                        self:say(util.fill("{name} goes quiet. {Name_they} asked you about this at Session Zero.", { name = p.name }), "warn")
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
    -- (Not on a turn where their hero can't do anything: down, stone, out of it. Round three, A1.)
    if who and who.pc and able.can_fight(self, who.player_key) and self.rng:chance(ev.brisk and 0.12 or 0.22) then
        local p
        for _, q in ipairs(self.players) do
            if q.key == who.player_key then
                p = q
            end
        end
        local trigger, at, target = self:turn_trigger(steps, who)
        -- (A turn of only walking, on a big board: they say so, in their own words.)
        local walking = #steps > 0
        for _, s in ipairs(steps) do
            walking = walking and s.kind == "move"
        end
        if walking then
            trigger, at = "walk", "start"
        end
        if p and trigger and not able.hush(self, trigger) then
            local mo = barks.from_steps(self, steps, who, p)
            local text, id = barks.pick(self, trigger, p, mo, self:vars({ target = target }))
            if text then
                ev.say = { who = p.key, text = text, ic = talk_mod.in_character(trigger), line = id, at = at }
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
    -- What the party carries into an adventure's fight: what they picked up works here, and the
    -- table hears it (game/model/museum_night.lua arm, from MODULE.items).
    util.lazy("game.model.museum_night").arm(self, sc)
    local plan = fight.plan(self, sc)
    sc.boss_name = plan.boss_name
    self.battle_boss_name = plan.boss_name
    sc.plan = plan
    -- A card for this fight: a rules question waits for round two, anything else comes first.
    -- Or the boss's turn is yours to run (B8), in place of that card.
    sc.boss_turn_planned = takeover.plan_boss(self, sc)
    local card = not sc.card_done and ((not sc.boss_turn_planned and not sc.talked) or self:idle() > 75)
        and self:pick_decision(sc)
    if card and card.type == "rules" then
        sc.rules_card = card
    elseif card then
        self:decision(card)
    end
    -- Who sees whom first: a paused roll before the fight.
    sc.surprise = nil
    local scouted = false
    -- (A nat-1 mishap in a quiet moment made a racket: table_life.lua. Nobody sneaks up on anyone.)
    if self.noisy then
        self.noisy = nil
        sc.no_sneak = true
    end
    if sc.ambushed then
        -- They walked into an ambush (a boss who strikes first): surprised, and no scouting roll.
        sc.surprise = "party"
        scouted = true
    elseif sc.no_sneak then
        -- Somebody gave them away (a fussing gnome, a talking boot): no sneaking up on anyone.
        scouted = true
    elseif (self.rng:chance(0.45) or self:idle() > 50) and self:decision_count() < 13 then
        self:scout(sc)
        scouted = true
    end
    -- Who they're up against, out loud, before anyone tries anything (the story playtest: "Roll
    -- initiative!" with no name left the table guessing who the enemy was).
    self:say(self:foe_line(plan, sc), "narration")
    -- Somebody at the table has other ideas (A12): a flashy opening move.
    if not scouted and self:idle() < 60 and self.rng:chance(0.4) then
        self:stunt(sc)
    end
    self:say(self:fight_caption("start", self:vars()), "dm")
    local boss_fan = self:pick_actor({ "butt_kicker", "tactician", "storyteller" })
    self:bark(boss_fan, "boss_appears", { ctx = self:boss_context(plan, sc) })
    local result, f = fight.run(self, sc, plan)
    sc.result = result
    sc.outcome = result.winner == "party" and "win" or "lose"
    -- Who's beaten and who got away, for every line after the fight (a boss that ran isn't beaten).
    sc.foes_ran, sc.foes_beaten = {}, {}
    -- (And who on their side is gone for good: a machine smashed or burnt out, not a friend knocked
    -- flat who comes round. What's destroyed stays destroyed: round three, B3. museum_night.after_showdown.)
    sc.allies_lost = {}
    local persons = {}
    for _, e in ipairs(require("game.model.companions").active(self.campaign, self.players)) do
        if e.monster and e.kind == "person" then
            persons[e.monster] = true
        end
    end
    for _, c in util.sorted_pairs(f and f.by_ref or {}) do
        if c.side == "foes" and c.monster_id then
            if c.dead then
                table.insert(sc.foes_beaten, c.monster_id)
            elseif c.removed and c.removed_why ~= "yield" then
                table.insert(sc.foes_ran, c.monster_id)
            end
        elseif c.side == "party" and not c.pc and c.monster_id and c.dead and not persons[c.monster_id] then
            table.insert(sc.allies_lost, { id = c.monster_id, name = c.name, burnt = c.shut_down or nil })
        end
    end
    -- The boss's own fate, so what's said after can't contradict it: dead (and how), ran, or yielded.
    local fb = f and f.boss
    sc.boss_yielded = (f and f.yielded and fb and not fb.dead) or nil
    sc.boss_ran = (fb and fb.removed and not fb.dead and not sc.boss_yielded) or nil
    sc.boss_dead = (fb and fb.dead) and (fb.dead_why or "beaten") or nil
    -- The fight, in the log (R7): every line after it about how it went reads it from there.
    local fev = self:log_fight(sc, f, result)
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
    -- A hero left on the floor when it's over comes round (stable, so 1 hit point after a while,
    -- SRD 5.2.1), and the table hears it: nobody cheers or rolls from 0 hit points. (Said once for all
    -- of them. A lost fight with every hero on the floor is a wipe: said as one, the table goes quiet
    -- for the rest of the room, and it leads the night's recap. Round three, A6: four "comes round"
    -- lines in a row, then a vote over the kitchen diorama.)
    local floor, standing = {}, 0
    for _, c in ipairs(self.pc_list or {}) do
        if not c.dead and (c.hp or 0) <= 0 then
            c.hp, c.down, c.stable, c.ds = 1, false, nil, nil
            table.insert(floor, c.name)
        elseif not c.dead and able.state(self, c.player_key) == nil then
            standing = standing + 1         -- (one turned to stone isn't standing either)
        end
    end
    local wiped = result.winner ~= "party" and #floor >= 2 and standing == 0
    if wiped then
        self.loss = { scene = sc, kind = "wipe", night = true }
        self:say(self:fresh(BARKS.told.wipe, "told_wipe"), "bad")
        self:say(util.join_names(floor) .. " come round on the floor with 1 hit point each, groggy, alive, and beaten.", "aside")
        local loc = sc.comps and sc.comps.location
        events.add(self.campaign, { kind = "wipe", who = "party", where = sc.room, beat = true, lead = true, from = sc.fight_ev, how = "but",
                                    text = events.word("wipe", { room = loc and (loc.short or util.lower_first(loc.name)) or "the museum" },
                                                       "the whole party went down") })
    elseif #floor > 0 then
        self:say(util.join_names(floor) .. (#floor == 1 and " comes" or " come") .. " round on the floor with 1 hit point"
            .. (#floor == 1 and "" or " each") .. ", groggy but alive.", "aside")
    end
    -- (Every hero who went down in it, for the recap's lead: "Brannoc went down twice". Not the dead,
    -- whose death leads; not after a wipe, which says it for everyone. Round three, A7.)
    if not wiped then
        for _, c in ipairs(self.pc_list or {}) do
            local n = c.stats and c.stats.downs or 0
            if n > 0 and not c.dead and c.player_key then
                events.add(self.campaign, { kind = "down", who = c.player_key, char = c.name, n = n, where = sc.room, beat = true,
                                            lead = true, from = sc.fight_ev, how = "but",
                                            text = events.word(n > 1 and "down_n" or "down", { char = c.name, n = events.times(n) },
                                                               n > 1 and "{char} went down {n}" or "{char} went down") })
            end
        end
    end
    -- (Someone on their side who fell comes round now: companions.lua.)
    require("game.model.companions").after_fight(self)
    if result.winner == "party" then
        -- Won is won, but say how: the foes ran, or gave up (the newcomer playtest, October 16:
        -- "runs for it" then "the last one falls" read as two different endings).
        -- (Any foe that ran, not just a called retreat: "the last one falls" was said over a boss
        -- that had run for it, the combat audit, Nov 2.)
        -- (A boss who yielded already said so, in her own words: fight.lua's yield.)
        -- (How it ended is the log's: the fight event says how many there were and how many ran.)
        local how = ((f and f.fled) or fev.ran > 0) and "party_win_fled" or "party_win"
        -- (One foe isn't "the last one": it's named.)
        local foes = fev.foes
        local v = self:vars()
        if how == "party_win" and foes == 1 and fev.boss then
            how = "party_win_one"
            v.foe, v.Foe = util.lower_first(fev.boss), util.capitalize(fev.boss)
        end
        -- (Only one ran: "the rest scatter" said over a boss who ran alone, the second playtest review.)
        if how == "party_win_fled" and fev.ran == 1 then
            how = "party_win_fled_one"
            for _, c in util.sorted_pairs(f and f.by_ref or {}) do
                if c.side == "foes" and c.removed and not c.dead and c.removed_why ~= "yield" then
                    v.tgt = require("game.model.barks").foe_label(c)
                    v.Tgt = util.capitalize(v.tgt)
                end
            end
        end
        if not (f and f.yielded) then
            self:say(self:fight_caption(how, v), "good")
        end
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
        self:bark(self:pick_actor({ "butt_kicker", "casual", "tactician" }), close and "victory_close" or "victory",
            (sc.boss_ran or sc.boss_yielded) and { boss = false } or nil)
        for _, p in ipairs(self.players) do
            score.add(p, "challenge", 6)
            score.add(p, "fun", 2)
        end
    else
        -- A lost fight in the museum is the museum's to tell (they fall back to a room they've
        -- cleared, or she lets them go down the stairs): no cells, no generic defeat scene.
        if not wiped then
            self:say("They can't win this one.", "bad")
        end
        local poses = {}
        for _, p in ipairs(self.players) do
            poses[p.key] = "gasp"
            score.add(p, "challenge", 10)
            score.add(p, "fun", -4)
        end
        self:react(poses)
        -- (No "defeat" beat of its own: the room's goal says how it went, once, for the recap.)
        -- (After a wipe, a friend says what everyone's thinking, not a joke.)
        if wiped then
            local q = self:pick_actor({ "casual", "tactician", "storyteller" })
            if q then
                self:emit({ kind = "say", who = q.key, ic = false, line = "told.wipe_react", text = self:fresh(BARKS.told.wipe_react, "told_wipe_react") })
            end
        else
            self:bark(self:pick_actor(nil), "defeat")
        end
    end
    -- Tactical fun: close fights thrill Tacticians, stomps bore them.
    local downs = result.pc_downs or 0
    if downs == 0 and (result.rounds or 0) <= 2 then
        self:apply({ { "arch:tactician", fun = -3, challenge = -4 } })
    elseif downs >= 1 and result.winner == "party" then
        self:apply({ { "arch:tactician", fun = 4 }, { "arch:butt_kicker", fun = 3 } })
        self:highlight(6, "a fight that came down to the wire", self.players)
    end
    -- No automatic patch-up after a fight (A16): rests are the break's, and the gift shop's.
    self.fights_since_long = (self.fights_since_long or 0) + 1
    for _, c in ipairs(self.pc_list or {}) do
        if c.down and not c.dead then
            c.down, c.hp = false, math.max(1, c.hp)    -- stabilized after the fight, back on their feet at 1
        end
    end
end

-- A fight in the event log (R7): who they fought (the leader by name), how many, who ran, who fell,
-- the boss's fate, how it came out, and what it followed from: the choice that started it
-- ("therefore"), or the room turning on them ("but"). Its clause tells it for the chain (R14).
-- (A hero going off alone, for the log's chain: one of them, or two.)
M.ALONE_TEXT = { "{names} went off alone", "{names} went off on their own" }
local FIGHT_TEXT = {
    -- How it started: their choice, or the room coming at them.
    chose = "they fought {boss}", sprang = "{boss} came at them",
    -- How it ended.
    won = ", and they won", won_ran_one = ", and it got away", won_ran = ", and they won, but some got away",
    yielded = ", until {boss} asked them to stop", dead = ", and {boss} fell", ran = ", and {boss} got away",
    lost = ", and it was too much for them",
}
M.FIGHT_TEXT = FIGHT_TEXT
function M:log_fight(sc, f, result)
    local c = self.campaign
    local foes, ran, beaten = 0, {}, {}
    local boss_id
    for _, cr in pairs(f and f.by_ref or {}) do
        if cr.side == "foes" then
            foes = foes + 1
        end
    end
    for _, id in ipairs(sc.foes_ran or {}) do
        table.insert(ran, id)
    end
    for _, id in ipairs(sc.foes_beaten or {}) do
        table.insert(beaten, id)
    end
    table.sort(ran)
    table.sort(beaten)
    if f and f.boss then
        boss_id = f.boss.monster_id
    end
    local boss = (f and f.boss_name) or (sc.encounter and sc.encounter.boss_name) or "them"
    local outcome = result.winner == "party" and "won" or "lost"
    local fate = (sc.boss_dead and "dead") or (sc.boss_ran and "ran") or (sc.boss_yielded and "yielded") or nil
    local key
    if fate == "yielded" then
        key = "yielded"
    elseif sc.boss and fate == "dead" then
        key = "dead"
    elseif sc.boss and fate == "ran" then
        key = "ran"
    elseif outcome == "lost" then
        key = "lost"
    elseif #ran > 0 then
        key = (#ran == 1 and foes == 1) and "won_ran_one" or "won_ran"
    else
        key = "won"
    end
    -- (A fight follows from what started it: a choice to fight, a trail followed with weapons out, a
    -- roll that went wrong, or, "but", the talk that ended her part and not her collection's. A room's
    -- own fight, one that came whatever they did, follows from nothing: it starts a sentence of its own,
    -- and isn't stitched to walking in. R14.)
    local from, how = sc.fight_from, sc.fight_how or "therefore"
    local ev = events.add(c, { kind = "fight", who = "party", whom = boss_id, where = sc.room, outcome = outcome, foes = foes,
                               ran = #ran, ran_ids = ran, beaten = beaten, boss = boss, fate = fate, rounds = result.rounds,
                               from = from, how = from and how or nil, beat = true,
                               text = util.fill(FIGHT_TEXT[(not from or how == "but") and "sprang" or "chose"] .. FIGHT_TEXT[key], { boss = util.lower_first(boss) }) })
    sc.fight_ev, sc.last_beat = ev.id, ev.id
    -- (Friendly fire is the recap's too: who it caught, whose spell. Round three, B2.)
    for _, ff in ipairs(f and f.friendly or {}) do
        local by = ff.by and self.campaign:player(ff.by)
        local down = #(ff.downed or {}) > 0
        events.add(c, { kind = "friendly", who = by and by.key or "party", where = sc.room, beat = true, lead = down or nil,
                        from = ev.id, how = "but",
                        text = events.word(down and "friendly_down" or "friendly",
                            { char = ff.char, spell = ff.spell or "swing", hit = util.join_names(ff.hit), downed = util.join_names(ff.downed or {}) },
                            down and "{char}'s {spell} dropped {downed}" or "{char}'s {spell} caught {hit} too") })
    end
    return ev
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
-- (Said at every fight: three or more ways each, R3. The ones for foes already in view, then the
-- ones only for foes nobody's seen yet.)
M.FOE_LINES = {
    "{Boss}, with {rest} behind them.",
    "It's {boss}, with {rest} at their back.",
    "{Boss}, and {rest} with them.",
}
-- (Only for foes nobody's seen yet: "out of hiding" over a knight already climbing out of its frame,
-- or Euryale mid-conversation, the second playtest review. F13.)
M.FOE_HIDDEN = {
    "Out of hiding comes {boss}, with {rest}.",
    "{Boss} steps into the open, {rest} close behind.",
}
M.FOE_ALONE = { "{Boss}, alone, and not worried about it.", "Just {boss}. That's plenty.", "Only {boss}. One's enough." }

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
    -- In view already: someone on the mat (the room's person, not still hidden), pieces that came
    -- alive, a moment that started the fight, a talk first.
    local seen = sc.wake or sc.fight_on or sc.talked or sc.showdown
        or (self.stage_now and self.stage_now.npc and not self.npc_pending)
    if not seen then
        local pool = {}
        for _, l in ipairs(M.FOE_LINES) do
            table.insert(pool, l)
        end
        for _, l in ipairs(M.FOE_HIDDEN) do
            table.insert(pool, l)
        end
        return util.fill(self:fresh(pool, "foe_lines_hidden"), v)
    end
    return util.fill(self:fresh(M.FOE_LINES, "foe_lines"), v)
end

-- Before a fight: who reacts first. The result sets who's surprised.
-- The museum's fights are in plain sight by the time anyone could scout (the playtest, November 4:
-- "the knight climbs out of its frame", then "Pip creeps ahead to scout"): who reacts first, instead.
-- (Three or more ways each: anything said every week is where players first notice the machine, R3.)
local READY = {
    rogue = { "{actor_char} is already moving, low and quick.", "{actor_char} drops into a crouch and watches for an opening.",
              "{actor_char} slips sideways, out of the light." },
    fighter = { "{actor_char} steps in front of everyone, weapon up.", "{actor_char} plants {actor_their} feet between it and the others.",
                "{actor_char} rolls a shoulder and moves to the front." },
    wizard = { "{actor_char} has a spell on {actor_their} lips before anyone else moves.", "{actor_char} reads the room, fast.",
               "{actor_char} counts the exits, then the enemies." },
    cleric = { "{actor_char} murmurs a prayer and squares up.", "{actor_char} counts the danger and calls it out.",
               "{actor_char} grips {actor_their} holy symbol and stands {actor_their} ground." },
}
local REACTED = {
    success = { "They're quicker. Weapons out before it reaches them.", "They react first: everyone's ready when it comes.",
                "Nobody's caught napping. They're set before it moves." },
    fail = { "Too slow: it's on them before anyone moves.", "It's faster than it looks. Nobody's ready.",
             "It moves first, and they're still reaching for their weapons." },
}
M.READY, M.REACTED = READY, REACTED   -- (for the Dialogue Desk: tools/dialogue/export.lua)

-- Heroic Inspiration, flicked across the table (most nights): three ways.
M.INSPIRE_LINES = { "You flick the Heroic Inspiration token across the table. It lands in front of {name}: one reroll, to spend whenever {char} needs it.",
                    "The Heroic Inspiration token skids across the table and stops in front of {name}: one reroll, whenever {char} needs it.",
                    "You slide the Heroic Inspiration token over to {name}. One reroll, for whenever {char} needs it." }

-- The night's last line, and the Franc on a great roll: said every week, so three or more ways (R3).
M.WRAP_LINES = { "That's a wrap. Chairs scrape, someone stacks the dice.", "That's the night. Dice go back in their bags.",
                 "And that's a wrap. Somebody's already clearing the pizza boxes.", "Lights up. Someone stacks the character sheets." }
M.FRANC_LINES = { "Better than they hoped: a Flitwidget Franc pops into {char}'s pocket.",
                  "Better than hoped: {char} finds a Flitwidget Franc {char_they're} sure wasn't there a moment ago.",
                  "Better than they hoped: there's a crisp Flitwidget Franc in {char}'s hand. The gnome's face winks on it.",
                  "Better than they hoped: a Flitwidget Franc flutters down out of nowhere into {char}'s palm." }

-- The DM's word as a fight starts and ends, three or more ways each, fresh across weeks (R3: "The
-- last one falls. Silence, then cheering." over a single foe, three weeks running). one: the fight
-- had one foe, named. Other fight captions are scene_beats' (talk:fight).
local FIGHT_CAPTIONS = {
    start = { "Weapons out. Here we go.", "Here they come.", "Chairs scrape. Here we go.", "Dice up. Here it comes.",
              "Everyone leans in over the mat." },
    party_win = { "The last one falls. Silence, then cheering.", "It's over. Everyone breathes out.",
                  "The last of them goes down, and the whole table exhales.", "That's the last one. Somebody actually applauds." },
    party_win_one = { "{Foe} falls. Silence, then cheering.", "{Foe} goes down and stays down. Everyone breathes out.",
                      "That's {foe} done. The table exhales.", "{Foe} drops. A beat, then high fives across the table." },
    party_win_fled = { "The rest scatter and don't look back. The fight is theirs.",
                       "And they're gone, running hard. Nobody's chasing them. It's over.",
                       "What's left of them bolts. Nobody's sorry to see them go." },
    party_win_fled_one = { "{Tgt} is gone, running hard, and nobody's chasing. The fight is theirs.",
                           "{Tgt} gets away, and that's the last of them. It's over.",
                           "{Tgt} runs for it. Nobody follows. The fight is theirs." },
}
M.FIGHT_CAPTIONS = FIGHT_CAPTIONS

function M:fight_caption(what, vars)
    local pool = FIGHT_CAPTIONS[what]
    if not pool then
        return self.talk:fight(what, vars)
    end
    return util.fill(self:fresh(pool, "fight_" .. what), vars or {})
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
    -- (A plan that "works perfectly" needs the room to have gone their way.)
    m.explore = (sc.type == "exploration" or sc.type == "puzzle") and sc.outcome ~= "lose" and sc.outcome ~= "fail"
    return m
end

local function doer_weight(def, p, campaign)
    if def.class and p.class ~= def.class then
        return 0
    end
    local d = def.doers
    if not d then
        return 1
    end
    local w = (d[p.primary] or 0) + (d[p.secondary] or 0) * 0.5
    -- (v2: a friend the DM has talked down acts up less: the answer counts. The playtest, Nov 2:
    -- Pip pocketed the same figure three times a night whatever the DM said.)
    local calm = campaign and campaign.adv and campaign.adv.calm and campaign.adv.calm[p.key]
    if calm then
        w = w * (0.4 ^ calm)
    end
    return w
end

function M:party_moment(sc)
    -- (What a hero does to another happens between heroes in this scene: one who wandered off
    -- isn't in it, F11.)
    local here = self:at_hand()
    if #here < 2 or self.end_early then
        return
    end
    local moments = self:scene_moments(sc)
    local fr = content.friction
    local function eligible(list)
        local cands, w = {}, {}
        for _, def in ipairs(list) do
            -- (In an adventure, each act happens once in the whole of it, not once a night.)
            local once = self.campaign.adv and (self.campaign.adv.acts_done or {})[def.id]
            if moments[def.when or "any"] and (def.needs ~= "cast" or (sc.comps.cast and not self:muted(sc.comps.cast)))
                and not (self.friction_done and self.friction_done[def.id]) and not once then
                for _, p in ipairs(here) do
                    local dw = doer_weight(def, p, self.campaign)
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
        -- (Somebody just handed over what they found: "lets them have first pick" right after it is
        -- the same thing said twice. The second playtest review.)
        if self.handed_off and self.handed_off == (sc and sc.index or true) then
            for i = #cands, 1, -1 do
                if cands[i].def.id == "share_the_loot" then
                    table.remove(cands, i)
                    table.remove(w, i)
                end
            end
        end
        if #cands > 0 then
            local pick = self.rng:weighted(cands, w)
            self:bond_act(sc, pick.def, pick.p)
        end
    end
end

function M:friction_act(sc, def, doer)
    self.friction_done[def.id] = true
    if self.campaign.adv then
        self.campaign.adv.acts_done = self.campaign.adv.acts_done or {}
        self.campaign.adv.acts_done[def.id] = self.campaign.week
    end
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
                    table.insert(opts, { label = util.fill(r.label, v), log = util.fill(r.log, v), resp = r, screen = r.screen })
                end
            end
        end
        -- The card says who's unhappy (A11: every consequence names its cause).
        local names = {}
        for _, p in ipairs(rapport.objectors(self.campaign, doer, def, self.players, target and target.key)) do
            table.insert(names, p.name)
        end
        -- Who minds this, not who's unhappy tonight (playtest, October 13: "Mara isn't having fun"
        -- while Mara cheered).
        local text = #names > 0 and (doer.name .. " is having fun. " .. util.join_names(names) .. (#names == 1 and " doesn't love it." or " don't love it."))
            or (doer.name .. " is having fun. The rest of the table is watching to see what you do.")
        local card = { id = "friction_" .. def.id, type = "table", title = "At the table", text = text, options = opts }
        self.actor = doer
        local o = self:decision(card)
        resp = o and o.resp
    end
    resp = resp or fr.responses[1]
    -- (What the DM said does something. Talking it down calms them for the rest of the
    -- adventure; a better outlet hands them the next card that could be anyone's.)
    if self.campaign.adv then
        if resp.id == "pause" or resp.id == "session_zero" or resp.id == "outlet" then
            local st = self.campaign.adv
            st.calm = st.calm or {}
            st.calm[doer.key] = (st.calm[doer.key] or 0) + 1
        end
        if resp.id == "outlet" then
            self.owed = { key = doer.key, cards = 1, rolls = 1, scene = self.scene and self.scene.index or 0 }
        end
    end
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
    -- (Only someone at the table whose hero is still standing, and in this scene, gives the look.)
    local who
    local here = self:at_hand()
    for _, q in ipairs(out.objectors) do
        local qc = self.pcs and self.pcs[q.key]
        if not who and util.contains(here, q) and not (qc and qc.dead) then
            who = q
        end
    end
    if who and self:idle() < 80 then
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
    local here = self:at_hand()       -- (heroes in this scene: F11)
    if def.amends then
        -- Amends come from someone others are hot with.
        local best, bh
        for _, p in ipairs(here) do
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
    -- What the line says happened has to have happened (fight.record, F13): a prayer that caught
    -- someone before they dropped is a heal on someone down or nearly; a move together is a foe they
    -- both hit and one of them finished; standing over someone needs them to have been in trouble.
    local rec = self.fight_record
    if def.needs_fight then
        local found
        for _, e in ipairs(rec and rec[def.needs_fight] or {}) do
            local a = def.needs_fight == "saves" and e.by or e.a
            local b = def.needs_fight == "saves" and e.to or e.b
            if not found and a == doer.key and b ~= doer.key then
                found = find_present(here, b)
            end
        end
        if not found then
            return
        end
        target = found
    elseif def.needs_close then
        local found
        for key in util.sorted_pairs(rec and rec.close or {}) do
            if key ~= doer.key and not found then
                found = find_present(here, key)
            end
        end
        if not found then
            return
        end
        target = found
    end
    -- A fight's teamwork only between two who did something in it (the playtest, Nov 2: a hero
    -- charmed the whole fight "pulled off a move together" with a friend).
    if def.when == "fight" and not def.needs_fight and not def.needs_close then
        local function acted(p)
            local c = p and self.pcs and self.pcs[p.key]
            local s = c and c.stats
            return s ~= nil and ((s.dealt or 0) > 0 or (s.healed or 0) > 0 or (s.kills or 0) > 0)
        end
        if not acted(doer) then
            return
        end
        if not acted(target) then
            target = nil
            for _, p in ipairs(here) do
                if p ~= doer and acted(p) then
                    target = target or p
                end
            end
        end
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
-- What comes back follows SRD 5.2.1 (game/rules/rest.lua).

function M:pc_of(p)
    return self.pcs and self.pcs[p.key]
end

-- A rest (the break, the gift shop, a trip back to it): "short" or "long". kind is the kind of
-- place, for the little scene it plays.
function M:do_rest(rest, kind)
    local long = rest == "long"
    self.table_min = self.table_min + (long and 15 or 8)
    local spend = rest_rules.SPEND
    local healed = 0
    local hurt = 0          -- (who needed it: "nobody had Hit Dice left" right after a long rest, F13)
    for _, c in ipairs(self.pc_list) do
        if not c.dead and (c.hp or 0) < (c.hp_max or 0) then
            hurt = hurt + 1
        end
    end
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
            items.settle(c, self.campaign)
        end
        items.dawn(self.campaign, self.rng)
        for _, c in ipairs(self.pc_list) do
            items.apply(self.campaign, c.player_key, c)
        end
        fight.prebuff(self)
        self.morning_buffs = true
    end
    self:say(long and ("A full night's rest. Everyone wakes whole, spells back, ready." .. fight.buff_line(self)) or
        (healed > 0 and ("An hour's rest: Hit Dice spent, " .. util.int(healed) .. " HP back across the party.")
         or (hurt == 0 and "An hour's rest. Nobody needed patching up, and the features are back.")
         or "An hour's rest. Nobody had Hit Dice left to spend, but the features are back."), "aside")
    self.rests = self.rests or {}
    table.insert(self.rests, { kind = long and "long" or "short", place = kind })
    self:emit({ kind = "rested", long = long })     -- (the tiles show what came back)
    if (self:arch_present("storyteller") or self:arch_present("method_actor")) and self:idle() < 80 then
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
            out.players[p.key].trust = -1
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
        if mm == 60 then
            h, mm = h + 1, 0
        end
        if h == 0 then
            return util.int(mm) .. "m"    -- "43m", not "0h 43m"
        end
        return util.int(h) .. "h" .. (mm > 0 and (" " .. util.int(mm) .. "m") or "")
    end
    local diff = r.minutes - r.planned
    local head
    if diff > 15 then
        -- (Past the time agreed at Session Zero, and what it cost: round three, A8.)
        local knocked = {}
        for _, p in ipairs(self.players) do
            local v = r.players[p.key]
            if v and v.trust then
                table.insert(knocked, p.name)
            end
        end
        head = "Ran " .. hm(diff) .. " past the " .. self:clock_text(r.planned) .. " you agreed at Session Zero (" .. hm(r.minutes) .. " at the table)."
            .. (#knocked > 0 and (" " .. util.join_names(knocked) .. (#knocked == 1 and " trusts" or " trust")
                .. " you a little less for it.") or "")
    elseif diff < -30 then
        head = "Finished " .. hm(-diff) .. " early (" .. hm(r.minutes) .. ")."
    else
        head = "Right on time (" .. hm(r.minutes) .. ")."
    end
    -- Grouped, so it reads "Jess and Sam were fading by 10:30 pm", not the same clause twice.
    local groups, order = {}, {}
    for _, p in ipairs(self.players) do
        local v = r.players[p.key]
        local tail
        if v and v.verdict == "long" then
            tail = "fading" .. (v.fading_at and (" by " .. self:clock_text(v.fading_at)) or "")
        elseif v and v.verdict == "short" then
            tail = "time to spare"   -- (not "wanted more" beside "checked out")
        end
        if tail then
            if not groups[tail] then
                groups[tail] = {}
                table.insert(order, tail)
            end
            table.insert(groups[tail], p.name)
        end
    end
    if #order == 0 then
        return head .. " It suited everyone."
    end
    local parts = {}
    for _, tail in ipairs(order) do
        local who = groups[tail]
        local many = #who > 1
        if string.sub(tail, 1, 6) == "fading" then
            table.insert(parts, util.join_names(who) .. (many and " were " or " was ") .. tail)
        else
            table.insert(parts, util.join_names(who) .. (many and " had " or " had ") .. tail)
        end
    end
    return head .. " " .. table.concat(parts, "; ") .. "."
end

-- Who leads the way takes turns over the campaign (A4): among those decent at it, whoever has
-- led least lately goes first.
function M:scout_roller(sc)
    local list = { "stealth", "perception", "survival", "athletics" }
    local camp = self.campaign
    camp.scouted = camp.scouted or {}
    local best = self:pick_roller(list, sc)
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
    camp.scouted[best.key] = (camp.scouted[best.key] or 0) + 1
    return best
end

function M:scout(sc)
    local best = self:scout_roller(sc)
    self.actor = best
    self.other = nil
    self:say(self:fresh(READY[best.class] or READY.rogue, "ready_" .. best.class), "goal")
    self:react({ [best.key] = "lean" })
    local spec = { dc = 12 + (sc.difficulty - 2), convenient = "success", skill = { "perception", "insight" },
                   quiet = true,     -- (spotting them first isn't a recap beat)
                   -- (The line is picked once it's said: one picked and never said still counted as
                   -- the last one, so the next could repeat what the table last heard.)
                   success = { fresh = { REACTED.success, "react_yes" },
                               effects = { { "actor", spotlight = 8 }, { "arch:tactician", fun = 4 } } },
                   fail = { fresh = { REACTED.fail, "react_no" },
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
    for _, p in ipairs(self:at_hand()) do
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
    local comp = sc.comps.complication
    -- A room's beat is its own snag's (the cards' `moment`), never a stock one ("win over the room
    -- before it turns", in a gift shop over tea).
    local mm = comp and comp.moment
    if not mm or comp.cliffhanger or self:muted(comp) or not self:room(12) then
        return
    end
    local best = self:pick_roller(comp.skill, sc)
    self.actor, self.other = best, nil
    self:say(mm.text, "goal")
    self:react({ [best.key] = "lean" })
    table.insert(self.decisions, { card = "moment_" .. sc.type, option = 0, rolls = {} })
    local ok = self:big_roll({ dc = 12 + (sc.difficulty - 2), convenient = "success", skill = comp.skill,
                               success = { log = mm.success, effects = { { "actor", spotlight = 8 } } },
                               fail = { log = mm.fail, effects = { { "all", challenge = 5 } } } })
    if ok then
        sc.progress.wins = sc.progress.wins + 1
    else
        sc.progress.setbacks = sc.progress.setbacks + 1
    end
    -- The dots on the top bar move with it (a triumph left them be).
    self:progress_event(sc)
end

-- The scene's dots on the top bar, as they stand: good moments, setbacks, and a warm word that made
-- the final roll easier (lead).
function M:progress_view(sc)
    local pr = sc.progress
    if not pr then
        return nil
    end
    local need = pr.need or 3
    return { wins = math.min(pr.wins, need), setbacks = pr.setbacks, need = need, max = content.scene_beats.setbacks }
end

function M:progress_event(sc)
    local pr = self:progress_view(sc)
    if pr then
        self:emit({ kind = "progress", progress = pr })
    end
end

-- A non-combat scene's big moment: one paused roll, then the DM's ruling.
function M:climax(sc)
    local st = content.scenes[sc.type]
    local cl = st.climax
    if not cl or sc.cut or sc.had_roll then
        return
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
    -- The goal's own moment, when it has one (the card-led night): "One stone at the altar's foot
    -- doesn't sit right", not the scene type's stock line.
    local gp, gvars = self:goal_play(sc)
    if gp and gp.moment then
        cl = { text = gp.moment.text, dc = cl.dc, prefer = cl.prefer, skill = gp.moment.skill or cl.skill,
               success = cl.success, fail = cl.fail }
        sc.moment_led = true
    end
    -- Whoever's good at what it asks steps up (A4).
    local best = self:pick_roller(cl.skill, sc, cl.prefer)
    self.actor = best
    self.other = nil
    self:say(cl.text, "goal", gvars)
    sc.climax_ran = true
    self:react({ [best.key] = "lean" })
    -- The goal pays off in its own words (the slice rework): the map found, the culprit named.
    local success, fail = cl.success, cl.fail
    local goal = sc.comps.goal
    if goal and goal.win and not self:muted(goal) then
        success = { log = goal.win, effects = cl.success.effects }
        fail = { log = goal.lose or cl.fail.log, effects = cl.fail.effects }
    end
    -- What the dots did to it: groundwork done makes it easier.
    local edge = sc.edge or 0
    local whys = {}
    if edge < 0 then
        table.insert(whys, "they did the groundwork")
    end
    local why = #whys > 0 and util.join_names(whys) or nil
    local spec = { dc = cl.dc + (sc.difficulty - 2) + edge, convenient = "success", success = success,
                   fail = fail, skill = cl.skill,
                   final = { goal = goal and not self:muted(goal) and goal.name or nil, edge = edge, why = why } }
    table.insert(self.decisions, { card = "climax_" .. sc.type, option = 0, rolls = {} })
    local ok = self:big_roll(spec)
    sc.outcome = ok and "win" or "lose"
    sc.goal_said = true
    self:goal_event(sc)
end

-- How a scene's goal came out, in its own words: the museum picks the words that match what
-- actually happened (game/model/museum_night.lua goal_text).
function M:goal_text(sc, goal)
    return util.lazy("game.model.museum_night").goal_text(self, sc, goal)
end

function M:goal_event(sc)
    local goal = sc.comps.goal
    if goal and goal.win and not self:muted(goal) then
        local text = self:goal_text(sc, goal)
        text = util.sentence_case(util.fill(text, self:vars()))     -- as it was said ({Cast}, {deal}...)
        self:event("goal", { who = "party", text = text, weight = sc.outcome == "win" and 6 or 7 })
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
        self:say(self:goal_text(sc, goal), sc.outcome == "win" and "good" or "bad")
        self:goal_event(sc)
    end
end

-- The night's log ---------------------------------------------------------------------------------

function M:note(sc, entry)
    entry.s = sc and sc.index
    entry.at = entry.at or (sc and sc.comps.location and sc.comps.location.id)
    table.insert(self.ledger, entry)
    return entry
end

-- The night's events (M8, B1). The night's ledger is the one event log: besides who did what,
-- it keeps the moments a table talks about afterwards. The recap, running jokes and the report
-- read these.
--   ev     the kind: moment, crit, fumble, down, death, killing_blow, inspiration, cooked, callout,
--          jail, escape, villain_falls, stunt, talk, boss_turn, goal, new_character, unfair
--   who    the player it's about (a key), or "party"; keys: everyone in it
--   text   a line for the recap;  weight how big a moment it was, 1 to 10
M.EVENT_WEIGHT = { moment = 4, crit = 6, fumble = 5, down = 6, death = 10, killing_blow = 8, inspiration = 5,
                   cooked = 3, callout = 6, jail = 3, escape = 7, villain_falls = 9, stunt = 5, talk = 6, boss_turn = 3 }

function M:event(ev, fields)
    local e = fields or {}
    e.ev = ev
    e.weight = e.weight or M.EVENT_WEIGHT[ev] or 3
    e.clock = self.clock
    e.who = e.who or "party"
    -- Who it was.
    if e.who ~= "party" and not e.char then
        local p = self.campaign:player(e.who)
        e.char = p and p.char or nil
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
M.SNAP_KINDS = { death = true, killing_blow = true, villain_falls = true, crit = true, escape = true, goodbye = true,
                 new_character = true }
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
    -- Mid-fight: the fight so far, up to this moment, to play back (the last 20 turns).
    if self.battle and self.fight_frames and #self.fight_frames > 1 then
        local fr, acts = {}, {}
        for i = math.max(1, #self.fight_frames - 19), #self.fight_frames do
            table.insert(fr, self.fight_frames[i])
            table.insert(acts, self.fight_acts and self.fight_acts[i] or {})
        end
        local kinds = {}
        for id, k in pairs(self.fight_kinds or {}) do
            kinds[id] = { side = k.side, class = k.class, monster = k.monster, name = k.name, hp_max = k.hp_max }
        end
        snap.frames, snap.kinds, snap.acts = fr, kinds, acts
        snap.wake = self.fight_wake
    end
    table.insert(self.snapshots, snap)
    return snap
end

-- A room of the adventure, played as a scene (museum_night.play builds it): the board and the minis,
-- the room's own read-aloud, its moments, then its fight or its checks and big roll, and how it went.
function M:play_scene(sc)
    local mus = util.lazy("game.model.museum_night")
    self.scene = sc
    self.actor, self.other = nil, nil
    sc.terrain = self:terrain_for(sc)
    sc.title = self:scene_title(sc)
    local party, npc = self:staging(sc)
    local cast = sc.comps.cast
    local goal = sc.comps.goal
    self.stage_now = { terrain = sc.terrain, board = self:board_for(sc), party = party, npc = npc }
    local map = self:map_for(sc)
    self:board_set(self:board_for(sc), sc)
    self:emit({ kind = "scene", index = sc.index, title = sc.title, type = sc.type, board = self:board_for(sc),
                type_name = content.scenes[sc.type].name, terrain = sc.terrain, party = party, npc = npc,
                npc_hidden = npc ~= nil and not self:npc_in_view(sc, party, npc),
                pieces = map and map.template == sc.terrain and maps.cells(map) or nil,
                cast = cast and cast.name, goal = goal and goal.name })
    thoughts.dawn(self)          -- a thought you misread: it comes to you now what it really was
    self:safety_check(sc)
    -- The person in the scene appears on the mat when the DM names them (or they speak).
    self.npc_pending = (npc ~= nil and not self:npc_in_view(sc, party, npc)) or nil
    mus.read(self, sc)                           -- the room's own read-aloud
    self:dress_board()
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
    self:say_intent(sc)
    mus.room_start(self, sc)      -- the heroes it's for, how you're running it, its first calls
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
    mus.moments(self, sc, "mid")
    local fight_here = mus.has_fight(sc) and not self.end_early
    sc.fought = fight_here or nil
    if sc.resolved then
        -- A room settled by its own moment (the ritual, a bargain): no checks, no big finish.
    elseif fight_here then
        if talk_now and not sc.showdown then
            takeover.talk(self, sc)        -- a word before the fight (B8), in place of the fight's card
        end
        self:combat_scene(sc)
    else
        if not (talk_now and takeover.talk(self, sc)) and not (sc.comps.cast and sc.comps.cast.talks == false) then
            self:conversation(sc)
        end
        self:conflict_spotlight(sc)
        self:quick_checks(sc)
        -- (An adventure's epilogue, the thanks downstairs, has no big roll to fail: it's over.)
        if not self.end_early and not sc.epilogue then
            self:climax(sc)
        end
    end
    self:settle_scene(sc)
    mus.explore_after(self, sc)    -- (looking around once the fight's done: museum_night.explore)
    mus.moments(self, sc, "end")
    mus.quiet_stretch(self, sc)    -- (the small moments, once the room's danger is settled)
    mus.reward(self, sc)          -- only what they earned, said once (museum_night.reward)
    -- How the scene went, as a card beside the table while the night moves on (the newcomer
    -- playtest, October 16: "damp squib" and "empty-handed" in the log, then "Loved it" in the
    -- report; the card keeps what the heroes did apart from how the table took it).
    if not self.end_early then
        local goal = sc.comps.goal
        local r = sc.comps.reward
        self:emit({ kind = "scene_end", index = sc.index, title = sc.title, call = self:scene_call(sc),
                    type_name = content.scenes[sc.type] and content.scenes[sc.type].name or nil,
                    goal = goal and not self:muted(goal) and goal.name or nil, outcome = sc.outcome,
                    reward = r and not self:muted(r) and mus.has_reward(self, sc, r) and util.capitalize(soft_lower(r.got or r.name)) or nil,
                    fight = (sc.type == "combat" or sc.type == "set_piece") or nil })
    end
    -- What the characters do to each other (A17): a rub, or a bond.
    self:party_moment(sc)
    self:maybe_callout(0)
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

-- The adventure module walks its own map (game/model/museum_night.lua), and ends with run_tail.
function M:run()
    return util.lazy("game.model.museum_night").run(self)
end

-- A night run long, said at the end of it ({time}: now; {agreed}: the end agreed at Session Zero), and
-- a good night's ending when everyone's too tired to cheer it. Three ways each (R3).
M.LATE_LINES = {
    "It's {time}. You all agreed to stop at {agreed}, and everyone's yawning into their dice.",
    "{time}. Somebody points at the clock: Session Zero said {agreed}. Nobody laughs.",
    "It's gone {time}, well past the {agreed} you all agreed on. Phones are out, checking alarms for the morning.",
}
M.LATE_HIGH = {
    "It was a good night. Everyone's too tired to say so.",
    "A good ending, and a groggy one. Coats go on in a hurry.",
    "They loved it, probably. Ask them tomorrow, after some sleep.",
}

-- The end of every night: how it landed, where the party rests, the goodbyes.
function M:run_tail()
    thoughts.dawn(self)
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
        local safe = (last and last.rest_here) or (loc and (util.contains(loc.setting or {}, "town")
            or util.contains(loc.setting or {}, "tavern") or util.contains(loc.setting or {}, "shop")))
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
    -- A night run past the time agreed at Session Zero is said, and it costs (table_verdicts: Trust and
    -- fun for whoever wanted to be home; the report says so). Round three, A8: "12:24 am (till 10:00 pm)",
    -- then "It ends on a high" and "Same time next week?".
    local late = (self.table_min or 0) > (self.table_planned or 210) + 15
    if late then
        self:say(self:fresh(M.LATE_LINES, "late_night"), "warn", { time = self:clock_text(), agreed = self:clock_text(self.table_planned) })
    end
    if self.dm_ended then
        -- (You closed the book yourself, and the table already reacted: museum_night.end_session.)
    elseif late and pv.finish_high then
        self:say(self:fresh(M.LATE_HIGH, "late_high"), "good")
    elseif self.end_early then
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
    self:say(self:fresh(M.WRAP_LINES, "wrap_system"), "system")
    self:emit({ kind = "done" })
end

return M
