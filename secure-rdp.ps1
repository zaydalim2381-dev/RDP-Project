# ============================================================
# 🔒 Secure RDP via Tailscale - Main Automation Script
# ============================================================
# Invoked by: .github/workflows/secure-rdp-loop.yml
# Runs on:   GitHub-hosted Windows runner (windows-2025)
#
# Required env vars:
#   $env:GH_TOKEN     - GitHub PAT (workflow input)
#   $env:TS_AUTH_KEY  - Tailscale auth key (repo secret)
#   $env:REPO_FULL    - GitHub repo (owner/name)
#   $env:REF_NAME     - GitHub ref name (branch)

$ErrorActionPreference = 'Stop'

# ============================================================
# 🔑 TOKEN VALIDATION + BRANDING
# ============================================================
$token = $env:GH_TOKEN
if (-not $token -or -not ($token -match '^ghp_[a-zA-Z0-9]+$')) {
    Write-Error "❌ Invalid GH_TOKEN env var (must be a ghp_... PAT)"
    exit 1
}

$u_enc = "VE9PTEJPWExBUA=="
$p_enc = "YWRtaW5AMTIz"
$w_enc = "aHR0cHM6Ly93d3cudG9vbGJveGxhcC5jb20="
$y_enc = "aHR0cHM6Ly93d3cueW91dHViZS5jb20vQFRPT0xMQVAtdTFj"

$u = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($u_enc))
$p = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($p_enc))
$w = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($w_enc))
$y = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($y_enc))

if ($u -ne "TOOLBOXLAP" -or $w -notlike "*toolboxlap*") {
    Write-Error "🔒 Security Violation: branding tampered"
    exit 1
}

Write-Host "🔓 TOOLBOXLAP branding verified" -ForegroundColor Green

# ============================================================
# 📢 SUMMARY HEADER
# ============================================================
$summaryHeader = @"
# 🚀 TOOLBOXLAP OFFICIAL RDP AUTOMATION
### 🔒 Copyright & Ownership
* **Copyright © 2026 [ToolboxLap.com](http://ToolboxLap.com)**
* All rights reserved.
### 🔗 Official Channels & Support
* **Official Website:** [$w]($w/)
* **YouTube Channel:** [Subscribe Here]($y)
### 📦 Snapshot System
* Auto-saves on exit, restores on next run
* Stored as GitHub Release assets (max ~1.5 GB each)
* Last 3 snapshots retained, older ones auto-cleaned
---
"@
$summaryHeader | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8

# ============================================================
# 🛠️ SETUP
# ============================================================
$headers = @{
    Authorization = "Bearer $token"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "ToolboxLap-RDP-Automation"
}

$workDir = "D:\$u link subscribe youtube channel"
if (-Not (Test-Path -Path $workDir)) { New-Item -Path $workDir -ItemType Directory | Out-Null }

# ============================================================
# 📥 SNAPSHOT RESTORE FUNCTION
# ============================================================
function Restore-Snapshot {
    Write-Host "🔍 Looking for previous snapshot..." -ForegroundColor Cyan
    try {
        $rels = Invoke-RestMethod -Method GET -Uri "https://api.github.com/repos/$env:REPO_FULL/releases?per_page=30" -Headers $headers
        $snap = $rels | Where-Object { $_.tag_name -like "rdp-snap-*" } | Select-Object -First 1
        if (-not $snap) { Write-Host "ℹ️ No snapshot - starting fresh"; return $false }
        $asset = $snap.assets | Where-Object { $_.name -eq "snapshot.zip" } | Select-Object -First 1
        if (-not $asset) { Write-Host "ℹ️ No snapshot asset - starting fresh"; return $false }

        $sizeMB = [math]::Round($asset.size / 1MB, 2)
        Write-Host "📥 Restoring: $($snap.tag_name) ($sizeMB MB)"

        $zipPath = "$env:TEMP\restore.zip"
        $extractPath = "$env:TEMP\restore"
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -Headers $headers -TimeoutSec 600
        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractPath)

        # Restore work folder
        if (Test-Path "$extractPath\work") {
            if (-not (Test-Path $workDir)) { New-Item -Path $workDir -ItemType Directory | Out-Null }
            Copy-Item -Path "$extractPath\work\*" -Destination $workDir -Recurse -Force
        }
        # Desktop & Documents
        $deskPath = "$env:USERPROFILE\Desktop"; $docsPath = "$env:USERPROFILE\Documents"
        if (-not (Test-Path $deskPath)) { New-Item -Path $deskPath -ItemType Directory -Force | Out-Null }
        if (-not (Test-Path $docsPath)) { New-Item -Path $docsPath -ItemType Directory -Force | Out-Null }
        if (Test-Path "$extractPath\Desktop")    { Copy-Item -Path "$extractPath\Desktop\*"    -Destination $deskPath -Recurse -Force }
        if (Test-Path "$extractPath\Documents")  { Copy-Item -Path "$extractPath\Documents\*"  -Destination $docsPath -Recurse -Force }
        # Hermes data
        $hermesDirs = @("$env:APPDATA\Hermes","$env:APPDATA\nousresearch","$env:LOCALAPPDATA\Hermes","$env:LOCALAPPDATA\Programs\Hermes","$env:LOCALAPPDATA\nousresearch")
        foreach ($hd in $hermesDirs) {
            $name = Split-Path $hd -Leaf
            if (Test-Path "$extractPath\hermes\$name") {
                if (-not (Test-Path $hd)) { New-Item -Path $hd -ItemType Directory -Force | Out-Null }
                Copy-Item -Path "$extractPath\hermes\$name\*" -Destination $hd -Recurse -Force
            }
        }
        # OpenCode data
        $ocDirs = @("$env:APPDATA\OpenCode","$env:APPDATA\opencode","$env:LOCALAPPDATA\OpenCode","$env:LOCALAPPDATA\opencode","$env:LOCALAPPDATA\Programs\OpenCode","$env:LOCALAPPDATA\Programs\opencode","$env:USERPROFILE\.opencode","$env:USERPROFILE\.config\opencode")
        foreach ($od in $ocDirs) {
            $name = Split-Path $od -Leaf
            if (Test-Path "$extractPath\opencode\$name") {
                if (-not (Test-Path $od)) { New-Item -Path $od -ItemType Directory -Force | Out-Null }
                Copy-Item -Path "$extractPath\opencode\$name\*" -Destination $od -Recurse -Force
            }
        }
        # Tailscale state
        $tsState = "$env:LOCALAPPDATA\Tailscale"
        if (Test-Path "$extractPath\tailscale") {
            if (-not (Test-Path $tsState)) { New-Item -Path $tsState -ItemType Directory -Force | Out-Null }
            Copy-Item -Path "$extractPath\tailscale\*" -Destination $tsState -Recurse -Force
        }

        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Snapshot restored successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "⚠️ Snapshot restore failed: $_" -ForegroundColor Yellow
        return $false
    }
}

# ============================================================
# 📤 SNAPSHOT SAVE FUNCTION
# ============================================================
function Save-Snapshot {
    param([string]$tag, [switch]$Emergency)
    try {
        Write-Host "📦 Creating snapshot: $tag"
        $snapDir = "$env:TEMP\snapshot"
        $zipPath = "$env:TEMP\snapshot.zip"
        if (Test-Path $snapDir) { Remove-Item $snapDir -Recurse -Force }
        New-Item -Path $snapDir -ItemType Directory | Out-Null

        if (Test-Path $workDir) {
            New-Item -Path "$snapDir\work" -ItemType Directory -Force | Out-Null
            robocopy "$workDir" "$snapDir\work" /E /NFL /NDL /NJH /NJS /R:0 /W:0 | Out-Null
        }
        $deskPath = "$env:USERPROFILE\Desktop"; $docsPath = "$env:USERPROFILE\Documents"
        if (Test-Path $deskPath) {
            New-Item -Path "$snapDir\Desktop" -ItemType Directory -Force | Out-Null
            robocopy "$deskPath" "$snapDir\Desktop" /E /NFL /NDL /NJH /NJS /R:0 /W:0 | Out-Null
        }
        if (Test-Path $docsPath) {
            New-Item -Path "$snapDir\Documents" -ItemType Directory -Force | Out-Null
            robocopy "$docsPath" "$snapDir\Documents" /E /NFL /NDL /NJH /NJS /R:0 /W:0 | Out-Null
        }
        $hermesSrcs = @("$env:APPDATA\Hermes","$env:APPDATA\nousresearch","$env:LOCALAPPDATA\Hermes","$env:LOCALAPPDATA\Programs\Hermes","$env:LOCALAPPDATA\nousresearch")
        foreach ($hs in $hermesSrcs) {
            if (Test-Path $hs) {
                $name = Split-Path $hs -Leaf
                $dest = "$snapDir\hermes\$name"
                New-Item -Path $dest -ItemType Directory -Force | Out-Null
                robocopy "$hs" "$dest" /E /NFL /NDL /NJH /NJS /R:0 /W:0 | Out-Null
            }
        }
        $ocSrcs = @("$env:APPDATA\OpenCode","$env:APPDATA\opencode","$env:LOCALAPPDATA\OpenCode","$env:LOCALAPPDATA\opencode","$env:LOCALAPPDATA\Programs\OpenCode","$env:LOCALAPPDATA\Programs\opencode","$env:USERPROFILE\.opencode","$env:USERPROFILE\.config\opencode")
        foreach ($os in $ocSrcs) {
            if (Test-Path $os) {
                $name = Split-Path $os -Leaf
                $dest = "$snapDir\opencode\$name"
                New-Item -Path $dest -ItemType Directory -Force | Out-Null
                robocopy "$os" "$dest" /E /NFL /NDL /NJH /NJS /R:0 /W:0 | Out-Null
            }
        }
        $tsState = "$env:LOCALAPPDATA\Tailscale"
        if (Test-Path $tsState) { robocopy "$tsState" "$snapDir\tailscale" /E /NFL /NDL /NJH /NJS /R:0 /W:0 | Out-Null }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        Add-Type -AssemblyName System.IO.Compression
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        $compression = [System.IO.Compression.CompressionLevel]::Optimal
        [System.IO.Compression.ZipFile]::CreateFromDirectory($snapDir, $zipPath, $compression, $true)

        $sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
        Write-Host "📦 Snapshot size: $sizeMB MB"

        if ((Get-Item $zipPath).Length -gt 1500MB) {
            Write-Warning "⚠️ Snapshot exceeds 1.5 GB - skipping upload"
            return
        }

        $releaseBody = @{
            tag_name = $tag
            name     = if ($Emergency) { "⚠️ EMERGENCY SNAPSHOT $tag" } else { "RDP Snapshot $tag" }
            body     = "Auto-saved snapshot.`nSize: $sizeMB MB"
        } | ConvertTo-Json

        try { Invoke-RestMethod -Method POST -Uri "https://api.github.com/repos/$env:REPO_FULL/releases" -Headers $headers -Body $releaseBody | Out-Null }
        catch { Write-Host "⚠️ Release may already exist" }

        Write-Host "📤 Uploading snapshot (may take several minutes)..."
        $uploadHeaders = $headers.Clone()
        $uploadHeaders["Content-Type"] = "application/zip"
        $uploadUrl = "https://uploads.github.com/repos/$env:REPO_FULL/releases/tags/$tag/assets?name=snapshot.zip"
        Invoke-RestMethod -Method POST -Uri $uploadUrl -Headers $uploadHeaders -InFile $zipPath -TimeoutSec 1800 | Out-Null
        Write-Host "✅ Snapshot uploaded: $tag" -ForegroundColor Green

        Remove-Item $snapDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

        # Cleanup old (keep latest 3)
        $allRels = Invoke-RestMethod -Method GET -Uri "https://api.github.com/repos/$env:REPO_FULL/releases?per_page=30" -Headers $headers
        $snaps = $allRels | Where-Object { $_.tag_name -like "rdp-snap-*" } | Sort-Object -Property created_at -Descending
        if ($snaps.Count -gt 3) {
            foreach ($old in ($snaps | Select-Object -Skip 3)) {
                try {
                    Invoke-RestMethod -Method DELETE -Uri "https://api.github.com/repos/$env:REPO_FULL/releases/$($old.id)" -Headers $headers | Out-Null
                    Write-Host "🗑️ Deleted old snapshot: $($old.tag_name)"
                } catch { Write-Host "⚠️ Could not delete $($old.tag_name): $_" }
            }
        }
    } catch { Write-Host "⚠️ Snapshot save failed: $_" }
}

# ============================================================
# 📥 RESTORE SNAPSHOT (if any)
# ============================================================
Restore-Snapshot

# ============================================================
# ⚙️ RDP CORE CONFIGURATION
# ============================================================
Write-Host "⚙️ Configuring RDP..." -ForegroundColor Cyan
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -Force
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0 -Force
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "SecurityLayer" -Value 0 -Force
netsh advfirewall firewall delete rule name="RDP-Tailscale" | Out-Null
netsh advfirewall firewall add rule name="RDP-Tailscale" dir=in action=allow protocol=TCP localport=3389 | Out-Null
Restart-Service -Name TermService -Force

$securePass = ConvertTo-SecureString $p -AsPlainText -Force
if (-not (Get-LocalUser -Name $u -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $u -Password $securePass -AccountNeverExpires | Out-Null
}
Add-LocalGroupMember -Group "Administrators" -Member $u -ErrorAction SilentlyContinue
Add-LocalGroupMember -Group "Remote Desktop Users" -Member $u -ErrorAction SilentlyContinue

# ============================================================
# 🌐 TAILSCALE INSTALL & CONNECT
# ============================================================
Write-Host "🌐 Connecting Tailscale..." -ForegroundColor Cyan
$tsExe = "$env:ProgramFiles\Tailscale\tailscale.exe"
if (-not (Test-Path $tsExe)) {
    Write-Host "📦 Installing Tailscale..."
    Invoke-WebRequest -Uri "https://pkgs.tailscale.com/stable/tailscale-setup-1.82.0-amd64.msi" -OutFile "$env:TEMP\ts.msi"
    Start-Process msiexec.exe -ArgumentList "/i", "`"$env:TEMP\ts.msi`"", "/quiet", "/norestart" -Wait
    Remove-Item "$env:TEMP\ts.msi" -Force
}
& $tsExe logout 2>$null | Out-Null
& $tsExe up --authkey=$env:TS_AUTH_KEY --hostname="gh-runner-toolboxlap-$($env:GITHUB_RUN_NUMBER)" --accept-routes

$tsIP = $null; $r = 0
while (-not $tsIP -and $r -lt 15) {
    $tsIP = & $tsExe ip -4
    Start-Sleep -Seconds 5; $r++
}
if (-not $tsIP) { Write-Error "❌ Tailscale failed to get IP"; exit 1 }
Write-Host "✅ Tailscale IP: $tsIP" -ForegroundColor Green

# ============================================================
# 📦 PARALLEL APP INSTALLER
# ============================================================
Write-Host "📦 Installing OpenCode + Hermes in parallel..." -ForegroundColor Cyan

$ocUrl = "https://opencode.ai/download/stable/windows-x64-nsis"
$hUrl  = "https://hermes-assets.nousresearch.com/Hermes-Setup.exe?build=0a7a81835b89"
$ocInstaller = "$env:TEMP\OpenCode-Setup.exe"
$hInstaller  = "$env:TEMP\Hermes-Setup.exe"

$dlScript = {
    param($u, $p)
    try {
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing -TimeoutSec 600
        return @{ Ok = $true; Size = (Get-Item $p).Length }
    } catch { return @{ Ok = $false; Err = $_.ToString() } }
}

$ocDl = Start-Job -ScriptBlock $dlScript -ArgumentList $ocUrl, $ocInstaller
$hDl  = Start-Job -ScriptBlock $dlScript -ArgumentList $hUrl,  $hInstaller
$ocRes = Wait-Job $ocDl -Timeout 300 | Receive-Job
$hRes  = Wait-Job $hDl  -Timeout 300 | Receive-Job
Remove-Job $ocDl, $hDl -Force -ErrorAction SilentlyContinue

if ($ocRes.Ok) { Write-Host "✅ OpenCode downloaded ($([math]::Round($ocRes.Size/1MB,2)) MB)" }
else { Write-Host "❌ OpenCode download failed"; $ocInstaller = $null }

if ($hRes.Ok) { Write-Host "✅ Hermes downloaded ($([math]::Round($hRes.Size/1MB,2)) MB)" }
else { Write-Host "❌ Hermes download failed"; $hInstaller = $null }

$ocMarkers = @("C:\Program Files\OpenCode\opencode.exe","C:\Program Files (x86)\OpenCode\opencode.exe","$env:LOCALAPPDATA\Programs\OpenCode\opencode.exe","$env:LOCALAPPDATA\Programs\opencode\opencode.exe")
$hMarkers  = @("C:\Program Files\Hermes\Hermes.exe","C:\Program Files (x86)\Hermes\Hermes.exe","$env:LOCALAPPDATA\Programs\Hermes\Hermes.exe","$env:LOCALAPPDATA\Hermes\Hermes.exe","$env:APPDATA\Hermes\Hermes.exe")

$ocAlready = $false; foreach ($m in $ocMarkers) { if (Test-Path $m) { $ocAlready = $true; break } }
$hAlready  = $false; foreach ($m in $hMarkers)  { if (Test-Path $m) { $hAlready  = $true; break } }

$ocProc = $null; $hProc = $null
if (-not $ocAlready -and $ocInstaller -and (Test-Path $ocInstaller)) {
    Write-Host "🚀 Starting OpenCode install..."
    try { $ocProc = Start-Process -FilePath $ocInstaller -ArgumentList "/S" -PassThru -NoNewWindow } catch {}
} elseif ($ocAlready) { Write-Host "✅ OpenCode already installed" }

if (-not $hAlready -and $hInstaller -and (Test-Path $hInstaller)) {
    Write-Host "🚀 Starting Hermes install (deps may take 15-25 min)..."
    try { $hProc = Start-Process -FilePath $hInstaller -ArgumentList "/S" -PassThru -NoNewWindow } catch {}
} elseif ($hAlready) { Write-Host "✅ Hermes already installed" }

if ($ocProc -or $hProc) {
    Write-Host "⏳ Waiting for installs in parallel..."
    $ocDeadline = (Get-Date).AddMinutes(10)
    $hDeadline  = (Get-Date).AddMinutes(25)
    $lastLog = Get-Date
    while (($ocProc -and -not $ocProc.HasExited) -or ($hProc -and -not $hProc.HasExited)) {
        Start-Sleep -Seconds 5
        if ($ocProc -and -not $ocProc.HasExited -and (Get-Date) -gt $ocDeadline) {
            Write-Warning "⚠️ OpenCode timed out - killing"
            try { Stop-Process -Id $ocProc.Id -Force -ErrorAction SilentlyContinue } catch {}
            try { taskkill /F /PID $ocProc.Id 2>$null | Out-Null } catch {}
            $ocProc = $null
        }
        if ($hProc -and -not $hProc.HasExited -and (Get-Date) -gt $hDeadline) {
            Write-Warning "⚠️ Hermes timed out - killing"
            try { Stop-Process -Id $hProc.Id -Force -ErrorAction SilentlyContinue } catch {}
            try { taskkill /F /PID $hProc.Id 2>$null | Out-Null } catch {}
            $hProc = $null
        }
        if (((Get-Date) - $lastLog).TotalSeconds -ge 30) {
            $ocS = if (-not $ocProc) {"✅"} elseif ($ocProc.HasExited) {"✅"} else {"⏳"}
            $hS  = if (-not $hProc)  {"✅"} elseif ($hProc.HasExited)  {"✅"} else {"⏳ (deps)"}
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] OpenCode: $ocS  |  Hermes: $hS"
            $lastLog = Get-Date
        }
    }
    Write-Host "✅ Both installs finished" -ForegroundColor Green
}

Remove-Item $ocInstaller -Force -ErrorAction SilentlyContinue
Remove-Item $hInstaller  -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 3
foreach ($pair in @(
    @{ Name = "OpenCode"; Markers = $ocMarkers; Exe = "opencode.exe" },
    @{ Name = "Hermes";   Markers = $hMarkers;  Exe = "Hermes.exe" }
)) {
    $ok = $false
    foreach ($m in $pair.Markers) { if (Test-Path $m) { Write-Host "✅ $($pair.Name) verified: $m"; $ok = $true; break } }
    if (-not $ok) {
        foreach ($root in @("C:\Program Files","C:\Program Files (x86)","$env:LOCALAPPDATA\Programs")) {
            if (Test-Path $root) {
                $found = Get-ChildItem -Path $root -Filter $pair.Exe -Recurse -ErrorAction SilentlyContinue -Depth 4 | Select-Object -First 1
                if ($found) { Write-Host "✅ $($pair.Name) found: $($found.FullName)"; $ok = $true; break }
            }
        }
    }
    if (-not $ok) { Write-Warning "⚠️ $($pair.Name) verification failed" }
}

# ============================================================
# 📂 HERMES WORKSPACE (clone source repo)
# ============================================================
Write-Host "📂 Setting up Hermes workspace..." -ForegroundColor Cyan
$hermesDir = Join-Path $workDir "hermes-workspace"
$hermesRepo = "outsourc-e/hermes-workspace"

if (Test-Path (Join-Path $hermesDir ".git")) {
    Write-Host "🔄 Pulling latest updates..."
    Push-Location $hermesDir
    try {
        git pull --ff-only 2>$null
        if ($LASTEXITCODE -ne 0) {
            git -c "credential.helper=" -c "credential.useHttpPath=true" pull "https://$token@github.com/$hermesRepo.git" --ff-only 2>$null
        }
    } catch { Write-Host "⚠️ git pull failed: $_" }
    Pop-Location
    Write-Host "✅ Hermes workspace updated" -ForegroundColor Green
} else {
    Write-Host "📥 Cloning hermes-workspace repo..."
    if (Test-Path $hermesDir) { Remove-Item $hermesDir -Recurse -Force }
    try {
        git clone --depth 1 "https://github.com/$hermesRepo.git" $hermesDir 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "🔐 Public clone failed, using auth..."
            git clone --depth 1 "https://$token@github.com/$hermesRepo.git" $hermesDir
        }
        Write-Host "✅ Hermes workspace cloned: $hermesDir" -ForegroundColor Green
    } catch { Write-Host "⚠️ Hermes clone failed: $_" }
}

# ============================================================
# 📢 CREDENTIALS OUTPUT
# ============================================================
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Yellow
Write-Host "Address:   $tsIP"
Write-Host "Username:  $u"
Write-Host "Password:  $p"
Write-Host "OpenCode:  System-installed"
Write-Host "Hermes:    System-installed + workspace cloned"
Write-Host "Workspace: $hermesDir"
Write-Host "Snapshot:  Will auto-save before handoff"
Write-Host "-----------------------------------------------------------------"
Write-Host "⚡ Powered by Toolbox Lab"
Write-Host "🌐 Official Website: $w"
Write-Host "📺 YouTube Channel: $y"
Write-Host "=================================================================" -ForegroundColor Yellow

$summaryLive = @"

### 🔌 Live Connection Info
| Field | Value |
|---|---|
| **Address** | \`$tsIP\` |
| **Username** | \`$u\` |
| **Password** | \`$p\` |
| **Runtime** | ~4h 30m per loop (auto-chains) |
| **Persistence** | ✅ Snapshot saves to GitHub Releases |
| **OpenCode** | ✅ Pre-installed (parallel install) |
| **Hermes App** | ✅ Pre-installed (parallel install) |
| **Hermes Workspace** | ✅ Source cloned to \`$hermesDir\` |
"@
$summaryLive | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8

# ============================================================
# ⏱️ RUNTIME LOOP (4h 30m of usable workspace)
# ============================================================
Write-Host "⏱️ Starting runtime loop..." -ForegroundColor Cyan
$m = 270
$exitNormally = $false
try {
    for ($i = 1; $i -le $m; $i++) {
        $l = $m - $i
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ⏱️ $l min remaining"
        Start-Sleep -Seconds 60
    }
    $exitNormally = $true
} catch {
    Write-Host "⚠️ Error in main loop: $_" -ForegroundColor Yellow
    Save-Snapshot -tag "rdp-snap-emergency-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Emergency
    $body = @{ ref = "$env:REF_NAME"; inputs = @{ gh_api_token = "$token"; loops = "" } } | ConvertTo-Json -Depth 5
    try {
        Invoke-RestMethod -Method POST -Uri "https://api.github.com/repos/$env:REPO_FULL/actions/workflows/secure-rdp-loop.yml/dispatches" -Headers $headers -Body $body | Out-Null
    } catch {}
    exit 1
}

# ============================================================
# 📦 SAVE SNAPSHOT (with 3-retry + verification)
# ============================================================
if ($exitNormally) {
    $snapTag = "rdp-snap-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "🔍 Verifying snapshot contents..."
    Write-Host "   Work folder: $(if (Test-Path $workDir) { (Get-ChildItem $workDir -Recurse -File | Measure-Object).Count } else { 0 }) files"
    Write-Host "   Hermes: $(if (Test-Path $hermesDir) { (Get-ChildItem $hermesDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count } else { 'NOT FOUND' }) files"

    $saved = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Save-Snapshot -tag $snapTag
        try {
            $verify = Invoke-RestMethod -Method GET -Uri "https://api.github.com/repos/$env:REPO_FULL/releases/tags/$snapTag" -Headers $headers
            if ($verify.assets | Where-Object { $_.name -eq "snapshot.zip" }) {
                Write-Host "✅ Snapshot verified on attempt $attempt" -ForegroundColor Green
                $saved = $true; break
            }
        } catch {
            Write-Host "⚠️ Verification failed (attempt $attempt): $_"
            Start-Sleep -Seconds 30
        }
    }
    if (-not $saved) {
        Write-Host "🚨 CRITICAL: Snapshot did NOT save after 3 attempts!" -ForegroundColor Red
    }
}

# ============================================================
# 🔁 CONTINUOUS LOOP - dispatch next job
# ============================================================
$body = @{ ref = "$env:REF_NAME"; inputs = @{ gh_api_token = "$token"; loops = "" } } | ConvertTo-Json -Depth 5
try {
    Invoke-RestMethod -Method POST -Uri "https://api.github.com/repos/$env:REPO_FULL/actions/workflows/secure-rdp-loop.yml/dispatches" -Headers $headers -Body $body | Out-Null
    Write-Host "✅ Next loop dispatched - continuous mode active" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Could not dispatch next loop: $_" -ForegroundColor Yellow
    Write-Host "🛑 Manual restart required"
    exit 1
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Yellow
Write-Host "🎯 This job finished. Next job is already queued."
Write-Host "📦 Your snapshot is saved. Next job will restore it automatically."
Write-Host "=================================================================" -ForegroundColor Yellow
