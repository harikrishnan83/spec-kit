# Analyze current feature alignment with all existing features using systems thinking
param(
    [string]$Json = "",
    [string[]]$Args = @()
)

$JsonMode = $Json -eq "{ARGS}" -or $Args -contains "--json"
$AnalysisFocus = ($Args | Where-Object { $_ -ne "--json" }) -join " "
if ([string]::IsNullOrWhiteSpace($AnalysisFocus)) {
    $AnalysisFocus = "Comprehensive Analysis"
}

# Get repository root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$FallbackRoot = Resolve-Path (Join-Path $ScriptDir "../..")

try {
    $RepoRoot = git rev-parse --show-toplevel 2>$null
    $HasGit = $true
} catch {
    $RepoRoot = $FallbackRoot
    $HasGit = $false
}

Set-Location $RepoRoot

# Get current branch name and find current spec
if ($HasGit) {
    try {
        $CurrentBranch = git rev-parse --abbrev-ref HEAD 2>$null
    } catch {
        $CurrentBranch = ""
    }
} else {
    # If no git, try to determine current feature from specs directory
    $SpecsDirs = Get-ChildItem -Path "specs" -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    $CurrentBranch = if ($SpecsDirs) { $SpecsDirs[0].Name } else { "" }
}

if ([string]::IsNullOrWhiteSpace($CurrentBranch) -or $CurrentBranch -eq "main" -or $CurrentBranch -eq "master") {
    Write-Error "Error: Alignment analysis must be run from a feature branch (created by /specify)"
    exit 1
}

$CurrentSpec = Join-Path $RepoRoot "specs" $CurrentBranch "spec.md"
if (-not (Test-Path $CurrentSpec)) {
    Write-Error "Error: Current specification not found at $CurrentSpec"
    exit 1
}

# Find all existing specifications
$AllSpecs = @()
$SpecsDir = Join-Path $RepoRoot "specs"
if (Test-Path $SpecsDir) {
    $SpecDirs = Get-ChildItem -Path $SpecsDir -Directory
    foreach ($dir in $SpecDirs) {
        $SpecFile = Join-Path $dir.FullName "spec.md"
        if ((Test-Path $SpecFile) -and ($SpecFile -ne $CurrentSpec)) {
            $AllSpecs += $SpecFile
        }
    }
}

# Create analysis file in current feature directory
$FeatureDir = Split-Path -Parent $CurrentSpec
$AnalysisFile = Join-Path $FeatureDir "cross-feature-analysis.md"

# Create analysis file from template
$Template = Join-Path $RepoRoot "templates" "cross-feature-analysis-template.md"
if (Test-Path $Template) {
    Copy-Item $Template $AnalysisFile
} else {
    New-Item -ItemType File -Path $AnalysisFile -Force | Out-Null
}

# Add clarification line to current spec.md for /clarify to pick up
$ClarificationLine = "- [NEEDS CLARIFICATION: Review cross-feature alignment analysis in cross-feature-analysis.md - potential conflicts identified that may require spec adjustments]"

# Find the Requirements section and add the clarification line
if (Test-Path $CurrentSpec) {
    $SpecContent = Get-Content $CurrentSpec -Raw

    # Check if the clarification line already exists to avoid duplicates
    if (-not $SpecContent.Contains("cross-feature-analysis.md")) {
        $Lines = Get-Content $CurrentSpec
        $NewLines = @()
        $Added = $false

        foreach ($Line in $Lines) {
            $NewLines += $Line
            # Add clarification line after "### Functional Requirements"
            if ($Line -match "^### Functional Requirements" -and -not $Added) {
                $NewLines += $ClarificationLine
                $Added = $true
            }
        }

        # If no Functional Requirements section found, add to end
        if (-not $Added) {
            $NewLines += ""
            $NewLines += $ClarificationLine
        }

        # Write back to file
        $NewLines | Set-Content $CurrentSpec
    }
}

# Build output
if ($JsonMode) {
    $AllSpecsJson = $AllSpecs | ForEach-Object { "`"$_`"" } | Join-String -Separator ","
    $Output = @{
        CURRENT_SPEC = $CurrentSpec
        ALL_SPECS = $AllSpecs
        ANALYSIS_FILE = $AnalysisFile
        ANALYSIS_FOCUS = $AnalysisFocus
    }
    $Output | ConvertTo-Json -Compress
} else {
    Write-Output "CURRENT_SPEC: $CurrentSpec"
    Write-Output "ALL_SPECS: $($AllSpecs -join ' ')"
    Write-Output "ANALYSIS_FILE: $AnalysisFile"
    Write-Output "ANALYSIS_FOCUS: $AnalysisFocus"
}