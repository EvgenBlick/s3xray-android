# VLESS VPN App Architecture

## Goal
- Android-first MVP that imports a `vless://` link, validates it, requests VPN permission, and connects through a native VPN runtime bridge.

## Platform rule
- UI iteration may temporarily run on Linux desktop for fast hot reload while Android build infrastructure is unstable.
- Real VPN work is not considered complete until it is implemented, launched, and verified on Android emulator or device.
- Any `VpnService`, permission flow, tunnel lifecycle, background execution, and runtime integration milestone must be validated on Android specifically.

## Layers
- `presentation`
  - Flutter screens, state rendering, validation feedback, connection status, logs.
- `domain`
  - `vless://` parsing, profile validation, connect/disconnect use-cases, app state contracts.
- `data`
  - Secure profile storage, settings, recent connections, runtime config serialization.
- `platform/android`
  - `VpnService`, permission flow, foreground service, bridge to VPN runtime, device network monitoring.
- `runtime`
  - Adapter over selected VPN core (`sing-box` or `xray-core`) with start/stop/status APIs.

## Recommended module flow
1. User pastes `vless://` link into Flutter UI.
2. Domain parser extracts host, port, UUID, security and transport.
3. Data layer persists validated profile.
4. Android bridge requests `VpnService` permission.
5. Runtime adapter transforms profile into runtime config and starts the tunnel.
6. Native layer streams status and logs back to Flutter.

## Immediate milestones
1. Scaffold app and prove hot reload on emulator.
2. Parse a single `vless://` link in Flutter.
3. Add local persistence for saved profiles.
4. Add Android platform channel plus `VpnService` shell.
5. Integrate runtime core and wire connect/disconnect.
6. Add diagnostics, reconnect strategy and error surface.

## Current delivery mode
- Current visual/design iteration runs through `flutter run -d linux`.
- Android emulator remains the required checkpoint for VPN behavior once the Gradle TLS download issue is resolved.

## Runtime decision
- Preferred default: `sing-box` for current ecosystem fit and flexible config model.
- Fallback: `xray-core` if existing VLESS configuration assets or operational knowledge depend on it.

## Non-goals for MVP
- iOS VPN implementation.
- Subscription sync and QR import.
- Full protocol matrix beyond VLESS.
