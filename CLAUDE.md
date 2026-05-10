# 프로젝트: {프로젝트명}

> 이 파일은 **프로젝트 CLAUDE.md 템플릿**이다. 새 프로젝트 생성 시 `projects/{프로젝트명}/CLAUDE.md`로 복사해 사용한다.
> `{중괄호}` placeholder는 반드시 채운다.
> Claude Code가 프로젝트 세션 시작 시 이 파일을 자동으로 읽는다. 실제 Phase 실행은 `/gsd:execute-phase`가 담당한다.
> 새 프로젝트 시작 절차는 맨 아래 "새 프로젝트 시작 체크리스트" 참조.

---

## 프로젝트 개요

- **이름**: {프로젝트명 (snake_case, `projects/` 폴더명과 일치)}
- **설명**: {이 프로젝트가 무엇을 하는지 한 문장}
- **위치**: `/coding/projects/{프로젝트명}/`

## 기술 스택

- **언어**: {Python 3.10+ | C/C++ (C++17 이상) | TypeScript | 혼합}
- **주요 의존성**: {예: requests, selenium, python-dotenv / FastAPI / React 등}
- **실행 환경**: {CLI / 데몬 / 크롤러 / 웹 서버 / 임베디드 등}

---

## CRITICAL 규칙 — 절대 위반 금지

### C1. 보안
- CRITICAL: API 키·비밀번호·토큰은 반드시 `.env`에서 `python-dotenv`로 로드한다. 코드·로그에 하드코딩 절대 금지.
- CRITICAL: `.env` 파일은 git에 커밋하지 않는다. `.gitignore`에 반드시 포함. `.env.example`만 커밋한다.

### C2. Python 코딩 스타일 (Python 프로젝트에 해당)
- CRITICAL: Python 3.10+ 문법 사용. `match/case`, `X | Y` 유니온 타입 허용.
- CRITICAL: 들여쓰기 스페이스 4칸. 줄 최대 100자. 인코딩 UTF-8.
- CRITICAL: 네이밍 — 변수/함수 `snake_case`, 클래스 `PascalCase`, 상수 `UPPER_SNAKE_CASE`, 비공개 속성 `_single_underscore`.
- CRITICAL: 코드 변경 후 `ruff check .` 통과 필수. 실패하면 step을 completed 처리하지 않는다.
- CRITICAL: import 정렬은 `ruff check --select I --fix .`로 자동 수정.
- 권장: `mypy . --ignore-missing-imports` 실행. 정적 타입 오류(잘못된 kwarg 이름, None 역참조, 타입 불일치)를 런타임 이전에 발견. ruff가 못 잡는 버그 클래스를 커버한다. 신규 프로젝트는 첫 날부터 적용 권장. `requirements-dev.txt`에 `mypy` 포함.
- 권장: `if __name__ == "__main__":` 가드 안의 코드는 `pytest`가 실행하지 않는다. CLI 진입점(`main.py` 등)은 `mypy main.py`로 별도 검증하거나 smoke test(`subprocess.run([sys.executable, "main.py", ...])`)를 작성한다.

### C2a. venv 격리 — Python 프로젝트 필수
- CRITICAL: Python 프로젝트는 프로젝트 루트에 `venv/` 폴더로 가상환경을 생성한다. 폴더명은 **`venv` 고정**. `.venv`, `env`, `virtualenv` 등 변형 금지.
- CRITICAL: 새 프로젝트 시작 시 **첫 `/harness` 실행 이전에** `python3 -m venv venv && source venv/bin/activate`를 수행한다.
- CRITICAL: **모든** `pip install` 명령은 venv 활성화 상태에서만 실행한다. 시스템 파이썬에 패키지를 설치하지 않는다.
- CRITICAL: 의존성은 용도별로 분리한다.
  - `requirements.txt` — 런타임 의존성 (예: `requests==2.31.0`, `python-dotenv==1.0.0`)
  - `requirements-dev.txt` — 린트·테스트 전용 (예: `ruff==0.4.0`, `pytest==7.4.0`, `pytest-cov==4.1.0`, `mypy==1.8.0`)
  - 첫 줄에 `-r requirements.txt`를 넣으면 requirements-dev.txt 하나로 두 파일 모두 설치 가능
- CRITICAL: 의존성 추가·변경 시 즉시 `pip freeze > requirements.txt`로 버전을 고정한다.
- CRITICAL: `venv/` 폴더는 `.gitignore`에 포함한다. **절대로 커밋하지 않는다.**
- CRITICAL: `/gsd:execute-phase`는 venv가 활성화된 셸에서 실행한다.
  ```bash
  # 올바른 실행 방법
  source venv/bin/activate
  /gsd:execute-phase {phase-name}
  ```
- CRITICAL: CI/프로덕션 서버 등 venv가 불가능한 환경에서는 OS 환경변수와 컨테이너 이미지로 대체한다. ARCHITECTURE.md "CI/서버 배포" 섹션 참조.

### C2b. TypeScript/JavaScript 코딩 스타일 (TS/JS 프로젝트에 해당)
- CRITICAL: Node.js 20+ / TypeScript 5+ 기준으로 작성한다.
- CRITICAL: 들여쓰기 스페이스 2칸. 줄 최대 100자. 파일 인코딩 UTF-8.
- CRITICAL: 네이밍 — 변수/함수 `camelCase`, 클래스/타입/인터페이스 `PascalCase`, 상수 `UPPER_SNAKE_CASE`, 파일명 `kebab-case.ts` (React 컴포넌트는 `PascalCase.tsx`).
- CRITICAL: 린트+포맷 — `biome check .` (권장) 또는 `eslint && prettier`. `tsc --noEmit`으로 타입 체크.
- CRITICAL: 테스트 — Vite 프로젝트는 `vitest`, Node 서버는 `jest` 또는 `node --test`.
- CRITICAL: 코드 변경 후 `npm run lint && npm run typecheck` 통과 필수.
- CRITICAL: 의존성은 `package.json`으로 관리. `package-lock.json` 또는 `yarn.lock` 반드시 커밋.
- CRITICAL: `node_modules/`는 `.gitignore`에 반드시 포함. 절대 커밋 금지.

### C3. C/C++ 코딩 스타일 (C/C++ 프로젝트에 해당)
- CRITICAL: 들여쓰기 스페이스 4칸. 줄 최대 100자. 인코딩 UTF-8.
- CRITICAL: 네이밍 — 변수/함수 `snake_case`, 클래스/구조체 `PascalCase`, 멤버 변수 `snake_case_`, 상수/매크로 `UPPER_SNAKE_CASE`.
- CRITICAL: 코드 변경 후 `clang-format -i` 실행 필수. `clang-tidy` 경고 0개 달성.

### C4. Git 커밋
- CRITICAL: 커밋 메시지 형식: `<type>: <요약 (50자 이내)>`. type ∈ {feat, fix, refactor, docs, chore}.
- CRITICAL: 하나의 커밋 = 하나의 목적. 미완성 코드 커밋 금지.
- CRITICAL: Phase 완료 후 원자적 커밋 1개로 정리한다.

### C5. 테스트 완결성 및 회귀 방지
- CRITICAL: 비즈니스 로직이 있는 모든 함수는 단위 테스트를 가져야 한다. 단순 getter/setter 제외.
- CRITICAL: 외부 경계(DB, HTTP API, 파일 I/O)는 통합 테스트를 가져야 한다.
- CRITICAL: 새 step 완료 전 반드시 **전체** 테스트 스위트를 실행한다. 새 테스트만이 아닌 기존 테스트 전부. 회귀 방지는 이 단계에서 결정된다.
- CRITICAL: PRD 섹션 7의 에러 케이스는 모두 테스트 케이스로 구현한다. `# PRD §7-{번호}` 주석으로 PRD와 테스트를 연결한다.
- CRITICAL: 커버리지 70% 미만이면 `status: completed`로 마킹하지 않는다. `circuit-breaker.sh`가 자동 강제.
- CRITICAL: 외부 HTTP API 호출은 테스트에서 반드시 `unittest.mock` 또는 `pytest-mock`으로 대체한다. 테스트가 실제 네트워크에 의존하면 안 된다.
- CRITICAL: `assert` 문이 없는 테스트 함수를 만들지 않는다. 빈 테스트는 거짓 안전감을 준다.
- CRITICAL: 테스트 네이밍: `test_[함수명]_[시나리오]_[기대결과]` 형식.
  - 예: `test_parse_price_empty_string_raises_value_error`
  - 예: `test_fetch_items_api_timeout_retries_three_times`
- CRITICAL: 테스트 간 독립성 유지. 실행 순서 의존 금지. 공유 상태는 `conftest.py` fixture로 매 테스트 전 초기화.
- CRITICAL: 경계값 테스트 의무 — None, 빈 문자열, 빈 리스트, 최대값, 최소값, 0, 음수. PRD 섹션 7의 엣지 케이스가 기준.
- CRITICAL: **모든 API 라우트 / HTTP 엔드포인트는 단위 테스트를 가져야 한다.** 정상 응답·필수 파라미터 누락(400)·타입 불일치(400)·인증 실패(401/403) 케이스를 모두 검증한다. Flask는 `app.test_client()`, FastAPI는 `TestClient`로 직접 호출한다.
- CRITICAL: **공유 상태(캐시·전역 dict 등)에 동시 접근하는 코드는 동시성 테스트를 가져야 한다.** `concurrent.futures.ThreadPoolExecutor`로 N개 스레드를 동시 실행해 race condition·키 충돌·deadlock 부재를 검증한다.
- CRITICAL: **CLI 진입점(`main.py`)은 smoke test로 검증한다.** `subprocess.run([sys.executable, "main.py", "--help"])` 또는 `runpy.run_path("main.py")`로 import·인자 파싱·기본 호출이 TypeError·NameError 없이 통과하는지 확인한다. 이유: `if __name__ == "__main__":` 가드 안의 코드는 pytest가 자동 실행하지 않아 잘못된 kwarg 이름·타입 등 잠복 버그가 출시 시점까지 발견되지 않는다.

### C6. GSD + harness 역할 분리
- CRITICAL: harness는 **인프라 셋업 전담** — docs/, CLAUDE.md, .gitignore, .env.example 생성까지만.
- CRITICAL: Phase 실행·상태 관리는 `/gsd:execute-phase`가 담당한다. harness가 직접 코드를 생성하거나 Phase를 실행하지 않는다.
- CRITICAL: harness가 생성한 `docs/PRD.md`는 GSD의 `.planning/ROADMAP.md`와 연계된다. `/gsd:new-project` 또는 `/gsd:plan-phase` 실행 시 docs/PRD.md를 입력 자료로 활용한다.
- CRITICAL: `/gsd:verify-work`로 UAT를 통과해야 GSD Phase를 완료로 처리한다.

### C7. 프로젝트 특화 규칙 (새 프로젝트 시작 시 작성)
- CRITICAL: {프로젝트 고유의 절대 규칙 — 없으면 이 섹션 삭제}

### C8. 모듈 경계 · DRY · 동시성 · 라우트 일관성

> stock_backtesting 프로젝트에서 발견된 구조적 취약점을 모체 규칙으로 승격한 항목. 신규 프로젝트는 첫 날부터 이 규칙들을 적용한다.

**C8-1. private 함수의 모듈 경계 (CRITICAL)**
- CRITICAL: `_` 접두어 함수/변수는 **정의된 모듈 내에서만** 사용한다. 다른 모듈이 `from module import _private_fn` 형태로 import하는 것을 금지한다.
- 이유: private 시그널과 실제 사용이 모순되면 새 개발자가 혼란을 겪는다. 타입 체커·린터도 이 위반을 자동으로 잡지 못한다.
- 적용: 두 모듈이 같은 함수를 필요로 하면 즉시 `metrics.py`, `utils.py`, `shared.py` 등 공용 모듈로 승격하고 언더스코어를 제거한다.
- 검출: `grep -rnE "from [a-zA-Z_]+ import _[a-zA-Z_]+" src/`로 사전 감시 가능 (CI 또는 사용자 검수 시점에 실행).

**C8-2. 공용 계산 함수 DRY 규칙 (CRITICAL)**
- CRITICAL: 동일한 계산 로직(특히 수치 계산·검증·변환)이 2개 이상의 모듈에 나타나면 즉시 공용 모듈로 추출한다.
- 이유: 각 구현의 엣지 케이스 처리(예: 0 나누기 정책, NaN 처리, 빈 리스트 반환값)가 시간이 지나며 미묘하게 달라지면 호출 위치에 따라 다른 결과가 나오는 조용한 버그가 발생한다.
- 적용: 함수 시그니처와 엣지 케이스 정책(0 나누기 → `None`/`0.0`/`raise` 중 무엇인지)을 한 모듈에서 명시적으로 결정하고, 다른 모듈은 그 함수를 import해서만 사용한다.

**C8-3. 스레드·요청 공유 상태 안전성 (CRITICAL)**
- CRITICAL: 요청 핸들러·스레드 간 공유되는 상태(캐시, 전역 딕셔너리, 모듈 레벨 변수)는 반드시 `threading.Lock` 또는 `threading.RLock`으로 보호한다.
- CRITICAL: Flask·FastAPI 등 다중 스레드 WSGI/ASGI 환경에서 모듈 전역 dict를 `global` 키워드로 읽기/쓰기 하는 코드는 금지한다.
- 권장: 공유 상태는 별도 클래스로 캡슐화하고 읽기/쓰기 메서드만 노출 (Repository 패턴). 향후 DB·Redis 전환 시 호출부 변경 없이 구현만 교체할 수 있다.
  ```python
  from threading import RLock

  class AppCache:
      def __init__(self) -> None:
          self._data: dict[str, object] = {}
          self._lock = RLock()

      def get(self, key: str) -> object | None:
          with self._lock:
              return self._data.get(key)

      def set(self, key: str, value: object) -> None:
          with self._lock:
              self._data[key] = value
  ```
- 검증: C5의 동시성 테스트(ThreadPoolExecutor로 N개 스레드 동시 호출) 의무.

**C8-4. API 라우트 검증 일관성 (CRITICAL)**
- CRITICAL: 같은 앱(Flask/FastAPI 등)의 모든 API 엔드포인트는 동일한 필수 파라미터 검증 패턴을 사용한다. 일부 라우트만 검증하고 다른 라우트는 검증 없이 통과시키는 혼재 패턴 금지.
- 권장 패턴:
  1. 모듈 상수로 required 키 목록 정의 — `RUN_REQUIRED_KEYS = ("symbol", "start", "end", "envelope")`
  2. 공용 헬퍼로 검증 — `validate_payload(payload, required_keys)` 한 함수가 누락 시 400 응답 객체 반환
  3. 모든 라우트가 같은 헬퍼를 호출 — 인라인 if 검증 금지
- 이유: 검증 패턴이 라우트마다 다르면 한 곳을 고쳐도 다른 곳은 누락된다. 보안·검증 정책의 단일 진실 원천(SSoT) 확보.

**C8-5. 정적 타입 검사로 잠복 버그 차단 (권장)**
- 권장: `mypy . --ignore-missing-imports`를 개발 루프와 CI에 포함한다.
- 이유: 다음과 같은 버그 클래스는 ruff·pytest로는 잡히지 않고 오직 mypy만 잡는다:
  - 잘못된 keyword 인자 이름 (`run_backtest(envelope_pct=0.05)`인데 함수 시그니처는 `upper_pct`/`lower_pct`만 받음)
  - 함수 호출 시 위치 인자 개수 불일치
  - `None` 반환 가능 함수의 결과를 곧바로 역참조
  - 타입 불일치(`str` 기대 자리에 `int` 전달)
- 적용: `if __name__ == "__main__":` 가드 안의 코드는 pytest가 실행하지 않으므로 `mypy`가 유일한 안전망이다. CLI 진입점·스크립트 파일에 특히 중요.

### C9. UI 디버깅 프로토콜

> stock_backtesting 프로젝트에서 `display:none` 컨테이너 안의 Plotly 차트 렌더링 버그를 JS 타이밍 수정으로 10회 이상 시도해 모두 실패하고, 결국 아키텍처 변경(`make_subplots(rows=2)`로 이미 보이는 figure에 서브플롯 삽입)으로 해결한 사건에서 도출한 규칙. UI 디버깅의 시간 낭비와 사용자 만족도 저하를 원천 차단한다.

**C9-1. 3회 실패 에스컬레이션 규칙 (CRITICAL)**
- CRITICAL: 같은 방향(예: JS timing 조정 — RAF, `Plotly.Plots.resize`, reflow, `setTimeout` 튜닝 등)으로 3회 이상 수정했는데도 동일 증상이 재현되면 즉시 멈춘다. 4번째 시도를 하지 않는다.
- CRITICAL: 더 많은 JS 코드를 쌓지 않는다. 덕지덕지 쌓인 타이밍 fix는 다음 디버깅을 더 어렵게 만들고, 진짜 원인을 가린다.
- CRITICAL: 사용자에게 명시적으로 보고한다 — "현재 접근(JS timing 조정)이 3회 실패해 막혔습니다. 구조적 대안을 제안드리겠습니다." 이후 C9-2 가설 사다리를 처음(아키텍처)부터 다시 탄다.
- 이유: 같은 방향의 반복 실패는 가설 자체가 잘못됐다는 신호다. 더 많은 코드를 쌓는 것은 문제가 아니라 새로운 부채를 만드는 행위다.

**C9-2. 가설 사다리 (CRITICAL)**
- CRITICAL: UI/차트 디버깅의 가설 우선순위는 **아키텍처 → 데이터 → JS 타이밍 → CSS** 순서다. 이 순서를 거꾸로 탐색하지 않는다.
  - **아키텍처**: 컨테이너 구조(display:none, visibility:hidden, width=0), DOM 삽입 시점, 렌더링 위치(이미 보이는 영역 vs 숨겨진 영역)
  - **데이터**: 차트에 전달된 데이터 형태(`x`, `y` 배열 길이·타입·축 종류 `category`/`linear`/`date`)
  - **JS 타이밍**: RAF, `Plotly.Plots.resize`, reflow, MutationObserver, `setTimeout` 등
  - **CSS**: 스타일 충돌, z-index, overflow
- CRITICAL: 각 단계에서 가설을 사용자에게 먼저 말로 보고하고 확인받은 뒤 구현한다. 가설 없이 코드를 수정하기 시작하지 않는다.
- CRITICAL: 세부 기술 조정(JS timing fix, RAF, resize)은 가장 나중에 시도한다. 아키텍처·데이터 가설을 모두 검토한 후에만 JS 타이밍을 의심한다.
- 이유: UI 버그의 다수는 아키텍처(특히 컨테이너 width=0)에서 비롯된다. JS 타이밍부터 들여다보면 진짜 원인은 영원히 숨고, 시간만 소모된다.

**C9-3. 애자일 UI 개발 (CRITICAL)**
- CRITICAL: UI/차트 변경은 **한 번에 하나씩** 진행한다. 여러 변경사항을 한꺼번에 구현하지 않는다.
- CRITICAL: 각 단계는 다음 4스텝을 따른다 — **계획 제시 → 구현 → 사용자 확인 → 다음 단계**. 사용자 확인 없이 다음 단계로 넘어가지 않는다.
- CRITICAL: 여러 변경사항을 한 커밋에 쌓지 않는다. 한 변경 = 한 확인 = 한 커밋.
- 이유: 한 번에 여러 변경을 쌓으면 어느 변경이 어떤 효과를 냈는지 분리할 수 없고, 회귀 발생 시 원인 추적 비용이 폭증한다. 사용자가 중간에 방향을 바꾸고 싶을 때도 작은 단위로 진행해야 빠르게 돌아갈 수 있다.

**C9-5. Plotly hovertemplate d3-format 부호 수정자 금지 (CRITICAL)**
- CRITICAL: Plotly hovertemplate에서 `%{y:+.2f}` 같은 **d3-format 부호 수정자(`+`)**를 사용하지 않는다. Plotly Bar trace에서 값이 정확히 `0`일 때 소수점과 부호가 모두 사라지고 `0`으로만 렌더링된다(d3/Plotly 라이브러리 버그). Scatter trace에서도 동일 버그 잠재.
- 이유: `%{y:+.2f}`는 Plotly가 d3-format을 클라이언트(JS)에서 해석할 때 `0.0`을 정수 `0`처럼 처리해 포맷을 무시한다. Python의 `f"{0.0:+.2f}" = "+0.00"`과 결과가 다르다.
- 올바른 방법: 부호 포함 소수점 포맷이 필요하면 **Python 서버에서 미리 포맷팅 후 `customdata`로 전달**한다.
  ```python
  # ❌ 금지
  hovertemplate=f"%{{x}}: %{{y:+.2f}}%<extra>Delta</extra>"
  # ✅ 올바른 방법
  delta_hover = [f"{d:+.2f}" if d is not None else "N/A" for d in delta_vals]
  go.Bar(..., customdata=delta_hover,
         hovertemplate="%{x}: %{customdata}%<extra>Delta</extra>")
  ```
- 검출: `grep -n '%{[^}]*:+' chart.py` — 부호 수정자가 포함된 hovertemplate 패턴 즉시 탐지. 또는 `test_no_d3_sign_format_in_hovertemplates` 테스트가 자동 검출.
- 적용 범위: 부호 없이 소수점만 필요한 `%{y:.2f}` 형식은 정상 동작하므로 허용.

**C9-4. Plotly display:none 금지 규칙 (CRITICAL)**
- CRITICAL: Plotly 차트(`type='category'` 포함 모든 축 타입)를 `display:none` 또는 `visibility:hidden` 상태인 컨테이너에 직접 그리지 않는다. 초기 렌더링 시점에 컨테이너가 화면에 보이지 않으면 그 안에 차트를 삽입하지 않는다.
- 이유: `display:none` 컨테이너는 width=0이 되어 모든 bar가 한 점으로 뭉치고, annotation이 우상단에 적층되는 현상이 발생한다. 이 증상은 JS(RAF, `Plotly.Plots.resize`, reflow 등)로 해결되지 않는다 — 초기 width=0 상태에서 layout이 한 번 확정되면 이후 resize가 정상 복구하지 못하는 케이스가 다수다.
- 올바른 방법:
  1. **이미 화면에 보이는 figure의 `make_subplots(rows=N)`으로 서브플롯에 삽입한다.** Python 측에서 figure를 합쳐서 한 번에 렌더하면 width 문제가 발생하지 않는다.
  2. 탭/accordion 안에 Plotly 차트가 반드시 있어야 한다면, 탭이 활성화된 직후 차트를 **최초 1회 생성**하거나(lazy init), 이미 그려진 차트는 탭 활성화 후 `Plotly.Plots.resize(div)`를 **단 한 번만** 호출한다(초기 렌더링이 아닌 resize만 호출).
  3. 모달 안 차트도 동일 — 모달이 화면에 표시된 직후 차트를 생성한다.
- 검출: 코드 리뷰 시 Plotly 차트 div가 `display:none` 또는 `hidden` 클래스가 적용된 부모 안에 있는지 grep으로 확인.

### C7b. Step별 AC(Acceptance Criteria) 차등화
- CRITICAL: 커버리지 검증(`pytest --cov-fail-under=70`)은 **Tests step에서만** required다. 그 외 step(DB 스키마, Backend Core, Server 레이어, Frontend)에서는 `ruff check .` + 해당 step 기능 동작 확인까지만 요구한다.
- CRITICAL: 이유: DB 스키마 step에서 억지로 70% 커버리지를 맞추려 하면 무의미한 테스트가 생성된다. 커버리지는 Tests step에서 전체를 통과하면 된다.
- CRITICAL: Tests step이 아닌 step의 표준 AC: `ruff check . && python -c "from src.{모듈} import *"` (임포트 오류 없음 확인)
- CRITICAL: Tests step의 표준 AC: `pytest --cov=src --cov-fail-under=70 && ruff check .`

---

## 워크플로우 — /gsd vs /harness

| 상황 | 사용할 도구 |
|------|------------|
| 프로젝트 인프라·가이드라인 셋업 | `/harness` |
| 새 프로젝트 시작 (GSD 상태 관리) | `/gsd:new-project` |
| Phase 단위 계획 수립 | `/gsd:plan-phase` |
| Phase 실행 | `/gsd:execute-phase` |
| 기존 프로젝트 기능 추가 (복잡, 여러 파일) | `/feature-dev` |
| 기존 프로젝트 기능 추가 (간단, 단일 파일) | `/gsd:fast` |
| 버그 수정 | `/gsd:debug` |
| 세션 현황 파악 | `/gsd:progress` |
| 세션 재개 | `/gsd:resume-work` |
| 세션 마무리 | `/gsd:session-report` |

> **원칙**: `/harness`는 인프라·가이드라인 셋업까지만. 실제 구현은 `/gsd:execute-phase` 또는 `/feature-dev`를 사용한다.

---

## 명령어

### harness 셋업
```bash
/harness                    # Claude Code 슬래시 커맨드 — 탐색→논의→인프라 셋업→위임
```

### GSD 실행
```bash
/gsd:new-project            # 프로젝트 상태 관리 시작
/gsd:plan-phase             # Phase 계획 수립
/gsd:execute-phase          # Phase 실행
source venv/bin/activate    # Python 프로젝트: Phase 실행 전 반드시 venv 활성화
```

### Python 프로젝트 (venv 격리 필수)
```bash
# 1. venv 최초 생성 (프로젝트 루트, 한 번만)
python3 -m venv venv

# 2. 활성화 — 모든 작업 전 반드시 수행
source venv/bin/activate          # Linux/macOS
# venv\Scripts\activate           # Windows

# 3. 의존성 설치
pip install -r requirements.txt -r requirements-dev.txt

# 4. 개발 루프
ruff check .                          # 린트 검사
ruff check --select I --fix .         # import 정렬
ruff format .                         # 포맷
mypy . --ignore-missing-imports       # 정적 타입 체크 (권장 — C2/C8-5)
pytest                                # 테스트
python main.py                        # 실행

# 5. 의존성 변경 후 버전 고정
pip freeze > requirements.txt

# 6. 비활성화
deactivate
```

### C/C++ 프로젝트
```bash
clang-format -i src/**/*.{c,cc,cpp,h,hpp}
clang-tidy src/**/*.{c,cc,cpp}
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

> 프로젝트 언어에 해당하지 않는 명령어 섹션은 이 CLAUDE.md에서 삭제한다.

---

## 새 프로젝트 시작 체크리스트

새 프로젝트를 `/coding/projects/{이름}/`에 복제한 직후 아래 순서로 진행한다.
**상세 절차는 `docs/QUICKSTART.md` 참조.**

### A. `/harness` 실행 전에 준비할 것 (환경 셋업)

- [ ] 1. (Python) `python3 -m venv venv && source venv/bin/activate`
- [ ] 2. (Python) `requirements.txt`, `requirements-dev.txt` 초안 작성 후 `pip install -r requirements-dev.txt`
- [ ] 3. `~/.claude/settings.json`에 `circuit-breaker.sh` 훅 등록 여부 확인 (QUICKSTART §0)

### B. `/harness` 실행 중 자동으로 채워지는 것 (논의 답변 기반)

`/harness` 슬래시 커맨드는 두 모드로 동작한다:

**신규 프로젝트 모드** (실행 코드 없음): 탐색 → Q0부터 1문1답 논의 → 인프라 셋업
**기존 프로젝트 모드** (실행 코드 있음): 탐색 → **핵심 파일 내용 분석 → 사용자 확인** → Q0(보완 서술) → 확정되지 않은 항목만 Q1~Q8 → 인프라 셋업

두 모드 모두 논의 후 자동 생성·채움:

- `docs/PRD.md` placeholder (§1~§7)
- `docs/ARCHITECTURE.md` (해당 언어 섹션만 남김)
- `docs/ADR.md` (ADR-100부터)
- `docs/UI_GUIDE.md` (Frontend 있을 때만)
- 이 `CLAUDE.md`의 프로젝트명·기술 스택·C7
- `.gitignore`, `.env.example`

### C. `/harness` 완료 후

- [ ] `git init && git add . && git commit -m "chore: project skeleton"`
- [ ] `/gsd:new-project` 또는 `/gsd:plan-phase`로 Phase 설계 시작
