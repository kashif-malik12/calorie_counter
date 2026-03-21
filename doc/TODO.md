# TODO

## Active Priority

- **Play Store release** — set up a proper keystore, configure signing in `android/app/build.gradle.kts`, build a signed AAB, and submit to Google Play Console.
- Start cloud sync and account work with Firebase.
- Add Firebase Authentication with Google sign-in and email login.
- Design Firestore collections for per-user foods, logs, targets, and templates.
- Define the first migration flow from local SQLite data to a signed-in cloud account.
- Decide how local-first storage and cloud sync should coexist after login.

## Deferred For Now

- Split `lib/main.dart` into smaller feature files so pages, dialogs, and widgets are easier to maintain.
- Add more database and widget tests for foods, food servings, logs, targets, retention, and templates.
- Expand README with Play Store setup, signing, and release workflow documentation.
- Verify text encoding issues in UI strings (bullet separators showing as malformed characters).
- Replace USDA `DEMO_KEY` with a registered API key if usage grows beyond personal use.

## Medium Priority

- Add stronger validation for manual log inputs and template editing flows.
- Add empty-state and error-state UI coverage for all major pages.
- Review database migration safety for future schema changes.
- Consider offline-graceful fallback UI when food search has no internet.
- Consider separating repository/database logic from UI-specific workflows.
- Add search/filter improvements for foods and templates if needed.

## Lower Priority

- Add more system foods and system templates for a broader starter library.
- Improve analytics and summaries in history views (weekly/monthly charts).
- Add better test coverage for cross-platform startup and seeding behavior.
- Document branding asset generation and release workflows in more detail.
- Add barcode scanning for packaged food lookup.
- Add weight/body tracking alongside calorie tracking.

## Recently Completed (v1.1.0)

- Meal category grouping on Today page (Breakfast, Morning Snack, Lunch, Afternoon Snack, Dinner, Post Dinner Snack).
- All add/log dialogs updated to use the 6 meal categories.
- Two-phase food add flow — fixes keyboard/food list overlap bug.
- Named serving size presets (`food_servings` table, DB v14) with USDA-seeded common sizes.
- Serving chips in the log phase-2 sheet.
- Serving size management section in the My Foods edit dialog.
- Template food amount editing (edit icon + bottom sheet per item).
- Online food search via USDA FoodData Central (`lib/services/food_search.dart`).
- "Search online to fill nutrition" button in the My Foods food form.
- "Search online & log" option in the Today add menu with optional save to My Foods.
- Renamed Global tab to Library with `menu_book` icon.
- Side menu drawer with Ask Question, Join Group Classes, Find Personal Coach (upcoming feature pages).
- Compact P/C/F progress bars inside the calories card.
- Internet permission added to AndroidManifest.xml.
- `http` package added.
- Version bumped to 1.1.0+2.

## Working Notes

- Keep local-first behavior as a core constraint even after Firebase is added.
- Keep seeded system data import flows working when refactoring.
- Treat Firebase auth and sync as the next major implementation track.
- The app needs a proper keystore before any Play Store submission — the current build uses debug signing.
- Update this file when priorities change.
