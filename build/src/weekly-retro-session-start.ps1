# weekly-retro-session-start (Windows) — Claude Code SessionStart 훅.
$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$cfg = Join-Path $env:USERPROFILE '.claude\weekly-retro.config'
if (-not (Test-Path $cfg)) { return }
$dir = (Get-Content -LiteralPath $cfg -TotalCount 1).Trim()
if (-not (Test-Path -LiteralPath $dir)) { return }
$cut = (Get-Date).AddDays(-14)
$debriefs = @(Get-ChildItem -LiteralPath $dir -Filter '*-debrief.md' -File |
              Where-Object { $_.LastWriteTime -ge $cut } |
              Sort-Object Name -Descending | Select-Object -First 5)
$buf = New-Object System.Collections.ArrayList
foreach ($f in $debriefs) {
    $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8
    $mist = @(); $guard = @(); $mode = ''
    foreach ($ln in $lines) {
        if ($ln -match '^###\s*실수')     { $mode = 'm'; continue }
        if ($ln -match '^###\s*다음 세션') { $mode = 'g'; continue }
        if (($ln -match '^### ') -or ($ln -match '^---')) { $mode = ''; continue }
        if ($ln.Trim()) {
            if ($mode -eq 'm') { $mist += $ln }
            elseif ($mode -eq 'g') { $guard += $ln }
        }
    }
    if ($mist.Count -or $guard.Count) {
        $d = (($f.Name -split '-')[0..2] -join '-')
        [void]$buf.Add("#### $d")
        if ($mist.Count)  { [void]$buf.Add('**실수 & 교훈**'); ($mist | Select-Object -First 5) | ForEach-Object { [void]$buf.Add($_) } }
        if ($guard.Count) { [void]$buf.Add('**가드레일**');   ($guard | Select-Object -First 5) | ForEach-Object { [void]$buf.Add($_) } }
        [void]$buf.Add('')
    }
}
if ($buf.Count) {
    Write-Output '[PAST SESSION LESSONS]'
    Write-Output '최근 세션 교훈/가드레일 — 같은 실수 반복 금지:'
    $buf | ForEach-Object { Write-Output $_ }
}
$pending = @(Get-ChildItem -LiteralPath $dir -Filter '리뷰 대기 — 주간 리트로 *.md' -File |
             Sort-Object Name -Descending | Select-Object -First 1)
if ($pending.Count -gt 0) {
    $content = Get-Content -LiteralPath $pending[0].FullName -Raw -Encoding UTF8
    if ($content -notmatch '처리 완료') {
        Write-Output ''
        Write-Output "[WEEKLY RETRO PENDING] 미처리 주간 리트로 후보가 있습니다: $($pending[0].Name)"
        Write-Output '→ 사용자에게 /weekly-retro 실행을 제안할 것.'
        if (Test-Path (Join-Path (Split-Path $dir -Parent) 'wiki')) { Write-Output '   (주간 정비: 위키도 /lint 로 함께 점검하면 좋습니다 — 한 번에.)' }
    }
}
# 금요일 첫 실행 게이트: 매주 금요일, 그날 첫 세션에서 1회만 주간 리트로 실행 여부를 묻는다.
# 하루 한 번만 발동하도록 날짜 마커 파일로 가드(= "처음 실행" 의미). 후보 유무와 무관하게 항상 묻는다.
if ((Get-Date).DayOfWeek -eq 'Friday') {
    $claudeDir = Join-Path $env:USERPROFILE '.claude'
    $askMarker = Join-Path $claudeDir ('.weekly-retro-asked-' + (Get-Date -Format 'yyyy-MM-dd'))
    if (-not (Test-Path -LiteralPath $askMarker)) {
        New-Item -ItemType File -Path $askMarker -Force | Out-Null   # 오늘 마커 생성 → 같은 날 이후 세션에선 다시 묻지 않음
        Get-ChildItem -LiteralPath $claudeDir -Filter '.weekly-retro-asked-*' -File -Force |
            Where-Object { $_.Name -ne (Split-Path $askMarker -Leaf) } | Remove-Item -Force   # 옛 마커 정리
        Write-Output ''
        Write-Output '[WEEKLY RETRO — 금요일 첫 실행]'
        Write-Output '→ 사용자에게 물어볼 것: "오늘 금요일입니다. 주간 리트로(/weekly-retro)를 지금 돌릴까요?"'
        Write-Output '  사용자가 예라고 하면 /weekly-retro 를 실행. 아니라고 하면 넘어갈 것 (오늘은 다시 묻지 않음).'
    }
}
