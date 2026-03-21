# Read Before Any Update

Read this file before making any project update.

## Checklist

- Review `doc/PROJECT_DETAILS.md` to understand current app behavior and architecture.
- Review `doc/PROJECT_STRUCTURE.md` to confirm where code, assets, scripts, tests, and platform files live.
- Review `doc/TODO.md` to avoid duplicating work and keep changes aligned with current priorities.

## Critical Rules

- System foods and system templates must sync by stable `system_key` — do not revert to count-based seed logic.
- If a packaged system item is removed, mark it inactive during sync instead of hard deleting it.
- Keep `seed_version` and `system_key` consistent when changing packaged system data.
- Preserve the local-first design of the app.
- Do not remove or overwrite user data behavior unless the change explicitly requires it.
- Keep system-seeded foods, templates, and serving sizes working.
- Keep cross-platform Flutter targets intact unless a platform-specific change is intentional.

## Key Constants to Keep in Sync

- `_kMealCategories` in `lib/main.dart` — used in all add/log dialogs and Today page grouping. If names change, update everywhere.
- DB version in `lib/data/db.dart` — currently **14**. Increment when adding new tables or columns, and add a corresponding migration in `onUpgrade`.
- `seedSystemServings()` in `lib/data/db.dart` — update when new common system foods are added that need serving presets.

## Food Serving Rules

- `food_servings` rows are per food and store amount in the food's base unit (usually grams).
- System servings are seeded by `system_key` in `seedSystemServings()` and skipped if the food already has servings.
- Users can add/remove servings in the My Foods edit dialog.
- Serving chips appear in the log phase-2 sheet when the selected food has servings.

## Online Food Search

- Service is in `lib/services/food_search.dart`.
- Uses USDA FoodData Central with `DEMO_KEY` — suitable for personal use, rate-limited to 1,000 req/hour.
- All results are per 100g and logged as manual entries (not tied to a saved food unless "Save to My Foods" is toggled).
- Internet permission is declared in `android/app/src/main/AndroidManifest.xml`.

## Signing Note

- The current build uses debug signing — not suitable for Play Store.
- Before any Play Store submission, generate a keystore, configure it in `android/app/build.gradle.kts`, and store it securely.
- Never commit the keystore or its passwords to the repository.

## Reminder

Read this file every time before any update.
