---
name: slack-digest
description: Use when the user says "/slack-digest", "슬랙 다이제스트", "슬랙 어제치 정리", or wants to capture yesterday's Slack channel activity into the knowledge base. Reads a configured list of Slack channels (or channel IDs passed as arguments), fetches the previous day's (KST) messages and full threads via the Slack MCP/connector tools, and writes one Markdown file per channel into the knowledge base's raw/slack/ folder so it can later be processed by /ingest. Producer only — never moves files to ingested/ (that is /ingest's job).
---

# /slack-digest — 슬랙 어제치를 raw로 떨구기

설정된 슬랙 채널들의 **어제(KST) 하루치 메시지 + 스레드**를 읽어 채널별 Markdown 파일로
**현재 지식 베이스 폴더의 `raw/slack/`** 에 저장한다. 이후 `/ingest`가 이 파일들을 위키로 정리하고 `ingested/`로 옮긴다.

- **이 스킬은 생산자다.** raw에 떨구기만 한다. `ingested/`로의 이동은 `/ingest`의 책임이므로 여기서 하지 않는다.
- **사전 조건:** Slack 커넥터(MCP)가 연결돼 있어야 하고(`설정 → 커넥터 → Slack`), **Code 탭(Local)에서 위키 폴더를 열고** 실행해야 한다. Slack 도구(`mcp__*Slack*`)는 현재 대화 세션에서만 동작하는 온디맨드 전용 스킬이다.

## 경로

- 채널 리스트: `~/.claude/skills/slack-digest/channels.txt`
- 산출물: `raw/slack/{date}-{channel_id}-{channel_name}.md` (현재 열어둔 지식 베이스 폴더 기준 상대 경로)

## 절차

### 1. 입력 결정
- **채널 목록**
  - 인자로 채널 ID가 주어지면(`/slack-digest C12345 C67890`) 그 채널들만 처리.
  - 인자가 없으면 `~/.claude/skills/slack-digest/channels.txt`를 읽는다.
    각 줄에서 `#` 이후(주석)와 빈 줄을 무시하고, 줄 맨 앞 토큰을 채널 ID로 본다.
- **대상 날짜**
  - `--date YYYY-MM-DD`가 주어지면 그 날짜, 없으면 **어제(KST)**.
  - 어제 날짜: `TZ=Asia/Seoul date -v-1d +%Y-%m-%d`

### 2. 시간 범위 계산 (KST)
대상 날짜를 `D`라 할 때, Unix 초 단위로:
```bash
oldest=$(TZ=Asia/Seoul date -j -f "%Y-%m-%d %H:%M:%S" "D 00:00:00" +%s)
latest=$(TZ=Asia/Seoul date -j -f "%Y-%m-%d %H:%M:%S" "D 23:59:59" +%s)
```
이 `oldest`/`latest`를 그대로 Slack 도구의 `oldest`/`latest` 인자로 쓴다(문자열 정수 초).

### 3. 채널별 루프
각 채널 ID에 대해:

a. **메시지 수집** — Slack 커넥터의 채널 읽기 도구(`slack_read_channel(channel_id, oldest, latest, limit=100)` 계열).
   응답에 `next_cursor`(또는 `response_metadata.next_cursor`)가 있으면 `cursor`로 넘기며 전부 페이징한다.
   - 채널명을 모르면 응답 메타에서 얻거나, 없으면 채널 검색 도구(`slack_search_channels`)로 ID를 조회해 이름을 확보한다.

b. **스레드 수집 — 부모 메시지가 어제 범위에 든 스레드만.**
   수집한 메시지 중 스레드 부모(보통 `thread_ts == ts`이고 `reply_count > 0`)인 것에 대해서만
   스레드 읽기 도구(`slack_read_thread(channel_id, message_ts=ts)`)로 답글 전체를 가져온다.
   - 답글이 오늘로 넘어가도 그 스레드는 통째로 수집한다(부모 기준 판정).
   - 부모가 어제 범위 밖이면(어제는 답글만 달린 오래된 스레드) 수집하지 않는다.

c. **작성자 이름 변환** — 메시지/답글의 user ID를 표시이름으로 바꾼다.
   사용자 프로필 조회 도구(`slack_read_user_profile(user_id)`)를 쓰되, **세션 내에서 user_id→이름을 캐시**해
   같은 사람을 반복 호출하지 않는다. 이름은 `profile.name`(닉네임) 기준. 봇/시스템 메시지는 봇 이름으로 표기.

d. **정렬** — 메시지를 시간 오름차순으로 정렬해 본문을 구성한다.

e. **파일 작성** — 아래 포맷으로
   `raw/slack/{date}-{channel_id}-{channel_name}.md`에 Write.
   - `channel_name`은 파일명 안전하게 정리(`#` 제거, 공백·슬래시→`-`).
   - 같은 파일이 이미 있으면 덮어쓴다(재실행 시 최신화).

### 4. 요약 보고
채널별로 `메시지 N건 / 스레드 M개 → 파일경로`를 표로 보고한다.
접근 실패·메시지 0건 채널은 사유와 함께 명시한다.

## md 포맷 (ingest 친화적)

```markdown
---
type: source
source: slack
channel: "#백엔드-알림"
channel_id: C12345
date: 2026-06-14
message_count: 23
thread_count: 4
---

# #백엔드-알림 — 2026-06-14

## 09:14 김키커
배포 관련 질문 있습니다 ...

### 🧵 스레드 (3 replies)
- **09:20 이플랩**: 확인해볼게요
- **09:25 김키커**: 감사합니다

## 10:02 박매니저
...
```

- 시각은 KST `HH:MM`로 표기.
- 스레드는 부모 메시지 바로 아래 `### 🧵 스레드 (N replies)` 블록으로 답글을 시간순 나열.

## 엣지/에러 처리 (최소)
- 채널 접근 불가(`channel_not_found`·권한 없음): 그 채널만 건너뛰고 보고에 명시, 나머지 진행.
- 어제 메시지 0건: **빈 파일을 만들지 않고** 보고에만 "메시지 없음"으로 남긴다.
- 봇/시스템 메시지: 포함하되 작성자를 봇/시스템 이름으로 표기.

## 범위 밖 (YAGNI)
- 리액션·첨부파일 메타데이터, DM, 무인 스케줄 실행은 다루지 않는다.
- `ingested/`로의 이동은 `/ingest`가 한다. 이 스킬은 절대 파일을 옮기거나 지우지 않는다.
