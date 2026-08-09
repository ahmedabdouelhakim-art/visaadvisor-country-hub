# Review, conflicts, corrections, and releases

## Independent state axes

Do not overload one status field.

- Publication: `draft → in_review → approved → published → archived`
- Verification: `unverified → provisional → verified → disputed → withdrawn`
- Freshness: `current → due → stale → expired`
- Translation: `missing → draft → reviewed → published → out_of_sync`

High-stakes claims require an evidence reviewer and a separate publishing approval. Automation may detect and prepare a change; it may not grant final high-stakes approval.

## Public pre-releases

A foundation pre-release may be distributed for transparent method review before the two high-stakes approvals are recorded only when all of the following are true:

- the release manifest identifies it as a pre-release;
- the change log keeps approval status at `pending_review`;
- the README and citation metadata state that definitive high-stakes reuse is not approved;
- no page presents the records as current personalised travel advice; and
- the later approved release receives a new immutable version.

## Append-only history

- Published facts and release artifacts are immutable.
- Correct by superseding a record, never by silently rewriting history.
- Preserve old value, new value, effective date, detection date, reason, evidence, reviewer, and affected releases.
- Retractions remain visible as `withdrawn`.

## Semantic versions

- **Major:** meaning-changing schema or methodology change.
- **Minor:** material new countries, domains, or coverage.
- **Patch:** source repair, factual correction, or non-breaking field fix.

Typographic changes that cannot alter meaning may avoid a public correction notice, but still belong in the internal audit trail.

## Release gates

Before publication:

1. Schema and relationship checks pass.
2. Every material published field has appropriate evidence or an editorial label.
3. Every high-stakes claim has current Tier A/B evidence suited to its scope.
4. No unresolved high-stakes conflict is hidden.
5. Arabic/English priority fields refer to the same fact IDs and are reviewed.
6. No public PII is present.
7. Manifest, row counts, checksums, license, changelog, and correction channel are included.

Each release manifest records its input datasets and hashes so the output can be reproduced.
