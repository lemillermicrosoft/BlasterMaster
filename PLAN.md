# BlasterMaster — PLAN

## Vision

An 8-bit love letter to Blaster Master (NES, 1988), reimagined as a WoW combat HUD. Your character is Jason; your HP is SOPHIA's ARMOR; your primary resource is AMMO. Engaging an elite or boss triggers a "BOSS ROOM" breach banner with a chiptune sting. The whole thing lives in a pixel-art frame, muted or loud depending on how much your groupmates hate you.

## Scope (MVP)

1. **Retro HUD frame** — anchored (default: top-center-ish, above player frame), draggable, pixelated border. Shows:
   - `ARMOR` bar = player HP (green → yellow → red, blocky segments)
   - `AMMO` bar = primary resource (mana/rage/energy/focus)
   - Small "PILOT" nameplate = player name + level
2. **BOSS ROOM alert** — on `PLAYER_TARGET_CHANGED` / `UNIT_TARGET`, if target `classification` is `worldboss`/`rareelite`/`elite`/`rare`, flash a full-width red banner "!! BOSS ROOM !!" with the boss name for ~2s. Cooldown 10s per unique GUID.
3. **8-bit sound cues** — use built-in WoW sounds as stand-ins for NES chiptune:
   - enter combat → laser-ish
   - low HP crossing threshold → siren loop (throttled)
   - killing blow (`PARTY_KILL`) → 1-up
   - `PLAYER_LEVEL_UP` → fanfare
4. **`/blaster` slash command** — `toggle`, `mute`, `reset` (position), plus `hud`, `hp <0-1>` (threshold).
5. **SavedVariables** — position, enabled, muted, lowHpThreshold. Per-character optional (post-MVP).

## Technical tasks

- [ ] Frame construction with pixelated backdrop (use `Interface\Buttons\WHITE8x8` tiling for the blocky look).
- [ ] HP + power bar update loop on `UNIT_HEALTH`, `UNIT_POWER_UPDATE`, `UNIT_MAXHEALTH`, `UNIT_DISPLAYPOWER`.
- [ ] Boss classification detector w/ GUID cooldown table.
- [ ] Sound dispatcher w/ mute gate + per-cue throttle.
- [ ] Drag handler → persist point/relPoint/x/y.
- [ ] Options: keep it slash-only for MVP; no config UI.

## QA

- Load in TBC Classic 2.5.6 (`_anniversary_` client) with no errors.
- Toggle each slash subcommand.
- Target a rare elite (or fake via `/run` script) → banner fires once, not repeatedly.
- Drop below 25% HP → siren fires once, not on every heartbeat tick.
- `/reload` preserves position + mute state.

## Post-MVP

- Real chiptune samples (custom `Sound\` folder, mp3/ogg).
- Per-class palette (paladin gold, DK green, etc.).
- "GUN-1 / GUN-2 / GUN-3" weapon indicator = current weapon-swap set (MH/OH icons).
- Vehicle UI takeover ("SOPHIA MODE") when in a WoW vehicle.
- LibSharedMedia / LibDBIcon integration.

## Deliverables

- `BlasterMaster.toc`, `BlasterMaster.lua`, `Media/icon.png`.
- `README.md`, `CHANGELOG.md`, `.gitignore`, `.curseforge.json` (after CF wiring).
- GitHub repo `lemillermicrosoft/BlasterMaster`, public.
- CurseForge project (deehoc-created).
