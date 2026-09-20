# Supabase

Server-side schema for Immortal Cultivation.

Project ref: `wjyrvzkzwjkfvgiodllt` (region Seoul, free tier — **pauses after ~7 days idle**).
Client constants live in `systems/backend.gd` (`SUPABASE_URL`, `SUPABASE_KEY`).

These files are verbatim copies of the six saved queries in the Supabase SQL
Editor, captured 2026-09-20. They are the source of truth for how the database
was built.

## Run order — this matters

Run in numerical order in the SQL Editor. Each file is individually idempotent
("safe to run again"), but **the set is not order-independent**: later parts
deliberately replace functions defined in earlier ones.

| # | File | Contents |
|---|------|----------|
| 1 | `setup_01_profiles_and_saves.sql` | profiles, saves |
| 2 | `setup_02_sects.sql` | sects, members, requests, chat, role actions |
| 3 | `setup_03_sect_progress.sql` | sign-in, donations, levels, research, treasury |
| 4 | `setup_04_sect_trial.sql` | Sect Trial ladder |
| 5 | `setup_05_server_locks.sql` | server-owned shop (`sect_shop_items`), trial rewards, chat rate limit |
| 6 | `setup_06_delete_account.sql` | `delete_my_account()` |

### Overrides introduced by part 5

Part 5 is not purely additive. Re-running an *earlier* part after it will
silently undo server-side protections:

- `sect_trial_claim()` — part 4 defines a version returning only Contribution.
  Part 5 replaces it with one that also computes and returns the item rewards.
  **Re-running part 4 alone strips item rewards from trial claims.**
- `send_sect_message()` — part 2 defines it without rate limiting. Part 5
  replaces it with a version enforcing one message per 3 seconds.
  **Re-running part 2 alone removes the chat rate limit.**
- `spend_contribution(int)` — part 3 grants EXECUTE to `authenticated`; part 5
  revokes it, since `buy_sect_item()` supersedes it.
  **Re-running part 3 alone re-exposes the unrestricted spend function.**

If you re-run any of parts 2, 3 or 4, re-run part 5 afterwards.

## Required project settings

- Anonymous sign-ins: **ON**
- Manual linking: **ON**
- Email templates must include `{{ .Token }}` (6-digit code flow)
- Custom SMTP required before shipping to testers

## Capturing the live schema (optional)

The files above are the intended history. The live database is ground truth and
may have drifted via ad-hoc changes made outside these scripts. To capture what
is actually deployed:

```bash
npx --yes supabase login
npx --yes supabase link --project-ref wjyrvzkzwjkfvgiodllt
npx --yes supabase db dump -f supabase/schema.sql
```

Run these **from the project root**, not your home directory. `db dump` requires
Docker Desktop or Podman on PATH — the CLI runs `pg_dump` in a container to match
the server's Postgres version. It prompts for the database password (Settings →
Database → Connection string), not the Supabase account login.
