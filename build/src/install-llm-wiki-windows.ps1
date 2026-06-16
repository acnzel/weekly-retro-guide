# ============================================================
#  내 지식 위키(LLM Wiki) 설치 (Windows / PowerShell)
#  비개발자용 — PowerShell 창에 통째로 붙여넣고 Enter 하세요.
#  (막히면 먼저: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned)
# ============================================================

# ▼▼▼▼▼ 여기 한 줄만 바꾸세요 ▼▼▼▼▼
# '지식 베이스' 폴더(작업 교훈·자료·위키가 함께 사는 한 폴더)의 "전체 경로"를 따옴표 안에 넣으세요.
#   · 예) $KbRoot = "C:\Users\이름\Documents\MyBrain"
#   · 이미 주간 리트로나 llm-wiki 중 하나를 설치했다면, 이 줄은 무시되고 같은 폴더를 자동으로 씁니다.
$KbRoot = "여기에 지식 베이스 폴더의 전체 경로를 붙여넣으세요"
# ▲▲▲▲▲ 여기 한 줄만 바꾸세요 ▲▲▲▲▲

$ErrorActionPreference = 'Stop'
function Write-Utf8NoBom($p, $t) { [System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false))) }

# --- 지식 베이스 루트 결정 (기존 설치가 있으면 이어받음) ---
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
    Write-Utf8NoBom $kbConfig "$KbRoot`r`n"
}
Write-Host "-> 위키 폴더(지식 베이스): $KbRoot"

$skills = Join-Path $env:USERPROFILE '.claude\skills'
foreach ($d in @(
    (Join-Path $KbRoot 'raw'), (Join-Path $KbRoot 'ingested'),
    (Join-Path $KbRoot 'wiki\entities'), (Join-Path $KbRoot 'wiki\concepts'),
    (Join-Path $KbRoot 'wiki\sources'), (Join-Path $KbRoot 'wiki\comparisons'),
    (Join-Path $skills 'ingest'), (Join-Path $skills 'query'), (Join-Path $skills 'lint')
)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }

Write-Host '-> 위키 규약(CLAUDE.md)...'
$claudePath = Join-Path $KbRoot 'CLAUDE.md'
if (-not (Test-Path $claudePath)) {
    $wikiClaude = @'
# 내 지식 위키 (LLM Wiki)

이 폴더는 "넣을수록 지식이 쌓이고 서로 연결되는" 위키입니다. (Andrej Karpathy의 LLM Wiki 패턴)

- **사람의 역할**: 좋은 자료를 모으고(`raw/`에 넣기), 좋은 질문을 한다.
- **AI(Claude)의 역할**: 자료를 읽고 `wiki/` 안에 정리·연결·갱신한다.

## 폴더 규칙
이 폴더는 '지식 베이스' 루트입니다. 아래 갈래가 함께 삽니다.
- `raw/` — **처리 대기함(inbox).** 새로 넣은 원본 자료(기사·PDF·이미지·데이터)가 여기 쌓인다. `/ingest`가 끝나면 그 파일은 `ingested/`로 옮겨지므로, raw/에는 항상 **'아직 처리 안 된 자료'만** 남는다.
- `ingested/` — **처리 완료 보관함.** ingest된 원본이 그대로 보존된다(삭제 아님). AI는 내용을 수정하지 않는다.
- `debriefs/` — (주간 리트로가 관리하는) 작업 교훈 일지. 위키 작업과는 별개지만 같은 지식 베이스에 함께 둔다.
- `wiki/` — AI가 관리하는 정리된 지식.
	- `wiki/entities/` — 사람·회사·제품·기술 등 "대상"
	- `wiki/concepts/` — 개념·방법·주제
	- `wiki/sources/` — 원본 자료의 요약 페이지
	- `wiki/comparisons/` — 비교·분석 결과(질문에 대한 가치 있는 답을 저장)
	- `wiki/index.md` — 목차. **항상 먼저 읽는 허브.**
	- `wiki/log.md` — 변경 기록

## 페이지 형식 (각 wiki 노트 맨 위)
```
---
tags: [관련, 태그]
source_count: 0
last_updated: YYYY-MM-DD
---
```
본문에서 관련 페이지는 `[[페이지이름]]` 위키링크로 잇는다.

## 작업 원칙
- 새 자료 하나가 **여러 wiki 페이지를 동시에** 갱신하도록(지식이 연결되도록) 한다.
- 기존 내용과 충돌하면 그 자리에 `⚠️ CONFLICT: (무엇이 충돌하는지)`를 남기고 사람에게 보고한다.
- 모든 정리 작업은 `wiki/log.md`에 한 줄로 남긴다.
- 대량 삭제·되돌리기는 사람 승인 없이 하지 않는다.
- 원본 파일의 내용은 수정하지 않는다. `/ingest`가 끝나면 그 원본을 `raw/` → `ingested/` 로 **이동**만 한다(삭제 아님).
'@
    Write-Utf8NoBom $claudePath $wikiClaude
}

Write-Host '-> 목차/기록/안내 파일...'
$idxPath = Join-Path $KbRoot 'wiki\index.md'
if (-not (Test-Path $idxPath)) {
    $idx = @'
# 위키 목차 (index)

> 새 자료를 /ingest 하면 이 목차가 자동으로 갱신됩니다.

## Entities

## Concepts

## Sources

## Comparisons
'@
    Write-Utf8NoBom $idxPath $idx
}
$logPath = Join-Path $KbRoot 'wiki\log.md'
if (-not (Test-Path $logPath)) { Write-Utf8NoBom $logPath "# 변경 기록 (log)`r`n" }
$rawPath = Join-Path $KbRoot 'raw\README.md'
if (-not (Test-Path $rawPath)) {
    $rawReadme = @'
# raw — 원본 자료 보관소

여기에 기사·PDF·이미지·데이터 등 "원본"을 넣으세요.
AI는 이 폴더를 읽기만 하고 절대 수정하지 않습니다.
파일 이름 예) 2026-06-11-기사제목.md
'@
    Write-Utf8NoBom $rawPath $rawReadme
}

Write-Host '-> /ingest /query /lint 스킬...'
Write-Utf8NoBom (Join-Path $skills 'ingest\SKILL.md') @'
---
name: ingest
description: Use when the user says "/ingest", "인제스트", "자료 넣어줘", or points at a file in raw/ to add into the knowledge wiki. Reads a source file from raw/, extracts key insights, creates/updates related wiki pages (entities, concepts, sources), flags contradictions, updates wiki/index.md, records the change in wiki/log.md, then moves the processed source from raw/ into ingested/ so raw/ only shows not-yet-processed files. Never edits raw file contents; never deletes the original (moves to ingested/).
---

# /ingest — 자료를 위키에 넣기

현재 폴더(지식 베이스)의 `raw/`에 있는 원본 자료를 읽어 `wiki/`로 정리한다.

## 절차
1. 대상 raw 파일을 읽는다. 사용자가 파일을 지정하지 않았으면 `raw/`에서 후보 파일을 보여주고 무엇을 넣을지 물어본다. **ingest가 끝날 때까지 raw 파일의 내용은 수정하지 않는다.**
2. 핵심 인사이트 3~7개를 뽑는다.
3. 관련 `wiki/entities/*`·`wiki/concepts/*` 페이지를 찾아 **갱신**하거나, 없으면 **새로 만든다**(페이지 형식: frontmatter + 본문, 관련 페이지는 `[[위키링크]]`로 연결).
4. `wiki/sources/`에 이 자료의 요약 페이지를 만든다(원본 파일 이름을 명시).
5. 기존 내용과 모순되면 그 자리에 `⚠️ CONFLICT: (설명)`을 남기고 사람에게 보고한다.
6. `wiki/index.md`(목차)를 갱신한다.
7. `wiki/log.md`에 기록한다:
	```
	## [YYYY-MM-DD] ingest | (자료 제목)
	+ wiki/sources/...      (새로 만든 파일)
	✎ wiki/entities/...     (수정한 파일)
	→ ingested/...          (원본 이동)
	```
8. **처리 완료 표시 — 원본을 `ingested/`로 이동한다.** 위 3~7번이 모두 성공했을 때만, 방금 ingest한 원본 파일을 `raw/`에서 `ingested/`로 **이동**한다(원본의 하위 경로 구조는 유지: 예 `raw/slack/a.md` → `ingested/slack/a.md`). 이렇게 하면 `raw/`에는 '아직 처리 안 된 자료'만 남아 한눈에 구분된다.
	- **삭제가 아니라 이동이다. 원본은 `ingested/`에 그대로 보존된다.** (필요하면 다시 꺼내 재-ingest 가능)
	- 여러 파일을 한꺼번에 처리했으면 처리한 것만 각각 이동한다. 실패하거나 건너뛴 파일은 `raw/`에 남겨 둔다.
9. 무엇을 갱신했고 어떤 파일을 `ingested/`로 옮겼는지 사람에게 짧게 요약 보고한다.

## 원칙
- 사람은 자료를 모으고, 정리는 AI가 한다.
- 한 자료가 여러 페이지를 동시에 갱신하도록 해서 지식이 흩어지지 않고 연결되게 한다.
- 확실하지 않은 사실은 단정하지 말고 `?`나 출처를 함께 남긴다.
- 원본을 지우지 않는다(항상 `ingested/`로 이동만).
'@
Write-Utf8NoBom (Join-Path $skills 'query\SKILL.md') @'
---
name: query
description: Use when the user says "/query", "쿼리", "위키에 물어봐", or asks a question to be answered from the knowledge wiki. Reads wiki/index.md first, gathers related pages, synthesizes an answer in the requested format, shows which pages it used, and offers to save valuable answers as a permanent wiki page.
---

# /query — 위키에 물어보기

쌓인 위키를 근거로 질문에 답한다.

## 절차
1. 먼저 `wiki/index.md`(목차)를 읽어 관련 페이지를 파악한다.
2. 관련 `wiki/entities/*`·`wiki/concepts/*`·`wiki/sources/*`·`wiki/comparisons/*`를 읽어 종합한다.
3. 사용자가 원하는 형식(글/표/요약/슬라이드 등)으로 답한다. **근거가 된 위키 페이지 목록을 함께 보여준다.**
4. **중요:** 답이 가치 있으면 "이 답을 `wiki/comparisons/(이름).md` 로 영구 저장할까요?"라고 제안하고, 승인하면 페이지로 저장한다. (오늘의 답이 다음 질문의 재료가 되도록 — 지식이 쌓인다.)

## 원칙
- 위키에 근거가 없으면 추측하지 말고 "위키에 아직 자료가 부족하다"고 말하고, 무엇을 `/ingest` 하면 좋을지 제안한다.
- 답에는 항상 "어느 페이지에서 나왔는지"를 밝혀 신뢰할 수 있게 한다.
'@
Write-Utf8NoBom (Join-Path $skills 'lint\SKILL.md') @'
---
name: lint
description: Use when the user says "/lint", "린트", "위키 점검", or wants a periodic health check of the knowledge wiki. Scans wiki/ for contradictions, orphan pages, stale claims, and missing links; lists findings; applies only approved fixes; logs changes; and suggests next research topics. Recommended weekly.
---

# /lint — 위키 건강검진 (주 1회 권장)

위키가 커져도 일관성·최신성을 유지하기 위한 점검.

## 절차
1. `wiki/` 전체를 훑는다(특히 최근 `/ingest`된 내용 반영).
2. 다음을 찾아 목록으로 정리한다:
	- ⚠️ **모순** — 서로 상충하는 서술
	- 📭 **고아 페이지** — 아무 데서도 링크되지 않는 페이지
	- 🕒 **오래된 주장** — 새 자료로 뒤집힌 내용
	- 🔗 **빠진 연결** — `[[위키링크]]`로 이어야 할 곳
	- 🔍 **데이터 갭** — 위키에 비어 있는 중요한 주제
3. 각 항목을 사람에게 보여주고 **승인받은 것만** 고친다.
4. 고친 내용을 `wiki/log.md`에 기록한다.
5. "다음에 조사하면 좋을 주제 3개"를 제안한다.

## 원칙
- 사람 승인 없이 대량 삭제하지 않는다.
- 매주 한 번(예: 주간 리트로 하는 날)에 같이 돌리면 좋다.
'@
$loopStatusDir = Join-Path $skills 'loop-status'
if (-not (Test-Path $loopStatusDir)) { New-Item -ItemType Directory -Path $loopStatusDir -Force | Out-Null }
Write-Utf8NoBom (Join-Path $loopStatusDir 'SKILL.md') @'
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

Write-Host ''
Write-Host '[OK] 설치 완료!'
Write-Host "   지식 베이스 : $KbRoot   (raw/ , wiki/ 생성됨)"
Write-Host '   사용법: Claude Code(데스크탑 앱 Code 탭)를 이 폴더로 열고, raw/ 에 자료를 넣은 뒤 /ingest 실행. 질문은 /query, 주간 점검은 /lint.'

Write-Host ''
Write-Host '-- 설치 점검 --'
if (Test-Path (Join-Path $KbRoot 'raw')) { Write-Host '  [OK] raw/ (자료 넣는 곳)' } else { Write-Host '  [!] raw 없음' }
if (Test-Path (Join-Path $KbRoot 'wiki')) { Write-Host '  [OK] wiki/ (AI 정리 지식)' } else { Write-Host '  [!] wiki 없음' }
if (Test-Path (Join-Path $KbRoot 'CLAUDE.md')) { Write-Host '  [OK] 위키 규약(CLAUDE.md)' } else { Write-Host '  [!] CLAUDE.md 없음' }
foreach ($s in @('ingest','query','lint','loop-status')) {
    if (Test-Path (Join-Path $skills "$s\SKILL.md")) { Write-Host "  [OK] 스킬: /$s" } else { Write-Host "  [!] /$s 스킬 없음" }
}
Write-Host ''
Write-Host '  TIP: 언제든 Claude Code에서  /loop-status  로 루프 상태를 확인하세요.'
