# Real screenshots go here

Drop real app captures in this folder to have them framed with the marketing
flair (gradient background + headline + iPhone frame) instead of the synthetic
drawn UI.

## How

1. Capture from a **6.9" simulator** (iPhone 16 Pro Max) so the image is natively
   **1320 × 2868**:
   ```bash
   xcrun simctl io booted screenshot 01-remote.png
   ```
2. Save it here using the **same filename** as the slide you want to replace:
   - `01-remote.png` → "Your remote, reimagined."
   - `02-dpad.png` → "Navigate without looking down."
   - `03-discovery.png` → "Finds your TV automatically."
   - `04-inputs.png` → "Switch inputs in one tap."
   - `05-setup.png` → "Set up in seconds."
3. Re-run the renderer:
   ```bash
   python3 AppStore/generate_screenshots.py
   ```
   Any slide with a matching file here is built from the real screenshot; the
   rest fall back to the synthetic UI. You can mix and match.

## Notes

- The image is scaled to fill the screen area (`xMidYMid slice`), so a native
  1320 × 2868 capture maps almost 1:1 — only a hairline is cropped.
- The synthetic "dynamic island" overlay is **skipped** for real screenshots,
  since your capture already includes the top of the device.
- To tweak a headline/subtitle/accent color, edit the `SLIDES` list in
  `generate_screenshots.py`.
