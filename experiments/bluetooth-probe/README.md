# Bluetooth feasibility probe

Experimental round-trip timing only. It cannot move the pointer, read typed input, access Sofa Remote pairing, or change the installed app. It is not a shipping transport or security audit.

The Mac advertises a BLE service with encryption-required writes and notifications. The phone scans for the service, connects, subscribes, sends a four-byte counter and times its echoed response. The first detected advertising device is not authenticated as the intended Mac; use only in a controlled environment. Never use this discovery model for remote control: a real release needs explicit identity verification, pairing, authorization, revocation, rate limits, and review.

## Next steps for a physical test

Full Xcode and an iOS SDK are required. Build a Mac app containing MacProbe.swift with `NSBluetoothAlwaysUsageDescription` in its Info.plist. Build an iOS SwiftUI app containing PhoneProbe.swift with the same Bluetooth usage description and a unique bundle identifier. Sign using an Xcode Personal Team, enable Developer Mode on the iPhone, and run both in the foreground. Both devices may prompt for Bluetooth permissions and pairing. Do not use a command-line executable without a usage description. Stop the Mac probe after testing.

A round-trip sample includes both directions and application processing. It does not measure pointer smoothness, one-way latency, loss, connection stability or security. To compare pointer quality, a separate authenticated input prototype and physical iPhone tests are necessary. Measure repeated samples and reconnect behavior; do not infer a winner from a single ping.
