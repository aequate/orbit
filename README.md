# Orbit

A visual way to learn computer science. Ideas live on a 3D map you can turn and zoom, and each one can be read, built step by step, or played as a simulation. It is designed for visual learners, and especially for people with aphantasia who can't picture things in their mind.

Understanding first, spectacle second.

## What's in it

- **Map**: 52 ideas across six areas (maths, how computers work, data, algorithms, networks, machine learning). Drag to turn it, pinch to zoom, and tap an idea to see what it needs and what it unlocks. The **Tower** layout stacks foundations at the bottom and advanced ideas at the top.
- **Read / Build / Play**: each idea has three depths of explanation, a diagram that builds one step at a time, and, where it helps, a simulation of the real algorithm that you can scrub through.
- **Before this**: the full chain of prerequisites in order, so nothing is assumed.
- **Where this leads**: why an idea matters, shown as a path to the bigger ideas it makes possible.
- **Compare**: two ideas side by side, one aspect per row.
- **Ask**: "Explain like I'm 12", analogies, steps and examples. On iOS 26 with Apple Intelligence, answers come from Apple's on-device model. Everywhere else they come from Orbit's reviewed notes. Every answer says which source it used.
- **Journeys**: guided routes through the map.
- **Review**: ideas you mark "I get it" come back on a spaced schedule, as questions about how they connect.
- **Aphantasia mode**: opens each idea on the visual build and keeps every caption so far on screen. The tutor never asks you to imagine anything.

All content is written by hand and linked to sources. Nothing leaves the device.

## Layout

```
App/                  SwiftUI app (iOS 17+)
Packages/OrbitKit/    content, graph queries, layouts, simulations, review scheduling; platform-free and tested on Linux
project.yml           XcodeGen spec
.github/workflows/    CI: tests, then an IPA
```

## Building

There is no Xcode project in the repo; XcodeGen generates it.

- **CI**: every push to `main` runs the OrbitKit tests on Linux and macOS, then the app tests on a simulator, and uploads `Orbit-unsigned.ipa` as a workflow artifact. Pushing a `v*` tag also attaches the IPA to a GitHub Release.
- **Locally on a Mac**: `brew install xcodegen && xcodegen generate && open Orbit.xcodeproj`.
- **OrbitKit without a Mac**: `swift test --package-path Packages/OrbitKit` (works in the `swift:6.1` Docker image).

## Installing on an iPhone

The unsigned IPA can be sideloaded with AltStore or Sideloadly using your own Apple ID.

To have CI produce a signed IPA instead, add these repository secrets:

| Secret | Value |
| --- | --- |
| `IOS_CERTIFICATE_P12` | base64 of your signing certificate (.p12) |
| `IOS_CERTIFICATE_PASSWORD` | its password |
| `IOS_PROVISIONING_PROFILE` | base64 of the provisioning profile for `app.orbit.learn` |
| `IOS_TEAM_ID` | optional, read from the profile if missing |
| `IOS_EXPORT_METHOD` | optional, defaults to `release-testing` (ad hoc) |
