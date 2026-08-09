# Source and evidence policy

## Evidence standard

Country Hub is claim-centric. A generic sources list at the bottom of a page is not sufficient for material facts. Each material field must point to evidence that supports that exact field and traveller scenario.

## Source tiers

| Tier | Source | Permitted use |
| --- | --- | --- |
| A | Controlling primary authority: law, official gazette, immigration/border authority, health authority, regulator | Required for definitive high-stakes rules |
| B | Official operational source: embassy, consulate, airport, transport authority, airline, telecom operator, official hospital directory | Implementation detail; may qualify but not silently override Tier A |
| C | Multilateral/statistical authority: WHO, ICAO, UN, World Bank, ITU | Cross-country standards and contextual indicators |
| D | Peer-reviewed research, audited independent dataset, established reporting | Context and corroboration |
| E | Blog, forum, community post, personal story, aggregator | Discovery or labelled experience only; never sole evidence for a high-stakes fact |

Ten pages repeating the same upstream source count as one evidence chain. Store authority scope, jurisdiction, directness, independence group, update date, and whether the publisher controls the rule.

## Scenario completeness

An entry claim is incomplete unless it specifies, where relevant:

- passport issuer and document type;
- nationality and residence when they change the rule;
- destination and transit jurisdiction;
- travel purpose;
- arrival mode or port restriction;
- action required before travel;
- relevant stay, validity, entry-count, and exception conditions;
- effective and verification dates.

“Visa-free” alone is not a publishable claim.

## Evidence relationships

Use one of:

- `primary`: direct evidence for the field and scenario;
- `supporting`: corroborates or adds operational detail;
- `qualifying`: limits or conditions the primary claim;
- `contradictory`: materially conflicts with the claim;
- `editorial_only`: no official factual claim is made; the value is a labelled VisaAdvisor judgment.

Confidence labels are policy outcomes, not AI probabilities:

- `authoritative`
- `corroborated`
- `provisional`
- `disputed`
- `editorial`

## Conflict handling

1. Normalize the traveller scenario and effective date.
2. Check whether the sources cover the same jurisdiction, document, purpose, port, and traveller class.
3. Identify the legally controlling authority.
4. Treat operational sources as implementation evidence, not automatic legal overrides.
5. Check explicit supersession and effective dates.
6. Preserve both claims and sources; do not silently delete the losing version.
7. Record the resolution, reason, reviewer, date, and evidence.
8. If unresolved, mark `disputed`, show both positions, and withhold definitive guidance.

Never resolve a conflict by website count or by assuming the newest-looking page controls the law.

## Citation rules

- Cite the original authority and the precise page or section.
- Remove tracking parameters from stored URLs.
- Prefer the original-language document; label VisaAdvisor translations.
- Store a short locator and evidence scope, not a full copyrighted copy.
- Label editorial inference and calculation, and link to their inputs.
- Record retrieved/checked dates and, where available, source update dates.
- A fee page cannot be used as proof of passport eligibility unless it states that eligibility.

## Import boundary for legacy datasets

Legacy rows enter staging with their existing status. Import does not upgrade them to current or newly verified. Delimiter-separated legacy fields may remain in the seed export only; the production model must atomize them before a full public Country Hub release.
