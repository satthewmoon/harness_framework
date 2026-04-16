#!/usr/bin/env bash
# PreToolUse hook — Bash 도구 실행 전 위험 명령어 패턴을 차단한다.
# Claude Code가 CLAUDE_TOOL_INPUT 환경변수로 도구 입력을 전달한다.

set -euo pipefail

# 입력 수집 (환경변수 우선, 없으면 stdin)
INPUT="${CLAUDE_TOOL_INPUT:-}"
if [ -z "$INPUT" ] && [ ! -t 0 ]; then
    INPUT="$(cat 2>/dev/null || true)"
fi

# 입력 없으면 통과
if [ -z "$INPUT" ]; then
    exit 0
fi

# 차단 패턴 목록 (확장 정규식)
DANGEROUS_PATTERNS=(
    # 재귀 삭제 — 루트, 홈, 와일드카드
    'rm[[:space:]]+-[rRfF]*r[fF]?[[:space:]]+(\/|~|\*|\$HOME)'
    'rm[[:space:]]+-[rRfF]*f[rR]?[[:space:]]+(\/|~|\*|\$HOME)'
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
    # 권한 위험
    'chmod[[:space:]]+-R[[:space:]]+[0-7]*7[0-7][0-7][[:space:]]+(\/|~|\*)'
    'chmod[[:space:]]+-R[[:space:]]+777'
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
