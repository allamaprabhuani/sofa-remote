# Presentation remote survey

Checked 1 November 2026. This is a review of published product documentation, not a hands-on comparison or a survey of prospective users. No demand or performance claim is established.

## Existing options

| Product | Published capability | Relevance |
| --- | --- | --- |
| [PPT Remote](https://github.com/gglanzani/ppt-remote) | Mac PowerPoint helper, phone web remote, slide navigation, laser toggle and trackpad; source available | Closest PowerPoint-specific alternative. A phone-browser remote is already an established approach. |
| [Remote for Slides](https://about.remoteforslides.com/) | Google Slides Chrome extension and phone progressive web app, connected by a six-digit code | Already serves the Google Slides use case without installing a phone app. |
| [Remotype presenter](https://remotype.custavia.com/presenter) | Mac/Windows host with iPhone/Android presentation controls; PowerPoint, Keynote and Google Slides; pointer, drawing, spotlight and timer are Premium | A broader commercial competitor; core trackpad/keyboard are free. |
| [PresentClic](https://presentclic.com/help/en/) | Browser remote with navigation, pointer and presenter features; documented Mac Keynote integration and Google Slides browser extension | Notes and previews already exist elsewhere; platform support must be checked by application rather than assuming Mac PowerPoint support. |
| [KDE Connect](https://kdeconnect.kde.org/) | Free, open-source device integration with presentation remote and virtual trackpad | Free/open-source alone is not a unique advantage. Feature availability needs platform-specific testing. |
| [Keynote Remote](https://support.apple.com/en-mo/guide/keynote-iphone/tan72233051/ios) | iPhone Keynote remote can draw and point on the presentation | Strong existing option for Keynote; it does not establish PowerPoint or Google Slides support. |

## Recommendation

Keep Sofa Remote as one small utility. If presentation support is added, make it an optional Present layout alongside its existing touchpad, rather than a separate app or transport. Its proposed benefit is the combination of a simple Mac helper, browser client, ordinary desktop input and presentation controls in one free MIT project. This combination still needs comparison with existing implementations and real-user feedback; it is not evidence that Sofa Remote is unique or better.

Start with large Next/Previous buttons, blank/resume, an explicit end-show control and the existing relative touchpad. On a small phone, the presenter watches the projected slide while using the touchpad. Do not require slide thumbnails, notes extraction or screen streaming for this first version.

Use application-specific tools: [PowerPoint for Mac](https://support.microsoft.com/en-us/accessibility/powerpoint/use-keyboard-shortcuts-to-deliver-powerpoint-presentations) documents Command-L laser, Command-P pen and Command-A arrow. [Google Slides](https://support.google.com/docs/answer/1696787?hl=en) documents arrow navigation and L for laser, plus a pen tool enabled from its slideshow menu. Do not send PowerPoint's Command-P to a Slides browser: it invokes Print. Start with an explicit app profile and check the foreground app before dispatching shortcuts. Any pen mode must release mouse-down on cancel, disconnect and leaving the mode.

Drawing without a slide preview is suitable for rough emphasis, not precise tablet-style annotation. Keep native Keynote Remote as the suggested option when direct drawing over a Keynote slide preview is needed. Verify PowerPoint and Slides on real presentations, two displays, sleep/reconnect and iPhone Safari before claiming support.

Status: research only. No presenter controls, slide preview or annotation feature ships in beta 2. The website/cleanup work remains the current release scope. No rename or paid tier is introduced by this survey.
