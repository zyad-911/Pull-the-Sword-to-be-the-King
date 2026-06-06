# Pull the Sword to be the King

A Roblox experience where players compete to pull the legendary King's Sword from the rock and claim the throne.

## Gameplay

Players approach the sword embedded in the rock and initiate a pull. During the minigame, they must **click (or tap) the sword as fast as they can** to drive the progress bar to 100%. Every moment, gravity drags the sword back down — pause for even a fraction of a second and it sinks faster. If it sinks all the way to 0% the pull fails. The first player to fill the bar becomes **King** — earning the king broadcast, a badge, and a leaderboard entry.

## Game Link

https://www.roblox.com/games/76195731114162/Pull-the-Sword-to-be-the-King

## Discord Server

https://discord.gg/SERg8zXDP

## Linkedin Profile

https://www.linkedin.com/in/zyad-kamal-7690193a3?utm_source=share&utm_campaign=share_via&utm_content=profile&utm_medium=ios_app

## Features

- **Server-authoritative minigame** — the server validates every hit, measures pull duration, awards the badge, and broadcasts the king announcement. Clients cannot fake a win.
- **Leaderboard** — fastest pull times are tracked via an ordered DataStore.
- **Persistent inventory** — revives and Stop-Falling charges purchased with Robux are saved across sessions (fixed from the legacy memory-only bug).
- **Monetisation**
  - *X2 Click* gamepass — doubles progress per click
  - *VIP* gamepass — doubles the minutes leaderstat accrual rate
  - *Stop Falling* developer products (5 s / 10 s) — freeze the sword's decay
  - Revive developer products (1× / 2× / 3×)
- **Anti-exploit protections**
  - Proximity check before a pull session starts
  - Hit-rate limiter (~16 hits/sec ceiling)
  - Minimum pull duration floor (< 2 s rejected)
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
    CameraController          # Smooth follow + subtle Perlin shake during the pull
    MusicController           # Client-side music playback
    PlayerVisibilityController# Hides other players during a pull
    PullingController         # Click-spam input + sword visuals + local decay mirror
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


