# Trailbound — Analytics event schema

**Status:** schema defined in Phase 0; implementation lands in Phase 1 (SDK wiring,
GDD §29 Phase 5). Events fire through the analytics autoload; Firebase
Analytics via the thin Android plugin (D-21). No personal data, no device id,
no free text. Consent (UMP, §26) covers ads; analytics is first-party usage
telemetry only.

## Event list

| Event | When | Payload |
|---|---|---|
| `session_start` | App open | `session_id` (fresh random per launch, not persisted), `lang`, `version_code`, `platform` |
| `phase_enter` | Morning/Prep/Evening/Night begins | `phase`, `site`, `site_day` |
| `day_complete` | Goodnight committed | `site`, `site_day`, `rating`, `coins_spent`, `pages_done`, `modifier` (if any) |
| `ad_impression` | An ad is shown | `placement` (`night_summary` \| `between_days` \| `crew_speedup`), `format` (`rewarded` \| `interstitial`) |
| `ad_fill` | An ad request resolves | `placement`, `result` (`shown` \| `no_fill` \| `declined` \| `capped`) |
| `iap_funnel` | Remove Ads / Camp Kit flow | `sku`, `result` (`started` \| `pending` \| `purchased` \| `refunded` \| `failed`) |
| `daily_played` | Trail Daily completed | `stars`, `time_seconds` |
| `crash` | Unhandled exception captured | `signature`, `version_code` (via Crashlytics, not this schema) |

## Privacy contract

- `session_id` is random per launch and not persisted; it cannot link sessions.
- No email, name, account id, or device id is sent.
- No free text or user content.
- Analytics can be disabled if the user declines consent where required.
- Matches GDD §26 (privacy policy) and the Play data-safety form.

## Phase 2 gate reads

D1/D7 retention, finisher share and ad opt-in are computed from these events.
Do not start Phase 2 without them firing in the closed test (§29 Phase 6).
