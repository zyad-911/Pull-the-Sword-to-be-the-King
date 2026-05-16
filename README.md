# Pull the Sword to be the King

A Roblox experience where players compete to pull the legendary King's Sword from the rock and claim the throne.

## Gameplay

Players approach the sword embedded in the rock and initiate a pull. During the minigame, they must press reaction keys at the right time to build progress toward 100%. The first player to fill the bar becomes **King** — earning the king broadcast, a badge, and a leaderboard entry.

## Features

- **Server-authoritative minigame** — the server validates every hit, measures pull duration, awards the badge, and broadcasts the king announcement. Clients cannot fake a win.
- **Leaderboard** — fastest pull times are tracked via an ordered DataStore.
- **Persistent inventory** — revives and autoclickers purchased with Robux are saved across sessions (fixed from the legacy memory-only bug).
- **Monetisation**
  - *X2 Click* gamepass — doubles progress per hit
  - *VIP* gamepass — doubles the minutes leaderstat accrual rate
  - Autoclicker developer products (10 s / 20 s)
  - Revive developer products (1× / 2× / 3×)
- **Anti-exploit protections**
  - Proximity check before a pull session starts
  - Hit-rate limiter (< 25 hits/sec ignored)
  - Minimum pull duration floor (< 3 s rejected)
- **Ambiance** — dynamic music via `AmbianceService` and a custom loading screen.

## Project Structure

```
src/
  ReplicatedFirst/
    LoadingScreenHandler      # Loading screen UI
  ReplicatedStorage/Shared/
    Config/
      AdminConfig             # Admin user list
      GameConfig              # Tuning constants (distances, timing, progress)
      MonetizationConfig      # Product / gamepass IDs
    Net                       # Remote creation & lookup (single source of truth)
    Remotes                   # Remote name manifest
    Types                     # Shared type definitions
    Util/
      Log                     # Structured logging utility
      Maid                    # Connection cleanup utility
  ServerScriptService/Server/
    init.server               # Server bootstrap — starts all services
    AdminService              # Admin commands
    AmbianceService           # Background music management
    DataService               # Player profile persistence (minutes + inventory)
    DataStoreWrapper          # Retry-safe DataStore helper
    LeaderboardService        # Ordered leaderboard DataStore
    LeaderstatsService        # In-game leaderstats (minutes played)
    MonetizationService       # Gamepass / product purchase handling
    NotificationService       # Toast notifications
    PullingService            # Core minigame logic (server-authoritative)
  StarterPlayer/StarterPlayerScripts/Client/
    init.client               # Client bootstrap
    CameraController          # Camera lock/unlock for the sword sequence
    MusicController           # Client-side music playback
    PlayerVisibilityController# Hides other players during a pull
    PullingController         # Reaction UI and input handling
    SwordInteractionController# Sword highlight, billboard prompt, proximity check
```

## Setup

1. Install [Rojo](https://rojo.space/) (v7+).
2. In the project root, run:
   ```
   rojo serve
   ```
3. Open the place in Roblox Studio and connect via the Rojo plugin.

## Configuration

| File | What to change |
|------|---------------|
| [`GameConfig.luau`](src/ReplicatedStorage/Shared/Config/GameConfig.luau) | Timing, distances, progress tuning |
| [`MonetizationConfig.luau`](src/ReplicatedStorage/Shared/Config/MonetizationConfig.luau) | Product & gamepass IDs, VIP settings |
| [`AdminConfig.luau`](src/ReplicatedStorage/Shared/Config/AdminConfig.luau) | Admin usernames |

## Networking

See [`docs/Networking.md`](docs/Networking.md) for the full remote event contract and security model.
