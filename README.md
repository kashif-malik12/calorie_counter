# CalorieFit

CalorieFit is a local-first Flutter calorie and nutrition tracking app.

## Features

- Daily food logging with meal categories (Breakfast, Morning Snack, Lunch, Afternoon Snack, Dinner, Post Dinner Snack)
- Named serving size presets per food (e.g. "1 egg", "1 tbsp") — tap to prefill when logging
- Online food search via USDA FoodData Central — auto-fill nutrition or log directly
- My Foods library with full nutrition editing
- Global food and meal template library (system-seeded)
- Meal template creation, editing, and import from system library
- Edit food amounts inside meal templates
- Macro and calorie progress bars with compact nutrient display
- Per-date and default macro targets with BMI / calorie tools
- History view with date picker
- Data retention setting with automatic cleanup
- Side menu with community features (upcoming)

## Tech Stack

- Flutter (Dart) — Material 3
- SQLite via `sqflite` / `sqflite_common_ffi`
- `shared_preferences` for settings
- `http` for USDA food search
- Local-first — no account or internet required (search is optional)

## Getting Started

```bash
flutter pub get
flutter run
```

Targets: Android, iOS, macOS, Linux, Windows, Web.

## Version

Current version: **1.1.0+2**
Database version: **14**
