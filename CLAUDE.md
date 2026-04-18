# 프로젝트: {프로젝트명}

> `{중괄호}`는 새 프로젝트 시작 시 반드시 채운다.
> `/harness`가 이 파일을 읽고 프로젝트 규칙의 기준으로 삼는다. 실제 Phase 실행은 `/gsd:execute-phase`가 담당한다.
> 새 프로젝트 시작 절차는 맨 아래 "새 프로젝트 시작 체크리스트" 참조.

---

## 프로젝트 개요

- **이름**: {프로젝트명 (kebab-case, `projects/` 폴더명과 일치)}
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

### C2a. venv 격리 — Python 프로젝트 필수
- CRITICAL: Python 프로젝트는 프로젝트 루트에 `venv/` 폴더로 가상환경을 생성한다. 폴더명은 **`venv` 고정**. `.venv`, `env`, `virtualenv` 등 변형 금지.
- CRITICAL: 새 프로젝트 시작 시 **첫 `/harness` 실행 이전에** `python3 -m venv venv && source venv/bin/activate`를 수행한다.
- CRITICAL: **모든** `pip install` 명령은 venv 활성화 상태에서만 실행한다. 시스템 파이썬에 패키지를 설치하지 않는다.
- CRITICAL: 의존성은 용도별로 분리한다.
  - `requirements.txt` — 런타임 의존성 (예: `requests==2.31.0`, `python-dotenv==1.0.0`)
  - `requirements-dev.txt` — 린트·테스트 전용 (예: `ruff==0.4.0`, `pytest==7.4.0`)
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

### C6. GSD + harness 역할 분리
- CRITICAL: harness는 **인프라 셋업 전담** — docs/, CLAUDE.md, .gitignore, .env.example 생성까지만.
- CRITICAL: Phase 실행·상태 관리는 `/gsd:execute-phase`가 담당한다. harness가 직접 코드를 생성하거나 Phase를 실행하지 않는다.
- CRITICAL: harness가 생성한 `docs/PRD.md`는 GSD의 `.planning/ROADMAP.md`와 연계된다. `/gsd:new-project` 또는 `/gsd:plan-phase` 실행 시 docs/PRD.md를 입력 자료로 활용한다.
- CRITICAL: `/gsd:verify-work`로 UAT를 통과해야 GSD Phase를 완료로 처리한다.

### C7. 프로젝트 특화 규칙 (새 프로젝트 시작 시 작성)
- CRITICAL: {프로젝트 고유의 절대 규칙 — 없으면 이 섹션 삭제}

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
ruff check .                      # 린트 검사
ruff check --select I --fix .     # import 정렬
ruff format .                     # 포맷
pytest                            # 테스트
python main.py                    # 실행

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
**첫 `/harness` 실행 전에 모두 완료해야 한다.**
상세 절차는 `docs/QUICKSTART.md` 참조.

- [ ] 1. `docs/PRD.md` placeholder 전체 채우기 (목표, 기능, 제외 사항 최소)
- [ ] 2. `docs/ARCHITECTURE.md`에서 해당하지 않는 언어 섹션 삭제
- [ ] 3. `docs/ADR.md`에서 ADR-100부터 프로젝트 고유 결정 추가 (없으면 placeholder 삭제)
- [ ] 4. 이 `CLAUDE.md`의 프로젝트명·기술 스택·C7 채우기
- [ ] 5. `docs/UI_GUIDE.md`에서 웹 UI 없으면 "웹 프론트엔드" 섹션 삭제
- [ ] 6. `.env.example`에 필요한 환경변수 키 작성 → `.env`로 복사 후 실제 값 입력
- [ ] 7. `.gitignore` 확인 — `venv/`, `__pycache__/`, `.env`, `build/`, `*.pyc` 포함
- [ ] 8. **(Python)** `python3 -m venv venv && source venv/bin/activate`
- [ ] 9. **(Python)** `requirements.txt`, `requirements-dev.txt` 초안 작성 후 `pip install -r requirements-dev.txt`
- [ ] 10. `git init` → 첫 커밋 `chore: project skeleton` → `/harness` 시작
