# Networking contract

All remotes are now defined in **one place**:
`ReplicatedStorage.Shared.Remotes` (the manifest) and created/served by
`ReplicatedStorage.Shared.Net`.

- The **server** creates every remote on boot (`Net.init()`), including the
  `ReplicatedStorage.RemoteEvents` folder and the root `SendNotification`.
  You no longer hand-create remotes in Studio.
- The **client** waits for them via `Net.event(name)` / `Net.func(name)`.
- Names and locations are unchanged from the original published place, so any
  instance still referencing them keeps working.

## Events (in `ReplicatedStorage.RemoteEvents`)

| Name | Direction | Purpose |
|------|-----------|---------|
| `StartPulling` | c→s | **1st sword click** — server proximity-checks, hides players, locks camera. Does NOT open a session yet (no decay) |
| `LeavePulling` | c→s / s→c | Client asks to exit; server confirms and tears the world back down |
| `StartGameButton` | c→s | **2nd sword click** (or the legacy Start button) — server `openSession`: the decay starts. Idempotent |
| `StartGame` | s→c | Server authorised the minigame to begin |
| `PullHit` | c→s | One sword click — server validates pace, credits `ProgressPerHit` (X2-aware) |
| `PullFail` | c→s | Player abandoned (exit / disconnect) and is not reviving |
| `FailPulling` | s→c | **Server** declares the pull failed (sword fully decayed) |
| `SuccessPulling` | s→c | **Server** declares the player KING (authoritative) |
| `ProgressSync` | s→c | Throttled push (~20Hz) of the authoritative progress so the client bar can't visibly drift from the server |
| `LockCamera` | s→c | Lock camera onto the sword |
| `ResetCamera` | s→c | Restore the player camera |
| `HidePlayersFor` | s→c | List of player names to hide (`{}` = show all) |
| `RequestAutoClickers` | c→s | Ask for current Stop-Falling charge inventory (legacy name) |
| `UpdateAutoClickers` | s→c | Push Stop-Falling charge inventory (legacy name) |
| `UseAutoClicker` | c→s | Consume a Stop-Falling charge (arg = freeze seconds; legacy name) |
| `AutoClickerActivated` | s→c | Decay frozen for N seconds (legacy name) |
| `UseRevive` | c→s | Consume a revive and continue the session |

## Functions (in `ReplicatedStorage.RemoteEvents`)

| Name | Direction | Purpose |
|------|-----------|---------|
| `CheckX2Click` | c→s invoke | Returns whether the player owns the X2 Click gamepass |

## Root of `ReplicatedStorage`

| Name | Direction | Purpose |
|------|-----------|---------|
| `SendNotification` | s→c | `{ Title, Text }` toast |

## Security model

The minigame is **server-authoritative**. The client renders the sword and
reports each click (`PullHit`), but:

- The server paces hits — anything faster than `GameConfig.MinHitIntervalSeconds`
  (~16/sec) is ignored — counts progress, and **alone** decides the win.
  Third-party autoclickers above the human ceiling are throttled here.
- The server runs its own decay tick (`DecayPerSecondActive` while the player is
  clicking, `DecayPerSecondIdle` once they stop) and **alone** decides the fail
  by firing `FailPulling` when its authoritative progress hits zero.
- A paid **Stop Falling** charge (`UseAutoClicker`) is validated server-side:
  the player must own a charge of that duration, can't stack a second freeze,
  and the freeze window is the server's record — `MonetizationService.isDecayFrozen`
  is what makes the decay tick skip. A client can't fake a freeze it didn't buy.
- `ProgressSync` pushes the authoritative progress to the client ~20Hz; the
  client only snaps its bar on a large drift so the displayed bar stays honest.
- The server measures the pull duration off its own clock and submits the
  leaderboard time — the client can no longer report a fake time.
- The badge and the king broadcast happen server-side after a validated win.

This removes the legacy exploits where a client could fire `SuccessPulling`,
`BadgeEvent`, or a forged `PullingTime` to instantly become king.

Removed legacy remotes: `BadgeEvent` (server now awards internally) and
`PullingTime` (server now measures duration). `FailurePulling` is replaced by
`PullFail`.

## VFX

`ReplicatedStorage.Effects.RockEffect` is still the single sword VFX part,
cloned into `workspace.SwordRock` by the client.
