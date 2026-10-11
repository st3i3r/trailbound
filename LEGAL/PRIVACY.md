# Privacy Policy — My Café 3D

**Last updated:** 2026-10-10
**Status:** DRAFT — placeholders marked TODO must be filled before launch.

## 1. Who we are

My Café 3D is a Telegram Mini App game.
- Developer / contact: TODO (legal entity name + contact email)
- This policy explains what data the game collects, why, and your rights.

## 2. Data we collect

| Data | Source | Purpose |
|---|---|---|
| Telegram user ID | Telegram WebApp `initData` | Identify your account; load your café |
| Telegram first name | Telegram WebApp `initData` | Greeting / display name in-game |
| Game state (coins, decor layout, recipes, progress, settings) | Your gameplay | Save and restore your café |
| Analytics events (session starts, tutorial steps, serves, purchases) | Your gameplay | Balance the game, fix bugs, measure retention |
| Payment records (Telegram Stars product, timestamp — no card data) | Telegram Payments | Fulfil and audit purchases |

**We do NOT collect:** your phone number, precise location, contacts, messages, or any payment card/bank details. Telegram processes all payments; we never see or store payment credentials.

## 3. Legal basis / consent

By opening the Mini App you consent to the processing described above, limited to what is needed to operate the game. TODO: confirm basis wording with counsel for your jurisdiction (GDPR legitimate interest vs consent; Vietnam PDPD requirements).

## 4. Data storage & security

- Game state is stored on our server (TODO: hosting provider + region).
- `initData` is verified with HMAC-SHA256 against the bot token on every request; tampered payloads are rejected.
- TODO: backup/retention schedule (e.g. state retained while account active; deleted on request).

## 5. Sharing

We do not sell your data. Data is shared only with:
- Telegram (platform operator — their privacy policy applies to their processing);
- Payment processing via Telegram Stars (no card data touches our servers);
- TODO: analytics/hosting sub-processors, if any.

## 6. Your rights

You may request a copy of your stored data or deletion of your account and all associated game state via TODO (contact method, e.g. in-game support button or email). Deletion removes your café permanently; Stars purchase *records* may be retained for tax/audit purposes where legally required (TODO: confirm).

## 7. Children

The game is intended for a general audience. TODO: set minimum age per target jurisdictions (commonly 13+) and add any parental-consent handling required.

## 8. Changes

Material changes to this policy will be announced in-game and/or via the game's Telegram channel before taking effect. Continued play after changes take effect constitutes acceptance.

## 9. Contact

TODO: privacy contact email / DPO details.
