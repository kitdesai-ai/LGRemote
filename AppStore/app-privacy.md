# App Privacy — "Nutrition Label" Answers

Enter these in **App Store Connect → App Privacy**. This app collects nothing, so
the label is the simplest possible: **Data Not Collected**.

## Data Collection

> **Question: "Do you or your third-party partners collect data from this app?"**
>
> **Answer: No, we do not collect data from this app.**

Justification (for your own records — confirmed from the source code):
- No analytics, crash-reporting, advertising, or tracking SDKs are linked.
- The only network connection is a WebSocket from the app to the user's TV on the
  local network (`LGTVService.swift`). Nothing is sent to any server we control.
- The TV IP address, MAC address, and SSAP pairing key are stored **locally** in
  `UserDefaults` on the device. They are never transmitted off-device.
- No account, login, or contact information is requested.

## Tracking
- **Does this app track users?** No.
- No `NSUserTrackingUsageDescription` / App Tracking Transparency prompt is needed.

## Export Compliance (Encryption)
- `Info.plist` already sets `ITSAppUsesNonExemptEncryption = false`.
- In App Store Connect, when asked about encryption, answer:
  - "Does your app use encryption?" → The app uses only standard HTTPS/TLS
    (`wss://`) provided by the OS for the local TV connection, which is **exempt**.
  - You will **not** need to provide export compliance documentation.

## Permissions the app requests (for your reference)
| Permission | Info.plist key | Why |
|-----------|----------------|-----|
| Local Network | `NSLocalNetworkUsageDescription` | Discover and talk to the TV on the LAN |
| Bonjour services | `NSBonjourServices` | `_webos-second-screen._tcp`, `_lgtv._tcp` |

These are device-access permissions, not data collection — they do not change the
"Data Not Collected" label.
