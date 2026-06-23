# App Store Submission Checklist — LG webOS Remote

A start-to-finish guide. Files referenced here live in this `AppStore/` folder and
in `docs/` (the public website). Check items off as you go.

---

## 0. What's already done (in this branch)
- [x] App icon present (1024 + all sizes) — `LGRemote/Assets.xcassets/AppIcon.appiconset`
- [x] `ITSAppUsesNonExemptEncryption = false` set in `Info.plist` (no export-compliance paperwork)
- [x] Device family set to **iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`)
- [x] Listing copy written → `metadata.md`
- [x] App Privacy answers → `app-privacy.md`
- [x] Privacy Policy + Support + landing pages → `docs/` (GitHub Pages)
- [x] Pages deploy workflow → `.github/workflows/pages.yml`
- [x] Screenshot spec & capture commands → `screenshots.md`

---

## 1. Publish the website (Privacy Policy + Support URLs are REQUIRED)
The Pages workflow deploys on push to **main/master**. So:
1. Merge this branch into `main` (or run the workflow manually via
   **Actions → Deploy GitHub Pages → Run workflow**).
2. In the repo: **Settings → Pages → Source: GitHub Actions**, then enable Pages.
3. Confirm these load:
   - [ ] `https://kitdesai-ai.github.io/lgremote/privacy-policy.html`
   - [ ] `https://kitdesai-ai.github.io/lgremote/support.html`

> If you'd rather not wait on a merge: in **Settings → Pages**, you can instead
> set Source to "Deploy from a branch", pick this branch and the `/docs` folder.

---

## 2. Capture screenshots (needs a Mac — see screenshots.md)
- [ ] 6.9" iPhone, **1320 × 2868**, 4–6 shots (main remote, D-pad, settings/discovery, input picker, onboarding)

---

## 3. App Store Connect — create the app record
1. Go to https://appstoreconnect.apple.com → **My Apps → +**.
2. Platform: iOS · Name: **LG webOS Remote** · Primary language: English (U.S.)
   · Bundle ID: **com.kitdesai.LGRemote** · SKU: `lgremote-001`.
3. Fill in fields from `metadata.md`:
   - [ ] Subtitle, Promotional Text, Description, Keywords
   - [ ] Support URL, Marketing URL, Copyright
   - [ ] Primary category **Utilities**, Secondary **Entertainment**
   - [ ] Upload screenshots
4. **App Privacy** → "Data Not Collected" (see `app-privacy.md`)
   - [ ] Set Privacy Policy URL
5. **Age Rating** → answer all "None" → results in **4+**.

---

## 4. Build, archive & upload (your CLAUDE.md pipeline)
Run on your Mac with signing configured:
```bash
xcodebuild archive -scheme LGRemote \
  -archivePath ./build/LGRemote.xcarchive \
  -destination 'generic/platform=iOS'

xcodebuild -exportArchive \
  -archivePath ./build/LGRemote.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```
- [ ] Build appears in App Store Connect → TestFlight (allow ~5–15 min processing)
- [ ] (Recommended) Test the processed build via TestFlight on a real device

> Consider bumping the build number for each upload. Version stays `1.0`; the
> build (`CURRENT_PROJECT_VERSION`) must increase on each new binary.

---

## 5. Attach build & submit
1. In the **1.0** version page → **Build** → select the uploaded build.
2. **App Review Information**:
   - [ ] Contact info (your name, phone, email)
   - [ ] **Notes for review (IMPORTANT):** the app needs a real LG TV to test —
         reviewers can't pair without one. Tell them so. Suggested note:

   > "This app controls a physical LG webOS TV over the local network via LG's
   > SSAP protocol. Full functionality (pairing, volume, inputs, D-pad) requires
   > a real LG TV on the same Wi-Fi network, which the app auto-discovers. Without
   > a TV present, the app shows its onboarding/discovery screen, which is expected.
   > The app collects no data and contacts no servers other than the TV itself."

   - [ ] Demo account: **Not needed** (no login) — leave blank / mark N/A.
3. **Version Release**: choose Automatic or Manual release.
4. - [ ] Click **Add for Review** → **Submit**.

---

## 6. Likely rejection risks (be ready)
| Risk | Guideline | Mitigation |
|------|-----------|-----------|
| Name leads with "LG" trademark | 4.1 / trademark | Disclaimer is in the description. If rejected, rename to **"Remote for LG webOS TV"** (Name field only — no code change) and reply/resubmit. |
| "Can't test without hardware" | 2.1 | The review note above tells them this is expected; offer a video if asked. |
| Local Network prompt | 5.1.1 | `NSLocalNetworkUsageDescription` is already set with a clear reason. |

---

## Quick reference — key values
| Item | Value |
|------|-------|
| App name | LG webOS Remote |
| Bundle ID | com.kitdesai.LGRemote |
| Version / Build | 1.0 / (increment per upload) |
| Min iOS | 18.0 |
| Devices | iPhone only |
| Category | Utilities (Entertainment secondary) |
| Age rating | 4+ |
| Privacy | Data Not Collected |
| Privacy URL | https://kitdesai-ai.github.io/lgremote/privacy-policy.html |
| Support URL | https://kitdesai-ai.github.io/lgremote/support.html |
| Keywords | 96 / 100 chars (see metadata.md) |
