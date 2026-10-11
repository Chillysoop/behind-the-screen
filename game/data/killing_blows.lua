-- The killing blow (M8, B4): when a boss or a villain falls, the DM can hand the final hit to a
-- player, who describes it. The lines are the player's, in character, per class; arch flavours
-- a line for one kind of player (the archetypes in game/data/archetypes.lua). Drafts: review
-- them like the dialogue. Fill-ins: {boss} the one who falls, {char} the hero.

return {
    -- The card's numbers: the Spotlight it's worth, scaled up by the villain's Grudge (B6), and
    -- the window the fairness check looks back over (sessions).
    SPOTLIGHT = 12,
    FUN = 6,
    WINDOW = 3,

    fighter = {
        { "One swing. I put everything into it. {boss} doesn't get up." },
        { "I drop my shield, two hands on the sword, and bring it down like a felled tree.", arch = "butt_kicker" },
        { "I wait for the opening I've been setting up for three rounds. There it is.", arch = "tactician" },
        { "I say his village's name. Then I end it.", arch = "method_actor" },
        { "Shield bash, spin, and the pommel to the jaw. Done.", arch = "butt_kicker" },
        { "I don't say anything. I just nod, once, and step in.", arch = "storyteller" },
        { "Low feint, high cut. Textbook. I've practised that one in the yard.", arch = "tactician" },
        { "I catch the blade on my gauntlet, step inside, and that's the end of {boss}.", arch = "power_gamer" },
        { "I yell. Really loud. And then I hit {boss} really hard.", arch = "casual" },
        { "Is it okay if I kick them off the edge? I'm kicking them off the edge.", arch = "instigator" },
        { "Brannoc leans on his sword afterwards and lets himself breathe for the first time all night." },
        { "I offer {boss} a hand up. They swing at me. I don't offer twice." },
    },
    rogue = {
        { "I'm not there. Then I'm behind {boss}. Then it's over." },
        { "One knife, thrown from the rafters, while everyone's looking the other way.", arch = "instigator" },
        { "I whisper 'you dropped this' and hand {boss} their own coin purse. Then the dagger.", arch = "method_actor" },
        { "Sneak attack, obviously. I've been counting their turns.", arch = "tactician" },
        { "I slide between their legs, come up behind, and that's that.", arch = "butt_kicker" },
        { "I take the key off their belt before they even hit the floor.", arch = "power_gamer" },
        { "Pip doesn't gloat. Pip just wipes the knife and says 'well'.", arch = "storyteller" },
        { "I wink at the crowd. There is no crowd. I wink anyway.", arch = "casual" },
        { "Two daggers, one each side. Very neat. Very quiet." },
        { "I trip {boss} with the rug. The rug did most of the work, honestly.", arch = "instigator" },
        { "From the shadows: 'That's for Lowmarket.'", arch = "method_actor" },
        { "I cut the rope. The chandelier does the rest.", arch = "explorer" },
    },
    cleric = {
        { "The relic flares, and {boss} falls back from the light and doesn't rise." },
        { "I bring the mace down with a prayer on my lips. A short one.", arch = "butt_kicker" },
        { "Sacred Flame, point blank. 'Go and rest.'", arch = "method_actor" },
        { "I say the old words over them before the end, so they're not alone.", arch = "storyteller" },
        { "Guiding Bolt, and I call the angle so Pip gets advantage on the next one. There's no next one.", arch = "tactician" },
        { "I don't swing. I just stand there, glowing, until {boss} gives up. Then I swing.", arch = "instigator" },
        { "Oswin sits down afterwards, very tired, and pours tea. Nobody knows where the tea came from.", arch = "casual" },
        { "One spell slot left. I spend it. Worth it.", arch = "power_gamer" },
        { "The light goes out of {boss}'s eyes, and comes back into the room." },
        { "My mace, my god, and a very firm opinion. In that order." },
        { "I heal Brannoc first, then deal with {boss}. Priorities.", arch = "tactician" },
        { "For the burned temple. For all of it.", arch = "method_actor" },
    },
    wizard = {
        { "Fire Bolt, right where I said it would go. I did the maths." },
        { "I don't even look up from my notes. Magic Missile. Three darts. Done.", arch = "power_gamer" },
        { "I spoke the word Ilsa taught me. I didn't know it did that.", arch = "storyteller" },
        { "I point dramatically. Then I remember the spell. Then I point again, and it works.", arch = "instigator" },
        { "Shatter, and everything in the room, including {boss}, goes very quiet.", arch = "butt_kicker" },
        { "I've been holding this one back all fight. Now.", arch = "tactician" },
        { "Thessaly adjusts her glasses. 'Fascinating. Goodbye.'", arch = "method_actor" },
        { "The spell goes off a little bigger than planned. Nobody mention the ceiling.", arch = "casual" },
        { "I write {boss}'s name in the margin of my spellbook and cross it out.", arch = "storyteller" },
        { "A single blue flame, very small, very precise. That's all it took." },
        { "I counted their weak points. They had one. I found it.", arch = "explorer" },
        { "Ray of Frost, and {boss} shatters like a dropped teacup." },
    },
}
