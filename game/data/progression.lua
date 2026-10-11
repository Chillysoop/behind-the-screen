-- Level-ups (M6). The slice starts at level 2. The DM decides when the party levels
-- (after every 2 to 4 nights feels right); the players decide what they become.
-- At level 3 everyone picks a subclass on their own, for their own reasons: who they
-- are as a player (archetype), what they've enjoyed (their nights so far) and the
-- story (seeds that nudge them). Data only: tune freely. The model is
-- game/model/progression.lua.
--
-- arch:   how much each archetype wants this subclass (primary counts 2/3, secondary 1/3).
-- meters: which nights pull toward it: a player's average of these session meters,
--         above or below 50, counts a little.
-- why:    what the DM hears about the pick, by the biggest reason. {name}, {char}, {seed}.

return {
    START_LEVEL = 2,
    MAX_LEVEL = 4,
    READY_AFTER = 2,         -- nights at a level before levelling feels earned
    OVERDUE_AFTER = 4,       -- nights at a level before the table starts asking
    OVERDUE_INVESTMENT = 2,  -- what power gamers and butt-kickers lose each week it's overdue
    PICK_INVESTMENT = 5,     -- the level-3 pick is a big table moment
    NUDGED_INVESTMENT = 3,   -- more when a seed they cared about led to it
    ASI_INVESTMENT = 3,      -- level 4
    SEED_PLANTED = 0.2,      -- nudge from a planted seed (times its nudge weight)
    SEED_PAID = 0.8,         -- nudge from a seed that paid off
    SEED_HYPED = 0.1,        -- per theory you encouraged in the chat
    SEED_EDGE = 0.2,         -- a seed can lift a subclass at most this far past the best other option:
                             -- it can make it the favourite (about 3 in 4) but never a sure thing (M7)
    HISTORY = 0.35,          -- weight of their meter history
    TEMPERATURE = 0.2,       -- people aren't spreadsheets: close calls can go either way
    FLOOR = 0.25,            -- archetype or seed pull a subclass needs to be considered...
    HIST_FLOOR = 0.12,       -- ...or this much pull from the nights they've had

    subclasses = {
        champion = {
            arch = { butt_kicker = 1.0, power_gamer = 0.7 }, meters = { "challenge" },
            why = { arch = "{name} wants bigger crits. Obviously.",
                    hist = "All those hard fights left {char} wanting to hit harder.",
                    seed = "After {seed}, {char} wants to be the best fighter in any room." },
        },
        banner_captain = {
            arch = { tactician = 1.0, casual = 0.4, storyteller = 0.3 }, meters = { "social" },
            why = { arch = "{name} likes keeping the whole party standing.",
                    hist = "{char} has been the one calling the shots in every fight.",
                    seed = "{seed} stuck with {char}. He wants to lead the way she did." },
        },
        spellguard = {
            arch = { power_gamer = 1.0, explorer = 0.3 }, meters = { "reward" },
            why = { arch = "{name} wants a sword AND spells. More numbers.",
                    hist = "All that magic loot gave {char} ideas.",
                    seed = "{seed} got {char} thinking about magic and steel." },
        },
        thief = {
            arch = { explorer = 1.0, instigator = 0.6 }, meters = { "reward" },
            why = { arch = "{name} wants to climb everything and pocket the rest.",
                    hist = "{char} has been sneaking ahead every chance she gets.",
                    seed = "{seed} called to {char}. She wants to run those rooftops." },
        },
        silvertongue = {
            arch = { method_actor = 1.0, instigator = 0.6 }, meters = { "social", "spotlight" },
            why = { arch = "Of course {name} picked the talker. {char} could sell sand in a desert.",
                    hist = "All those conversations with every NPC in town paid off.",
                    seed = "{seed} taught {char} that the right words open any door." },
        },
        ambusher = {
            arch = { butt_kicker = 1.0, tactician = 0.7, power_gamer = 0.4 }, meters = { "challenge" },
            why = { arch = "{name} wants to strike first.",
                    hist = "{char} loves starting fights on her own terms.",
                    seed = "{seed} taught {char} a thing or two about watching from the trees." },
        },
        life = {
            arch = { tactician = 0.8, casual = 0.5 }, meters = { "challenge" },
            why = { arch = "{name} just wants everyone to make it home.",
                    hist = "After all those close fights and all those heals, {char} leans into it.",
                    seed = "{seed} stayed with {char}. He wants to heal like they do." },
        },
        hearth = {
            arch = { casual = 1.0, method_actor = 0.4 }, meters = { "social" },
            why = { arch = "{name} wants to look after everyone, snacks included.",
                    hist = "{char} has been the warm heart of the party all along.",
                    seed = "{seed} meant something to {char}. He wants to keep the fires lit." },
        },
        mischief = {
            arch = { instigator = 1.0, method_actor = 0.6 }, meters = { "spotlight" },
            why = { arch = "{name} wants to cause a little chaos.",
                    hist = "{char} has been getting up to more trouble every week.",
                    seed = "{seed} won {char} over. Mischief it is." },
        },
        evoker = {
            arch = { butt_kicker = 1.0, power_gamer = 0.9 }, meters = { "challenge" },
            why = { arch = "{name} wants to blow things up.",
                    hist = "All those fights taught {char} to hit hard.",
                    seed = "{seed} made {char} want spells that can't be swallowed." },
        },
        wayfinder = {
            arch = { explorer = 1.0, storyteller = 0.4 }, meters = { "story" },
            why = { arch = "{name} wants to see what's over the next hill.",
                    hist = "Every ruin and mystery made {char} want to go further.",
                    seed = "{seed} sent {char} down a new path." },
        },
        mirror_mage = {
            arch = { storyteller = 0.7, method_actor = 0.8, instigator = 0.4 }, meters = { "story", "social" },
            why = { arch = "{name} loves a trick and a big reveal.",
                    hist = "{char} has talked her way through every scene so far.",
                    seed = "{seed}: {char} is following her sister's footsteps." },
        },
    },
}
