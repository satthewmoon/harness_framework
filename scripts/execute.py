#!/usr/bin/env python3
"""
Harness Step Executor — phase 내 step을 순차 실행하고 자가 교정한다.

Usage:
    python3 scripts/execute.py <phase-dir> [--push]
"""

import argparse
import contextlib
import json
import os
import subprocess
import sys
import threading
import time
import types
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parent.parent


@contextlib.contextmanager
def progress_indicator(label: str):
    """터미널 진행 표시기. with 문으로 사용하며 .elapsed 로 경과 시간을 읽는다."""
    frames = "◐◓◑◒"
    stop = threading.Event()
    t0 = time.monotonic()

    def _animate():
        idx = 0
        while not stop.wait(0.12):
            sec = int(time.monotonic() - t0)
            sys.stderr.write(f"\r{frames[idx % len(frames)]} {label} [{sec}s]")
            sys.stderr.flush()
            idx += 1
        sys.stderr.write("\r" + " " * (len(label) + 20) + "\r")
        sys.stderr.flush()

    th = threading.Thread(target=_animate, daemon=True)
    th.start()
    info = types.SimpleNamespace(elapsed=0.0)
    try:
        yield info
    finally:
        stop.set()
        th.join()
        info.elapsed = time.monotonic() - t0


class StepExecutor:
    """Phase 디렉토리 안의 step들을 순차 실행하는 하네스."""

    MAX_RETRIES = 3
    FEAT_MSG = "feat({phase}): step {num} — {name}"
    CHORE_MSG = "chore({phase}): step {num} output"
    TZ = timezone(timedelta(hours=9))

    def __init__(self, phase_dir_name: str, *, auto_push: bool = False):
        self._root = str(ROOT)
        self._phases_dir = ROOT / "phases"
        self._phase_dir = self._phases_dir / phase_dir_name
        self._phase_dir_name = phase_dir_name
        self._top_index_file = self._phases_dir / "index.json"
        self._auto_push = auto_push

        if not self._phase_dir.is_dir():
            print(f"ERROR: {self._phase_dir} not found")
            sys.exit(1)

        self._index_file = self._phase_dir / "index.json"
        if not self._index_file.exists():
            print(f"ERROR: {self._index_file} not found")
            sys.exit(1)

        idx = self._read_json(self._index_file)
        self._project = idx.get("project", "project")
        self._phase_name = idx.get("phase", phase_dir_name)
        self._total = len(idx["steps"])

    def run(self):
        self._print_header()
        self._check_blockers()
        self._validate_gitignore()
        self._checkout_branch()
        guardrails = self._load_guardrails()
        self._ensure_created_at()
        self._execute_all_steps(guardrails)
        self._finalize()

    # --- timestamps ---

    def _stamp(self) -> str:
        return datetime.now(self.TZ).strftime("%Y-%m-%dT%H:%M:%S%z")

    # --- JSON I/O ---

    @staticmethod
    def _read_json(p: Path) -> dict:
        return json.loads(p.read_text(encoding="utf-8"))

    @staticmethod
    def _write_json(p: Path, data: dict):
        p.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")

    # --- git ---

    def _run_git(self, *args) -> subprocess.CompletedProcess:
        cmd = ["git"] + list(args)
        return subprocess.run(cmd, cwd=self._root, capture_output=True, text=True)

    def _checkout_branch(self):
        branch = f"feat-{self._phase_name}"

        r = self._run_git("rev-parse", "--abbrev-ref", "HEAD")
        if r.returncode != 0:
            print(f"  ERROR: git을 사용할 수 없거나 git repo가 아닙니다.")
            print(f"  {r.stderr.strip()}")
            sys.exit(1)

        if r.stdout.strip() == branch:
            return

        r = self._run_git("rev-parse", "--verify", branch)
        r = self._run_git("checkout", branch) if r.returncode == 0 else self._run_git("checkout", "-b", branch)

        if r.returncode != 0:
            print(f"  ERROR: 브랜치 '{branch}' checkout 실패.")
            print(f"  {r.stderr.strip()}")
            print(f"  Hint: 변경사항을 stash하거나 commit한 후 다시 시도하세요.")
            sys.exit(1)

        print(f"  Branch: {branch}")

    def _commit_step(self, step_num: int, step_name: str):
        output_rel = f"phases/{self._phase_dir_name}/step{step_num}-output.json"
        index_rel = f"phases/{self._phase_dir_name}/index.json"

        self._run_git("add", "-A")
        self._run_git("reset", "HEAD", "--", output_rel)
        self._run_git("reset", "HEAD", "--", index_rel)

        if self._run_git("diff", "--cached", "--quiet").returncode != 0:
            msg = self.FEAT_MSG.format(phase=self._phase_name, num=step_num, name=step_name)
            r = self._run_git("commit", "-m", msg)
            if r.returncode == 0:
                print(f"  Commit: {msg}")
            else:
                print(f"  WARN: 코드 커밋 실패: {r.stderr.strip()}")

        self._run_git("add", "-A")
        if self._run_git("diff", "--cached", "--quiet").returncode != 0:
            msg = self.CHORE_MSG.format(phase=self._phase_name, num=step_num)
            r = self._run_git("commit", "-m", msg)
            if r.returncode != 0:
                print(f"  WARN: housekeeping 커밋 실패: {r.stderr.strip()}")

    # --- top-level index ---

    def _update_top_index(self, status: str):
        if not self._top_index_file.exists():
            return
        top = self._read_json(self._top_index_file)
        ts = self._stamp()
        for phase in top.get("phases", []):
            if phase.get("dir") == self._phase_dir_name:
                phase["status"] = status
                ts_key = {"completed": "completed_at", "error": "failed_at", "blocked": "blocked_at"}.get(status)
                if ts_key:
                    phase[ts_key] = ts
                break
        self._write_json(self._top_index_file, top)

    # --- guardrails & context ---

    def _load_guardrails(self) -> str:
        sections = []
        claude_md = ROOT / "CLAUDE.md"
        if claude_md.exists():
            text = claude_md.read_text()
            self._validate_no_placeholders(claude_md, text)
            sections.append(f"## 프로젝트 규칙 (CLAUDE.md)\n\n{text}")
        docs_dir = ROOT / "docs"
        if docs_dir.is_dir():
            for doc in sorted(docs_dir.glob("*.md")):
                sections.append(f"## {doc.stem}\n\n{doc.read_text()}")
        # decisions.md가 있으면 가드레일에 포함 (harness B단계 기록)
        decisions_file = self._phases_dir / "decisions.md"
        if decisions_file.exists():
            sections.append(f"## 프로젝트 결정 사항 (decisions.md)\n\n{decisions_file.read_text()}")
        return "\n\n---\n\n".join(sections) if sections else ""

    @staticmethod
    def _validate_no_placeholders(path: Path, text: str):
        """CLAUDE.md의 미치환 {placeholder}를 감지해 실행 전 경고한다."""
        import re
        # 코드 블록 안의 placeholder는 제외 (정상적인 예시 코드)
        # 마크다운 코드 블록 제거 후 검사
        stripped = re.sub(r'```[\s\S]*?```', '', text)
        stripped = re.sub(r'`[^`]*`', '', stripped)
        # 실제 placeholder 패턴: {영문/한글 변수명}
        unresolved = re.findall(r'\{(?!중괄호|예:|예시|N}|M}|\d)[가-힣A-Za-z_][가-힣A-Za-z0-9_ ]*\}', stripped)
        # 알려진 정상 패턴 제외
        known_ok = {"프로젝트 고유의 절대 규칙 — 없으면 이 섹션 삭제"}
        unresolved = [u for u in unresolved if u.strip("{}") not in known_ok]
        if unresolved:
            print(f"\n  ⚠ WARN: {path.name}에 미치환 placeholder가 있습니다: {unresolved[:5]}")
            print(f"  Hint: 프로젝트 CLAUDE.md의 {{프로젝트명}}, C7 등을 먼저 채우세요.")
            print(f"  계속 진행하려면 Enter를 누르세요. 중단하려면 Ctrl+C를 누르세요.")
            try:
                input()
            except (KeyboardInterrupt, EOFError):
                print("\n  실행 중단.")
                sys.exit(3)

    @staticmethod
    def _build_step_context(index: dict) -> str:
        lines = [
            f"- Step {s['step']} ({s['name']}): {s['summary']}"
            for s in index["steps"]
            if s["status"] == "completed" and s.get("summary")
        ]
        if not lines:
            return ""
        return "## 이전 Step 산출물\n\n" + "\n".join(lines) + "\n\n"

    @staticmethod
    def _normalize_error(msg: str) -> str:
        """에러 메시지 상위 3줄 정규화 — 경로·타임스탬프·PID 제거 후 fingerprint 생성 (ADR-015)."""
        import re
        lines = [ln.strip() for ln in (msg or "").splitlines()[:3]]
        normalized = []
        for ln in lines:
            ln = re.sub(r'/tmp/[\w/.-]+', '/tmp/X', ln)
            ln = re.sub(r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}[\w:.+-]*', 'TS', ln)
            ln = re.sub(r'\bpid[= ]\d+\b', 'pid=X', ln, flags=re.IGNORECASE)
            ln = re.sub(r'\s+', ' ', ln)
            normalized.append(ln)
        return '\n'.join(normalized)

    def _build_preamble(self, guardrails: str, step_context: str,
                        prev_error: Optional[str] = None,
                        strategy_section: str = "") -> str:
        commit_example = self.FEAT_MSG.format(
            phase=self._phase_name, num="N", name="<step-name>"
        )
        retry_section = ""
        if prev_error:
            retry_section = (
                f"\n## ⚠ 이전 시도 실패 — 아래 에러를 반드시 참고하여 수정하라\n\n"
                f"{prev_error}\n\n---\n\n"
            )
        return (
            f"당신은 {self._project} 프로젝트의 개발자입니다. 아래 step을 수행하세요.\n\n"
            f"{guardrails}\n\n---\n\n"
            f"{step_context}{strategy_section}{retry_section}"
            f"## 작업 규칙\n\n"
            f"1. 이전 step에서 작성된 코드를 확인하고 일관성을 유지하라.\n"
            f"2. 이 step에 명시된 작업만 수행하라. 추가 기능이나 파일을 만들지 마라.\n"
            f"3. 기존 테스트를 깨뜨리지 마라.\n"
            f"4. AC(Acceptance Criteria) 검증을 직접 실행하라.\n"
            f"5. /phases/{self._phase_dir_name}/index.json의 해당 step status를 업데이트하라:\n"
            f"   - AC 통과 → \"completed\" + \"summary\" 필드에 이 step의 산출물을 한 줄로 요약\n"
            f"   - {self.MAX_RETRIES}회 수정 시도 후에도 실패 → \"error\" + \"error_message\" 기록\n"
            f"   - 사용자 개입이 필요한 경우 (API 키, 인증, 수동 설정 등) → \"blocked\" + \"blocked_reason\" 기록 후 즉시 중단\n"
            f"6. 모든 변경사항을 커밋하라:\n"
            f"   {commit_example}\n\n---\n\n"
        )

    # --- Claude 호출 ---

    @staticmethod
    def _lint_step_file(path: Path) -> list[str]:
        """step.md의 자기완결성을 검사한다. 외부 참조나 필수 섹션 누락을 경고."""
        text = path.read_text()
        warnings = []
        # 외부 참조 패턴 탐지 (독립 세션에서 실행되므로 외부 참조 금지)
        forbidden_phrases = ["이전 대화", "아까 논의", "앞서 말한", "논의했듯이",
                             "앞에서 설명", "위에서 언급", "이전 세션"]
        for phrase in forbidden_phrases:
            if phrase in text:
                warnings.append(f"외부 참조 의심: '{phrase}' 발견 — 독립 세션에서 실행되므로 내용을 파일 안에 직접 기술하세요.")
        # 필수 섹션 검증
        required_sections = ["## 작업", "## Acceptance Criteria"]
        for section in required_sections:
            if section not in text:
                warnings.append(f"필수 섹션 누락: '{section}' — step.md에 반드시 포함되어야 합니다.")
        return warnings

    def _invoke_claude(self, step: dict, preamble: str) -> dict:
        step_num, step_name = step["step"], step["name"]
        step_file = self._phase_dir / f"step{step_num}.md"

        if not step_file.exists():
            print(f"  ERROR: {step_file} not found")
            sys.exit(1)

        # step.md 자기완결성 lint
        lint_warnings = self._lint_step_file(step_file)
        if lint_warnings:
            print(f"  ⚠ Step {step_num} ({step_name}) lint 경고:")
            for w in lint_warnings:
                print(f"    - {w}")

        prompt = preamble + step_file.read_text()
        try:
            result = subprocess.run(
                ["claude", "-p", "--dangerously-skip-permissions", "--output-format", "json", prompt],
                cwd=self._root, capture_output=True, text=True, timeout=1800,
            )
        except subprocess.TimeoutExpired:
            timeout_msg = "claude CLI 1800초(30분) 타임아웃 초과. step 범위가 너무 크거나 응답 없음."
            print(f"\n  ERROR: {timeout_msg}")
            output = {
                "step": step_num, "name": step_name,
                "exitCode": -1,
                "stdout": "", "stderr": timeout_msg,
            }
            out_path = self._phase_dir / f"step{step_num}-output.json"
            with open(out_path, "w") as f:
                json.dump(output, f, indent=2, ensure_ascii=False)
            return output

        if result.returncode != 0:
            print(f"\n  WARN: Claude가 비정상 종료됨 (code {result.returncode})")
            if result.stderr:
                print(f"  stderr: {result.stderr[:500]}")

        output = {
            "step": step_num, "name": step_name,
            "exitCode": result.returncode,
            "stdout": result.stdout, "stderr": result.stderr,
        }
        out_path = self._phase_dir / f"step{step_num}-output.json"
        with open(out_path, "w") as f:
            json.dump(output, f, indent=2, ensure_ascii=False)

        return output

    # --- 헤더 & 검증 ---

    def _print_header(self):
        print(f"\n{'='*60}")
        print(f"  Harness Step Executor")
        print(f"  Phase: {self._phase_name} | Steps: {self._total}")
        if self._auto_push:
            print(f"  Auto-push: enabled")
        print(f"{'='*60}")

    def _check_blockers(self):
        """error/blocked step이 있으면 즉시 중단. 전체 순회로 어떤 순서든 놓치지 않는다."""
        index = self._read_json(self._index_file)
        for s in index["steps"]:
            if s["status"] == "error":
                print(f"\n  ✗ Step {s['step']} ({s['name']}) failed.")
                print(f"  Error: {s.get('error_message', 'unknown')}")
                print(f"  Fix and reset status to 'pending' to retry.")
                sys.exit(1)
            if s["status"] == "blocked":
                print(f"\n  ⏸ Step {s['step']} ({s['name']}) blocked.")
                print(f"  Reason: {s.get('blocked_reason', 'unknown')}")
                print(f"  Resolve and reset status to 'pending' to retry.")
                sys.exit(2)

    def _validate_gitignore(self):
        """.env 파일이 존재하는데 .gitignore에 없으면 커밋 전에 경고하고 중단한다."""
        root = Path(self._root)
        env_file = root / ".env"
        gitignore = root / ".gitignore"
        if not env_file.exists():
            return
        if not gitignore.exists():
            print("\n  ERROR: .env 파일이 있지만 .gitignore가 없습니다.")
            print("  .gitignore를 생성하고 '.env'를 포함하세요. git add -A 시 .env가 커밋됩니다.")
            sys.exit(1)
        if ".env" not in gitignore.read_text():
            print("\n  ERROR: .env 파일이 있지만 .gitignore에 '.env'가 포함되지 않았습니다.")
            print("  .gitignore에 '.env'를 추가한 뒤 다시 실행하세요.")
            sys.exit(1)

    def _ensure_created_at(self):
        index = self._read_json(self._index_file)
        if "created_at" not in index:
            index["created_at"] = self._stamp()
            self._write_json(self._index_file, index)

    # --- 실행 루프 ---

    def _execute_single_step(self, step: dict, guardrails: str) -> bool:
        """단일 step 실행 (재시도 + 동일 에러 감지 포함). 완료되면 True, 실패/차단이면 False.

        동일 에러 감지 정책 (ADR-015):
          - 에러 메시지 상위 3줄을 정규화해 fingerprint 비교.
          - 동일 에러 2회 연속 → "전략 변경 필수" preamble 주입.
          - 동일 에러 3회 연속 → status: blocked 전환 후 sys.exit(2).
          - 60초 이내 즉시 실패는 재시도 카운트 미집계 (전략 탐색 허용).
        """
        step_num, step_name = step["step"], step["name"]
        done = sum(1 for s in self._read_json(self._index_file)["steps"] if s["status"] == "completed")
        prev_error: Optional[str] = None
        prev_fingerprint: Optional[str] = None
        repeat_count = 0

        # blocked 복구 시 에러 history를 프롬프트에 전달
        existing_step = next((s for s in self._read_json(self._index_file)["steps"] if s["step"] == step_num), {})
        prior_history = existing_step.get("error_history", [])

        for attempt in range(1, self.MAX_RETRIES + 1):
            index = self._read_json(self._index_file)
            step_context = self._build_step_context(index)

            # 동일 에러 2회 이상이면 "전략 변경 필수" 섹션을 preamble에 추가 (ADR-015)
            strategy_section = ""
            if prev_error and repeat_count >= 2:
                strategy_section = (
                    f"\n## ⚠ 반복 에러 감지 — 전략을 변경하라 (동일 에러 {repeat_count}회)\n\n"
                    f"이전 {repeat_count}회 시도가 같은 에러로 실패했다. 단순 재시도는 동일 결과를 낳는다.\n"
                    f"다음 중 하나를 반드시 선택하라:\n\n"
                    f"1. 문제 원인을 재분석하라 — 전제가 틀렸을 가능성이 높다.\n"
                    f"2. 다른 라이브러리·API·접근법을 시도하라.\n"
                    f"3. venv 활성화 상태를 확인하라 (ModuleNotFoundError 유형 시).\n"
                    f"4. step 범위가 너무 크면 blocked로 전환하고 사용자에게 step 재설계를 요청하라.\n\n"
                    f"반복 에러 요약:\n{prev_error[:500]}\n\n---\n\n"
                )

            # 이전 실패 이력이 있으면 preamble에 포함 (blocked 복구 후 재시도 시)
            history_section = ""
            if prior_history and attempt == 1:
                history_lines = "\n".join(
                    f"  - 시도 {h['attempt']} ({h['timestamp']}): {h['error'][:200]}"
                    for h in prior_history[-3:]  # 최근 3개만
                )
                history_section = (
                    f"\n## ⚠ 이전 실패 이력 (blocked 복구 후 재시도)\n\n"
                    f"이 step은 이전에 아래 에러로 blocked되었습니다. 같은 실수를 반복하지 마세요:\n\n"
                    f"{history_lines}\n\n---\n\n"
                )
                strategy_section = history_section + strategy_section

            preamble = self._build_preamble(guardrails, step_context, prev_error, strategy_section)

            tag = f"Step {step_num}/{self._total - 1} ({done} done): {step_name}"
            if attempt > 1:
                tag += f" [retry {attempt}/{self.MAX_RETRIES}]"
            if repeat_count >= 2:
                tag += f" [동일에러 {repeat_count}회→전략변경]"

            t_start = time.monotonic()
            with progress_indicator(tag) as pi:
                self._invoke_claude(step, preamble)
            elapsed = int(pi.elapsed)  # with 블록 종료 후 finally에서 설정됨

            # 60초 이내 즉시 실패 → 재시도 카운트 미집계 (ADR-015)
            fast_fail = (time.monotonic() - t_start) < 60

            index = self._read_json(self._index_file)
            status = next((s.get("status", "pending") for s in index["steps"] if s["step"] == step_num), "pending")
            ts = self._stamp()

            if status == "completed":
                summary = next((s.get("summary", "") for s in index["steps"] if s["step"] == step_num), "")
                if not summary.strip():
                    print(f"  ⚠ Step {step_num}: summary 누락 — 다음 step 컨텍스트 전달 불가")
                for s in index["steps"]:
                    if s["step"] == step_num:
                        s["completed_at"] = ts
                self._write_json(self._index_file, index)
                self._commit_step(step_num, step_name)
                print(f"  ✓ Step {step_num}: {step_name} [{elapsed}s]")
                return True

            if status == "blocked":
                for s in index["steps"]:
                    if s["step"] == step_num:
                        s["blocked_at"] = ts
                self._write_json(self._index_file, index)
                reason = next((s.get("blocked_reason", "") for s in index["steps"] if s["step"] == step_num), "")
                print(f"  ⏸ Step {step_num}: {step_name} blocked [{elapsed}s]")
                print(f"    Reason: {reason}")
                self._update_top_index("blocked")
                sys.exit(2)

            err_msg = next(
                (s.get("error_message", "Step did not update status") for s in index["steps"] if s["step"] == step_num),
                "Step did not update status",
            )

            # 동일 에러 fingerprint 비교 (ADR-015)
            # fast_fail 시에는 fingerprint/repeat_count 모두 갱신 안 함 — 탐색 허용
            current_fingerprint = self._normalize_error(err_msg)
            if not fast_fail:
                if current_fingerprint == prev_fingerprint:
                    repeat_count += 1
                else:
                    repeat_count = 1
                prev_fingerprint = current_fingerprint

            # 동일 에러 3회 이상 → blocked 강제 전환 (ADR-015)
            if repeat_count >= 3:
                for s in index["steps"]:
                    if s["step"] == step_num:
                        s["status"] = "blocked"
                        s["blocked_at"] = ts
                        s["blocked_reason"] = (
                            f"동일 에러 {repeat_count}회 반복: {err_msg[:300]}. 사용자 개입 필요."
                        )
                        # 에러 history 유지 — blocked 복구 시 같은 실수 반복 방지
                        history_entry = {"attempt": attempt, "error": err_msg[:500], "timestamp": ts}
                        s.setdefault("error_history", []).append(history_entry)
                        s.pop("error_message", None)
                self._write_json(self._index_file, index)
                self._commit_step(step_num, step_name)
                print(f"  ⏸ Step {step_num}: blocked (동일 에러 {repeat_count}회) [{elapsed}s]")
                print(f"    Reason: {err_msg[:200]}")
                self._update_top_index("blocked")
                sys.exit(2)

            if attempt < self.MAX_RETRIES:
                for s in index["steps"]:
                    if s["step"] == step_num:
                        s["status"] = "pending"
                        s.pop("error_message", None)
                self._write_json(self._index_file, index)
                prev_error = err_msg
                fast_tag = " [fast-fail, 카운트 미집계]" if fast_fail else ""
                print(f"  ↻ Step {step_num}: retry {attempt}/{self.MAX_RETRIES} — {err_msg}{fast_tag}")
            else:
                for s in index["steps"]:
                    if s["step"] == step_num:
                        s["status"] = "error"
                        s["error_message"] = f"[{self.MAX_RETRIES}회 시도 후 실패] {err_msg}"
                        s["failed_at"] = ts
                self._write_json(self._index_file, index)
                self._commit_step(step_num, step_name)
                print(f"  ✗ Step {step_num}: {step_name} failed after {self.MAX_RETRIES} attempts [{elapsed}s]")
                print(f"    Error: {err_msg}")
                self._update_top_index("error")
                sys.exit(1)

        return False  # unreachable

    def _execute_all_steps(self, guardrails: str):
        while True:
            index = self._read_json(self._index_file)
            pending = next((s for s in index["steps"] if s["status"] == "pending"), None)
            if pending is None:
                print("\n  All steps completed!")
                return

            step_num = pending["step"]
            for s in index["steps"]:
                if s["step"] == step_num and "started_at" not in s:
                    s["started_at"] = self._stamp()
                    self._write_json(self._index_file, index)
                    break

            self._execute_single_step(pending, guardrails)

    def _finalize(self):
        index = self._read_json(self._index_file)
        index["completed_at"] = self._stamp()
        self._write_json(self._index_file, index)
        self._update_top_index("completed")

        self._run_git("add", "-A")
        if self._run_git("diff", "--cached", "--quiet").returncode != 0:
            msg = f"chore({self._phase_name}): mark phase completed"
            r = self._run_git("commit", "-m", msg)
            if r.returncode == 0:
                print(f"  ✓ {msg}")

        if self._auto_push:
            branch = f"feat-{self._phase_name}"
            r = self._run_git("push", "-u", "origin", branch)
            if r.returncode != 0:
                print(f"\n  ERROR: git push 실패: {r.stderr.strip()}")
                sys.exit(1)
            print(f"  ✓ Pushed to origin/{branch}")

        print(f"\n{'='*60}")
        print(f"  Phase '{self._phase_name}' completed!")
        print(f"{'='*60}")


def main():
    parser = argparse.ArgumentParser(description="Harness Step Executor")
    parser.add_argument("phase_dir", help="Phase directory name (e.g. 0-mvp)")
    parser.add_argument("--push", action="store_true", help="Push branch after completion")
    args = parser.parse_args()

    StepExecutor(args.phase_dir, auto_push=args.push).run()


if __name__ == "__main__":
    main()
