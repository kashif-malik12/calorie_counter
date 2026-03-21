# CalorieFit Project Details

## Overview

CalorieFit is a local-first Flutter calorie tracking application.

Current project characteristics:
- Flutter app with Material 3 UI.
- Main app logic is concentrated in `lib/main.dart`.
- Local persistence uses SQLite through `sqflite`, `sqflite_common`, `sqflite_common_ffi`, and `sqflite_common_ffi_web`.
- User preferences use `shared_preferences`.
- Online food search uses `http` against the USDA FoodData Central API (no key required with DEMO_KEY).
- The app ships with seeded system foods and seeded system meal templates from JSON assets.
- Packaged system data uses sync-safe metadata with stable keys and seed versions.
- The app targets Android, iOS, macOS, Linux, Windows, and Web.

## Core Features Present

- Today tracking with meal-category grouping (Breakfast, Morning Snack, Lunch, Afternoon Snack, Dinner, Post Dinner Snack).
- Two-phase food add flow: select food first, then enter amount/category/time separately.
- Named serving size presets per food (`food_servings` table) with USDA-seeded common sizes (egg, tbsp, cup, etc.).
- Online food search via USDA FoodData Central — auto-fills the food form or logs directly as a manual entry.
- My Foods management with full nutrition editing.
- Library tab (formerly Global) for system foods and system templates.
- Importing system foods into user foods.
- Importing system templates into user templates.
- User meal template creation and editing, including editing food amounts inside templates.
- Logging food entries and manual entries.
- Daily macro totals and calorie progress card with compact P/C/F mini-bars.
- Default target settings and per-date target overrides.
- BMI and calorie helper tools.
- History view with date picker.
- Data retention setting with old-log cleanup.
- Side menu drawer with upcoming community features.
- Startup initialization gate and database bootstrap.

## Data Model Summary

### Foods
Stored in the `foods` table.

Important fields:
- `name`
- `calories`, `protein`, `carbs`, `fat`, `fiber`, `sugar`, `sodium`
- `unit` — g, ml, tbsp, tsp, cup, liter, piece, slice
- `base_amount` — 100 for g/ml, 1 for unit-based
- `is_system`, `is_active`, `category`, `system_key`, `seed_version`

Notes:
- Nutrition values are stored per `base_amount` of the given unit.
- System foods are seeded from `assets/system_foods.json`.
- User foods are stored in the same table with `is_system = 0`.
- System foods are synchronized by `system_key` and marked inactive when removed from packaged assets.

### Food Servings
Stored in the `food_servings` table (added in DB v14).

Fields:
- `food_id` — references `foods(id)`, CASCADE on delete
- `name` — display label e.g. "1 tbsp", "1 egg", "½ cup"
- `grams` — equivalent amount in the food's base unit

Notes:
- Common serving sizes are auto-seeded for system foods (egg, olive oil, butter, oats, milk, bread, etc.).
- Users can add/remove serving size presets per food in the My Foods edit dialog.
- Serving chips appear in the log phase-2 sheet for quick prefill.

### Log Entries
Stored in the `log_entries` table.

Important fields:
- `date`, `time`, `label` (meal category)
- `food_id`, `grams`, `unit`, `base_amount`
- `food_name`, `calories_100`, `protein_100`, `carbs_100`, `fat_100` (snapshot)
- `entry_type` — 'food' or 'manual'
- `manual_name`, `manual_kcal`, `manual_protein`, `manual_carbs`, `manual_fat`

Notes:
- Snapshot nutrition is stored for food logs so history is accurate even if food data changes.
- Manual entries support one-time logging without a saved food.
- Entries are grouped by `label` (meal category) on the Today page, ordered by `time` within each category.

### Day Targets
Stored in the `day_targets` table.

Fields: `date`, `calories_target`, `protein_target`, `carbs_target`, `fat_target`, `source`, `calculator_json`.

### Meal Templates
Stored in `meal_templates` and `meal_template_items`.

Capabilities:
- System templates seeded from `assets/system_templates.json`
- User-created templates
- Per-template items linked to foods, with editable amounts
- Import from system templates to user templates
- Add a template to a date as a manual log snapshot
- Active/inactive visibility for packaged templates
- Meal category selector when adding a template to the daily log

## Settings

Settings are stored with `shared_preferences`.

Modules:
- `lib/settings/target_settings.dart`
- `lib/settings/retention_settings.dart`

Defaults:
- Calories: 2000, Protein: 150g, Carbs: 200g, Fat: 70g
- Retention: 180 days

## Branding

Brand assets under `assets/branding/`.

Constants:
- Primary: `#0B3C49`
- Accent: `#3AC47D`
- Surface: `#F4FBF7`

Brand asset generation: `scripts/generate_brand_assets.ps1`

## Online Food Search

- Service: `lib/services/food_search.dart`
- API: USDA FoodData Central (`api.nal.usda.gov/fdc/v1/foods/search`)
- Key: `DEMO_KEY` (1,000 requests/hour, no sign-up)
- Data types queried: Foundation, SR Legacy (generic whole foods, per 100g)
- Nutrient IDs: 1008 (calories), 1003 (protein), 1005 (carbs), 1004 (fat), 1079 (fiber), 2000 (sugar), 1093 (sodium)
- Integration points:
  - My Foods form: "Search online to fill nutrition" button auto-fills all fields
  - Today add menu: "Search online & log" option — search, enter grams, log, optionally save to My Foods

## Testing and Quality

- `test/widget_test.dart` — basic smoke test
- `test/system_seed_sync_test.dart` — packaged food/template sync tests
- Lints via `flutter_lints`

## Important Technical Notes

- Database version: **14**
- `kResetOnStartup` in `lib/main.dart` is `false`
- Internet permission is declared in `AndroidManifest.xml` (required for food search)
- System library sync runs automatically during database open
- System foods and templates sync by stable `system_key`
- Packaged system rows not present in current assets are marked inactive instead of deleted
- Retention cleanup runs during startup via `InitGate`

## Meal Category Constants

Defined as `_kMealCategories` in `lib/main.dart`:
```
Breakfast, Morning Snack, Lunch, Afternoon Snack, Dinner, Post Dinner Snack
```
Used in all add/log dialogs and for grouping the Today page log list.

## System Seed Sync Rules

When updating `assets/system_foods.json` or `assets/system_templates.json`:
- Keep every `system_key` stable once released.
- Add new records with new `system_key` values.
- Update existing records by keeping the same `system_key`.
- Use `is_active` behavior for removals instead of deleting rows.
- System templates are refreshed from packaged assets during sync, including their item lists.

## Current Risks / Constraints

- `lib/main.dart` is very large — increases maintenance cost.
- Test coverage is minimal.
- `DEMO_KEY` for USDA API has rate limits (1,000/hour) — sufficient for personal use.
- App is signed with debug keys — needs a proper keystore before Play Store submission.
