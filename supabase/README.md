# Fuse × Supabase

Fuse stores every fold in one table, `public.fuses`, and reads the public rows back as the
community feed. Users are signed in anonymously, so there is no account flow.

## Setup

1. **Create a project** at [supabase.com/dashboard](https://supabase.com/dashboard). Any region, free tier is fine.
2. **Run the schema.** Open *SQL Editor → New query*, paste the contents of `schema.sql`, run it.
   It creates the table, indexes and row-level-security policies, and is safe to re-run.
3. **Enable anonymous sign-ins.** *Authentication → Sign In / Providers → Anonymous sign-ins → on.*
   Without this, `record()` fails and the app shows "Anonymous sign-in failed" in Settings › Status.
4. **Paste the keys into the app.** In Fuse open *Settings › Keys* and enter
   - **Supabase project ref** — the `abcdefghijklmnop` part of `https://abcdefghijklmnop.supabase.co`
     (*Project Settings → General → Reference ID*; a full URL also works), and
   - **Supabase anon key** — *Project Settings → API Keys → anon / public*.

   Or put them in `Config/Secrets.local.xcconfig` as `SUPABASE_PROJECT_REF` / `SUPABASE_ANON_KEY` before building.

## Data model

| column | type | notes |
| --- | --- | --- |
| `id` | uuid | primary key, generated |
| `created_at` | timestamptz | server time |
| `user_id` | uuid → `auth.users` | the anonymous user who fused |
| `device` | text | e.g. `iPhone Duo` |
| `left_kind`, `right_kind` | text | `SurfaceKind` raw values |
| `left_title`, `right_title` | text | what was on each screen |
| `instruction` | text | spoken/typed instruction, if any |
| `recipe`, `title`, `summary` | text | the model's answer header |
| `artifact` | jsonb | the `FuseArtifact` JSON; `type` selects the renderer |
| `is_public` | boolean | shown in the community feed |

Policies: owners insert/select/update/delete their own rows; everyone (anon key or signed in)
can select rows where `is_public = true`.
