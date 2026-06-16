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
