# weekly-retro-scan (Windows) — 작업 스케줄러가 매주 정해진 시각에 실행.
$ErrorActionPreference = 'SilentlyContinue'
$cfg = Join-Path $env:USERPROFILE '.claude\weekly-retro.config'
if (-not (Test-Path $cfg)) { return }
$dir = (Get-Content -LiteralPath $cfg -TotalCount 1).Trim()
if ([string]::IsNullOrWhiteSpace($dir) -or -not (Test-Path -LiteralPath $dir)) { return }
$cutoff = (Get-Date).AddDays(-90)
$files = @(Get-ChildItem -LiteralPath $dir -Filter '*-debrief.md' -File |
           Where-Object { $_.LastWriteTime -ge $cutoff } | Sort-Object Name)
$lessons = @{}
$guards  = @{}
foreach ($f in $files) {
    $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8
    foreach ($raw in $lines) {
        if ($raw -match '#promoted') { continue }
        $isMajor = [regex]::IsMatch($raw, '#sev/major\b')
        foreach ($m in [regex]::Matches($raw, '#lesson/([^\s#]+)')) {
            $cat = $m.Groups[1].Value
            if (-not $lessons.ContainsKey($cat)) {
                $lessons[$cat] = @{
                    Files    = New-Object 'System.Collections.Generic.HashSet[string]'
                    Evidence = New-Object System.Collections.ArrayList
                    Major    = $false
                }
            }
            [void]$lessons[$cat].Files.Add($f.Name)
            [void]$lessons[$cat].Evidence.Add(@($f.Name, $raw.Trim()))
            if ($isMajor) { $lessons[$cat].Major = $true }
        }
        foreach ($m in [regex]::Matches($raw, '#guardrail/([^\s#]+)')) {
            $cat = $m.Groups[1].Value
            if (-not $guards.ContainsKey($cat)) { $guards[$cat] = New-Object System.Collections.ArrayList }
            [void]$guards[$cat].Add(@($f.Name, $raw.Trim()))
        }
    }
}
$cands = @()
foreach ($cat in $lessons.Keys) {
    $slot = $lessons[$cat]
    $recurring = $slot.Files.Count -ge 2
    if ($recurring -or $slot.Major) {
        $cands += [pscustomobject]@{
            Category = $cat; Count = $slot.Files.Count
            Major = $slot.Major; Recurring = $recurring; Evidence = $slot.Evidence
        }
    }
}
$cands = @($cands | Sort-Object @{Expression='Count';Descending=$true}, @{Expression='Major';Descending=$true})
$today = (Get-Date).ToString('yyyy-MM-dd')
$out = New-Object System.Collections.ArrayList
[void]$out.Add('---')
[void]$out.Add('tags:')
[void]$out.Add('  - weekly-retro')
[void]$out.Add("created: $today")
[void]$out.Add('---')
[void]$out.Add('')
[void]$out.Add("# 주간 리트로 후보 — $today")
[void]$out.Add('')
[void]$out.Add('> 자동 집계 결과입니다. Claude Code에서 `/weekly-retro` 를 실행해 건건이 승인/기각하세요. 승인한 것만 영구 규칙(CLAUDE.md)으로 올라갑니다.')
[void]$out.Add('')
if ($cands.Count -eq 0) {
    [void]$out.Add('## 승격 후보')
    [void]$out.Add('')
    [void]$out.Add('- 이번 주 재발(2회+) 또는 치명(#sev/major) 교훈 없음. 👍')
} else {
    [void]$out.Add("## 승격 후보 ($($cands.Count)건)")
    [void]$out.Add('')
    foreach ($c in $cands) {
        $badge = @()
        if ($c.Recurring) { $badge += "재발 $($c.Count)회" }
        if ($c.Major)     { $badge += '치명(major)' }
        [void]$out.Add("### #lesson/$($c.Category) — $($badge -join ', ')")
        foreach ($e in $c.Evidence) {
            $d = (($e[0] -split '-')[0..2] -join '-')
            [void]$out.Add("`t- [$d] $($e[1])")
        }
        [void]$out.Add('')
    }
}
if ($guards.Count -gt 0) {
    [void]$out.Add("## 아직 살아있는 가드레일 ($($guards.Count)개 범주)")
    [void]$out.Add('')
    foreach ($cat in ($guards.Keys | Sort-Object { -$guards[$_].Count })) {
        [void]$out.Add("### #guardrail/$cat — $($guards[$cat].Count)회")
        foreach ($e in $guards[$cat]) {
            $d = (($e[0] -split '-')[0..2] -join '-')
            [void]$out.Add("`t- [$d] $($e[1])")
        }
        [void]$out.Add('')
    }
}
$text = ($out -join "`r`n") + "`r`n"
if (Test-Path (Join-Path (Split-Path $dir -Parent) 'wiki')) {
    $text += "## 함께 정비`r`n- 위키(wiki/)도 ``/lint``로 같이 점검하세요 — 모순·끊긴 링크 정리. (주간 정비를 한 번에)`r`n"
}
$notePath = Join-Path $dir "리뷰 대기 — 주간 리트로 $today.md"
[System.IO.File]::WriteAllText($notePath, $text, (New-Object System.Text.UTF8Encoding($false)))
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $n = New-Object System.Windows.Forms.NotifyIcon
    $n.Icon = [System.Drawing.SystemIcons]::Information
    $n.Visible = $true
    $msg = if ($cands.Count -gt 0) { "승격 후보 $($cands.Count)건 대기 중 — /weekly-retro 로 검토하세요" } else { '이번 주 승격 후보 없음' }
    $n.ShowBalloonTip(8000, '주간 리트로', $msg, [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Seconds 9
    $n.Dispose()
} catch {}
