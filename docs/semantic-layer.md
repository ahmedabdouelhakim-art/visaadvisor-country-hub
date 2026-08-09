# Portable semantic layer

This guide defines how analysts, editors, and automated systems should interpret
Country Hub v0.1.0. It is source-selection guidance, not a substitute for live
official-source checks.

## Canonical counts

Read counts from `data/seed/v0.1.0/validation-report.json` after a clean rebuild.
The validated v0.1.0 release contains 21 place records, 12 planning profiles,
8 entry rules, 58 sources, and 150 field-evidence edges.

## Entity meanings

- **Place:** state, territory, or special administrative region. It does not
  mean sovereign country only.
- **Planning profile:** one imported planning recommendation version. Editorial
  fields are not government recommendations.
- **Entry rule:** one passport-origin, document, purpose, and destination route.
  The seed covers eight selected ordinary Egyptian-passport tourism routes only.
- **Source:** one official page identity, usable only for its recorded evidence scope.
- **Field evidence:** one relationship between a field and a source or an explicit
  editorial-only label.

## Required interpretation

- Blank means not supplied or not supported; never infer none.
- Keep maximum stay, authorisation validity, and period actually granted separate.
- A current source identity does not make every linked fact current.
- Preserve `last_verified`, `next_review_due`, verification status, and freshness
  status as separate concepts.
- Fields ending in `_editorial` remain visibly labelled in analysis and publication.
- High-stakes facts require a current authoritative check before actionable use.

## Canonical joins

- Planning to place: `country-planning-profiles.place_id → places.place_id`
- Entry origin/destination to place: `origin_place_id` and `destination_place_id → places.place_id`
- Evidence to source: `field-evidence.source_id → sources.source_id`
- Any imported record to source release: `source_dataset_id → datasets.dataset_id`

## Known caveats

- Macao is a special administrative region, so 21 places must not be reported as 21 countries.
- Venezuela's provisional operational evidence was due for review on 2026-08-09.
- Egyptian v13 was checked on 2026-07-26; its Hub review date is policy, not a new verification.
- Legacy `stay_or_validity` and fee text remains non-atomic pending reviewed normalization.
- Two official secondary URLs present in Egyptian route rows were absent from its
  source registry and are labelled supplemental in the Hub.
- Cities, cost, safety, connectivity, healthcare, and immigration are schema-only.
- Personal identity documents and contact information are never evidence.

See `governance/` and `schema/` for the binding project rules.
