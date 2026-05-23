# Game Structure — the whole Explorer

The complete instance tree the game expects, service by service. Use this as
the single source of truth for **what lives where**.

See the companion docs for deeper detail on subtrees that have their own:
- [GUI-Structure.md](GUI-Structure.md) — every UI instance (SwordUI, Main, …)
- [Networking.md](Networking.md) — every RemoteEvent and the security model

## Legend

| Symbol | Meaning |
|---|---|
| 🟦 **Rojo** | Synced from this repo (see file path) — do not duplicate in Studio |
| 🟩 **Build** | You build/keep in Studio — Rojo doesn't manage it |
| 🟧 **Runtime** | Created at runtime by code — don't pre-build |

---

## Workspace 🟩

The 3D world. Mostly yours, plus a few **required** instances:

```
Workspace/
├── SwordRock (MeshPart or Model)      🟩 the rock + sword (REQUIRED)
│   ├── King's Sword (Model)           🟩 exact name, apostrophe + space
│   │   ├── Handle (Folder/Model)
│   │   │   ├── CamLock (BasePart)     🟩 camera/anchor — everything welds to this
│   │   │   └── …other handle parts    (welded to CamLock by PullingController)
│   │   ├── Neon (Folder)              🟩 glowing parts (welded by code)
│   │   ├── Blade (BasePart)           🟩 the blade (welded by code)
│   │   ├── ClickDetector              🟩 1st sword click → enters pulling mode
│   │   └── Highlight                  🟩 glows when player is within range
│   ├── BillboardGui                   🟩
│   │   └── TextLabel                  🟩 shown when in range; "Click to Start"
│   └── RockEffect (BasePart)          🟧 cloned in from ReplicatedStorage.Effects on join
├── <topPulling board model>           🟩 fastest-pull leaderboard (see §Leaderboard boards)
├── <topTime board model>              🟩 most-minutes leaderboard
├── <ambient looping Sound>            🟩 optional — wind / forest ambiance (AmbianceService note)
├── <your map, terrain, decoration>    🟩 whatever you've built around the rock
├── Camera                             (default)
└── Terrain                            (default)
```

Touched by: [`SwordInteractionController`](../src/StarterPlayer/StarterPlayerScripts/Client/SwordInteractionController.luau),
[`PullingController`](../src/StarterPlayer/StarterPlayerScripts/Client/PullingController.luau),
[`CameraController`](../src/StarterPlayer/StarterPlayerScripts/Client/CameraController.luau),
[`PullingService`](../src/ServerScriptService/Server/PullingService.luau) (proximity check).

### Leaderboard boards

Each board is a Part (or Model) with:

```
<board>/
├── SurfaceGui                         🟩
│   └── Frame
│       └── ScrollingFrame             🟩 rows are cloned into this
└── <script>                           🟩 the topPulling OR topTime server Script
    └── FrameTemplate (Frame)          🟩 hidden row template
        ├── Rank     (TextLabel)
        ├── Username (TextLabel)
        ├── Time (TextLabel)            ← topPulling boards only
        └── Min  (TextLabel)            ← topTime boards only
```

Latest corrected script bodies live in [GUI-Structure.md](GUI-Structure.md) §5.

---

## ReplicatedStorage 🟦 + 🟧

```
ReplicatedStorage/
├── Shared (Folder)                    🟦 Rojo path: src/ReplicatedStorage/Shared/
│   ├── Config (Folder)
│   │   ├── GameConfig      (ModuleScript)  🟦 ALL gameplay tunables
│   │   ├── MonetizationConfig              🟦 product / gamepass IDs, VIP
│   │   └── AdminConfig                     🟦 admin user allowlist
│   ├── Util (Folder)
│   │   ├── Log             (ModuleScript)  🟦 prefixed logger
│   │   └── Maid                            🟦 connection-cleanup helper
│   ├── Net                 (ModuleScript)  🟦 typed remote lookup / creation
│   ├── Remotes                             🟦 the remote manifest (single source of truth)
│   └── Types                               🟦 shared Luau type exports
├── Effects (Folder)                   🟩 ParticleEmitter templates
│   └── RockEffect (BasePart)          🟩 cloned onto SwordRock by PullingController
├── RemoteEvents (Folder)              🟧 created by Net.init() on server boot
│   ├── StartPulling          (RemoteEvent)
│   ├── LeavePulling          (RemoteEvent)
│   ├── StartGameButton       (RemoteEvent)
│   ├── StartGame             (RemoteEvent)
│   ├── PullHit               (RemoteEvent)
│   ├── PullFail              (RemoteEvent)
│   ├── FailPulling           (RemoteEvent)
│   ├── SuccessPulling        (RemoteEvent)
│   ├── ProgressSync          (RemoteEvent)
│   ├── LockCamera            (RemoteEvent)
│   ├── ResetCamera           (RemoteEvent)
│   ├── HidePlayersFor        (RemoteEvent)
│   ├── RequestAutoClickers   (RemoteEvent)
│   ├── UpdateAutoClickers    (RemoteEvent)
│   ├── UseAutoClicker        (RemoteEvent)
│   ├── AutoClickerActivated  (RemoteEvent)
│   ├── UseRevive             (RemoteEvent)
│   └── CheckX2Click          (RemoteFunction)
└── SendNotification          (RemoteEvent)  🟧 lives at the ReplicatedStorage ROOT
```

See [Networking.md](Networking.md) for every remote's direction and purpose.

---

## ServerScriptService 🟦

```
ServerScriptService/
└── Server (Folder)                    🟦 Rojo path: src/ServerScriptService/Server/
    ├── init.server          (Script)          🟦 server entry point
    ├── DataService          (ModuleScript)    🟦 per-player profile + persistence
    ├── DataStoreWrapper     (ModuleScript)    🟦 retry-safe DataStore helper
    ├── NotificationService  (ModuleScript)    🟦 toast notifications (SendNotification)
    ├── LeaderstatsService   (ModuleScript)    🟦 leaderstats.Minutes accrual + VIP boost
    ├── LeaderboardService   (ModuleScript)    🟦 fastest-pull OrderedDataStore + formatter
    ├── MonetizationService  (ModuleScript)    🟦 ProcessReceipt, gamepass checks, Stop-Falling tracking
    ├── PullingService       (ModuleScript)    🟦 authoritative click-spam minigame
    ├── AdminService         (ModuleScript)    🟦 chat admin commands + bans
    └── AmbianceService      (ModuleScript)    🟦 day/night clock + music swap
```

Bootstrapped in [`init.server`](../src/ServerScriptService/Server/init.server.luau) in dependency order.

---

## ServerStorage 🟦

```
ServerStorage/    (currently empty)
```

No server-only assets.

---

## StarterPlayer 🟦

```
StarterPlayer/
├── StarterPlayerScripts/
│   └── Client (Folder)                 🟦 Rojo: src/StarterPlayer/StarterPlayerScripts/Client/
│       ├── init.client             (LocalScript)    🟦 client entry point
│       ├── CameraController        (ModuleScript)   🟦 follow + wind sway + click kick
│       ├── MusicController         (ModuleScript)   🟦 day/sword music + mute toggle
│       ├── PlayerVisibilityController              🟦 hides other players during a pull
│       ├── SwordInteractionController              🟦 1st-click entry, BillboardGui prompt
│       ├── PullingController                       🟦 the click-spam minigame UI
│       └── UiFxController                          🟦 ember VFX + freeze tint + win flash
└── StarterCharacterScripts/  (empty)
```

Controllers are required in dependency order by [`init.client`](../src/StarterPlayer/StarterPlayerScripts/Client/init.client.luau).

---

## StarterGui 🟩

```
StarterGui/
├── SwordUI (ScreenGui)                🟩 the pull-minigame UI (Enabled=false)
│   ├── KeyBox / KeyPrompt …           see GUI-Structure.md §1
│   ├── ProgressBar / FillBar (CanvasGroup + Frame)
│   ├── Exit (button)
│   ├── Uses/Buttons/{5sStop, 10sStop, 1ReviveUse}
│   ├── Revives/Numper (TextLabel)
│   ├── Sounds (Folder: Click, Failed, ChallengeCompleteSFX, SlipWarning [planned])
│   ├── EmberVFX            🟧 created by UiFxController at runtime
│   ├── FreezeOverlay       🟧 created by UiFxController at runtime
│   └── WinFlashOverlay     🟧 created by UiFxController at runtime
└── Main (ScreenGui)                   🟩 overworld HUD (Enabled=true)
    ├── MusicRunning / MusicMuted (buttons)
    └── ShopButton + ShopFrame…/      🟩 [planned] see GUI-Structure.md §3
```

Full detail per-element: [GUI-Structure.md](GUI-Structure.md).

---

## ReplicatedFirst 🟦 + 🟩

```
ReplicatedFirst/
├── LoadingScreenHandler (LocalScript)  🟦 Rojo: src/ReplicatedFirst/LoadingScreenHandler.client.luau
└── LoadingScreen (ScreenGui)           🟩 you build the template; see GUI-Structure.md §4
    └── Frame / TextLabel / LoadingBar / Bar
```

`ReplicatedFirst` runs before anything else replicates — perfect for the
loading screen.

---

## SoundService 🟩

```
SoundService/
├── Music        (Sound)                🟩 overworld music (looping)
├── SwordMusic   (Sound)                🟩 plays during a pull (looping)
├── DayMusic     (Sound)                🟩 day ambiance (looping)
└── NightMusic   (Sound)                🟩 night ambiance (looping)
```

Touched by [`MusicController`](../src/StarterPlayer/StarterPlayerScripts/Client/MusicController.luau)
and [`AmbianceService`](../src/ServerScriptService/Server/AmbianceService.luau).

---

## Lighting 🟩

`AmbianceService` rotates `Lighting.ClockTime` over a 15-minute day. You set
the look (Brightness, Ambient, Atmosphere, Sky…) — the cycle is driven from
code.

---

## DataStores 🟧

Not in the Explorer, but part of the game's state. Created on first write:

| Store | Type | Key | Value | Touched by |
|---|---|---|---|---|
| `MinutesStats` | DataStore | UserId | `{Minutes=n}` (legacy schema) | DataService |
| `PlayerInventory_v1` | DataStore | UserId | `{revives, autoClickers, hasX2Click, invVersion}` | DataService |
| `PlayerMinutes` | OrderedDataStore | UserId | integer minutes | LeaderstatsService, topTime board |
| `FastestPullTimes` | OrderedDataStore | UserId | integer **milliseconds** | LeaderboardService, topPulling board |
| `BannedPlayers` | DataStore | UserId | `true` | AdminService |

---

## Per-player runtime additions 🟧

Each `Player` gets these added when their profile loads:

```
<Player>/
├── leaderstats (Folder)                🟧 created by LeaderstatsService
│   └── Minutes (NumberValue)
├── RevivesLeft (IntValue)              🟧 mirrored from profile.revives
└── HasX2Click (BoolValue)              🟧 mirrored from profile.hasX2Click
```

`PullingController` reads `RevivesLeft` to decide whether to offer a revive,
and `Revives/Numper` (in `SwordUI`) auto-updates from its `.Changed` signal.

---

## Quick reference — every file in the Rojo project

| Path | Purpose |
|---|---|
| `src/ReplicatedStorage/Shared/Config/GameConfig.luau` | All tunable gameplay numbers |
| `src/ReplicatedStorage/Shared/Config/MonetizationConfig.luau` | Product / gamepass IDs |
| `src/ReplicatedStorage/Shared/Config/AdminConfig.luau` | Admin allowlist |
| `src/ReplicatedStorage/Shared/Util/Log.luau` | Logger |
| `src/ReplicatedStorage/Shared/Util/Maid.luau` | Connection cleanup helper |
| `src/ReplicatedStorage/Shared/Net.luau` | Remote lookup / creation |
| `src/ReplicatedStorage/Shared/Remotes.luau` | Remote manifest |
| `src/ReplicatedStorage/Shared/Types.luau` | Shared Luau types |
| `src/ServerScriptService/Server/init.server.luau` | Server bootstrap |
| `src/ServerScriptService/Server/DataService.luau` | Profile + persistence |
| `src/ServerScriptService/Server/DataStoreWrapper.luau` | DataStore retries |
| `src/ServerScriptService/Server/NotificationService.luau` | Toast notifications |
| `src/ServerScriptService/Server/LeaderstatsService.luau` | Minutes accrual |
| `src/ServerScriptService/Server/LeaderboardService.luau` | Fastest-pull store |
| `src/ServerScriptService/Server/MonetizationService.luau` | Purchases + Stop-Falling tracker |
| `src/ServerScriptService/Server/PullingService.luau` | Authoritative minigame |
| `src/ServerScriptService/Server/AdminService.luau` | Admin commands + bans |
| `src/ServerScriptService/Server/AmbianceService.luau` | Day/night + music |
| `src/StarterPlayer/StarterPlayerScripts/Client/init.client.luau` | Client bootstrap |
| `src/StarterPlayer/StarterPlayerScripts/Client/CameraController.luau` | Scriptable pull camera |
| `src/StarterPlayer/StarterPlayerScripts/Client/MusicController.luau` | Music + mute |
| `src/StarterPlayer/StarterPlayerScripts/Client/PlayerVisibilityController.luau` | Hide players during pull |
| `src/StarterPlayer/StarterPlayerScripts/Client/SwordInteractionController.luau` | Sword-entry click |
| `src/StarterPlayer/StarterPlayerScripts/Client/PullingController.luau` | Pull minigame |
| `src/StarterPlayer/StarterPlayerScripts/Client/UiFxController.luau` | Ember VFX + overlays |
| `src/ReplicatedFirst/LoadingScreenHandler.client.luau` | Custom loading screen |
| `docs/GUI-Structure.md` | Per-element UI spec |
| `docs/Networking.md` | Remote contract |
| `docs/Game-Structure.md` | This file |

---

## What you need to build vs what's already done

**You build (in Studio):**
- The 3D world (terrain, map, decoration).
- `Workspace/SwordRock` and its `King's Sword` tree (already exists in the live place).
- The two leaderboard board models in `Workspace`.
- `StarterGui/SwordUI` + `StarterGui/Main` — full spec in [GUI-Structure.md](GUI-Structure.md).
- `ReplicatedFirst/LoadingScreen` ScreenGui template.
- `SoundService` sounds: Music, SwordMusic, DayMusic, NightMusic.
- Lighting look (the cycle is automated).

**Already done in code (Rojo):**
- Every server service.
- Every client controller (including the new ember VFX, freeze tint, win flash).
- All shared modules and configs.
- The loading screen handler logic.

**Created at runtime — leave alone:**
- `ReplicatedStorage/RemoteEvents/*` (Net builds them on boot).
- `SwordUI/EmberVFX`, `SwordUI/FreezeOverlay`, `SwordUI/WinFlashOverlay` (UiFxController).
- `Player/leaderstats`, `Player/RevivesLeft`, `Player/HasX2Click` (DataService).
- `SwordRock/RockEffect` (cloned by PullingController).
