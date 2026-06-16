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
