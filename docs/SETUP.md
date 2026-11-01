# Set up Sofa Remote

## 1. Install on the Mac

Requires macOS 14 or later, Apple silicon or Intel. Download the disk image from the [public beta release](https://github.com/allamaprabhuani/sofa-remote/releases/tag/preview-v0.1.0-beta.13), open it and drag **Sofa Remote** to **Applications**. Eject the disk image, then open the app from Applications.

This preview is certificate-signed, **not Apple-verified or Developer ID notarised**. macOS may block first launch. If you trust the source and intentionally downloaded this beta, review the blocked-app option in **System Settings → Privacy & Security**. Availability depends on macOS and device-management policy. Do not disable Gatekeeper globally or paste commands from an untrusted issue. Building from the [source](../README.md#build-from-source) is another development option.

## 2. Allow mouse and keyboard control

In Sofa Remote, choose **Open Accessibility settings**. Enable Sofa Remote in **System Settings → Privacy & Security → Accessibility**, then return to the app. This lets a paired phone control your logged-in desktop. Screen Recording is not required.

If the phone still reports missing permission, check that the enabled entry points to the installed copy. Quit any duplicate copy, reopen Applications → Sofa Remote and check permission again. The first move from an older ad-hoc build to the persistent certificate identity may require one manual permission review. Later certificate-signed updates must keep the same signing identity; see [Signing](SIGNING.md). If the switch is on but a fresh diagnostic preview still reports missing access after restarting, remove only Sofa Remote from the list, add the current Applications copy again, and enable it yourself. Do not grant permissions automatically or enable unrelated apps.

## 3. Connect the phone

Keep the Mac awake and both devices on a trusted private network. In the Mac app, choose **Show pairing code**, scan the QR with iPhone Camera and open the link in Safari. A six-digit code can also be entered manually at the displayed address. Pairing expires after five minutes or when its window closes.

Direct local HTTP is unencrypted. For encrypted network transport, connect both devices to your own Tailscale tailnet and scan the Mac's displayed Tailscale IP link. Check your tailnet access policy. Never enable router port forwarding or a public tunnel for Sofa Remote. Custom HTTPS proxies and Tailscale hostnames are not supported by this beta's Host policy.

## 4. Try the touchpad and save it

In **About & Help → Setup and connection help**, open the disposable practice window, or use your own empty test window. Move one finger on the phone touchpad and tap once to click; tap twice quickly to double-click. Use two fingers to scroll and the Drag button to drag. Open **Shortcuts** for the keyboard, presenter controls, websites and saved apps/sites. Test these controls in the disposable window before relying on them elsewhere.

In iPhone Safari, choose **Share → Add to Home Screen**. Keep that shortcut to return to the remote. If the Mac's network address changes, open a fresh QR link from the Mac instead of the old shortcut, then save the new link if necessary.

Choose **Velvet Cinema**, **Paper & Ink** or **Soft Machine** in the phone remote’s Settings. The appearance is saved in that phone’s browser. Action buttons are icon-only; their accessible names identify them to VoiceOver.

The remote’s **Settings** include **Screen off**, **Wake** and Mac brightness buttons. Brightness sends the Mac's brightness-key events; macOS and the display determine what responds, so some external displays need their own controls. Screen off affects all connected displays and macOS may lock; Wake requires the Mac to remain awake and cannot unlock it. Saved shortcuts use local initials alongside their names, without fetching icons from websites.

## Present a slideshow

Start your slideshow on the Mac in Keynote, PowerPoint or Google Slides, and keep the slideshow as the active app. On the phone, choose **Present**. Previous and Next send the Mac's left and right arrow keys; **End slideshow** sends Escape. Animated builds may consume a press before the slide changes.

Choose the display showing your audience's slides. Select **Laser**, **Pen** or **Highlight** and a colour, then touch and move on the phone's presentation pad. The ring shows your position on the pad, and a matching marker appears on the display while you touch it. The pad is a control surface: it does not show or stream the slide. The laser disappears when you lift your finger; highlights disappear about 2½ seconds after you finish each stroke. Pen marks are temporary, are not saved to the presentation, and clear when you change slides, close Present, or lose connection for 30 seconds. Undo and Clear remove marks. The overlay may not be included when sharing only an app window; share the display if your meeting software supports it. Full-screen stacking and display configurations vary, so try it with your setup before a presentation.

Open **Stroke options** to enable smoothing or shape correction for pen and highlighter strokes. Both are off by default. Shape correction attempts near-straight lines and closed circles after you lift your finger; other strokes remain freehand. Try these options before presenting to see whether they suit your drawing style.

The overlay has a limit of 100 strokes or 10,000 points. In this preview, reaching the limit can clear the overlay; use Clear periodically during long presentations.

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
