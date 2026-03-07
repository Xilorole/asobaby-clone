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
- Push to `origin/main`

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
