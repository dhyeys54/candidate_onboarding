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

The `/admin` namespace (staff-only, no routes yet) is likewise protected by HTTP Basic Auth via
`Admin::BaseController`. Set `ADMIN_USERNAME` and `ADMIN_PASSWORD` in the environment to enable access
(same fail-closed behavior when unset).

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
