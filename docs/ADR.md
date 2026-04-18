# Architecture Decision Records

> ADR-001~099는 `/coding` 대규칙에서 이미 결정된 사항이다. **변경하려면 새 ADR로 뒤집어라.**
> 프로젝트별 결정은 ADR-100부터 추가한다.

---

## 철학

1. **MVP 속도 우선** — 작동하는 최소 구현을 먼저. 최적화는 측정 후에.
2. **외부 의존성 최소화** — 표준 라이브러리로 가능하면 서드파티를 추가하지 않는다.
3. **가시성 > 영리함** — 한 번 읽어 이해되는 코드가 5% 짧은 코드보다 낫다.
4. **자동화된 검증** — 사람이 체크하는 것은 시간 문제. 린트·테스트를 hook에 박는다.
5. **서브에이전트 독립성** — 각 step은 완전히 독립적으로 실행 가능해야 한다. 암묵적 의존 금지.
6. **재현 가능한 환경** — 어느 머신에서도 `venv + requirements.txt`만으로 동일한 환경을 만들 수 있어야 한다.

---

## 확정된 결정 (ADR-001~015) — 변경 불가

### ADR-001: Python 린트 도구로 ruff 선택
- **결정**: `ruff`를 린트·포맷·import 정렬에 통합 사용. flake8 + black + isort 조합은 쓰지 않는다.
- **이유**: Rust 구현체로 10~100배 빠름. 설정 한 파일(`pyproject.toml`)에 통합. 도구 간 충돌 없음.
- **트레이드오프**: 일부 flake8 플러그인의 세부 규칙은 ruff 미지원. 필요 시 ADR로 재논의.

### ADR-002: Python 줄 길이 100자
- **결정**: PEP8 기본값 79자 대신 100자 채택.
- **이유**: 현대 모니터에서 79자는 과도하게 짧아 변수명 축약을 유발한다. 100자는 black/Django/Google 스타일과 호환.
- **트레이드오프**: 매우 좁은 터미널 분할에서 줄바꿈 가능. 대부분 환경에서 문제 없음.

### ADR-003: Python 3.10+ 최소 버전
- **결정**: Python 3.10 이상 요구. `match/case`, `X | Y` 유니온 타입, `ParamSpec` 사용 허용.
- **이유**: 최신 문법의 가독성 이점. 3.10은 2021-10 출시, 현재 모든 주요 배포판 기본 탑재.
- **트레이드오프**: 레거시 시스템(CentOS 7 등)에서는 직접 빌드 필요. 그런 환경은 타겟 제외.

### ADR-004: C/C++ 포맷은 Google 스타일 기반 + 변형
- **결정**: `.clang-format`에 `BasedOnStyle: Google` + `IndentWidth: 4` + `ColumnLimit: 100`.
- **이유**: Google 스타일은 가장 널리 알려진 레퍼런스. 다만 Google 기본 들여쓰기(2칸)는 Python과 일관성을 위해 4칸으로 override.
- **트레이드오프**: 순수 Google 스타일과 혼용된 코드베이스에서 포맷 차이 발생. 프로젝트 내부 일관성 우선.

### ADR-005: 환경변수 로딩은 python-dotenv
- **결정**: `.env` 파일 + `python-dotenv`로 로드. pydantic-settings의 자동 로드도 내부적으로 dotenv를 사용하므로 허용.
- **이유**: 업계 표준. CI/프로덕션에서는 .env 없이 OS 환경변수로 동일 코드 동작.
- **트레이드오프**: 런타임 파싱 비용. 무시 가능 수준.

### ADR-006: 가상환경은 venv (표준 라이브러리)
- **결정**: `python3 -m venv venv`로 프로젝트 루트에 생성. 폴더명 `venv` 고정 (`.venv`, `env`, `virtualenv` 등 변형 금지). poetry/pipenv/uv는 프로젝트별 필요 시 ADR-100+로 추가.
- **이유**: 추가 설치 불필요. 어떤 환경에서도 동일 동작. 학습 곡선 없음. CI/Docker에서도 동일 커맨드 사용.
- **필수 사용 절차**:
  1. 프로젝트 시작 시점 (**첫 `/harness` 실행 이전**)에 생성 → `python3 -m venv venv`
  2. 매 세션 시작마다 활성화 → `source venv/bin/activate` (Windows: `venv\Scripts\activate`)
  3. 의존성 설치는 항상 venv 활성화 상태에서 → `pip install -r requirements.txt -r requirements-dev.txt`
  4. `requirements.txt`(런타임)와 `requirements-dev.txt`(린트/테스트)로 분리
  5. 의존성 변경 시 즉시 `pip freeze > requirements.txt`로 버전 고정
  6. `.gitignore`에 `venv/` 포함 — **절대 커밋 금지**
- **execute.py와의 결합**: headless Claude 세션도 venv가 활성화된 셸에서 `execute.py`를 실행해야 한다. 미활성화 시 `ModuleNotFoundError` 대량 발생 → SW In the Loop blocked 조건 유발. 자세한 내용은 ARCHITECTURE.md "venv 격리 및 의존성 Lifecycle" 참조.
- **트레이드오프**: 의존성 해석 성능은 `uv`가 10배 이상 빠르다. 프로젝트 규모 확대 또는 다중 Python 버전 필요 시 ADR-006을 뒤집을 수 있음. 현재는 단순성 우선.

### ADR-007: 커밋 타입은 Conventional Commits 축약 5종
- **결정**: `feat | fix | refactor | docs | chore` 5종만 사용. `perf | style | test | build | ci`는 쓰지 않는다.
- **이유**: 종류가 적을수록 분류가 빠르고 일관됨. `chore`가 나머지를 흡수.
- **트레이드오프**: 세밀한 changelog 자동 생성 도구는 필요 시 옵션 확장.

### ADR-008: harness 2단계 커밋 구조 [deprecated 2026-04-18]
- **폐기 이유**: execute.py 제거(2026-04-18)로 비활성화. 커밋은 이제 `/gsd:execute-phase`의 원자적 커밋 규칙을 따른다.

### ADR-009: /gsd는 개발 워크플로우, /harness는 인프라·가이드라인 셋업 전용
- **결정**: 두 프레임워크를 역할에 따라 분리 사용한다. /harness는 프로젝트 인프라·가이드라인 셋업까지만. 실제 구현은 /gsd:execute-phase 또는 /feature-dev를 사용한다.
- **이유**: /gsd는 세션 관리·Context Rot 방지·Phase 단위 실행에 최적화. /harness는 docs 템플릿·코딩 규칙·품질 훅 제공에 집중. 두 도구는 상호 보완 관계.
- **트레이드오프**: 두 프레임워크의 개념을 모두 학습해야 함. CLAUDE.md의 워크플로우 표가 가이드 역할.

### ADR-010: 서브에이전트 독립 순차 실행 — DB→Backend Core→Server→Frontend→Test 순서 강제
- **결정**: harness phase 설계 시 아래 순서로 step을 분리한다. 각 step은 독립 Claude 인스턴스로 **순차** 실행되며(병렬 아님), 앞 step의 산출물을 index.json summary로만 수신한다.
  - Step 0: DB 스키마 (테이블/모델/마이그레이션)
  - Step 1: Backend Core (서비스·저장소·도메인 로직)
  - Step 2: Server 레이어 (API 라우터·미들웨어·진입점) — 웹 서비스인 경우
  - Step 3: Frontend (UI 컴포넌트·페이지) — 웹 UI가 있는 경우
  - Step 4: Tests (단위·통합·E2E)
  - CLI·스크립트처럼 해당 없는 step은 생략. 너무 크면 쪼갠다.
- **이유**: 인터페이스(스키마, 서비스 시그니처, API 계약)가 확정된 후에야 의존하는 레이어를 구현할 수 있다. Backend Core와 Server 레이어를 분리하면 비즈니스 로직이 HTTP 관심사에 오염되지 않는다. 독립 순차 실행은 Context Rot를 원천 차단하고 재실행 비용을 낮춘다.
- **트레이드오프**: step 간 직접 코드 공유 불가. summary 필드의 품질이 다음 step 결과에 직접 영향. CLI처럼 Server 레이어가 없으면 Backend Core만으로 충분하므로 5-step이 항상 필요한 것은 아니다.

### ADR-011: 재시도는 지수 백오프, 최대 3회
- **결정**: 네트워크·외부 API 에러 시 지수 백오프(1초→2초→4초)로 최대 3회 재시도. HTTP 4xx(클라이언트 에러)는 재시도 없음.
- **이유**: 즉시 재시도는 서버에 부하를 더함. 4xx는 재시도해도 동일 결과. 3회로 제한해 무한 루프 방지.
- **트레이드오프**: 일시적 5xx에서 총 7초 대기 발생. 실시간성이 중요한 경우 별도 ADR로 재논의.

### ADR-012: 예외 계층은 프로젝트 베이스 에러에서 상속
- **결정**: 모든 프로젝트 예외는 `ProjectBaseError`를 상속. `ConfigError`, `ExternalServiceError`, `DataError` 3종 최소 구성.
- **이유**: 최상위 catch에서 `except ProjectBaseError`로 프로젝트 에러 전체를 구분 처리 가능. `except Exception`의 과잉 catch 방지.
- **트레이드오프**: 외부 라이브러리 예외를 래핑해야 하는 보일러플레이트 증가.

### ADR-013: SQL은 파라미터 바인딩만, f-string SQL 금지
- **결정**: DB 쿼리는 파라미터 바인딩(`?`, `:name`)만 사용. 변수를 문자열 포맷으로 SQL에 삽입하는 것은 절대 금지.
- **이유**: SQL 인젝션 방지. 한 번의 실수가 데이터 전체 유출 또는 삭제로 이어짐.
- **트레이드오프**: 동적 쿼리(컬럼명·테이블명 동적 생성) 구현이 복잡해짐. 그 경우 allowlist 검증 후 사용.

### ADR-014: 로그에 민감정보 마스킹 필수
- **결정**: API 키, 토큰, 비밀번호를 로그에 출력할 때는 `{앞4자리}...{뒤4자리}` 형식으로 마스킹. 길이 8 이하면 `***`.
- **이유**: 로그 파일은 종종 공유되거나 외부로 전송됨. 민감정보 유출 방지.
- **트레이드오프**: 디버깅 시 실제 값 확인 불가. `--debug` 모드에서만 전체 값 출력하는 것은 명시적 동의 하에 허용.

### ADR-015: SW In the Loop 타임아웃 및 전략 변경 정책 [deprecated 2026-04-18]
- **폐기 이유**: execute.py 제거(2026-04-18)로 재시도·blocked 로직 폐기. 향후 재시도 정책은 GSD에서 별도 ADR로 기록.

### ADR-016: 테스트 피라미드 전략 — 단위:통합:E2E = 70:25:5, 커버리지 70% 기준
- **결정**: 단위 테스트 70%, 통합 테스트 25%, E2E 테스트 5% 비율을 목표로 테스트를 작성한다. 커버리지 최소 기준은 70%. `circuit-breaker.sh`가 `pytest --cov-fail-under=70`으로 자동 강제. 임계값은 `pyproject.toml [tool.coverage.report] fail_under`로 프로젝트별 조정 가능.
- **이유**: 단위 테스트는 빠르고 격리되어 있어 빈번한 실행에 적합하다. 통합 테스트는 실제 경계(DB, HTTP)를 검증하나 느리므로 전략적으로 작성한다. E2E는 비용이 크므로 핵심 사용자 플로우만. 커버리지 100% 요구는 비용 대비 효과가 낮다. 70%는 의미 있는 로직은 커버하면서 테스트 유지 비용을 합리적으로 유지하는 임계값이다.
- **트레이드오프**: 70%로는 일부 경로가 테스트되지 않을 수 있다. 위험도가 높은 모듈(인증, 결제)은 80~90%를 권장. 비율이 규범이 아닌 가이드라인임을 주지한다.

### ADR-017: 회귀 방지 정책 — 새 step 완료 전 전체 테스트 스위트 실행 의무화
- **결정**: harness step이 `completed`로 전환되기 위한 조건에 "전체 테스트 스위트 통과"를 포함한다. 새로 작성한 테스트만이 아니라 프로젝트의 모든 테스트(`pytest` 경로 지정 없이)가 통과해야 한다. `circuit-breaker.sh` Stop 훅이 이를 자동으로 검증한다.
- **이유**: step 단위 개발에서 가장 흔한 회귀 패턴은 "이번 step에서 건드린 코드만 테스트하고 기존 코드의 깨짐을 방치"하는 것이다. 전체 스위트 실행은 이를 원천 차단한다. 특히 harness 서브에이전트 아키텍처에서는 이전 step의 산출물이 summary만 전달되므로, 기존 테스트만이 유일한 회귀 감지 수단이다.
- **구현 위치**: `circuit-breaker.sh` — `pytest -q --tb=short` (pytest-cov 미설치 시) 또는 `pytest --cov --cov-fail-under={임계값}` (pytest-cov 설치 시)
- **트레이드오프**: 전체 스위트 실행으로 commit 전 대기 시간 증가. 테스트가 100개 넘어가면 수십 초 추가 소요. 허용 가능한 범위. 1000개 이상이면 병렬 실행(`pytest-xdist`)을 ADR-100+으로 추가.
- **연결**: CLAUDE.md C8, ARCHITECTURE.md "테스트 전략 및 회귀 방지" 섹션.

### ADR-018: TypeScript 린트·포맷 도구로 biome 권장, 테스트는 vitest/jest
- **결정**: TypeScript/JavaScript 프로젝트의 린트+포맷 통합 도구로 `biome`를 권장한다. ESLint + Prettier 조합도 허용하지만 biome가 기본. 테스트는 Vite 프로젝트는 `vitest`, Node 서버는 `jest` 또는 `node --test`.
- **이유**: biome는 Rust 구현체로 10~100배 빠름. 린트·포맷·import 정렬을 하나의 도구로. ADR-001(Python ruff)과 동일한 철학. vitest는 Vite 에코시스템과 자연스럽게 통합.
- **트레이드오프**: biome는 일부 ESLint 플러그인 규칙 미지원. ESLint 생태계 의존 프로젝트(Next.js 등)는 기존 ESLint 유지 가능.

---

## 프로젝트별 결정 (ADR-100부터 자유롭게 추가)

### ADR-100: {첫 번째 프로젝트 결정}
- **결정**: {뭘 선택했는지}
- **이유**: {왜}
- **트레이드오프**: {뭘 포기했는지}

### ADR-101: {두 번째 결정}
- **결정**:
- **이유**:
- **트레이드오프**:

---

## ADR 작성 가이드

- **번호**: 확정 결정은 001~099, 프로젝트별 결정은 100부터.
- **뒤집기**: 기존 ADR을 바꾸려면 **새 ADR을 작성**하고 구 ADR에 `**Superseded by ADR-NNN**` 표기.
- **삭제 금지**: ADR을 지우지 말고 "Deprecated" 상태로 남긴다 — 과거 맥락을 잃지 않기 위함.
- **간결성**: 결정·이유·트레이드오프 3줄이면 충분. 길어지면 ARCHITECTURE.md에 상세 기술하고 여기서는 참조만.
