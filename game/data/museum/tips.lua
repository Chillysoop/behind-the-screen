-- Lore tips for The Museum of Nightmares (Conner, November 6: "lore tips that can be given out, separate from the bag,
-- that can help point the party in the right direction"). The DM hands one out when a friend pokes at something in the
-- room it's for (game/model/lore_tips.lua). Each points the way without giving the answer: a tip that `hints` a secret
-- counts as that secret's hint. Our words; the book's pages for what each points at.
--
-- room: where it helps (nil: anywhere). when: only once this holds. moot: no use once this holds (besides its secret
-- being known).

return {
    { id = "tip_flitwidget", name = "Flitwidget isn't telling it all", room = "street", hints = "gorgon", page = 6,
      text = "Flitwidget's cheer has a crack in it. Ask him straight what's gone wrong in there, and don't let him change the subject." },
    { id = "tip_pond", name = "Mind the pond", room = "garden", hints = "pond", page = 8,
      text = "Keep clear of the pond's edge. Whatever lives in that water reaches further than it looks." },
    { id = "tip_hedges", name = "The clipped beasts", room = "garden", hints = "living_hedges", page = 8,
      text = "The clipped beasts are best walked round, not up to. Only one of them is only ever a hedge." },
    { id = "tip_statue", name = "The metal man by the doors", room = "entrance", hints = "sentinel_wakes", page = 9,
      text = "The big metal man only cares about the donation case. Leave the case be, or put something in it, and he stays put." },
    { id = "tip_tablet", name = "Read all of the tablet", room = "chamber", hints = "ritual", page = 12,
      text = "The tablet by the pedestal reads like a recipe. Every line of it matters: get all of it before anyone tries anything." },
    { id = "tip_scarabs", name = "A second wave", room = "chamber", hints = "scarabs", page = 12,
      text = "The guardian has more in it than bones. Once it's hurt, be ready for whatever comes pouring out." },
    { id = "tip_knight", name = "What hurts a painting", room = "paintings", hints = "knight_weak", page = 15,
      text = "The dark knight is paint all the way through. Plain steel does little to it: think about what ruins a painting." },
    { id = "tip_book", name = "The scholar's book", room = "gift_shop", hints = "gorgon_lore", when = { told = "gorgon" }, page = 17,
      text = "The scholar's book on the shop's shelf knows a great deal about gorgons. It's worth a slow, careful read." },
    { id = "tip_tracks", name = "Too easy to follow", room = "hunting", hints = "tracks", page = 20,
      text = "The scratch marks are very easy to follow. Ask why anything would make it that easy." },
    { id = "tip_pack", name = "Count them first", room = "hunting", hints = "pack_hides", page = 20,
      text = "Count the hunters before chasing one. There are more of them in here than the ones in plain sight." },
    { id = "tip_bird", name = "Listen to the bird", room = "offices", hints = "bird", page = 21,
      text = "The little bird under the dome isn't there for decoration. It sings when magic comes close." },
    { id = "tip_ore", name = "The ore samples", room = "offices", hints = "mythril", page = 21,
      text = "The ore samples in here don't like magic. Keep spells well away from them." },
    { id = "tip_drone", name = "Don't listen", room = "lecture", hints = "lecturer_ears", page = 23,
      text = "The lecturer's voice is the weapon. Whoever can't hear him has the best of it." },
    { id = "tip_switch", name = "The red switch", room = "tomorrow", hints = "hyper", page = 19,
      text = "The red switch makes the machine deadlier, and it also makes it burn itself out. It's all in the timing." },
    { id = "tip_pots", name = "Every pot smashed", room = "lair", hints = "sisters", when = { told = "gorgon" }, page = 27,
      text = "She smashed every pot in her lair looking for something. Whatever she lost may matter more to her than a fight." },
}
