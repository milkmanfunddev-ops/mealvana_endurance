# Firebase Configuration for Codemagic Builds

## Problem

The `google-services.json` file is required for Android builds but is gitignored for security. Codemagic builds fail with:

```
File google-services.json is missing.
The Google Services Plugin cannot function without it.
```

## Solution

Store the `google-services.json` contents as an environment variable in Codemagic and create it during the build.

---

## Setup Steps

### 1. Copy google-services.json Contents

The file is located at: `android/app/google-services.json`

**Copy the ENTIRE file contents:**

```bash
cat android/app/google-services.json | pbcopy
```

This copies the entire JSON to your clipboard.

---

### 2. Add to Codemagic Environment Variables

**Navigation:**
- **Option A**: [Your App] → **App Settings** → **Environment variables** tab
- **Option B**: **Teams** → [Your Account] → **Global variables and secrets**

**Add Variable:**

| Field | Value |
|-------|-------|
| **Variable name** | `GOOGLE_SERVICES_JSON` |
| **Variable value** | Paste entire contents of `google-services.json` |
| **Variable group** | `firebase_config` |
| **Secret** | ✅ Check this box |

Click **Add**

---

### 3. Verify codemagic.yaml Configuration

The `codemagic.yaml` has been updated to automatically create the file during builds.

**Android workflows now include:**

```yaml
environment:
  groups:
    - firebase_config  # Contains GOOGLE_SERVICES_JSON

scripts:
  - name: Create google-services.json
    script: |
      echo "$GOOGLE_SERVICES_JSON" > android/app/google-services.json
      echo "✅ google-services.json created"
```

**Affected workflows:**
- `android-shorebird-release`
- `android-shorebird-patch`
- `android-build-legacy`

---

## What Happens During Build

1. Codemagic loads the `GOOGLE_SERVICES_JSON` environment variable
2. The build script writes it to `android/app/google-services.json`
3. The Android build process finds the file and proceeds normally
4. The file is temporary and deleted after the build

---

## Security Notes

✅ **Good Practices:**
- File remains gitignored (not committed to repository)
- Stored encrypted in Codemagic (marked as Secret)
- Only accessible during builds
- Automatically cleaned up after build

⚠️ **Important:**
- Never commit `google-services.json` to git
- Keep the environment variable marked as **Secret**
- Only share Codemagic access with trusted team members

---

## Troubleshooting

### Build still fails with "File google-services.json is missing"

**Check:**
1. Environment variable `GOOGLE_SERVICES_JSON` exists in Codemagic
2. Variable is in group `firebase_config`
3. Workflow references the group in `environment.groups`
4. Variable contains valid JSON (paste the entire file)

### How to verify the variable in Codemagic

In Codemagic UI:
1. Go to your app → App Settings → Environment variables
2. You should see: `GOOGLE_SERVICES_JSON` with group `firebase_config`
3. The value will be hidden (shows `***` because it's marked Secret)

### Test the variable format

To verify your JSON is valid, run locally:

```bash
cat android/app/google-services.json | jq .
```

If this outputs formatted JSON with no errors, your file is valid.

---

## Reference

**File location (local):** `android/app/google-services.json`
**File location (Codemagic):** Created dynamically during build
**Environment variable:** `GOOGLE_SERVICES_JSON`
**Variable group:** `firebase_config`
**Used in workflows:** All Android workflows

---

## Complete Example

**Environment variable in Codemagic:**

```
Name: GOOGLE_SERVICES_JSON
Group: firebase_config
Secret: ✅ Enabled
Value:
{
  "project_info": {
    "project_number": "187980576164",
    "project_id": "mealvana-endurance-46886",
    "storage_bucket": "mealvana-endurance-46886.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:187980576164:android:140a82b494da58dc3c3d31",
        "android_client_info": {
          "package_name": "com.milkman.mealvanaendurance"
        }
      },
      ...rest of file...
    }
  ],
  "configuration_version": "1"
}
```

**In codemagic.yaml:**

```yaml
android-shorebird-release:
  environment:
    groups:
      - firebase_config  # ← Reference the group here

  scripts:
    - name: Create google-services.json
      script: |
        echo "$GOOGLE_SERVICES_JSON" > android/app/google-services.json
        echo "✅ google-services.json created"
```

---

Last updated: 2025-12-11
