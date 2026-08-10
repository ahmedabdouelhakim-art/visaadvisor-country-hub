from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import streamlit as st


RELEASE_ID = "CH-0.1.0"
RELEASE_VERSION = "0.1.0"
RELEASE_DATE = "2026-08-09"
VERSION_DOI = "https://doi.org/10.5281/zenodo.21858354"
REPOSITORY_URL = "https://github.com/ahmedabdouelhakim-art/visaadvisor-country-hub"
PROJECT_URL = "https://visaadvisor.ai/"

EXPECTED_ROWS = {
    "places.csv": 21,
    "country-planning-profiles.csv": 12,
    "sources.csv": 58,
    "field-evidence.csv": 150,
    "coverage-matrix.csv": 9,
    "datasets.csv": 2,
}

REQUIRED_COLUMNS = {
    "places.csv": {"place_id", "name_en", "place_type", "coverage_status"},
    "country-planning-profiles.csv": {
        "planning_profile_id",
        "place_id",
        "suggested_days_min_editorial",
        "suggested_days_max_editorial",
        "gateway_city_editorial",
        "route_intensity_editorial",
        "review_status",
        "next_review_due",
    },
    "sources.csv": {
        "source_id",
        "source_title",
        "field_type",
        "evidence_scope",
        "url",
        "authority_tier",
        "volatility_class",
        "checked_on",
        "next_review_due",
    },
    "field-evidence.csv": {"evidence_edge_id", "record_id", "field_name", "claim_kind"},
    "coverage-matrix.csv": {
        "domain",
        "scope",
        "coverage_status",
        "record_count",
        "verified_record_count",
        "stale_or_due_count",
    },
    "datasets.csv": {"dataset_id", "title", "version", "scope", "doi", "status"},
}


def find_release_dir() -> Path:
    """Find the immutable seed snapshot without copying or rewriting it."""
    here = Path(__file__).resolve()
    candidates = [
        parent / "data" / "seed" / f"v{RELEASE_VERSION}"
        for parent in [here.parent, *here.parents]
    ]
    for candidate in candidates:
        if all((candidate / filename).is_file() for filename in EXPECTED_ROWS):
            return candidate
    raise FileNotFoundError(
        "Country Hub v0.1.0 was not found. Deploy this app from the "
        "visaadvisor-country-hub repository so the versioned seed remains available."
    )


@st.cache_data(show_spinner=False)
def load_release() -> tuple[dict[str, pd.DataFrame], str]:
    release_dir = find_release_dir()
    tables: dict[str, pd.DataFrame] = {}

    for filename, expected_rows in EXPECTED_ROWS.items():
        frame = pd.read_csv(release_dir / filename, keep_default_na=False)
        if len(frame) != expected_rows:
            raise ValueError(
                f"{filename} contains {len(frame)} rows; {expected_rows} were expected for {RELEASE_ID}."
            )
        missing = REQUIRED_COLUMNS[filename] - set(frame.columns)
        if missing:
            raise ValueError(f"{filename} is missing required columns: {sorted(missing)}")
        tables[filename] = frame

    return tables, release_dir.as_posix()


def mark_review_state(values: pd.Series) -> pd.Series:
    due_dates = pd.to_datetime(values, errors="coerce").dt.date
    today = datetime.now(timezone.utc).date()
    return due_dates.map(lambda value: "Due" if value and value <= today else "Current window")


def clean_label(value: str) -> str:
    return value.replace("_", " ").strip().title()


st.set_page_config(
    page_title="VisaAdvisor Country Hub Explorer",
    page_icon="🌍",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown(
    """
    <style>
      .block-container {max-width: 1260px; padding-top: 2rem; padding-bottom: 4rem;}
      .va-hero {padding: 1.45rem 1.6rem; border-radius: 18px; color: #f8fffb;
                background: linear-gradient(120deg, #12372a 0%, #176b4d 58%, #2b8a68 100%);
                margin-bottom: 1rem;}
      .va-hero h1 {font-size: 2.15rem; margin: 0 0 .35rem 0;}
      .va-hero p {font-size: 1.02rem; opacity: .94; margin: 0; max-width: 850px;}
      .va-kicker {font-weight: 700; letter-spacing: .08em; text-transform: uppercase;
                  font-size: .76rem; opacity: .8; margin-bottom: .45rem;}
      .va-note {border-left: 4px solid #2b8a68; padding: .75rem 1rem;
                background: #eef8f2; border-radius: 0 10px 10px 0; color: #173b2e;}
      .va-footer {margin-top: 2.5rem; padding-top: 1rem; border-top: 1px solid #dce7e1;
                  color: #53645d; font-size: .88rem;}
      div[data-testid="stMetric"] {background: #f6faf7; border: 1px solid #dce7e1;
                                   padding: .8rem; border-radius: 12px;}
    </style>
    """,
    unsafe_allow_html=True,
)

try:
    tables, release_path = load_release()
except (FileNotFoundError, ValueError) as exc:
    st.error("The versioned release could not be loaded safely.")
    st.code(str(exc))
    st.stop()

places = tables["places.csv"].copy()
planning = tables["country-planning-profiles.csv"].copy()
sources = tables["sources.csv"].copy()
evidence = tables["field-evidence.csv"].copy()
coverage = tables["coverage-matrix.csv"].copy()
datasets = tables["datasets.csv"].copy()

planning = planning.merge(
    places[["place_id", "name_en", "iso2"]], on="place_id", how="left", validate="many_to_one"
)
planning["review_window"] = mark_review_state(planning["next_review_due"])
sources["review_window"] = mark_review_state(sources["next_review_due"])

st.markdown(
    """
    <section class="va-hero">
      <div class="va-kicker">VisaAdvisor Research · بحث VisaAdvisor</div>
      <h1>Global Country Hub Explorer</h1>
      <p>An interactive, source-dated view of the Country Hub foundation seed —
      with evidence status and editorial judgments kept visibly separate.</p>
    </section>
    """,
    unsafe_allow_html=True,
)

st.warning(
    "Public foundation pre-release. Coverage is partial, independent evidence review is pending, "
    "and this explorer is not definitive travel or entry advice."
)

with st.sidebar:
    st.subheader("Release identity")
    st.write(f"**{RELEASE_ID}** · {RELEASE_DATE}")
    st.caption("The app reads the versioned seed in place. It does not change the release or its DOI.")
    st.link_button("Version DOI", VERSION_DOI, use_container_width=True)
    st.link_button("Source repository", REPOSITORY_URL, use_container_width=True)
    st.divider()
    st.subheader("Safe-use boundary")
    st.caption(
        "Entry-rule details are intentionally excluded from this MVP. High-stakes travel rules "
        "need a current official check before actionable guidance."
    )
    st.caption(f"Loaded locally from the repository · {release_path.split('/')[-1]}")

overview_tab, planning_tab, sources_tab, method_tab = st.tabs(
    ["Overview", "Planning explorer", "Source audit", "Method & limits"]
)

with overview_tab:
    st.subheader("What the foundation seed actually contains")
    metric_cols = st.columns(4)
    metric_cols[0].metric("Seed places", f"{len(places):,}")
    metric_cols[1].metric("Planning profiles", f"{len(planning):,}")
    metric_cols[2].metric("Normalized sources", f"{len(sources):,}")
    metric_cols[3].metric("Evidence edges", f"{len(evidence):,}")

    st.markdown(
        "<div class='va-note'><strong>Coverage rule:</strong> an empty contract is not data. "
        "Cities, cost, safety, connectivity, healthcare and immigration remain schema-only in v0.1.0.</div>",
        unsafe_allow_html=True,
    )
    st.write("")

    coverage_view = coverage[
        [
            "domain",
            "scope",
            "coverage_status",
            "record_count",
            "verified_record_count",
            "stale_or_due_count",
            "notes",
        ]
    ].copy()
    coverage_view.columns = [
        "Domain",
        "Scope",
        "Coverage",
        "Records",
        "Verified",
        "Due / stale",
        "Notes",
    ]
    st.dataframe(coverage_view, hide_index=True, use_container_width=True)

    st.subheader("Published source releases")
    dataset_view = datasets[["title", "version", "scope", "doi", "status"]].copy()
    dataset_view.columns = ["Dataset", "Version", "Scope", "DOI", "Status"]
    st.dataframe(
        dataset_view,
        hide_index=True,
        use_container_width=True,
        column_config={"DOI": st.column_config.LinkColumn("DOI", display_text="Open DOI")},
    )

with planning_tab:
    st.subheader("South America planning comparison")
    st.caption(
        "Suggested days, route intensity, gateways and selected experiences are labelled "
        "VisaAdvisor editorial planning judgments — not government recommendations."
    )

    available_countries = planning.sort_values("name_en")["name_en"].tolist()
    default_countries = [
        name for name in ["Argentina", "Brazil", "Colombia"] if name in available_countries
    ]
    selected_countries = st.multiselect(
        "Compare up to six countries",
        options=available_countries,
        default=default_countries,
        max_selections=6,
    )

    selected = planning[planning["name_en"].isin(selected_countries)].copy()
    if selected.empty:
        st.info("Select at least one country to start the comparison.")
    else:
        chart_data = selected.set_index("name_en")[[
            "suggested_days_min_editorial",
            "suggested_days_max_editorial",
        ]].apply(pd.to_numeric, errors="coerce")
        chart_data.columns = ["Suggested minimum", "Suggested maximum"]
        st.bar_chart(chart_data, horizontal=True)

        comparison = selected[
            [
                "name_en",
                "suggested_days_min_editorial",
                "suggested_days_max_editorial",
                "gateway_city_editorial",
                "route_intensity_editorial",
                "review_status",
                "next_review_due",
            ]
        ].copy()
        comparison.columns = [
            "Country",
            "Days min · editorial",
            "Days max · editorial",
            "Gateway · editorial",
            "Route intensity · editorial",
            "Review status",
            "Next review due",
        ]
        st.dataframe(comparison, hide_index=True, use_container_width=True)

        for _, row in selected.sort_values("name_en").iterrows():
            status = clean_label(str(row["review_status"]))
            with st.expander(f"{row['name_en']} · {status}"):
                if row["review_status"] != "reviewed" or row["review_window"] == "Due":
                    st.warning(
                        "This profile is provisional or due for review. Treat operational details cautiously."
                    )
                c1, c2 = st.columns(2)
                c1.markdown(f"**Gateway · editorial**  \n{row['gateway_city_editorial']}")
                c1.markdown(f"**Gateway note**  \n{row['gateway_note'] or 'Not supplied'}")
                c2.markdown(f"**Route intensity · editorial**  \n{row['route_intensity_editorial']}")
                c2.markdown(f"**Next review due**  \n{row['next_review_due']}")
                st.markdown(f"**Seasonality note**  \n{row['seasonality_note'] or 'Not supplied'}")
                st.markdown(
                    "**Selected experiences · editorial**  \n"
                    f"- {row['signature_experience_1_editorial'] or 'Not supplied'}  \n"
                    f"- {row['signature_experience_2_editorial'] or 'Not supplied'}"
                )
                link_cols = st.columns(2)
                if row["official_tourism_url"]:
                    link_cols[0].link_button("Official tourism source", row["official_tourism_url"])
                if row["official_entry_url"]:
                    link_cols[1].link_button(
                        "Official entry source · verify live", row["official_entry_url"]
                    )

with sources_tab:
    st.subheader("Source and review audit")
    st.caption(
        "A source is shown only for its recorded evidence scope. Authority does not make every field "
        "on a page evidence for every claim."
    )

    f1, f2, f3 = st.columns(3)
    selected_tiers = f1.multiselect(
        "Authority tier",
        options=sorted(value for value in sources["authority_tier"].unique() if value),
    )
    selected_domains = f2.multiselect(
        "Evidence domain",
        options=sorted(value for value in sources["field_type"].unique() if value),
    )
    selected_volatility = f3.multiselect(
        "Volatility",
        options=sorted(value for value in sources["volatility_class"].unique() if value),
    )
    search_text = st.text_input("Search source title, organization or evidence scope")

    filtered_sources = sources.copy()
    if selected_tiers:
        filtered_sources = filtered_sources[filtered_sources["authority_tier"].isin(selected_tiers)]
    if selected_domains:
        filtered_sources = filtered_sources[filtered_sources["field_type"].isin(selected_domains)]
    if selected_volatility:
        filtered_sources = filtered_sources[
            filtered_sources["volatility_class"].isin(selected_volatility)
        ]
    if search_text.strip():
        query = search_text.strip().casefold()
        haystack = (
            filtered_sources["source_title"].astype(str)
            + " "
            + filtered_sources["source_organization"].astype(str)
            + " "
            + filtered_sources["evidence_scope"].astype(str)
        ).str.casefold()
        filtered_sources = filtered_sources[haystack.str.contains(query, regex=False)]

    st.metric("Matching sources", len(filtered_sources))
    source_view = filtered_sources[
        [
            "source_title",
            "source_organization",
            "field_type",
            "authority_tier",
            "evidence_scope",
            "checked_on",
            "next_review_due",
            "review_window",
            "url",
        ]
    ].copy()
    source_view.columns = [
        "Source",
        "Organization",
        "Domain",
        "Authority tier",
        "Recorded evidence scope",
        "Checked",
        "Next review",
        "Review window",
        "Official URL",
    ]
    st.dataframe(
        source_view,
        hide_index=True,
        use_container_width=True,
        column_config={
            "Official URL": st.column_config.LinkColumn("Official URL", display_text="Open source")
        },
    )

with method_tab:
    st.subheader("Interpretation rules")
    st.markdown(
        """
        - Blank means **not supplied or not supported**; it never means “none”.
        - Mirrored GitHub, Hugging Face, Kaggle and Zenodo files are distribution copies, not independent corroboration.
        - Editorial planning fields stay visibly labelled; they are not government recommendations.
        - `last_verified` is an evidence date, not a promise that a rule remains current.
        - High-stakes entry, immigration, health, safety, tax and financial material requires a current official check.
        - Personal identity documents, private contact details and private correspondence are excluded.
        """
    )

    st.subheader("Why entry rules are not exposed here")
    st.info(
        "The seed contains eight scoped ordinary-Egyptian-passport tourism routes, but the legacy "
        "fields still combine stay, authorisation validity, fees and requirements. This MVP shows "
        "coverage and source governance without turning the snapshot into actionable entry advice."
    )

    st.subheader("Reproducibility")
    st.markdown(
        f"This explorer validates the expected row counts for **{RELEASE_ID}** before rendering. "
        "It reads the repository's versioned seed directly and does not write to it. "
        f"See the [version DOI]({VERSION_DOI}) and [source repository]({REPOSITORY_URL})."
    )

st.markdown(
    f"""
    <div class="va-footer">
      <strong>Ahmed Abdou — Co‑Founder, Editor &amp; Travel Researcher</strong><br>
      VisaAdvisor Country Hub · <a href="{PROJECT_URL}">VisaAdvisor.ai</a> ·
      Foundation seed {RELEASE_ID}
    </div>
    """,
    unsafe_allow_html=True,
)
