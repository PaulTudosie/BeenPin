# AGENTS.md

## Project
BeenPin — Flutter mobile app for urban exploration, photo-based check-ins, hidden spots, and nearby partner rewards.

## Product context
BeenPin is a premium-feeling, modern, map-first mobile app.
Core MVP:
- Users explore real places in Bucharest
- Users capture places with the in-app camera
- Captured places appear in Journey/Profile
- Hidden spots exist as a discovery layer
- Nearby partner rewards unlock based on valid captures

Android-first MVP. iOS later.

## Tech stack
- Flutter
- Dart
- Google Maps
- geolocator
- camera
- shared_preferences
- flutter_svg
- intl
- qr / reward-related UI where already present

## Working style
Make targeted, production-safe edits.
Prefer minimal diffs over broad rewrites.
Do not change unrelated files.
Do not introduce architectural churn unless explicitly requested.

## Hard constraints
- Do not add new dependencies unless explicitly requested
- Do not rename files unless required to fix a real issue
- Preserve existing navigation structure unless the task is about navigation
- Preserve existing app behavior unless the task explicitly changes behavior
- Keep imports clean and valid
- Keep null-safety correct
- Avoid placeholder/demo code unless explicitly requested

## UI and brand rules
Visual direction:
- premium minimal
- polished
- clean hierarchy
- slightly playful but not childish
- modern 2026 mobile product feel

Brand rules:
- "BeenPin" capitalization matters
- "Been" = blue
- "Pin" = green
- Maintain consistency with existing brand styling

Design system rules:
- Reuse existing theme tokens from app_colors.dart and related theme files
- Prefer existing spacing/radius/shadow conventions
- Avoid overly heavy gradients, noisy glassmorphism, or clutter
- Maintain clean card hierarchy and readable spacing
- Icons and tab bars should feel refined, not bulky

## Current code priorities
Prioritize stability and visible UX quality in:
- lib/features/map/
- lib/features/pins/
- lib/features/journey/
- lib/features/hidden/
- lib/features/notifications/
- lib/widgets/top_header.dart
- lib/widgets/sub_header_tabs.dart
- lib/core/theme/

## Known product preferences
- Tabs: Map, Pins, Hidden, Journey, and Notifications if integrated
- The top header should feel premium and compact
- The bottom/sub header should feel modern and robust, but not oversized
- Polaroid/photo cards should be straight, clean, premium, with subtle depth
- Hidden spots should feel intriguing, not loud
- Reward and spot detail surfaces should feel polished and trustworthy

## File-specific guidance
When editing:
- home_shell.dart:
  Keep a single source of truth for selected tab/index mapping
- sub_header_tabs.dart:
  Preserve enum integrity and asset path mappings
- journey_screen.dart / pins_screen.dart:
  Preserve data loading flow and existing storage integration
- map_screen.dart:
  Be careful with marker logic, anchors, popups, and navigation
- capture_store.dart:
  Preserve storage compatibility when extending persisted models

## Code quality rules
- Prefer small private helper methods for readability
- Avoid deeply nested widget trees when extractable
- Use const where appropriate
- Keep naming explicit
- Remove dead code created during the change if safe
- Do not leave TODOs unless unavoidable; if unavoidable, report them clearly

## Validation
After changes, run the smallest relevant validation set first.
Default validation:
- dart format .
- flutter analyze

If logic/storage/UI flows changed materially, also run:
- flutter test

If pubspec or dependencies changed, also run:
- flutter pub get

## Output format
After completing a task, always report:
1. files changed
2. what was implemented
3. validation run and results
4. any assumptions
5. any remaining issues or risks

## Preferred task style
Best task shape:
- one concrete objective
- clear scope
- explicit constraints
- explicit validation

If a request is broad, break it into phases and complete the highest-value phase first.