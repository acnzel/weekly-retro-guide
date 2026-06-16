<!-- weekly-retro:debrief-convention -->
## 작업 debrief 자동 기록 (주간 리트로 연동)

의미 있는 작업(문서 작성, 자료 정리, 분석, 조사, 기능 구현, 버그 수정 등)을 끝내면,
교훈 폴더에 `YYYY-MM-DD-debrief.md` 파일을 Write로 작성한다(이미 있으면 섹션 추가).
교훈 폴더 경로는 `~/.claude/weekly-retro.config`(Windows: `%USERPROFILE%\.claude\weekly-retro.config`) 첫 줄에 있다.

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

- 범주는 짧은 영문 키워드(kebab-case, 예: `wrong-folder`, `double-booking`). 기존 범주를 먼저 확인해 같은 사건이면 재사용한다(재발 카운트 전제).
- 심각도: 치명적(돌이키기 힘든 손실/사고)은 `#sev/major`(1회만으로도 승격 후보), 그 외 `#sev/minor`.
- 영구 규칙으로 승격된 교훈에는 `/weekly-retro`가 원본 줄에 `#promoted`를 붙인다. 수동으로 건드리지 말 것.

## 반복 교훈 (Lessons)
<!-- /weekly-retro 가 승인한 반복 교훈이 여기에 누적됩니다. 매 세션 자동으로 읽힙니다. -->
