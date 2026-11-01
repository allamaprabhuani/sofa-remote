# Set up Sofa Remote

## 1. Install on the Mac

Requires macOS 14 or later, Apple silicon or Intel. Download the disk image from the [public beta release](https://github.com/allamaprabhuani/sofa-remote/releases/tag/v0.1.0-beta.5), open it and drag **Sofa Remote** to **Applications**. Eject the disk image, then open the app from Applications.

This beta is ad-hoc signed, **not Developer ID notarised**. macOS may block first launch. If you trust the source and intentionally downloaded this beta, review the blocked-app option in **System Settings → Privacy & Security**. Availability depends on macOS and device-management policy. Do not disable Gatekeeper globally or paste commands from an untrusted issue. Building from the [source](../README.md#build-from-source) is another development option.

## 2. Allow mouse and keyboard control

In Sofa Remote, choose **Open Accessibility settings**. Enable Sofa Remote in **System Settings → Privacy & Security → Accessibility**, then return to the app. This lets a paired phone control your logged-in desktop. Screen Recording is not required.

If the phone still reports missing permission, check that the enabled entry points to the installed copy. Quit any duplicate copy, reopen Applications → Sofa Remote and check permission again. An upgrade or rebuilt ad-hoc signature may require you to review that entry. If the switch is on but a fresh diagnostic preview still reports missing access after restarting, remove only Sofa Remote from the list, add the current Applications copy again, and enable it yourself. Do not grant permissions automatically or enable unrelated apps.

## 3. Connect the phone

Keep the Mac awake and both devices on a trusted private network. In the Mac app, choose **Show pairing code**, scan the QR with iPhone Camera and open the link in Safari. A six-digit code can also be entered manually at the displayed address. Pairing expires after five minutes or when its window closes.

Direct local HTTP is unencrypted. For encrypted network transport, connect both devices to your own Tailscale tailnet and scan the Mac's displayed Tailscale IP link. Check your tailnet access policy. Never enable router port forwarding or a public tunnel for Sofa Remote. Custom HTTPS proxies and Tailscale hostnames are not supported by this beta's Host policy.

## 4. Try the touchpad and save it

In **About & Help → Setup and connection help**, open the disposable practice window, or use your own empty test window. Move one finger on the phone touchpad and tap once to click. Choose Dark, Black, Light, Ivory (brown), Plum, Ocean or Custom in the remote’s **Settings → Appearance**. The colour choice stays in your phone browser. Use two fingers to scroll; the labelled controls provide other clicks and keyboard input. Open **Shortcuts** (the grid icon) to enter a website address or launch saved apps/sites. Test dragging in that disposable window before relying on it elsewhere.

In iPhone Safari, choose **Share → Add to Home Screen**. Keep that shortcut to return to the remote. If the Mac's network address changes, open a fresh QR link from the Mac instead of the old shortcut, then save the new link if necessary.

## Find the Mac controls again

Choose the cursor icon in the Mac menu bar. If you hid it, open **Applications → Sofa Remote** again; its setup window reopens. Restore **Show menu bar icon** if you want. Hiding the icon or closing the setup window keeps sharing running. **Stop sharing** closes the listener; **Quit** exits the helper.

Open at login and Keep Mac awake are optional and off by default. Keep Mac awake prevents idle system sleep while sharing and can increase total energy use; displays can still sleep.

## Connection and permission recovery

| What you see | What to do |
| --- | --- |
| Cannot open the remote | Check the Mac is awake, sharing is started, and both devices are on the same reachable network. Scan its current QR. Guest Wi-Fi may isolate devices. |
| Lost connection after changing Wi-Fi | Open the Mac app and use its current network link. The old IP/Home Screen shortcut may no longer reach it. |
| Pairing expired or phone removed | Start a new pairing session on the Mac and scan again. Revoked secrets do not become valid by refreshing. |
| Accessibility permission needed | Review the installed app's Accessibility entry, then return to Sofa Remote. |
| Input paused | Unlock on the Mac, leave secure text input, then choose **Resume input on this Mac**. |
| Screen wake did nothing | The Mac must stay awake and reachable. Use its physical keyboard if needed; waking a display does not unlock macOS or power on separate TV hardware. |
| A window is on the wrong display | Phone Settings → choose the display by its real name → **Move front window to display**. Choosing a display alone jumps the pointer; moving the window is a separate action. |
| Pointer pauses or speeds up | Try an ordinary slow movement and a quick swipe in a disposable window. Note which fails and report versions. Some jitter remains in this beta. |
| Copy diagnostics unavailable | Select the preview text and copy manually. Clipboard API access may be unavailable on HTTP. |

Use **About & Help** for versions, guides, privacy, licences and a diagnostic preview. Check for updates opens release notes; it does not install anything automatically. For more help, see [Support](../SUPPORT.md).

## Remove access or uninstall

Remove a paired phone in the Mac app to invalidate its secret. Stop sharing or Quit when you do not want remote access. To uninstall, turn off Open at login, quit Sofa Remote and move the installed app to Trash. Its local settings/device digests remain in `~/Library/Application Support/Sofa Remote` until you explicitly remove them. Remove its Accessibility entry in System Settings and the phone's Home Screen shortcut/site data if you also want to clear saved access locally. Do not post those files or site data in an issue.
