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
| `StartPulling` | c→s | Request to begin a pull; server does a proximity check then locks camera + hides players |
| `LeavePulling` | c→s / s→c | Client asks to exit; server confirms and tears the world back down |
| `StartGameButton` | c→s | Player pressed **Start** |
| `StartGame` | s→c | Server authorised the minigame to begin |
| `PullHit` | c→s | One successful key press — **server validates pace and counts progress** |
| `PullFail` | c→s | Missed / timed out and not reviving |
| `SuccessPulling` | s→c | **Server** declares the player KING (authoritative) |
| `LockCamera` | s→c | Lock camera onto the sword |
| `ResetCamera` | s→c | Restore the player camera |
| `HidePlayersFor` | s→c | List of player names to hide (`{}` = show all) |
| `RequestAutoClickers` | c→s | Ask for current autoclicker inventory |
| `UpdateAutoClickers` | s→c | Push autoclicker inventory |
| `UseAutoClicker` | c→s | Consume an autoclicker |
| `AutoClickerActivated` | s→c | Autoclicker granted for N seconds |
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

The minigame is **server-authoritative**. The client renders the reaction UI
and reports each successful hit (`PullHit`), but:

- The server paces hits (anything faster than `GameConfig.MinHitIntervalSeconds`
  is ignored), counts progress, and **alone** decides the win.
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
