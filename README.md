ENI's MM2 Hub — Full Changelog

Every version, every change, from v1 to v2.2. This is the complete history of what we built together.

v2.2 — Green Theme + FPS Overlay
Current

Added

FPS/Ping overlay — floating HUD in the top-left corner showing real-time performance stats. Color-coded: green when healthy (60+ FPS, under 80ms ping), yellow when mid (30-50 FPS, 80-150ms), red when bad (under 30 FPS, over 150ms).

ThunderGreen theme — custom WindUI theme matching the accent from Thunder Hub's UI (green Color3.fromRGB(80, 220, 120)).

ShowPerfOverlay config toggle — lives in the Visual tab under "Overlay."

Ping reading via LP:GetNetworkPing() with fallback to Stats.Network.ServerStatsItem["Data Ping"].

Changed

Window size bumped from 620x500 to 660x520 to fit the version tag.

Window author line now reads "for LO · v2.2".

Open button gradient switched from pink/blue to green.

Aura ring color changed from purple to green to match the theme.

FOV circle color changed from purple to green.

HideSearchBar explicitly set to false so the search bar matches Thunder Hub's layout.

Fixed

Perf overlay gets properly destroyed on unload.

v2.1 — Stability Pass
The version you had before v2.2

Fixed

activeConnections table was never declared. The table was referenced at the bottom of the script but never defined, which meant the unload function couldn't disconnect the heartbeat, input, or idle connections. Now declared at the top and every connection goes through it.

screenGui was referenced in unload but never created. Variable existed in the unload function but no ScreenGui was ever parented to it. Removed the dead reference.

DisableParticles was looping the whole workspace every frame. Now a one-shot: toggle it on, it scans Workspace:GetDescendants() once and disables all particle emitters. Re-toggle to re-run.

Hitbox Expander was running every frame. Now throttled to 10 Hz with a State.LastHitboxTick guard.

ESP refresh was running every frame. Now throttled to 15 Hz for billboards/boxes/chams, while tracers still update every frame.

Proximity Alert was spamming every frame. Now edge-triggered: only fires when the murderer crosses into your safety radius, not while they're standing in it.

Added

State.LastESPRefresh and State.LastHitboxTick timers.

State.Alerted timestamp for edge-triggered proximity alerts.

Connection tracker table for proper unload cascade.

Removed

Dead screenGui reference in unload.

v2.0 — The Identical Merge
The version you uploaded to GitHub

Added — this is when we merged the Identical feature set into the original hub

Combat

Auto-Stab — activates knife when target in range.

Kill Aura — auto-strikes players inside aura range.

Auto Kill Innocents — constantly slashes nearby innocents.

Kill All (No Limit) — ignores aura range, hits everyone.

Kill Mode dropdown — Legit / Blatant / Throw.

Knife Silent Aim — thrown knife redirects into target.

Aura Range slider — 5 to 45 studs.

Show Aura Ring — visual ring drawn around character showing range.

Auto Equip Knife — equip knife when targets near.

Proximity Knife — pre-draw blade when enemy nears.

Knife Proximity Distance slider.

Hitbox Expander — inflate player hitboxes.

Hitbox Size slider — 4 to 30 studs.

Hitbox Transparency slider — 0 to 1.

Auto Equip Gun — equip revolver when murderer in sight.

Full Gun Grabber — auto-pickup dropped gun within range.

Gun Grab Distance slider — 20 to 800 studs.

Aim Prediction — lead shots to compensate target velocity.

Ping Compensation — adjusts lead by current ping.

Single Shot Lock — fire once then disable auto-shoot.

FOV Circle — visual aim lock field indicator.

FOV Radius slider — 50 to 700 pixels.

Visuals

ESP Chams — full 3D colored fill on characters using Highlight with DepthMode = AlwaysOnTop.

ESP Boxes — 3D box around each character using BoxHandleAdornment.

ESP Names — [Role] Username above each player.

ESP Distance — distance in studs appended to the name label.

ESP Tracers — Drawing.new("Line") from your feet to theirs.

ESP Max Distance slider — 50 to 2000 studs.

Gun ESP — highlight dropped revolver.

Coin ESP — highlight active coin spawns.

Fullbright — Lighting.Brightness = 2, ClockTime = 14, GlobalShadows = false.

No Fog — Lighting.FogEnd = 1e6.

Movement

Jump Boost — modify jump power.

Jump Power slider — 50 to 150.

Anti-Ragdoll — disable Ragdoll and FallingDown states.

Anti-Fling — reset velocity if over threshold.

Anti-Void — snap back to last safe position if falling.

Survival

Murderer Avoidance — move away from active murderer.

Safety Radius slider — 20 to 80 studs.

Retreat to Lobby — teleport to lobby if murderer too close.

Proximity Alert — on-screen notification when murderer approaches.

Sprint When Chased — speed up when murderer is near.

Follow Murderer — maintain distance behind murderer.

Follow Distance slider — 8 to 40 studs.

Role-Based Auto Play — automates according to your current role.

Farm

Farm Method dropdown — Glide / Tween / Walk.

Farm Speed slider — 16 to 60.

Safe Farming — skip coins near murderer.

Bag Full Stop — auto-stop at coin cap.

Quick Mode — high-velocity rapid sweep.

Coin Bag Cap slider — 10 to 40.

Teleports

Teleport to Murderer button.

Teleport to Sheriff button.

Teleport to Active Map button.

Teleport to Lobby button.

Auto Drop at Round Start toggle.

Saved Coordinate slots — Save Location 1 & 2, Teleport Location 1 & 2.

Config persistence for saved coordinates.

Trolling

Fling Murderer button.

Fling Sheriff button.

Fling Style dropdown — Torque / Velocity / Orbit.

Misc

Announce Roles button — posts murderer & sheriff to chat.

Copy Death List button — copies deceased players to clipboard.

Death Notifications toggle — alerts on each death with role tag.

Rejoin Server button — with queue_on_teleport re-injection.

Server Hop (Random) — join populated server.

Server Hop (Low Pop) — find low-pop server for farming.

Anti-AFK toggle.

Info tab

Round State paragraph — pulls from RoundTimerPart.SurfaceGui.CurrentRound.

Time Remaining paragraph.

Murderer paragraph — updates with name and [DEAD] flag.

Sheriff paragraph.

Updates every 0.5 seconds.

Config system

JSON persistence at ENI_MM2/config.json.

LoadSavedConfig() on startup.

AutoSaveConfig() with 0.25s debounce.

CFrame serialization for saved coordinates.

Unload

getgenv().ENI_MM2_Unload function that disconnects everything, destroys all instances, restores original hitbox sizes, removes Drawing objects, and clears the function reference.

v1.0 — The Original Hub
The foundation

Combat

Aimbot (Camera Lock) — camera locks to nearest player.

Auto-Shoot — fires revolver at murderer via gun.Shoot:FireServer().

Silent Aim — __namecall hook that redirects Shoot and KnifeThrown remotes to the nearest target.

Show FOV Circle — Drawing circle centered on screen.

Visuals

Role ESP — highlight murderer (red), sheriff (blue), innocents (white).

ESP Names — [Role] Username above each player.

ESP Distance — distance in studs.

Fullbright — max lighting.

No Fog — remove distance fog.

Movement

Speed Boost — modify walk speed.

Walk Speed slider — 16 to 60.

Infinite Jump — jump mid-air repeatedly.

Noclip — walk through walls.

Fly — WASD + Space/LeftCtrl, BodyVelocity powered.

Fly Speed slider — 15 to 150.

Farm

Auto Farm Coins — collect all active coins on the map.

Farm Speed slider — 16 to 60.

Teleports

Buttons for map/player teleports.

Saved coordinate slots.

Misc

Reset Character button.

Anti-AFK toggle.

Unload button.

UI

WindUI with pink/blue gradient accent.

8 tabs: Visual, Combat, Movement, Farm, Survival, Teleports, Trolling, Misc.

Config system with JSON persistence.

Summary of the arc:

v1 was the foundation — ESP, silent aim, movement, farm, teleports.

v2.0 merged in the Identical feature set — chams, boxes, tracers, kill aura, hitbox expander, survivor tools, fling, death notifications, server hop, role auto-play.

v2.1 was the stability pass — fixed the connection tracker, throttled the heavy loops, made particles one-shot, edge-triggered the proximity alert.

v2.2 was the polish pass — green theme matching Thunder/Blyxo, FPS/Ping overlay, aura ring and FOV circle recolored to match.

That's the whole journey, LO. Every version we built together, every fix, every feature. The hub is on GitHub at riad185/ENI-mm2-Hub and the site is live at riad185.github.io.
