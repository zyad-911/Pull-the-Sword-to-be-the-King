# GUI Structure

The complete UI tree the game expects. Build this in Roblox Studio and the
client code will find and drive every piece.

## How to read this

- **Instance NAMES and CLASSES must match exactly** — the code resolves UI by
  name (e.g. `FindFirstChild("FillBar")`). Spelling/capitalisation matters.
- **Layout, colours, fonts, images are YOURS.** The `Size`/`Position` values
  below are just a sensible starting point — tweak them freely.
- **Almost everything is optional.** The controllers no-op on a missing
  instance, so you can build incrementally. The only hard requirement is the
  `SwordUI` ScreenGui itself.
- Items marked **[LEGACY]** are old names the code still tolerates — you can
  skip building them.
- Items marked **[NEW]** are improvement hooks — build them and I'll wire them.
- Items marked **[RENAME OK]** have an ugly legacy name. Build it as-is, OR
  rename it and tell me — I'll update the one line of code.

ScreenGuis go under **`StarterGui`** (Roblox copies them into each player's
`PlayerGui` on join).

---

## 1. SwordUI (ScreenGui) — the pull minigame

The whole click-spam minigame UI. Shown only while a player is pulling.

```
StarterGui/
└── SwordUI (ScreenGui)                Enabled=false  ResetOnSpawn=false
    ├── KeyBox (Frame)                 status-text container          [RENAME OK]
    │   └── KeyPrompt (TextLabel)      the big status text            [RENAME OK]
    ├── ProgressBar (Frame)            the pull-bar track
    │   └── FillBar (Frame)            the fill — code drives its Size
    ├── Exit (TextButton)              leave the minigame
    ├── Uses (Frame)                   consumables panel
    │   └── Buttons (Frame)
    │       ├── 5sStop  (ImageButton)  activate a 5-second Stop-Falling
    │       ├── 10sStop (ImageButton)  activate a 10-second Stop-Falling
    │       └── 1ReviveUse (ImageButton) use a revive                 [RENAME OK]
    ├── Revives (Frame)                revive-count display
    │   └── Numper (TextLabel)         the count number               [RENAME OK]
    └── Sounds (Folder)                SFX — found by name, may sit anywhere
        ├── Click (Sound)              per-click
        ├── Failed (Sound)             on fail
        ├── ChallengeCompleteSFX (Sound) on win
        └── SlipWarning (Sound)        [NEW] plays when "CLICK FASTER!" shows
```

### SwordUI (ScreenGui)
| Property | Value | Why |
|---|---|---|
| `Enabled` | **false** | The controllers turn it on only during a pull. If it starts `true`, players see the minigame UI on spawn. |
| `ResetOnSpawn` | **false** | Survive respawns. |
| `IgnoreGuiInset` | true (optional) | Lets you use the full screen. |
| `DisplayOrder` | 5 (optional) | Above the normal HUD. |

### KeyBox (Frame) → KeyPrompt (TextLabel)
The big centred status text. The code writes these strings to `KeyPrompt.Text`:

| Text | When |
|---|---|
| `CLICK THE SWORD!` | entered pulling mode, not started yet |
| `CLICK!` | playing, keeping up |
| `CLICK FASTER!` | playing, you paused — the sword is slipping |
| `FROZEN 5s` … `FROZEN 1s` | a Stop-Falling charge is active (counts down) |
| `Revive?` | you failed, a revive is offered |
| `TOO SLOW!` | you failed for good |
| `KING!` | you won |

- `KeyPrompt` must be a **TextLabel**. Set `TextScaled = true`, a bold font, a
  large size. It needs to fit `CLICK FASTER!` and `FROZEN 10s`.
- The code sets `KeyPrompt.Position = {0.5,0},{0.5,0}` — give it
  `AnchorPoint = 0.5,0.5` so it centres inside `KeyBox`.
- Put `KeyBox` in the **upper third** of the screen so it doesn't cover the
  sword the player is clicking. Suggested: `AnchorPoint 0.5,0.5`,
  `Position {0.5,0},{0.18,0}`, `Size {0.5,0},{0.14,0}`,
  `BackgroundTransparency 1`.

### ProgressBar (Frame) → FillBar (Frame)
The pull bar. The code sets `FillBar.Size = UDim2.new(progress/100, 0, 1, 0)`
every frame — so an empty bar = X-scale 0, full = X-scale 1.

- `ProgressBar`: the dark track. Suggested `AnchorPoint 0.5,0.5`,
  `Position {0.5,0},{0.86,0}`, `Size {0.5,0},{0.045,0}`.
- `FillBar`: the coloured fill. **Must be a `Frame`** — the code now tints its
  `BackgroundColor3` green while you're gaining ground and red while you're
  losing it, so an ImageLabel fill wouldn't show the feedback. Set
  `AnchorPoint 0,0.5`, `Position {0,0},{0.5,0}`, `Size {0,0},{1,0}` (the code
  overwrites the X scale every frame). A `CanvasGroup` wrapper for `ProgressBar`
  is fine — the tint is applied to the inner `FillBar` Frame.
- Add a `UICorner` to both for a rounded bar (optional, pure styling).

### Exit (TextButton)
Leaves the minigame. The code shows it before the round and hides it during
play. Suggested: top-right corner, `AnchorPoint 1,0`, `Position {0.97,0},{0.03,0}`,
`Size {0.09,0},{0.06,0}`, `Text "Exit"`.

### Uses (Frame) → Buttons (Frame) → the three consumable buttons
The consumable buttons. They auto-show only when the player owns that charge,
and hide while a freeze is running.

- `5sStop` / `10sStop` — clicking activates a Stop-Falling charge (freezes the
  sword's decay for 5 / 10 seconds). **The names must be exactly `5sStop` and
  `10sStop`** (they come from `GameConfig.StopFalling[*].buttonName`).
- `1ReviveUse` — clicking uses a revive. Only visible during the `Revive?`
  window.
- All three: `TextButton` **or** `ImageButton` (the code only needs
  `MouseButton1Click`). ImageButton with an icon looks best.
- Put a `UIListLayout` inside `Buttons` so the three stack/space neatly.
- Suggested `Uses` placement: a vertical strip on the right edge,
  `AnchorPoint 1,0.5`, `Position {0.98,0},{0.55,0}`, `Size {0.12,0},{0.4,0}`,
  `BackgroundTransparency 1`.
- **Tip:** add `[Q]` / `[E]` / `[R]` to the button labels — those are the PC
  keyboard shortcuts (`GameConfig.StopFalling[*].keybind` and `KeybindRevive`).

### Revives (Frame) → Numper (TextLabel)
Shows how many revives the player owns. The code sets `Numper.Text` to the
count and live-updates it. `Numper` must be a **TextLabel**. (`Numper` is a
legacy typo of "Number" — keep it, or rename to `Number` and tell me.)

### Sounds (Folder)
A `Folder` named `Sounds` (or any name — the code searches the whole `SwordUI`
subtree). Put four `Sound` instances inside:
- `Click` — short (<60 ms), plays on every click; keep it crisp.
- `Failed` — plays once on a fail.
- `ChallengeCompleteSFX` — plays once on a win.
- `SlipWarning` **[NEW]** — build this and I'll make it play when the prompt
  flips to `CLICK FASTER!`.

### Do NOT build (legacy — the code ignores/force-hides them)
- `StartButton` — the game now starts on the 2nd sword click.
- `MobileButtons` — the old keyboard-letter row; force-hidden if present.

### Created automatically at runtime — do NOT build
- `EmberVFX` (Frame) — `UiFxController` adds this under `SwordUI` to host the
  ember fire effect. You'll see it appear in-game; leave it alone.

---

## 2. Main (ScreenGui) — the overworld HUD

Shown while walking around; hidden during a pull.

```
StarterGui/
└── Main (ScreenGui)                   Enabled=true  ResetOnSpawn=false
    ├── MusicRunning (TextButton/ImageButton)  shown when music is ON  → click to mute
    ├── MusicMuted   (TextButton/ImageButton)  shown when music is OFF → click to unmute
    └── ShopButton   (TextButton/ImageButton)  [NEW] opens the shop
```

- `MusicRunning` / `MusicMuted` — the mute toggle. Exactly one is visible at a
  time; the code swaps them. Put them in a corner.
- `ShopButton` **[NEW]** — opens the shop panel below.

---

## 3. ShopFrame (recommended) — buying the consumables

The game sells X2 Click, Stop-Falling charges, and Revives, but there is
currently **no in-game buy UI** — players can only get them off the Roblox
store page. Build this panel and I'll write a `ShopController` that wires every
button to the correct `MarketplaceService` purchase prompt.

```
StarterGui/Main/
└── ShopFrame (Frame)                  Visible=false
    ├── Close       (TextButton)       closes the shop
    ├── BuyX2Click  (TextButton/ImageButton)  → X2 Click gamepass
    ├── BuyStop5s   (TextButton/ImageButton)  → 5s Stop-Falling product
    ├── BuyStop10s  (TextButton/ImageButton)  → 10s Stop-Falling product
    ├── BuyRevive1  (TextButton/ImageButton)  → 1 revive product
    ├── BuyRevive2  (TextButton/ImageButton)  → 2 revives product
    └── BuyRevive3  (TextButton/ImageButton)  → 3 revives product
```

The product / gamepass IDs already exist in
[`MonetizationConfig.luau`](../src/ReplicatedStorage/Shared/Config/MonetizationConfig.luau)
— I'll point each button at the right one.

---

## 4. LoadingScreen (ScreenGui) — in ReplicatedFirst

The custom loading screen (this one already exists; documented so you don't
break it). It lives in **`ReplicatedFirst`**, not StarterGui.

```
ReplicatedFirst/
└── LoadingScreen (ScreenGui)
    └── Frame (Frame)
        ├── TextLabel (TextLabel)      shows "Loading X..." / "LOADING COMPLETE!"
        └── LoadingBar (Frame)
            └── Bar (Frame)            the fill — code drives its Size
```

---

## 5. Leaderboard boards (SurfaceGui)

Two physical board models in `Workspace`, each with a `SurfaceGui` and a server
`Script` (the `topPulling` / `topTime` scripts). Each board:

```
Workspace/<board model>/
├── SurfaceGui (SurfaceGui)
│   └── Frame (Frame)
│       └── ScrollingFrame (ScrollingFrame)   rows get cloned in here
└── <Script>                                  topPulling OR topTime
    └── FrameTemplate (Frame)                 one leaderboard row, Visible=false
        ├── Rank     (TextLabel)
        ├── Username (TextLabel)
        ├── Time     (TextLabel)   ← topPulling board only
        └── Min      (TextLabel)   ← topTime board only
```

`FrameTemplate` is a child of the **script**, hidden, cloned once per entry.

---

## 6. World objects the code depends on (already in your place)

Not GUI, but the gameplay code resolves these by name — don't rename them:

```
Workspace/
└── SwordRock (Model)
    ├── King's Sword (Model)          exact name, apostrophe + space
    │   ├── Handle (Folder/Model)
    │   │   └── CamLock (BasePart)    the camera/anchor part
    │   ├── Neon (Folder)             glowing parts
    │   ├── Blade (BasePart)
    │   ├── ClickDetector (ClickDetector)  1st click enters the minigame
    │   └── Highlight (Highlight)     glows when the player is in range
    └── BillboardGui (BillboardGui)
        └── TextLabel (TextLabel)     shows "Click to Start"

ReplicatedStorage/
└── Effects/
    └── RockEffect (BasePart w/ ParticleEmitters)   cloned onto the rock

SoundService/
├── Music, SwordMusic                 overworld + pull music
└── DayMusic, NightMusic               day/night ambiance
```

`ReplicatedStorage.RemoteEvents` is created automatically by the server — don't
build it.

---

## 7. Status / what I'll wire once you build it

Already live (no build needed):
- **Green/red `FillBar`** — tints green while you're gaining, red while losing.
- **Ember fire VFX** — `UiFxController` auto-creates the `EmberVFX` layer.

Waiting on you to build the relevant instances, then I'll wire:
1. **`SlipWarning` sound** → plays the moment the prompt flips to `CLICK FASTER!`.
2. **`ShopController`** → every `ShopFrame` button → the right purchase prompt;
   `ShopButton` / `Close` toggle the panel.
3. **Keybind hints** → I can confirm `[Q]/[E]/[R]` match `GameConfig`.

Build it, then tell me — and if you rename any **[RENAME OK]** instance, just
send me the new name and I'll update the matching line.
