# Immortal Cultivation — Project Handoff

Upload this file at the start of a new chat, plus only the scripts needed for the task at hand.

## The game
Godot 4.7 GDScript, portrait 1080×1920 mobile xianxia idle RPG (6v6 auto-battler stages). Autoloads: **GameState**, **PartnerDatabase**, **DaoIcons**, **Backend**. Home scene runs `home_battle.gd` + `screen_router.gd` (on node `LowerStack`). Screens are built in code: `res://ui/screens/<tab>_screen.gd` (tabs: Home, Growth, Mission, Codex, Events, More; quick tabs: Formation, Summon, Partner, Inventory, Guild).

## Coding rules (warnings are errors)
- Always send **complete replacement files**.
- No `:=` on untyped values (array/dict indexing, `.get()`, untyped function results) → use `var x: Type = ...`.
- Don't shadow built-ins: `size, scale, name, text, owner, free, sign, ready, open(on Window), _input, _set, _get, rpc`.
- No multi-line lambdas **inside a call's argument list** followed by more args → put the lambda in a variable first. Avoid `(x as Array)` on Variants; use `var a: Array = x`.
- Long labels must `autowrap` (unwrapped long text widened screens and once looped `screen_router`).
- Glyphs like ✓ ◆ ▸ may not exist in the Trajan font → draw shapes or use plain text.
- Popups built as `CanvasLayer`; ones used during pauses need `process_mode = ALWAYS`.

## Core systems (res://systems/ unless noted)
- **Realms** (`realms.gd`): 30 realms × 10 levels; QI_GROWTH 1.0745; `get_breakthrough_cost()`. Old 28-realm saves migrate via `GameState.OLD_28_TO_30`.
- **Damage**: `ATK² / (ATK + DEF)`. Qi income × `strength(stage)^0.35`.
- **Partners**: 200 total (White 30, Blue 27, Green 25, Purple 32, Red 44, Gold 35, Prismatic 7). Data `res://data/partners/<tier>/<id>.tres`; art `assets/partners/<tier>/<id>/card.png|sprite.png` (or `<id>_card.png`). Tools in `res://tools/`: `generate_partner_data.gd`, `apply_partner_names.gd` (names+forms), `apply_partner_daos.gd`.
- **Partner skills** (`partner_skills.gd`): families (same character across tiers share a skill) + TEMPLATES + TIER_RULES (White none, Blue 8% proc, Green 15% proc, Purple+ active; Red/Gold/Prismatic stronger).
- **Premium Reds**: evolvable Reds (15), excluded from summons/Fate/regular scrolls; only Premium Selection Scrolls (5 groups) — `summon_system.gd`.
- **Summoning**: rates/pity/×10 guarantee; scrolls before Jade; first summon guaranteed Purple; Fate Points (300 = featured Red, rotating 14 days); Selection Scrolls; `summon_screen.gd` (Summoning Altar), `summon_ceremony.gd`, `card_choice_popup.gd`.
- **Beasts** (`beasts.gd`): 45 species in 5 hunting grounds; Beast Forest (Events), taming → Soul Spirits (one per partner); Soul Land-style spirit rings (10-Year…Divine) inside spirits give stats/specials/skill boosts and awaken the Beast Skill (fires every 4th action). UI `soul_spirit_popup.gd`; partner panel scene slots `SpiritSlot`, `LifeboundSlot`.
- **Codex** (`codex.gd`, `codex_lore.gd`, `ui/screens/codex_screen.gd`): discovery, Legend/tier/ground/hunter/treasure sets → team bonus; backgrounds for all partners/beasts/treasures. `ui/bonuses_popup.gd` = All Bonuses.
- **God Path** (`gods.gd`, unlock Ascendant) + **Fallen God** (`fallen_god.gd`): windows 12/18/21 UTC-local, 3 attacks, ranking.
- **Other**: missions (chest Qi capped by `QI_STEPS_PER_HOUR`), achievements (endless chains incl. hunts, tamed, codex, tribulation, divinity, fallen god, sect trial, expeditions, login, ads), trials, tribulation, battle array, treasures, lifebound, dungeons, expeditions, alchemy.
- **Unlocks** (`unlocks.gd`): features gated by stage/realm (Inventory 5, Missions 10, Growth 20, Codex 30, Forge 40, Events/Achievements 50, Beast Forest 120, Trials 150, Sects 200, Array 300, Tribulation 500, God Path Ascendant). Router dims locked tabs and announces unlocks.
- **Tutorial** (`ui/tutorial.gd`): mentor Elder Yunhe; intro after character creation; unlock tutorials; spotlight + blockers; auto-scroll; resumes after restart (`GameState.tutorials_pending`, `tutorial_step`); tap-to-continue via `_input`.
- **Ads** (`ads.gd`, TEST_MODE fake 5 s ad): Heavenly Fortune (5/day, Events → Daily), Free Summon, Extra Beast Hunt, daily ad chests (3/6/9), ×2 offline. Real AdMob via the Poing Studios plugin; `USE_TEST_AD_UNITS := true` keeps it on Google's demo units — never ship real unit ids in development, it gets the account banned for invalid traffic.
- **Titles** (`titles.gd`): 46 titles across Arena, achievements, login, progression, collection, sect and trials. Every one held adds its bonus (they stack, spread over six stats); one is worn and shows beside your name. Standings lapse after a week or a month; titles whose condition cannot stop being true are kept. Codex tab; spec in `docs/titles.md`.
- **Arena** (`arena.gd`): 6v6 duels in your major-realm bracket, Elo, 10 duels a day plus buyable, NPC stand-ins when the bracket is thin. Standings freeze when a period closes and rewards arrive by mail — there is no claim button. Exchange sells Premium Scrolls for Arena Tokens.

## Online (Supabase, project region Seoul)
`backend.gd` autoload: SUPABASE_URL/KEY constants (re-paste after replacing the file!), anonymous guest sign-in, email+password link/login/reset via 6-digit codes, cloud save (upload ≤1/min), `delete_account()`. `ui/account_popup.gd` = welcome title screen + account screens (layer 120). SQL run in order in Supabase SQL Editor:
The scripts live in `supabase/`, numbered in the order they must run.
All 16 are applied to the live project.
1. `setup_01_profiles_and_saves.sql` profiles + saves
2. `setup_02_sects.sql` sects, members, requests, chat, role actions
3. `setup_03_sect_progress.sql` sign-in, donations, levels, research, treasury
4. `setup_04_sect_trial.sql` Sect Trial ladder
5. `setup_05_server_locks.sql` server-owned shop (`sect_shop_items`), trial rewards, chat rate limit
6. `setup_06_delete_account.sql` `delete_my_account()`
7. `setup_07_social.sql` World chat, whispers, friends, gifts, blocks, reports
8. `setup_08_codes.sql` redeem codes
9. `setup_09_arena.sql` Arena: profiles, Elo, brackets, match log
10. `setup_10_arena_shop.sql` Arena Exchange
11. `setup_11_showcase.sql` the team + gear snapshot others inspect
12. `setup_12_arena_rewards.sql` frozen standings, rewards posted to the mailbox
13. `setup_13_titles.sql` titles on the profile, carried on chat messages
14. `setup_14_code_titles.sql` a redeem code can carry a title (tester titles)
15. `setup_15_title_expiry.sql` `player_titles`, so standings lapse
16. `setup_16_sect_titles.sql` sect titles derived from membership

Every script is idempotent, so re-running one is safe.
Sects client: `sects.gd`, `sect_trial.gd`, `ui/screens/guild_screen.gd` (quiet refresh).
Social client: `chat.gd`, `friends.gd`, `ui/chat_box.gd`, `ui/friends_popup.gd`.
Arena client: `arena.gd`, `ui/arena_popup.gd`; inspect: `showcase.gd`, `ui/inspect_popup.gd`.
Titles: `titles.gd`, Codex tab in `ui/screens/codex_screen.gd`, spec in `docs/titles.md`.
Supabase settings: anonymous sign-ins ON, manual linking ON, email templates include `{{ .Token }}`; need custom SMTP before testers.

## Legal
Live at `https://treesapdew-hash.github.io/immortal-cultivation/legal/` (privacy.html, terms.html, delete-account.html). Contact cultivationimmortal0@gmail.com. URLs in `settings.gd`.

## Pre-launch checklist
- `TEST_MODE=false` in `ads.gd` and `payments.gd` (after AdMob + billing), `ENABLED=false` in `dev_cheats.gd`
- Android export + release keystore (back it up), package name fixed forever
- Play Console: content rating, 13+ audience, Data safety, contains ads, privacy + deletion links
- TrajanPro licence; IP question for novel characters
- Custom SMTP in Supabase; Supabase free projects pause after ~7 days idle

## Open / next
- **46 title banners** not generated yet: `assets/ui/titles/<id>.png`, spec
  and per-title prompts in `docs/titles.md`. Titles draw a plain tier-coloured
  plate until the art lands, so nothing is blocked. Check import settings when
  they arrive — Godot's defaults are lossless/uncapped, and the rest of the art
  uses `compress/mode=1` + `process/size_limit=1024`.
- Arena unlock is at stage 20 for alpha; raise back to 250 before launch
  (TODO in `unlocks.gd`).
- Fake leaderboards: `ranking.gd` and `fallen_god.gd` still simulate rivals
  with hardcoded names. Only the Sect Trial, Arena and profiles are real.
- Server wallet (currencies on server) before real payments; Google sign-in.
  Note a server wallet only helps if the *grants* move server-side too.
- Sect: account-safe moderation beyond report/block, red dots on Guild,
  member activity, weekly ranking
- Summon card red spikes (needs `summon_card.gd`)
- Heavenly Auction, Secret Realm, Sect Recruitment Day events; Dao Codex sets; replay tutorials in Settings
