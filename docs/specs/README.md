# Feature specs

Design inputs live here — the *reasoning* behind a feature, before
it becomes code. A spec is short: problem → options → decision →
where it landed. Conclusions always migrate into the owning doc
(GDD section, UI-0xx row, D-ARCH/D-UI decision); the spec stays as
the record of *why*.

## Lifecycle

1. `NNN-slug.md` — next free number, kebab-case slug.
2. Header line: `Status: Draft | Decided | Landed | Superseded by NNN`.
3. When decided, the decision row lands in the owning doc and the
   spec is marked `Decided → pointer`. When shipped, `Landed →
   file/row`. Never delete; supersede instead.

## Specs

| # | Spec | Status |
|---|---|---|
| 001 | Rolling-front world FX (weather as scalar + response curves) | Landed → `world_fx.gd`, UI-046, D-ARCH-1/3 |
| 002 | Cozy time model (no day-clock, engagement-gated yields, event tiers) | Landed → D-UI-8, `_letter_due` gate |
| 003 | Sit spots — benches as sim affordances | Decided — blocked on actor view presenter (PLAN D4 sockets) |
| 004 | Camp systems audit (ledger/upgrades/maintenance/spawner/cooking) | Partial — fusion tier landed; decor-demand + maintenance are open design calls |
| 005 | Eastward texture audit (vignette cues, reactive barks, trigger density) | Decided — A/B/C independent of actor layer; D blocked with spec 003 |
