# VisaAdvisor Country Hub Explorer — Streamlit MVP

This is an independent presentation layer for the existing Country Hub v0.1.0 foundation seed. It does not alter the seed, rebuild a release, change a DOI, or publish high-stakes entry guidance.

## What it shows

- release-level coverage and honest gaps;
- South America planning comparisons with every editorial field visibly labelled;
- source authority, evidence scope, volatility and review dates;
- the release DOI, source repository and safe-use limits.

The MVP intentionally excludes detailed entry-rule outputs. Those legacy records combine concepts that must be atomized and rechecked against current official sources before actionable publication.

## Run locally

From the `country-hub` repository root:

```powershell
python -m pip install -r apps/streamlit-country-hub-explorer/requirements.txt
streamlit run apps/streamlit-country-hub-explorer/streamlit_app.py
```

## Deploy to Streamlit Community Cloud

Use the existing public GitHub repository and select:

- Repository: `ahmedabdouelhakim-art/visaadvisor-country-hub`
- Branch: `main`
- Entrypoint: `apps/streamlit-country-hub-explorer/streamlit_app.py`
- Python: `3.12`
- Secrets: none

Before deployment, commit only this new app directory after reviewing the diff. Do not include unrelated working-tree changes. Community Cloud clones the full repository, so the app reads `data/seed/v0.1.0` in place without a copied dataset or a runtime data API.

## Release boundary

- Read-only: `data/seed/v0.1.0`
- No writes, uploads, forms, authentication or personal data
- No change to `VERSION`, release manifest, checksums, DOI metadata or generated distribution files
- Row-count and required-column checks stop rendering if the expected v0.1.0 contract changes

## Platform choice

Streamlit Community Cloud is the fastest launch path because the current data and workflow are Python/CSV based and Streamlit can deploy a subdirectory entrypoint directly from the existing GitHub repository. Observable Framework remains a strong later option for an always-awake static public site, but it adds Node, a build step and a GitHub Pages workflow.

Community Cloud hibernates apps after 12 hours without traffic; a visitor can wake the app. This is acceptable for a fast campaign MVP, but it is the main reason to consider an Observable/GitHub Pages build for the durable second phase.

Official references:

- [Streamlit file organization](https://docs.streamlit.io/deploy/streamlit-community-cloud/deploy-your-app/file-organization)
- [Deploy an app](https://docs.streamlit.io/deploy/streamlit-community-cloud/deploy-your-app/deploy)
- [Community Cloud resources and hibernation](https://docs.streamlit.io/deploy/streamlit-community-cloud/manage-your-app)
- [Observable Framework deployment](https://observablehq.com/framework/deploying)
