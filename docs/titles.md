# Titles — design and asset list

Titles are earned from the leaderboard, achievements, login, progression
and testing. **Every title you own contributes its stat bonus
permanently**; the one you *wear* is what other cultivators see beside
your name in chat. Lives in the Codex, as a fourth tab beside Partners,
Beasts and Treasures.

## Rules

- **Bonuses stack.** Owning a title is enough — it does not need to be
  worn. Numbers are therefore small per title, because a veteran will
  hold most of them at once.
- **One worn at a time**, for display: chat, the inspect popup, the
  Arena board, the friends list.
- **Bonuses spread across five stats** so no single one balloons when
  forty titles stack. Roughly +25% to each stat for a complete set.
- **Server-granted titles cannot be earned locally.** Arena placements,
  tester titles and Founding Cultivator are awarded by the server and
  carried on the profile, the same route the showcase takes. Everything
  else is checked from the local save.

## Tiers

Reusing the existing item grade ladder (`ItemDB.GRADE_NAMES` /
`GRADE_COLORS`), so titles speak the same language as everything else.

| # | Tier | Colour | Bonus | Count |
|---|---|---|---|---|
| 0 | Common | `#c9cfd8` | +0.5% | 6 |
| 1 | Uncommon | `#5aa8ff` | +1% | 8 |
| 2 | Rare | `#4ddc7a` | +1.5% | 9 |
| 3 | Epic | `#b476ff` | +2.5% | 5 |
| 4 | Legendary | `#ff5a4d` | +4% | 6 |
| 5 | Mythical | `#ffcf4a` | +6% | 4 |
| 6 | Heaven-Defying | `#9ff6ff` | +10% | 6 |

## The titles

`STAT` is one of: `atk_pct`, `hp_pct`, `def_pct`, `crit`, `qi` (idle income).

### Arena — server-granted

| id | Name | Tier | Earned by | Stat |
|---|---|---|---|---|
| `arena_challenger` | Arena Challenger | Common | Enter the Arena once | atk_pct |
| `arena_duelist` | Arena Duelist | Uncommon | Win 10 duels | atk_pct |
| `arena_veteran` | Arena Veteran | Rare | Win 100 duels | atk_pct |
| `arena_unfallen` | The Unfallen | Legendary | Win 20 duels with no loss between | crit |
| `arena_top_ten` | Among the Ten | Epic | Finish a week in your bracket's top 10 | crit |
| `arena_champion` | Bracket Champion | Mythical | Finish a week at rank 1 | atk_pct |
| `arena_sovereign` | Sovereign of the Ring | Heaven-Defying | Rank 1 for three weeks, consecutive | crit |

### Achievements

| id | Name | Tier | Earned by | Stat |
|---|---|---|---|---|
| `ach_diligent` | Diligent | Common | 10 achievements | qi |
| `ach_accomplished` | Accomplished | Rare | 50 achievements | qi |
| `ach_completionist` | Completionist | Legendary | 150 achievements | hp_pct |
| `ach_ledger` | Heaven's Ledger | Heaven-Defying | Every achievement | hp_pct |

### Login

`login_days` (cumulative) already exists. **`login_streak` does not and
needs adding** — a small counter in `GameState`, reset when a day is
missed.

| id | Name | Tier | Earned by | Stat |
|---|---|---|---|---|
| `login_returning` | Returning Disciple | Common | 7 days total | qi |
| `login_faithful` | The Faithful | Uncommon | 30 days total | qi |
| `login_devoted` | Devoted Cultivator | Rare | 100 days total | hp_pct |
| `login_vigil` | Unbroken Vigil | Epic | 30-day streak | qi |
| `login_eternal` | Eternal Presence | Mythical | 365 days total | qi |

### Testing — redeem-code granted

These ride the existing redeem code system (`setup_08_codes.sql`), so
you hand a code to testers rather than maintaining a list.

| id | Name | Tier | Earned by | Stat |
|---|---|---|---|---|
| `tester_alpha` | Alpha Tester | Heaven-Defying | Alpha code | atk_pct |
| `tester_beta` | Beta Tester | Mythical | Beta code | hp_pct |
| `founding` | Founding Cultivator | Heaven-Defying | First 100 accounts | def_pct |

### Progression

| id | Name | Tier | Earned by | Stat |
|---|---|---|---|---|
| `realm_foundation` | Foundation Builder | Common | Reach Foundation Establishment | hp_pct |
| `realm_core` | Core Formed | Uncommon | Reach Core Formation | hp_pct |
| `realm_nascent` | Nascent Soul | Rare | Reach Nascent Soul | def_pct |
| `realm_ascendant` | The Ascendant | Epic | Reach Ascendant | def_pct |
| `realm_immortal` | Immortal Ascended | Mythical | Reach the Immortal realm | hp_pct |
| `stage_breaker` | Stage Breaker | Uncommon | Stage 500 | atk_pct |
| `stage_thousand` | Thousandfold | Rare | Stage 1000 | atk_pct |
| `stage_veil` | Beyond the Veil | Legendary | Stage 5000 | atk_pct |

### Collection

| id | Name | Tier | Earned by | Stat |
|---|---|---|---|---|
| `codex_collector` | Collector | Uncommon | 50 Codex entries | def_pct |
| `codex_archivist` | Archivist | Rare | 150 Codex entries | def_pct |
| `codex_keeper` | Keeper of Records | Heaven-Defying | Complete the Codex | def_pct |
| `beast_tamer` | Beast Tamer | Uncommon | Tame 20 beasts | hp_pct |
| `beast_soul_master` | Soul Master | Legendary | Tame all 45 | hp_pct |

### Sect

| id | Name | Tier | Earned by | Stat |
|---|---|---|---|---|
| `sect_disciple` | Sect Disciple | Common | Join a sect | def_pct |
| `sect_elder` | Sect Elder | Rare | Reach Elder | def_pct |
| `sect_master` | Sect Master | Legendary | Lead a sect | hp_pct |
| `sect_vanguard` | Trial Vanguard | Mythical | Top your sect's Trial contribution | crit |

### Trials and gods

| id | Name | Tier | Earned by | Stat |
|---|---|---|---|---|
| `trib_endurer` | Lightning Endurer | Rare | Survive a Tribulation | def_pct |
| `god_slayer` | God Slayer | Legendary | Defeat the Fallen God | crit |
| `god_defier` | Heaven Defier | Heaven-Defying | Top the Fallen God ranking | crit |
| `trial_daily` | Trialgoer | Common | Clear a Daily Trial | qi |
| `forge_master` | Forge Master | Uncommon | Refine a piece to +50 | atk_pct |
| `alchemy_sage` | Alchemy Sage | Uncommon | Brew 100 pills | qi |
| `expedition_lead` | Expedition Leader | Uncommon | Complete 50 expeditions | qi |
| `summon_fated` | Fate-Touched | Rare | Reach 300 Fate Points | crit |
| `evolve_first` | Awakener | Epic | Evolve a Premium Red | atk_pct |
| `evolve_prismatic` | Prismatic Sovereign | Heaven-Defying | Evolve a partner to Prismatic | atk_pct |

**Total: 44 titles.**

---

# Asset list

**44 banner images**, at `assets/ui/titles/<id>.png` — the filename must
match the `id` column exactly, that is how the game finds it.

## The one rule that matters

**Do not put any text in the image.** The title name is drawn in code
over the banner, so every image is an empty plaque or frame. Image
generators render text badly and inconsistently, and baked-in text
cannot be restyled or translated later. If a generated banner comes back
with lettering on it, regenerate.

## Spec

- **512 × 128 px**, transparent PNG, 4:1
- **Safe zone: the centre 400 × 72 px must stay clear and low-contrast.**
  Ornament belongs at the ends and edges. Anything busy in the middle
  will fight the title text.
- Ornament may bleed to the image edge; keep 8 px of breathing room
  around the outer frame so it doesn't clip when scaled
- Readable at **256 × 64** — that is roughly how big it sits in chat.
  Fine filigree will disappear; keep shapes bold
- Chinese xianxia / cultivation aesthetic throughout, matching the
  existing UI: dark navy grounds, gold linework, ink-wash texture

## Per-tier art direction

Each tier should be recognisable at a glance, before reading anything.

| Tier | Colour | Direction |
|---|---|---|
| Common | `#c9cfd8` | Plain stone or wooden plaque. Simple bevel, no glow, slightly worn. Humble. |
| Uncommon | `#5aa8ff` | Polished blue jade with a thin silver rim. A soft inner light. |
| Rare | `#4ddc7a` | Green jade set in bronze, small leaf or vine motifs at the ends, faint spirit mist. |
| Epic | `#b476ff` | Violet crystal in dark iron, arcane sigils at the corners, a low purple glow. |
| Legendary | `#ff5a4d` | Crimson lacquer and blackened gold, flame curling from both ends, embers. |
| Mythical | `#ffcf4a` | Imperial gold, dragon heads facing inward at each end, radiant aura, hanging tassels. |
| Heaven-Defying | `#9ff6ff` | Prismatic iridescence, celestial runes, fractured light, cracks in reality at the edges. Should look like it does not belong in the same world as the others. |

## Prompt template

Paste this and swap the bracketed parts:

> A horizontal fantasy game UI name banner, 512x128 pixels, 4:1 aspect
> ratio, transparent background, centered composition.
> **[TIER DIRECTION FROM THE TABLE ABOVE]**
> Chinese xianxia cultivation aesthetic, dark navy ground with gold
> linework, ink-wash texture.
> **[TITLE-SPECIFIC MOTIF]**
> The centre of the banner must be flat, clear and uncluttered so text
> can be placed over it later.
> **Absolutely no text, no letters, no words, no numbers, no characters
> of any kind anywhere in the image.**
> Ornamental detail only at the left and right ends. Bold readable
> shapes, no fine filigree. Game asset, clean edges, PNG with alpha.

### Worked examples

`arena_sovereign` — Sovereign of the Ring (Heaven-Defying):
> ...prismatic iridescent plaque, celestial runes, fractured light,
> cracks in reality at the edges. Two crossed spears forming an arch at
> each end, a laurel of broken blades. The centre flat and clear.
> Absolutely no text...

`tester_alpha` — Alpha Tester (Heaven-Defying):
> ...prismatic iridescent plaque, celestial runes, fractured light. A
> stylised first-dawn sun at the left end and an unfinished brushstroke
> at the right, suggesting something still being made. The centre flat
> and clear. Absolutely no text...

`login_eternal` — Eternal Presence (Mythical):
> ...imperial gold plaque, dragon heads facing inward, radiant aura,
> hanging tassels. An hourglass and a crescent moon worked into the
> ends. The centre flat and clear. Absolutely no text...

`sect_disciple` — Sect Disciple (Common):
> ...plain worn wooden plaque, simple bevel, no glow. A small sect
> banner pennant at each end. The centre flat and clear. Absolutely no
> text...

## Also needed

- `assets/items/premium_essence.png` — 256×256, transparent. A faceted
  magenta-pink crystal vial or condensed soul flame, wisps rising. Base
  `#ff7ad0`. It is distilled from salvaged Red+ cultivators, so it
  should read as refined remains rather than raw ore. Match the lighting
  of `premium_scroll.png`.
- **Optional:** `assets/ui/titles/_locked.png`, the same 512×128 plaque
  in flat grey, shown for titles not yet earned. Without it the Codex
  page can darken an owned banner instead, so this is a nice-to-have.
