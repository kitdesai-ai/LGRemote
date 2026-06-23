# App Store Screenshots — Requirements & Plan

You chose **iPhone-only**, so you only need one iPhone screenshot set. Apple
auto-scales it down for smaller iPhones, so you do **not** need every size.

## Required size (iPhone, 2025+ requirement)

| Display | Device example | Portrait pixels | Required? |
|---------|----------------|-----------------|-----------|
| **6.9"** | iPhone 16 Pro Max | **1320 × 2868** | ✅ Required (primary) |
| 6.5" | iPhone 11 Pro Max | 1242 × 2688 | Accepted as the set instead of 6.9" |

Upload the **6.9" (1320 × 2868)** set. That single set satisfies the iPhone
requirement; App Store Connect scales it for all other iPhones.

- **Minimum:** 1 screenshot. **Maximum:** 10. **Recommended:** 4–6.
- No alpha channel. PNG or JPEG. RGB. Portrait orientation (your app is portrait-locked).

## You can't capture these from this Linux environment

Real device screenshots need Xcode + the iOS Simulator (or a physical iPhone),
which requires macOS. Here's the fastest path on your Mac.

### Capture on the Simulator (recommended)
```bash
# 1. Open the 6.9" simulator
xcrun simctl boot "iPhone 16 Pro Max"
open -a Simulator

# 2. Build & run the app to that simulator from Xcode (⌘R), then set up a
#    demo TV in Settings so the main remote UI is populated.

# 3. Capture a pixel-perfect screenshot (saves 1320 × 2868 PNG):
xcrun simctl io booted screenshot ~/Desktop/01-remote.png
```
Repeat for each screen you want to feature.

### Suggested shot list (4–5 screens that sell the app)
1. **Main remote** — power ring + volume/channel pills + input + mute (the hero shot).
2. **D-pad** — the navigation half-sheet open.
3. **Settings / discovery** — the network scan finding a TV (shows auto-discovery).
4. **Input picker** — the input switcher list.
5. **Onboarding** — the "No TV Connected / Get Started" screen.

> Tip: Because the UI is pure dark with a black background, the raw screenshots
> look great as-is. You can optionally drop them onto a marketing background with
> a one-line caption per shot (e.g. "Wake your TV from anywhere on Wi-Fi"), but
> Apple accepts plain device screenshots too — don't let framing block your launch.

## iPad
Not needed — the app is now configured iPhone-only (`TARGETED_DEVICE_FAMILY = 1`).
