# AI guidelines

AI assistance is optional. Humans must be able to contribute without it.

Agents read [`AGENTS.md`](../AGENTS.md) at the repo root automatically; it holds
the working instructions, repo map, and commands. This page is the human-facing
policy behind it. Reusable agent workflows live in `.agents/skills/`, the
vendor-neutral location, so they are not tied to one editor.

## Before any AI-assisted work

1. Read [constraints.md](constraints.md) and [architecture.md](architecture.md).
2. Confirm the task does not require servers, paid APIs, cloud sync, or in-app AI.

## How to use AI well

- **Chunk tasks** — one layer, one screen, or one doc section per session.
- **Minimal diffs** — match existing patterns; no speculative abstractions.
- **Never add** cloud backends, paid map services, login, sync, or AI orchestration layers.
- **Never let a model invent data.** A plausible-looking boundary, season date or
  policy summary is the worst output this project can receive, because it reads
  exactly like a real one. If a source cannot supply it, the gap ships.
- **Land Info answers offline** — identify, the report sheet, and policies from the
  pack. The Weather tab is the one sanctioned live call: optional, additive, and
  failing with a plain message rather than degrading the card. No live policy
  lookup APIs.

## Review checklist

- [ ] Core paths work offline with a downloaded pack
- [ ] No new network dependency for core paths
- [ ] Province data under `data/{cc}/` conventions, with `source`, `license` and `license_url` on every layer
- [ ] No sample, placeholder or illustrative data in anything that ships; test fixtures stay under `app/test/`
- [ ] Anything uncertain says so on screen, not only in the commit message

Reject suggestions that trade constraints for convenience.
