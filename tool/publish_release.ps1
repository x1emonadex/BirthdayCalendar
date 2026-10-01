# Publishes a GitHub release with the APK and the Windows archive.
#
# The token comes from Git Credential Manager, where it is already stored by
# the earlier `git push`. It is never printed: only its length is reported.
#
# Usage (PowerShell):
#   .\tool\publish_release.ps1 -Tag v1.0.4
#
# The release notes are read from release_notes.txt next to this script.
param(
    [Parameter(Mandatory = $true)]
    [string]$Tag
)

$ErrorActionPreference = 'Stop'

$owner = 'x1emonadex'
$repo = 'BirthdayCalendar'
$version = $Tag.TrimStart('v')
$root = Split-Path $PSScriptRoot -Parent
$releaseDir = Join-Path $root 'release'

$gcm = 'C:\Program Files\Git\mingw64\bin\git-credential-manager.exe'
$queryFile = [System.IO.Path]::GetTempFileName()
@('protocol=https', 'host=github.com', 'username=x1emonadex', '') |
    Out-File -FilePath $queryFile -Encoding ascii

$token = cmd /c "`"$gcm`" get < `"$queryFile`" 2>nul" |
    Where-Object { $_ -like 'password=*' } |
    Select-Object -First 1
if ($token) { $token = $token.Substring(9) }
Remove-Item $queryFile -Force -ErrorAction SilentlyContinue
if (-not $token) { throw 'GCM returned no token' }

$headers = @{
    Authorization          = "Bearer $token"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent'           = 'birthday-calendar-release'
}

$assets = @(
    (Join-Path $releaseDir "birthday-calendar-$version-android.apk")
    (Join-Path $releaseDir "birthday-calendar-$version-windows.zip")
)
foreach ($a in $assets) {
    if (-not (Test-Path $a)) { throw "Missing asset: $a" }
}

$notesPath = Join-Path $PSScriptRoot 'release_notes.txt'
$notes = if (Test-Path $notesPath) {
    [System.IO.File]::ReadAllText($notesPath, [System.Text.Encoding]::UTF8)
} else {
    ''
}

$payload = @{
    tag_name                = $Tag
    target_commitish       = 'main'
    name                   = $Tag
    draft                  = $false
    prerelease             = $false
    generate_release_notes = $true
    body                   = $notes
} | ConvertTo-Json -Depth 5

$bodyFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText(
    $bodyFile, $payload, (New-Object System.Text.UTF8Encoding($false))
)
$release = Invoke-RestMethod `
    -Method Post `
    -Uri "https://api.github.com/repos/$owner/$repo/releases" `
    -Headers $headers `
    -ContentType 'application/json; charset=utf-8' `
    -InFile $bodyFile
Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue

Write-Host "Release created: $($release.html_url)"

foreach ($asset in $assets) {
    $name = Split-Path $asset -Leaf
    $bytes = [System.IO.File]::ReadAllBytes($asset)
    $upload = "https://uploads.github.com/repos/$owner/$repo/releases/" +
        "$($release.id)/assets?name=$([uri]::EscapeDataString($name))"
    $head = @{
        Authorization = "Bearer $token"
        Accept        = 'application/json'
        'User-Agent'  = 'birthday-calendar-release'
    }
    Invoke-RestMethod -Method Post -Uri $upload -Headers $head `
        -ContentType 'application/octet-stream' -Body $bytes | Out-Null
    Write-Host "Uploaded: $name"
}

Write-Host "Done: https://github.com/$owner/$repo/releases/tag/$Tag"
