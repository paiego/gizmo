# Gizmo

A single-player memory game. Each round shows one icon, drawn in code from a small part grammar. The icon leaves. You pick it from similar icons.

A correct pick scores one point. An incorrect pick costs one of three chances. At zero chances the run ends. The score is the number of correct picks. Chances do not refill. Quitting mid-run does not save a score.

Source: https://github.com/paiego/gizmo

## Layout

```text
gizmo/
  packages/rules/     pure Dart: names, grammar, colors, difficulty
  app/                Flutter client. Icons are painted here, not loaded.
  api/                Dart shelf API and Postgres migrations
```

The app and the API both depend on `packages/rules`.

## Icons

Each icon is two centered shapes, drawn in list order, first underneath. Both stay inside a circle of radius 32 centered at (50, 50). The first shape is the larger one. The second uses a smaller radius, so it sits inside the first.

| Value | What it sets |
| --- | --- |
| `kind` | Circle, square, triangle, pentagon, hexagon, or star |
| `radius` | Circumradius of this shape |
| `rotation` | Turn of this shape. A circle stores 0 |
| `color` | This shape's palette color |
| `paint` | Fill or stroke |
| `thickness` | Stroke width. A fill stores 0 |
| `points` | Star points, 4, 5, or 6. Other kinds store 0 |

Body, top, side, hole, and pulse change both shapes. The first shape uses the assembly color. The second uses another palette color. A star's inner points sit at 0.45 of its radius.

## Run locally

Prerequisites: Flutter stable, the Dart SDK that ships with it, and Docker.

From this directory:

```bash
docker compose up -d
```

That starts Postgres with database `gizmo`, user `gizmo`, password `gizmo`, on port 5432.

API, in a second terminal:

```bash
cd api
dart pub get
dart run bin/server.dart
```

`DATABASE_URL` defaults to `postgres://gizmo:gizmo@localhost:5432/gizmo`. The process listens on `0.0.0.0:8080` and applies `migrations/*.sql` before it serves.

```bash
curl http://localhost:8080/v1/health
```

App, in a third terminal:

```bash
cd app
flutter pub get
flutter run
```

Pass the API base URL with `--dart-define=API_BASE_URL=...` when it is not `http://localhost:8080`.

| Where the app runs | Base URL |
| --- | --- |
| iOS Simulator, desktop, Chrome | `http://localhost:8080` |
| Android emulator | `http://10.0.2.2:8080` |
| A phone on the same network | `http://<this-computer-lan-ip>:8080` |

Local CORS allows any origin so Chrome works.

## Tests

```bash
cd packages/rules && dart test
cd api && dart test
cd app && flutter analyze && flutter test
```

The API suite that talks to Postgres is skipped when the database is down.
