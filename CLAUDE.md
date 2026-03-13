# LG webOS Remote

iOS SwiftUI app to control LG webOS TVs via SSAP WebSocket protocol. No external dependencies.

## Key Files
- `LGTVService.swift` — core service: WebSocket, SSAP handshake, commands, WoL, TV discovery
- `RemoteView.swift` — main UI with floating glass FABs (D-pad bottom-left, Settings bottom-right)
- `DPadView.swift` — D-pad navigation half-sheet modal
- `SettingsView.swift` — TV discovery (subnet scan) + manual IP/MAC config
- `InputPickerView.swift` — input switcher with synthetic "TV" live input
- `HapticManager.swift` — haptic feedback helpers

## Protocol
- Connection fallback: `wss://<ip>:3001` → `wss://<ip>:3636` → `ws://<ip>:3000`
- SSAP registration handshake required on connect; client-key stored in UserDefaults
- D-pad uses a separate pointer input socket: sends `type:button\nname:BUTTONNAME\n\n`
- Volume uses `type: subscribe` for real-time updates
- Wake-on-LAN via UDP magic packet broadcast to MAC address

## Key Decisions
- TV discovery scans port 3000 (plain TCP) on /24 subnet — Bonjour didn't work across WiFi/Ethernet
- Hidden inputs: `["av", "sonos"]`
- Disconnect on background, reconnect on foreground to prevent socket abort errors
- `ITSAppUsesNonExemptEncryption = false` in Info.plist

## Preferences
- No "Co-Authored-By: Claude" in commit messages
