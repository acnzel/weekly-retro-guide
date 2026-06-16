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
