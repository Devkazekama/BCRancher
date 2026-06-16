[README.md](https://github.com/user-attachments/files/29013873/README.md)
Desktop Auto-Battler Game Design Document (GDD)
This document serves as the architectural foundation, game design summary, and technical roadmap for the Godot 4.x desktop pet auto-battler project.

1. Project Overview & Core Concept
A simple blending of the nostalgia of classic desktop pets (like Shimeji) with a modern, data-driven auto-battler and training mechanics (Monster Rancher/Tamagotchi).
Autonomy: Creatures live autonomously on the desktop, with players acting as caretakers rather than direct controllers.
Training & Evolution: Real-time and AFK training influence stat growth and branching evolutionary paths.
Combat: Hands-off arena battles. Players influence combat via strategy modifications ("audibles") rather than direct inputs.


2. Technical Architecture (Godot 4.x)
2.1 OS Overlay & Transparency
The game runs as a borderless, transparent window overlaid on the user's OS.

2.2 Data-Driven Creatures
Creature data is completely decoupled from the node tree using Custom Resources (CreatureData) for easy JSON serialization, network transport, and AFK progress calculation.
Data Component
Description
Implementation Example
Identity & Timestamps
Tracks age, facility assignments, and offline duration.
Time.get_unix_time_from_system()
Core Stats
Health, Strength, Agility, Intelligence.
Base integers scaled by training.
AI Combat Weights
Aggression, Defense, Mobility.
Floats (0.0 - 1.0) used by Utility AI.



3. Multiplayer Architecture
The system utilizes a dual-layer approach for maximum engagement.
Asynchronous (BaaS): Using tools like Nakama or Supabase to upload/download CreatureData JSON files for offline bracket tournaments.
Synchronous (Godot RPC): ENetMultiplayerPeer handles live duels. The Host/Server has absolute authority over AI state machines. Clients send audibles via @rpc("any_peer", "call_remote").


4. Technical Art Pipeline
To optimize overlay performance and modularity, visuals are strictly defined and separated from core logic.
4.1 Creature Sprites
Base Grid: 32x32 or 48x48. Evolved forms scale up to 64x64.
Style Requirements: High contrast 1px outlines (dark or white) to ensure readability against dynamic desktop wallpapers.
Slicing: Horizontal strips to keep the SpriteFrames resource clean.
4.2 Modular VFX & Abilities System
Abilities are defined via AbilityData (Resource). Creatures play a generic physical cast_special animation. A CastPointTimer triggers at the apex of the animation to instantiate a separate, decoupled VFX scene (64x64 grid) at a specific EffectAnchor marker.


5. Development Roadmap
Phase 1: Core Physics & Advanced Overlay: Borderless OS configuration and screen-bound physics using display safe areas.
Phase 2: Creature Systems & AFK Logic: CreatureData resource setup, JSON Save/Load implementation, and evolution triggers based on Unix timestamps.
Phase 3: Desktop AI & Player Interaction: State machines for autonomous wandering, drag-and-drop mouse physics via raycasting, and transparent UI facilities anchored to desktop corners.
Phase 4: Utility AI & Combat Execution: Data-driven combat brains driven by weights and real-time player "audible" multipliers.
Phase 5: Multiplayer & Networking: Asynchronous bracket BaaS integration and Synchronous Godot RPC live arena configuration.
Phase 6: Art Pipeline & Polish: Finalizing pixel art templates, instantiating the VFX pool, and polishing the minimalist Start Menu UI.



Technical Art Direction (Pixel Art)
To keep performance high while running as an overlay, optimize your AnimatedSprite2D configurations.
Grid Size: Use 32x32 or 48x48 canvases for the base creatures. Evolved creatures can scale to 64x64. This ensures they remain distinct but non-obtrusive on a 1080p/1440p desktop.
Slicing Strategy: Pack animations into horizontal strip SpriteSheets (e.g., 5 frames of idle = 160x32 image). This keeps the SpriteFrames resource clean.
Required Animations (State Machine Triggers):
idle (2-4 frames, looping)
walk (4-6 frames, looping)
dragged (1 frame, dangling limbs, triggered when player clicks and holds)
falling (1-2 frames, triggered upon release from a drag)
eat / interact (3 frames)
attack_light, attack_heavy, hit, faint (For the Arena)
Visual Style: High contrast outlines. Because the desktop background changes constantly based on user wallpapers and open apps, your creatures must have a distinct 1px dark or white outline to maintain readability against any background.


Technical Art Direction (VFX & Casting)
To make this modular system look good, the base creature animation and the VFX need strict framing rules.
The Generic Creature Animation (cast_special)
Grid: 32x32 or 48x48.
Frame Count: 3 to 5 frames.
Action:
Frame 1-2 (Anticipation): Creature squishes down or pulls arms back.
Frame 3 (The "Cast Point"): Creature thrusts arms forward, opens mouth wide, or points a staff. This is when cast_point_timer triggers.
Frame 4-5 (Recovery): Creature returns to idle stance.
Rule: The creature should never emit particles, colored glows, or projectiles in this spritesheet. Keep it strictly physical movement.
The VFX Sprite Sheets (vfx_scene)
Create separate scenes (e.g., VFX_Fireball.tscn, VFX_Heal.tscn) containing an AnimatedSprite2D.
Grid: 64x64. (VFX should be larger than the creature to feel impactful).
Design Prompts:
Fire Blast: 6 frames. Starts as a small bright yellow spark at the EffectAnchor, expanding into a 48x48 roaring red/orange flame burst, fading to black smoke.
Void Ripple: 5 frames. A dark purple ring that expands outward from the center, distorting the pixels behind it, thinning out until invisible.
Nature Mend (Buff): 6 frames. Spawns under the creature (adjust EffectAnchor Y-axis dynamically or via the VFX script). Green glowing leaves spiral upward in a cylinder shape.
Slicing Strategy: 1 row per effect (e.g., 384x64 image = 6 frames of 64x64). Set the AnimatedSprite2D to NOT loop, and connect its animation_finished signal to a queue_free() call so it cleans itself up from memory.


Evolution Notes

Evolution Tier
Name
Visual/Art Notes
Tier 1 (Base)
Apprentice Chick
Smallest form. Fits perfectly on a 32x32 pixel canvas. Simple 1px dark border.
Tier 2
Sous-Chef Rooster
Medium form. Can step up to a 48x48 canvas. Gains an apron and a dynamic green tail feather.
Tier 3
Head-Chef Fowl
Large form. 64x64 canvas. Decorated chef hat with gold stars and a red cravat.
Tier 4 (Mega)
Gastronomy Overlord
Final form. 64x64 canvas. Full white chef coat with double-breasted buttons.


