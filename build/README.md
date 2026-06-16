# build/ — 가이드 빌드 파이프라인

`index.html`(통합 가이드)과 `llm-wiki.html`(구 URL 리다이렉트)은 **손으로 고치지 말고** 여기서 생성한다.

## 재생성

```bash
python3 build/build_index.py
```

- 입력: `build/src/` 안의 소스 17개(설치 스크립트·스킬·스캔/훅·CLAUDE 조각 등)
- 출력: repo 루트의 `index.html`, `llm-wiki.html`
- 빌더는 f-string 대신 **토큰 치환**(`__INSTALLERS_RETRO__`/`__INSTALLERS_WIKI__`/`__INDIVIDUAL__`)을 써서 CSS 중괄호 이스케이프 문제를 피한다.

## 구조

- `build_index.py` — 단일 빌더. `FILES` 목록이 `build/src/`의 어떤 파일을 어느 카드로 임베드할지 정의한다.
- `build/src/` — 다운로드/임베드되는 원본 파일들. 내용 수정은 여기서 한다.
- 본문 문장(설명·FAQ 등)은 `build_index.py`의 `TEMPLATE` 문자열 안에 있다.

## 배포

```bash
vercel deploy --prod --yes   # acnzel 계정
```

git push만으로 자동 배포되지 않을 수 있으니, 출력이 바뀌면 위 명령으로 직접 배포한다.
