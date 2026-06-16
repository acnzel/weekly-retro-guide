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
