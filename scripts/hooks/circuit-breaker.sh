#!/usr/bin/env bash
# Stop hook — Claude 세션 종료 직전 실행. 코드 품질·테스트·회귀 방지·보안을 자동 검증한다.
# Python 프로젝트와 C/C++ 프로젝트를 자동 감지하여 적절한 검증을 수행.
# 실패 시 exit 1로 Claude에게 수정을 요청한다.
#
# 참고 규칙: CLAUDE.md C1~C8, ADR-016, ADR-017

set -u  # set -e는 의도적으로 사용하지 않음: 개별 체크 실패 후 메시지 수집 필요

# Stop 훅: stdin(JSON)을 읽어 버려야 Claude Code가 정상 동작함 (동기 소비)
cat /dev/stdin > /dev/null 2>&1 || true

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT" || exit 1

# venv가 있으면 활성화 (ruff, pytest 등 로컬 도구 사용)
if [ -f "venv/bin/activate" ]; then
    # shellcheck disable=SC1091
    source venv/bin/activate
fi

FAIL=0
WARNINGS=()
ERRORS=()

# 세션별 임시 로그 파일 (경쟁 조건 방지)
CB_TMP="$(mktemp /tmp/cb-output.XXXXXX.log)"
trap 'rm -f "$CB_TMP"' EXIT

# ─────────────────────────────────────
# 헬퍼 함수
# ─────────────────────────────────────

run_check() {
    local name="$1"
    local is_required="$2"  # "required" or "optional"
    shift 2

    if "$@" >"$CB_TMP" 2>&1; then
        echo "  ✓ $name"
    else
        local output
        output="$(cat "$CB_TMP")"
        if [ "$is_required" = "required" ]; then
            echo "  ✗ $name [FAIL]"
            ERRORS+=("── $name ──")
            ERRORS+=("$output")
            ERRORS+=("")
            FAIL=1
        else
            echo "  ⚠ $name [경고, 계속]"
            WARNINGS+=("$name: $output")
        fi
    fi
}

tool_check() {
    local tool="$1"
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "  ⚠ $tool 미설치 — 스킵"
        return 1
    fi
    return 0
}

record_error() {
    local header="$1"
    shift
    ERRORS+=("── $header ──")
    for line in "$@"; do
        ERRORS+=("$line")
    done
    ERRORS+=("")
    FAIL=1
}

# pyproject.toml에서 coverage fail_under 읽기, 없으면 기본 70
read_coverage_threshold() {
    local default=70
    if [ ! -f "pyproject.toml" ]; then
        echo "$default"
        return
    fi
    local value
    value="$(python3 - <<'PY' 2>/dev/null
import sys
try:
    try:
        import tomllib          # Python 3.11+
    except ImportError:
        try:
            import tomli as tomllib  # type: ignore
        except ImportError:
            sys.exit(1)
    with open("pyproject.toml", "rb") as f:
        data = tomllib.load(f)
    threshold = data.get("tool", {}).get("coverage", {}).get("report", {}).get("fail_under")
    if threshold is None:
        sys.exit(1)
    print(int(threshold))
except Exception:
    sys.exit(1)
PY
)"
    if [ -z "$value" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# ─────────────────────────────────────
# 보안 기본 검사 (모든 프로젝트)
# ─────────────────────────────────────

echo ""
echo "▶ 보안 검사"

# .env가 git에 추적되는지 확인
if git ls-files --error-unmatch .env >/dev/null 2>&1; then
    echo "  ✗ .env 파일이 git에 추적되고 있습니다! [CRITICAL]"
    record_error "보안: .env git 추적" \
        ".env 파일을 즉시 git에서 제거하세요: git rm --cached .env"
else
    echo "  ✓ .env git 미추적 확인"
fi

# .env.example 존재 확인 (있어야 함)
if [ ! -f ".env.example" ] && [ -f ".env" ]; then
    echo "  ✗ .env.example이 없습니다. [FAIL]"
    record_error "보안: .env.example 누락" \
        ".env 파일이 있는데 .env.example이 없습니다." \
        "팀원이 어떤 환경변수가 필요한지 알 수 없습니다." \
        "해결: cat .env | cut -d= -f1 | sed 's/$/=/' > .env.example"
elif [ -f ".env" ] && [ -f ".env.example" ]; then
    # .env의 키가 .env.example에 모두 있는지 비교
    ENV_KEYS="$(grep -v '^#' .env 2>/dev/null | grep '=' | cut -d= -f1 | sort 2>/dev/null || true)"
    EXAMPLE_KEYS="$(grep -v '^#' .env.example 2>/dev/null | grep '=' | cut -d= -f1 | sort 2>/dev/null || true)"
    MISSING_IN_EXAMPLE="$(comm -23 <(echo "$ENV_KEYS") <(echo "$EXAMPLE_KEYS") 2>/dev/null || true)"
    if [ -n "$MISSING_IN_EXAMPLE" ]; then
        echo "  ⚠ .env.example에 없는 키: $MISSING_IN_EXAMPLE [경고]"
        WARNINGS+=(".env.example 키 누락: $MISSING_IN_EXAMPLE — .env.example을 최신화하세요.")
    else
        echo "  ✓ .env.example 키 동기화 확인"
    fi
fi

# .gitignore 필수 항목 검사 (ADR-006, C1)
if [ -f ".gitignore" ]; then
    MISSING_ENTRIES=()
    for entry in "venv/" ".env" "__pycache__/"; do
        if ! grep -qF "$entry" .gitignore 2>/dev/null; then
            MISSING_ENTRIES+=("$entry")
        fi
    done
    if [ "${#MISSING_ENTRIES[@]}" -gt 0 ]; then
        echo "  ✗ .gitignore 필수 항목 누락 [FAIL]"
        record_error ".gitignore 필수 항목 누락" \
            "누락된 항목: ${MISSING_ENTRIES[*]}" \
            "해결: 각 항목을 .gitignore에 추가하세요."
    else
        echo "  ✓ .gitignore 필수 항목 확인 (venv/, .env, __pycache__/)"
    fi
else
    echo "  ⚠ .gitignore 파일 없음 [경고]"
    WARNINGS+=(".gitignore 없음 — venv/, .env, __pycache__/ 를 포함하는 .gitignore 생성 권장")
fi

# ─────────────────────────────────────
# Python 프로젝트 감지 및 검사
# ─────────────────────────────────────

IS_PYTHON=false
# globstar 의존 금지 — find로 안전하게 탐지 (monorepo backend/ 폴더도 감지)
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "main.py" ] || \
   [ -f "backend/pyproject.toml" ] || [ -f "backend/requirements.txt" ] || \
   [ -n "$(find . -maxdepth 4 -name '*.py' \
       -not -path '*/venv/*' -not -path '*/.venv/*' \
       -not -path '*/node_modules/*' -not -path '*/__pycache__/*' \
       -print -quit 2>/dev/null)" ]; then
    IS_PYTHON=true
fi

if [ "$IS_PYTHON" = true ]; then
    echo ""
    echo "▶ Python 검사"

    # ─── 하드코딩된 시크릿 스캔 (C1, required) ───
    # tests/ 폴더는 mock 값이 많아 오탐이 크므로 제외
    if [ -d "src" ]; then
        SECRET_PATTERN='(api_key|password|token|secret|passwd)[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"']{6,}'
        SECRET_HITS="$(grep -rnE --include='*.py' "$SECRET_PATTERN" src/ 2>/dev/null \
            | grep -vE '(os\.getenv|os\.environ|getenv\(|config\.|settings\.|Field\(|#[[:space:]]*nosec)' \
            | grep -vE '/tests?/' \
            || true)"
        if [ -n "$SECRET_HITS" ]; then
            echo "  ✗ 하드코딩된 시크릿 감지 [FAIL]"
            record_error "하드코딩된 시크릿 (C1 위반)" \
                "src/에서 시크릿처럼 보이는 값을 발견했습니다. .env로 외부화하세요:" \
                "$SECRET_HITS" \
                "" \
                "허용 패턴: os.getenv('API_KEY'), config.api_key 등"
        else
            echo "  ✓ 하드코딩된 시크릿 없음"
        fi
    fi

    # ─── requirements.txt 버전 고정 검사 (C2a, optional) ───
    if [ -f "requirements.txt" ]; then
        UNPINNED="$(grep -vE '^[[:space:]]*(#|-r|-c|-e|$)' requirements.txt 2>/dev/null \
            | grep -vE '(==|>=|<=|~=|!=|@)' \
            || true)"
        if [ -n "$UNPINNED" ]; then
            echo "  ⚠ requirements.txt 버전 미고정 패키지 감지 [경고]"
            WARNINGS+=("requirements.txt 버전 미고정: $(echo "$UNPINNED" | tr '\n' ' ')")
            WARNINGS+=("  → 해결: pip freeze > requirements.txt")
        else
            echo "  ✓ requirements.txt 버전 고정 확인"
        fi
    fi

    # ─── import * 사용 감지 (C2, optional) ───
    if [ -d "src" ]; then
        STAR_IMPORTS="$(grep -rnE --include='*.py' \
            '^from[[:space:]]+[^[:space:]]+[[:space:]]+import[[:space:]]+\*' src/ 2>/dev/null \
            || true)"
        if [ -n "$STAR_IMPORTS" ]; then
            echo "  ⚠ import * 사용 감지 [경고]"
            WARNINGS+=("import * 사용 — 명시적 import 권장:")
            WARNINGS+=("$STAR_IMPORTS")
        else
            echo "  ✓ import * 미사용 확인"
        fi
    fi

    # ─── ruff 린트 (C2, required) ───
    if tool_check "ruff"; then
        run_check "ruff check (린트)" "required" ruff check .
        run_check "ruff format --check (포맷)" "optional" ruff format --check .
    fi

    # ─── pytest + 커버리지 (C8, ADR-016/017 — 회귀 방지 핵심) ───
    if [ -d "tests" ]; then
        TEST_FILES="$(find tests -name 'test_*.py' -o -name '*_test.py' 2>/dev/null | wc -l)"
        if [ "$TEST_FILES" -gt 0 ]; then
            if tool_check "pytest"; then
                COV_THRESHOLD="$(read_coverage_threshold)"

                # pytest-cov 설치 여부 확인
                if python3 -c "import pytest_cov" >/dev/null 2>&1; then
                    echo "  · 전체 테스트 스위트 + 커버리지 ≥${COV_THRESHOLD}% 검사 (ADR-016/017)"
                    run_check "pytest --cov (커버리지 ≥${COV_THRESHOLD}%)" "required" \
                        pytest --cov=src --cov-report=term-missing \
                               --cov-fail-under="$COV_THRESHOLD" \
                               -q --tb=short
                else
                    echo "  ⚠ pytest-cov 미설치 — 커버리지 검사 스킵 (ADR-016 미충족)"
                    WARNINGS+=("pytest-cov 미설치 — requirements-dev.txt에 pytest-cov 추가 필요")
                    run_check "pytest (전체 테스트 스위트)" "required" pytest -q --tb=short
                fi
            fi
        else
            echo "  ✗ tests/ 폴더가 있지만 테스트 파일이 없습니다 [FAIL]"
            record_error "테스트 파일 없음 (C8 위반)" \
                "tests/ 폴더에 test_*.py 파일이 없습니다." \
                "최소 1개 이상의 테스트 파일을 작성하세요." \
                "회귀 방지 불가 — ADR-017 위반"
        fi
    else
        echo "  ⚠ tests/ 폴더 없음 — 테스트 스킵"
        WARNINGS+=("tests/ 폴더 없음 — 회귀 방지 불가. ADR-017 위반 상태.")
    fi

    # ─── mypy (선택적 — pyproject.toml [tool.mypy]도 인식) ───
    HAS_MYPY_CONFIG=false
    if [ -f "mypy.ini" ] || [ -f "setup.cfg" ]; then
        HAS_MYPY_CONFIG=true
    elif [ -f "pyproject.toml" ] && grep -qE '^\[tool\.mypy\]' pyproject.toml 2>/dev/null; then
        HAS_MYPY_CONFIG=true
    fi

    if [ "$HAS_MYPY_CONFIG" = true ] && tool_check "mypy" 2>/dev/null; then
        run_check "mypy (타입 체크)" "optional" mypy .
    fi
fi

# ─────────────────────────────────────
# TypeScript/JavaScript 프로젝트 감지 및 검사
# ─────────────────────────────────────

IS_TS=false
# frontend/ 또는 루트에 package.json이 있으면 TS/JS 프로젝트로 간주
if [ -f "package.json" ] || [ -f "frontend/package.json" ]; then
    IS_TS=true
fi

if [ "$IS_TS" = true ]; then
    echo ""
    echo "▶ TypeScript/JavaScript 검사"

    # frontend/ 폴더가 있는 monorepo 지원
    TS_ROOT="."
    if [ ! -f "package.json" ] && [ -f "frontend/package.json" ]; then
        TS_ROOT="frontend"
    fi

    cd "$TS_ROOT" || { echo "  ✗ 디렉토리 전환 실패: $TS_ROOT"; exit 1; }

    # node_modules가 git에 추적되는지 확인
    if git ls-files --error-unmatch node_modules >/dev/null 2>&1; then
        echo "  ✗ node_modules/가 git에 추적되고 있습니다! [CRITICAL]"
        record_error "보안: node_modules/ git 추적" \
            "node_modules/를 즉시 git에서 제거하세요: git rm -r --cached node_modules/"
    else
        echo "  ✓ node_modules/ git 미추적 확인"
    fi

    # npm/yarn/pnpm 감지
    if [ -f "package-lock.json" ]; then PKG_CMD="npm"
    elif [ -f "yarn.lock" ]; then PKG_CMD="yarn"
    elif [ -f "pnpm-lock.yaml" ]; then PKG_CMD="pnpm"
    else PKG_CMD="npm"
    fi

    # 의존성 설치 확인
    if [ ! -d "node_modules" ]; then
        echo "  ⚠ node_modules/ 없음 — $PKG_CMD install을 먼저 실행하세요 [경고]"
        WARNINGS+=("node_modules 없음 — $PKG_CMD install 필요")
    else
        # lint 검사 (biome 또는 eslint)
        if [ -f "biome.json" ] || [ -f "biome.jsonc" ]; then
            if tool_check "biome" 2>/dev/null; then
                run_check "biome check (린트+포맷)" "required" biome check .
            elif [ -f "node_modules/.bin/biome" ]; then
                run_check "biome check (린트+포맷)" "required" node_modules/.bin/biome check .
            fi
        elif [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ] || [ -f "eslint.config.cjs" ] || \
             [ -f ".eslintrc" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.cjs" ] || \
             [ -f ".eslintrc.mjs" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.yaml" ] || \
             [ -f ".eslintrc.yml" ] || \
             ([ -f "package.json" ] && grep -q '"eslint"' package.json 2>/dev/null); then
            if [ -f "node_modules/.bin/eslint" ]; then
                run_check "eslint" "required" node_modules/.bin/eslint .
            fi
        fi

        # TypeScript 타입 체크 (tsconfig.json이 있으면)
        if [ -f "tsconfig.json" ]; then
            if [ -f "node_modules/.bin/tsc" ]; then
                run_check "tsc --noEmit (타입 체크)" "required" node_modules/.bin/tsc --noEmit
            fi
        fi

        # 테스트 실행 (vitest/jest)
        if grep -qE '"vitest"' package.json 2>/dev/null; then
            TEST_CMD="node_modules/.bin/vitest run"
        elif grep -qE '"jest"' package.json 2>/dev/null; then
            TEST_CMD="node_modules/.bin/jest --passWithNoTests"
        else
            TEST_CMD=""
        fi

        if [ -n "$TEST_CMD" ]; then
            if [ -d "tests" ] || [ -n "$(find src -name '*.test.*' -print -quit 2>/dev/null)" ]; then
                run_check "TS 테스트" "required" bash -c "$TEST_CMD"
            else
                echo "  ⚠ 테스트 파일 없음 [경고]"
                WARNINGS+=("TS 테스트 파일 없음 — tests/ 또는 src/*.test.ts 작성 권장")
            fi
        fi
    fi

    # monorepo라면 원래 디렉토리로 복귀
    cd "$PROJECT_ROOT" || exit 1
fi

# ─────────────────────────────────────
# C/C++ 프로젝트 감지 및 검사
# ─────────────────────────────────────

IS_CPP=false
if [ -f "CMakeLists.txt" ] || [ -f "Makefile" ]; then
    IS_CPP=true
fi

if [ "$IS_CPP" = true ]; then
    echo ""
    echo "▶ C/C++ 검사"

    # clang-format 포맷 체크
    if tool_check "clang-format"; then
        SRC_FILES="$(find src -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) 2>/dev/null | head -50)"
        if [ -n "$SRC_FILES" ]; then
            FORMAT_ISSUES=""
            while IFS= read -r file; do
                if ! clang-format --dry-run --Werror "$file" >/dev/null 2>&1; then
                    FORMAT_ISSUES="$FORMAT_ISSUES\n  - $file"
                fi
            done <<< "$SRC_FILES"
            if [ -n "$FORMAT_ISSUES" ]; then
                echo "  ✗ clang-format 포맷 불일치 [FAIL]"
                record_error "clang-format 포맷 이슈" \
                    "$(echo -e "$FORMAT_ISSUES")" \
                    "실행: clang-format -i src/**/*.{c,cc,cpp,h,hpp}"
            else
                echo "  ✓ clang-format 포맷 확인"
            fi
        fi
    fi

    # cmake 빌드
    if tool_check "cmake"; then
        run_check "cmake 빌드" "required" bash -c \
            "cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=Debug 2>&1 && cmake --build build 2>&1"

        # ctest (전체 테스트 스위트 — ADR-017)
        if [ -d "build" ] && tool_check "ctest"; then
            run_check "ctest (전체 테스트 스위트)" "required" \
                ctest --test-dir build --output-on-failure
        fi
    elif [ -f "Makefile" ]; then
        run_check "make 빌드" "required" make -j"$(nproc 2>/dev/null || echo 2)"
    fi
fi

# ─────────────────────────────────────
# 결과 출력
# ─────────────────────────────────────

echo ""

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "경고 (${#WARNINGS[@]}개):"
    for w in "${WARNINGS[@]}"; do
        echo "  ⚠ $w"
    done
    echo ""
fi

if [ "$FAIL" -ne 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CIRCUIT-BREAKER: 검증 실패. 위 에러를 수정한 뒤 계속하세요." >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    for err in "${ERRORS[@]}"; do
        echo "$err" >&2
    done
    exit 1
fi

echo "✅ 모든 검사 통과"
exit 0
