-- What the friends at the table think and don't say (v2, October 30): the Discord feedback's
-- "some barks could be internal dialogue... watch one of them react to a moment internally".
-- A thought shows what's really driving a player right now, so the DM can read it and answer it
-- (game/model/thoughts.lua decides when; game/ui/night_view.lua draws the bubble and the card).
-- Data only: tune freely. Every line is the player talking to themselves, out of character, and
-- fits any adventure (no place names, nothing from one story).
--
-- needs:     what a thought is about. want: the card's line under the thought ("{name} {want}"),
--            answers: the two things the DM can do about it (plus "Let it be", always).
-- answers:   label and log are filled with {name} (the player), {char} (their hero) and
--            {them} / {their} (the player's pronouns). table_min: real table minutes it costs.
-- lines:     each friend's own lines by need; generic: anyone's, when a friend has none.
--            A need's "_after" lines answer something that just happened (a call that cost them).

return {
    pronouns = {
        mara = { them = "her", their = "her" }, dev = { them = "him", their = "his" },
        jess = { them = "her", their = "her" }, sam = { them = "him", their = "his" },
    },

    needs = {
        spotlight = { want = "wants a turn in the spotlight", answers = { "next_moment", "ask" } },
        story = { want = "wants a mystery to chew on", answers = { "detail", "next_moment" } },
        pace = { want = "is losing the thread in a long fight", answers = { "detail", "hurry" } },
        challenge = { want = "wants some danger, or at least a fight", answers = { "stakes", "hurry" } },
        social = { want = "wants to talk to somebody", answers = { "talk", "snack" } },
        reward = { want = "wants something shiny to take home", answers = { "prize", "next_moment" } },
        off_spot = { want = "would rather not be the one on the spot", answers = { "spare", "cheer" } },
        fairness = { want = "isn't sure that was fair", answers = { "open", "own" } },
        plan = { want = "is about to go off on {their} own", answers = { "catch_eye", "let_go" } },
        glow = { want = "is having a great time", answers = {} },
        -- The week they've had (game/data/moods.lua): each mood's own second answer.
        tired = { want = "is running on empty tonight", answers = { "check_in", "early_break" } },
        stressed = { want = "has had a rough week", answers = { "check_in", "keep_light" } },
        distracted = { want = "has half a mind somewhere else", answers = { "check_in", "early_moment" } },
        celebrating = { want = "has good news, bursting to get out", answers = { "news", "check_in" } },
        chatty = { want = "is in a mood to talk", answers = { "talk", "news" } },
    },

    answers = {
        next_moment = { label = "Give {them} the next moment", log = "You make a mental note: the next moment is {name}'s." },
        ask = { label = "Ask what {char} is doing", log = "\"{char}, what are you doing while this happens?\"", table_min = 1 },
        detail = { label = "Let {char} notice something", log = "You add one more detail, just for {name}, and watch {them} sit up.",
                   table_min = 1 },
        stakes = { label = "Raise the stakes", log = "You let something shift in the dark at the edge of the room. Now it's dangerous." },
        hurry = { label = "Move things along", log = "You trim the next bit and get to the point." },
        talk = { label = "Have someone talk to {them}", log = "You turn to {name} in a new voice. Somebody here wants a word with {char}.",
                 table_min = 1 },
        snack = { label = "Call a snack break", log = "\"Five minutes. Snacks.\" Chairs scrape back.", table_min = 8 },
        prize = { label = "Dangle a prize", log = "You mention, casually, something glinting where {char} can see it." },
        spare = { label = "Give the next one to someone else", log = "You turn the next moment to someone else. {name} breathes out." },
        cheer = { label = "Tell {them} that was great", log = "\"That was great, {name}.\" A small, surprised smile." },
        open = { label = "Roll the next one in the open", log = "You roll the next one in front of the screen, where everyone can see." },
        own = { label = "Own it with a wink", log = "\"Yes, I nudged that one. Just the once.\" A few laughs." },
        catch_eye = { label = "Catch {their} eye", log = "You catch {name}'s eye and shake your head, very slightly." },
        let_go = { label = "Let {them} go", log = "You let it ride. This could be fun." },
        check_in = { label = "Check in quietly", log = "A quiet word with {name}, just the two of you, while the others talk.", table_min = 2 },
        early_break = { label = "Plan a break for halfway", log = "\"Break at the halfway mark, everyone.\" {name} nods, grateful.",
                        table_min = 6 },
        keep_light = { label = "Keep tonight light", log = "You lean into the jokes tonight and go easy on the grim stuff." },
        early_moment = { label = "Give {them} something to do early", log = "You make a note to put {name} on the spot early, to pull {them} in." },
        news = { label = "Make room for the news", log = "\"Hang on, {name}, didn't you have news?\" The table turns.", table_min = 5 },
    },

    lines = {
        mara = {
            story = { "There's more to this place than monsters. Somebody ask about the history.",
                      "I've got three theories and nobody's asked for one.",
                      "I want to know why, not just what's behind the next door." },
            story_after = { "We skipped right past the best part.", "I wanted to stay and look closer. Oh well." },
            pace = { "Still fighting. I'm drawing {char}'s hat in the margin.", "Fights are fine. This one is a lot of fine." },
            spotlight = { "{char} has a spell for exactly this. Nobody's looked my way." },
            fairness = { "That die said six a second ago. I'm sure it did." },
            glow = { "This is exactly the night I hoped for.", "I'm writing that one down. In ink." },
            plan = { "If nobody else reads that, I'm reading it myself." },
        },
        dev = {
            challenge = { "Is anything in here going to try to kill us?", "We've been talking for ages. My dice are getting cold." },
            challenge_after = { "Can we get back to the action, please?", "So we're just... not hitting anything?" },
            reward = { "Three rooms and not one cool sword.", "Somebody in this place has to own a magic axe." },
            spotlight = { "{char}'s just been standing there. He's a wall with a sword." },
            fairness = { "Did we just get a freebie? Feels like a freebie." },
            glow = { "THAT is why I come every week.", "Okay. That was awesome. I'm telling everyone at work." },
        },
        jess = {
            spotlight = { "I have had a voice ready for twenty minutes.", "{char} could steal that. {char} could absolutely steal that." },
            social = { "Can we please talk to someone? Anyone? A haunted coat rack?", "I want to chat with somebody weird. Bring me somebody weird." },
            social_after = { "I had a whole bit ready for that. Oh well." },
            plan = { "Outvoted. Fine. {char} goes and looks on her own, then.", "If nobody's watching, {char} goes first. Alone." },
            fairness = { "Ooh. Did the DM fudge that? Spicy." },
            glow = { "I love this group so much.", "Best. Night. Ever." },
        },
        sam = {
            social = { "I miss when we were all just laughing. Is it snack time?", "I just want the four of us talking for a bit." },
            challenge = { "I've got a plan. It's a good plan. Nobody's asked." },
            challenge_after = { "Hm. I'd have done that differently." },
            off_spot = { "That was a lot of eyes on me. Someone else take the next one.", "My hands were shaking on that roll." },
            fairness = { "That came out of nowhere. Was that fair?" },
            glow = { "This is nice. This is really nice.", "This is my favourite kind of night." },
        },
    },

    generic = {
        spotlight = { "When's it my turn to do something cool?", "Everyone's had a moment but me." },
        story = { "I want to know what's really going on here." },
        story_after = { "That was the interesting bit, and we just left it." },
        pace = { "How many hit points does this thing HAVE?" },
        challenge = { "I'd like something to go wrong. Just a little." },
        challenge_after = { "That's not the call I'd have made." },
        social = { "Can we talk to someone instead of something?" },
        social_after = { "I wanted to hang around and chat a bit longer." },
        reward = { "Is there any loot in this place at all?" },
        off_spot = { "Please don't make the next one mine." },
        fairness = { "Hm. That roll looked convenient.", "That felt harsh. Did we know that could happen?" },
        plan = { "Nobody's going to stop me, are they?" },
        glow = { "I love this game.", "Okay, that was brilliant." },
        tired = { "Long week. I nearly stayed home tonight.", "If this runs late, I'm asleep on the dice." },
        stressed = { "I need tonight not to be about work. At all.", "Today was a lot. Please let this be fun." },
        distracted = { "Phone face down. Phone face down. Phone..." },
        celebrating = { "I've got news. Big news. I'm saving it for the break.", "Best day all year, and now this. Lucky me." },
        chatty = { "I've got so much to tell everyone. Is it break time yet?" },
    },
}
