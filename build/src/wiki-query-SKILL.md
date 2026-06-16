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
