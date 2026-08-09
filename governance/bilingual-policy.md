# Arabic–English integrity policy

Facts are language-neutral. Arabic and English are publication layers that reuse the same record and claim IDs.

## Rules

- Use BCP-47 language tags (`ar`, `en`) in the normalized model.
- Keep ISO dates, units, currencies, and codes canonical internally; localize only display.
- Maintain controlled terminology in `locales/glossary-ar-en.csv`.
- Record source language and distinguish translation from official wording.
- When a factual source changes, mark all affected translations `out_of_sync` until reviewed.
- Machine translation may produce a draft; a reviewed translation is required for high-stakes publication.
- Do not create separate Arabic and English facts merely because the wording differs.

The v0.1 seed preserves the bilingual columns present in the Egyptian Passport dataset and marks missing translations as coverage gaps rather than manufacturing them.
