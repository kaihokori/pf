# Trackerio – iOS Application

This repository contains the frontend iOS application for Trackerio, a complete fitness and coaching platform supporting macro tracking, workout logging, plan management, coaching interactions, progress analytics, gamification, and HealthKit integration.

The frontend is built using Swift and SwiftUI, targeting iOS 26 and above.

> [!NOTE]
> 
> This repository only contains the iOS application. The backend services, including APIs and database management, are hosted separately and are not included here.

## Theme Configuration

- The active UI theme is stored under the `selectedTheme` key in `UserDefaults` and exposed to the iOS Settings app via `Settings.bundle`.
- Users can switch themes inside the **Account → Appearance** panel or from the Settings app; both surfaces stay in sync at runtime.
- Selecting **Multicolour** restores the original Trackerio gradient backgrounds per tab, while any other theme applies a global gradient + accent override.
- Aurora, Midnight, Solar Flare, and Obsidian now ship with light/dark palettes (background + accent) so copy stays legible regardless of system appearance.
- The `ThemeManager` observable object keeps SwiftUI views updated (background gradients + accent colour) and listens for external preference changes.

## Tech Stack Summary

| Layer           | Tech                                |
| --------------- | ----------------------------------- |
| Frontend        | Swift, SwiftUI                      |

## Local Development & Testing

The new Nutrition tab interacts with the Cloud Functions API described in `/functions/src/routes`. To exercise the food library, saved meals, and daily logging views locally you will need:

- A Firebase project with Authentication enabled and an email/Apple test account.
- The Trackerio Cloud Functions instance running (or the deployed URL in `APIConfig.baseURL`).
- A valid USDA API key stored in `USDA_API_KEY` for food search.
- FatSecret API credentials configured via `FATSECRET_CLIENT_ID` and `FATSECRET_CLIENT_SECRET` Info.plist entries (or corresponding xcconfig substitutions) so the Quick Add sheet can query the FatSecret Foods Search API.

After signing in, use the Nutrition tab to:

1. Log meals for a given day (Breakfast, Lunch, Dinner, Snack) and adjust water intake.
2. Open **Foods** to search/import USDA items, create manual foods, and edit/delete saved foods.
3. Open **Saved** to create saved meals, manage their items, and apply them to the current day.

## Features (Full Application Overview)

The frontend is responsible for diplaying all major Trackerio functionality, including:

### Macro Tracking

- Daily calorie and macro targets via Mifflin-St Jeor
- Meal logging (Breakfast, Lunch, Dinner, Snacks)
- Saved meals, favourites, collections
- Water tracking
- Calorie floor/ceiling warnings
- Offline-first support with resync

### Workout Tracking

- Exercise library with filters
- Rest sets, standard sets, drop sets, failure sets
- Previous set comparisons
- Volume calculations
- Workout history and muscle highlights

### Recipe Library

- Full macro breakdown
- Tagging by meal type & dietary requirements
- Add/edit your own recipes

### Coaching Features

#### Coach Side

- Full workout + nutrition plan creation
- Assign plans to clients
- Messaging, file sharing, notes
- Session scheduling, coach → client calls
- AI-generated insights & red flags
- Client list filtering & dashboards

#### Client Side

- View & follow assigned plans
- Create personal plans
- Messaging + check-ins
- Accept coach calls

### Gamification

- Streaks
- Achievements
- Leaderboards

### Analytics

- Workout graphs
- Macro adherence trends
- Progress photos & animations
- AI insights

### HealthKit Integration

- Automatic step import
- Automatic weight & water export
- Nutrition sync

## Authentication

Authentication is handled entirely by Firebase Auth.

The only supported provider in the production app is Sign in with Apple.

## Deployment

The app is deployed to the Apple App Store using Xcode Cloud. 

## License

This project is proprietary and all rights are reserved by the author. Unauthorised use, distribution, or reproduction is strictly prohibited.

© 2025 Kyle Graham. All rights reserved.
