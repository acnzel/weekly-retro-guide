# ============================================================
#  주간 리트로 설치 프로그램 (Windows / PowerShell)
#  비개발자용 — PowerShell 창에 통째로 붙여넣고 Enter 하세요.
#  (실행이 막히면 먼저 아래 한 줄 실행:
#     Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned )
# ============================================================

# ▼▼▼▼▼ 여기 한 줄만 바꾸세요 ▼▼▼▼▼
# '지식 베이스' 폴더(작업 교훈·자료·위키가 함께 사는 한 폴더)의 "전체 경로"를 따옴표 안에 넣으세요.
#   · 탐색기에서 폴더를 Shift+우클릭 → "경로로 복사" 로 얻은 전체 경로를 붙여넣으면 됩니다.
#   · 예) $KbRoot = "C:\Users\이름\Documents\MyBrain"
#   · 이미 llm-wiki나 주간 리트로 중 하나를 설치했다면, 이 줄은 무시되고 같은 폴더를 자동으로 씁니다.
$KbRoot = "여기에 지식 베이스 폴더의 전체 경로를 붙여넣으세요"
# ▲▲▲▲▲ 여기 한 줄만 바꾸세요 ▲▲▲▲▲

# --- 지식 베이스 루트 결정 (기존 설치가 있으면 그 폴더를 이어받음) ---
$kbConfig = Join-Path $env:USERPROFILE '.claude\knowledge-base.config'
$kbDir = Split-Path $kbConfig
if (-not (Test-Path $kbDir)) { New-Item -ItemType Directory -Path $kbDir -Force | Out-Null }
if (Test-Path $kbConfig) {
    $KbRoot = (Get-Content -LiteralPath $kbConfig -TotalCount 1).Trim()
    Write-Host "-> 기존 지식 베이스 폴더를 사용합니다: $KbRoot"
} else {
    $KbRoot = $KbRoot.Trim().Trim('"').Trim("'")
    $KbRoot = [Environment]::ExpandEnvironmentVariables($KbRoot)
    if ($KbRoot.StartsWith('~')) { $KbRoot = $env:USERPROFILE + $KbRoot.Substring(1) }
    if ($KbRoot -eq "여기에 지식 베이스 폴더의 전체 경로를 붙여넣으세요") {
        Write-Host "[!] 맨 위 `$KbRoot 를 '지식 베이스 폴더의 전체 경로'로 바꾼 뒤 다시 실행하세요." -ForegroundColor Yellow
        Write-Host "    예) `"$env:USERPROFILE\Documents\MyBrain`""
        exit 1
    }
    if (-not [System.IO.Path]::IsPathRooted($KbRoot)) {
        Write-Host "[!] 경로가 올바르지 않습니다: '$KbRoot' (전체 경로를 넣고 ~ 로 시작하지 마세요)" -ForegroundColor Yellow
        exit 1
    }
    [System.IO.File]::WriteAllText($kbConfig, "$KbRoot`r`n", (New-Object System.Text.UTF8Encoding($false)))
}
$VaultDebriefDir = Join-Path $KbRoot 'debriefs'
Write-Host "-> 교훈 일지 폴더: $VaultDebriefDir"

# 자동 점검 시각. 기본: 금요일 14:30
$RetroDay = 'Friday'
$RetroHour = 14
$RetroMinute = 30

$ErrorActionPreference = 'Stop'
function Write-Utf8NoBom($path, $text) {
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

$claude    = Join-Path $env:USERPROFILE '.claude'
$skillsDir = Join-Path $claude 'skills\weekly-retro'
$scriptsDir= Join-Path $claude 'scripts'
$hooksDir  = Join-Path $claude 'hooks'
$config    = Join-Path $claude 'weekly-retro.config'
$scanPath  = Join-Path $scriptsDir 'weekly-retro-scan.ps1'
$hookPath  = Join-Path $hooksDir 'weekly-retro-session-start.ps1'
$skillPath = Join-Path $skillsDir 'SKILL.md'
$claudeMd  = Join-Path $claude 'CLAUDE.md'
$settingsPath = Join-Path $claude 'settings.json'

Write-Host '→ 폴더 준비...'
foreach ($d in @($skillsDir, $scriptsDir, $hooksDir, $VaultDebriefDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

Write-Host '→ 설정 파일 기록...'
Write-Utf8NoBom $config $VaultDebriefDir

Write-Host '→ 스캔 스크립트 설치...'
$scan = @'
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
'@
Write-Utf8NoBom $scanPath $scan

Write-Host '→ 세션 시작 훅 설치...'
$hook = @'
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
'@
Write-Utf8NoBom $hookPath $hook

Write-Host '→ 스킬 설치...'
$skill = @'
---
name: weekly-retro
description: Use weekly (or when a "리뷰 대기 — 주간 리트로" note exists, or the user says "주간 리트로"/"weekly retro") to review recurring lessons from debrief logs and promote approved ones into the "반복 교훈" section of ~/.claude/CLAUDE.md. Detects lessons recurring in 2+ debriefs (or #sev/major once), presents an approval gate, and never writes a rule without explicit user approval.
---

# Weekly Retro — 승격 게이트

debrief 로그에 쌓인 교훈을 영구 규칙으로 졸업시키는 반자동 게이트.

## 경로
- 교훈 폴더: `~/.claude/weekly-retro.config`(Windows: `%USERPROFILE%\.claude\weekly-retro.config`) 첫 줄에 적힌 경로
- 리뷰 대기 노트: 그 폴더의 `리뷰 대기 — 주간 리트로 YYYY-MM-DD.md` (top-level만 활성)
- 처리 완료 보관: 그 폴더의 `retro-archive/` — 처리한 노트는 여기로 이동한다(매 세션 스캔에서 제외)
- 영구 규칙 대상: `~/.claude/CLAUDE.md` 의 `## 반복 교훈 (Lessons)` 섹션

## 절차
1. 최근 `리뷰 대기 — 주간 리트로 *.md`(상단에 `처리 완료` 없는 것)를 읽어 후보를 가져온다. 없으면 폴더의 `*-debrief.md`에서 `#lesson/*`·`#guardrail/*`를 직접 집계한다(`#promoted` 줄 제외).
2. 후보 선별: 같은 `#lesson/<범주>`가 서로 다른 debrief 2개 이상 → 재발 후보. `#sev/major`는 1회만으로도 후보. 이미 CLAUDE.md에 같은 취지 규칙이 있으면 제외(먼저 CLAUDE.md를 읽어 대조).
3. 게이트: 후보를 표로 제시(범주/횟수/근거 원문). 각 후보를 사용자가 **승인/기각/수정**. **승인 없이는 절대 기록하지 않는다.**
4. 승격(승인분만): `~/.claude/CLAUDE.md`의 `## 반복 교훈 (Lessons)` 섹션에 한 줄 규칙으로 추가. 원본 debrief의 해당 교훈 줄 끝에 ` #promoted`를 붙여 재카운트 방지.
5. 미해결 가드레일(`#guardrail/*` 중 `#promoted` 안 된 것)을 "아직 살아있는 주의사항"으로 정리해 보여준다.
6. 처리한 리뷰 노트 상단에 `> 처리 완료 YYYY-MM-DD`를 적고, 그 노트를 `retro-archive/`로 이동한다(삭제하지 않음 — 보관만). 결과 요약 보고.

## 원칙
- 2회째 발생에만 규칙화(1회성 교훈으로 CLAUDE.md 오염 금지). 단 `#sev/major`는 예외.
- 게이트는 사람이 통제한다. 자동 기록 없음.
'@
Write-Utf8NoBom $skillPath $skill

Write-Host '-> 상태 점검 스킬(loop-status) 설치...'
$loopStatusDir = Join-Path $claude 'skills\loop-status'
if (-not (Test-Path $loopStatusDir)) { New-Item -ItemType Directory -Path $loopStatusDir -Force | Out-Null }
$loopstatus = @'
---
name: loop-status
description: Use when the user says "/loop-status", "상태", "루프 상태", "내 루프 잘 돌고 있어?", "대시보드", or wants a health check of their knowledge-base self-improvement loop. Reports vital signs — knowledge base folder, weekly scheduler, last scan, debrief flow (14 days), pending reviews, wiki size, raw backlog, promoted rules — and flags anything stale or broken with a concrete next action. Read-only: never changes or deletes anything.
---

# /loop-status — 내 루프 건강검진 대시보드

비개발자가 "내 자가발전 루프가 살아있고 잘 도는가"를 한눈에 보게 한다.
**읽기 전용 — 아무 파일도 만들거나 고치거나 지우지 않는다.** OS에 맞는 명령(mac/Windows)을 골라 쓴다.

## 1. 기준 경로 확인
- 루트: `~/.claude/knowledge-base.config` 첫 줄. 없으면 "아직 설치 안 됨"으로 안내하고 종료.
- 교훈: `<루트>/debriefs/`, 위키: `<루트>/wiki/`, 원본: `<루트>/raw/`, 보관: `<루트>/ingested/`

## 2. 생체신호 수집 (셸로 조용히 확인)
- **스케줄 살아있나**: mac `launchctl print gui/$(id -u)/com.user.weekly-retro` 성공 여부 / Windows `Get-ScheduledTask -TaskName WeeklyRetro`
- **마지막 자동 점검**: `~/.claude/logs/weekly-retro.out.log` 수정시각, 또는 `debriefs/`의 최신 `리뷰 대기 — 주간 리트로 *.md` 날짜
- **교훈 흐름**: `debriefs/`의 최근 14일 `*-debrief.md` 개수
- **미처리 리뷰**: `리뷰 대기 — 주간 리트로 *.md` 중 본문에 `처리 완료` 없는 것 개수
- **위키 규모**: `wiki/`의 `*.md` 페이지 수
- **처리 대기 자료**: `raw/`의 파일 수(README 제외), **보관됨**: `ingested/` 파일 수
- **승격된 규칙**: `~/.claude/CLAUDE.md`의 `## 반복 교훈` 섹션 항목 수

## 3. 대시보드 출력 (표 + 신호등)
각 항목을 ✅(정상) / ⚠️(주의) / 🔔(할 일) / ❌(고장) 으로. 예:
```
🔍 내 루프 상태
  ✅ 지식 베이스      /Users/.../MyBrain
  ✅ 자동 점검 스케줄  매주 금 14:30 (마지막 실행: 3일 전)
  🔔 검토 대기        승격 후보 2건 → /weekly-retro 실행
  ✅ 교훈 흐름        최근 2주 5건
  🔔 미처리 자료      raw에 3개 → /ingest 실행
  ✅ 위키             24페이지 (보관 18)
  ✅ 승격된 규칙      7개
```

## 4. 경고는 반드시 "행동 한 줄"과 함께
- 스케줄 없음 → ❌ "자동 점검이 꺼져 있어요. 설치 스크립트를 다시 실행하세요."
- 최근 14일 교훈 0건 → ⚠️ "교훈이 안 쌓이고 있어요. 작업 후 '오늘 debrief 정리해줘'라고 하거나, Code 탭+Local에서 일하고 있는지 확인하세요."
- 미처리 리뷰 ≥1 → 🔔 "검토 대기 N건 — `/weekly-retro` 실행하세요."
- raw 대기 ≥1 → 🔔 "ingest 안 한 자료 M개 — `/ingest` 하세요."
- 위키 0페이지 & ingested 0 → ⚠️ "아직 위키를 안 쓰고 있어요. raw에 자료를 넣고 /ingest 해보세요."

## 원칙
- 절대 읽기 전용. 수정·삭제·생성 금지.
- 모든 경고에 "무엇을 / 어떻게" 한 줄 행동지침을 붙인다.
- 숫자만 나열하지 말고, "잘 돌고 있어요" 또는 "이건 챙기세요"를 한 줄 총평으로 마무리.
'@
Write-Utf8NoBom (Join-Path $loopStatusDir 'SKILL.md') $loopstatus

Write-Host '→ CLAUDE.md 규약 추가...'
$snippet = @'

<!-- weekly-retro:debrief-convention -->
## 작업 debrief 자동 기록 (주간 리트로 연동)

의미 있는 작업(문서 작성, 자료 정리, 분석, 조사, 기능 구현, 버그 수정 등)을 끝내면,
교훈 폴더에 `YYYY-MM-DD-debrief.md` 파일을 Write로 작성한다(이미 있으면 섹션 추가).
교훈 폴더 경로는 `~/.claude/weekly-retro.config`(Windows: `%USERPROFILE%\.claude\weekly-retro.config`) 첫 줄에 있다.

### 각 작업 섹션 형식
```markdown
## HH:MM — 작업명

### 무엇을 했나
- (한 일 요약)

### 핵심 의사결정
- [결정] → [이유]

### 실수 & 교훈
- [실수] → [올바른 접근] #lesson/<범주> #sev/major|minor

### 다음 세션 주의사항
- [다음에 먼저 확인할 가드레일] #guardrail/<범주>
```

- 범주는 짧은 영문 키워드(kebab-case, 예: `wrong-folder`, `double-booking`). 기존 범주를 먼저 확인해 같은 사건이면 재사용한다(재발 카운트 전제).
- 심각도: 치명적(돌이키기 힘든 손실/사고)은 `#sev/major`(1회만으로도 승격 후보), 그 외 `#sev/minor`.
- 영구 규칙으로 승격된 교훈에는 `/weekly-retro`가 원본 줄에 `#promoted`를 붙인다. 수동으로 건드리지 말 것.

## 반복 교훈 (Lessons)
<!-- /weekly-retro 가 승인한 반복 교훈이 여기에 누적됩니다. 매 세션 자동으로 읽힙니다. -->
'@
$existing = ''
if (Test-Path $claudeMd) { $existing = [System.IO.File]::ReadAllText($claudeMd) }
if ($existing -notmatch 'weekly-retro:debrief-convention') {
    Write-Utf8NoBom $claudeMd ($existing + $snippet)
}

Write-Host '→ Claude Code 훅(settings.json) 연결...'
$hookCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$hookPath`""
$json = $null
if (Test-Path $settingsPath) {
    try { $json = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $json = $null }
}
if ($null -eq $json) { $json = [pscustomobject]@{} }
if (-not ($json.PSObject.Properties.Name -contains 'hooks')) {
    $json | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
}
if (-not ($json.hooks.PSObject.Properties.Name -contains 'SessionStart')) {
    $json.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue @()
}
$exists = $false
foreach ($b in @($json.hooks.SessionStart)) {
    foreach ($h in @($b.hooks)) { if ($h.command -eq $hookCmd) { $exists = $true } }
}
if (-not $exists) {
    $entry = [pscustomobject]@{ hooks = @([pscustomobject]@{ type = 'command'; command = $hookCmd; timeout = 5 }) }
    $json.hooks.SessionStart = @($json.hooks.SessionStart) + $entry
}
Write-Utf8NoBom $settingsPath ($json | ConvertTo-Json -Depth 20)

Write-Host '→ 자동 점검 스케줄 등록 (작업 스케줄러)...'
try {
    $action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scanPath`""
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $RetroDay -At (Get-Date -Hour $RetroHour -Minute $RetroMinute -Second 0)
    $set     = New-ScheduledTaskSettingsSet -StartWhenAvailable
    Register-ScheduledTask -TaskName 'WeeklyRetro' -Action $action -Trigger $trigger -Settings $set -Description '주간 리트로 자동 점검' -Force | Out-Null
    Write-Host '   작업 스케줄러 등록 완료'
} catch {
    Write-Warning "작업 스케줄러 등록 실패: $($_.Exception.Message)"
    Write-Host '   → 관리자 권한 PowerShell에서 다시 실행하거나, 가이드의 FAQ를 참고하세요.'
}

Write-Host '→ 설치 검증 (스캔 1회 실행)...'
try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scanPath } catch {}

Write-Host ''
Write-Host '✅ 설치 완료!'
Write-Host "   교훈 폴더 : $VaultDebriefDir"
Write-Host "   자동 점검 : 매주 $RetroDay ${RetroHour}:$('{0:D2}' -f $RetroMinute)"
Write-Host '   이제 Claude Code로 일하면 교훈이 쌓이고, 금요일에 자동 점검됩니다.'

Write-Host ''
Write-Host '-- 설치 점검 --'
if (Test-Path $KbRoot) { Write-Host "  [OK] 지식 베이스 폴더: $KbRoot" } else { Write-Host '  [!] 지식 베이스 폴더 없음' }
if (Test-Path $VaultDebriefDir) { Write-Host '  [OK] 교훈 일지(debriefs)' } else { Write-Host '  [!] debriefs 폴더 없음' }
if (Get-ScheduledTask -TaskName WeeklyRetro -ErrorAction SilentlyContinue) { Write-Host '  [OK] 자동 점검 스케줄 (매주 금요일)' } else { Write-Host '  [!] 스케줄 미등록 — 관리자 PowerShell에서 다시 실행' }
if ((Test-Path $settingsPath) -and (Select-String -Path $settingsPath -Pattern 'weekly-retro-session-start' -Quiet)) { Write-Host '  [OK] 세션 훅 연결됨(settings.json)' } else { Write-Host '  [!] 세션 훅 미연결' }
if (Test-Path $skillPath) { Write-Host '  [OK] 스킬: weekly-retro' } else { Write-Host '  [!] weekly-retro 스킬 없음' }
if (Test-Path (Join-Path $claude 'skills\loop-status\SKILL.md')) { Write-Host '  [OK] 스킬: loop-status (상태 점검)' } else { Write-Host '  [!] loop-status 스킬 없음' }
Write-Host ''
Write-Host '  TIP: 언제든 Claude Code에서  /loop-status  로 루프 상태를 확인하세요.'
