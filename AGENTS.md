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
- **Always work on a feature branch** (`feat/xxx`, `fix/xxx`), then create a PR to `main`
- Never push directly to `main`

### Branching & PR Workflow
1. Create a feature branch from `main` (e.g. `feat/new-game`, `fix/bubble-crash`)
2. Run `./scripts/bump-version.sh` to auto-bump CalVer (or CI will block the PR)
3. Push to `origin/<branch>` and create a **Pull Request** → `main`
4. Staging build + version check run automatically on PR
5. After merge to `main`, release is **automatic** (tag + APK + GitHub Release)

### Versioning & Deployment
- **CalVer** format: `YY.M.patch` (e.g. `26.3.0` = March 2026)
- **versionCode**: Simple incremental integer (must increase each release)
- Version is defined in `android/app/build.gradle.kts` as `val calVersion = "..."`
- `./scripts/bump-version.sh` auto-bumps version if it matches main (local pre-commit helper)
- CI `check-version.yml` **blocks PRs** where version has not been bumped
- On merge to `main`:
  1. `build.yml` reads `calVersion` from `build.gradle.kts`
  2. Auto-creates git tag `v<calVersion>`
  3. Builds release APK and creates GitHub Release
  4. **No manual tagging needed**
- For multiple releases in the same month, increment the patch: `26.3.0` → `26.3.1`

### Debug vs Release APK
| | Debug (dev) | Release (production) |
|---|---|---|
| **App ID** | `dev.asobaby.app.dev` | `dev.asobaby.app` |
| **App label** | "Asobaby Dev" | "Asobaby" |
| **Version suffix** | `-dev` | (none) |
| **Debuggable** | Yes | No |
| **Minified** | No | Yes (R8) |
| **Co-install** | Both can be installed side-by-side on same device |

### CI/CD Workflows
| Workflow | File | Trigger | Action |
|----------|------|---------|--------|
| **Staging Build** | `.github/workflows/staging.yml` | PR to `main` | Build debug APK, upload artifact |
| **Check Version** | `.github/workflows/check-version.yml` | PR to `main` (runs automatically, no approval needed) | Block if version not bumped |
| **Build & Release** | `.github/workflows/build.yml` | Push to `main` (merge) | Auto-tag, build release APK, create GitHub Release |
| **Deploy Content** | `.github/workflows/deploy-content.yml` | Push to `main` (game_specs/**) | Deploy game content to Azure |
| **Setup Branch Protection** | `.github/workflows/setup-branch-protection.yml` | Manual (`workflow_dispatch`) | Configures required status check on `main` |

> **⚠️ One-time setup required**: Run the **Setup Branch Protection** workflow once (Actions → Setup Branch Protection → Run workflow) to enforce the version check as a required status check. Without this, PRs can be merged even when the check fails.

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
