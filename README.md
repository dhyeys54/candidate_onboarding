# Dental Onboarding

A candidate uploads a CV/résumé, the app parses it and pre-fills onboarding forms, and the user
reviews/edits/submits the pre-filled data. Full-stack Rails app — no separate frontend framework/SPA;
interactivity is handled with Hotwire (Turbo/Stimulus).

The app is currently a freshly generated Rails skeleton — most domain code has not landed yet. See
`CLAUDE.md` for the target architecture (namespacing, service objects, CV parsing, background jobs) that
features should be built toward.

## Stack

* Ruby 4.0.6 (see `.ruby-version`)
* Rails 8.1.3
* PostgreSQL
* Redis (backs Sidekiq, Rails.cache, and Action Cable)
* Sidekiq (background job processing)
* Propshaft (asset pipeline)
* Importmap, Turbo, Stimulus
* Tailwind CSS

## Setup

Requirements: Ruby 4.0.6 (as pinned in `.ruby-version`), a running PostgreSQL server, and a running
Redis server (defaults to `redis://localhost:6379/0`; override with `REDIS_URL`).

CV parsing extracts text from PDF and `.docx` with pure-Ruby gems (`pdf-reader`, `docx`), but legacy
`.doc` files need the `antiword` system binary on `PATH`. It's baked into the Docker image via `apt-get`
(Debian package `antiword`). For local dev it isn't packaged in Homebrew — build it from source instead:

```
git clone https://github.com/grobian/antiword.git
cd antiword && make && make install
```

`make install` puts the binary in `~/bin` and its character-mapping resources in `~/.antiword` (no sudo
needed). Add both to your shell profile:

```
export PATH="$HOME/bin:$PATH"
export ANTIWORDHOME="$HOME/.antiword"
```

If `antiword` is missing or fails on a given file, `.doc` parsing just fails for that upload and the UI
falls back to manual form entry — it's not a hard dependency for the app to run.

```
bin/setup
```

This installs gems, prepares the database, and clears logs/tmp, then starts the dev server. Add
`--skip-server` to skip launching the server, or `--reset` to reset the database.

Gems are installed into `vendor/bundle` rather than a system/rbenv gem path (`bundle config set --local
path vendor/bundle`, stored in the gitignored `.bundle/config`). This keeps the project's gems isolated
per-checkout; each machine sets this up locally via `bin/setup` / `bundle install`, it is not committed.

## Running the app

```
bin/dev
```

Runs Rails together with the Tailwind CSS watcher and a Sidekiq worker (see `Procfile.dev`). Requires a
Redis server running locally (`REDIS_URL` defaults to `redis://localhost:6379/0`) — this also backs
Action Cable in development (`config/cable.yml`), which the CV upload flow uses to broadcast Turbo
Stream status updates from the Sidekiq worker process to the browser.

CV uploads (`Onboarding::CandidateDocument`) are capped at 25MB and restricted to PDF/DOC/DOCX by
default (`config/initializers/cv_upload.rb`); override the size limit with `CV_MAX_SIZE_MB`.

The Sidekiq Web UI is mounted at `/sidekiq`, protected by HTTP Basic Auth. Set `SIDEKIQ_WEB_USERNAME` and
`SIDEKIQ_WEB_PASSWORD` in the environment to enable access (unset in local dev means the check always
fails closed, so the UI stays inaccessible until both are set).

The `/admin` namespace (staff-only) is likewise protected by HTTP Basic Auth via `Admin::BaseController`.
Set `ADMIN_USERNAME` and `ADMIN_PASSWORD` in the environment to enable access (same fail-closed behavior
when unset). It exposes a minimal candidate list/detail view (`/admin/candidates`), scoped to submitted
profiles only, with a CV download action, plus CRUD management of the onboarding form's option lists —
job functions, regions, employment types, skills, and languages (`/admin/job_functions`, `/admin/regions`,
`/admin/employment_types`, `/admin/skills`, `/admin/languages`) — so these can be edited without a code
deploy. See `Onboarding::JobFunction`/`Region`/`EmploymentType`/`Skill`/`Language`.

When a candidate saves the last page of the onboarding review form, `Onboarding::CompleteCandidateProfileService`
marks their profile submitted and fires two optional, independently-configured side effects (both are
no-ops, fail closed, when unset):

* **Recruitment team email** — set `RECRUITMENT_TEAM_EMAIL` to have `Onboarding::CandidateNotificationMailer`
  send a notification to that address via `deliver_later`.
* **Automation webhook** — set `CANDIDATE_ONBOARDING_WEBHOOK_URL` to have `Onboarding::CandidateOnboardingWebhookJob`
  POST a `candidate_onboarding_completed` JSON event to that URL. Delivery failures raise, so Sidekiq's
  default retry policy applies.

## Privacy & security

* CV files are never served from a public/guessable URL — both the candidate-facing and admin-facing
  download actions stream the file's bytes through the app (`send_data`), so no Active Storage blob URL
  is ever generated or exposed to the browser.
* A candidate's session is tied to an opaque `session_token` on their `Onboarding::CandidateProfile`,
  stored server-side and mirrored into the encrypted Rails session cookie at upload time. Every
  candidate-facing request re-checks that token, so a guessed/shared profile ID alone can't be used to
  view or edit someone else's data.
* Admins/recruiters authenticate via the existing HTTP Basic Auth (`ADMIN_USERNAME`/`ADMIN_PASSWORD`) and
  can only see profiles that have completed onboarding (`onboarding_status: submitted`).
* Candidates must check a consent box before their CV/profile data is processed; the timestamp is
  recorded on `consent_given_at`.

## Tests

```
bin/rails test                          # full suite
bin/rails test test/models/some_test.rb # single file
bin/rails test test/models/some_test.rb:12 # single test by line
bin/rails test:system                   # system tests (Capybara/Selenium; not run in CI by default)
```

## Linting & security

```
bin/rubocop           # lint (Omakase Rubocop config)
bin/bundler-audit      # gem vulnerability audit
bin/importmap audit     # importmap vulnerability audit
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error  # static analysis
```

Run the full CI pipeline locally (setup, rubocop, audits, brakeman, tests, seed replant) with:

```
bin/ci
```

## Database

```
bin/rails db:prepare
bin/rails db:migrate
bin/rails db:seed:replant
```

## Deployment

The `Dockerfile` builds a production image (see the comment at the top of the file for build/run
commands). Deployment is via [Kamal](https://kamal-deploy.org/) — see `config/deploy.yml` and `.kamal/`.
The same image runs both the web server and, on the `job` role, the Sidekiq worker
(`bin/sidekiq -C config/sidekiq.yml`); a `redis` Kamal accessory backs Sidekiq, `Rails.cache`, and Action
Cable in production (`REDIS_URL`, see `config/deploy.yml`).

The Dockerfile and this README are kept in sync with what the app actually needs to run; any change that
adds a service, dependency, background worker, or env var should update both.
