-- Level-ups (M6). The slice starts at level 2. The DM decides when the party levels
-- (after every 2 to 4 nights feels right); the players decide what they become.
-- At level 3 everyone picks a subclass on their own, for their own reasons: who they
-- are as a player (archetype) and what they've enjoyed (their nights so far). Data
-- only: tune freely. The model is game/model/progression.lua.
--
-- arch:   how much each archetype wants this subclass (primary counts 2/3, secondary 1/3).
-- meters: which nights pull toward it: a player's average of these session meters,
--         above or below 50, counts a little.
-- why:    what the DM hears about the pick, by the biggest reason. {name}, {char}.

return {
    START_LEVEL = 2,
    MAX_LEVEL = 4,
    READY_AFTER = 2,         -- nights at a level before levelling feels earned
    OVERDUE_AFTER = 4,       -- nights at a level before the table starts asking
    OVERDUE_INVESTMENT = 2,  -- what power gamers and butt-kickers lose each week it's overdue
    PICK_INVESTMENT = 5,     -- the level-3 pick is a big table moment
    ASI_INVESTMENT = 3,      -- level 4
    HISTORY = 0.35,          -- weight of their meter history
    TEMPERATURE = 0.2,       -- people aren't spreadsheets: close calls can go either way
    FLOOR = 0.25,            -- archetype pull a subclass needs to be considered...
    HIST_FLOOR = 0.12,       -- ...or this much pull from the nights they've had

    subclasses = {
        champion = {
            arch = { butt_kicker = 1.0, power_gamer = 0.7 }, meters = { "challenge" },
            why = { arch = "{name}: \"Bigger crits. Obviously.\"",
                    hist = "{name}: \"After all those hard fights? I want to hit harder.\"" },
        },
        banner_captain = {
            arch = { tactician = 1.0, casual = 0.4, storyteller = 0.3 }, meters = { "social" },
            why = { arch = "{name}: \"Somebody has to keep this lot standing.\"",
                    hist = "{name}: \"I've been calling the shots in every fight anyway.\"" },
        },
        spellguard = {
            arch = { power_gamer = 1.0, explorer = 0.3 }, meters = { "reward" },
            why = { arch = "{name}: \"A sword AND spells. More numbers.\"",
                    hist = "{name}: \"All that magic loot gave me ideas.\"" },
        },
        thief = {
            arch = { explorer = 1.0, instigator = 0.6 }, meters = { "reward" },
            why = { arch = "{name}: \"Climb everything, pocket the rest.\"",
                    hist = "{name}: \"I've been sneaking ahead every chance I get. Might as well be good at it.\"" },
        },
        silvertongue = {
            arch = { method_actor = 1.0, instigator = 0.6 }, meters = { "social", "spotlight" },
            why = { arch = "{name}: \"The talker, obviously. {char} could sell sand in a desert.\"",
                    hist = "{name}: \"All that talking to every NPC in town? It's paying off.\"" },
        },
        ambusher = {
            arch = { butt_kicker = 1.0, tactician = 0.7, power_gamer = 0.4 }, meters = { "challenge" },
            why = { arch = "{name}: \"I strike first.\"",
                    hist = "{name}: \"Fights start when I say so.\"" },
        },
        life = {
            arch = { tactician = 0.8, casual = 0.5 }, meters = { "challenge" },
            why = { arch = "{name}: \"Everyone makes it home. That's the job.\"",
                    hist = "{name}: \"After all those close fights and all those heals? I'm leaning into it.\"" },
        },
        hearth = {
            arch = { casual = 1.0, method_actor = 0.4 }, meters = { "social" },
            why = { arch = "{name}: \"I look after everyone. Snacks included.\"",
                    hist = "{name}: \"{char}'s been holding this party together all along.\"" },
        },
        mischief = {
            arch = { instigator = 1.0, method_actor = 0.6 }, meters = { "spotlight" },
            why = { arch = "{name}: \"A little chaos. For fun.\"",
                    hist = "{name}: \"{char} gets into more trouble every week. This fits.\"" },
        },
        evoker = {
            arch = { butt_kicker = 1.0, power_gamer = 0.9 }, meters = { "challenge" },
            why = { arch = "{name}: \"I want to blow things up.\"",
                    hist = "{name}: \"All those fights taught me to hit hard.\"" },
        },
        wayfinder = {
            arch = { explorer = 1.0, storyteller = 0.4 }, meters = { "story" },
            why = { arch = "{name}: \"What's round the next corner? I need to know.\"",
                    hist = "{name}: \"Every mystery we opened made me want to go further.\"" },
        },
        mirror_mage = {
            arch = { storyteller = 0.7, method_actor = 0.8, instigator = 0.4 }, meters = { "story", "social" },
            why = { arch = "{name}: \"Tricks. Big reveals. Yes.\"",
                    hist = "{name}: \"{char}'s talked her way through every scene so far.\"" },
        },
    },
}
