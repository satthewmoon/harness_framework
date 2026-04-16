#!/usr/bin/env bash
# PreToolUse hook — Write/Edit 시 테스트 파일 존재 여부를 확인한다.
# 강제 차단이 아닌 경고. 실제 검증은 circuit-breaker.sh에서 수행.

set -uo pipefail

INPUT="${CLAUDE_TOOL_INPUT:-}"
if [ -z "$INPUT" ] && [ ! -t 0 ]; then
    INPUT="$(cat 2>/dev/null || true)"
fi

if [ -z "$INPUT" ]; then
    exit 0
fi

# JSON에서 file_path 추출
FILE_PATH=""
if command -v python3 >/dev/null 2>&1; then
    FILE_PATH="$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    # tool_input 래핑 또는 직접 접근
    obj = data.get('tool_input', data)
    print(obj.get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")"
fi

# 파일 경로 없으면 통과
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# 예외 파일: 테스트 파일 자체, 문서, 설정, 자동 생성 파일
case "$FILE_PATH" in
    # 테스트 파일 자체
    */tests/*|*/test_*.py|*_test.py|*/test_*.cpp|*_test.cpp|*/spec_*.py)
        exit 0
        ;;
    # 문서·설정·메타 파일
    *.md|*.txt|*.json|*.yaml|*.yml|*.toml|*.cfg|*.ini|*.env*|\
    *.gitignore|*requirements*.txt|*Makefile|*CMakeLists.txt|\
    *.clang-format|*.clang-tidy|*pyproject.toml|\
    */phases/*|*/.claude/*|*/.planning/*|*/docs/*|*/scripts/hooks/*)
        exit 0
        ;;
    # __init__.py, config.py 등 로직 없는 파일
    */__init__.py|*/config.py|*/settings.py|*/constants.py)
        exit 0
        ;;
esac

# src/ 또는 핵심 소스 파일에 한해 테스트 존재 여부 검사
if [[ "$FILE_PATH" =~ \.(py|cpp|cc|c|h|hpp)$ ]]; then
    PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    TESTS_DIR="$PROJECT_ROOT/tests"

    if [ ! -d "$TESTS_DIR" ]; then
        echo "TDD-GUARD: ⚠ tests/ 폴더가 없습니다." >&2
        echo "  → 소스 구현 전에 tests/ 폴더와 테스트 파일을 먼저 만드세요." >&2
        echo "  → 이 경고를 무시하면 circuit-breaker.sh가 step 완료를 막습니다." >&2
        # 경고만. exit 0으로 통과.
    else
        TEST_COUNT="$(find "$TESTS_DIR" -type f \( -name 'test_*.py' -o -name '*_test.py' -o -name 'test_*.cpp' \) 2>/dev/null | wc -l)"
        if [ "$TEST_COUNT" -eq 0 ]; then
            echo "TDD-GUARD: ⚠ tests/ 폴더에 테스트 파일이 없습니다." >&2
            echo "  → 이 step이 끝나기 전에 테스트를 추가하세요." >&2
        fi
    fi
fi

exit 0
