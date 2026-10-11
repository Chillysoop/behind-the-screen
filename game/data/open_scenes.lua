-- Open scenes (A15: player agency). The DM sets the stage and asks "what do you do?"; the
-- players pitch where to go, by type and by story. Data only: tune freely. The model is
-- game/model/night.lua (open_scene) and game/model/prep.lua (spots).
--
-- SPOTS: how many places an open scene can sketch. SPOT_COST: prep hours to sketch a new one
--   (a place you already know costs nothing: Your places).
-- arrive: the DM's opening ({hub} is where they are).
-- pitch: what a player says for a spot, by the scene type it suits ({place} is the spot).
-- thread: a player whose backstory is tied to the spot. person: someone from the notebook was
--   last seen there ({person}). again: a place they've been before.
-- wild: ideas nobody prepped, by archetype: a place (a location id) and what they say. If the
--   DM goes with one, the place gets improvised around the idea.

return {
    SPOTS = 4,
    SPOT_COST = 1,

    arrive = {
        "They reach {hub} with the afternoon ahead of them. You lean back from the screen: 'So. What do you do?'",
        "{Hub}, and nobody's chasing them for once. You put your pencil down. 'Where to?'",
        "They have a free day in {hub}. You fold your hands and wait. 'Your call.'",
    },

    pitch = {
        combat = { "I want a fight. A proper one. {Place}.", "Let's go to {place}. I'm itching for trouble." },
        social = { "{Place}. I want to talk to people.", "Let's hang around {place} and see who turns up." },
        mystery = { "Something's off about {place}. I want to poke at it.", "{Place}. I bet there's a clue there." },
        exploration = { "What's past {place}? Let's find out.", "I want to see {place}. All of it." },
        puzzle = { "{Place}. There's a riddle there, I can feel it.", "Let's figure out {place}." },
        downtime = { "{Place}. We've earned a quiet hour.", "Can we just go to {place} and relax?" },
        set_piece = { "{Place}. Something big's going to happen there.", "Let's do something daring at {place}." },
    },
    thread = { "{Place}. It's about {char}'s past. I need to go.", "{Char} has unfinished business at {place}." },
    person = { "{Person} said they'd be at {place}. Let's find them.", "Let's look for {person} at {place}." },
    again = { "Back to {place}! I liked it there.", "Can we go back to {place}?" },
    back = { "Yeah, {place}. I'm in.", "Seconded. {Place}.", "Same idea. {Place}!", "{Place} works for me." },

    wild = {
        { archetype = "instigator", place = "counting_house", say = "Hear me out: we rob the counting house." },
        { archetype = "butt_kicker", place = "fighting_pit", say = "There's a fighting pit behind the tannery. I'm entering." },
        { archetype = "power_gamer", place = "market", say = "Shopping. Magic items. I have gold and I want to spend it." },
        { archetype = "method_actor", place = "tavern", say = "I want to sing at the Kettle. In character. All of it." },
        { archetype = "explorer", place = "archive", say = "The flooded archive. Nobody's mapped it. Let's map it." },
        { archetype = "storyteller", place = "ilsa_room", say = "Ilsa's room. I keep thinking we missed something." },
        { archetype = "casual", place = "tavern", say = "Honestly? Lunch. The Kettle. Then we see." },
        { archetype = "tactician", place = "millbrook_walls", say = "The walls. If trouble comes, I want to know where we'd hold." },
    },

    -- How the DM handles the pitches (decision card options).
    labels = {
        follow = "Follow the table: {place} ({who})",
        other = "Go with {name}'s idea: {place}",
        split = "Split the party: {place} and {other_place}",
        quantum = "Follow the table, and move your prepped hook to {place}",
        steer = "Steer them to your hook: {hook}",
    },
    logs = {
        follow = "You go with the table. {Place} it is.",
        other = "You go with {name}'s idea. Off to {place}.",
        split = "You cut between them: half the party at {place}, half at {other_place}.",
        quantum = "Off to {place}. Funny thing: what you'd prepped for elsewhere is waiting there.",
        steer = "A messenger, a scream, a sign: somehow, they end up at {hook} after all.",
    },
    meanwhile = {
        "Meanwhile, at {place}, {who} gets a lead of their own.",
        "Over at {place}, {who} does well enough on their own, and comes back with a story.",
    },
}
