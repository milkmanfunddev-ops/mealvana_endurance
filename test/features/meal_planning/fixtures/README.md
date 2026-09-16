# Meal-planning test fixtures

Most files here are recorded Vana responses, producer-shaped, used by the
domain parsers and the seam tests.

## `dish_photo_with_gps.jpg`

A camera photo that really carries location, for the Tester photo-upload tests
(ADR 0003, meal-imagery ticket 05). It is 2400x1800 (4:3, so cropping to the
recipe screen's 16:10 does something, and over the 1600px long-edge limit, so
shrinking does too) and its EXIF holds an iPhone's make and model, the time it
was taken, and coordinates in Birmingham, Alabama.

The point of the fixture is that it is not synthetic in the way that matters:
`prepareDishPhoto` must strip a real APP1 segment holding a real GPS IFD, and a
test fed a metadata-free image would pass while the app shipped a Tester's home
address. If you regenerate it, check the GPS is really there first.

Rebuild it with:

```bash
python3 - <<'PY'
from PIL import Image
from PIL.ExifTags import Base, GPS
from PIL.TiffImagePlugin import IFDRational

img = Image.new('RGB', (2400, 1800), (120, 60, 40))
for y in range(0, 1800, 200):
    for x in range(0, 2400, 200):
        img.paste(((x // 200 * 20) % 256, (y // 200 * 30) % 256, 90),
                  (x, y, x + 200, y + 200))

exif = img.getexif()
exif[Base.Make.value] = 'Apple'
exif[Base.Model.value] = 'iPhone 16 Pro'
exif[Base.DateTimeOriginal.value] = '2026:09:16 18:04:11'
gps = exif.get_ifd(0x8825)
gps[GPS.GPSLatitudeRef.value] = 'N'
gps[GPS.GPSLatitude.value] = (IFDRational(33), IFDRational(31), IFDRational(12))
gps[GPS.GPSLongitudeRef.value] = 'W'
gps[GPS.GPSLongitude.value] = (IFDRational(86), IFDRational(48), IFDRational(36))

img.save('test/features/meal_planning/fixtures/dish_photo_with_gps.jpg',
         'JPEG', quality=92, exif=exif)
PY
```

`dish_photo_preparation_test.dart` asserts the fixture's size and GPS before it
asserts anything about the preparation, so a bad rebuild fails loudly rather
than making the real assertions vacuous.
