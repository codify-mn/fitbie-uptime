# fitbie-uptime

Every five minutes a GitHub Action probes Fitbie from outside and posts to Discord when a target goes
down or comes back — once per change, not every run. Public so Actions minutes are free.

| Target | URL | Down means |
|---|---|---|
| `api` | `https://api.fitbie.app/healthz` | API container, nginx, Cloudflare or the box |
| `api-db` | `https://api.fitbie.app/v1/notifications/copy` | Postgres (this route reads it; `/healthz` doesn't) |
| `web` | `https://fitbie.app/` | landing page container |

- Targets live in `check.sh`. Three tries 20 s apart before anything counts as down.
- `down.txt` is the last run's down list, committed by the workflow. Don't edit it by hand.
- Secret `DISCORD_WEBHOOK_URL` (repo → Settings → Secrets). Without it a state change fails the run instead,
  and GitHub e-mails whoever last edited the schedule.
- GitHub's scheduler runs late by 5–20 min under load, so an outage can take ~25 min to show up.
- A public repo's schedule turns off after 60 days without commits; the workflow touches `.keepalive`
  every 30 days to prevent that. If it ever stops anyway: Actions → Uptime → Enable workflow.
- Run it now: Actions → Uptime → Run workflow, or `gh workflow run uptime.yml -R codify-mn/fitbie-uptime`.
  Add `-f test=true` to also post a test message (after setting or rotating the webhook).
