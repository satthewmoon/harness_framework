#!/usr/bin/env bash
# PreToolUse hook — Bash 도구 실행 전 위험 명령어 패턴을 차단한다.
# Claude Code가 CLAUDE_TOOL_INPUT 환경변수로 도구 입력을 전달한다.

set -euo pipefail

# 입력 수집 (stdin JSON에서 command 필드 추출, 없으면 raw input으로 폴백)
RAW_INPUT=""
if [ ! -t 0 ]; then
    RAW_INPUT="$(cat 2>/dev/null || true)"
fi

# 입력 없으면 통과
if [ -z "$RAW_INPUT" ]; then
    exit 0
fi

# stdin JSON에서 tool_input.command 필드 추출 (Claude Code PreToolUse 형식)
INPUT=""
if command -v python3 >/dev/null 2>&1; then
    INPUT="$(echo "$RAW_INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    cmd = data.get('tool_input', {}).get('command', '')
    print(cmd)
except Exception:
    print('')
" 2>/dev/null || true)"
fi
# command 추출 실패 시 raw input으로 폴백 (하위 호환)
if [ -z "$INPUT" ]; then
    INPUT="$RAW_INPUT"
fi

# 차단 패턴 목록 (확장 정규식)
DANGEROUS_PATTERNS=(
    # 재귀 삭제 — 루트, 홈, 와일드카드, 현재 디렉토리, ${HOME} 중괄호 확장
    'rm[[:space:]]+-[rRfF]*r[fF]?[[:space:]]+(\/|~|\*|\$\{?HOME\}?|\.\.?(/|$))'
    'rm[[:space:]]+-[rRfF]*f[rR]?[[:space:]]+(\/|~|\*|\$\{?HOME\}?|\.\.?(/|$))'
    # 긴 옵션 형태 (--recursive --force) — 명령어 구분자를 넘지 않도록 [^;|&]* 사용
    'rm[[:space:]]+[^;|&]*(--recursive|--force)[^;|&]*[[:space:]]+(\/|~|\*|\$\{?HOME\}?|\.\.?(/|$))'
    # Git 위험 명령어
    'git[[:space:]]+push[[:space:]]+.*--force'
    'git[[:space:]]+push[[:space:]]+-f([[:space:]]|$)'
    'git[[:space:]]+reset[[:space:]]+--hard'
    'git[[:space:]]+clean[[:space:]]+-[fdxX]'
    'git[[:space:]]+branch[[:space:]]+-[Dd][[:space:]]+main'
    'git[[:space:]]+branch[[:space:]]+-[Dd][[:space:]]+master'
    # DB 파괴 명령어
    'DROP[[:space:]]+TABLE'
    'DROP[[:space:]]+DATABASE'
    'DROP[[:space:]]+SCHEMA'
    'TRUNCATE[[:space:]]+TABLE'
    # 파일 시스템 파괴
    'mkfs\.'
    'dd[[:space:]]+.*of=/dev/[sh]d'
    'dd[[:space:]]+.*of=/dev/nvme'
    # 권한 위험 — -R 777 / setuid(4xxx) / setgid(2xxx) / +s 비트
    'chmod[[:space:]]+-R[[:space:]]+[0-7]*7[0-7][0-7][[:space:]]+(\/|~|\*)'
    'chmod[[:space:]]+-R[[:space:]]+777'
    'chmod[[:space:]]+[0-9]*[46][0-7][0-7][0-7][[:space:]]'
    'chmod[[:space:]]+[ugoa]*[+]s'
    # 원격 스크립트 실행 (curl/wget pipe to shell)
    'curl[[:space:]]+.*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh'
    'wget[[:space:]]+.*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh'
    # Fork bomb
    ':\(\)[[:space:]]*\{[[:space:]]*:\|:&[[:space:]]*\}[[:space:]]*;[[:space:]]*:'
    # sudo 위험 조합
    'sudo[[:space:]]+rm[[:space:]]+-rf'
    'sudo[[:space:]]+dd'
)

MATCHED_PATTERN=""
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$INPUT" | grep -qiE "$pattern"; then
        MATCHED_PATTERN="$pattern"
        break
    fi
done

if [ -n "$MATCHED_PATTERN" ]; then
    echo "BLOCKED: 위험한 명령어 패턴이 감지되었습니다." >&2
    echo "패턴: $MATCHED_PATTERN" >&2
    echo "" >&2
    echo "이 명령어가 정말 필요하다면:" >&2
    echo "  1. 사용자에게 직접 확인받아야 합니다." >&2
    echo "  2. 사용자가 터미널에서 직접 실행해야 합니다." >&2
    exit 1
fi

exit 0
