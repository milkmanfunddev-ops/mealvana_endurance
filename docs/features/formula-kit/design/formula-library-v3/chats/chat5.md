# During-Card Descriptors

_Started 2026-05-16 01:00 UTC_

---

## User

# Formula Kit — During card descriptors

Replace the eyebrow, component list, monospace subtitle, and category badge below each during-workout template title with one short descriptor.

| Template | Descriptor |
|----------|------------|
| Quick Gel Module (T1/T2) | Fast carbs between disciplines |
| Gel + Water | Beginner-friendly, easy on gut |
| (Gel + Water) + Sports Drink | Stretch gels into longer sessions |
| Chew + Water | If gels feel too sweet or sticky |
| Chew + Water + Sports Drink | Chew alternative that stretches further |
| Sports Drink Only | Under 90 min — keep it simple |
| High Carb Drink Mix + Water | Max carbs without chewing — trained gut |
| Bar + Sports Drink + Water | Solid food, mid-distance, any stomach |
| Bar + (Gel + Water) + Sports Drink | Long-ride variety, portable bar anchor |
| Stroopwafel + Sports Drink + Water | Cyclist's classic — easy to eat mid-ride |
| Stroopwafel + (Gel + Water) + Sports Drink | Long-ride variety with a treat |
| Banana + Sports Drink + Water | Real food, gentle on stomach |
| Banana + (Gel + Water) + Sports Drink | Long-ride variety with whole food |
| Rice Cake + Sports Drink + Water | Real-food cycling staple, any duration |
| Rice Cake + (Gel + Water) + Sports Drink | Substantial fueling for ultras |
| Chew + Water (Cycling) | If gels feel too sweet or sticky |
| Chew + Water + Sports Drink (Cycling) | Chew alternative that stretches further |
| HCDM + Bar + Water | Top carb intake — trained gut required |
| HCDM + Stroopwafel + Water | Top carb intake — trained gut required |
| HCDM + Banana + Water | Top carb intake — trained gut required |
| HCDM + Rice Cake + Water | Top carb intake — trained gut required |
| CDM + Bar + Water | Mid-tier carb load, moderate gut OK |
| CDM + Stroopwafel + Water | Mid-tier carb load, moderate gut OK |
| CDM + Banana + Water | Mid-tier carb load, moderate gut OK |
| CDM + Rice Cake + Water | Mid-tier carb load, moderate gut OK |

Before formulas unchanged.

## Assistant

_[tool: list_files]_

_[tool: grep]_

_[tool: grep]_

_[tool: read_file]_

_[tool: grep]_

_[tool: grep]_

_[tool: read_file]_

_[tool: grep]_

_[tool: grep]_

_[tool: read_file]_

_[tool: str_replace_edit]_

I understand the structure now. The DuringCard currently shows: title, foodForm pill (the "category badge"), components list, and the monospace formula+ratio line. I'll replace those subtitle elements with a single descriptor line.

Let me edit browser.jsx to add a descriptor map and simplify the card.

_[tool: done]_

Replaced the foodForm pill, components list, and monospace formula+ratio under each During card title with one short descriptor. Descriptors are mapped per template id (via a `DURING_DESCRIPTORS` map in `browser.jsx`), drawing from your table where the templates exist (Gel + Water, Sports Drink Only, HCDM + Water, Bar + SD + Water, Stroopwafel + SD + Water, Banana + SD + Water, Banana + (Gel+Water) + SD, Rice Cake + SD + Water, Chew + Water, Chew + SD, Gel + SD variants, Tri-transition gel). The remaining ~12 templates in the data (Banana + Water, Dates + SD, PB&J, Honey, Bonk Bar, 2× Gel, ultra mixes, etc.) got descriptors in the same voice since the table didn't cover them — say the word if you want any rephrased. Before cards untouched.

