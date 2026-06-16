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
            candidates.append(
                {
                    "category": cat,
                    "count": len(slot["files"]),
                    "major": slot["major"],
                    "recurring": recurring,
                    "evidence": slot["evidence"],
                }
            )
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
    lines.append(
        "> 자동 집계 결과입니다. Claude Code에서 `/weekly-retro` 를 실행해 "
        "건건이 승인/기각하세요. 승인한 것만 영구 규칙(CLAUDE.md)으로 올라갑니다.\n"
    )
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
            subprocess.run(
                [
                    "osascript",
                    "-e",
                    f'display notification "{message}" with title "{title}"',
                ],
                check=False,
                timeout=10,
            )
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
    (directory / f"리뷰 대기 — 주간 리트로 {today}.md").write_text(
        note, encoding="utf-8"
    )
    n = len(candidates)
    notify(
        "주간 리트로",
        (
            f"승격 후보 {n}건 대기 중 — /weekly-retro 로 검토하세요"
            if n
            else "이번 주 승격 후보 없음 👍"
        ),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
