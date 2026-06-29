#!/bin/bash
# ============================================================
#  주간 리트로 설치 프로그램 (Mac)
#  비개발자용 — 터미널에 통째로 붙여넣거나, 이 파일을 더블클릭해서 실행하세요.
# ============================================================
set -euo pipefail

# ▼▼▼▼▼ 여기 한 줄만 바꾸세요 ▼▼▼▼▼
# '지식 베이스' 폴더(작업 교훈·자료·위키가 함께 사는 한 폴더)의 "전체 경로"를 따옴표 안에 넣으세요.
#   · Finder에서 폴더를 option 누른 채 우클릭 → "...의 경로 이름 복사" 로 얻은 절대경로를 붙여넣으면 됩니다.
#   · 예) KB_ROOT="/Users/이름/Documents/MyBrain"
#   · 주의: ~(물결표)로 시작하는 경로는 넣지 마세요.
#   · 이미 llm-wiki나 주간 리트로 중 하나를 설치했다면, 이 줄은 무시되고 같은 폴더를 자동으로 씁니다.
KB_ROOT="여기에 지식 베이스 폴더의 전체 경로를 붙여넣으세요"
# ▲▲▲▲▲ 여기 한 줄만 바꾸세요 ▲▲▲▲▲

# 자동 점검 시각 (1=월 … 5=금 … 7=일). 기본: 금요일 14:30
RETRO_WEEKDAY=5
RETRO_HOUR=14
RETRO_MINUTE=30

if [ ! -x /usr/bin/python3 ]; then
  echo "⚠️  python3 가 필요합니다. 터미널에서 다음을 실행해 설치한 뒤 다시 시도하세요:"
  echo "      xcode-select --install"
  exit 1
fi

# --- 지식 베이스 루트 결정 (기존 설치가 있으면 그 폴더를 이어받음) ---
KB_CONFIG="$HOME/.claude/knowledge-base.config"
mkdir -p "$HOME/.claude"
if [ -f "$KB_CONFIG" ]; then
  KB_ROOT="$(head -n1 "$KB_CONFIG")"
  echo "→ 기존 지식 베이스 폴더를 사용합니다: $KB_ROOT"
else
  # (1) 안 바꿨으면 중단
  if [ "$KB_ROOT" = "여기에 지식 베이스 폴더의 전체 경로를 붙여넣으세요" ]; then
    echo "⚠️  맨 위 KB_ROOT 를 '지식 베이스 폴더의 전체 경로'로 바꾼 뒤 다시 실행하세요."
    echo "     예) \"/Users/$(whoami)/Documents/MyBrain\""
    exit 1
  fi
  # (2) 앞뒤 공백·따옴표 제거
  KB_ROOT="$(printf '%s' "$KB_ROOT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//")"
  # (3) 선행 ~ 확장
  case "$KB_ROOT" in
    "~")    KB_ROOT="$HOME" ;;
    "~/"*)  KB_ROOT="$HOME/${KB_ROOT#\~/}" ;;
  esac
  # (4) 절대경로 확인
  case "$KB_ROOT" in
    /*) : ;;
    *)  echo "⚠️  경로가 올바르지 않습니다: '$KB_ROOT'  (전체 경로를 넣고 ~ 로 시작하지 마세요)"; exit 1 ;;
  esac
  printf '%s\n' "$KB_ROOT" > "$KB_CONFIG"
fi
VAULT_DEBRIEF_DIR="$KB_ROOT/debriefs"
echo "→ 교훈 일지 폴더: $VAULT_DEBRIEF_DIR"

CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills/weekly-retro"
SCRIPTS_DIR="$CLAUDE_DIR/scripts"
HOOKS_DIR="$CLAUDE_DIR/hooks"
LOGS_DIR="$CLAUDE_DIR/logs"
LA_DIR="$HOME/Library/LaunchAgents"
CONFIG="$CLAUDE_DIR/weekly-retro.config"
HOOK_SH="$HOOKS_DIR/weekly-retro-session-start.sh"
SCAN_PY="$SCRIPTS_DIR/weekly-retro-scan.py"
PLIST="$LA_DIR/com.user.weekly-retro.plist"

echo "→ 폴더 준비..."
mkdir -p "$SKILLS_DIR" "$SCRIPTS_DIR" "$HOOKS_DIR" "$LOGS_DIR" "$LA_DIR" "$VAULT_DEBRIEF_DIR"

echo "→ 설정 파일 기록..."
printf '%s\n' "$VAULT_DEBRIEF_DIR" > "$CONFIG"

echo "→ 스캔 스크립트 설치..."
cat > "$SCAN_PY" <<'WRS_PY'
#!/usr/bin/env python3
"""weekly-retro-scan (Mac) — 매주 정해진 시각에 launchd가 실행."""
from __future__ import annotations
import platform, re, subprocess
from datetime import date, datetime
from pathlib import Path

CONFIG = Path.home() / ".claude" / "weekly-retro.config"
WINDOW_DAYS = 90
LESSON_RE = re.compile(r"#lesson/([^\s#]+)")
GUARDRAIL_RE = re.compile(r"#guardrail/([^\s#]+)")
MAJOR_RE = re.compile(r"#sev/major\b")

def debrief_dir():
    try:
        line = CONFIG.read_text(encoding="utf-8").strip().splitlines()[0].strip()
        return Path(line).expanduser()
    except Exception:
        return None

def collect_lines(directory):
    cutoff = datetime.now().timestamp() - WINDOW_DAYS * 86400
    rows = []
    for f in sorted(directory.glob("*-debrief.md")):
        try:
            if f.stat().st_mtime < cutoff:
                continue
            content = f.read_text(encoding="utf-8")
        except OSError:
            continue
        for raw in content.splitlines():
            if "#promoted" in raw:
                continue
            line = raw.strip()
            is_major = bool(MAJOR_RE.search(line))
            for cat in LESSON_RE.findall(line):
                rows.append((cat, "lesson", is_major, f.name, line))
            for cat in GUARDRAIL_RE.findall(line):
                rows.append((cat, "guardrail", is_major, f.name, line))
    return rows

def build_candidates(rows):
    by_cat = {}
    for cat, kind, is_major, fname, line in rows:
        if kind != "lesson":
            continue
        slot = by_cat.setdefault(cat, {"files": set(), "evidence": [], "major": False})
        slot["files"].add(fname)
        slot["evidence"].append((fname, line))
        slot["major"] = slot["major"] or is_major
    candidates = []
    for cat, slot in by_cat.items():
        recurring = len(slot["files"]) >= 2
        if recurring or slot["major"]:
            candidates.append({"category": cat, "count": len(slot["files"]),
                               "major": slot["major"], "recurring": recurring,
                               "evidence": slot["evidence"]})
    candidates.sort(key=lambda c: (c["count"], c["major"]), reverse=True)
    return candidates

def open_guardrails(rows):
    by_cat = {}
    for cat, kind, _m, fname, line in rows:
        if kind != "guardrail":
            continue
        by_cat.setdefault(cat, []).append((fname, line))
    return by_cat

def render_note(candidates, guardrails, today):
    fm = "---\ntags:\n  - weekly-retro\ncreated: %s\n---\n\n" % today
    lines = [f"# 주간 리트로 후보 — {today}\n"]
    lines.append("> 자동 집계 결과입니다. Claude Code에서 `/weekly-retro` 를 실행해 "
                 "건건이 승인/기각하세요. 승인한 것만 영구 규칙(CLAUDE.md)으로 올라갑니다.\n")
    if not candidates:
        lines.append("## 승격 후보\n")
        lines.append("- 이번 주 재발(2회+) 또는 치명(#sev/major) 교훈 없음. 👍\n")
    else:
        lines.append(f"## 승격 후보 ({len(candidates)}건)\n")
        for c in candidates:
            badge = []
            if c["recurring"]:
                badge.append(f"재발 {c['count']}회")
            if c["major"]:
                badge.append("치명(major)")
            lines.append(f"### #lesson/{c['category']} — {', '.join(badge)}")
            for fname, text in c["evidence"]:
                lines.append(f"\t- [{'-'.join(fname.split('-')[:3])}] {text}")
            lines.append("")
    if guardrails:
        lines.append(f"## 아직 살아있는 가드레일 ({len(guardrails)}개 범주)\n")
        for cat, ev in sorted(guardrails.items(), key=lambda kv: -len(kv[1])):
            lines.append(f"### #guardrail/{cat} — {len(ev)}회")
            for fname, text in ev:
                lines.append(f"\t- [{'-'.join(fname.split('-')[:3])}] {text}")
            lines.append("")
    return fm + "\n".join(lines) + "\n"

def notify(title, message):
    try:
        if platform.system() == "Darwin":
            subprocess.run(["osascript", "-e",
                f'display notification "{message}" with title "{title}"'],
                check=False, timeout=10)
    except Exception:
        pass

def main():
    directory = debrief_dir()
    if directory is None or not directory.is_dir():
        return 0
    today = date.today().isoformat()
    rows = collect_lines(directory)
    candidates = build_candidates(rows)
    guardrails = open_guardrails(rows)
    note = render_note(candidates, guardrails, today)
    if (directory.parent / "wiki").is_dir():
        note += "\n## 함께 정비\n- 위키(wiki/)도 `/lint`로 같이 점검하세요 — 모순·끊긴 링크 정리. (주간 정비를 한 번에)\n"
    (directory / f"리뷰 대기 — 주간 리트로 {today}.md").write_text(note, encoding="utf-8")
    n = len(candidates)
    notify("주간 리트로", f"승격 후보 {n}건 대기 중 — /weekly-retro 로 검토하세요" if n
           else "이번 주 승격 후보 없음 👍")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
WRS_PY

echo "→ 세션 시작 훅 설치..."
cat > "$HOOK_SH" <<'WRS_SH'
#!/bin/bash
# SessionStart 훅: 최근 debrief 교훈/가드레일 주입 + 미처리 리뷰 노트 넛지
CONFIG="$HOME/.claude/weekly-retro.config"
[ -f "$CONFIG" ] || exit 0
DIR="$(head -n1 "$CONFIG")"
[ -d "$DIR" ] || exit 0
DEBRIEFS=$(find "$DIR" -name "*-debrief.md" -mtime -14 2>/dev/null | sort -r | head -5)
CONTENT=""
while IFS= read -r FILE; do
  [ -z "$FILE" ] && continue
  DATE_STR=$(basename "$FILE" | cut -d'-' -f1-3)
  MISTAKES=$(awk '/### 실수 & 교훈/{f=1;next} /^### /{f=0} f&&NF{print}' "$FILE" | head -5)
  GUARDRAILS=$(awk '/### 다음 세션 주의사항/{f=1;next} /^### |^---/{f=0} f&&NF{print}' "$FILE" | head -5)
  if [ -n "$MISTAKES" ] || [ -n "$GUARDRAILS" ]; then
    CONTENT="$CONTENT\n#### $DATE_STR"
    [ -n "$MISTAKES" ] && CONTENT="$CONTENT\n**실수 & 교훈**\n$MISTAKES"
    [ -n "$GUARDRAILS" ] && CONTENT="$CONTENT\n**가드레일**\n$GUARDRAILS"
    CONTENT="$CONTENT\n"
  fi
done <<< "$DEBRIEFS"
if [ -n "$CONTENT" ]; then
  echo "[PAST SESSION LESSONS]"
  echo "최근 세션 교훈/가드레일 — 같은 실수 반복 금지:"
  printf "%b\n" "$CONTENT"
fi
# 처리 완료된 리뷰 노트는 retro-archive/ 로 이동되므로 top-level(-maxdepth 1)만 스캔한다
PENDING=$(find "$DIR" -maxdepth 1 -name "리뷰 대기 — 주간 리트로 *.md" 2>/dev/null | sort -r | head -1)
if [ -n "$PENDING" ] && ! grep -q "처리 완료" "$PENDING" 2>/dev/null; then
  echo ""
  echo "[WEEKLY RETRO PENDING] 미처리 주간 리트로 후보가 있습니다: $(basename "$PENDING")"
  echo "→ 사용자에게 /weekly-retro 실행을 제안할 것."
  [ -d "$(dirname "$DIR")/wiki" ] && echo "   (주간 정비: 위키도 /lint 로 함께 점검하면 좋습니다 — 한 번에.)"
fi
# 금요일 첫 실행 게이트: 매주 금요일, 그날 첫 세션에서 1회만 주간 리트로 실행 여부를 묻는다.
# 하루 한 번만 발동하도록 날짜 마커 파일로 가드(= "처음 실행" 의미). 후보 유무와 무관하게 항상 묻는다.
if [ "$(date +%u)" = "5" ]; then
  ASK_MARKER="$HOME/.claude/.weekly-retro-asked-$(date +%F)"
  if [ ! -f "$ASK_MARKER" ]; then
    : > "$ASK_MARKER"          # 오늘 마커 생성 → 같은 날 이후 세션에선 다시 묻지 않음
    find "$HOME/.claude" -maxdepth 1 -name '.weekly-retro-asked-*' ! -name "$(basename "$ASK_MARKER")" -delete 2>/dev/null  # 옛 마커 정리
    echo ""
    echo "[WEEKLY RETRO — 금요일 첫 실행]"
    echo "→ 사용자에게 물어볼 것: \"오늘 금요일입니다. 주간 리트로(/weekly-retro)를 지금 돌릴까요?\""
    echo "  사용자가 예라고 하면 /weekly-retro 를 실행. 아니라고 하면 넘어갈 것 (오늘은 다시 묻지 않음)."
  fi
fi
WRS_SH
chmod +x "$HOOK_SH"

echo "→ 스킬 설치..."
cat > "$SKILLS_DIR/SKILL.md" <<'WRS_SKILL'
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
WRS_SKILL

echo "→ 상태 점검 스킬(loop-status) 설치..."
mkdir -p "$CLAUDE_DIR/skills/loop-status"
cat > "$CLAUDE_DIR/skills/loop-status/SKILL.md" <<'WRS_LOOPSTATUS'
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
WRS_LOOPSTATUS

echo "→ CLAUDE.md 규약 추가..."
touch "$CLAUDE_DIR/CLAUDE.md"
if ! grep -qF "weekly-retro:debrief-convention" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
cat >> "$CLAUDE_DIR/CLAUDE.md" <<'WRS_MD'

<!-- weekly-retro:debrief-convention -->
## 작업 debrief 자동 기록 (주간 리트로 연동)

의미 있는 작업(문서 작성, 자료 정리, 분석, 조사, 기능 구현, 버그 수정 등)을 끝내면,
교훈 폴더에 `YYYY-MM-DD-debrief.md` 파일을 Write로 작성한다(이미 있으면 섹션 추가).
교훈 폴더 경로는 `~/.claude/weekly-retro.config` 첫 줄에 있다.

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

- 범주는 짧은 영문 키워드(kebab-case, 예: `wrong-folder`, `double-booking`). **기존 범주를 먼저 확인해 같은 사건이면 재사용**한다(재발 카운트 전제).
- 심각도: 치명적(돌이키기 힘든 손실/사고)은 `#sev/major`(1회만으로도 승격 후보), 그 외 `#sev/minor`.
- 영구 규칙으로 승격된 교훈에는 `/weekly-retro`가 원본 줄에 `#promoted`를 붙인다. 수동으로 건드리지 말 것.

## 반복 교훈 (Lessons)
<!-- /weekly-retro 가 승인한 반복 교훈이 여기에 누적됩니다. 매 세션 자동으로 읽힙니다. -->
WRS_MD
fi

echo "→ Claude Code 훅(settings.json) 연결..."
/usr/bin/python3 - "$HOOK_SH" <<'WRS_MERGE'
import json, sys
from pathlib import Path
cmd = sys.argv[1]
p = Path.home() / ".claude" / "settings.json"
data = {}
if p.exists():
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        data = {}
hooks = data.setdefault("hooks", {})
ss = hooks.setdefault("SessionStart", [])
present = any(h.get("command") == cmd for b in ss for h in b.get("hooks", []))
if not present:
    ss.append({"hooks": [{"type": "command", "command": cmd, "timeout": 5}]})
p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
print("   settings.json 업데이트 완료")
WRS_MERGE

if [ "${WR_SKIP_SCHEDULE:-0}" != "1" ]; then
echo "→ 자동 점검 스케줄 등록 (launchd)..."
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.user.weekly-retro</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/python3</string>
		<string>$SCAN_PY</string>
	</array>
	<key>StartCalendarInterval</key>
	<dict>
		<key>Weekday</key>
		<integer>$RETRO_WEEKDAY</integer>
		<key>Hour</key>
		<integer>$RETRO_HOUR</integer>
		<key>Minute</key>
		<integer>$RETRO_MINUTE</integer>
	</dict>
	<key>StandardOutPath</key>
	<string>$LOGS_DIR/weekly-retro.out.log</string>
	<key>StandardErrorPath</key>
	<string>$LOGS_DIR/weekly-retro.err.log</string>
	<key>RunAtLoad</key>
	<false/>
</dict>
</plist>
PLIST_EOF
launchctl bootout "gui/$(id -u)/com.user.weekly-retro" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
fi

echo "→ 설치 검증 (스캔 1회 실행)..."
/usr/bin/python3 "$SCAN_PY" || true

echo ""
echo "✅ 설치 완료!"
echo "   교훈 폴더 : $VAULT_DEBRIEF_DIR"
echo "   자동 점검 : 매주 (요일 $RETRO_WEEKDAY) ${RETRO_HOUR}:$(printf '%02d' "$RETRO_MINUTE")"
echo "   이제 Claude Code로 일하면 교훈이 쌓이고, 금요일에 자동 점검됩니다."

echo ""
echo "── 설치 점검 ──"
[ -d "$KB_ROOT" ] && echo "  ✅ 지식 베이스 폴더: $KB_ROOT" || echo "  ⚠️ 지식 베이스 폴더 없음"
[ -d "$VAULT_DEBRIEF_DIR" ] && echo "  ✅ 교훈 일지(debriefs)" || echo "  ⚠️ debriefs 폴더 없음"
if [ "${WR_SKIP_SCHEDULE:-0}" = "1" ]; then echo "  ⏭️  스케줄 등록 건너뜀(테스트)"
elif launchctl print "gui/$(id -u)/com.user.weekly-retro" >/dev/null 2>&1; then echo "  ✅ 자동 점검 스케줄 (매주 금 ${RETRO_HOUR}:$(printf '%02d' "$RETRO_MINUTE"))"
else echo "  ⚠️ 스케줄 미등록 — 스크립트를 다시 실행해 보세요"; fi
grep -q "weekly-retro-session-start" "$CLAUDE_DIR/settings.json" 2>/dev/null && echo "  ✅ 세션 훅 연결됨(settings.json)" || echo "  ⚠️ 세션 훅 미연결"
[ -f "$SKILLS_DIR/SKILL.md" ] && echo "  ✅ 스킬: weekly-retro" || echo "  ⚠️ weekly-retro 스킬 없음"
[ -f "$CLAUDE_DIR/skills/loop-status/SKILL.md" ] && echo "  ✅ 스킬: loop-status (상태 점검)" || echo "  ⚠️ loop-status 스킬 없음"
echo ""
echo "  💡 언제든 Claude Code에서  /loop-status  로 루프가 잘 도는지 확인하세요."
