# Docs map — Trailbound

One owner per truth. When you change a system, change its doc in the
same commit. If a fact lives in two places it will drift — reference,
don't copy.

| Doc | Owns (single source of truth for…) | Update when |
|---|---|---|
| `GAME_DESIGN.md` | Rules, economy, loops, content spec — §-numbered; **the** spec | A rule, number or loop changes |
| `ARCHITECTURE.md` | Runtime map, systems, data/save contracts, presentation layers, QA harness, engineering decisions (D-ARCH-x) | An autoload, system, contract or flag changes |
| `UI_PRODUCTION.md` | UI gap audit + backlog (UI-0xx) + UI decisions (D-UI-x) + kit/tooling notes | A UI row lands or a UI decision is made |
| `SITE_BRIEFS.md` | Per-site content contracts before generation | A site is designed |
| `PLAN_gameplay.md`, `PLAN_art_craft.md` | Sequencing — what builds in what order | Scope or phase order changes |
| `DEV_WORKFLOW.md` | Environment, toolchain, iteration loop, testing methodology | Env or tooling changes |
| `specs/` | Feature design inputs (the *reasoning*) | A spec lands → mark it; decision goes to the owning doc |
| `assets_src/prompts/style_lock.md` | The look — art direction rules | Art direction changes |
| `LEGAL/` | Store compliance drafts | Store/legal changes |

## Working rules

1. **Append-only decisions.** D-UI-x / D-ARCH-x rows are never
   edited — a changed mind is a new row that says *supersedes*.
   The table is the "why is it like this" record.
2. **§-refs are contracts.** Code comments cite `GAME_DESIGN.md §x.y`;
   docs cite each other the same way. Renumbering a section is a
   repo-wide find/replace, or don't.
3. **Spec → decision flow.** A design input (a doc, a chat export, a
   matrix) lands as `docs/specs/NNN-slug.md` first; its outcome lands
   as a decision row or GDD edit; the spec is marked Landed with a
   pointer. No loose `*.txt` outside the repo.
4. **Backlog is work items, not prose.** The UI-0xx and PLAN tables
   track what isn't built; when a row ships it gets `✓` + where it
   landed + how it was verified.
5. **Advisory ≠ ignored.** Lint advisories (VI width) are documented
   exceptions, accepted in writing or fixed.
