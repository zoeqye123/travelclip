# Project Instructions

## Project Overview

- `travelclip` is an iOS SwiftUI app for travel journaling, canvas editing, stickers, tapes, ticket templates, and local notebook storage.
- Main app sources live in `travelclip/`.
- Generated/source media lives under `generated_assets/`; bundled runtime assets live under `travelclip/Resources/`.
- The Xcode project is `travelclip.xcodeproj`; the app scheme and target are both `travelclip`.

## Product Iteration Loop

Treat Codex as a loop-driven product iteration system, not only as an executor of isolated requests. For each meaningful product change, move through this loop:

1. User scenario
   - Who uses it?
   - Is it used before, during, or after travel?
   - What concrete result does the user complete?

2. Product hypothesis
   - Why does the user open it?
   - Why does the user stay?
   - Why does the user share it?
   - Why would the user pay for it?

3. Minimum feature
   - Do not build a full suite at once.
   - Each round should deliver one verifiable closed loop.

4. Implementation
   - Codex writes the code.
   - Codex must run build/test when relevant.
   - Codex must summarize what changed.

5. Experience check
   - Review the result from the user's perspective.
   - Look for friction, misunderstanding, and ineffective functionality.

6. Next round
   - Continue iterating based on feedback.
   - Do not add random features without tying them back to the scenario and hypothesis.

## Coding Guidelines

- Prefer SwiftUI-native patterns already used in `ContentView.swift` and related files.
- Keep changes scoped. This repo currently keeps many UI types in `ContentView.swift`; follow the existing structure unless a refactor is needed for the task.
- Preserve existing user data compatibility for `Codable` models in `TravelModels.swift`. When adding model fields, provide safe defaults in custom decoders.
- Do not rewrite generated assets or large resource folders unless the task is specifically about assets.
- Avoid unrelated Xcode project churn. If adding files, make sure they are included in the `travelclip` target.
- Use plain system symbols and existing visual language unless the request asks for a new design direction.

## Useful Commands

- List project metadata:
  `xcodebuild -list -project travelclip.xcodeproj`
- Build the app:
  `xcodebuild -scheme travelclip -project travelclip.xcodeproj build`
- Simulator build fallback:
  `xcodebuild -scheme travelclip -project travelclip.xcodeproj -destination 'generic/platform=iOS Simulator' build`
- Show connected devices:
  `xcrun devicectl list devices`

## Verification

- After completing code changes, build the app and install it to a connected iPhone when possible.
- Prefer the currently connected device named `zoe` with identifier `5D3FBF08-6D09-5925-A780-FAB806A6DE21`.
- Use the `travelclip` scheme and this project file:
  `xcodebuild -scheme travelclip -project travelclip.xcodeproj`.
- If no physical iPhone is available, still run a simulator build and report that device installation was skipped.
- Do not block final delivery on installation if signing, pairing, or device availability fails; report the exact failure and the build result.

## Commit Policy

- After completing each requested change, create a focused git commit for the completed work.
- Do not include unrelated worktree changes in that commit.
- If existing uncommitted changes are required for the completed work to compile, include only the required files and call that out in the summary.

## Good Codex Prompts For This Repo

Use this shape for implementation tasks:

```text
Goal: Change <specific behavior> in travelclip.
Context: Relevant files are <files>. Current issue is <bug/feature>.
Constraints: Keep SwiftUI style consistent, preserve Codable compatibility, and avoid unrelated Xcode project changes.
Done when: The app builds with xcodebuild, and the changed flow works on simulator or device.
```

Use this shape for debugging:

```text
Reproduce: <steps and observed result>.
Expected: <expected result>.
Please inspect the relevant SwiftUI state/data flow, make a focused fix, run the build, and summarize the root cause.
```

Use this shape for UI work:

```text
Update <screen/flow> so that <target user outcome>.
Keep the travel journal/canvas editing aesthetic, ensure text does not overlap on small iPhone sizes, and verify with a build.
```
