# Campus Map & Location Guide

A responsive Flutter campus guide with an illustrated, top-down schematic of a
school campus. The map shows campus paths and sample locations only; it does
not use GPS or show surrounding streets.

## Features

- Responsive home, map, search, saved places, and settings screens.
- Pan and zoom around the illustrated campus map on phones, tablets, and PCs.
- Search the campus directory and filter places by category.
- Load directory data from the Vercel serverless API at `/api/places`.
- Keep the example campus directory available when the API is offline.
- Add custom pins only inside the campus outline.
- Save places on the current device and confirm before deleting saved places.
- Persistent dark-mode preference and in-app walking-route preview.

The included map layout and place names are examples. Update the place list in
`api/places.js` and the offline fallback in `lib/services/campus_api.dart` to
match a specific school's buildings and paths before using it as a real guide.
Saved places are stored locally and are not synchronized between devices.

## Run locally

Install the Flutter SDK with Dart 3.13.5 or newer, clone this repository, and
run:

```shell
flutter pub get
flutter run
```

Run in a desktop browser:

```shell
flutter run -d chrome
```

Local runs use the bundled example locations when `/api/places` is unavailable.
The full directory endpoint is deployed with the app on Vercel.

Build the static web app:

```shell
flutter build web --release
```

The web output is written to `build/web`.

## Deploy to Vercel

Import the GitHub repository into Vercel with the repository root as the
project root. `vercel.json` runs `scripts/vercel_build.sh` to build the Flutter
Web app and configures the client-side route fallback. The `api/places.js`
serverless function serves the campus directory. The first deployment may take
longer while the build script downloads Flutter 3.47.7 on the Vercel Linux
builder. Set `FLUTTER_VERSION` in Vercel to use another compatible stable SDK
release.

## Campus layout

The schematic map is drawn locally in Flutter, so it remains available without
map tiles, a GPS signal, or a network connection. All example and custom pins
are restricted to the school-shaped campus area. Example locations are
illustrative rather than verified room or building coordinates.
