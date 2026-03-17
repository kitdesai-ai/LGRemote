# LG webOS Remote

A native iOS remote control for LG webOS TVs. Built with SwiftUI, no external dependencies.

Communicates directly with your TV over the local network using LG's SSAP (Simple Service Access Protocol) over WebSocket.

## Features

- **Auto-discovery** — finds LG TVs on your network automatically
- **Power** — turn on (Wake-on-LAN) and off
- **Volume & Channels** — real-time volume display with live subscription
- **Input switching** — switch between HDMI, TV antenna, and other inputs
- **D-pad navigation** — directional pad, OK, back, home, and menu buttons
- **Wake-on-LAN** — power on your TV remotely via MAC address

## Requirements

- iOS 18.0+
- LG TV running webOS (2014 or newer)
- Phone and TV on the same local network

## Setup

1. Open the app — it will scan for LG TVs on your network
2. Tap your TV to connect
3. Accept the pairing prompt on your TV
4. That's it — the pairing key is saved for future connections

For Wake-on-LAN (turning the TV on when it's off), enter your TV's MAC address in Settings. You can find it in your TV's network settings.

## How It Works

The app connects to the TV's WebSocket server and performs an SSAP registration handshake. Once paired, it can send commands for power, volume, channels, inputs, and navigation. D-pad navigation uses a separate pointer input socket.

**Connection fallback:** `wss://3001` → `wss://3636` → `ws://3000`

## Building

Open `LGRemote.xcodeproj` in Xcode and build. No package manager setup or dependencies required.

## License

MIT
