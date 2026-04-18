# 아키텍처

> 프로젝트 언어에 해당하지 않는 섹션은 삭제한다.
> `{중괄호}` placeholder는 새 프로젝트 시작 시 채운다.

---

## 공통 원칙

1. **단일 책임** — 모듈·파일 하나는 한 가지 일만 한다.
2. **외부 경계 분리** — 외부 I/O(HTTP, 파일, DB)는 `services/` 또는 `repositories/`에 래퍼로 격리한다.
3. **설정 외부화** — 환경 의존 값은 `.env`로. 코드에 하드코딩하지 않는다.
4. **계층 위반 금지** — 진입점(main/routes) → 서비스(비즈니스 로직) → 저장소(DB/파일). 역방향 호출 금지.
5. **테스트 가능성** — 외부 리소스는 의존성 주입으로 교체 가능하게 설계한다.

---

## venv 격리 및 의존성 Lifecycle (Python 프로젝트)

### 왜 venv가 필수인가

- 시스템 Python에 패키지를 쌓으면 프로젝트 간 의존성 충돌이 반드시 발생한다.
- `/gsd:execute-phase`가 각 Phase step을 독립 Claude 세션으로 실행하므로, 재현 가능한 환경이 없으면 "내 로컬에서는 되던데" 문제가 반복된다.
- venv 없이 `ModuleNotFoundError`가 반복되면 Phase 실행이 blocked 상태로 전환돼 비용 낭비로 이어진다.

### Lifecycle 다이어그램

```
[프로젝트 초기화]
  python3 -m venv venv                       ← 한 번만 (첫 /harness 이전)
  source venv/bin/activate
  ↓
[의존성 초기 설치]
  requirements.txt         (runtime)         ← requests, fastapi, python-dotenv ...
  requirements-dev.txt     (lint/test)       ← ruff, pytest, mypy
  pip install -r requirements.txt -r requirements-dev.txt
  ↓
[개발 루프 (매 세션)]
  source venv/bin/activate                   ← 세션 시작마다 반드시
  코드 작성 → ruff check . → pytest → 실행
  새 의존성 추가: pip install X → pip freeze > requirements.txt
  ↓
[step / phase 완료]
  circuit-breaker.sh가 ruff/pytest 자동 검증
  pip freeze > requirements.txt 버전 고정 확인
  ↓
[프로젝트 완료 (wrap-up)]
  pip freeze > requirements.txt             ← 최종 버전 고정
  .env.example 최신화
  README.md 설치·실행 절차 확정
  git tag v1.0.0 && git push --tags
```

### requirements 파일 분리 전략

| 파일 | 용도 | 예시 |
|------|------|------|
| `requirements.txt` | 런타임(프로덕션) 의존성 | `requests==2.31.0`, `python-dotenv==1.0.0` |
| `requirements-dev.txt` | 개발·린트·테스트 전용 | `ruff==0.4.0`, `pytest==7.4.0`, `mypy==1.8.0` |

- `requirements-dev.txt` 첫 줄에 `-r requirements.txt`를 넣으면 dev 파일 하나만 설치해도 runtime 포함.
- **분리 이유**: 프로덕션 컨테이너·서버에 `ruff/pytest`를 배포하지 않기 위함. 이미지 크기·보안 노출 면적 축소.

### venv를 git에 커밋하면 안 되는 이유

1. **플랫폼 의존성** — venv 내부에는 OS/Python 버전에 binding된 바이너리(`.so`, `.exe`)가 포함된다. Linux venv를 Windows에서 활성화하면 즉시 깨진다.
2. **용량** — 중간 규모 venv는 쉽게 100~500MB. 리포지토리가 폭증한다.
3. **재현성** — `requirements.txt`만 있으면 `python3 -m venv venv && pip install -r requirements.txt`로 누구나 동일한 환경을 만든다.

표준 `.gitignore` 항목 (Python 프로젝트):
```
venv/
.venv/
__pycache__/
*.pyc
*.pyo
.pytest_cache/
.ruff_cache/
.mypy_cache/
.env
build/
dist/
*.egg-info/
```

### CI/서버 배포 환경에서의 venv 전략

| 환경 | 전략 |
|------|------|
| GitHub Actions / GitLab CI | 각 job 시작 시 `python -m venv venv && pip install -r requirements.txt` |
| Docker 이미지 | `python:3.11-slim` 베이스 + `RUN pip install -r requirements.txt`. 컨테이너 자체가 격리되므로 venv 생략 가능. |
| 단일 서버 직접 배포 | venv 필수. systemd `ExecStart`에 `/app/venv/bin/python main.py` 절대경로 사용. |
| 서버리스 (Lambda/Cloud Functions) | requirements.txt를 layer/deployment package에 포함. venv 불필요. |

---

## Phase 설계 가이드라인 (/gsd:plan-phase에서 참고)

> `/gsd:execute-phase`가 각 Phase의 step을 독립 Claude 세션으로 **순차** 실행한다.
> 실행 전 반드시 venv 활성화: `source venv/bin/activate`
> step 간 인터페이스(파일·스키마·API 스펙)를 명확히 정의해야 다음 step이 독립적으로 실행 가능하다.

### 권장 Phase step 분리 패턴

**패턴 A — CLI / 스크립트**
```
Step 0 — 핵심 로직 + 프로젝트 설정
Step 1 — Tests
```

**패턴 B — 백엔드 API (웹 서비스, Frontend 없음)**
```
Step 0 — DB 스키마
  담당: DB 테이블 설계, 마이그레이션, 시드 데이터
  산출물: schema.sql / models.py / migration 파일
  summary 예시: "users(id, email, created_at), items(id, user_id, title, status) 테이블 생성. SQLite 사용."
  ─────────────────────────────────────────────────
  ↓ summary만 전달

Step 1 — Backend Core (비즈니스 로직)
  담당: 서비스 계층, 저장소, 도메인 로직 — HTTP 관심사 없음
  선행 조건: Step 0 완료 (schema 확정)
  산출물: src/services/, src/repositories/, src/{domain}/ 모듈
  summary 예시: "ItemService(fetch, save, delete) 구현. 지수 백오프 재시도 포함."
  ─────────────────────────────────────────────────
  ↓ summary만 전달

Step 2 — Server 레이어 (라우터·미들웨어·진입점)
  담당: API 라우터 마운트, 미들웨어, CORS, 인증 훅, 헬스체크, main.py
  선행 조건: Step 1 완료 (서비스 인터페이스 확정)
  산출물: src/api/routes.py, main.py, src/server.py
  summary 예시: "GET /items, POST /items, DELETE /items/{id} 구현. Bearer 토큰 인증. CORS 허용."
  ─────────────────────────────────────────────────
  ↓ summary만 전달

Step 3 — Tests
  담당: 단위 테스트, 통합 테스트
  선행 조건: Step 0~2 모두 완료
  산출물: tests/ 폴더 내 테스트 파일
  Acceptance Criteria: pytest && ruff check .
  summary 예시: "단위 12개, 통합 5개 테스트 작성. 커버리지 80%."
```

**패턴 C — 풀스택 (Frontend 포함)**
```
Step 0 — DB 스키마
Step 1 — Backend Core
Step 2 — Server 레이어
Step 3 — Frontend (UI 컴포넌트, 페이지, 라우팅)
  선행 조건: Step 2 완료 (API 계약 확정)
  산출물: 컴포넌트 + 페이지 파일
Step 4 — Tests
```

> Backend Core와 Server 레이어를 분리하는 이유: 비즈니스 로직(Core)이 HTTP 관심사(라우팅, 상태코드, 미들웨어)에 오염되지 않도록 한다. Core는 순수 Python 함수로 테스트하기 쉽고, Server는 Core를 호출하는 얇은 어댑터 역할만 한다.
> 단순 CRUD처럼 비즈니스 로직이 거의 없으면 Core + Server를 하나의 step으로 합쳐도 된다.
> step 수는 프로젝트 규모에 따라 조정하되, 하나의 step이 너무 크면 쪼갠다.

---

## Python 프로젝트 구조

```
{프로젝트명}/
├── main.py                 # 진입점 (argparse 또는 간단한 CLI)
├── requirements.txt        # 의존성 (버전 고정 pip freeze > requirements.txt)
├── pyproject.toml          # ruff 설정
├── .env                    # 실제 환경변수 (git 제외)
├── .env.example            # 환경변수 키 목록 + 예시값 (git 포함)
├── .gitignore
├── README.md
├── src/
│   ├── __init__.py
│   ├── config.py           # .env 로드 + 설정 객체 (dataclass 또는 BaseSettings)
│   ├── models/             # 데이터 클래스 / Pydantic 모델
│   ├── services/           # 외부 API·HTTP 클라이언트 래퍼
│   ├── repositories/       # DB·파일 접근 계층
│   ├── api/                # 라우터·핸들러 (웹 서버 시)
│   └── {domain}/           # 핵심 비즈니스 로직 (프로젝트별 명명)
├── tests/
│   ├── __init__.py
│   ├── test_{domain}.py    # 단위 테스트
│   └── test_integration.py # 통합 테스트 (선택)
└── docs/
    ├── PRD.md
    ├── ARCHITECTURE.md
    ├── ADR.md
    └── UI_GUIDE.md
```

### Python 표준 설정 파일 (`pyproject.toml`)

```toml
[tool.ruff]
line-length = 100
target-version = "py310"

[tool.ruff.lint]
select = ["E", "F", "I"]   # pycodestyle, pyflakes, isort
ignore = ["E501"]           # 줄 길이는 ruff format이 처리
```

### Python 패턴

- **진입점 얇게 유지**: `main.py`는 인자 파싱과 서비스 호출만. 로직은 `src/`에.
- **설정 객체 한 곳에**: `src/config.py`에서 `os.getenv()`를 한 번에 읽고 `@dataclass`로 노출.
- **의존성 주입**: 서비스 클래스는 외부 리소스(HTTP client, DB connection)를 생성자로 주입받는다.

### Python 데이터 흐름

```
사용자 실행 (main.py)
  → config 로드 (.env)
  → services.{ExternalAPI}.fetch()   # 외부 데이터 수집
  → models.{DataClass} 변환          # 도메인 객체로 변환
  → {domain}.process()               # 비즈니스 로직
  → repositories.save() (선택)       # 영속화
  → 출력 (stdout / 파일 / 외부 API)
```

---

## TypeScript/JavaScript 프로젝트 구조

```
{프로젝트명}/
├── package.json            # 의존성 및 스크립트
├── tsconfig.json           # TypeScript 설정
├── biome.json              # 린트+포맷 설정 (또는 .eslintrc + .prettierrc)
├── .gitignore              # node_modules/ 포함 필수
├── .env                    # 환경변수 (git 제외)
├── .env.example            # 환경변수 키 목록 (git 포함)
├── README.md
├── src/
│   ├── index.ts            # 진입점
│   ├── config.ts           # 환경변수 로드 + 설정 객체
│   ├── models/             # 타입·인터페이스 정의
│   ├── services/           # 외부 API 클라이언트
│   ├── repositories/       # DB 접근 계층
│   ├── routes/             # Express/Hono 라우터 (웹 서버 시)
│   └── {domain}/           # 핵심 비즈니스 로직
├── tests/
│   └── *.test.ts           # vitest / jest 테스트
└── docs/
```

### TypeScript 표준 설정 (`package.json` scripts)

```json
{
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "biome check .",
    "lint:fix": "biome check --write .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest"
  }
}
```

---

## 혼합 언어 프로젝트 구조 (Python 백엔드 + TS 프론트엔드)

> Python+TypeScript 혼합(패턴 C — 풀스택)은 반드시 아래 폴더 구조를 따른다.

```
{프로젝트명}/
├── backend/                # Python (FastAPI/Flask 등)
│   ├── main.py
│   ├── src/
│   ├── tests/
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   ├── pyproject.toml
│   ├── venv/               # git 제외
│   ├── .env                # git 제외
│   └── .env.example
├── frontend/               # TypeScript (React/Vue/Svelte 등)
│   ├── src/
│   ├── tests/
│   ├── package.json
│   ├── tsconfig.json
│   ├── node_modules/       # git 제외
│   ├── .env                # git 제외
│   └── .env.example
├── docker-compose.yml      # 개발 환경 통합 (선택)
├── .gitignore              # 루트: venv/, node_modules/, .env 포함
└── README.md
```

### 혼합 프로젝트 circuit-breaker.sh 동작

- `backend/` 존재 → Python 검사(ruff, pytest) 실행
- `frontend/` 존재 → TS 검사(lint, typecheck, test) 실행
- 두 폴더 모두 존재 → 순차로 양쪽 실행

### harness step 분리 (패턴 C — 혼합)

```
Step 0 — DB 스키마 (backend/src/models/)
Step 1 — Backend Core (backend/src/services/, repositories/, domain/)
Step 2 — Server 레이어 (backend/src/routes/, main.py)
Step 3 — Frontend (frontend/src/components/, pages/, hooks/)
          ← Step 2 완료 후 API 계약 확정 필요
Step 4 — Tests (backend/tests/ + frontend/tests/)
```

---

## C/C++ 프로젝트 구조

```
{프로젝트명}/
├── CMakeLists.txt          # 빌드 (또는 Makefile)
├── .clang-format           # BasedOnStyle: Google, IndentWidth: 4, ColumnLimit: 100
├── .clang-tidy             # 정적 분석 설정
├── .gitignore              # build/, *.o, compile_commands.json 포함
├── README.md
├── src/
│   ├── main.cpp            # 진입점
│   ├── core/               # 핵심 로직
│   ├── io/                 # 파일·네트워크 I/O
│   └── utils/              # 순수 유틸 함수
├── include/
│   └── {프로젝트명}/       # public 헤더
├── tests/
│   └── test_*.cpp          # Catch2 / GoogleTest
├── build/                  # CMake 빌드 출력 (git 제외)
└── docs/
```

### C/C++ 표준 설정 파일 (`.clang-format`)

```yaml
BasedOnStyle: Google
IndentWidth: 4
ColumnLimit: 100
```

### C/C++ 패턴

- **헤더 최소화**: public API만 `include/`에. 내부 구현 헤더는 `src/` 옆에.
- **RAII**: 리소스는 `unique_ptr` 또는 RAII 클래스로 관리. raw `new/delete` 금지.
- **include 순서**: (1) 짝 헤더, (2) C 표준, (3) C++ 표준, (4) 서드파티, (5) 프로젝트. 그룹 간 빈 줄.

---

## 상태 관리

{프로젝트가 상태를 가진다면 여기에 기술:
- 영속 상태: SQLite (`data/app.db`) / PostgreSQL / 파일 시스템
- 런타임 상태: `src/state.py` 싱글톤 / 인메모리 딕셔너리
- 외부 상태: Telegram API 세션 / Redis 등

상태가 없는 무상태 스크립트/크롤러이면: "무상태. 매 실행마다 독립."으로 교체 후 이 섹션 삭제.}

---

## 에러 처리 전략

### 기본 원칙

- **회복 가능한 에러**: 구체적인 예외를 catch하여 로깅 후 재시도 또는 스킵.
- **회복 불가 에러**: 명확한 메시지 출력 후 `sys.exit(1)` / `std::exit(1)`.
- **사용자 입력 오류**: 친절한 안내 메시지를 stderr에 출력 후 종료.
- **절대 금지**: `except Exception: pass` (Python), `catch(...)` 빈 블록 (C++), 에러 무시.

### 재시도 전략 (네트워크·외부 API)

```python
# 지수 백오프 패턴
MAX_RETRIES = 3
INITIAL_DELAY = 1.0  # 초

for attempt in range(MAX_RETRIES):
    try:
        result = external_api_call()
        break
    except (TimeoutError, ConnectionError) as e:
        if attempt == MAX_RETRIES - 1:
            logger.error(f"최대 재시도 초과: {e}")
            raise
        delay = INITIAL_DELAY * (2 ** attempt)
        logger.warning(f"재시도 {attempt + 1}/{MAX_RETRIES} ({delay}s 후)")
        time.sleep(delay)
    except HTTPError as e:
        if e.status_code in (400, 401, 403, 404):
            raise  # 클라이언트 에러는 재시도 없음
        # 5xx는 재시도
```

### 에러 로깅 형식

```
ERROR: {에러 타입} — {구체적 원인}
  위치: {파일명}:{라인}
  입력: {관련 입력값 — 민감정보 마스킹}
  재시도: {N}회 시도 후 실패 (해당 시)
```

### 예외 계층 설계 (Python)

```python
class ProjectBaseError(Exception):
    """프로젝트 최상위 에러"""

class ConfigError(ProjectBaseError):
    """설정·환경변수 오류"""

class ExternalServiceError(ProjectBaseError):
    """외부 API·서비스 연동 오류"""

class DataError(ProjectBaseError):
    """데이터 파싱·검증 오류"""
```

---

## 테스트 전략 및 회귀 방지

> **회귀(regression)**: 새 기능 추가·버그 수정 중에 기존에 작동하던 기능이 망가지는 현상.
> 이를 방지하는 유일한 방법은 변경 때마다 **전체 테스트 스위트**를 실행하는 것이다.

### 테스트 피라미드 (ADR-016)

```
         ▲
        /E\       E2E 테스트  (~5%)  — 실제 환경 전체 흐름 (드물게, 느림)
       /───\
      / 통합 \     통합 테스트 (~25%) — 외부 경계(DB, HTTP, 파일) 진짜 연결
     /───────\
    /  단위   \    단위 테스트 (~70%) — 함수·클래스 단독 실행, 외부 mock 처리
   /───────────\
```

| 계층 | 대상 | mock 여부 | 실행 속도 | 실패 시 의미 |
|------|------|----------|-----------|------------|
| 단위 | 비즈니스 로직, 유틸 함수, 데이터 변환 | 외부 전부 mock | 빠름 (ms) | 로직 버그 |
| 통합 | 서비스 레이어, DB 쿼리, HTTP 클라이언트 | 외부 API만 mock | 중간 (초) | 계층 간 연결 버그 |
| E2E | 전체 사용자 플로우 | mock 없음 | 느림 (분) | 배포 단위 회귀 |

### 무엇을 테스트해야 하는가

| 코드 위치 | 테스트 유형 | 테스트 대상 |
|----------|------------|------------|
| `src/{domain}/` | 단위 | 모든 public 함수. 입력별 출력, 에러 케이스 |
| `src/services/` | 통합 | 외부 API 성공·실패·타임아웃 응답 처리 |
| `src/repositories/` | 통합 | CRUD 동작, unique 제약 위반, 빈 결과 |
| `src/config.py` | 단위 | 필수 환경변수 누락 시 `ConfigError` 발생 확인 |
| `main.py` | 통합/E2E | CLI 인자 파싱, 전체 플로우 smoke test |

### conftest.py 구조 패턴

```python
# tests/conftest.py
import pytest
from unittest.mock import MagicMock, patch
from src.config import Config


@pytest.fixture
def mock_config() -> Config:
    """테스트용 설정 객체 — 실제 .env 불필요"""
    return Config(api_key="test-api-key-1234", db_url="sqlite:///:memory:")


@pytest.fixture
def mock_http_client():
    """외부 HTTP 호출 mock — 네트워크 의존 제거"""
    with patch("src.services.external_api.httpx.Client") as mock:
        mock_instance = MagicMock()
        mock.return_value.__enter__ = MagicMock(return_value=mock_instance)
        mock.return_value.__exit__ = MagicMock(return_value=False)
        yield mock_instance


@pytest.fixture
def db_session():
    """인메모리 DB — 테스트 후 자동 롤백"""
    from src.repositories.database import create_engine, create_tables
    engine = create_engine("sqlite:///:memory:")
    create_tables(engine)
    session = Session(engine)
    yield session
    session.rollback()
    session.close()
```

### 테스트 작성 패턴

#### 기본 단위 테스트
```python
# tests/test_price_parser.py

def test_parse_price_valid_string_returns_float():
    # Arrange
    raw = "1,234,567원"
    # Act
    result = parse_price(raw)
    # Assert
    assert result == 1_234_567.0


def test_parse_price_empty_string_raises_value_error():
    # PRD §7-3: 빈 데이터 처리
    with pytest.raises(ValueError, match="가격 형식이 잘못"):
        parse_price("")


def test_parse_price_none_raises_type_error():
    # PRD §7-1: None 입력 처리
    with pytest.raises(TypeError):
        parse_price(None)
```

#### 파라미터화 테스트 (경계값 커버)
```python
@pytest.mark.parametrize("raw,expected", [
    ("1,000원",     1000.0),
    ("0원",            0.0),
    ("999,999,999원", 999_999_999.0),
    ("100",          100.0),   # 단위 없는 경우
])
def test_parse_price_boundary_values(raw, expected):
    assert parse_price(raw) == expected
```

#### 외부 API mock 통합 테스트
```python
def test_fetch_items_success_returns_list(mock_http_client, mock_config):
    # Arrange
    mock_http_client.get.return_value.json.return_value = [{"id": 1, "title": "Item A"}]
    mock_http_client.get.return_value.status_code = 200
    service = ItemService(config=mock_config, client=mock_http_client)
    # Act
    items = service.fetch_items()
    # Assert
    assert len(items) == 1
    assert items[0].title == "Item A"


def test_fetch_items_timeout_retries_three_times(mock_http_client, mock_config):
    # PRD §7-2: HTTP 타임아웃 재시도
    from httpx import TimeoutException
    mock_http_client.get.side_effect = TimeoutException("timeout")
    service = ItemService(config=mock_config, client=mock_http_client)

    with pytest.raises(ExternalServiceError):
        service.fetch_items()

    assert mock_http_client.get.call_count == 3  # ADR-011: 최대 3회
```

### 커버리지 설정 (`pyproject.toml`)

```toml
[tool.coverage.run]
source = ["src"]
omit = [
    "src/config.py",       # 설정만 있는 파일 (필요 시 포함)
    "*/migrations/*",
    "*/__init__.py",
]

[tool.coverage.report]
fail_under = 70            # circuit-breaker.sh가 이 값을 읽어 적용
show_missing = true
skip_covered = false
exclude_lines = [
    "pragma: no cover",
    "if TYPE_CHECKING:",
    "raise NotImplementedError",
]
```

### 회귀 방지 5원칙 (ADR-017)

1. **전체 스위트 실행**: 새 코드를 추가하면 반드시 기존 테스트 전부를 실행한다. `pytest` 단독으로 실행 — 경로 지정 없이.
2. **테스트 파일 삭제 금지**: 기존 테스트가 방해가 된다면 코드를 수정하는 것이 맞다. 테스트를 지우는 것은 회귀 감지기를 부수는 행위다.
3. **실패 테스트를 skip으로 숨기지 않는다**: `@pytest.mark.skip`은 임시 표시 목적으로만. `skipif` 조건이 명확해야 한다.
4. **새 기능 → 새 테스트 먼저**: 함수를 작성하기 전에 테스트를 작성하는 것이 이상적. 최소한 동시에 작성.
5. **circuit-breaker.sh가 강제**: 세션 종료 시 `pytest --cov --cov-fail-under=70`이 자동 실행된다. 이를 우회하는 방법은 없다.

### 테스트 격리 원칙

```python
# 금지: 테스트 간 전역 상태 공유
_SHARED_DB = Database()  # 이렇게 하지 않는다

# 권장: fixture로 매 테스트 전 초기화
@pytest.fixture(autouse=True)
def reset_state():
    """모든 테스트 전 상태 초기화"""
    yield
    # teardown: DB 롤백, 파일 삭제, mock 리셋 등
```

### 테스트 네이밍 컨벤션

```
test_[함수명]_[입력_시나리오]_[기대_결과]

예시:
  test_parse_price_valid_input_returns_float
  test_parse_price_empty_string_raises_value_error
  test_fetch_items_http_timeout_retries_three_times
  test_save_item_duplicate_key_raises_data_error
  test_config_missing_api_key_raises_config_error
```

---

## 의존성 관리

### Python `pyproject.toml` 표준 구조

```toml
[tool.ruff]
line-length = 100
target-version = "py310"

[tool.ruff.lint]
select = ["E", "F", "I"]
ignore = ["E501"]

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_functions = ["test_*"]
addopts = "-v --tb=short"
```

### 의존성 버전 고정 원칙

venv lifecycle 전체 절차는 "venv 격리 및 의존성 Lifecycle" 섹션 참조.

```bash
# requirements.txt 형식 예시
requests==2.31.0
python-dotenv==1.0.0

# requirements-dev.txt 형식 예시
-r requirements.txt
ruff==0.4.0
pytest==7.4.0
```

- 보안 업데이트: 분기별 `pip list --outdated` 확인. CVE 발생 시 즉시 업그레이드.

---

## 보안 설계 원칙

1. **입력 검증은 경계에서** — 외부 입력(사용자, API 응답, 파일)은 진입 시점에서 즉시 검증.
2. **최소 권한** — 파일 권한은 필요한 최소로. API 키 scope도 최소로.
3. **로그에 민감정보 금지** — API 키, 토큰, 비밀번호는 `***`로 마스킹 후 로깅.
4. **SQL 인젝션 방지** — 파라미터 바인딩만 사용. f-string SQL 절대 금지.
5. **경로 순회 방지** — 사용자 입력을 파일 경로에 직접 사용 금지. `pathlib.Path` + 경계 검사.

```python
# 안전한 API 키 마스킹 예시
def mask_secret(value: str) -> str:
    if len(value) <= 8:
        return "***"
    return f"{value[:4]}...{value[-4:]}"
```

