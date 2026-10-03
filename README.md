# ENI-mm2-Hub
Changelog — v2.1
Fixed:

activeConnections was never declared — the table was referenced at the bottom of the script but never defined, which meant the unload function couldn't disconnect the heartbeat, input, or idle connections. Now declared at the top and every connection goes through it.

screenGui was referenced in unload but never created — the variable existed in the unload function but no ScreenGui was ever parented to it. Removed the dead reference. WindUI handles its own UI lifecycle.

DisableParticles was looping the whole workspace every frame — the same lag you flagged earlier. Now a one-shot: when you toggle it on, it scans Workspace:GetDescendants() once and disables all particle emitters. Re-toggle to re-run if new ones spawn.

Hitbox Expander was running every frame — now throttled to 10 Hz with a State.LastHitboxTick guard. Same effect, less CPU.

ESP refresh was running every frame — now throttled to 15 Hz for the billboards/boxes/chams, while tracers still update every frame because they're cheap. This is the same fix we talked about for the earlier lag.

Proximity Alert was spamming every frame — now edge-triggered: only fires a notification when the murderer crosses into your safety radius, not while they're standing in it.

Added:

State.LastESPRefresh and State.LastHitboxTick — timers for the throttles above.

activeConnections table — tracks every connection so unload can disconnect all of them in one loop.

Unchanged:

Everything else. Same features, same UI, same layout, same toggles. This is a stability pass, not a feature pass. Wave 1 (gun grabber, kill all via Stab, candy farm) comes next once you confirm this loads clean and doesn't lag.
