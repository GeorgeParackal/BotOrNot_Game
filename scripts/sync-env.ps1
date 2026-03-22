$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $repoRoot ".env"
$configPath = Join-Path $repoRoot "src/server/GeminiConfig.luau"

if (-not (Test-Path $envPath)) {
    throw ".env file not found at $envPath"
}

$envMap = @{}
Get-Content -Path $envPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) {
        return
    }

    $parts = $line.Split("=", 2)
    if ($parts.Count -ne 2) {
        return
    }

    $key = $parts[0].Trim()
    $value = $parts[1].Trim()
    $envMap[$key] = $value
}

if (-not $envMap.ContainsKey("GEMINI_API_KEY") -or [string]::IsNullOrWhiteSpace($envMap["GEMINI_API_KEY"])) {
    throw "GEMINI_API_KEY is missing in .env"
}

$key = $envMap["GEMINI_API_KEY"] -replace "\\", "\\\\" -replace '"', '\"'

$configContent = @"
return {
    GEMINI_API_KEY = "$key",
}
"@

Set-Content -Path $configPath -Value $configContent -NoNewline
Write-Host "Generated $configPath"
