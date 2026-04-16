# 프로젝트: {프로젝트명}

> `{중괄호}`는 새 프로젝트 시작 시 반드시 채운다.
> `execute.py`가 매 step 실행마다 이 파일을 프롬프트에 주입한다 — placeholder를 채우지 않으면 AI가 혼란을 겪는다.
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
- CRITICAL: `execute.py`는 venv가 활성화된 셸에서 실행한다. 미활성화 시 `ModuleNotFoundError` 대량 발생 → SW In the Loop C6a의 blocked 조건 유발.
  ```bash
  # 올바른 실행 방법
  source venv/bin/activate
  python3 scripts/execute.py {task-name}
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
- CRITICAL: `execute.py`가 step 완료 시 자동 커밋 (feat + chore 2단계). 수동으로 포맷 깨뜨리지 않는다.

### C5. 서브에이전트 경계 (harness 실행 시)
- CRITICAL: 각 step은 독립된 Claude 인스턴스로 **순차** 실행된다. 병렬 실행이 아님. step 간 직접 통신은 없다.
- CRITICAL: 앞 step의 산출물은 `index.json`의 `summary` 필드로만 다음 step에 전달된다.
- CRITICAL: DB 스키마 step이 완료되기 전에 Backend Core step을 시작하지 않는다.
- CRITICAL: 서비스 인터페이스(함수 시그니처)가 확정되기 전에 서버 레이어(라우터) step을 시작하지 않는다.
- CRITICAL: API 계약(엔드포인트·요청/응답 형식)이 확정되기 전에 프론트엔드 step을 시작하지 않는다.
- CRITICAL: 테스트 step은 모든 구현 step이 완료된 후에 시작한다.
- CRITICAL: 각 step은 자신의 산출물 요약을 `summary` 필드에 한 줄로 반드시 기록한다. summary가 없으면 다음 step이 컨텍스트 없이 실행된다.
- CRITICAL: 권장 step 순서 — DB 스키마 → Backend Core → Server 레이어 → Frontend → Tests. 해당 없는 step은 생략한다.

### C6. 테스트 및 완료 처리
- CRITICAL: 테스트 없이 기능을 `completed`로 마킹하지 않는다.
- CRITICAL: step의 Acceptance Criteria 커맨드가 실제로 통과해야 `status: completed`로 업데이트한다.
- CRITICAL: 재시도는 **횟수(최대 3회) + 동일 에러 반복 감지** 이중 제한이다.
- CRITICAL: 에러 메시지 상위 3줄이 직전 시도와 동일하면 "동일 에러"로 간주한다. 단순 재시도가 아니라 반드시 **전략을 변경**해야 한다.

### C6a. SW In the Loop 디버깅 타임아웃
- CRITICAL: 같은 에러가 2회 연속 반복되면 preamble에 "**전략 변경 필수**" 경고가 주입된다. 이 경고가 보이면 다른 접근법을 반드시 선택한다.
  - 라이브러리 버전 문제 → 다른 라이브러리 또는 버전 고정
  - 테스트 실패 → 더 작은 단위로 분리해 최소 재현 케이스부터 수정
  - `ModuleNotFoundError` → venv 활성화 상태 재확인, `pip install` 재실행
  - import 경로 에러 → 프로젝트 구조와 `sys.path` 재확인
- CRITICAL: 동일 에러 3회 → `status: blocked`로 전환. `blocked_reason`에 "동일 에러 N회 반복: {에러 요약}. 사용자 개입 필요" 기록. 실행 중단.
- CRITICAL: 60초 이내 즉시 실패는 "전략 탐색"으로 간주해 재시도 카운트를 소진하지 않는다 (빠른 탐색 허용).
- CRITICAL: blocked 해제는 사용자가 직접 수행한다. `phases/{task}/index.json`에서 해당 step의 `status`를 `"pending"`으로, `blocked_reason`을 삭제한 뒤 `execute.py`를 재실행.

### C7. 프로젝트 특화 규칙 (새 프로젝트 시작 시 작성)
- CRITICAL: {프로젝트 고유의 절대 규칙 — 없으면 이 섹션 삭제}

### C7b. Step별 AC(Acceptance Criteria) 차등화
- CRITICAL: 커버리지 검증(`pytest --cov-fail-under=70`)은 **Tests step에서만** required다. 그 외 step(DB 스키마, Backend Core, Server 레이어, Frontend)에서는 `ruff check .` + 해당 step 기능 동작 확인까지만 요구한다.
- CRITICAL: 이유: DB 스키마 step에서 억지로 70% 커버리지를 맞추려 하면 무의미한 테스트가 생성된다. 커버리지는 Tests step에서 전체를 통과하면 된다.
- CRITICAL: Tests step이 아닌 step의 표준 AC: `ruff check . && python -c "from src.{모듈} import *"` (임포트 오류 없음 확인)
- CRITICAL: Tests step의 표준 AC: `pytest --cov=src --cov-fail-under=70 && ruff check .`

### C8. 테스트 완결성 및 회귀 방지
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

---

## 워크플로우 — /gsd vs /harness

| 상황 | 사용할 도구 |
|------|------------|
| 새 프로젝트 MVP 전체 빌드 | `/harness` → `execute.py` |
| 새 프로젝트 초기 설정 | `/gsd:new-project` |
| 기존 프로젝트 기능 추가 (복잡, 여러 파일) | `/feature-dev` |
| 기존 프로젝트 기능 추가 (간단, 단일 파일) | `/gsd:fast` |
| 버그 수정 | `/gsd:debug` |
| 세션 현황 파악 | `/gsd:progress` |
| 세션 재개 | `/gsd:resume-work` |
| 세션 마무리 | `/gsd:session-report` |

> **원칙**: `/harness`는 MVP 초기 빌드(Phase 단위 자동 실행)에 쓰고, 이후 일상 개발은 `/gsd` 워크플로우를 따른다.

---

## 명령어

### harness 실행
```bash
/harness                                      # Claude Code 슬래시 커맨드 — 탐색→논의→phase 설계
source venv/bin/activate                      # 반드시 먼저 활성화
python3 scripts/execute.py {task-name}        # task 순차 실행
python3 scripts/execute.py {task-name} --push # 실행 후 원격 push
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
**첫 `/harness` 또는 `execute.py` 실행 전에 모두 완료해야 한다.**
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
