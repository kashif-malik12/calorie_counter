# Project Structure

## Root

Main files and folders in the repository:

- `README.md` — project overview, features, setup.
- `pubspec.yaml` — Flutter package metadata, dependencies, and asset registration.
- `pubspec.lock` — resolved dependency versions.
- `analysis_options.yaml` — analyzer and lint configuration.
- `doc/` — project documentation for ongoing maintenance.
- `lib/` — application source code.
- `assets/` — seeded data and branding assets.
- `test/` — automated tests.
- `scripts/` — utility scripts.
- `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/` — platform targets.

## lib

Current source layout:

- `lib/main.dart`
  - App bootstrap and theme setup
  - Navigation shell (`HomeShell`) with bottom nav + side drawer
  - Today page — daily log with meal-category grouping, progress bars, add flows
  - Two-phase food add flow (select food → enter details)
  - Search online & log flow
  - My Foods page — food list, add/edit dialog with serving size management
  - Library page (Foods + Templates tabs, formerly Global)
  - System template preview page
  - Templates page (user templates)
  - Template edit page with food amount editing
  - History page
  - Upcoming feature pages (Ask Question, Join Group Classes, Find Personal Coach)
  - Online food search sheet (`_FoodSearchSheet`)
  - Shared UI helpers and formatters

- `lib/data/models.dart`
  - `Food`
  - `FoodServing` — named serving size preset for a food
  - `LogEntry`
  - `MealTemplate`
  - `MealTemplateItem`
  - `DayTotals`

- `lib/data/db.dart`
  - `MacroTargets`
  - SQLite schema creation (DB v14)
  - Schema upgrades and migrations (v1–v14)
  - System seed loading for foods, templates, and serving sizes
  - CRUD for foods, food servings, logs, targets, templates
  - Retention cleanup
  - Database reset and close helpers

- `lib/services/food_search.dart`
  - `FoodSearchResult` model
  - `searchFoodsOnline(query)` — queries USDA FoodData Central API

- `lib/settings/target_settings.dart`
  - Default macro target persistence via shared_preferences

- `lib/settings/retention_settings.dart`
  - Retention-day persistence via shared_preferences

## assets

- `assets/system_foods.json` — system food library seed data
- `assets/system_templates.json` — system meal template seed data
- `assets/branding/` — app mark, logo, splash, source icon files

## scripts

- `scripts/generate_brand_assets.ps1` — generates branding and icon assets for multiple platforms.

## test

- `test/widget_test.dart` — basic smoke test that checks the app boots.
- `test/system_seed_sync_test.dart` — verifies packaged food/template sync by `system_key`.

## Platform Folders

Android, iOS, macOS, Linux, Windows, Web.

Notable platform-specific files:
- `android/app/src/main/AndroidManifest.xml` — includes `INTERNET` permission for food search.

These folders mainly contain generated Flutter platform scaffolding plus app icons, manifests, and runner files.

## Maintenance Guidance

- Put architecture notes and change-tracking docs inside `doc/`.
- Prefer moving new logic out of `lib/main.dart` into feature files or `lib/services/`.
- Treat generated platform files carefully — only edit for platform-specific changes.
- Preserve the packaged seed-sync model when changing JSON assets or `lib/data/db.dart`.
- Keep `_kMealCategories` in sync if meal category names ever change (used in add dialogs and log grouping).
- `food_servings` seeding runs inside `ensureSystemSeeded` — update `seedSystemServings()` in `db.dart` if new common foods are added.
