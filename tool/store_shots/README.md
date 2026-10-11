# Store screenshots

How the images under `store/` were made.

1. Copy `shots.dart.txt` to `lib/shots.dart`. It is kept here as text
   because its imports are relative to `lib/`.
2. `flutter build web --release -t lib/shots.dart`
3. In a folder with Playwright installed (`npm install playwright`,
   `npx playwright install chromium`), run for each device:
   - `node store_shots.js <repo>/store/phone 360 720 3` (1080 x 2160)
   - `node store_shots.js <repo>/store/tablet-7in 600 960 2` (1200 x 1920)
   - `node store_shots.js <repo>/store/tablet-10in 800 1280 2` (1600 x 2560)
4. Delete `lib/shots.dart` again.

`shots.dart` seeds saved progress and plays the computer against itself to
reach a mid-battle position, then prints the tiles for the script to tap.
`store_shots.js` has the path to `build/web` hard-coded near the top.
