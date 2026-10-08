# 68-004 · Retest of 49-007: a gallery meal photo's GPS location is uploaded to meal-photos unchanged; the app keeps EXIF GPS, Make, Model and DateTime

- kind: bug
- status: open
- ticket: 68
- run: w7-20261008T2309Z
- screen: Log a Meal > Describe > Gallery > Analyze
- decision: 

**Steps.**
1. Retest of 49-007 step 4.
2. Made a SCRATCH copy of benchmarks/ai-model-benchmark-2026-07/images/img-01.jpg with a neutral GPS tag (40°44'30"N, 73°59'15"W) written by PIL; simctl addmedia.
3. Gallery: the iOS picker shows 'Location Is Included' by default; left as is and picked the photo.
4. Typed a description, COST spend 7 logging 68 (3/5), Analyze at 23:24:38Z.
5. Read storage.objects for the upload, downloaded the object read-only to SCRATCH as test@test.com, read its EXIF with PIL.

**Expected.**
The uploaded meal photo carries no GPS tags (the app strips location before upload, or asks the picker to drop it).


**Actual.**
The object meal-photos/607f9dd5-…/b1ccbabe-f422-494b-a20d-99de4a2772b2.jpg (320,708 bytes, 1333x1000) carries the full GPS IFD written into the source (N 40/44/30, W 73/59/15, altitude 10) plus Make 'Apple', Model 'iPhone 14 Plus', DateTime '2025:07:19 11:13:21'. image_picker re-encoded the image (quality/size) but copied the metadata. An athlete's home or gym location is stored with every meal photo in the bucket.


**Evidence.**
- runs/68/exif-uploaded-meal-photo.txt: source and uploaded EXIF side by side.
- runs/68/db-meal-photos-object.txt: the storage row.
- runs/68/08a-picker-location-included.png: the picker's default 'Location Is Included'.
- runs/68/edge-check8-photo.txt: the one upload and the one analyze request.

**Decision quote.**
> 

**Triage.**

