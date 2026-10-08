# 49-006 · meal_ai_photo_attached fires on every Camera or Gallery tap, also when no photo is attached (no camera, cancelled picker)

- kind: bug
- status: triaged
- ticket: 49
- run: w5-20261008T1719Z
- screen: Log a Meal (Describe tab)
- decision: 

**Steps.**
1. Describe tab, tap Camera on the simulator (17:34:28Z): iOS camera permission -> Allow -> plugin alert "Error / Camera not available." -> OK. Nothing attached.
2. Tap Gallery (17:34:57Z): the iOS picker opens; close it with X. Nothing attached.

**Expected.**
`meal_ai_photo_attached` fires once a photo is attached (its name says so); a no-camera or cancelled pick sends nothing, or a distinct event.

**Actual.**
`meal_ai_photo_attached {method: photo_camera}` at 12:34:28.49 local (the tap, before the permission prompt was answered) and `meal_ai_photo_attached {method: photo_gallery}` at 12:34:57.78 local (the tap). Neither attached a photo (37-after-camera-ok.png, 39-gallery-cancelled.png: no "Photo attached" card). From code (`log_meal_screen.dart` `_pickPhoto`, about `:1978-1984`): the event is tracked before `pickImage` is awaited, so a null result or a picker failure still counts as attached. Photo-attach rates in analytics are overstated.

**Evidence.**
- runs/49/37-after-camera-ok.png — after the camera alert: no photo attached
- runs/49/39-gallery-cancelled.png — after Gallery X: no photo attached
- runs/49/console-redacted.log — both `meal_ai_photo_attached` lines at 12:34:28 and 12:34:57 local

**Decision quote.**
> 

**Triage.**
