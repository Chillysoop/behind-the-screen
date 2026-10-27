-- Standalone streamlined campaign. No prep economy, decaying needs or weekly
-- maintenance: the human chooses two details, then runs four consequential moments.
-- Serializable data is separate from the temporary SRD battle objects. Reading a
-- snapshot never rolls dice or changes the campaign. Saves can resume any decision.
local data = require "game.data.guided_episodes"
local json = require "game.model.jsonlite"
local dice_mod = require "game.rules.dice"
local battle_mod = require "game.rules.battle"
local party_mod = require "game.rules.party"
local creature = require "game.rules.creature"
local encounter = require "game.rules.encounter"
local ai = require "game.rules.ai"

local M = { VERSION = 1, KIND = "behind_the_screen_guided" }
local PHASES = { prep_focus = true, prep_twist = true, decision = true, result = true,
                 aftermath = true, hook = true, complete = true }

local function copy(v)
    if type(v) ~= "table" then return v end
    local o = {}
    for k, x in pairs(v) do o[k] = copy(x) end
    return o
end
local function find(list, id)
    for _, v in ipairs(list or {}) do if v.id == id then return v end end
end
local function ep(s) return data.episodes[s.episode] end
local function line(s, text)
    return (text or ""):gsub("{hero}", data.players[s.focus or "mara"].char)
end
local function apply(s, flags)
    for k, v in pairs(flags or {}) do s.flags[k] = v end
end
local function add_history(s, title, text, kind)
    local h = { episode = s.episode, scene_index = s.scene_index, title = title, text = text, kind = kind or "moment" }
    s.history[#s.history + 1] = h
    return h
end
local function roll(s, def)
    local d = dice_mod.new(s.rng)
    local n = d:d20(0)
    s.rng = d.rng.s
    return { label = data.players[def.who].char .. ": " .. def.skill, who = def.who, skill = def.skill,
             d20 = n, modifier = def.modifier, total = n + def.modifier, dc = def.dc,
             success = n + def.modifier >= def.dc }
end

local function current_scene(s)
    local base = ep(s).scenes[s.scene_index]
    local sc = copy(base.by_focus and base.by_focus[s.focus] or base.by_twist and base.by_twist[s.twist] or base)
    -- A successful hidden pursuit needs no rescue or falsified result. Its genuine
    -- die is kept; the live call becomes how to celebrate it instead.
    if sc.preview_policy and s.pending_roll and s.pending_roll.success then
        sc.title = "A catch worth describing"
        sc.text = "Pip makes the rooftop leap and catches the courier carrying Ilsa's ward page. The die behind your screen is a real success. The interesting call is whose voice gets to describe it."
        sc.options = {
            sc.options[1],
            { id = "describe", title = "Let Jess describe the catch", body = "Keep the successful roll. Give Jess the last detail of Pip's rooftop stunt.",
              success = { text = "Jess describes Pip catching the courier by his expensive scarf. The ward page is safe, and the scarf becomes a running joke.",
                          flags = { ward_page = true, fair_roll = true, scarf_joke = true },
                          reaction = { key = "jess", text = "Pip invoices him for the scarf. Professional expenses.", pose = "cheer" } } },
        }
    end
    -- Earlier choices return in the scene itself, and sometimes in its declared
    -- stakes. These are direct callbacks to saved facts, not hidden modifiers.
    if sc.id == "chapel_entry" then
        local proof = find(sc.options, "proof")
        if s.flags.biscuit then
            sc.text = "Biscuit trots beneath the chapel altar and returns with Tobin, who recognizes his old companion. The bell-ringer is still afraid of Kessrick, but the dog has made the introduction. How do you play his fear?"
            local patience = find(sc.options, "patience")
            patience.body = "Biscuit has already earned his trust. Oswin treats Tobin's hands without losing time to reassurance."
            patience.success = { text = "Biscuit curls up beside Tobin while Oswin tends his hands. The bell-ringer trusts the friends who brought his dog home and offers to guide them before the scouts arrive.",
                flags = { tobin_ally = true }, reaction = { key = "sam", text = "Biscuit did the difficult part. Good dog.", pose = "cheer" } }
        end
        if s.incoming_hook == "lantern" then
            proof.check.dc = 10
            proof.body = "The lantern led you straight to Tobin. Wren's arrival reassures him: Persuasion +3, DC 10. A miss gets the map but not his company."
        elseif s.incoming_hook == "scout" then
            proof.check.dc = 10
            proof.body = "The scout's stolen chapel token proves the party is following his enemies. Persuasion +3, DC 10. A miss gets the map but not his company."
        end
    elseif sc.id == "two_witnesses" then
        if s.incoming_hook == "scriptorium" then
            sc.board, sc.npc = "ilsa_room", "npc_corin"
            sc.text = "Corin spreads Ilsa's annotated map across her old desk. Madame Sable arrives with the key receipt. Each fears the other will use the information badly. The party proposes comparing them. How do you frame the meeting?"
        end
        if s.flags.wren_trust then
            sc.text = sc.text .. " Wren vouches for the party: they listened when she needed help."
        end
    elseif sc.id == "pip_debt" and (s.flags.pip_friend or s.flags.pip_owes_wren) then
        sc.text = sc.text .. " Wren waits by the door, returning the kindness from your first night."
    elseif sc.id == "ilsa_letter" and s.flags.ilsa_promise then
        sc.text = sc.text .. " The promise is underlined twice, just as Mara established at the Kettle."
    elseif sc.id == "ready_for_tower" then
        if s.flags.ren_ally then
            local fight = find(sc.options, "intercept")
            fight.body = "Ren repays the shelter you gave him by drawing the scout away. The party fights one tough escort for Vask's orders."
            fight.battle = { foes = { "tough" }, names = { "Wolf escort" }, sprites = { "tough" } }
            fight.success.text = "Ren draws the scout away, repaying the party's kindness. They take Vask's orders from the escort: he intends to flee through the bell loft if the ward breaks."
        end
        if s.flags.tobin_ally then
            local tail = find(sc.options, "tail")
            tail.check.dc = 12
            tail.body = "Tobin shows Pip a quiet bell-keeper's path. Stealth +5, DC 12. Success finds the side entrance; a miss warns Vask."
        end
    elseif sc.id == "vask_bargain" then
        if s.flags.vask_escape_known then
            local answer = find(sc.options, "answer")
            answer.check.dc = 12
            answer.body = "The courier's orders exposed Vask's escape plan. Persuasion +4, DC 12. Success wins surrender; a miss sends him fleeing."
        end
        if s.flags.pip_signet then sc.text = sc.text .. " Jess points at the signet Pip promised to bring Sable." end
    elseif sc.id == "town_chorus" then
        if s.flags.town_chorus then
            sc.text = "The ridiculous chorus from Gus's harvest supper rises through the tower windows. Millbrook remembered every word. Vask orders them silent, but nobody below can hear him. What do you do with the moment?"
        elseif s.flags.town_ready then
            sc.text = "The neighbors the party warned last Thursday gather under Wren's lantern. Their bell song rises through the windows. Vask orders them silent, but nobody below can hear him. What do you do with the moment?"
        end
    elseif sc.id == "last_note" then
        if s.flags.ilsa_last_line then
            sc.text = "Thessaly sings the line Mara wrote into Ilsa's letter. The hush breaks. Seven bells wait above Millbrook, and wolf-horns answer from the hills. The party has earned this ending. What do you give the final moment?"
        elseif s.flags.theory_true then
            sc.text = "The party reverses the song, exactly as Jess guessed last Thursday. The hush breaks. Seven bells wait above Millbrook, and wolf-horns answer from the hills. What do you give the final moment?"
        end
    end
    -- A warning that was actually earned changes a later confrontation. Its cost
    -- is explicit on the offered card, never an unseen satisfaction penalty.
    if s.episode == 4 and s.scene_index == 1 then
        if s.incoming_hook == "side_door" then
            sc.text = "The copied key turns in the side door. The party slips into the bell-keeper's passage and meets a surprised guard. He has not raised the alarm. How do you handle him?"
            for _, o in ipairs(sc.options) do
                if o.id == "guard_bluff" then
                    o.check.dc = 11
                    o.body = "Your quiet entrance makes Pip's inspection plausible. Deception +3, DC 11. A miss sends the guard upstairs."
                end
            end
        elseif s.flags.tower_alert then
            sc.text = "The party arrives on the front steps. Warnings from earlier nights have reached Vask: his guard is waiting. The copied key still opens the lower door. How do you handle the guard?"
            for _, o in ipairs(sc.options) do
                if o.id == "guard_bluff" then
                    o.check.dc = 15
                    o.body = "Vask was warned earlier. Deception +3, DC 15. Success wins the guard's help; a miss sends him upstairs."
                end
            end
        end
    end
    return sc
end

local function enter_decision(s)
    s.phase, s.result, s.pending_roll = "decision", nil, nil
    local sc = current_scene(s)
    if sc.preview_check then s.pending_roll = roll(s, sc.preview_check) end
end

local function actor_id(c)
    return type(c) == "table" and c.guided_id or nil
end

local function run_battle(s, def)
    local dice = dice_mod.new(s.rng)
    local events = {}
    local function capture(_, ev)
        if ev.kind == "round" or ev.kind == "turn" or ev.kind == "initiative" or ev.kind == "zone" then return end
        local e = { kind = ev.kind, who = actor_id(ev.who or ev.caster), att = actor_id(ev.att),
                    tgt = actor_id(ev.tgt or ev.target), src = actor_id(ev.src), name = ev.name or ev.weapon }
        for _, k in ipairs({ "amount", "hp", "hp_max", "hit", "crit", "roll", "total", "ac", "dc", "ok", "slot" }) do
            local v = ev[k]
            if type(v) == "number" or type(v) == "boolean" then e[k] = v end
        end
        if ev.path then
            e.path = {}
            for i, p in ipairs(ev.path) do e.path[i] = { p[1], p[2] } end
        end
        events[#events + 1] = e
    end
    local b = battle_mod.new({ dice = dice, ai = ai, max_rounds = 20, on_event = capture,
        hooks = { before_pc_death = function() return "stable" end } })
    b.gentle_deaths = true
    local pcs = party_mod.build(s.level, s.subclasses)
    local foes = {}
    for _, c in ipairs(pcs) do c.guided_id = c.player end
    for i, id in ipairs(def.foes) do
        local c = creature.new_monster(id)
        c.guided_id = "foe_" .. i
        c.name = def.names and def.names[i] or c.name
        foes[#foes + 1] = c
    end
    encounter.place(b, pcs, foes, 30)
    local actors, ps, fs = {}, {}, {}
    for _, c in ipairs(pcs) do
        local p = { id = c.player, key = c.player, name = c.name, class = c.class, sprite = c.class,
                    x = c.x, y = c.y, hp = c.hp, hp_max = c.hp_max }
        ps[#ps + 1], actors[#actors + 1] = p, copy(p)
    end
    for i, c in ipairs(foes) do
        local f = { id = c.guided_id, name = c.name, sprite = def.sprites and def.sprites[i] or "tough",
                    x = c.x, y = c.y, hp = c.hp, hp_max = c.hp_max }
        fs[#fs + 1], actors[#actors + 1] = f, copy(f)
    end
    encounter.prebuff(b, pcs)
    local result = b:run()
    s.rng = dice.rng.s
    -- Replay the opening and the decisive ending, keeping every collapse. The full
    -- battle resolves once; rendering these highlights cannot change the result.
    local highlights = {}
    for i, e in ipairs(events) do
        if i <= 10 or i > #events - 10 or e.kind == "down" or e.kind == "death" then
            if #highlights < 24 then highlights[#highlights + 1] = e end
        end
    end
    local won = result.winner == "party"
    local summary = won and "The party wins the encounter." or "The party falls back; the story continues with the stated cost."
    summary = summary .. " " .. result.rounds .. " rounds, resolved with the game's combat rules."
    return { winner = result.winner, rounds = result.rounds, party = ps, foes = fs, actors = actors,
             events = highlights, summary = summary, pc_downs = result.pc_downs,
             final_hp = (function() local r = {}; for _, p in ipairs(result.pcs) do r[p.class] = math.max(0, p.hp) end; return r end)() }, won
end

function M.new(seed)
    seed = tonumber(seed) or 20261027
    if seed ~= seed or seed == math.huge or seed == -math.huge then seed = 20261027 end
    seed = math.floor(math.abs(seed)) % 2147483646
    if seed < 1 then seed = 1 end
    return { version = M.VERSION, kind = M.KIND, seed = seed, rng = seed, episode = 1, scene_index = 1,
             phase = "prep_focus", level = 2, focus = nil, twist = nil, flags = {}, history = {},
             choices = {}, episodes = {}, keepsakes = {}, subclasses = {}, result = nil }
end

local function finish_episode(s)
    local e = ep(s)
    local rec = { episode = s.episode, title = e.title, focus = s.focus, twist = s.twist, moments = {} }
    for _, h in ipairs(s.history) do
        if h.episode == s.episode and h.kind == "moment" then rec.moments[#rec.moments + 1] = copy(h) end
    end
    s.episodes[s.episode] = rec
    s.keepsakes[#s.keepsakes + 1] = copy(e.keepsake)
    s.milestone = nil
    if s.episode == 2 then
        s.level = 3
        for _, key in ipairs(data.order) do
            local p = data.players[key]
            s.subclasses[p.class] = p.subclass
        end
        s.milestone = "Level 3! Dev chooses Champion, Jess chooses Thief, Sam chooses Life Domain, and Mara chooses Evoker. Your friends make their own builds."
    elseif s.episode == 4 then
        s.level = 4
        s.milestone = "Level 4! The party grows together. Their new strength belongs to the next chapter."
    end
    s.phase = "aftermath"
end

function M.choose(s, id)
    if type(s) ~= "table" or not PHASES[s.phase] then return nil, "This campaign is not ready for a choice." end
    if type(id) ~= "string" then return nil, "Choose one of the offered options." end
    local options
    if s.phase == "prep_focus" then options = ep(s).focus
    elseif s.phase == "prep_twist" then options = ep(s).twists
    elseif s.phase == "hook" then options = ep(s).hooks
    elseif s.phase == "decision" then options = current_scene(s).options
    else return nil, "There is no choice on this screen." end
    local o = find(options, id)
    if not o then return nil, "That option is not available here." end
    local picked_phase = s.phase
    s.choices[#s.choices + 1] = { episode = s.episode, scene_index = s.scene_index, phase = s.phase, id = id }
    if picked_phase == "prep_focus" then
        s.focus, s.phase = id, "prep_twist"
    elseif picked_phase == "prep_twist" then
        s.twist = id
        enter_decision(s)
    elseif picked_phase == "hook" then
        s.incoming_hook, s.incoming_callback = id, o.callback
        s.flags[o.flag] = true
        s.episodes[s.episode].hook = id
        s.episode, s.scene_index, s.phase = s.episode + 1, 1, "prep_focus"
        s.focus, s.twist, s.result, s.pending_roll, s.milestone = nil, nil, nil, nil, nil
    else
        local sc = current_scene(s)
        local success, test, battle = true, nil, nil
        if o.check then test = roll(s, o.check); success = test.success
        elseif o.battle then battle, success = run_battle(s, o.battle)
        elseif sc.preview_policy and s.pending_roll then
            test = copy(s.pending_roll)
            success = id == "honor" and test.success or id ~= "honor"
        end
        local outcome = copy((success and o.success) or o.failure or o.success)
        apply(s, outcome.flags)
        local text = line(s, outcome.text)
        if sc.clue then
            s.flags["clue_" .. sc.clue.id] = true
            -- The narrative result already contains the clue. The saved fact gives
            -- summaries a reliable source independent of roll or scene variant.
            s.last_clue = copy(sc.clue)
        end
        local reactions = {}
        if outcome.reaction then reactions[#reactions + 1] = outcome.reaction end
        if test and not sc.preview_policy and s.flags.open_dice_promise and not s.flags.open_promise_kept then
            s.flags.open_promise_kept = true
            reactions[#reactions + 1] = { key = "sam", text = "Thanks for keeping that die in the open, like we agreed.", pose = "lean" }
        end
        if sc.preview_policy and id == "cook" then
            s.flags.open_dice_promise = true
        end
        local entry = add_history(s, sc.title, text)
        s.result = { title = success and "That becomes your story" or "A setback worth keeping", text = text,
                     reactions = reactions, roll = test, battle = battle, choice = id, success = success,
                     board = sc.board, npc = sc.npc, entry = copy(entry) }
        s.phase = "result"
    end
    return true
end

function M.advance(s)
    if type(s) ~= "table" then return nil, "No campaign is open." end
    if s.phase == "result" then
        if s.scene_index == #ep(s).scenes then finish_episode(s)
        else s.scene_index = s.scene_index + 1; enter_decision(s) end
        return true
    elseif s.phase == "aftermath" then
        s.phase = s.episode == #data.episodes and "complete" or "hook"
        return true
    end
    return nil, "Choose an option before continuing."
end

local function recap(s)
    if s.episode == 1 then return "Millbrook's bells have fallen silent. Four friends are about to find out why." end
    local prev = s.episodes[s.episode - 1]
    if not prev then return "" end
    local last = prev.moments[#prev.moments]
    return "Last Thursday: " .. (last and last.text or prev.title)
end
local function ending_text(s)
    local text = s.result and s.result.text or "The bells ring again."
    if s.flags.pip_signet then
        text = text .. (s.flags.signet and " Pip returns the signet; Sable burns her debt page." or " Pip's bargain remains open; Jess already has ideas for another adventure.")
    end
    if s.flags.biscuit then text = text .. " Biscuit has his own place at the Kettle."
    elseif s.flags.biscuit_home then text = text .. " Biscuit is waiting by Gus's fire." end
    return text
end

function M.snapshot(s)
    local e = ep(s)
    local snap = { phase = s.phase, episode = s.episode, scene_index = s.scene_index, title = e.title,
        kicker = "THURSDAY " .. s.episode .. " OF " .. #data.episodes, text = "", cards = {},
        progress = "Thursday " .. s.episode .. " / " .. #data.episodes, party = {}, reactions = {},
        history = copy(s.history), recap = recap(s), board = e.board, npc = nil,
        keepsakes = copy(s.keepsakes), milestone = s.milestone, focus = s.focus, twist = s.twist }
    for _, key in ipairs(data.order) do
        local p = copy(data.players[key])
        p.key, p.level = key, s.level
        if s.level < 3 then p.subclass, p.subclass_name = nil, nil end
        snap.party[#snap.party + 1] = p
    end
    local opts
    if s.phase == "prep_focus" then
        snap.title = "Whose story gets a moment?"
        snap.text = e.intro .. "\n\n" .. e.objective
        opts = e.focus
        snap.progress = "Thursday " .. s.episode .. " / 4  |  Your first detail"
    elseif s.phase == "prep_twist" then
        snap.title = "Add one thing that feels like you"
        snap.text = "Tonight already has a beginning, a middle and an ending. " .. data.players[s.focus].name .. " gets a personal moment. Choose one surprise, then pull up your screen."
        opts = e.twists
        snap.progress = "Thursday " .. s.episode .. " / 4  |  Your final detail"
    elseif s.phase == "decision" then
        local sc = current_scene(s)
        snap.title, snap.text, snap.board, snap.npc = sc.title, sc.text, sc.board, sc.npc
        if s.scene_index == 1 and s.incoming_callback then snap.text = s.incoming_callback .. "\n\n" .. snap.text end
        if s.pending_roll then snap.roll = copy(s.pending_roll) end
        opts = sc.options
        snap.progress = "Thursday " .. s.episode .. " / 4  |  Moment " .. s.scene_index .. " / 4"
    elseif s.phase == "result" then
        local r = s.result
        snap.title, snap.text, snap.reactions = r.title, r.text, copy(r.reactions)
        snap.board, snap.npc, snap.roll, snap.battle = r.board, r.npc, copy(r.roll), copy(r.battle)
        snap.continue_label = s.scene_index == 4 and "Let the night settle" or "Continue the story"
        snap.progress = "Thursday " .. s.episode .. " / 4  |  Moment " .. s.scene_index .. " / 4"
    elseif s.phase == "aftermath" then
        snap.title = "One more Thursday to remember"
        snap.text = (s.last_clue and s.last_clue.text or "The party has a new story.") .. "\n\n" .. e.keepsake.text
        if s.milestone then snap.text = snap.text .. "\n\n" .. s.milestone end
        snap.reactions = { { key = e.keepsake.from, text = e.keepsake.text, pose = "cheer" } }
        snap.continue_label = s.episode == 4 and "Open the scrapbook" or "Choose next week's opening"
    elseif s.phase == "hook" then
        snap.title = "Where do you leave their thoughts?"
        snap.text = "Choose the opening image for next Thursday. It will be waiting when the party returns."
        opts = e.hooks
    elseif s.phase == "complete" then
        snap.title = "Four Thursdays, one shared story"
        snap.text = ending_text(s)
        snap.recap = "The Silent Bells: your first chapter is complete."
        snap.board = "kettle"
    end
    for _, o in ipairs(opts or {}) do
        local body = o.body
        -- The number shown before the decision is the number used by resolution.
        local tag = o.check and ("d20 +" .. o.check.modifier .. " / DC " .. o.check.dc)
                    or o.battle and "The party takes the fight" or nil
        snap.cards[#snap.cards + 1] = { id = o.id, title = o.title, body = body, tag = tag }
    end
    return snap
end

local function integer(v, low, high)
    return type(v) == "number" and v == math.floor(v) and v >= low and v <= high
end
local function array(t, max)
    if type(t) ~= "table" or #t > max then return false end
    local n = 0
    for k in pairs(t) do if not integer(k, 1, max) then return false end; n = n + 1 end
    return n == #t
end
local function short(v, max) return type(v) == "string" and #v <= max end
local function plain(v, depth, budget)
    budget.n = budget.n + 1
    if budget.n > 16000 or depth > 14 then return false end
    local t = type(v)
    if t == "string" then return #v <= 12000 end
    if t == "number" then return v == v and v ~= math.huge and v ~= -math.huge end
    if t == "boolean" or t == "nil" then return true end
    if t ~= "table" then return false end
    for k, x in pairs(v) do
        if type(k) ~= "string" and type(k) ~= "number" then return false end
        if not plain(x, depth + 1, budget) then return false end
    end
    return true
end

local function valid_roll(r)
    return type(r) == "table" and integer(r.d20, 1, 20) and integer(r.modifier, -10, 20)
        and integer(r.dc, 1, 40) and r.total == r.d20 + r.modifier
        and r.success == (r.total >= r.dc) and data.players[r.who] ~= nil and short(r.label, 160)
end
local function valid_reactions(rs)
    if not array(rs, 4) then return false end
    for _, r in ipairs(rs) do
        if type(r) ~= "table" or not data.players[r.key] or not short(r.text, 600) or not short(r.pose, 30) then return false end
    end
    return true
end
local function valid_battle(b)
    if type(b) ~= "table" or not integer(b.rounds, 1, 20) or not short(b.summary, 600)
        or not (b.winner == "party" or b.winner == "foes" or b.winner == "timeout")
        or not array(b.events, 24) or not array(b.party, 4) or #b.party ~= 4
        or not array(b.foes, 6) or not array(b.actors, 10) then return false end
    for _, group in ipairs({ b.actors, b.party, b.foes }) do
        for _, a in ipairs(group) do
            if type(a) ~= "table" or not short(a.id, 40) or not short(a.name, 120) or not short(a.sprite, 60)
                or not integer(a.x, 1, 24) or not integer(a.y, 1, 16) then return false end
        end
    end
    for _, event in ipairs(b.events) do
        if type(event) ~= "table" or not short(event.kind, 40) then return false end
        if event.path then
            if not array(event.path, 60) then return false end
            for _, p in ipairs(event.path) do
                if not array(p, 2) or #p ~= 2 or not integer(p[1], 1, 24) or not integer(p[2], 1, 16) then return false end
            end
        end
    end
    return true
end

function M.validate(s)
    if type(s) ~= "table" or s.kind ~= M.KIND or s.version ~= M.VERSION then return nil, "This is not a streamlined-edition save." end
    if not plain(s, 0, { n = 0 }) then return nil, "The save contains invalid data." end
    if not integer(s.episode, 1, 4) or not integer(s.scene_index, 1, 4) or not PHASES[s.phase]
        or not integer(s.seed, 1, 2147483646) or not integer(s.rng, 1, 2147483646)
        or not integer(s.level, 2, 4) then return nil, "The save has an invalid position." end
    if type(s.flags) ~= "table" or type(s.subclasses) ~= "table"
        or not array(s.history, 32) or not array(s.choices, 27) or not array(s.episodes, 4)
        or not array(s.keepsakes, 4) then return nil, "The save is missing its story record." end
    if s.result ~= nil and type(s.result) ~= "table" then return nil, "The saved result is invalid." end
    if s.last_clue and (type(s.last_clue) ~= "table" or not short(s.last_clue.id, 80) or not short(s.last_clue.text, 600)) then
        return nil, "The saved clue is invalid."
    end
    if s.milestone and not short(s.milestone, 600) then return nil, "The saved milestone is invalid." end
    for k, v in pairs(s.flags) do
        if not short(k, 80) or not (type(v) == "boolean" or short(v, 80)) then return nil, "A saved consequence is invalid." end
    end
    for _, key in ipairs(data.order) do
        local p = data.players[key]
        if s.subclasses[p.class] and s.subclasses[p.class] ~= p.subclass then return nil, "A saved character build is invalid." end
    end
    local settled = s.phase == "aftermath" or s.phase == "hook" or s.phase == "complete"
    local completed = s.episode - 1 + (settled and 1 or 0)
    local level = (s.episode > 2 or s.episode == 2 and settled) and 3 or 2
    if s.episode == 4 and settled then level = 4 end
    if s.level ~= level or #s.episodes ~= completed or #s.keepsakes ~= completed then
        return nil, "The saved milestones do not match the story."
    end
    if settled and s.scene_index ~= 4 then return nil, "The saved episode ended too early." end
    if (s.phase == "prep_focus" or s.phase == "prep_twist") and s.scene_index ~= 1 then
        return nil, "The saved preparation is out of place."
    end
    if s.episode > 1 then
        local previous_hook = find(data.episodes[s.episode - 1].hooks, s.incoming_hook)
        if not previous_hook or s.incoming_callback ~= previous_hook.callback then return nil, "The saved opening is invalid." end
    end
    for _, h in ipairs(s.history) do
        if type(h) ~= "table" or not integer(h.episode, 1, 4) or not short(h.title, 160) or not short(h.text, 1500) then
            return nil, "A saved memory is invalid."
        end
    end
    for _, c in ipairs(s.choices) do
        if type(c) ~= "table" or not integer(c.episode, 1, 4) or not integer(c.scene_index, 1, 4)
            or not short(c.id, 60) or not (c.phase == "prep_focus" or c.phase == "prep_twist" or c.phase == "decision" or c.phase == "hook") then
            return nil, "A saved choice is invalid."
        end
    end
    for _, r in ipairs(s.episodes) do
        if type(r) ~= "table" or not short(r.title, 160) or not array(r.moments, 4) or #r.moments ~= 4 then
            return nil, "An episode record is invalid."
        end
        for _, h in ipairs(r.moments) do
            if type(h) ~= "table" or not integer(h.episode, 1, 4) or not short(h.title, 160) or not short(h.text, 1500) then
                return nil, "An episode memory is invalid."
            end
        end
    end
    for _, k in ipairs(s.keepsakes) do
        if type(k) ~= "table" or not short(k.id, 80) or not short(k.name, 160) or not short(k.text, 600) or not data.players[k.from] then
            return nil, "A saved keepsake is invalid."
        end
    end
    if s.phase ~= "prep_focus" and not find(ep(s).focus, s.focus) then return nil, "The saved spotlight is missing." end
    if s.phase ~= "prep_focus" and s.phase ~= "prep_twist" and not find(ep(s).twists, s.twist) then
        return nil, "The saved surprise is missing."
    end
    if (s.phase == "result" or s.phase == "aftermath" or s.phase == "complete") and
        (type(s.result) ~= "table" or not short(s.result.text, 2000) or not short(s.result.title, 160)
         or not valid_reactions(s.result.reactions) or type(s.result.success) ~= "boolean") then return nil, "The saved result is missing." end
    if s.pending_roll and not valid_roll(s.pending_roll) then return nil, "The saved die is invalid." end
    if s.result and s.result.roll and not valid_roll(s.result.roll) then return nil, "The saved roll is invalid." end
    if s.result and s.result.battle and not valid_battle(s.result.battle) then return nil, "The saved battle is invalid." end
    if s.phase == "decision" and current_scene(s).preview_check and not s.pending_roll then
        return nil, "The saved scene is missing its rolled die."
    end
    if s.phase == "complete" and (s.episode ~= 4 or #s.episodes ~= 4 or not s.flags.bells_awake) then
        return nil, "The ending is incomplete."
    end
    if s.phase == "hook" and (s.episode >= 4 or not s.episodes[s.episode]) then return nil, "The next-week hook is invalid." end
    if s.episode > 1 and not s.episodes[s.episode - 1] then return nil, "The previous episode is missing." end
    local ok = pcall(M.snapshot, s)
    if not ok then return nil, "The saved scene cannot be restored." end
    return true
end

function M.dump(s)
    local ok, why = M.validate(s)
    if not ok then return nil, why end
    return json.encode(s)
end

function M.restore(text)
    if type(text) ~= "string" or #text > 1000000 then return nil, "This save cannot be read." end
    local ok, s = pcall(json.decode, text)
    if not ok then return nil, "This save is damaged or incomplete." end
    local checked, valid, why = pcall(M.validate, s)
    if not checked then return nil, "This save is damaged or incomplete." end
    if not valid then return nil, why end
    return s
end

M.data = data
return M
