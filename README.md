# Skreen App (Mobile)

Flutter app that turns an Android device into an extra touch screen for your PC.
It receives the desktop video stream over WebRTC and sends touch input back to
the computer. It works together with the Skreen desktop app.

## Features

- **Two connection modes**
  - **Cable (USB):** connects to `127.0.0.1` through an `adb reverse` tunnel.
  - **WiFi:** connects directly to the PC's IP on the same local network.
- **Low-latency video** via WebRTC (no STUN/TURN needed: loopback over USB, direct LAN over WiFi).
- **Touch control:** tap, drag, and two-finger scroll, mapped to the desktop
  while preserving its aspect ratio (letterbox/pillarbox).
- **Immersive fullscreen** while streaming, with the screen kept awake.
- **WiFi lock** in WiFi mode to avoid stutter caused by radio power saving.
- Shows the device's screen resolution on the start screen.

## Requirements

- Flutter SDK (Dart `^3.9.0`)
- An Android device
- The Skreen desktop app running on the PC
- For cable mode: `adb` and USB debugging enabled on the device

## Getting started

```bash
flutter pub get
flutter run
```

To build a release APK:

```bash
flutter build apk --release
```

## Usage

1. Start the Skreen desktop app on your PC.
2. Open the app on the device and pick a connection mode:
   - **Cable:** connect the device over USB.
   - **WiFi:** enter the IP shown by the desktop app (both devices must be on the same network).
3. Tap **Continue**, then **Connect**.
4. Use the back button or the close button to stop streaming.

## Ports

The app connects to the following TCP ports on the PC (or on `127.0.0.1` in cable mode):

| Port | Purpose |
|------|---------|
| 9002 | WebRTC signaling (newline-delimited JSON) |
| 9003 | Touch/control events (13-byte binary messages) |
| 9004 | Status notifications (e.g. `stream_stopped`) |

In cable mode these ports must be forwarded from the device to the PC, for example:

```bash
adb reverse tcp:9002 tcp:9002
adb reverse tcp:9003 tcp:9003
adb reverse tcp:9004 tcp:9004
```

## Project structure

```
lib/
├── main.dart                      # App entry point and streaming screen
├── screens/
│   └── connection_mode_screen.dart # Start screen (cable/WiFi selection)
├── models/
│   └── connection_mode.dart       # Connection mode and config
├── services/
│   ├── webrtc_connection.dart     # WebRTC peer connection and signaling
│   └── control_connection.dart    # Touch events and status channel
├── helpers/
│   ├── screen_info_helper.dart    # Real screen resolution (native channel)
│   └── wifi_lock_helper.dart      # WiFi lock (native channel)
└── theme/
    ├── app_colors.dart            # App color palette
    └── app_page_transitions.dart  # Page transition animation
```

## License

Licensed under the [Apache License 2.0](LICENSE).
