[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$HubRoot = Split-Path -Parent $PSScriptRoot
$DataDir = Join-Path $HubRoot 'data\seed\v0.1.0'
$ContractPath = Join-Path $HubRoot 'schema\table-contracts.json'
$ReportPath = Join-Path $DataDir 'validation-report.json'
$issues = New-Object System.Collections.Generic.List[object]

function Add-Issue {
    param([string]$Severity, [string]$Rule, [string]$Table, [string]$Record, [string]$Message)
    $script:issues.Add([pscustomobject][ordered]@{ severity = $Severity; rule = $Rule; table = $Table; record = $Record; message = $Message })
}

function Get-Utf8StringFromBase64 {
    param([Parameter(Mandatory)][string]$Value)
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
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

$ArabicSouthAmerica = Get-Utf8StringFromBase64 '2KPZhdix2YrZg9inINin2YTYrNmG2YjYqNmK2Kk='
$ArabicEgypt = Get-Utf8StringFromBase64 '2YXYtdix'

if (-not (Test-Path -LiteralPath $ContractPath -PathType Leaf)) { throw "Missing contracts: $ContractPath" }
$contracts = Get-Content -LiteralPath $ContractPath -Raw | ConvertFrom-Json
$tables = @{}

foreach ($tableProperty in $contracts.tables.PSObject.Properties) {
    $tableName = $tableProperty.Name
    $contract = $tableProperty.Value
    $path = Join-Path $DataDir $contract.file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Issue -Severity 'error' -Rule 'FILE_MISSING' -Table $tableName -Record '' -Message "Missing $($contract.file)"
        continue
    }
    $rows = @(Import-Csv -LiteralPath $path -Encoding UTF8)
    $tables[$tableName] = $rows
    if ($rows.Count -eq 0) {
        Add-Issue -Severity 'error' -Rule 'EMPTY_TABLE' -Table $tableName -Record '' -Message 'Seed release table must not be empty.'
        continue
    }

    $actualHeaders = @($rows[0].PSObject.Properties.Name)
    $expectedHeaders = @($contract.headers)
    if (($actualHeaders -join '|') -ne ($expectedHeaders -join '|')) {
        Add-Issue -Severity 'error' -Rule 'HEADER_MISMATCH' -Table $tableName -Record '' -Message "Expected $($expectedHeaders -join ', ')"
    }

    foreach ($column in @($contract.required)) {
        foreach ($row in $rows) {
            if ([string]::IsNullOrWhiteSpace([string]$row.$column)) {
                Add-Issue -Severity 'error' -Rule 'REQUIRED_VALUE' -Table $tableName -Record ([string]$row.($contract.primary_key)) -Message "Blank required column: $column"
            }
        }
    }

    $primaryKey = [string]$contract.primary_key
    $duplicates = $rows | Group-Object -Property $primaryKey | Where-Object { $_.Count -gt 1 }
    foreach ($duplicate in $duplicates) {
        Add-Issue -Severity 'error' -Rule 'DUPLICATE_PRIMARY_KEY' -Table $tableName -Record $duplicate.Name -Message "Primary key appears $($duplicate.Count) times."
    }

    if ($contract.enums) {
        foreach ($enumProperty in $contract.enums.PSObject.Properties) {
            $allowed = @($enumProperty.Value)
            foreach ($row in $rows) {
                $value = [string]$row.($enumProperty.Name)
                if ($value -and $value -notin $allowed) {
                    Add-Issue -Severity 'error' -Rule 'ENUM_VALUE' -Table $tableName -Record ([string]$row.$primaryKey) -Message "$($enumProperty.Name)=$value is not allowed."
                }
            }
        }
    }
}

$recordTypeTargets = @{
    planning_profile = @{ table = 'planning_profiles'; key = 'planning_profile_id' }
    entry_rule = @{ table = 'entry_rules'; key = 'entry_rule_id' }
}
foreach ($edge in @($tables.field_evidence)) {
    if (-not $recordTypeTargets.ContainsKey([string]$edge.record_type)) {
        Add-Issue -Severity 'error' -Rule 'EVIDENCE_RECORD_TYPE' -Table 'field_evidence' -Record $edge.evidence_edge_id -Message "Unknown record_type=$($edge.record_type)."
        continue
    }
    $target = $recordTypeTargets[[string]$edge.record_type]
    $targetContract = $contracts.tables.([string]$target.table)
    $declaredFields = @($targetContract.headers)
    if ($targetContract.virtual_fields) { $declaredFields += @($targetContract.virtual_fields.PSObject.Properties.Name) }
    if ([string]$edge.field_name -notin $declaredFields) {
        Add-Issue -Severity 'error' -Rule 'EVIDENCE_FIELD_TARGET' -Table 'field_evidence' -Record $edge.evidence_edge_id -Message "$($edge.record_type).$($edge.field_name) is not a declared column or virtual field."
    }
    $targetIds = @($tables[[string]$target.table] | ForEach-Object { [string]$_.$([string]$target.key) })
    if ([string]$edge.record_id -notin $targetIds) {
        Add-Issue -Severity 'error' -Rule 'EVIDENCE_RECORD_TARGET' -Table 'field_evidence' -Record $edge.evidence_edge_id -Message "$($edge.record_type) record $($edge.record_id) does not exist."
    }
}

foreach ($tableProperty in $contracts.tables.PSObject.Properties) {
    $tableName = $tableProperty.Name
    $contract = $tableProperty.Value
    if (-not $tables.ContainsKey($tableName)) { continue }
    foreach ($fk in @($contract.foreign_keys)) {
        if (-not $fk) { continue }
        $targetRows = @($tables.([string]$fk.table))
        $targetValues = @{}; foreach ($targetRow in $targetRows) { $targetValues[[string]$targetRow.([string]$fk.target)] = $true }
        foreach ($row in @($tables[$tableName])) {
            $value = [string]$row.([string]$fk.column)
            if ($value -and -not $targetValues.ContainsKey($value)) {
                Add-Issue -Severity 'error' -Rule 'FOREIGN_KEY' -Table $tableName -Record ([string]$row.([string]$contract.primary_key)) -Message "$($fk.column)=$value not found in $($fk.table).$($fk.target)"
            }
        }
    }
    foreach ($fk in @($contract.optional_foreign_keys)) {
        if (-not $fk) { continue }
        $targetRows = @($tables.([string]$fk.table))
        $targetValues = @{}; foreach ($targetRow in $targetRows) { $targetValues[[string]$targetRow.([string]$fk.target)] = $true }
        foreach ($row in @($tables[$tableName])) {
            $value = [string]$row.([string]$fk.column)
            if ($value -and -not $targetValues.ContainsKey($value)) {
                Add-Issue -Severity 'error' -Rule 'OPTIONAL_FOREIGN_KEY' -Table $tableName -Record ([string]$row.([string]$contract.primary_key)) -Message "$($fk.column)=$value not found in $($fk.table).$($fk.target)"
            }
        }
    }
}

foreach ($tableName in $tables.Keys) {
    $contract = $contracts.tables.$tableName
    foreach ($row in @($tables[$tableName])) {
        $record = [string]$row.([string]$contract.primary_key)
        foreach ($property in $row.PSObject.Properties) {
            $name = $property.Name
            $value = [string]$property.Value
            if (-not $value) { continue }
            if ($name -match '(checked_on|verified_on|last_verified|next_review_due|changed_on)$' -and $value -notmatch '^\d{4}-\d{2}-\d{2}$') {
                Add-Issue -Severity 'error' -Rule 'ISO_DATE' -Table $tableName -Record $record -Message "$name is not YYYY-MM-DD: $value"
            }
            if ($name -match '(^url$|_url$|^doi$|concept_doi$|canonical_url$)' -and $value -notmatch '^https://') {
                Add-Issue -Severity 'error' -Rule 'HTTPS_URL' -Table $tableName -Record $record -Message "$name must use HTTPS: $value"
            }
        }
        if ($row.PSObject.Properties.Name -contains 'iso2' -and $row.iso2 -notmatch '^[A-Z]{2}$') {
            Add-Issue -Severity 'error' -Rule 'ISO2' -Table $tableName -Record $record -Message "Invalid ISO2: $($row.iso2)"
        }
        if (($row.PSObject.Properties.Name -contains 'checked_on') -and ($row.PSObject.Properties.Name -contains 'next_review_due') -and $row.checked_on -and $row.next_review_due) {
            if ([datetime]$row.next_review_due -lt [datetime]$row.checked_on) {
                Add-Issue -Severity 'error' -Rule 'REVIEW_DATE_ORDER' -Table $tableName -Record $record -Message 'next_review_due precedes checked_on.'
            }
        }
        if (($row.PSObject.Properties.Name -contains 'last_verified') -and ($row.PSObject.Properties.Name -contains 'next_review_due') -and $row.last_verified -and $row.next_review_due) {
            if ([datetime]$row.next_review_due -lt [datetime]$row.last_verified) {
                Add-Issue -Severity 'error' -Rule 'REVIEW_DATE_ORDER' -Table $tableName -Record $record -Message 'next_review_due precedes last_verified.'
            }
        }
    }
}

$releaseDate = [datetime]'2026-08-09'
foreach ($rule in @($tables.entry_rules)) {
    $due = [datetime]$rule.next_review_due -le $releaseDate
    if ($due -and $rule.freshness_status -eq 'current') {
        Add-Issue -Severity 'error' -Rule 'FRESHNESS_DATE_STATUS' -Table 'entry_rules' -Record $rule.entry_rule_id -Message 'Record is due on or before release date but is marked current.'
    }
    if (-not $due -and $rule.freshness_status -ne 'current') {
        Add-Issue -Severity 'error' -Rule 'FRESHNESS_DATE_STATUS' -Table 'entry_rules' -Record $rule.entry_rule_id -Message 'Record is not yet due but is not marked current.'
    }
}

$coverageById = @{}; foreach ($row in @($tables.coverage_matrix)) { $coverageById[$row.coverage_id] = $row }
$coverageExpectations = @(
    @{ id = 'COV-JURISDICTIONS'; records = @($tables.places).Count; verified = @($tables.places | Where-Object coverage_status -eq 'partial_verified').Count; due = @($tables.places | Where-Object coverage_status -eq 'provisional').Count },
    @{ id = 'COV-SA-PLANNING'; records = @($tables.planning_profiles).Count; verified = @($tables.planning_profiles | Where-Object review_status -eq 'reviewed').Count; due = @($tables.planning_profiles | Where-Object review_status -eq 'provisional_alert').Count },
    @{ id = 'COV-EG-ENTRY'; records = @($tables.entry_rules).Count; verified = @($tables.entry_rules | Where-Object { $_.verification_status -eq 'verified_as_of_date' -and $_.freshness_status -eq 'current' }).Count; due = @($tables.entry_rules | Where-Object freshness_status -ne 'current').Count }
)
foreach ($expected in $coverageExpectations) {
    if (-not $coverageById.ContainsKey($expected.id)) {
        Add-Issue -Severity 'error' -Rule 'COVERAGE_ROW_MISSING' -Table 'coverage_matrix' -Record $expected.id -Message 'Required coverage summary row is missing.'
        continue
    }
    $actual = $coverageById[$expected.id]
    if ([int]$actual.record_count -ne [int]$expected.records -or [int]$actual.verified_record_count -ne [int]$expected.verified -or [int]$actual.stale_or_due_count -ne [int]$expected.due) {
        Add-Issue -Severity 'error' -Rule 'COVERAGE_COUNT_RECONCILIATION' -Table 'coverage_matrix' -Record $expected.id -Message "Expected record/verified/due=$($expected.records)/$($expected.verified)/$($expected.due); found $($actual.record_count)/$($actual.verified_record_count)/$($actual.stale_or_due_count)."
    }
}

$manifestPath = Join-Path $DataDir 'release-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Add-Issue -Severity 'error' -Rule 'RELEASE_MANIFEST_MISSING' -Table 'release' -Record 'CH-0.1.0' -Message 'release-manifest.json is missing.'
} else {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $expectedOutputs = @{
        datasets = @($tables.datasets).Count
        places = @($tables.places).Count
        planning_profiles = @($tables.planning_profiles).Count
        entry_rules = @($tables.entry_rules).Count
        sources = @($tables.sources).Count
        field_evidence_edges = @($tables.field_evidence).Count
        coverage_rows = @($tables.coverage_matrix).Count
        change_rows = @($tables.change_log).Count
    }
    foreach ($name in $expectedOutputs.Keys) {
        if ([int]$manifest.outputs.$name -ne [int]$expectedOutputs[$name]) {
            Add-Issue -Severity 'error' -Rule 'MANIFEST_OUTPUT_COUNT' -Table 'release' -Record 'CH-0.1.0' -Message "Manifest $name=$($manifest.outputs.$name); expected $($expectedOutputs[$name])."
        }
    }
    foreach ($input in @($manifest.inputs)) {
        $inputPath = [IO.Path]::GetFullPath((Join-Path $HubRoot ([string]$input.path)))
        if (-not $inputPath.StartsWith([IO.Path]::GetFullPath($HubRoot), [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
            Add-Issue -Severity 'error' -Rule 'MANIFEST_INPUT_PATH' -Table 'release' -Record ([string]$input.dataset_id) -Message 'Manifest input path is missing or outside the repository.'
            continue
        }
        $actualHash = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne [string]$input.sha256) {
            Add-Issue -Severity 'error' -Rule 'MANIFEST_INPUT_HASH' -Table 'release' -Record ([string]$input.dataset_id) -Message 'Manifest input hash does not match the bundled input.'
        }
    }
    if ([string]$manifest.status -eq 'foundation_seed_pre_release' -and @($tables.change_log | Where-Object approval_status -ne 'pending_review').Count -gt 0) {
        Add-Issue -Severity 'error' -Rule 'PRE_RELEASE_APPROVAL_STATE' -Table 'change_log' -Record '' -Message 'A foundation pre-release must keep unrecorded independent approvals pending.'
    }
}

$checksumPath = Join-Path $DataDir 'checksums.sha256'
if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
    Add-Issue -Severity 'error' -Rule 'CHECKSUM_MANIFEST_MISSING' -Table 'release' -Record 'CH-0.1.0' -Message 'checksums.sha256 is missing.'
} else {
    foreach ($line in @(Get-Content -LiteralPath $checksumPath)) {
        if ($line -notmatch '^([0-9a-f]{64})  ([^/\\]+)$') {
            Add-Issue -Severity 'error' -Rule 'CHECKSUM_LINE_FORMAT' -Table 'release' -Record 'CH-0.1.0' -Message "Malformed checksum line: $line"
            continue
        }
        $expectedHash = $Matches[1]
        $artifactName = $Matches[2]
        $artifactPath = Join-Path $DataDir $artifactName
        if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
            Add-Issue -Severity 'error' -Rule 'CHECKSUM_FILE_MISSING' -Table 'release' -Record $artifactName -Message 'Checksummed artifact is missing.'
            continue
        }
        $actualHash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            Add-Issue -Severity 'error' -Rule 'CHECKSUM_MISMATCH' -Table 'release' -Record $artifactName -Message 'Artifact hash does not match checksums.sha256.'
        }
    }
}

$minimums = @{ datasets = 2; places = 21; planning_profiles = 12; entry_rules = 8; sources = 58; field_evidence = 140; coverage_matrix = 9; change_log = 1 }
foreach ($name in $minimums.Keys) {
    if (-not $tables.ContainsKey($name) -or @($tables[$name]).Count -lt $minimums[$name]) {
        Add-Issue -Severity 'error' -Rule 'MINIMUM_ROW_COUNT' -Table $name -Record '' -Message "Expected at least $($minimums[$name]) rows."
    }
}

$entryDestinationIds = @($tables.entry_rules | ForEach-Object { $_.destination_place_id })
if (@($entryDestinationIds | Sort-Object -Unique).Count -ne 8) {
    Add-Issue -Severity 'error' -Rule 'ENTRY_DESTINATION_UNIQUENESS' -Table 'entry_rules' -Record '' -Message 'Expected eight unique destination jurisdictions.'
}

$egyptPlace = @($tables.places | Where-Object place_id -eq 'PLC-EG')
if ($egyptPlace.Count -ne 1 -or $egyptPlace[0].name_ar -ne $ArabicEgypt) {
    Add-Issue -Severity 'error' -Rule 'ARABIC_IDENTITY_VALUE' -Table 'places' -Record 'PLC-EG' -Message 'Egypt Arabic name is missing or incorrectly encoded.'
}

foreach ($place in @($tables.places | Where-Object region_en -eq 'South America')) {
    if ($place.region_ar -ne $ArabicSouthAmerica) {
        Add-Issue -Severity 'error' -Rule 'ARABIC_REGION_VALUE' -Table 'places' -Record $place.place_id -Message 'South America Arabic region value is missing or incorrectly encoded.'
    }
}

$expectedExplicitOriginIds = @('EGY-KEN-2026', 'EGY-MAC-2026', 'EGY-TZA-2026')
$actualExplicitOriginIds = @($tables.entry_rules | Where-Object origin_named_explicitly -eq 'true' | ForEach-Object entry_rule_id | Sort-Object)
if (($actualExplicitOriginIds -join '|') -ne (($expectedExplicitOriginIds | Sort-Object) -join '|')) {
    Add-Issue -Severity 'error' -Rule 'EXPLICIT_ORIGIN_SET' -Table 'entry_rules' -Record '' -Message "Expected explicit-origin true set: $($expectedExplicitOriginIds -join ', '); found: $($actualExplicitOriginIds -join ', ')."
}

$expectedPrimaryEgyptSourceIds = @('SRC-EG-SRC-01', 'SRC-EG-SRC-02', 'SRC-EG-SRC-03', 'SRC-EG-SRC-05', 'SRC-EG-SRC-07', 'SRC-EG-SRC-09', 'SRC-EG-SRC-11', 'SRC-EG-SRC-12')
foreach ($source in @($tables.sources | Where-Object source_id -like 'SRC-EG-SRC-*')) {
    $expectedTier = if ($source.source_id -in $expectedPrimaryEgyptSourceIds) { 'A_CONTROLLING_OR_PRIMARY' } else { 'B_OFFICIAL_OPERATIONAL' }
    if ($source.authority_tier -ne $expectedTier) {
        Add-Issue -Severity 'error' -Rule 'EGYPT_SOURCE_AUTHORITY_TIER' -Table 'sources' -Record $source.source_id -Message "Expected authority_tier=$expectedTier; found $($source.authority_tier)."
    }
}

# U+00D8 and U+00D9 are the leading artifacts produced when UTF-8 Arabic is
# decoded as a Western code page; U+FFFD is the replacement character.
$mojibakeMarkers = @([char]0x00D8, [char]0x00D9, [char]0xFFFD)
foreach ($tableName in $tables.Keys) {
    $contract = $contracts.tables.$tableName
    foreach ($row in @($tables[$tableName])) {
        $record = [string]$row.([string]$contract.primary_key)
        foreach ($property in $row.PSObject.Properties) {
            $value = [string]$property.Value
            foreach ($marker in $mojibakeMarkers) {
                if ($value.Contains([string]$marker)) {
                    Add-Issue -Severity 'error' -Rule 'TEXT_ENCODING' -Table $tableName -Record $record -Message "Possible UTF-8 decoding artifact in $($property.Name)."
                    break
                }
            }
        }
    }
}

$forbiddenHeaders = '(^|_)(passport_number|document_number|dni|cuil|cuit|birth_date|date_of_birth|phone_number|mrz)($|_)|^(signature|signature_image)$'
foreach ($tableName in $tables.Keys) {
    $headers = @($tables[$tableName][0].PSObject.Properties.Name)
    foreach ($header in $headers) {
        if ($header -match $forbiddenHeaders) {
            Add-Issue -Severity 'error' -Rule 'PUBLIC_PII_FIELD' -Table $tableName -Record '' -Message "Forbidden public PII column: $header"
        }
    }
}

$errorCount = @($issues | Where-Object severity -eq 'error').Count
$warningCount = @($issues | Where-Object severity -eq 'warning').Count
$validationStatus = if ($errorCount -eq 0) { 'pass' } else { 'fail' }
$issueArray = @($issues | ForEach-Object { $_ })
$report = [ordered]@{
    release_id = 'CH-0.1.0'
    validated_on = '2026-08-09'
    status = $validationStatus
    error_count = $errorCount
    warning_count = $warningCount
    table_counts = [ordered]@{}
    issues = $issueArray
}
foreach ($name in ($tables.Keys | Sort-Object)) { $report.table_counts[$name] = @($tables[$name]).Count }
Write-HubUtf8Lf -Path $ReportPath -Content ($report | ConvertTo-Json -Depth 8)

if ($errorCount -gt 0) {
    $issues | Format-Table -AutoSize | Out-String | Write-Error
    exit 1
}

Write-Output ($report | ConvertTo-Json -Depth 8 -Compress)
