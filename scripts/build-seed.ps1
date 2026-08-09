[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$HubRoot = Split-Path -Parent $PSScriptRoot
$InputDir = Join-Path $HubRoot 'inputs\upstream'
$ReleaseId = 'CH-0.1.0'
$ReleaseVersion = '0.1.0'
$ReleaseDate = '2026-08-09'
$OutputDir = Join-Path $HubRoot 'data\seed\v0.1.0'

# Windows PowerShell 5.1 parses UTF-8 source files without a BOM using the
# system code page. Keep the few Arabic literals needed by the build in an
# ASCII-safe form so the same release is reproducible in both 5.1 and 7+.
function Get-Utf8StringFromBase64 {
    param([Parameter(Mandatory)][string]$Value)
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

$ArabicSouthAmerica = Get-Utf8StringFromBase64 '2KPZhdix2YrZg9inINin2YTYrNmG2YjYqNmK2Kk='
$ArabicEgypt = Get-Utf8StringFromBase64 '2YXYtdix'
$ArabicPrimaryGovernmentSource = Get-Utf8StringFromBase64 '2YXYtdiv2LEg2K3Zg9mI2YXZiiDYo9iz2KfYs9mK'
$ArabicYes = Get-Utf8StringFromBase64 '2YbYudmF'

$resolvedHub = [IO.Path]::GetFullPath($HubRoot)
$resolvedOutput = [IO.Path]::GetFullPath($OutputDir)
if (-not $resolvedOutput.StartsWith($resolvedHub, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to write outside Country Hub: $resolvedOutput"
}

$SouthAmericaDataPath = Join-Path $InputDir 'south-america-trip-planning-dataset-2026-v1-1.csv'
$SouthAmericaSourcesPath = Join-Path $InputDir 'south-america-trip-planning-sources-2026-v1-1.csv'
$EgyptDataPath = Join-Path $InputDir 'egyptian-passport-entry-rules-2026-v13.csv'
$EgyptSourcesPath = Join-Path $InputDir 'egyptian-passport-sources-2026-v13.csv'

@($SouthAmericaDataPath, $SouthAmericaSourcesPath, $EgyptDataPath, $EgyptSourcesPath) | ForEach-Object {
    if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) { throw "Missing canonical input: $_" }
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Export-HubCsv {
    param([Parameter(Mandatory)]$Rows, [Parameter(Mandatory)][string]$Path)
    $csv = @($Rows) | ConvertTo-Csv -NoTypeInformation
    Write-HubUtf8Lf -Path $Path -Content ($csv -join "`n")
}

function Write-HubUtf8Lf {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )
    $normalized = $Content.Replace("`r`n", "`n").Replace("`r", "`n")
    if (-not $normalized.EndsWith("`n")) { $normalized += "`n" }
    [IO.File]::WriteAllText($Path, $normalized, (New-Object Text.UTF8Encoding($false)))
}

function Get-IsoDatePlusDays {
    param([Parameter(Mandatory)][string]$Date, [Parameter(Mandatory)][int]$Days)
    return ([datetime]::ParseExact($Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)).AddDays($Days).ToString('yyyy-MM-dd')
}

$saRows = @(Import-Csv -LiteralPath $SouthAmericaDataPath -Encoding UTF8)
$saSourceRows = @(Import-Csv -LiteralPath $SouthAmericaSourcesPath -Encoding UTF8)
$egRows = @(Import-Csv -LiteralPath $EgyptDataPath -Encoding UTF8)
$egSourceRows = @(Import-Csv -LiteralPath $EgyptSourcesPath -Encoding UTF8)

$datasets = @(
    [pscustomobject][ordered]@{
        dataset_id = 'DSET-SA-2026-V1-1'
        title = 'South America Travel Planning Index 2026'
        version = '1.1'
        scope = '12 sovereign South American country planning profiles'
        canonical_url = 'https://visaadvisor.ai/south-america-travel-planning-index-2026/'
        doi = 'https://doi.org/10.5281/zenodo.21765168'
        concept_doi = 'https://doi.org/10.5281/zenodo.21765167'
        local_canonical_path = 'inputs/upstream/south-america-trip-planning-dataset-2026-v1-1.csv'
        record_count = $saRows.Count
        source_count = $saSourceRows.Count
        verified_on = '2026-08-02'
        next_review_due = '2026-11-02'
        license_url = 'https://creativecommons.org/licenses/by/4.0/'
        status = 'published_source_release'
    },
    [pscustomobject][ordered]@{
        dataset_id = 'DSET-EG-PASS-2026-V13'
        title = 'Egyptian Passport Entry Rules 2026'
        version = '13.0'
        scope = '8 selected tourism short-visit routes for ordinary Egyptian passport holders'
        canonical_url = 'https://visaadvisor.ai/egyptian-passport-dataset-2026/'
        doi = 'https://doi.org/10.5281/zenodo.21744802'
        concept_doi = ''
        local_canonical_path = 'inputs/upstream/egyptian-passport-entry-rules-2026-v13.csv'
        record_count = $egRows.Count
        source_count = $egSourceRows.Count
        verified_on = '2026-07-26'
        next_review_due = (Get-IsoDatePlusDays -Date '2026-07-26' -Days 30)
        license_url = 'https://creativecommons.org/licenses/by/4.0/'
        status = 'published_source_release'
    }
)

$placesByIso = @{}
foreach ($row in $saRows) {
    $placesByIso[$row.iso2] = [pscustomobject][ordered]@{
        place_id = "PLC-$($row.iso2)"
        iso2 = $row.iso2
        name_en = $row.country
        name_ar = ''
        place_type = 'sovereign_country'
        parent_place_id = ''
        region_en = 'South America'
        region_ar = $ArabicSouthAmerica
        coverage_status = if ($row.status -eq 'provisional_alert') { 'provisional' } else { 'partial_verified' }
        last_verified = $row.checked_on
        next_review_due = $row.next_review_due
        source_dataset_id = 'DSET-SA-2026-V1-1'
        notes = 'Identity and planning seed only; capital, language, currency and timezone are not yet populated.'
    }
}

$placesByIso['EG'] = [pscustomobject][ordered]@{
    place_id = 'PLC-EG'
    iso2 = 'EG'
    name_en = 'Egypt'
    name_ar = $ArabicEgypt
    place_type = 'sovereign_country'
    parent_place_id = ''
    region_en = ''
    region_ar = ''
    coverage_status = 'identity_only'
    last_verified = '2026-07-26'
    next_review_due = '2027-07-26'
    source_dataset_id = 'DSET-EG-PASS-2026-V13'
    notes = 'Added as the passport-origin jurisdiction; geography fields are not asserted by the source release.'
}

foreach ($row in $egRows) {
    if (-not $placesByIso.ContainsKey($row.iso2)) {
        $placeType = if ($row.iso2 -eq 'MO') { 'special_administrative_region' } else { 'sovereign_country' }
        $placesByIso[$row.iso2] = [pscustomobject][ordered]@{
            place_id = "PLC-$($row.iso2)"
            iso2 = $row.iso2
            name_en = $row.destination_en
            name_ar = $row.destination_ar
            place_type = $placeType
            parent_place_id = ''
            region_en = ''
            region_ar = ''
            coverage_status = 'identity_only'
            last_verified = $row.last_verified
            next_review_due = (Get-IsoDatePlusDays -Date $row.last_verified -Days 30)
            source_dataset_id = 'DSET-EG-PASS-2026-V13'
            notes = 'Added as an entry-rule destination; country basics are not yet populated.'
        }
    }
}
$places = @($placesByIso.Values | Sort-Object place_id)

$planningProfiles = foreach ($row in $saRows) {
    [pscustomobject][ordered]@{
        planning_profile_id = "PLAN-$($row.iso2)-V1-1"
        place_id = "PLC-$($row.iso2)"
        source_dataset_id = 'DSET-SA-2026-V1-1'
        version = $row.version
        checked_on = $row.checked_on
        next_review_due = $row.next_review_due
        suggested_days_min_editorial = $row.suggested_days_min
        suggested_days_max_editorial = $row.suggested_days_max
        buffer_days_editorial = $row.buffer_days
        gateway_city_editorial = $row.gateway_city
        gateway_iata_codes = $row.gateway_iata_codes
        gateway_note = $row.gateway_note
        route_intensity_editorial = $row.route_intensity_editorial
        seasonality_note = $row.seasonality_note
        signature_experience_1_editorial = $row.signature_experience_1
        signature_experience_2_editorial = $row.signature_experience_2
        official_tourism_url = $row.official_tourism_url
        official_entry_url = $row.official_entry_url
        review_status = $row.status
        operational_note = $row.operational_note
    }
}

$isoByCountryName = @{}
foreach ($row in $saRows) { $isoByCountryName[$row.country] = $row.iso2 }
$isoByArabicDestination = @{}
foreach ($row in $egRows) { $isoByArabicDestination[$row.destination_ar] = $row.iso2 }

$normalizedSources = New-Object System.Collections.Generic.List[object]
foreach ($source in $saSourceRows) {
    $iso = $isoByCountryName[$source.country]
    $volatility = switch ($source.field_type) {
        'entry' { 'V3_REGULATORY' }
        'operational_alert' { 'V4_OPERATIONAL' }
        default { 'V2_PLANNING' }
    }
    $tier = if ($source.source_type -match 'immigration|foreign affairs|consular') { 'A_CONTROLLING_OR_PRIMARY' } else { 'B_OFFICIAL_OPERATIONAL' }
    $normalizedSources.Add([pscustomobject][ordered]@{
        source_id = "SRC-SA-$($source.source_id)"
        source_dataset_id = 'DSET-SA-2026-V1-1'
        place_id = "PLC-$iso"
        source_title = $source.field_supported
        source_organization = $source.source_organization
        source_type = $source.source_type
        source_role = 'official source'
        field_type = $source.field_type
        evidence_scope = $source.field_supported
        url = $source.url
        checked_on = $source.checked_on
        next_review_due = $source.next_review_due
        volatility_class = $volatility
        authority_tier = $tier
        automation_eligible = 'true'
        update_boundary = if ($volatility -in @('V3_REGULATORY', 'V4_OPERATIONAL')) { 'report_only' } else { 'propose_only' }
        notes = $source.note
    })
}

foreach ($source in $egSourceRows) {
    $iso = $isoByArabicDestination[$source.destination_ar]
    $tier = if ($source.source_role_ar -eq $ArabicPrimaryGovernmentSource) { 'A_CONTROLLING_OR_PRIMARY' } else { 'B_OFFICIAL_OPERATIONAL' }
    $normalizedSources.Add([pscustomobject][ordered]@{
        source_id = "SRC-EG-$($source.source_id)"
        source_dataset_id = 'DSET-EG-PASS-2026-V13'
        place_id = "PLC-$iso"
        source_title = $source.source_title
        source_organization = ''
        source_type = 'official government or operational source'
        source_role = $source.source_role_ar
        field_type = 'entry'
        evidence_scope = $source.evidence_scope_ar
        url = $source.source_url
        checked_on = $source.last_verified
        next_review_due = (Get-IsoDatePlusDays -Date $source.last_verified -Days 30)
        volatility_class = 'V3_REGULATORY'
        authority_tier = $tier
        automation_eligible = 'true'
        update_boundary = 'report_only'
        notes = 'Imported from Egyptian Passport Entry Rules v13 source registry.'
    })
}

# Preserve official secondary URLs cited by route rows even when the legacy v13
# source registry omitted them. They are labelled supplemental and do not alter
# the published source_count of the input dataset.
$registeredEgUrls = @{}; foreach ($source in $egSourceRows) { $registeredEgUrls[$source.source_url] = $true }
$supplementalIndexByIso = @{}
foreach ($route in $egRows) {
    foreach ($url in @($route.official_source_url, $route.secondary_source_url)) {
        if (-not $url -or $registeredEgUrls.ContainsKey($url)) { continue }
        if (-not $supplementalIndexByIso.ContainsKey($route.iso2)) { $supplementalIndexByIso[$route.iso2] = 0 }
        $supplementalIndexByIso[$route.iso2]++
        $supplementalId = "SRC-EG-SUP-$($route.iso2)-$('{0:D2}' -f $supplementalIndexByIso[$route.iso2])"
        $normalizedSources.Add([pscustomobject][ordered]@{
            source_id = $supplementalId
            source_dataset_id = 'DSET-EG-PASS-2026-V13'
            place_id = "PLC-$($route.iso2)"
            source_title = "Supplemental official route source for $($route.record_id)"
            source_organization = ''
            source_type = 'official government or operational source'
            source_role = 'supplemental route-level source'
            field_type = 'entry'
            evidence_scope = "Secondary operational detail cited by $($route.record_id)"
            url = $url
            checked_on = $route.last_verified
            next_review_due = (Get-IsoDatePlusDays -Date $route.last_verified -Days 30)
            volatility_class = 'V3_REGULATORY'
            authority_tier = 'B_OFFICIAL_OPERATIONAL'
            automation_eligible = 'true'
            update_boundary = 'report_only'
            notes = 'Present in the v13 route table but omitted from the v13 source registry; preserved without upgrading evidence status.'
        })
        $registeredEgUrls[$url] = $true
    }
}
$normalizedSources = @($normalizedSources | Sort-Object source_id)

$sourceIdByUrl = @{}
foreach ($source in $normalizedSources) { $sourceIdByUrl[$source.url] = $source.source_id }

$entryRules = foreach ($row in $egRows) {
    $primarySourceId = $sourceIdByUrl[$row.official_source_url]
    if (-not $primarySourceId) { throw "No normalized source matches primary URL for $($row.record_id)" }
    $secondaryIds = ''
    if ($row.secondary_source_url) {
        $secondaryIds = $sourceIdByUrl[$row.secondary_source_url]
        if (-not $secondaryIds) { throw "No normalized source matches secondary URL for $($row.record_id)" }
    }
    [pscustomobject][ordered]@{
        entry_rule_id = $row.record_id
        origin_place_id = 'PLC-EG'
        destination_place_id = "PLC-$($row.iso2)"
        document_type = 'ordinary_passport'
        travel_purpose = 'tourism_short_visit'
        entry_method_en = $row.entry_method_en
        entry_method_ar = $row.entry_method_ar
        stay_or_validity_en_legacy = $row.stay_or_validity_en
        stay_or_validity_ar_legacy = $row.stay_or_validity_ar
        fees_en_legacy = $row.fees_en
        fees_ar_legacy = $row.fees_ar
        passport_validity_en = $row.passport_validity_en
        passport_validity_ar = $row.passport_validity_ar
        core_requirements_ar = $row.core_requirements_ar
        origin_named_explicitly = if ($row.egypt_named_explicitly -eq $ArabicYes) { 'true' } else { 'false' }
        rule_basis_ar = $row.rule_basis_ar
        primary_source_id = $primarySourceId
        secondary_source_ids = $secondaryIds
        last_verified = $row.last_verified
        next_review_due = (Get-IsoDatePlusDays -Date $row.last_verified -Days 30)
        source_dataset_id = 'DSET-EG-PASS-2026-V13'
        source_version = $row.dataset_version
        verification_status = 'verified_as_of_date'
        freshness_status = 'current'
        editorial_note_ar = $row.editorial_note_ar
    }
}

$fieldEvidence = New-Object System.Collections.Generic.List[object]
$sourceFieldMaps = @(
    @{ Column = 'seasonality_source_ids'; Field = 'seasonality_note'; Code = 'SEA'; Kind = 'official_source_synthesis'; Confidence = 'authoritative' },
    @{ Column = 'gateway_source_ids'; Field = 'gateway_note'; Code = 'GAT'; Kind = 'official_source_synthesis'; Confidence = 'authoritative' },
    @{ Column = 'experience_source_ids'; Field = 'signature_experiences'; Code = 'EXP'; Kind = 'editorial_judgment'; Confidence = 'editorial' },
    @{ Column = 'tourism_source_ids'; Field = 'official_tourism_url'; Code = 'TOU'; Kind = 'official_fact'; Confidence = 'authoritative' },
    @{ Column = 'entry_source_id'; Field = 'official_entry_url'; Code = 'ENT'; Kind = 'official_fact'; Confidence = 'authoritative' },
    @{ Column = 'operational_alert_source_ids'; Field = 'operational_note'; Code = 'ALT'; Kind = 'official_source_synthesis'; Confidence = 'provisional' }
)

foreach ($row in $saRows) {
    $recordId = "PLAN-$($row.iso2)-V1-1"
    foreach ($map in $sourceFieldMaps) {
        $rawIds = $row.($map.Column)
        if ($rawIds) {
            $seq = 0
            foreach ($legacySourceId in @($rawIds -split '\|' | Where-Object { $_ })) {
                $seq++
                $fieldEvidence.Add([pscustomobject][ordered]@{
                    evidence_edge_id = "EVD-SA-$($row.iso2)-$($map.Code)-$('{0:D2}' -f $seq)"
                    record_type = 'planning_profile'
                    record_id = $recordId
                    field_name = $map.Field
                    claim_kind = $map.Kind
                    source_id = "SRC-SA-$legacySourceId"
                    evidence_role = if ($map.Kind -eq 'editorial_judgment') { 'supporting' } else { 'primary' }
                    confidence_label = $map.Confidence
                    source_dataset_id = 'DSET-SA-2026-V1-1'
                    notes = 'Imported field-to-source link from South America v1.1.'
                })
            }
        }
    }

    $editorialFields = @(
        'suggested_days_range_editorial',
        'buffer_days_editorial',
        'gateway_city_editorial',
        'route_intensity_editorial',
        'signature_experience_1_editorial',
        'signature_experience_2_editorial'
    )
    $editorialSeq = 0
    foreach ($field in $editorialFields) {
        $editorialSeq++
        $fieldEvidence.Add([pscustomobject][ordered]@{
            evidence_edge_id = "EVD-SA-$($row.iso2)-EDT-$('{0:D2}' -f $editorialSeq)"
            record_type = 'planning_profile'
            record_id = $recordId
            field_name = $field
            claim_kind = 'editorial_judgment'
            source_id = ''
            evidence_role = 'editorial_only'
            confidence_label = 'editorial'
            source_dataset_id = 'DSET-SA-2026-V1-1'
            notes = 'Explicitly labelled VisaAdvisor editorial judgment; no government recommendation is claimed.'
        })
    }
}

foreach ($rule in $entryRules) {
    $fieldEvidence.Add([pscustomobject][ordered]@{
        evidence_edge_id = "EVD-EG-$($rule.entry_rule_id)-PRI"
        record_type = 'entry_rule'
        record_id = $rule.entry_rule_id
        field_name = 'legacy_entry_rule_bundle'
        claim_kind = 'official_source_synthesis'
        source_id = $rule.primary_source_id
        evidence_role = 'primary'
        confidence_label = 'authoritative'
        source_dataset_id = 'DSET-EG-PASS-2026-V13'
        notes = 'Legacy bundle pending atomic split of stay, validity, fees, and requirements.'
    })
    if ($rule.secondary_source_ids) {
        $fieldEvidence.Add([pscustomobject][ordered]@{
            evidence_edge_id = "EVD-EG-$($rule.entry_rule_id)-SUP"
            record_type = 'entry_rule'
            record_id = $rule.entry_rule_id
            field_name = 'legacy_entry_rule_bundle'
            claim_kind = 'official_source_synthesis'
            source_id = $rule.secondary_source_ids
            evidence_role = 'supporting'
            confidence_label = 'corroborated'
            source_dataset_id = 'DSET-EG-PASS-2026-V13'
            notes = 'Supporting or operational source retained from v13.'
        })
    }
}
$fieldEvidence = @($fieldEvidence | Sort-Object evidence_edge_id)

$coverageMatrix = @(
    [pscustomobject][ordered]@{ coverage_id = 'COV-JURISDICTIONS'; domain = 'jurisdiction_identity'; scope = 'Seed jurisdictions'; coverage_status = 'partial'; record_count = $places.Count; verified_record_count = @($places | Where-Object coverage_status -eq 'partial_verified').Count; stale_or_due_count = @($places | Where-Object coverage_status -eq 'provisional').Count; release_id = $ReleaseId; notes = '11 planning-linked jurisdictions are current; Venezuela is provisional and due; 9 additional jurisdictions are identity-only entry-rule records.' },
    [pscustomobject][ordered]@{ coverage_id = 'COV-SA-PLANNING'; domain = 'travel_planning'; scope = '12 sovereign South American countries'; coverage_status = 'partial'; record_count = $planningProfiles.Count; verified_record_count = 11; stale_or_due_count = 1; release_id = $ReleaseId; notes = 'Venezuela provisional operational alert is due for review on 2026-08-09.' },
    [pscustomobject][ordered]@{ coverage_id = 'COV-EG-ENTRY'; domain = 'entry_rules'; scope = 'Ordinary Egyptian passport; selected tourism short visits'; coverage_status = 'partial'; record_count = $entryRules.Count; verified_record_count = $entryRules.Count; stale_or_due_count = 0; release_id = $ReleaseId; notes = 'Verified as of 2026-07-26; 30-day review target assigned by Country Hub policy.' },
    [pscustomobject][ordered]@{ coverage_id = 'COV-CITIES'; domain = 'cities'; scope = 'Global'; coverage_status = 'schema_only'; record_count = 0; verified_record_count = 0; stale_or_due_count = 0; release_id = $ReleaseId; notes = 'No city facts imported in v0.1.0.' },
    [pscustomobject][ordered]@{ coverage_id = 'COV-COST'; domain = 'cost'; scope = 'Global'; coverage_status = 'schema_only'; record_count = 0; verified_record_count = 0; stale_or_due_count = 0; release_id = $ReleaseId; notes = 'Methodology-backed observations required.' },
    [pscustomobject][ordered]@{ coverage_id = 'COV-SAFETY'; domain = 'safety'; scope = 'Global'; coverage_status = 'schema_only'; record_count = 0; verified_record_count = 0; stale_or_due_count = 0; release_id = $ReleaseId; notes = 'No universal VisaAdvisor safety score is asserted.' },
    [pscustomobject][ordered]@{ coverage_id = 'COV-CONNECTIVITY'; domain = 'connectivity'; scope = 'Global'; coverage_status = 'schema_only'; record_count = 0; verified_record_count = 0; stale_or_due_count = 0; release_id = $ReleaseId; notes = 'Provider offers and independent observations will be separated.' },
    [pscustomobject][ordered]@{ coverage_id = 'COV-HEALTHCARE'; domain = 'healthcare'; scope = 'Global'; coverage_status = 'schema_only'; record_count = 0; verified_record_count = 0; stale_or_due_count = 0; release_id = $ReleaseId; notes = 'Official facility directories and visitor-access facts required.' },
    [pscustomobject][ordered]@{ coverage_id = 'COV-IMMIGRATION'; domain = 'immigration'; scope = 'Global'; coverage_status = 'schema_only'; record_count = 0; verified_record_count = 0; stale_or_due_count = 0; release_id = $ReleaseId; notes = 'Government primary sources and professional-review safeguards required.' }
)

$changeLog = @(
    [pscustomobject][ordered]@{
        change_id = 'CHG-0.1.0-001'
        release_id = $ReleaseId
        change_type = 'foundation'
        changed_on = $ReleaseDate
        summary = 'Created Country Hub contracts and imported two existing source-linked releases as a non-promoted seed.'
        source_or_issue = 'DSET-SA-2026-V1-1|DSET-EG-PASS-2026-V13'
        approval_status = 'pending_review'
    }
)

Export-HubCsv -Rows $datasets -Path (Join-Path $OutputDir 'datasets.csv')
Export-HubCsv -Rows $places -Path (Join-Path $OutputDir 'places.csv')
Export-HubCsv -Rows $planningProfiles -Path (Join-Path $OutputDir 'country-planning-profiles.csv')
Export-HubCsv -Rows $entryRules -Path (Join-Path $OutputDir 'passport-entry-rules.csv')
Export-HubCsv -Rows $normalizedSources -Path (Join-Path $OutputDir 'sources.csv')
Export-HubCsv -Rows $fieldEvidence -Path (Join-Path $OutputDir 'field-evidence.csv')
Export-HubCsv -Rows $coverageMatrix -Path (Join-Path $OutputDir 'coverage-matrix.csv')
Export-HubCsv -Rows $changeLog -Path (Join-Path $OutputDir 'change-log.csv')

$manifest = [ordered]@{
    release_id = $ReleaseId
    version = $ReleaseVersion
    release_date = $ReleaseDate
    status = 'foundation_seed_pre_release'
    inputs = @(
        [ordered]@{ dataset_id = 'DSET-SA-2026-V1-1'; path = 'inputs/upstream/south-america-trip-planning-dataset-2026-v1-1.csv'; sha256 = (Get-FileHash -LiteralPath $SouthAmericaDataPath -Algorithm SHA256).Hash.ToLowerInvariant(); records = $saRows.Count },
        [ordered]@{ dataset_id = 'DSET-SA-2026-V1-1-SOURCES'; path = 'inputs/upstream/south-america-trip-planning-sources-2026-v1-1.csv'; sha256 = (Get-FileHash -LiteralPath $SouthAmericaSourcesPath -Algorithm SHA256).Hash.ToLowerInvariant(); records = $saSourceRows.Count },
        [ordered]@{ dataset_id = 'DSET-EG-PASS-2026-V13'; path = 'inputs/upstream/egyptian-passport-entry-rules-2026-v13.csv'; sha256 = (Get-FileHash -LiteralPath $EgyptDataPath -Algorithm SHA256).Hash.ToLowerInvariant(); records = $egRows.Count },
        [ordered]@{ dataset_id = 'DSET-EG-PASS-2026-V13-SOURCES'; path = 'inputs/upstream/egyptian-passport-sources-2026-v13.csv'; sha256 = (Get-FileHash -LiteralPath $EgyptSourcesPath -Algorithm SHA256).Hash.ToLowerInvariant(); records = $egSourceRows.Count }
    )
    outputs = [ordered]@{
        datasets = $datasets.Count
        places = $places.Count
        planning_profiles = $planningProfiles.Count
        entry_rules = $entryRules.Count
        sources = $normalizedSources.Count
        field_evidence_edges = $fieldEvidence.Count
        coverage_rows = $coverageMatrix.Count
        change_rows = $changeLog.Count
    }
    important_limitations = @(
        'Import does not constitute a new live verification.',
        'Legacy stay_or_validity and fee text remain non-atomic pending reviewed normalization.',
        'Independent evidence-review and publishing approvals for high-stakes reuse are not recorded in this pre-release.',
        'Cities, cost, safety, connectivity, healthcare and immigration contain contracts only.',
        'Personal identity documents and contact details are excluded.'
    )
}
Write-HubUtf8Lf -Path (Join-Path $OutputDir 'release-manifest.json') -Content ($manifest | ConvertTo-Json -Depth 8)

$artifactFiles = Get-ChildItem -LiteralPath $OutputDir -File | Where-Object { $_.Name -notin @('checksums.sha256', 'validation-report.json') } | Sort-Object Name
$checksumLines = foreach ($file in $artifactFiles) {
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $($file.Name)"
}
Write-HubUtf8Lf -Path (Join-Path $OutputDir 'checksums.sha256') -Content (($checksumLines -join "`n") + "`n")

Write-Output ([pscustomobject]@{
    release = $ReleaseId
    output = $OutputDir
    datasets = $datasets.Count
    places = $places.Count
    planning_profiles = $planningProfiles.Count
    entry_rules = $entryRules.Count
    sources = $normalizedSources.Count
    evidence_edges = $fieldEvidence.Count
} | ConvertTo-Json -Compress)
