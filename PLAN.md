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

## Crit audio (in-flight, issue #4)

- CLEU listener on `SPELL_DAMAGE` / `SPELL_PERIODIC_DAMAGE`, source = player, `critical == true`.
- Distinct cue for Shadow Bolt (warlock flagship), generic cue for everything else.
- Throttle 0.4s. Gate on `muted` + `critAudioEnabled`.
- `/blaster crit` toggles.
- Post-MVP: per-spell config, pet crits (imp/felguard), custom audio.

## Custom Scrolling Combat Text (SCT) — planned

**Why:** Default WoW SCT anchors to the mob nameplate and gets buried underneath it in busy fights. deehoc wants readable, customizable damage/heal numbers that stay out of the nameplate's way.

**MVP scope:**

- Replace (or supplement) Blizzard's floating combat text for outgoing damage/healing from the player.
- Anchor mode options (persisted in SavedVariables):
  - `above-nameplate` — pin above target nameplate with configurable Y offset (default +40px).
  - `screen-anchor` — free-floating frame anchored to a screen point, numbers scroll upward from it (default: right of the HUD).
  - `arc` — scatter numbers in a fan from the target (post-MVP).
- Number styling:
  - Font size scales with damage relative to player's average hit (bigger = harder-hitting).
  - Crit numbers: larger, yellow, exclamation-styled ("1234!").
  - Miss/dodge/parry/immune: small red text, distinct.
  - Heal numbers: green, prefixed `+`.
- Icon support: leading spell icon (small, left of the number) for `SPELL_DAMAGE` / `SPELL_HEAL`.
- Throttle / merge: coalesce multi-hit ticks of the same spell within 100ms into one number (post-MVP toggle).
- Slash: `/blaster sct anchor <above-nameplate|screen>`, `/blaster sct scale <n>`, `/blaster sct off/on`.

**Anti-overlap logic:**

- `above-nameplate` mode uses `C_NamePlate.GetNamePlateForUnit(unit)` to attach to the actual nameplate frame, then adds a configurable Y offset so numbers float above rather than under the health bar/name text.
- Fallback when nameplate not visible: switch to `screen-anchor` for that event.

**Tech notes:**

- Events: `COMBAT_LOG_EVENT_UNFILTERED` (source = player) + `UNIT_SPELLCAST_SUCCEEDED` for cast confirmation.
- Each number = a lightweight `FontString` from a small pool (reuse to avoid GC churn).
- Animation via `OnUpdate` — float up + fade out over ~1.2s. Use `AnimationGroup` if smoother.
- No dependency on Blizzard's FCT; user can disable Blizzard's SCT separately or run both.
- Interface number check: `C_NamePlate` exists in TBC Classic 2.5.6 — verify before shipping.

**Out of scope for the SCT MVP:**

- Incoming damage/heals on player (post-MVP).
- Pet damage (post-MVP).
- Advanced physics/scatter (post-MVP `arc` mode).
- LibSharedMedia integration.

## Post-MVP

- Real chiptune samples (custom `Sound\` folder, mp3/ogg).
- Per-class palette (paladin gold, DK green, etc.).
- "GUN-1 / GUN-2 / GUN-3" weapon indicator = current weapon-swap set (MH/OH icons).
- Vehicle UI takeover ("SOPHIA MODE") when in a WoW vehicle.
- LibSharedMedia / LibDBIcon integration.
- Pet crit audio (imp/felguard/etc.).
- SCT incoming damage/heals + arc mode + spell coalescing toggle.

## Deliverables

- `BlasterMaster.toc`, `BlasterMaster.lua`, `Media/icon.png`.
- `README.md`, `CHANGELOG.md`, `.gitignore`, `.curseforge.json` (after CF wiring).
- GitHub repo `lemillermicrosoft/BlasterMaster`, public.
- CurseForge project (deehoc-created).
