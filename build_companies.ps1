$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputDir = Join-Path $scriptDir "buddycode"
$outputFile = Join-Path $outputDir "companies.json"
$freqOutputFile = Join-Path $outputDir "frequencies.json"
$checkpointFile = Join-Path $outputDir "companies_checkpoint.json"
$freqCheckpointFile = Join-Path $outputDir "frequencies_checkpoint.json"

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Step 1: Get company list from the repo tree
Write-Host "Fetching repo tree..."
$treeUrl = "https://api.github.com/repos/snehasishroy/leetcode-companywise-interview-questions/git/trees/master"
$treeResponse = Invoke-RestMethod -Uri $treeUrl -Method GET -TimeoutSec 30
$companyNames = $treeResponse.tree | Where-Object { $_.type -eq "tree" } | ForEach-Object { $_.path } | Sort-Object
Write-Host "Found $($companyNames.Count) companies"

# Load checkpoint if exists
$result = @{}
if (Test-Path $checkpointFile) {
    Write-Host "Loading checkpoint..."
    $temp = Get-Content $checkpointFile -Raw | ConvertFrom-Json
    $result = @{}
    $temp.PSObject.Properties | ForEach-Object { $result[$_.Name] = [System.Collections.ArrayList]@($_.Value) }
}

$processed = 0
$skipped = 0
$failed = 0
$lastSave = 0

# Frequency tracking: slug -> @{ total = sum_of_freq%, count = num_companies }
$freqData = @{}
if (Test-Path $freqCheckpointFile) {
    Write-Host "Loading frequency checkpoint..."
    $tempFreq = Get-Content $freqCheckpointFile -Raw | ConvertFrom-Json
    $tempFreq.PSObject.Properties | ForEach-Object {
        $freqData[$_.Name] = @{ total = $_.Value.total; count = $_.Value.count }
    }
}

function Title-CaseCompany($name) {
    $words = $name -split '[-\s]'
    $cased = foreach ($w in $words) {
        if ($w.Length -gt 1) {
            $w.Substring(0,1).ToUpper() + $w.Substring(1).ToLower()
        } elseif ($w.Length -eq 1) {
            $w.ToUpper()
        } else {
            $w
        }
    }
    $cased -join ' '
}

function Extract-SlugFromUrl($url) {
    if ($url -match '/problems/([^/]+)') {
        return $Matches[1].ToLower()
    }
    return $null
}

# Map of special company name overrides for display
$nameOverrides = @{
    "bytedance" = "ByteDance"
    "de-shaw" = "DE Shaw"
    "dp-world" = "DP World"
    "hbo" = "HBO"
    "ibm" = "IBM"
    "tcs" = "TCS"
    "wipro" = "Wipro"
    "hcl" = "HCL"
    "amd" = "AMD"
    "att" = "AT&T"
    "bt-group" = "BT Group"
    "c3-ai" = "C3.ai"
    "lg" = "LG"
    "epam" = "EPAM"
    "mts" = "MTS"
    "sap" = "SAP"
    "dji" = "DJI"
    "bnp-paribas" = "BNP Paribas"
    "bny-mellon" = "BNY Mellon"
    "cme-group" = "CME Group"
    "cbre" = "CBRE"
    "deloitte" = "Deloitte"
    "ncr" = "NCR"
    "jpmc" = "JPMC"
    "dbs" = "DBS"
    "ubs" = "UBS"
    "hsbc" = "HSBC"
    "poshmark" = "Poshmark"
    "reddit" = "Reddit"
    "snapchat" = "Snapchat"
}

function Get-CompanyDisplayName($folderName) {
    if ($nameOverrides.ContainsKey($folderName)) {
        return $nameOverrides[$folderName]
    }
    return Title-CaseCompany $folderName
}

# Process each company
for ($i = 0; $i -lt $companyNames.Count; $i++) {
    $company = $companyNames[$i]
    $displayName = Get-CompanyDisplayName $company
    
    try {
        $csvUrl = "https://raw.githubusercontent.com/snehasishroy/leetcode-companywise-interview-questions/master/$company/all.csv"
        # Suppress progress bar for web request
        $oldProgress = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        $response = Invoke-WebRequest -Uri $csvUrl -Method GET -TimeoutSec 15 -UseBasicParsing
        $ProgressPreference = $oldProgress
        
        if ($response.StatusCode -eq 200) {
            $lines = $response.Content -split "`n" | Where-Object { $_.Trim() -ne "" }
            if ($lines.Count -gt 1) {
                # Skip header line
                $dataLines = $lines[1..($lines.Count - 1)]
                $problemCount = 0
                foreach ($line in $dataLines) {
                    # Parse CSV: ID, Title, URL, Difficulty, Acceptance%, Frequency%
                    # URL could contain commas if not properly quoted, but LeetCode URLs don't have commas
                    $parts = $line -split ','
                    if ($parts.Count -ge 3) {
                        # URL is in column index 2
                        # Title may be quoted, URL may be the unquoted part
                        # Better approach: extract URL by finding "https://leetcode.com/problems/"
                        if ($line -match 'https://leetcode\.com/problems/([^/,\s"]+)') {
                            $slug = $Matches[1].ToLower()
                            if (-not $result.ContainsKey($slug)) {
                                $result[$slug] = [System.Collections.ArrayList]@()
                            }
                            if ($result[$slug] -notcontains $displayName) {
                                [void]$result[$slug].Add($displayName)
                            }

                            # Extract frequency% (last numeric field in CSV)
                            $trimmed = $line.TrimEnd("`r`n ")
                            if ($trimmed -match ',(\d+\.?\d*)\s*$') {
                                $freqPct = [double]$Matches[1]
                                if (-not $freqData.ContainsKey($slug)) {
                                    $freqData[$slug] = @{ total = 0.0; count = 0 }
                                }
                                $freqData[$slug].total += $freqPct
                                $freqData[$slug].count += 1
                            }

                            $problemCount++
                        }
                    }
                }
                if ($problemCount -gt 0) {
                    $processed++
                } else {
                    $skipped++
                }
            } else {
                $skipped++
            }
        } else {
            $failed++
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.Value__
        if ($statusCode -eq 429 -or $statusCode -eq 403) {
            Write-Host "RATE LIMITED at company #$i ($company). Saving and stopping..."
            break
        } elseif ($statusCode -eq 404) {
            # No all.csv for this company
            $skipped++
        } else {
            Write-Host "  ERROR for $company : $_"
            $failed++
            # If it's a 429, break; otherwise continue
            if ($_ -match "429|Too Many Requests|rate limit") {
                Write-Host "RATE LIMITED. Saving and stopping..."
                break
            }
        }
    }
    
    # Print progress every 10 companies
    if ($i % 10 -eq 0) {
        Write-Host "Progress: $($i+1)/$($companyNames.Count) companies checked, $processed processed, $skipped skipped, $failed failed"
    }
    
    # Save checkpoint every 50 companies
    if ($processed - $lastSave -ge 50) {
        Write-Host "Saving checkpoint at $processed processed companies..."
        $output = @{}
        $result.GetEnumerator() | ForEach-Object { $output[$_.Key] = @($_.Value | Sort-Object) }
        $output | ConvertTo-Json -Depth 5 -Compress | Out-File $checkpointFile -Encoding UTF8

        $freqCheckpoint = @{}
        $freqData.GetEnumerator() | ForEach-Object {
            $freqCheckpoint[$_.Key] = @{ total = $_.Value.total; count = $_.Value.count }
        }
        $freqCheckpoint | ConvertTo-Json -Depth 3 -Compress | Out-File $freqCheckpointFile -Encoding UTF8

        $lastSave = $processed
    }
    
    # Small delay to be polite to the server
    Start-Sleep -Milliseconds 50
}

# Final save
Write-Host ""
Write-Host "========== FINAL RESULTS =========="
Write-Host "Companies checked: $($companyNames.Count)"
Write-Host "Successfully processed: $processed"
Write-Host "Skipped (empty/no data): $skipped"
Write-Host "Failed: $failed"
Write-Host "Current company index: $i"

# Convert hashtable of ArrayLists to sorted output
Write-Host "Building final JSON..."
$finalOutput = [ordered]@{}
$result.GetEnumerator() | Sort-Object Name | ForEach-Object {
    $finalOutput[$_.Key] = @($_.Value | Sort-Object)
}

Write-Host "Unique problems: $($finalOutput.Count)"

$json = $finalOutput | ConvertTo-Json -Depth 5
$json | Out-File $outputFile -Encoding UTF8

$fileInfo = Get-Item $outputFile
Write-Host "File size: $([math]::Round($fileInfo.Length / 1024, 1)) KB"
Write-Host "Output written to: $outputFile"

# Frequency output
Write-Host "Building frequencies.json..."
$finalFreq = [ordered]@{}
$freqData.GetEnumerator() | Sort-Object Name | ForEach-Object {
    $avg = [math]::Round($_.Value.total / $_.Value.count, 1)
    $finalFreq[$_.Key] = $avg
}
$finalFreq | ConvertTo-Json -Depth 2 -Compress | Out-File $freqOutputFile -Encoding UTF8
$freqFileInfo = Get-Item $freqOutputFile
Write-Host "Frequency file size: $([math]::Round($freqFileInfo.Length / 1024, 1)) KB"
Write-Host "Frequency output written to: $freqOutputFile"
Write-Host "Unique problems with frequency: $($finalFreq.Count)"
