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
