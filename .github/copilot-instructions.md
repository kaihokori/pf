# Pump Fitness – Copilot Instructions

## Core Context
- Frontend iOS client for Pump Fitness; server APIs live elsewhere. Keep SwiftUI-first, target iOS 16+ (current scaffolding in `Pump Fitness/Pump_FitnessApp.swift`).
- Product requirements live in `features.md`; treat it as the feature contract when planning screens, flows, and data models.
- `README.md` documents Nutrition tab expectations, Firebase + USDA dependencies, and HealthKit integration; reference it when wiring API calls.

## Architecture Expectations
- App entry point `Pump Fitness/Pump_FitnessApp.swift` launches `RootView`. Expand `RootView.swift` into a `NavigationStack`-based shell with tab scaffolding for Nutrition, Workouts, Coaching, and Analytics.
- Data must sync with Firebase (Auth + Firestore/Functions) but cache via Core Data for offline access; design models to deserialize once from Firebase responses, then persist locally before updating the UI.
- Nutrition features call the Cloud Functions API (see `APIConfig.baseURL` once added); enforce USDA API key usage for food search and respect meal-slot enums (Breakfast/Lunch/Dinner/Snack).
- Health metrics flow: ingest from HealthKit (steps, weight, water) → reconcile with Core Data cache → post to Firebase when online. Avoid duplicating samples.

## Implementation Patterns
- Use modular SwiftUI views with dependency injection for services so offline/online behavior can be unit tested without Firebase.
- Favor `ObservableObject` view models backed by `@Published` state; seed with mock data when Firebase is unavailable so previews like `#Preview` in `RootView.swift` stay functional.
- When adding new screens, accompany them with lightweight view models plus Core Data entities that mirror Firebase document IDs for conflict resolution.
- Follow navigation guidance from `.github/agents/developer.agent.md`: built around a `NavigationStack`, Firebase Auth for Sign in with Apple, Core Data caching.

## Workflows & Tooling
- Xcode is the build tool; open `Pump Fitness.xcodeproj` and run on an iOS 26+ simulator. Synchronize Firebase config (`GoogleService-Info.plist`) and USDA keys via Xcode build settings or xcconfigs.
- GitHub Actions enforce branch prefixes (`feature/`, `bugfix/`, `chore/`, `admin/`) via `.github/workflows/branch.yml`. PRs must include one type label plus exactly one release label unless the type is `admin` (`.github/workflows/pr.yml`).
- Keep API credentials out of the repo; load via Xcode secrets or runtime injection.

## Communication
- Document any new schema or API contract changes in `README.md` so mobile and backend stay aligned.
- If implementing out-of-scope features from `features.md`, call them out in PR descriptions to help reviewers verify against release labels.
