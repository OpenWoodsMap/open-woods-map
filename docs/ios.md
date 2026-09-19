# iOS: why there is nothing to download

OpenWoodsMap does not ship an iOS build. The code targets iOS, `app/ios/` is
intact, and the intention is that this stays true — but no build is published
and none is planned until something changes on Apple's side or on ours.

This is a distribution decision, not a technical one. It is written down because
it looks like an oversight otherwise, and because the obvious workaround is
worse than it appears.

## The short version

There is no free way to put an iOS app on someone's phone and have it keep
working. Android verifies a self-signed APK and never asks again; iOS refuses to
launch a binary unless Apple vouches for it, and outside the App Store that
vouching expires.

| Route | Cost | Expiry |
| --- | --- | --- |
| App Store | $99 USD/yr, or free with a nonprofit fee waiver | none |
| TestFlight | $99 USD/yr | 90 days per build |
| Ad Hoc, 100 devices | $99 USD/yr | about a year |
| Sideloading (SideStore/AltStore) | free | **7 days** |

## Why sideloading is disqualified

Sideloading is what most open-source iOS projects without a developer account
use, and for an emulator or a media player it is fine. For this app it is not,
and the reason is specific rather than aesthetic.

A free Apple ID issues provisioning profiles that
[expire seven days after issue](https://developer.apple.com/support/compare-memberships),
with three apps per device. When one expires the app does not degrade — it stops
launching. Refreshing means asking Apple to mint a new profile, which is a
network operation: SideStore's own
[error 1414](https://docs.sidestore.io/docs/troubleshooting/error-codes) is "No
Wi-Fi/StosVPN — SideStore cannot refresh or install applications without Wi-Fi
and LocalDevVPN". AltStore is stricter still and needs a computer on the same
network.

Worse, Apple
[documents](https://developer.apple.com/help/account/provisioning-profiles/provisioning-profile-updates/)
that for development teams created after 6 June 2021 — which is anyone setting
this up now — development- and ad-hoc-signed apps "must check in with the PPQ
service when the app is first launched... If the device can't successfully make a
connection, the app may not launch." Apple's own workaround is an *offline
provisioning profile*, valid for seven days and available only to paid members.

So the failure mode is not merely "it expires eventually". It is: refresh the app
at home on Friday, drive north, open it at the trailhead with no bars, and the
first launch on the new profile can fail. An app whose entire purpose is
answering a legal question with no signal cannot be distributed through a channel
that needs signal to keep running. Shipping it that way would hand someone a tool
that fails exactly when they are furthest from help.

An App Store app carries Apple's own signature, is never re-checked at launch,
and has no device limit. That is the only iOS channel compatible with how this
app is used.

## Why not just pay

Nothing here is opposed to the $99. It is that the project has no budget and no
revenue by design, and a recurring personal cost creates exactly the dependency
on one person that the rest of the project avoids.

The [fee waiver](https://developer.apple.com/support/fee-waiver) is real, Canada
is an eligible country, and a free app with no in-app purchases meets the app-side
conditions. The blocker is the entity: applicants must "not be an individual,
sole proprietor, or single-person business", so it requires an incorporated
not-for-profit, a D-U-N-S number registered to it, and a public website on the
organisation's own domain. That is worth doing if OpenWoodsMap should outlive one
maintainer or approach provincial ministries as an organisation. It is not worth
doing to avoid $99.

## What stays true in the code

The decision is about publishing, not about the codebase. iOS support should
remain possible without a rewrite:

- `app/ios/` stays in the repo. Bundle id `ca.openwoodsmap.openWoodsMap`,
  deployment target iOS 15.
- New packages must support iOS. Check pub.dev before adding one; a plugin with
  no iOS implementation closes this door quietly.
- Platform-specific code stays behind conditional imports, as
  `style_server_io.dart` and `offline_pack_store_io.dart` already do.
- `Info.plist` keeps its `NSAppTransportSecurity` loopback exemption, which the
  offline basemap's style server needs. See [packs.md](packs.md).
- **Track recording is Android-only in one specific way, and this is the first
  thing to fix if an iOS build is ever attempted.** `walking_location.dart` asks
  Android for a foreground service with a wake lock, because without it the OS
  stops delivering fixes the moment the screen goes off and a recorded walk comes
  out as straight lines between the times somebody looked at their phone. iOS needs
  the equivalent: `UIBackgroundModes` with `location` in `Info.plist`, plus
  `AppleSettings(allowBackgroundLocationUpdates: true,
  showBackgroundLocationIndicator: true, pauseLocationUpdatesAutomatically:
  false)`. Both halves are required — asking for background updates without the
  plist entry fails at runtime. That configuration is deliberately absent rather
  than written blind, because a plausible-looking guess nobody can run is exactly
  the kind of untested claim this file warns about, and the symptom it produces is
  a silently incomplete track rather than an error.

Nothing in `app/ios/` has ever been compiled. Treat "it should build" as an
untested claim: the first real attempt will surface CocoaPods, signing and
MapLibre issues, and the offline basemap's loopback server and MapLibre's offline
regions are the parts most likely to behave differently.

## What an iPhone owner can do today

Run the Android build in an emulator on a desktop and use it to plan before
leaving — not in the field:

- **Windows:** [BlueStacks](https://www.bluestacks.com/) or Android Studio's
  emulator. Install the APK from [Releases](https://github.com/OpenWoodsMap/open-woods-map/releases).
- **Mac:** BlueStacks Air, which requires Apple Silicon (M1–M4) and macOS 11 or
  later. Intel Macs are not supported.

Be honest with people about what this is. An emulator has no real GPS, so the
question the app exists to answer — *whose land am I standing on* — is not the
question it can answer there. What it does well is let someone read the
boundaries around a spot they are planning to visit, check a season, and
understand the rules before they leave. It is a map to study at the kitchen
table, not a tool to carry. Desktop connections also collect HTTP 429s from the
free tile endpoints far faster than a phone does, so basemap area downloads are
slower than they look; see [devtest.md](devtest.md).

## What would change this

- The project incorporates as a non-profit, making the fee waiver available.
- Someone funds the $99/yr and is willing to keep funding it.
- Apple permits durable signing outside the App Store in Canada. The EU's Digital
  Markets Act forced alternative marketplaces and web distribution, but it is
  EU-only and still requires paid membership.

Until one of those, Android is the shipped platform and the honest thing to say
is that there is no iOS build.
