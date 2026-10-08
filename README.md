4.0 — ZeroPoint GUI Port
Current

Changed

UI library swapped from WindUI to ZeroPoint GUI (JaxRol's library, raw.githubusercontent.com/JaxRol/ZeroPoint/main/GUI/ZeroPoint-GUI).

Window config now uses ZeroPoint's schema: Title, Footer, Icon, Size, Center, AutoShow, Resizable, Glow, GlobalSearch, ToggleKeybind, ShowMobileButtons, MobileButtonsSide, MobileButtonDragging, ScreenEffects, GuiEffects.

All notifications migrated to Library:Notify({Title, Description, Time}) — note ZeroPoint uses Description, not Content.

Tab creation uses Window:AddTab({Name, Icon, Description}).

Groupboxes split into AddLeftGroupbox / AddRightGroupbox throughout, matching ZeroPoint's two-column layout pattern.

Toggle/slider/dropdown API now uses (id, {Text, Default, Callback}) signature.

Keybind is now ToggleKeybind = Enum.KeyCode.RightControl in window config (was Left Ctrl in v3.1).

Settings tab is now auto-generated via Window:LoadSettingsTab({ScriptName, Name, Icon, ThemeFolder, ConfigFolder, ConfigSubFolder}).

Unload calls Library:Unload() instead of WindUI:Destroy().

Added

Home tab with Welcome groupbox and Quick Actions panel.

ZeroPoint's built-in theme manager — themes ship with the library, accessible from the auto-generated Settings tab.

ZeroPoint's built-in config manager — profiles saved to RiadHub/MM2/ folder.

Tabs got descriptions — ZeroPoint shows a subtitle under each tab name.

Preserved from v3.0

Every feature: ESP, aimbot, silent aim, kill aura, hitbox expander, gun grabber, coin farm with teleport method, murderer avoidance, fly/noclip/speed, teleports, fling suite, round-end notifications, death notifications, config persistence, emergency stop on END key, anti-AFK.

Known issues

ZeroPoint's API surface for AddKeyPicker, AddColorPicker, and AddSubPage is documented in the showcase file but I haven't tested every call. If any specific widget errors, paste me the line and I'll patch it.

Screen effects and GUI effects are off by default — they cost frames and on lower-end machines can drop you below 30 FPS.

v3.1 — Themes Tab (WindUI)
Superseded by v4.0

Added

Themes tab with 12 built-in color themes: Emerald, Amethyst, Cyan, Crimson, Sunset, Rose, Ice, Matrix, Cyber, Mono, Vapor, Forest.

Config.ActiveTheme — theme choice persists to config and applies on startup.

Themes table with full WindUI theme definitions (Accent, Dialog, Outline, Text, Placeholder, Background, Button, Icon).

setTheme(name) function — hot-swaps themes at runtime.

applyThemeToWindUI(theme) — pushes theme definition into WindUI's registry.

Changed

Removed hardcoded ThunderGreen theme.

Window Theme field now reads from Config.ActiveTheme.

Aura ring and FOV circle colors pull from CurrentTheme.Accent instead of hardcoded green.

Fixed

Theme application moved to after window creation (was applied before WindUI existed).

v3.0 — Teleport Farm, Round Reactions, Fling Suite
Superseded by v3.1

Added

Teleport farm method

New "Teleport" option in Farm Method dropdown — snaps your character directly to each coin's CFrame instead of gliding/tweening/walking.

TeleportFarmDelay slider (0.01–0.5s) — hop speed control.

Set as default farm method.

Round-end reactions

Round-state tracker — watches RoundTimerPart.SurfaceGui.CurrentRound.Text, stores State.RoundState as "Active" or "Intermission".

Round-end notifications — fires when state transitions Active → Intermission. Announced result based on your role: "Murderer survived" / "Sheriff won" / "Innocent survived".

Last round result paragraph in the Info tab.

RoundEndNotifications toggle in Misc.

Pre-round fling suite (all DETECTION RISK)

Fling Murderer (Pre-Round) — flings murderer during intermission.

Fling Sheriff (Pre-Round) — flings sheriff during intermission.

Fling Hero (Pre-Round) — flings hero role during intermission.

Fling ALL Players (Pre-Round) — flings every player in the server.

Pre-round fling loop — background coroutine firing enabled toggles every 0.5s when round state is not Active.

Fling Sheriff During Round — repeatedly flings sheriff mid-round.

Emergency stop updated — END key now kills all fling toggles along with old ones.

Changed

Script renamed from "ENI's MM2 Hub" to "Riad Hub" across window title, notifications, getgenv().RiadHub_Unload, config folder (RiadHub/config.json), ESP folder (RiadHub_ESP), perf overlay (Riad_PerfOverlay).

Farm Method dropdown now shows Teleport first.

Config default for FarmMethod changed from "Glide" to "Teleport".

Fixed

Round-state tracking was only used for Auto Drop. Now drives round-end notifications and pre-round fling gate.

v2.2 — Green Theme + FPS Overlay
Superseded by v3.0

Added

FPS/Ping overlay — floating HUD in the top-left, color-coded (green/yellow/red) by performance.

ShowPerfOverlay toggle in Visual tab under "Overlay."

ThunderGreen theme — custom WindUI theme matching the accent from Thunder Hub's UI.

Changed

Window size bumped from 620x500 to 660x520.

Window author line now reads "for LO · v2.2".

Open button gradient switched from pink/blue to green.

Aura ring color changed from purple to green.

FOV circle color changed from purple to green.

HideSearchBar explicitly set to false.

Perf overlay properly destroyed on unload.

v2.1 — Stability Pass
Superseded by v2.2

Fixed

activeConnections table was never declared. Now declared at the top and every connection goes through it.

screenGui was referenced in unload but never created. Removed dead reference.

DisableParticles was looping the whole workspace every frame. Now a one-shot.

Hitbox Expander was running every frame. Now throttled to 10 Hz.

ESP refresh was running every frame. Now throttled to 15 Hz.

Proximity Alert was spamming every frame. Now edge-triggered.

Added

State.LastESPRefresh and State.LastHitboxTick timers.

State.Alerted timestamp for edge-triggered proximity alerts.

activeConnections table for proper unload cascade.

v2.0 — The Identical Merge
Superseded by v2.1

Added

Combat

Auto-Stab, Kill Aura, Auto Kill Innocents, Kill All, Kill Mode dropdown

Knife Silent Aim, Aura Range slider, Show Aura Ring

Auto Equip Knife, Proximity Knife, Knife Proximity Distance

Hitbox Expander, Hitbox Size, Hitbox Transparency

Auto Equip Gun, Full Gun Grabber, Gun Grab Distance

Aim Prediction, Ping Compensation, Single Shot Lock

FOV Circle, FOV Radius

Visuals

ESP Chams, ESP Boxes, ESP Names, ESP Distance, ESP Tracers

ESP Max Distance slider

Gun ESP, Coin ESP

Fullbright, No Fog

Movement

Jump Boost, Jump Power

Anti-Ragdoll, Anti-Fling, Anti-Void

Survival

Murderer Avoidance, Safety Radius, Retreat to Lobby

Proximity Alert, Sprint When Chased

Follow Murderer, Follow Distance, Role-Based Auto Play

Farm

Farm Method dropdown, Farm Speed, Safe Farming

Bag Full Stop, Quick Mode, Coin Bag Cap

Teleports

Murderer/Sheriff/Map/Lobby teleport buttons

Auto Drop at Round Start

Save Location 1 & 2, Teleport Location 1 & 2

Trolling

Fling Murderer, Fling Sheriff, Fling Style dropdown

Misc

Announce Roles, Copy Death List, Death Notifications

Rejoin Server, Server Hop (Random), Server Hop (Low Pop), Anti-AFK

Info tab

Round State, Time Remaining, Murderer, Sheriff paragraphs updating every 0.5s

Config system

JSON persistence at ENI_MM2/config.json

LoadSavedConfig(), AutoSaveConfig() with 0.25s debounce

CFrame serialization for saved coordinates

Unload

Full cleanup function that disconnects connections, destroys instances, restores hitbox sizes, removes Drawing objects

v1.0 — The Original Hub
The foundation

Combat

Aimbot (Camera Lock), Auto-Shoot, Silent Aim

__namecall hook redirecting Shoot and KnifeThrown remotes

Show FOV Circle

Visuals

Role ESP — murderer (red), sheriff (blue), innocents (white)

ESP Names, ESP Distance

Fullbright, No Fog

Movement

Speed Boost, Walk Speed

Infinite Jump, Noclip, Fly, Fly Speed

Farm

Auto Farm Coins, Farm Speed

Teleports

Map/player teleport buttons

Saved coordinate slots

Misc

Reset Character, Anti-AFK, Unload

UI

WindUI with pink/blue gradient accent

8 tabs: Visual, Combat, Movement, Farm, Survival, Teleports, Trolling, Misc

Config system with JSON persistence

The arc, in one sentence per version:

v1 was the foundation — ESP, silent aim, movement, farm, teleports.
v2.0 merged in the Identical feature set — chams, boxes, tracers, kill aura, hitbox, survival, fling, notifications, server hop.
v2.1 was the stability pass — connection tracker, throttled loops, one-shot particles, edge-triggered alerts.
v2.2 was the polish pass — green theme, FPS/Ping overlay, aura/FOV recolored.
v3.0 added the teleport farm method, round-end reactions, and the pre-round fling suite.
v3.1 added the Themes tab with 12 built-in color themes on WindUI.
v4.0 is the full port to ZeroPoint GUI — same features, new interface, built-in theme and config managers.
