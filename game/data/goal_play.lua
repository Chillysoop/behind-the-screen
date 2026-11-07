-- How the heroes play each goal card (the card-led night, October 16: "the players don't play the
-- story card"; none of the 139 stock moves named the scene's goal). A scene's checks come from its
-- goal's approaches first, then the scene type's stock moves (actions.lua); its last roll is the
-- goal's own moment; a player says what they're there to do as the scene starts; and the table's
-- chatter is about what's in front of them. Data only: tune freely.
--
-- Each goal (by card id):
--   intent      what a player says, in character, as the scene starts (who they are: {char})
--   approaches  what the heroes try, as in actions.lua: skill, say (in character), win and lose
--               (the DM's narration), cast = true when it's aimed at the scene's person
--   moment      the scene's last roll: text ({actor_char} steps up) and the skills it can use
--   talk        what the players say out of character, at the table, about it
-- Fill-ins as in actions.lua: {char}, {other_char}, {cast}/{Cast}, {location}, {lead}, {actor_char}.
-- An adventure brings its own goals' entries (game/data/museum/cards.lua goal_play, added by
-- adventure.enter); a goal with no entry plays from `default`, with {goal} its name in lower case.

return {
    default = {
        intent = { "We're here to {goal}. Let's not get distracted.", "Right. {Goal}. That's the job." },
        approaches = {
            { skill = "investigation", say = "Let's start with what's in front of us. What do we actually know?",
              win = "{char} pieces it together: the way to {goal} is clearer now.",
              lose = "{char} goes round in circles. Nothing about {goal} makes sense yet." },
            { skill = "persuasion", cast = true, say = "We're trying to {goal}. Can you help us?",
              win = "{Cast} {nods|nod} slowly, and {tells|tell} them what they need.",
              lose = "{Cast} {shakes|shake} their head. Not their problem." },
            { skill = "perception", say = "Hang on. Everyone stop talking for a second.",
              win = "{char} catches the thing everyone else walked past.",
              lose = "Whatever {char} heard, it doesn't happen again." },
        },
        moment = { text = "It comes down to this: {actor_char} has one chance to {goal}.", skill = { "investigation", "persuasion", "athletics" } },
        talk = { "Wait, what are we here for again? {Goal}?", "Okay, focus. {Goal}." },
    },
}
