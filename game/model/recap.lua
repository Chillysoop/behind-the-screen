-- The session report's recap and verdict (M8, B7; the GDD's "The session report and the
-- scrapbook"). The recap is for the DM only: built from pre-written templates, 4 to 6 variants
-- per kind of event, read off the event log (B1). Three title suggestions; pin a beat to keep it
-- for the scrapbook, cut one to drop it, add a one-line note. The verdict is the Table Score:
-- everyone's Fun, weighted so a great night can't come from delighting three and losing one.
-- Pure Lua.

local util = require "game.model.util"

local M = {}

-- Templates per event kind. {who} the player's name, {char} their hero, {text} the event's own
-- line, {place} where it happened, {boss} the one who fell.
M.TEMPLATES = {
    -- What a scene's goal came to (the story playtest: losing the relic never reached the recap).
    goal = { "{text}" },
    start = { "It started at {place}.", "The night opened at {place}.", "First stop: {place}.",
              "They began at {place}, as planned.", "{place} first, where it all kicked off." },
    crit = { "{char} rolled a natural 20 and the table lost its mind.", "A natural 20 from {char}, right when it counted.",
             "{who}'s die came up 20. Nobody has stopped talking about it.", "{char} landed the roll of the night.",
             "The 20 that {char} rolled will be in the group chat for weeks." },
    fumble = { "{char} rolled a 1. Of course {char} did.", "A natural 1 for {char}, at the worst moment.",
               "{who}'s die betrayed them: a 1.", "{char} found out what a 1 looks like up close." },
    jail = { "{who}'s d20 went to dice jail.", "One d20 is serving time tonight: {who}'s.", "{who} jailed a die. It had it coming.",
             "Dice jail claimed {who}'s d20." },
    down = { "{char} went down, and the table held its breath.", "{char} hit the floor mid-fight.",
             "For a moment it looked bad for {char}.", "{char} dropped, and everyone leaned in." },
    death = { "{text}.", "The table lost {char} tonight.", "{char} didn't make it.",
              "{char}'s story ended tonight." },
    goodbye = { "They said goodbye to {char} properly.", "{char}'s last words got a silence after them.",
                "A wake for {char} at the Kettle.", "{who} gave {char} a send-off nobody will forget." },
    back = { "{char} came back, changed.", "Death didn't keep {char}, but it left a mark.", "{char} is back. Mostly." },
    killing_blow = { "{char} landed the killing blow. {who} described every second of it.", "{text}.",
                     "The final hit went to {char}.", "{who} got to finish it, and did it in style.",
                     "{char} ended the fight." },
    villain_falls = { "{text}.", "The one leading them went down, and the rest lost heart.", "The fight's big name hit the floor." },
    escape = { "{text}.", "The villain got away, and will remember.", "Someone slipped out the back, swearing revenge.",
               "One of them escaped. That's a Grudge now." },
    defeat = { "They lost the fight. {text}", "A defeat, and they lived.", "Not every fight is won: this one wasn't.",
               "They were beaten, and the story kept going." },
    clue = { "They found out: {text}", "They learned something: {text}", "A piece fell into place. {text}",
             "{text}. That changes things." },
    payoff = { "{text}.", "A seed planted weeks ago paid off.", "Something you set up a while back came good.",
               "The payoff landed." },
    theory = { "{text}.", "{who} was right all along, and knows it.", "A theory from the group chat came true.",
               "{who}'s theory? True. Unbearable now." },
    curveball = { "{text}.", "{char} went off the map, as {char} does.", "They didn't do what you planned. {text}.",
                  "A curveball from {who}." },
    stunt = { "{text}.", "{char} pulled off a stunt.", "A flashy opening from {char}.", "{char} showed off, and it worked." },
    joke = { "{text}", "The running joke came back.", "An old joke got another outing.", "They called back the joke." },
    inspiration = { "{text}", "Heroic Inspiration changed hands.", "{who} earned the Inspiration token.",
                    "The Inspiration token went to {who}." },
    new_character = { "{text}", "A new face at the table: {char}.", "{who} brought someone new: {char}.",
                      "{char} joined the party." },
    fail_card = { "{text}", "It went wrong, and well.", "A failure worth remembering: {text}", "{char} failed with style." },
    callout = { "{text}", "Someone asked to see a roll.", "The table noticed something behind the screen.",
                "A callout. Awkward." },
    moment = { "{text}." },
    reputation = { "{text}", "{char} has a reputation now." },
    talk = { "{text}.", "{text}, in your own words." },
    boss_turn = { "{text}" },
    taunt = { "{text}.", "{text}. Nobody's forgotten it." },
    interrupt = { "{text}.", "{text}, and the table cheered." },
    retort = { "{text}.", "{text}. They'd been waiting all night to say it." },
}

-- Title suggestions, by the night's biggest event.
M.TITLES = {
    death = { "The Night We Lost {char}", "{char}'s Last Stand", "Goodbye, {char}" },
    death_back = { "{char} Comes Back", "The Price of Coming Back", "Not Yet, {char}" },
    death_quest = { "The Way Back for {char}", "{char} Falls", "Not the End of {char}" },
    villain_falls = { "The Fall of {boss}", "{char} and the Final Blow", "Down Goes {boss}" },
    killing_blow = { "{char} Finishes It", "The Final Hit", "How {char} Ended It" },
    escape = { "The One That Got Away", "{boss} Runs", "Unfinished Business" },
    defeat = { "A Bad Night in the Vale", "They Lived, Anyway", "The Long Way Home" },
    theory = { "{who} Was Right", "The Theory", "Told You So" },
    payoff = { "It All Comes Back", "The Payoff", "Planted, Harvested" },
    crit = { "The Natural 20", "{char}'s Big Roll", "Twenty" },
    fumble = { "The Natural 1", "{char} and the Die", "One" },
    curveball = { "Off the Map", "{char}'s Bright Idea", "Nobody Planned This" },
    retort = { "{char} Answers", "The Last Word", "Paid in Full" },
    clue = { "What They Found", "The Clue", "A Piece of the Puzzle" },
    moment = { "Thursday at the Kettle", "Another Night in the Vale", "Session {week}" },
}

M.VERDICTS = {
    { 82, "One for the stories" }, { 68, "Great session" }, { 54, "Good session" }, { 40, "Okay" }, { 0, "Rough night" },
}

-- The Table Score: the average Fun pulled toward the unhappiest player, so three delighted
-- players can't carry a night the fourth hated. 0 to 100, and its word.
function M.table_score(funs)
    if #funs == 0 then
        return 0, "Rough night"
    end
    local sum, low = 0, 100
    for _, f in ipairs(funs) do
        sum = sum + f
        low = math.min(low, f)
    end
    local avg = sum / #funs
    local s = 0.6 * avg + 0.4 * low
    for _, v in ipairs(M.VERDICTS) do
        if s >= v[1] then
            return s, v[2]
        end
    end
    return s, "Rough night"
end

local function pick(list, rng)
    return list[rng:int(1, #list)]
end

local function vars_for(campaign, night, e)
    local p = e.who and e.who ~= "party" and campaign:player(e.who)
    local text = e.text or ""
    if e.ev == "clue" then
        text = string.gsub(text, "^They found out: ", "")
    end
    text = string.gsub(text, "[%.!]+$", "")
    return {
        who = p and p.name or "The party", char = p and p.char or "the party", text = text,
        text_lower = util.lower_first and util.lower_first(text) or text,
        boss = night.battle_boss_name and util.capitalize(night.battle_boss_name) or "the villain",
        week = util.int(campaign.week),
    }
end

-- Build the recap for a finished night: { titles = {3}, title = 1, beats = { {kind, text, weight} },
-- note = "", snapshots = {...} }.
-- Drops any beat whose sentence is the opening of another's.
function M.drop_echoes(beats)
    local function stem(t)
        return string.lower((string.gsub(t or "", "[%.!?\"'%s]+$", "")))
    end
    for i = #beats, 1, -1 do
        local a = stem(beats[i].text)
        for j, b in ipairs(beats) do
            if j ~= i and #a > 0 and #stem(b.text) > #a and string.sub(stem(b.text), 1, #a) == a then
                table.remove(beats, i)
                break
            end
        end
    end
    return beats
end

function M.build(campaign, night, rng)
    local beats = {}
    -- Where it started.
    local first = night.scenes and night.scenes[1]
    local loc = first and first.comps and first.comps.location
    if loc and first.terrain then
        table.insert(beats, { kind = "start", weight = 2, order = 0,
                              text = util.sentence_case(util.fill(pick(M.TEMPLATES.start, rng),
                                  { place = loc.short and util.lower_first(loc.short) or util.lower_first(loc.name) })) })
    end
    -- The night's events, biggest first, one per kind (two for moments).
    local evs = {}
    for i, e in ipairs(night.ledger or {}) do
        if e.ev and M.TEMPLATES[e.ev] then
            table.insert(evs, { e = e, i = i })
        end
    end
    table.sort(evs, function(a, b)
        if (a.e.weight or 0) ~= (b.e.weight or 0) then
            return (a.e.weight or 0) > (b.e.weight or 0)
        end
        return a.i < b.i
    end)
    local per, used_text = {}, {}
    local top
    for _, x in ipairs(evs) do
        local e = x.e
        local cap = e.ev == "moment" and 2 or 1
        if (per[e.ev] or 0) < cap and #beats < 6 and not used_text[e.text or e.ev] then
            local tpl = (e.ev == "death" and M.DEATH_BACK[e.outcome or ""]) or pick(M.TEMPLATES[e.ev], rng)
            local text = util.sentence_case(util.fill(tpl, vars_for(campaign, night, e)))
            text = string.gsub(text, "%.%.", ".")
            text = string.gsub(text, "([%.!?]['\"])%.$", "%1")   -- ("hollow.'." from a "{text}." template)
            if not string.find(text, "[%.!?\"']$") then   -- ("'This wall is hollow.'", no extra full stop)
                text = text .. "."
            end
            -- Two events can come out as the same sentence (playtest, October 13: one beat twice).
            if not used_text[text] then
                per[e.ev] = (per[e.ev] or 0) + 1
                used_text[e.text or e.ev] = true
                used_text[text] = true
                top = top or e
                table.insert(beats, { kind = e.ev, weight = e.weight or 3, order = x.i, text = text, who = e.who,
                                      clue = e.clue })
            end
        end
    end
    -- One beat that's the start of another says it twice ("The relic, wrapped in the thief's own
    -- cloak." and the same with what Oswin did next): keep the longer (October 15).
    M.drop_echoes(beats)
    -- In the order they happened.
    table.sort(beats, function(a, b) return a.order < b.order end)
    -- Titles from the biggest event.
    local tk = top and (M.TITLES[top.ev] and top.ev or "moment") or "moment"
    if top and top.ev == "death" and M.DEATH_BACK[top.outcome or ""] then
        tk = top.outcome == "scar" and "death_back" or "death_quest"
    end
    local tv = vars_for(campaign, night, top or {})
    tv.boss = util.title_case(tv.boss)
    -- One name per session (October 15: "Strangers at the Kettle" in prep, "Brannoc Comes Back" on the
    -- report and a third after a click were three names for one night). The name it was planned
    -- under comes first and stays unless the DM picks another, which then names it everywhere.
    local titles = {}
    local beat = campaign.arc_beat and campaign:arc_beat()
    local planned = beat and beat.title and util.title_case(beat.title)
    if planned then
        table.insert(titles, planned)
    end
    for _, t in ipairs(M.TITLES[tk]) do
        local name = util.title_case(util.fill(t, tv))
        if not util.contains(titles, name) then
            table.insert(titles, name)
        end
    end
    return { titles = titles, title = 1, planned = planned, beats = beats, note = "",
             spoken = M.spoken_beats(campaign, night) }
end

-- What the DM says out loud at the start of next session (the session-start recap): the story
-- beats and the big moments, in the DM's voice, past tense. Kept with the recap so the DM's pins
-- and cuts on the report decide what makes it in. {past} is the event's own line in the past
-- tense; {clue} what they found out.
M.SPOKEN = {
    clue = "{clue}", killing_blow = "{past}.", villain_falls = "{past}", escape = "{text}.",
    defeat = "You lost a fight, and lived to tell it.", death = "We lost {char}.", defeat_death = "You lost a fight, and not everyone walked away.", goodbye = "You said goodbye to {char}.",
    new_character = "{past}", crit = "{past}, right when it counted.", retort = "{char} finally got the last word in.",
    theory = "{past}.", payoff = "{text}.", goal = "{text}",
}
M.SPOKEN_CAP = { clue = 2, goal = 3 }
-- A death that didn't stick: the recap says so (the report beat and the spoken line alike).
M.DEATH_BACK = { scar = "{char} died, and came back at a cost.", quest = "{char} fell. There may still be a way back." }

local PAST = { { " lands ", " landed " }, { " rolls ", " rolled " }, { " falls%.", " fell." }, { " falls$", " fell" },
               { " joins ", " joined " }, { " comes true", " came true" }, { " goes down", " went down" },
               { " brings down ", " brought down " }, { " comes ", " came " }, { " cries ", " cried " },
               { " stays ", " stayed " }, { " rolls ", " rolled " }, { " walks ", " walked " } }

local function past(text)
    for _, r in ipairs(PAST) do
        text = string.gsub(text, r[1], r[2])
    end
    return text
end

function M.spoken_beats(campaign, night)
    local out, per = {}, {}
    for i, e in ipairs(night.ledger or {}) do
        local tpl = e.ev and ((e.ev == "death" and M.DEATH_BACK[e.outcome or ""]) or M.SPOKEN[e.ev])
        -- A lost fight that cost a hero isn't "lived to tell it" (October 15).
        if e.ev == "defeat" and (per.death or 0) > 0 then
            tpl = M.SPOKEN.defeat_death
        end
        if tpl and (per[e.ev] or 0) < (M.SPOKEN_CAP[e.ev] or 1) then
            local v = vars_for(campaign, night, e)
            v.past = past(v.text)
            v.clue = string.gsub(e.text or "", "^They found out: ", "")
            local text = util.sentence_case(util.fill(tpl, v))
            text = string.gsub(text, "%.%.", ".")
            text = string.gsub(text, "([%.!?]['\"])%.$", "%1")
            if not string.find(text, "[%.!?\"']$") then
                text = text .. "."
            end
            if #text > 2 then
                per[e.ev] = (per[e.ev] or 0) + 1
                table.insert(out, { kind = e.ev, order = i, weight = e.weight or 3, text = text, clue = e.clue, who = e.who })
            end
        end
    end
    M.drop_echoes(out)
    -- The killing blow says the villain fell; don't say it twice.
    if per.killing_blow and per.villain_falls then
        for i = #out, 1, -1 do
            if out[i].kind == "villain_falls" then
                table.remove(out, i)
            end
        end
    end
    return out
end

-- "Last session: ..." for the start of the night: up to three beats, pinned ones first, then what
-- they found out, then the biggest moments; nothing the DM cut. Nil if there's no last session.
function M.last_session(campaign)
    local log = campaign.session_log or {}
    local entry
    for _, le in ipairs(log) do
        if le.week == campaign.week - 1 then
            entry = le
        end
    end
    local rc = entry and entry.recap
    if not (rc and rc.spoken and #rc.spoken > 0) then
        return nil
    end
    local cut, pinned = {}, {}
    for _, b in ipairs(rc.beats or {}) do
        if b.cut then
            cut[b.order] = true
        elseif b.pinned then
            pinned[b.order] = true
        end
    end
    local pool = {}
    for _, s in ipairs(rc.spoken) do
        if not cut[s.order] then
            table.insert(pool, s)
        end
    end
    -- A clue that came with a handout sticks (game/model/handouts.lua): it leads.
    local handed = require("game.model.handouts").last_week_cards(campaign)
    local function rank(s)
        return (pinned[s.order] and 100 or 0) + ((s.clue and handed[s.clue]) and 60 or 0) + (s.kind == "clue" and 20 or 0)
            + (s.kind == "goal" and 15 or 0) + (s.weight or 0)
    end
    table.sort(pool, function(a, b)
        if rank(a) ~= rank(b) then
            return rank(a) > rank(b)
        end
        return a.order < b.order
    end)
    local picked = {}
    for i = 1, math.min(3, #pool) do
        table.insert(picked, pool[i])
    end
    if #picked == 0 then
        return nil
    end
    table.sort(picked, function(a, b) return a.order < b.order end)
    local parts = {}
    for _, s in ipairs(picked) do
        table.insert(parts, s.text)
    end
    return "Last session: " .. table.concat(parts, " ")
end

-- What last session added to the story, for the card that opens the next one (October 15): the
-- clues they found, in the order they found them (the beats the DM cut stay out). Each
-- { text, clue = its card's id }. Empty in week 1, or when they found nothing. And, second, the
-- biggest thing that happened (a spoken beat: { text, kind, who, weight }), or nil.
function M.last_learned(campaign)
    local entry
    for _, le in ipairs(campaign.session_log or {}) do
        if le.week == campaign.week - 1 then
            entry = le
        end
    end
    local rc = entry and entry.recap
    local out = {}
    if not (rc and rc.spoken) then
        return out
    end
    local cut = {}
    for _, b in ipairs(rc.beats or {}) do
        if b.cut then
            cut[b.order] = true
        end
    end
    local happened = {}
    for _, s in ipairs(rc.spoken) do
        if not cut[s.order] and s.kind == "clue" then
            table.insert(out, { text = s.text, clue = s.clue })
        elseif not cut[s.order] and M.HAPPENED[s.kind] then
            table.insert(happened, s)
        end
    end
    -- The biggest first (a pinned beat leads), then in the order they happened.
    table.sort(happened, function(a, b)
        local pa, pb = (a.weight or 0), (b.weight or 0)
        if pa ~= pb then
            return pa > pb
        end
        return a.order < b.order
    end)
    return out, happened
end

-- What counts as "what happened" on that card: how the night's big moments ended, not a lucky roll.
M.HAPPENED = { killing_blow = true, villain_falls = true, goal = true, escape = true, defeat = true, death = true,
               payoff = true, goodbye = true }

-- The session log (B7): every report, kept with the campaign so the notebook can reopen it.
function M.file(campaign, rep)
    campaign.session_log = campaign.session_log or {}
    local players = {}
    for _, row in ipairs(rep.players or {}) do
        table.insert(players, { key = row.key, name = row.name, char = row.char, fun = row.fun, tier = row.tier,
                                quote = row.quote, why = row.why })
    end
    local entry = { week = rep.week, recap = rep.recap, score = rep.score, verdict = rep.verdict, players = players,
                    headline = rep.headline, snapshots = rep.snapshots }
    for i = #campaign.session_log, 1, -1 do
        if campaign.session_log[i].week == rep.week then
            table.remove(campaign.session_log, i)
        end
    end
    table.insert(campaign.session_log, entry)
    return entry
end

-- The beats that survive: not cut, pinned ones first-class.
function M.kept(recap)
    local out = {}
    for _, b in ipairs(recap and recap.beats or {}) do
        if not b.cut then
            table.insert(out, b)
        end
    end
    return out
end

return M
