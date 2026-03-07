# AGENTS.md — AI Agent Rules

## Repository Overview

- **App**: Asobaby — 子供向けミニゲームアプリ (Android Native / Kotlin)
- **Package**: `dev.asobaby.app`
- **Build**: Gradle (Kotlin DSL), minSdk 24, targetSdk 35

## Project Structure

```
android/app/src/main/kotlin/dev/asobaby/app/
├── GameHostActivity.kt          # ランチャー (全画面ゲームホスト)
├── UpdateActivity.kt            # アップデートチェック画面
├── games/
│   ├── GameView.kt              # ゲーム基底クラス (abstract View)
│   ├── GameInfo.kt              # ゲームメタデータ
│   ├── GameRegistry.kt          # ゲーム登録簿
│   ├── GAME_IMPLEMENTATION_GUIDE.md  # ゲーム追加の詳細ガイド
│   ├── bubbles/
│   │   └── BubblePopGameView.kt
│   └── animal/
│       └── AnimalEmojiGameView.kt
└── ui/
    └── GameSelectionActivity.kt # ゲーム選択画面
```

## Key Rules

### Git / Commits
- Commit messages in English, using conventional commit format (`feat:`, `fix:`, `chore:`, `docs:`)
- **Always work on `develop` branch**, then create a PR to `main`
- Never push directly to `main`

### Branching & PR Workflow
1. Create a feature branch from `develop` (or work on `develop` directly)
2. Push to `origin/develop`
3. Create a **Pull Request** from `develop` → `main`
4. Staging build runs automatically on PR (debug APK uploaded as artifact)
5. After merge to `main`, bump version and tag for release

### Versioning & Deployment
- Version is defined in `android/app/build.gradle.kts` (`versionName` + `versionCode`)
- **versionCode**: Increment by 1 for every release
- **versionName**: Follow semver (`major.minor.patch`)
- To deploy a release:
  1. Bump `versionName` and `versionCode` in `build.gradle.kts`
  2. Commit with `chore: bump version to X.Y.Z (versionCode N)`
  3. Create a git tag: `git tag vX.Y.Z`
  4. Push both: `git push origin main vX.Y.Z`
  5. The `build.yml` workflow builds a release APK and creates a GitHub Release

### CI/CD Workflows
| Workflow | File | Trigger | Action |
|----------|------|---------|--------|
| **Staging Build** | `.github/workflows/staging.yml` | Push to `develop`, PR to `develop`/`main` | Build debug APK, upload artifact |
| **Build & Release** | `.github/workflows/build.yml` | Push `v*` tag, PR to `main` | Build release APK, create GitHub Release |
| **Deploy Content** | `.github/workflows/deploy-content.yml` | Push to `main` (game_specs/**) | Deploy game content to Azure |

### Code Style
- Language: Kotlin
- No external libraries beyond existing dependencies (androidx, material, coroutines)
- Game rendering uses Android Canvas API — no Compose, no WebView
- Property `gameBgColor` (not `backgroundColor`) for game background color to avoid JVM signature clash with `View.setBackgroundColor()`

### Adding a New Game
1. Create `games/<game_id>/<GameName>GameView.kt` extending `GameView`
2. Register in `GameRegistry.kt`
3. See `games/GAME_IMPLEMENTATION_GUIDE.md` for full template and checklist

### Architecture
- See `GAME_ARCHITECTURE.md` (root) for overall design
- Games are `View` subclasses drawn via `Canvas`, managed by `GameHostActivity`
- `GameRegistry` is the single source of truth for available games
