#!/usr/bin/env python3
"""통합 가이드 빌더 — 주간 리트로 + LLM 위키를 점진형 단일 index.html로.
f-string 대신 토큰 치환을 써서 CSS 중괄호 이스케이프 문제를 피한다."""
import html
from pathlib import Path

# 빌더는 build/ 안에 있고, 소스는 build/src/, 산출물(index.html·llm-wiki.html)은 repo 루트에 쓴다.
HERE = Path(__file__).resolve().parent
SRC = HERE / "src"
OUTDIR = HERE.parent

# group: retro(교훈 루프) / wiki(지식 위키) / common(공통). primary=설치 스크립트.
FILES = [
    dict(
        id="mac-installer",
        src="install-weekly-retro-mac.command",
        file="install-weekly-retro-mac.command",
        os="mac",
        badge="Mac · 원클릭",
        primary=True,
        group="retro",
        must='⚠️ 실행 전, 맨 위 한 줄의 "여기에…붙여넣으세요"를 본인 지식 베이스 폴더의 전체 경로로 반드시 바꾸세요.',
        desc="이 파일 하나가 교훈 루프의 모든 구성요소(스킬·스캔·훅·스케줄·CLAUDE.md 규약)를 자동 설치합니다.",
    ),
    dict(
        id="win-installer",
        src="install-weekly-retro-windows.ps1",
        file="install-weekly-retro-windows.ps1",
        os="win",
        badge="Windows · 원클릭",
        primary=True,
        group="retro",
        must='⚠️ 실행 전, 맨 위 한 줄($KbRoot)의 "여기에…붙여넣으세요"를 본인 지식 베이스 폴더의 전체 경로로 반드시 바꾸세요.',
        desc="이 스크립트 하나가 교훈 루프의 모든 구성요소를 자동 설치합니다.",
    ),
    dict(
        id="wiki-mac",
        src="install-llm-wiki-mac.command",
        file="install-llm-wiki-mac.command",
        os="mac",
        badge="Mac · 원클릭",
        primary=True,
        group="wiki",
        must='⚠️ 실행 전, 맨 위 한 줄의 "여기에…붙여넣으세요"를 지식 베이스 폴더의 전체 경로로 바꾸세요. (교훈 루프를 이미 깔았다면 같은 폴더를 자동으로 씁니다.)',
        desc="이 파일 하나가 위키 폴더 구조(raw/·wiki/) + 규약(CLAUDE.md) + /ingest·/query·/lint 세 명령을 자동 설치합니다.",
    ),
    dict(
        id="wiki-win",
        src="install-llm-wiki-windows.ps1",
        file="install-llm-wiki-windows.ps1",
        os="win",
        badge="Windows · 원클릭",
        primary=True,
        group="wiki",
        must='⚠️ 실행 전, 맨 위 한 줄($KbRoot)의 "여기에…붙여넣으세요"를 지식 베이스 폴더의 전체 경로로 바꾸세요. (교훈 루프를 이미 깔았다면 같은 폴더를 자동으로 씁니다.)',
        desc="이 스크립트 하나가 위키 폴더 구조 + 규약 + 세 명령을 자동 설치합니다.",
    ),
    # ---- 개별 파일 (수동 설치용) ----
    dict(
        id="mac-scan",
        src="weekly-retro-scan.py",
        file="weekly-retro-scan.py",
        os="mac",
        badge="Mac · 교훈루프",
        primary=False,
        group="retro",
        desc="매주 자동 실행되는 집계 스크립트. 재발(2회+)·치명(major) 교훈을 모아 '리뷰 대기' 노트를 만듭니다.",
    ),
    dict(
        id="mac-hook",
        src="weekly-retro-session-start.sh",
        file="weekly-retro-session-start.sh",
        os="mac",
        badge="Mac · 교훈루프",
        primary=False,
        group="retro",
        desc="세션 시작 훅. 최근 교훈을 AI에게 주입하고, 미처리 리뷰가 있으면 알려줍니다.",
    ),
    dict(
        id="win-scan",
        src="weekly-retro-scan.ps1",
        file="weekly-retro-scan.ps1",
        os="win",
        badge="Windows · 교훈루프",
        primary=False,
        group="retro",
        desc="매주 자동 실행되는 집계 스크립트(PowerShell).",
    ),
    dict(
        id="win-hook",
        src="weekly-retro-session-start.ps1",
        file="weekly-retro-session-start.ps1",
        os="win",
        badge="Windows · 교훈루프",
        primary=False,
        group="retro",
        desc="세션 시작 훅(PowerShell).",
    ),
    dict(
        id="skill",
        src="SKILL.md",
        file="SKILL.md",
        os="both",
        badge="공통 · 교훈루프",
        primary=False,
        group="retro",
        desc="/weekly-retro 게이트 스킬. ~/.claude/skills/weekly-retro/SKILL.md 에 둡니다.",
    ),
    dict(
        id="claude-snippet",
        src="CLAUDE-snippet.md",
        file="CLAUDE-snippet.md",
        os="both",
        badge="공통 · 교훈루프",
        primary=False,
        group="retro",
        desc="debrief 작성 규약 + 태그 규칙. 사용자 전역 CLAUDE.md 맨 아래에 붙여넣습니다.",
    ),
    dict(
        id="wiki-claude",
        src="wiki-CLAUDE.md",
        file="CLAUDE.md",
        os="both",
        badge="공통 · 위키",
        primary=False,
        group="wiki",
        desc="위키 폴더 맨 위에 두는 '규약' 파일. 작동 방식·폴더 규칙·페이지 형식을 AI에게 알려줍니다.",
    ),
    dict(
        id="ingest",
        src="wiki-ingest-SKILL.md",
        file="ingest-SKILL.md",
        os="both",
        badge="공통 · 위키",
        primary=False,
        group="wiki",
        desc="/ingest 명령. ~/.claude/skills/ingest/SKILL.md 에 둡니다.",
    ),
    dict(
        id="query",
        src="wiki-query-SKILL.md",
        file="query-SKILL.md",
        os="both",
        badge="공통 · 위키",
        primary=False,
        group="wiki",
        desc="/query 명령. ~/.claude/skills/query/SKILL.md 에 둡니다.",
    ),
    dict(
        id="lint",
        src="wiki-lint-SKILL.md",
        file="lint-SKILL.md",
        os="both",
        badge="공통 · 위키",
        primary=False,
        group="wiki",
        desc="/lint 명령. ~/.claude/skills/lint/SKILL.md 에 둡니다.",
    ),
    dict(
        id="slack-digest",
        src="slack-digest-SKILL.md",
        file="slack-digest-SKILL.md",
        os="both",
        badge="선택 · Slack",
        primary=False,
        group="wiki",
        desc="/slack-digest 명령(선택). ~/.claude/skills/slack-digest/SKILL.md 로 저장(파일명은 SKILL.md). Slack 커넥터가 연결돼 있어야 동작합니다. 어제치 채널 대화를 raw/slack/ 로 떨궈 줘요.",
    ),
    dict(
        id="slack-channels",
        src="slack-digest-channels.txt",
        file="channels.txt",
        os="both",
        badge="선택 · Slack",
        primary=False,
        group="wiki",
        desc="slack-digest가 읽는 채널 목록. ~/.claude/skills/slack-digest/channels.txt 로 저장하고 본인 채널 ID로 채우세요.",
    ),
    dict(
        id="loop-status",
        src="loop-status-SKILL.md",
        file="loop-status-SKILL.md",
        os="both",
        badge="공통",
        primary=False,
        group="common",
        desc="루프 상태 점검 스킬. ~/.claude/skills/loop-status/SKILL.md 에 둡니다. Claude Code에서 /loop-status 로 실행하면 루프 건강검진 대시보드를 보여줍니다.",
    ),
]

for f in FILES:
    f["content"] = (SRC / f["src"]).read_text(encoding="utf-8")
    assert "</script>" not in f["content"], f["src"]


def file_card(f):
    oscls = {"mac": "only-mac", "win": "only-win", "both": "only-both"}[f["os"]]
    badgecls = {"mac": "b-mac", "win": "b-win", "both": "b-both"}[f["os"]]
    must_html = (
        ('\n      <p class="fmust">%s</p>' % html.escape(f["must"]))
        if f.get("must")
        else ""
    )
    return """
    <div class="filecard %(oscls)s">
      <div class="fhead">
        <div class="fmeta"><span class="fname">%(file)s</span><span class="badge %(badgecls)s">%(badge)s</span></div>
        <div class="factions">
          <button class="btn" onclick="copyFile('%(id)s', this)">복사</button>
          <button class="btn" onclick="downloadFile('%(id)s','%(file)s')">다운로드</button>
        </div>
      </div>
      <p class="fdesc">%(desc)s</p>%(must)s
      <pre class="code" id="code-%(id)s"></pre>
      <script type="text/plain" id="src-%(id)s">%(content)s</script>
    </div>""" % dict(
        oscls=oscls,
        badgecls=badgecls,
        file=html.escape(f["file"]),
        badge=html.escape(f["badge"]),
        id=f["id"],
        desc=html.escape(f["desc"]),
        must=must_html,
        content=f["content"],
    )


installers_retro = "".join(
    file_card(f) for f in FILES if f["primary"] and f["group"] == "retro"
)
installers_wiki = "".join(
    file_card(f) for f in FILES if f["primary"] and f["group"] == "wiki"
)
individual = "".join(file_card(f) for f in FILES if not f["primary"])

TEMPLATE = r"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>내 지식 작업 세트 · 교훈 루프 + 지식 위키 (비개발자용 따라하기)</title>
<style>
  :root {
    --bg:#f6f7fb; --card:#ffffff; --ink:#1f2330; --mut:#6b7280; --line:#e6e8ef;
    --accent:#0e9f6e; --accent2:#5b54e8; --good:#10b981; --warn:#f59e0b; --code:#1b1e2b;
  }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--bg); color:var(--ink);
    font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","Apple SD Gothic Neo","Malgun Gothic",Roboto,sans-serif;
    line-height:1.7; -webkit-font-smoothing:antialiased; }
  .wrap { max-width:880px; margin:0 auto; padding:0 20px 120px; }
  header.hero { background:linear-gradient(135deg,var(--accent),var(--accent2)); color:#fff; padding:54px 20px 40px; }
  header.hero .inner { max-width:880px; margin:0 auto; }
  header.hero h1 { font-size:30px; margin:0 0 10px; letter-spacing:-.5px; }
  header.hero p { font-size:17px; margin:0; opacity:.95; }
  .osbar { position:sticky; top:0; z-index:50; background:rgba(255,255,255,.9); backdrop-filter:blur(8px);
    border-bottom:1px solid var(--line); padding:10px 0; }
  .osbar .inner { max-width:880px; margin:0 auto; padding:0 20px; display:flex; align-items:center; gap:10px; }
  .osbar .lbl { font-size:13px; color:var(--mut); margin-right:4px; }
  .ostoggle button { border:1px solid var(--line); background:#fff; color:var(--ink); padding:7px 16px;
    border-radius:999px; cursor:pointer; font-size:14px; font-weight:600; }
  .ostoggle button.active { background:var(--accent); color:#fff; border-color:var(--accent); }
  h2 { font-size:22px; margin:42px 0 14px; letter-spacing:-.3px; }
  h2 .part { display:inline-block; font-size:12.5px; font-weight:700; color:#fff; background:var(--accent2);
    border-radius:999px; padding:2px 10px; margin-right:8px; vertical-align:middle; }
  h2 .part.a { background:var(--accent); }
  h3 { font-size:17px; margin:24px 0 8px; }
  p, li { font-size:15.5px; }
  .lead { font-size:16.5px; }
  .card { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:20px 22px; margin:16px 0;
    box-shadow:0 1px 2px rgba(20,20,50,.04); }
  .flow { display:grid; grid-template-columns:1fr; gap:10px; margin:16px 0; }
  .flow .step { display:flex; gap:14px; align-items:flex-start; background:var(--card); border:1px solid var(--line);
    border-radius:12px; padding:14px 16px; }
  .flow .ic { font-size:24px; line-height:1; }
  .flow .step b { display:block; font-size:15.5px; }
  .flow .step span { color:var(--mut); font-size:14px; }
  .steps { counter-reset:step; }
  .stepblock { position:relative; padding-left:50px; margin:24px 0; }
  .stepblock:before { counter-increment:step; content:counter(step); position:absolute; left:0; top:-2px;
    width:34px; height:34px; border-radius:50%; background:var(--accent); color:#fff; font-weight:700;
    display:flex; align-items:center; justify-content:center; }
  .twocol { display:grid; grid-template-columns:1fr 1fr; gap:12px; margin:14px 0; }
  .twocol .box { border:1px solid var(--line); border-radius:12px; padding:14px 16px; background:var(--card); }
  .twocol .box.raw { border-color:#cfe9dd; background:#f0fbf6; }
  .twocol .box.wiki { border-color:#d9d7fb; background:#f4f3fe; }
  @media (max-width:620px) { .twocol { grid-template-columns:1fr; } }
  .filecard { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:14px 16px 16px; margin:16px 0; }
  .fhead { display:flex; justify-content:space-between; align-items:center; gap:10px; flex-wrap:wrap; }
  .fmeta { display:flex; align-items:center; gap:10px; }
  .fname { font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:14px; font-weight:700; }
  .badge { font-size:11.5px; font-weight:700; padding:3px 9px; border-radius:999px; }
  .b-mac { background:#e7f6ef; color:#0a7a52; }
  .b-win { background:#e7f3ff; color:#1d6fd0; }
  .b-both { background:#eef0ff; color:#4b46c9; }
  .factions { display:flex; gap:8px; }
  .btn { border:1px solid var(--line); background:#fff; color:var(--ink); padding:6px 14px; border-radius:8px;
    cursor:pointer; font-size:13px; font-weight:600; }
  .btn:hover { border-color:var(--accent); color:var(--accent); }
  .btn.copied { background:var(--good); color:#fff; border-color:var(--good); }
  .fdesc { color:var(--mut); font-size:13.5px; margin:8px 0 4px; }
  .fmust { color:#d92d20; font-weight:700; font-size:14px; margin:0 0 10px; background:#fff2f0;
    border:1px solid #ffd5cf; border-radius:8px; padding:8px 12px; }
  pre.code { background:var(--code); color:#e6e6f0; border-radius:10px; padding:14px 16px; overflow:auto;
    font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:12.5px; line-height:1.55;
    max-height:340px; margin:0; }
  code.inl { background:#e7f4ee; color:#0a7a52; padding:1px 6px; border-radius:5px;
    font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:13px; }
  .cmd { display:flex; gap:14px; align-items:flex-start; }
  .cmd .tag { font-family:ui-monospace,Menlo,Consolas,monospace; font-weight:700; color:#0a7a52;
    background:#e7f4ee; border-radius:8px; padding:4px 10px; white-space:nowrap; }
  .callout { border-left:4px solid var(--accent); background:#eefaf4; padding:12px 16px; border-radius:0 10px 10px 0; margin:14px 0; }
  .callout.warn { border-color:var(--warn); background:#fff8ec; }
  .callout.good { border-color:var(--good); background:#eefaf4; }
  .callout.info { border-color:var(--accent2); background:#f3f3fe; }
  .checkpoint { background:linear-gradient(135deg,#ecfdf5,#eef2ff); border:1px solid #c9efdc; border-radius:14px;
    padding:18px 22px; margin:22px 0; }
  .checkpoint b { font-size:16px; }
  details { background:var(--card); border:1px solid var(--line); border-radius:12px; padding:6px 16px; margin:14px 0; }
  summary { cursor:pointer; font-weight:700; padding:8px 0; font-size:16px; }
  details[open] summary { border-bottom:1px solid var(--line); margin-bottom:10px; }
  table.faq td { padding:8px 10px; border-bottom:1px solid var(--line); vertical-align:top; font-size:14px; }
  .pathex { font-family:ui-monospace,Menlo,Consolas,monospace; font-size:12.5px; background:#eef0f6;
    padding:8px 12px; border-radius:8px; display:block; margin:6px 0; overflow:auto; white-space:pre; }
  .muted { color:var(--mut); font-size:13.5px; }
  a { color:var(--accent); }
  .pill { display:inline-block; background:#eef0ff; color:#4b46c9; font-weight:700; font-size:12px;
    padding:2px 9px; border-radius:999px; }
  hr.sep { border:none; border-top:1px solid var(--line); margin:34px 0; }
</style>
</head>
<body data-os="mac">
<header class="hero">
  <div class="inner">
    <h1>🧠 내 지식이 자라는 작업 세트</h1>
    <p>한 폴더 안에서 두 가지가 같이 자랍니다. 하나는 일하는 법(교훈 루프), 하나는 아는 것(지식 위키)이요. Claude Code로 일할수록 나도 AI도 똑똑해집니다. 개발 안 해본 분도 따라 할 수 있게 적었어요.</p>
  </div>
</header>

<div class="osbar">
  <div class="inner">
    <span class="lbl">내 컴퓨터:</span>
    <div class="ostoggle">
      <button id="btn-mac" class="active" onclick="setOS('mac')"> Mac</button>
      <button id="btn-win" onclick="setOS('win')">⊞ Windows</button>
    </div>
    <span class="muted" id="oshint" style="margin-left:auto"></span>
  </div>
</div>

<div class="wrap">

  <div class="callout info" style="margin-top:24px">⏱️ <b>3분 요약</b> (끝까지 안 읽어도 흐름만):
    <br>① Obsidian으로 폴더 하나 만들기 → ② Claude Code(데스크탑 Code 탭) 설치 → ③ 설치 스크립트에서 폴더 경로 한 줄만 바꿔 실행 → ④ 평소처럼 일하면 교훈이 쌓이고, 금요일에 <code class="inl">/weekly-retro</code>로 검토 → ⑤ (선택) 자료를 <code class="inl">raw/</code>에 넣고 <code class="inl">/ingest</code> 하면 나만의 위키가 자랍니다.</div>

  <h2>이게 뭐예요?</h2>
  <p class="lead">AI와 일하다 보면 두 가지가 그냥 날아가 버려요. 내가 얻은 교훈, 그리고 내가 읽고 모은 지식이요.
  이 세트는 그 둘을 같은 폴더 한 곳에 차곡차곡 쌓습니다. 쓰면 쓸수록 나도 AI도 똑똑해지고요.</p>
  <div class="twocol">
    <div class="box raw">
      <b>교훈 루프</b> <span class="pill">Part A · 기본</span>
      <p class="muted" style="margin:6px 0 0">일하며 얻은 교훈을 일지에 모읍니다. 그중 반복되는 것만 골라 AI의 영구 규칙으로 올려요. 같은 실수를 두 번 하지 않게요.</p>
    </div>
    <div class="box wiki">
      <b>지식 위키</b> <span class="pill">Part B · 확장</span>
      <p class="muted" style="margin:6px 0 0">읽은 자료를 넣어 두면 AI가 주제별로 정리하고 이어 붙여, 나만의 백과사전으로 키웁니다.</p>
    </div>
  </div>
  <div class="card">
    <b>왜 좋을까?</b>
    <ul>
      <li><b>나한테는</b> '결정·교훈·지식'이 검색 가능한 자산으로 쌓여요. "그때 왜 그렇게 정했더라?", "그 자료 어디 뒀더라?" 싶을 때 한 폴더에서 바로 찾습니다.</li>
      <li><b>AI한테는</b> 같은 실수를 반복하지 않고, 내가 모은 지식을 근거로 답하게 됩니다. 그래서 점점 똑똑해져요.</li>
      <li><b>개발자가 아니어도</b> 됩니다. 문서·자료 정리, 분석, 기획, 투자, 취미 리서치까지 Claude Code로 하는 일이면 다 통해요.</li>
    </ul>
    <span class="muted">한 줄로 비유하면 이렇습니다. 그냥 AI 채팅은 그때그때 찾아보고 버려서 아무것도 안 남아요. 이 세트는 넣을 때마다 쌓이고 서로 이어집니다. (Andrej Karpathy의 'LLM Wiki' 아이디어에 주간 회고를 더했습니다.)</span>
  </div>
  <div class="callout info">📌 <b>읽는 순서.</b> 공통 준비를 먼저 하세요. Part A(교훈 루프)까지만 해도 충분히 쓸 만합니다. Part B(지식 위키)는 원할 때 같은 폴더에 이어서 더하면 돼요.</div>

  <h2>어떻게 작동하나요? <span class="muted" style="font-size:14px">(교훈 루프 기준)</span></h2>
  <div class="flow">
    <div class="step"><div class="ic">✍️</div><div><b>1. 기록</b><span>Claude Code가 일을 끝내면 '교훈'을 일지에 자동으로 적습니다 (작은 #태그와 함께).</span></div></div>
    <div class="step"><div class="ic">🔍</div><div><b>2. 집계</b><span>매주 금요일 14:30, 컴퓨터가 자동으로 <b>2번 이상 반복된</b> 교훈을 모아 '리뷰 대기' 목록을 만듭니다.</span></div></div>
    <div class="step"><div class="ic">✅</div><div><b>3. 승인</b><span>당신이 <code class="inl">/weekly-retro</code> 를 실행하면 후보를 보여주고, "이건 규칙으로" 라고 고르기만 하면 됩니다.</span></div></div>
    <div class="step"><div class="ic">🧠</div><div><b>4. 적용</b><span>승인된 규칙을 AI가 매 작업마다 기억해서, 같은 실수를 다시 하지 않습니다.</span></div></div>
  </div>
  <div class="callout"><b>핵심 원칙.</b> 한 번 한 실수는 규칙으로 안 만듭니다(괜한 잔소리 방지). 두 번째로 반복됐을 때 비로소 후보가 돼요. 단, 되돌리기 힘든 치명적 실수는 한 번이라도 올립니다. (위키의 <code class="inl">/lint</code>·<code class="inl">/ingest</code>도 똑같이 '사람이 승인하는' 방식으로 움직여요.)</div>

  <h2>어디서 써야 작동하나요? <span class="muted" style="font-size:14px">(꼭 확인하세요)</span></h2>
  <p>이 세트는 <b>Claude Code</b>에서 돌아갑니다. <b>Claude Desktop 앱</b>을 쓴다면 앱 안 세 탭(Chat · Cowork · <b>Code</b>) 중에서 꼭 <b>Code 탭</b>을, 환경은 <b>"내 컴퓨터(Local)"</b>로 골라야 해요.</p>
  <div class="card">
    <table class="faq">
      <tr><td>✅</td><td><b>Claude Desktop 앱 → Code 탭 (Local)</b><br><span class="muted">CLI와 똑같은 <code class="inl">~/.claude</code> 설정·스킬·훅을 공유하고 내 컴퓨터 파일에 접근해요. 터미널 없이 GUI로 쓰니 <b>비개발자에게 추천</b>합니다.</span></td></tr>
      <tr><td>✅</td><td><b>터미널 Claude Code (CLI)</b><br><span class="muted">개발자·고급 사용자용. 위와 설정을 공유하니 결과는 똑같아요.</span></td></tr>
      <tr><td>❌</td><td><b>Chat 탭(일반 대화)</b><br><span class="muted">Claude Code가 아닙니다. CLAUDE.md·스킬·훅·로컬 파일을 쓰지 않아 작동하지 않아요.</span></td></tr>
      <tr><td>❌</td><td><b>클라우드(Remote) 세션</b><br><span class="muted">Anthropic 서버 샌드박스에서 돌아 <b>내 Obsidian 폴더를 못 봅니다.</b> 꼭 Local을 고르세요.</span></td></tr>
      <tr><td>⏰</td><td><b>매주 자동 점검(스캔)</b><br><span class="muted">이건 늘 돕니다. 내 컴퓨터 스케줄러가 돌리니 Claude를 켜두지 않아도 돼요.</span></td></tr>
    </table>
  </div>

  <hr class="sep">

  <h2>공통 준비물</h2>
  <div class="card">
    <ul>
      <li><b>Obsidian</b> 무료 메모 앱이에요. 교훈 일지와 위키가 여기 쌓입니다.</li>
      <li><b>Claude Code</b> 이 세트의 엔진입니다. <b>Claude Desktop 앱의 Code 탭</b>(비개발자 추천)이나 터미널 CLI, 둘 중 하나면 돼요. 설치하고 로그인까지 해 두세요.</li>
      <li class="only-mac"><b>Mac</b>은 <code class="inl">python3</code>가 보통 깔려 있어요. 없으면 설치 안내가 뜹니다.</li>
      <li class="only-win"><b>Windows</b>는 따로 깔 게 없습니다. PowerShell이 기본으로 들어 있어요.</li>
    </ul>
  </div>

  <div class="steps">

    <div class="stepblock">
      <h3>Obsidian 설치 + 지식 베이스 폴더 만들기</h3>
      <p><a href="https://obsidian.md" target="_blank" rel="noopener">obsidian.md</a> 에서 내려받아 설치하고, <b>보관함(Vault)</b>을 하나 만듭니다.
      그 안에 <b>"지식 베이스"</b> 폴더(예: <code class="inl">MyBrain</code>)를 하나 만들고, <b>그 폴더의 전체 경로를 복사</b>해 두세요. 다음 단계에서 한 번 붙여넣습니다.
      <span class="muted">(교훈 일지는 이 폴더 안 <code class="inl">debriefs/</code> 에 저장돼요. Part B 위키를 깔면 같은 폴더에 <code class="inl">raw/</code>·<code class="inl">wiki/</code>가 더해져서 <b>한 폴더로 모입니다</b>.)</span></p>
      <div class="only-mac">
        <span class="muted">Mac 경로 예시:</span>
        <span class="pathex">/Users/내이름/Documents/MyBrain</span>
        <p class="muted">폴더에서 <b>option</b> 키를 누른 채 우클릭 → "경로 이름 복사"로 정확한 경로를 얻을 수 있어요.</p>
      </div>
      <div class="only-win">
        <span class="muted">Windows 경로 예시:</span>
        <span class="pathex">C:\Users\내이름\Documents\MyBrain</span>
        <p class="muted">탐색기에서 폴더를 <b>Shift+우클릭</b> → "경로로 복사"로 정확한 경로를 얻을 수 있어요.</p>
      </div>
    </div>

    <div class="stepblock">
      <h3>Claude Code 설치 + 로그인</h3>
      <p><b>방법 A. Claude Desktop 앱</b> <span class="pill">비개발자 추천</span> <span class="muted">(터미널 없이 GUI로 사용)</span></p>
      <ul>
        <li><a href="https://code.claude.com/docs/en/desktop" target="_blank" rel="noopener">데스크탑 앱 다운로드</a> → 설치 → 로그인 → 상단의 <b>Code 탭</b> 클릭.</li>
        <li class="only-win">Windows는 Code 탭을 처음 열기 전에 <a href="https://git-scm.com/downloads/win" target="_blank" rel="noopener">Git for Windows</a>가 필요합니다(앱이 안내해 줍니다). 설치 후 앱을 재시작하세요.</li>
        <li>새 세션을 만들 때 <b>환경 = "내 컴퓨터(Local)"</b>, <b>프로젝트 폴더 = Obsidian 보관함 폴더</b>를 선택하세요. (Chat 탭·클라우드(Remote)는 작동 안 함 — 위 표 참고)</li>
      </ul>
      <p style="margin-top:14px"><b>방법 B. 터미널 CLI</b> <span class="muted">(개발자·고급 사용자)</span></p>
      <pre class="code">npm install -g @anthropic-ai/claude-code</pre>
      <p class="muted">설치 후 <code class="inl">claude</code> 를 실행해 로그인하세요.</p>
      <div class="callout good">두 방법은 <b>같은 설정(<code class="inl">~/.claude</code>)을 공유</b>해요. 어느 쪽으로 깔든 나머지 단계는 똑같이 적용됩니다.</div>
      <div class="callout muted">※ 설치 방법은 버전에 따라 달라질 수 있으니 <a href="https://code.claude.com/docs" target="_blank" rel="noopener">공식 문서</a>를 기준으로 하세요.</div>
    </div>
  </div>

  <hr class="sep">

  <h2><span class="part a">Part A</span>교훈 루프 설치 <span class="muted" style="font-size:14px">(기본)</span></h2>

  <div class="steps">
    <div class="stepblock">
      <h3>설치 스크립트 실행 (자동 설치)</h3>
      <p>아래 스크립트가 교훈 루프 전체를 한 번에 설치합니다. <b>맨 위 한 줄(지식 베이스 폴더 경로)만</b> 앞에서 복사한 전체 경로로 바꾼 뒤 실행하세요.</p>
      <div class="callout"><b>경로 넣는 법.</b> Finder/탐색기에서 "<b>경로 복사</b>"로 얻은 <b>전체 경로</b>(<span class="only-mac"><code class="inl">/Users/이름/…</code></span><span class="only-win"><code class="inl">C:\Users\이름\…</code></span>)를 따옴표 안에 그대로 붙여넣으세요. <code class="inl">~</code><span class="only-win"> 나 <code class="inl">%USERPROFILE%</code></span> 로 시작하는 경로는 넣지 마세요. <span class="muted">(잘못 넣거나 안 바꾸면 스크립트가 그 자리에서 알려주고 멈춥니다.)</span></div>
      <div class="only-mac">
        <div class="callout"><b>실행 방법(둘 중 하나):</b>
          <br>① 아래 <b>다운로드</b> → 받은 <code class="inl">.command</code> 파일을 더블클릭 (차단되면 우클릭 → "열기").
          <br>② 또는 <b>복사</b> → 터미널에 붙여넣고 Enter.
        </div>
      </div>
      <div class="only-win">
        <div class="callout"><b>실행 방법:</b> 아래 <b>복사</b> → <b>PowerShell</b>을 열고 붙여넣은 뒤 Enter.
        <br>실행이 막히면 먼저 이 한 줄을 실행하세요: <code class="inl">Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned</code></div>
      </div>
      <p class="muted">💡 <b>Claude Desktop 앱만 쓰는 분</b>도 괜찮습니다. Code 탭의 <b>통합 터미널</b>(보기 메뉴 또는 <code class="inl">Ctrl+`</code>)을 열어 붙여넣으면 별도 터미널 앱 없이 설치돼요. <span class="only-win">Windows는 통합 터미널의 PowerShell에서 실행하세요.</span></p>
      __INSTALLERS_RETRO__
    </div>

    <div class="stepblock">
      <h3>설치 확인</h3>
      <div class="only-mac">
        <p>터미널에서 아래를 실행해 스케줄이 등록됐는지 확인합니다(숫자/이름이 보이면 성공):</p>
        <pre class="code">launchctl list | grep weekly-retro</pre>
      </div>
      <div class="only-win">
        <p>PowerShell에서 아래를 실행해 작업이 등록됐는지 확인합니다(상태가 보이면 성공):</p>
        <pre class="code">Get-ScheduledTask -TaskName WeeklyRetro</pre>
      </div>
      <p>그리고 폴더 안 <b><code class="inl">debriefs/</code></b> 에 <code class="inl">리뷰 대기 — 주간 리트로 (날짜).md</code> 파일이 생겼다면 정상 작동입니다. 👍</p>
    </div>

    <div class="stepblock">
      <h3>이제 이렇게 씁니다</h3>
      <div class="card">
        <ul>
          <li><b>평소엔</b> Claude의 <b>Code 탭(내 컴퓨터·Local)</b>에서 일하세요. 의미 있는 작업을 마치면 AI가 일지에 교훈을 알아서 적어 둡니다. (원하면 <code class="inl">오늘 작업 debrief 정리해줘</code>라고 직접 시켜도 되고요.)</li>
          <li><b>금요일 14:30엔</b> 컴퓨터가 알아서 반복 교훈을 모아 알림을 띄워요. (Claude를 켜두지 않아도 됩니다.)</li>
          <li><b>검토할 때는</b> Code 탭을 엽니다. "리뷰 대기 후보가 있다"고 알려주면, 입력창에 <code class="inl">/</code> 를 치고 <b>weekly-retro</b> 를 골라 실행하세요. 후보를 보고 승인/기각만 하면 승인한 교훈이 영구 규칙이 됩니다.</li>
          <li><b>상태가 궁금하면</b> 언제든 <code class="inl">/loop-status</code> 를 실행하세요. 자동 점검 스케줄·교훈 흐름·미처리 리뷰·위키 규모를 한눈에 보여줍니다. <span class="muted">시작 버튼만 누르고 잊는 게 아니라 루프를 지켜보는 창구예요.</span></li>
        </ul>
        <div class="callout warn" style="margin-top:6px">⚠️ 작동 조건. 반드시 <b>Code 탭 + 내 컴퓨터(Local)</b>여야 해요. Chat 탭이나 클라우드(Remote)에서는 일지 기록도 <code class="inl">/weekly-retro</code>도 동작하지 않습니다.</div>
      </div>
    </div>
  </div>

  <div class="checkpoint">
    <b>✅ 여기까지면 기본 완료!</b>
    <p style="margin:8px 0 0">교훈 루프만으로도 충분히 쓸 만해요. 읽은 자료까지 쌓아 '나만의 백과사전'을 만들고 싶다면 아래 Part B로 이어가세요. <b>같은 폴더</b>에 더해지고, 설치 스크립트가 그 폴더를 자동으로 이어받습니다. 필요 없으면 여기서 멈춰도 되고요.</p>
  </div>

  <hr class="sep">

  <h2 id="wiki"><span class="part">Part B</span>지식 위키 만들기 <span class="muted" style="font-size:14px">(확장·선택)</span></h2>
  <p class="lead">읽은 자료를 <code class="inl">raw/</code>에 넣으면 AI가 <code class="inl">wiki/</code>에 정리하고 이어 붙여요. 넣을수록 자라는 나만의 백과사전이 됩니다.</p>

  <h3>폴더 딱 두 개만 기억하세요</h3>
  <div class="twocol">
    <div class="box raw">
      <b>📥 raw/</b> 내가 넣는 곳
      <p class="muted" style="margin:6px 0 0">기사·PDF·이미지·메모 같은 <b>원본</b>을 그냥 던져 넣는 곳이에요. <code class="inl">/ingest</code> 하면 그 파일은 처리 완료 보관함(<code class="inl">ingested/</code>)으로 자동으로 옮겨갑니다. 그래서 raw엔 아직 처리 안 한 것만 남아요. (삭제가 아니라 이동이에요.)</p>
    </div>
    <div class="box wiki">
      <b>🧠 wiki/</b> AI가 채우는 곳
      <p class="muted" style="margin:6px 0 0">AI가 raw 자료를 읽어 정리하고 이어 붙여 만든 지식 페이지들이에요(인물·개념·요약·비교). 목차(index)와 기록(log)도 알아서 관리합니다.</p>
    </div>
  </div>
  <span class="pathex">내지식베이스/   (교훈 루프와 같은 폴더!)
├── raw/        ← 처리할 자료를 넣는 곳 (아직 ingest 안 된 것만 남음)
├── ingested/   ← /ingest 끝난 원본이 자동 보관됨 (삭제 아님)
├── debriefs/   ← 작업 교훈 일지 (Part A 교훈 루프가 관리)
└── wiki/       ← AI가 정리해서 채웁니다
    ├── entities/      (인물·회사·제품·기술)
    ├── concepts/      (개념·주제)
    ├── sources/       (원본 요약)
    ├── comparisons/   (질문에 대한 분석 저장)
    ├── index.md       (목차 — 항상 먼저 봄)
    └── log.md         (변경 기록)</span>

  <h3>raw 폴더 사용법</h3>
  <div class="card">
    <ul>
      <li><b>웹 기사</b>는 Obsidian <b>Web Clipper</b>(브라우저 확장)로 한 번 클릭하면 raw로 저장돼요.</li>
      <li><b>PDF·이미지·데이터</b>는 그냥 <code class="inl">raw/</code> 폴더에 끌어다 놓으면 됩니다.</li>
      <li>파일 이름은 <code class="inl">2026-06-11-기사제목.md</code>처럼 날짜로 시작하면 정리가 쉬워요(권장).</li>
    </ul>
    <span class="muted">raw에 넣기만 하면 끝이에요. 정리는 다음 <code class="inl">/ingest</code> 한 번으로 AI가 합니다.</span>
  </div>

  <h3>명령은 딱 세 개</h3>
  <div class="card">
    <div class="cmd"><span class="tag">/ingest</span><div><b>자료 넣기</b><br><span class="muted">raw에 넣은 자료를 위키로 정리해요. 관련 페이지를 한꺼번에 갱신하고 기록을 남깁니다. 내용이 충돌하면 ⚠️로 표시하고요. 처리한 원본은 raw에서 <code class="inl">ingested/</code>로 옮겨 둬서, 뭐가 처리됐는지 한눈에 보입니다(삭제 아님).</span><br><span class="muted">예) <code class="inl">raw/2026-06-11-기사.md 를 /ingest 해줘</code></span></div></div>
    <hr class="sep" style="margin:16px 0">
    <div class="cmd"><span class="tag">/query</span><div><b>물어보기</b><br><span class="muted">위키를 근거로 답해요. 어느 페이지에서 나왔는지 알려주고, 쓸 만한 답은 위키에 저장할지 물어봅니다.</span><br><span class="muted">예) <code class="inl">/query GPT-5가 시장에 줄 영향 정리해줘</code></span></div></div>
    <hr class="sep" style="margin:16px 0">
    <div class="cmd"><span class="tag">/lint</span><div><b>점검(주 1회)</b><br><span class="muted">모순·외톨이 페이지·빠진 연결·오래된 내용을 찾아 보여줘요. 그중 승인한 것만 고칩니다. "다음에 조사할 주제"도 제안하고요.</span><br><span class="muted">예) <code class="inl">/lint</code>, 교훈 루프 점검하는 날 같이 돌리면 좋아요.</span></div></div>
  </div>
  <div class="callout info">셋 다 <b>사람이 통제</b>해요. AI가 멋대로 지우거나 바꾸지 않고, 정리한 내용을 보여준 다음에 진행합니다. (교훈 루프의 '승인 게이트'와 같은 방식이에요.)</div>

  <h3>'나만의 사서'에 비유하면</h3>
  <div class="card">
    <p>이 위키는 <b>나만을 위해 일하는 도서관 사서</b>를 한 명 두는 것과 같아요. 세 명령이 곧 사서가 하는 일입니다.</p>
    <ul>
      <li><b>📥 raw/ = 반납함.</b> 읽을거리를 일단 쌓아두는 책 더미예요. 아직 정리 전이고요.</li>
      <li><b>🗂️ /ingest = 사서가 읽고 꽂기.</b> 내용을 읽어 주제별 서가에 분류하고, 핵심을 요약 카드로 만들어 둬요. 책 한 권을 읽으면 관련된 여러 칸의 카드가 한꺼번에 갱신됩니다.</li>
      <li><b>🧠 wiki/ = 잘 정리된 서가.</b> 주제별 카드가 서로 연결돼 꽂혀 있는 곳이에요. 넣을수록 두꺼워집니다.</li>
      <li><b>❓ /query = 사서에게 물어보기.</b> "이 주제 정리해줘" 하면 서가를 뒤져 종합해 답해요. 인터넷 검색이 아니라 <b>내가 모아둔 것</b>이 기준입니다.</li>
      <li><b>🧹 /lint = 서가 주기 점검.</b> 사서가 가끔 서가를 돌며 중복·모순·낡은 카드를 찾아 "이거 정리할까요?" 하고 물어봐요.</li>
    </ul>
    <p class="muted">일반 AI 채팅에 파일을 매번 올리는 건 <b>복사기 옆 아르바이트</b> 같아요. 그때그때 찾아주지만 끝나면 다 잊죠. 위키는 <b>전속 사서</b>라 읽은 걸 계속 쌓아 둡니다. 그래서 쓸수록 똑똑해져요.</p>
  </div>

  <div class="steps">
    <div class="stepblock">
      <h3>위키 설치 스크립트 실행</h3>
      <p>맨 위 한 줄(지식 베이스 폴더 경로)만 본인 <b>전체 경로</b>로 바꾼 뒤 실행하세요. <span class="muted">(Part A를 이미 설치했으면 이 줄은 무시되고 <b>같은 폴더</b>를 자동으로 씁니다.)</span> <code class="inl">~</code> 로 시작하면 안 되고, 안 바꾸면 스크립트가 알려주고 멈춥니다.</p>
      <div class="only-mac"><div class="callout">아래 <b>다운로드</b> → <code class="inl">.command</code> 더블클릭(차단 시 우클릭→"열기"), 또는 <b>복사</b> → 터미널에 붙여넣기.</div></div>
      <div class="only-win"><div class="callout">아래 <b>복사</b> → PowerShell에 붙여넣고 Enter. (막히면 <code class="inl">Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned</code> 먼저)</div></div>
      <p class="muted">💡 데스크탑 앱만 쓰는 분은 Code 탭의 <b>통합 터미널</b>(<code class="inl">Ctrl+`</code>)에 붙여넣어도 됩니다.</p>
      __INSTALLERS_WIKI__
    </div>

    <div class="stepblock">
      <h3>첫 자료, '나' 프로필부터 만들기</h3>
      <p>raw에 뭘 넣을지 막막하면 <b>'나' 프로필</b>을 첫 자료로 만드세요. 만드는 방법은 <b>당신이 Claude를 어디서 써왔는지</b>에 따라 갈립니다. 어느 쪽이든 결과를 복사해 <code class="inl">raw/about-me.md</code> 로 저장하면 됩니다.</p>
      <div class="callout info">🧭 <b>나는 어느 쪽일까?</b><br>
      · <b>Claude Desktop 일반 대화(Chat)만</b> 써왔다 / 잘 모르겠다 → <b>B안(추천)</b>. Claude는 당신을 거의 기억하지 못하므로, 자료를 직접 줘서 정리시킵니다.<br>
      · <b>Code 탭(Local)</b>이나 <b>메모리를 켠 claude.ai</b>를 오래 써왔다 → A안도 좋습니다. Claude가 이미 가진 기억을 끌어냅니다.</div>
      <div class="filecard">
        <div class="fhead">
          <div class="fmeta"><span class="fname">B안 · 자료를 주고 정리시키기</span><span class="badge b-both">누구나 · 추천</span></div>
          <div class="factions"><button class="btn" onclick="copyFile('selfprompt-b', this)">복사</button></div>
        </div>
        <p class="fdesc">이력서·소개글, 최근 업무 문서·회의록, 인상 깊었던 Claude 대화 캡처 같은 <b>본인 자료를 붙여넣어</b> 정리시키는 방식이에요. 환경이나 기억과 상관없이 누구나 되고, 준 자료에만 근거하니 <b>지어낼 위험이 없습니다.</b></p>
        <pre class="code" id="code-selfprompt-b"></pre>
        <script type="text/plain" id="src-selfprompt-b">아래에 내가 붙여넣는 자료들을 근거로 '나'에 대한 프로필을 마크다운으로 정리해줘.

- 근거 있는 것만: 내가 준 자료에 실제로 있는 내용만 써. 추측하거나 지어내지 말고, 자료에 없는 항목은 '(확인 필요)'로 비워둬.
- 구성: 다음 소제목으로 나눠줘
   ① 기본 프로필(역할·관심사)
   ② 주로 해온 업무·프로젝트
   ③ 일하는 방식·선호(도구, 규칙, 스타일)
   ④ 반복되는 의사결정 패턴
   ⑤ 진행 중이거나 미해결인 것
- 형식: 복붙해서 파일로 저장할 거니까 순수 마크다운으로. 맨 위에 제목과 "출처: 본인 제공 자료, (날짜)"를 적어줘.

--- 여기부터 내 자료 ---
(이력서·소개글·업무 문서·회의록·메모·대화 캡처 등을 여기에 붙여넣으세요)</script>
      </div>
      <div class="filecard">
        <div class="fhead">
          <div class="fmeta"><span class="fname">A안 · Claude의 기억에서 끌어내기</span><span class="badge b-mac">기억 기반</span></div>
          <div class="factions"><button class="btn" onclick="copyFile('selfprompt-a', this)">복사</button></div>
        </div>
        <p class="fdesc">Code 탭(Local)에서 위키 폴더를 열고 쓰거나, 메모리를 켠 claude.ai에서 쓰세요. Code 탭이라면 CLAUDE.md·메모리 파일이 근거가 됩니다.</p>
        <p class="fmust">빈 새 채팅(메모리 OFF)에서는 하지 마세요. Claude가 모르는 걸 그럴듯하게 지어내, 사실이 아닌 내용이 위키에 박힙니다. 그런 경우엔 위 B안을 쓰세요.</p>
        <pre class="code" id="code-selfprompt-a"></pre>
        <script type="text/plain" id="src-selfprompt-a">내 LLM 위키의 기초 자료를 만들려고 해. 아래 조건으로 '나'에 대한 프로필을 마크다운으로 정리해줘.

- 근거 있는 것만: 우리의 실제 대화 기록·메모리, (Claude Code라면) CLAUDE.md와 메모리 파일에 실제로 있는 내용만 써. 추측하거나 지어내지 말고, 근거가 없는 항목은 '(확인 필요)'로 비워둬.
- 출처 표시: 각 항목 끝에 근거를 괄호로 — (메모리) / (예전 대화) / (CLAUDE.md 등 파일) / (추론).
- 구성: 다음 소제목으로 나눠줘
   ① 기본 프로필(역할·관심사)
   ② 주로 해온 업무·프로젝트
   ③ 일하는 방식·선호(도구, 규칙, 스타일)
   ④ 반복되는 의사결정 패턴
   ⑤ 진행 중이거나 미해결인 것
- 형식: 복붙해서 파일로 저장할 거니까 순수 마크다운으로. 맨 위에 제목과 "출처: Claude 기억 추출, (날짜)"를 적어줘.</script>
      </div>
      <p class="muted">답변에 <b>(확인 필요)</b>가 남아 있으면 그대로 저장하세요. 나중에 실제 자료로 채우면 됩니다. 이렇게 만든 <code class="inl">about-me.md</code>가 위키의 '나' 엔티티가 돼요.</p>
    </div>

    <div class="stepblock">
      <h3>첫 사용</h3>
      <ol>
        <li>Claude Code(또는 데스크탑 앱 <b>Code 탭 · Local</b>)를 <b>위키 폴더</b>로 엽니다.</li>
        <li><code class="inl">raw/</code> 에 자료를 하나 넣어요. <b>처음이라면 위에서 만든 <code class="inl">about-me.md</code></b>, 그다음부터는 기사·PDF 뭐든 좋습니다.</li>
        <li><code class="inl">/ingest</code> 실행 → AI가 <code class="inl">wiki/</code>에 정리합니다. 결과를 확인하세요.</li>
        <li>궁금한 걸 <code class="inl">/query</code> 로 물어보고, 일주일에 한 번 <code class="inl">/lint</code> 로 점검합니다.</li>
      </ol>
      <div class="callout warn">⚠️ 반드시 <b>Code 탭 + 내 컴퓨터(Local)</b>에서, 위키 폴더를 열고 사용하세요. (Chat 탭·클라우드(Remote)에서는 폴더 파일을 못 다룹니다.)</div>
    </div>
  </div>

  <hr class="sep">

  <h3>실제로 이렇게 씁니다</h3>
  <p class="muted">설치를 마쳤으면, 평소엔 이런 식으로 써먹습니다.</p>
  <div class="card">
    <b>💬 팀 Slack 대화를 지식으로 (자동 수집)</b>
    <p class="muted" style="margin:6px 0 8px">중요한 논의·결정이 Slack에 묻혀 사라지는 걸 막는 흐름. 채널 대화를 위키로 끌어와 쌓습니다. <b>'나만의 사서'에게 매일 Slack을 읽혀 두는 것</b>과 같아요.</p>
    <p style="margin:0 0 4px"><b>먼저, Slack 커넥터를 한 번 연결</b> <span class="muted">(앞의 'MCP 연결' 방식)</span></p>
    <ul style="margin-top:4px">
      <li>claude.ai나 Claude Desktop에서 <b>설정 → 커넥터(Connectors)</b> → <b>Slack</b> 검색 → <b>연결</b>(Slack 로그인·권한 승인). <span class="muted">워크스페이스에 따라 Pro 이상이거나 관리자 승인이 필요할 수 있어요.</span></li>
      <li>연결되면 <b>Code 탭(Local)</b>에서도 Slack 도구가 잡힙니다. <span class="muted">안 보이면 Claude Code를 새 세션으로 다시 열거나, 설정에서 커넥터 연결을 한 번 더 확인하세요.</span></li>
    </ul>
    <p style="margin:10px 0 4px"><b>그다음, 모아서 위키로</b></p>
    <ul style="margin-top:4px">
      <li><b>수집.</b> Code 탭에서 이렇게 시켜요. "어제 <code class="inl">#채널A·#채널B</code>의 메시지와 스레드를 전부 가져와 <code class="inl">raw/slack/2026-06-15-채널A.md</code>처럼 채널별로 저장해줘" (날짜는 어제, 한국시간 기준)</li>
      <li><b>정리.</b> <code class="inl">/ingest</code> 하면 <code class="inl">wiki/entities/사람.md</code>·<code class="inl">wiki/concepts/논의주제.md</code> 에 쌓이고, 핵심 결정은 기록으로 남아요.</li>
      <li><b>묻기.</b> <code class="inl">/query</code> "지난주 우리 팀 주요 결정 5가지랑 그 맥락 정리해줘"</li>
    </ul>
    <p style="margin:10px 0 4px"><b>(선택) 한 줄 명령으로 만들기</b> <code class="inl">/slack-digest</code></p>
    <p class="muted" style="margin:4px 0">매번 프롬프트 치기 번거로우면, 아래 <b>개별 파일</b>에서 <code class="inl">slack-digest-SKILL.md</code>·<code class="inl">channels.txt</code>를 받아 두고 Claude에게 설치를 맡기세요. Code 탭(Local)에서 이렇게요.</p>
    <div class="callout">"받아둔 <code class="inl">slack-digest-SKILL.md</code>와 <code class="inl">channels.txt</code>를 참고해서 <code class="inl">~/.claude/skills/slack-digest/</code>에 slack-digest 스킬을 설치해줘 (스킬 파일은 <code class="inl">SKILL.md</code>로 저장)."</div>
    <p class="muted" style="margin:4px 0 0">설치하고 나면 세 가지를 꼭 챙기세요.
      <br>· <b>새 세션으로 다시 열기.</b> 스킬은 세션 시작 때 로드돼서, 설치 직후엔 안 보입니다. Claude Code를 새로 열어야 <code class="inl">/slack-digest</code>가 떠요.
      <br>· <b>Slack 커넥터가 연결돼 있어야</b> 동작합니다(맨 위에서 연결한 그거예요).
      <br>· <code class="inl">channels.txt</code>에 <b>본인 채널 ID</b>를 채워 두세요.
      <br>이러면 <code class="inl">/slack-digest</code> 한 줄로 어제치가 <code class="inl">raw/slack/</code>에 떨어집니다. (Gmail·캘린더 같은 다른 커넥터도 같은 식으로 나만의 명령을 만들 수 있어요.)</p>
  </div>
  <div class="card">
    <b>🍷 취미·관심사 깊이 파기</b>
    <p class="muted" style="margin:6px 0 8px">와인·커피·러닝화·여행지… 블로그 글, 유튜브 자막, 후기를 raw에 모읍니다.</p>
    <ul>
      <li><b>넣기.</b> "이 와인 리뷰 정리해줘" 하면 <code class="inl">wiki/concepts/내추럴와인.md</code>, <code class="inl">wiki/entities/생산자이름.md</code> 가 자동으로 갱신돼요.</li>
      <li><b>묻기.</b> "지금까지 모은 것 중 2만 원대 데일리 와인을 비교표로 만들어줘"</li>
    </ul>
  </div>
  <div class="card">
    <b>💼 흩어진 업무 자료 한곳에</b>
    <p class="muted" style="margin:6px 0 8px">회의록·이메일·기획안·참고 자료를 프로젝트별로 raw에 넣습니다.</p>
    <ul>
      <li><b>넣기.</b> "이번 주 회의록 ingest" 하면 <code class="inl">wiki/entities/거래처.md</code>, <code class="inl">wiki/concepts/이번분기목표.md</code> 에 쌓여요.</li>
      <li><b>묻기.</b> "A 프로젝트 지금까지의 결정사항과 남은 과제를 타임라인으로 정리해줘"</li>
      <li><b>점검.</b> 주 1회 <code class="inl">/lint</code>로 "서로 어긋난 결정"이나 "빠진 후속조치"를 잡아냅니다.</li>
    </ul>
  </div>
  <div class="card">
    <b>📈 투자 종목 추적</b>
    <p class="muted" style="margin:6px 0 8px">증권사 리포트 PDF, 공시, 뉴스, 실적 자료를 종목별로 raw에 모읍니다.</p>
    <ul>
      <li><b>넣기.</b> "삼성전자 1분기 실적자료 ingest" 하면 <code class="inl">wiki/entities/삼성전자.md</code> 에 실적 추이·컨센서스 갭이 쌓여요.</li>
      <li><b>묻기.</b> "내 5종목의 최근 3개월 주요 이벤트를 타임라인으로 만들어줘"</li>
      <li><b>점검.</b> <code class="inl">/lint</code>가 "내가 아직 안 챙긴 새 이슈"를 짚어 줍니다.</li>
    </ul>
  </div>
  <p class="muted">공통점은 이거예요. <b>나는 자료를 모으고 좋은 질문만</b> 하고, <b>분류·연결·요약은 AI가</b> 합니다. 몇 달 모으면 "살아 있는 나만의 백과사전"이 돼요. (공부·자격증 노트, 육아·건강 정보까지 무엇이든 같은 방식입니다.)</p>

  <hr class="sep">

  <h2>주간 정비는 한 자리에서</h2>
  <p>둘 다 설치했다면, 금요일 알림이 오는 날 <b>한 자리에서</b> 정비하세요. 같은 '사람이 승인하는' 리듬입니다.</p>
  <div class="card">
    <ul>
      <li><code class="inl">/weekly-retro</code> 로 반복된 <b>교훈</b>을 영구 규칙으로 올려요(승인/기각).</li>
      <li><code class="inl">/lint</code> 로 <b>위키</b>의 모순·외톨이 페이지·낡은 내용을 점검합니다(승인한 것만 수정).</li>
      <li><code class="inl">/loop-status</code> 로 둘 다 잘 돌고 있는지 대시보드로 확인하고요.</li>
    </ul>
    <span class="muted">교훈(주관적·암묵지)과 위키(출처 있는 지식)는 <b>한 폴더 안에서도 섞지 않고</b> 따로 둡니다. 성격이 다른 지식이라서요.</span>
  </div>

  <hr class="sep">

  <h2>개별 파일 (수동 설치용)</h2>
  <p class="muted">위 자동 설치 스크립트가 아래 파일들을 알아서 만들어 줍니다. 직접 살펴보거나 수동으로 설치하고 싶을 때만 사용하세요.
  배지의 <span class="pill">교훈루프</span>·<span class="pill">위키</span> 로 어느 쪽 파일인지 구분됩니다. 스킬은 각각 <code class="inl">~/.claude/skills/(이름)/SKILL.md</code> 로,
  위키 <code class="inl">CLAUDE.md</code>는 위키 폴더 맨 위에, <code class="inl">CLAUDE-snippet.md</code>는 전역 <code class="inl">~/.claude/CLAUDE.md</code> 맨 아래에 둡니다.
  <span class="only-mac">아래는 <span class="pill">Mac</span> 및 <span class="pill">공통</span> 파일입니다.</span>
  <span class="only-win">아래는 <span class="pill">Windows</span> 및 <span class="pill">공통</span> 파일입니다.</span></p>
  __INDIVIDUAL__

  <hr class="sep">

  <h2>자주 묻는 질문 (FAQ)</h2>
  <details>
    <summary>교훈 루프(Part A)랑 지식 위키(Part B), 뭐가 다른가요?</summary>
    <p>교훈 루프는 <b>내가 일하며 얻은 교훈</b>을 쌓아 같은 실수를 막아요. 지식 위키는 <b>내가 읽고 모으는 외부 지식</b>을 쌓고요. 같은 폴더에 있어도 <b>섞지는 않습니다</b>. 하나는 주관적 경험, 하나는 출처 있는 지식이라 성격이 다르거든요. 둘 다 "사람이 승인하고 AI가 정리한다"는 똑같은 방식으로 움직입니다.</p>
  </details>
  <details>
    <summary>꼭 둘 다 설치해야 하나요?</summary>
    <p>아니요. <b>Part A(교훈 루프)만</b> 써도 충분합니다. 읽은 자료까지 쌓고 싶을 때 Part B를 같은 폴더에 더하면 됩니다. 반대로 위키만 쓰고 싶어도 됩니다(설치 스크립트가 분리돼 있어요).</p>
  </details>
  <details>
    <summary>꼭 개발 지식이어야 하나요?</summary>
    <p>아니요. 업무 자료, 리서치, 관심 주제(예: 마케팅·투자·요리 레시피)도 똑같이 됩니다. raw에 넣고 /ingest 하면 됩니다.</p>
  </details>
  <details>
    <summary>실행이 막혀요 / 권한 오류가 나요</summary>
    <table class="faq">
      <tr><td><b class="only-mac">Mac</b><b class="only-win">Windows</b></td>
      <td><span class="only-mac"><code class="inl">.command</code> 더블클릭 시 "확인되지 않은 개발자" 경고가 뜨면, 파일을 <b>우클릭 → 열기</b>를 선택하세요. 한 번만 하면 됩니다.</span>
      <span class="only-win">PowerShell에서 스크립트 실행이 차단되면 먼저 <code class="inl">Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned</code> 를 실행하세요. 작업 스케줄러 등록이 실패하면 <b>PowerShell을 "관리자 권한으로 실행"</b>한 뒤 다시 시도하세요.</span></td></tr>
    </table>
  </details>
  <details class="only-mac">
    <summary>Mac에서 "python3가 필요합니다"라고 나와요</summary>
    <p>터미널에서 <code class="inl">xcode-select --install</code> 를 실행해 설치한 뒤, 설치 스크립트를 다시 실행하세요.</p>
  </details>
  <details>
    <summary>알림(팝업)이 안 떠요</summary>
    <p>알림은 보조 수단이에요. 안 떠도 괜찮습니다. 다음에 Claude Code를 열면 "리뷰 대기 후보가 있다"고 알려주거든요. <span class="only-mac">Mac은 시스템 설정 → 알림에서 권한을 확인할 수 있어요.</span></p>
  </details>
  <details>
    <summary>실행 요일/시간을 바꾸고 싶어요</summary>
    <p>설치 스크립트 맨 위의 시간 설정값을 바꾼 뒤 <b>다시 실행</b>하면 됩니다.
    <span class="only-mac"><code class="inl">RETRO_WEEKDAY</code>(1=월…5=금…7=일), <code class="inl">RETRO_HOUR</code>, <code class="inl">RETRO_MINUTE</code></span>
    <span class="only-win"><code class="inl">$RetroDay</code>(예: <code class="inl">'Monday'</code>), <code class="inl">$RetroHour</code>, <code class="inl">$RetroMinute</code></span> 값을 수정하세요.</p>
  </details>
  <details>
    <summary>raw 자료가 사라지거나 바뀌면요?</summary>
    <p>규약(CLAUDE.md)에 "AI는 raw를 절대 수정하지 않는다"가 박혀 있습니다. raw는 원본 보관소로만 쓰고, /ingest 후엔 <code class="inl">ingested/</code>로 <b>이동(삭제 아님)</b>되며, 정리물은 전부 wiki/에만 쌓입니다.</p>
  </details>
  <details>
    <summary>여러 사람이 쓰는데 안전한가요?</summary>
    <p>네. 규칙으로 '승격'하거나 위키를 고치는 건 <b>항상 당신이 직접 승인</b>해야만 일어납니다. 자동 점검은 후보를 '정리만' 할 뿐, 당신 허락 없이 바꾸지 않습니다.</p>
  </details>

  <details>
    <summary>설치한 걸 제거하려면? (되돌리기)</summary>
    <p class="muted">자동화와 스킬만 지웁니다. 폴더 안 <b>데이터(<code class="inl">debriefs/</code>·<code class="inl">raw/</code>·<code class="inl">wiki/</code>)는 그대로 남아요.</b></p>
    <div class="only-mac"><pre class="code"># 교훈 루프(Part A): 스케줄 + 스킬
launchctl bootout gui/$(id -u)/com.user.weekly-retro 2>/dev/null
rm -f ~/Library/LaunchAgents/com.user.weekly-retro.plist
rm -rf ~/.claude/skills/weekly-retro

# 위키(Part B)·공통 스킬
rm -rf ~/.claude/skills/ingest ~/.claude/skills/query ~/.claude/skills/lint \
       ~/.claude/skills/loop-status ~/.claude/skills/slack-digest</pre></div>
    <div class="only-win"><pre class="code"># 교훈 루프(Part A): 작업 + 스킬
Unregister-ScheduledTask -TaskName WeeklyRetro -Confirm:$false
Remove-Item "$env:USERPROFILE\.claude\skills\weekly-retro" -Recurse -Force

# 위키(Part B)·공통 스킬
"ingest","query","lint","loop-status","slack-digest" | ForEach-Object {
  Remove-Item "$env:USERPROFILE\.claude\skills\$_" -Recurse -Force -ErrorAction SilentlyContinue }</pre></div>
    <p class="muted"><code class="inl">~/.claude/settings.json</code>에 추가된 훅 한 줄과 전역 <code class="inl">CLAUDE.md</code> 아래쪽에 붙은 부분은 직접 지우면 됩니다. 데이터 폴더까지 없애려면 그 폴더를 직접 삭제하세요.</p>
  </details>

  <p class="muted" style="margin-top:40px">이 가이드는 self-contained HTML입니다. 그대로 다른 사람에게 보내도 모든 버튼이 동작합니다.</p>
</div>

<script>
  function fillAll() {
    document.querySelectorAll('pre.code[id^="code-"]').forEach(function(pre){
      var id = pre.id.replace('code-','');
      var src = document.getElementById('src-'+id);
      if (src) pre.textContent = src.textContent.replace(/^\n/,'');
    });
  }
  function srcText(id) {
    var src = document.getElementById('src-'+id);
    return src ? src.textContent.replace(/^\n/,'') : '';
  }
  function copyFile(id, btn) {
    navigator.clipboard.writeText(srcText(id)).then(function(){
      if(btn){ var t=btn.textContent; btn.textContent='복사됨!'; btn.classList.add('copied');
        setTimeout(function(){ btn.textContent=t; btn.classList.remove('copied'); },1400); }
    });
  }
  function downloadFile(id, filename) {
    var blob = new Blob([srcText(id)], {type:'text/plain;charset=utf-8'});
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url; a.download = filename; document.body.appendChild(a); a.click();
    document.body.removeChild(a); setTimeout(function(){ URL.revokeObjectURL(url); }, 1500);
  }
  function setOS(os) {
    document.body.dataset.os = os;
    document.getElementById('btn-mac').classList.toggle('active', os==='mac');
    document.getElementById('btn-win').classList.toggle('active', os==='win');
    document.getElementById('oshint').textContent = os==='mac' ? 'Mac 기준으로 표시 중' : 'Windows(PowerShell) 기준으로 표시 중';
    try { localStorage.setItem('wr-os', os); } catch(e) {}
  }
  fillAll();
  setOS((function(){ try { return localStorage.getItem('wr-os') || 'mac'; } catch(e) { return 'mac'; } })());
</script>
<style>
  body[data-os="mac"] .only-win { display:none !important; }
  body[data-os="win"] .only-mac { display:none !important; }
</style>
</body>
</html>
"""

HTMLDOC = (
    TEMPLATE.replace("__INSTALLERS_RETRO__", installers_retro)
    .replace("__INSTALLERS_WIKI__", installers_wiki)
    .replace("__INDIVIDUAL__", individual)
)

OUT = OUTDIR / "index.html"
OUT.write_text(HTMLDOC, encoding="utf-8")
print("WROTE", OUT, len(HTMLDOC.encode("utf-8")), "bytes")

# 구 llm-wiki.html → 합쳐진 페이지의 위키 섹션으로 리다이렉트
REDIRECT = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>이동합니다 — 지식 위키 가이드</title>
<link rel="canonical" href="./#wiki">
<meta http-equiv="refresh" content="0; url=./#wiki">
<script>location.replace("./#wiki");</script>
<style>body{font-family:-apple-system,"Apple SD Gothic Neo","Malgun Gothic",sans-serif;background:#f6f7fb;color:#1f2330;display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0}a{color:#0e9f6e}</style>
</head>
<body>
<p>가이드가 한 페이지로 합쳐졌습니다. 자동으로 이동하지 않으면 <a href="./#wiki">여기를 눌러</a> 이동하세요.</p>
</body>
</html>
"""
ROUT = OUTDIR / "llm-wiki.html"
ROUT.write_text(REDIRECT, encoding="utf-8")
print("WROTE", ROUT, len(REDIRECT.encode("utf-8")), "bytes (redirect)")
