# 11: The companion's conversation surface

**What to build:** The inside of the sheet, as the export draws it. A status chip at the top naming
what this exchange is about — "Fuel plan · to do" in orange when there is something to do, "Update" in
electrolyte when there is not. Vana's messages flush left, each with a small filled orange sparkle
avatar. The athlete's own turns right-aligned in a soft cream-tinted bubble. A typing indicator where
the answer will land. At most two quick-reply chips, one filled and one outline, which vanish the
moment the thread has anything in it and do not come back in that exchange. A composer whose send
control is inert until there is a draft and orange once there is.

The generative-UI parts Vana already renders compose inside the message column unchanged.

**Blocked by:** 10 Vana everywhere

**Status:** ready-for-agent once 10 lands

- [ ] Status chip derives from the exchange, not from a hardcoded string; both tones render
- [ ] Vana and athlete message treatments match the spec, at iPhone-SE width and at large text
- [ ] Quick replies: at most two, one filled and one outline; they retire on the first thread entry and stay retired
- [ ] Typing indicator shows only while a turn is in flight, and never alongside quick replies
- [ ] Composer send is inert with an empty draft and orange with a non-empty one
- [ ] An existing VanaPart (a meal picker) renders inside the sheet's message column unchanged
- [ ] Goldens for the four message shapes and both chip tones
