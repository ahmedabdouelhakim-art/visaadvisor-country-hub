# Freshness policy

## Volatility classes

| Code | Examples | Monitoring | Default review target | Hard expiry guidance |
| --- | --- | --- | --- | --- |
| `V0_IDENTITY` | ISO identity, geography | Event-driven | Annual | 18 months |
| `V1_SLOW` | Capital, official language, currency, timezone, emergency numbers | Monthly/event-driven | 6–12 months | 12–18 months |
| `V2_PLANNING` | Seasonality, gateways, attractions, facility directories | Monthly/quarterly | 90–180 days | 180 days |
| `V3_REGULATORY` | Visa, transit, entry, immigration, tax, health-entry rules | Change monitoring | 7–30 days | 30–90 days by risk |
| `V4_OPERATIONAL` | Border closure, active alert, live fee or transport interruption | Daily/event-driven | Within 24 hours–7 days | 48 hours–30 days |

The shorter documented source or legal expiry always wins.

## Freshness states

- `current`: verified and before its review due date.
- `due`: review date reached; may remain visible with a warning if not high-stakes.
- `stale`: overdue beyond the permitted grace period.
- `expired`: hard expiry reached; cannot be presented as definitive.

Every public fact should expose `verified_at`, `next_review_at`, and its freshness state.

## Safe degradation

- Expired high-stakes fields are blocked from definitive publication.
- A stale country page may still show stable identity and clearly labelled editorial content.
- When a high-stakes answer cannot be safely shown, present the official verification link and state that the stored record requires review.
- Exchange rates are retrieved for the moment of use and expire after 24 hours; they are not permanent country facts.

## Seed-specific notices

- The South America v1.1 source check date is 2026-08-02. Venezuela's operational alert review was due 2026-08-09 and must be treated as due until rechecked.
- Egyptian Passport Entry Rules v13.0 was checked on 2026-07-26 and lacked a next-review field. The seed assigns a 30-day review target without claiming a new verification.
