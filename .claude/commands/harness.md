이 프로젝트는 Harness 프레임워크를 사용한다. 아래 워크플로우에 따라 작업을 진행하라.

---

## 워크플로우

### A. 탐색

`/docs/` 하위 문서(PRD, ARCHITECTURE, ADR 등)를 읽고 프로젝트의 기획·아키텍처·설계 의도를 파악한다. 필요시 Explore 에이전트를 병렬로 사용한다.

### B. 논의 (Human In The Loop — 필수)

탐색(A)에서 PRD/ARCHITECTURE를 읽은 뒤, 아래 체크리스트를 **한 번에 묶어서** 사용자에게 제시한다.
PRD에서 명확히 읽을 수 없는 항목은 **절대 자율 판단하지 않는다.**
모든 답변은 마지막에 `phases/decisions.md`에 기록한다 (이 파일은 execute.py 가드레일에 자동 주입됨).

---

#### B-1. 실행 형태 (필수 — 이것이 패턴 A/B/C를 결정)

다음 중 어떤 형태인가요?
- [ ] **CLI 스크립트** — `python main.py`처럼 실행 후 종료
- [ ] **데몬 / 백그라운드** — cron, systemd, supervisor 등 상시 실행
- [ ] **웹 서버 (API만)** — HTTP 엔드포인트, Frontend 없음
- [ ] **웹 서버 + Frontend UI** — API + React/Vue/Svelte 등
- [ ] **데스크톱 GUI** — Tkinter, Qt, Electron 등
- [ ] **라이브러리** — 다른 프로젝트에서 import 하는 모듈

> CLI/스크립트 → **패턴 A** | API 서버 → **패턴 B** | 풀스택 → **패턴 C**

#### B-2. 실행 환경 (필수)

- 로컬(개발자 PC)에서만 실행 / 서버 배포 / Docker 컨테이너 / 클라우드
- 대상 OS: Linux / macOS / Windows / 크로스플랫폼

#### B-3. 데이터 영속성 (필수)

데이터를 저장해야 하나요?
- [ ] **없음** — 메모리 또는 임시 처리만
- [ ] **파일** — JSON/CSV/SQLite 파일 방식
- [ ] **RDB** — PostgreSQL / MySQL / SQLite (SQLAlchemy/raw SQL)
- [ ] **NoSQL** — MongoDB / Redis / 기타

#### B-4. 외부 API / 시크릿 (필수)

외부 서비스를 호출하나요?
- 호출하는 API 목록과 인증 방식(API Key / OAuth / Token / 없음)을 나열해주세요.
- `.env`에 들어갈 시크릿 키 이름을 확인합니다: (예: `OPENAI_API_KEY`, `TELEGRAM_BOT_TOKEN`)

#### B-5. 인증/인가 (웹 서버인 경우 필수)

사용자 인증이 필요한가요?
- [ ] **없음** (단일 사용자 / 내부 도구)
- [ ] **API Key**
- [ ] **JWT** (stateless)
- [ ] **Session 쿠키** (stateful)
- [ ] **OAuth** (Google / GitHub / 기타)

#### B-6. Frontend (UI가 있는 경우 필수)

- 프레임워크: React(Vite) / Next.js / Vue / Svelte / 서버 렌더링(Jinja 등) / 없음
- 스타일링: Tailwind / CSS Modules / styled-components / 기본 CSS

#### B-7. 언어 구성 (필수)

- [ ] Python만
- [ ] TypeScript/JavaScript만
- [ ] C/C++만
- [ ] Python + TypeScript (풀스택)
- [ ] 기타 혼합

> Python+TS 혼합이면 `backend/` + `frontend/` 폴더 분리 구조를 권장.

#### B-8. 그 외 확인 사항

- 기존 코드에 기능을 추가하는 건가요, 새로 만드는 건가요?
- 로깅/모니터링 요구사항이 있나요? (stdout만 / 파일 로그 / 외부 알림)
- 배포/운영 특수 요구사항이 있나요?

---

#### B-9. 패턴 확정 및 decisions.md 기록 (의무)

위 답변을 바탕으로 phases 패턴을 도출해 사용자에게 제시하고 승인을 받는다:

| 조건 | 패턴 |
|------|------|
| CLI/스크립트 + DB 없음/파일 | 패턴 A |
| 웹 서버(API만) + DB 있음 | 패턴 B |
| 웹 서버 + Frontend UI | 패턴 C |
| 기타 | 사용자와 협의해 커스텀 구성 |

승인 후 `phases/decisions.md`에 아래 형식으로 기록한다 (execute.py가 가드레일에 자동 포함):

```markdown
# Decisions Log — {프로젝트명}
생성일: {날짜}

## 실행 형태: {결정값}
## 실행 환경: {결정값}
## DB: {결정값}
## 인증: {결정값}
## 외부 API: {목록}
## 시크릿 키: {목록}
## 언어 구성: {결정값}
## 선택한 패턴: 패턴 {A/B/C} — {이유 한 줄}
## 추가 결정 사항: {있으면 기록}
```

### C. Step 설계

사용자가 구현 계획 작성을 지시하면 여러 step으로 나뉜 초안을 작성해 피드백을 요청한다.

> **실행 방식**: 각 step은 독립 Claude 세션에서 **순차** 실행된다 (병렬 아님). step 간 통신은 `summary` 필드 하나뿐이다.

**권장 step 순서 (ADR-010):**
```
Step 0 — DB 스키마 (있는 경우)
Step 1 — Backend Core (서비스·저장소·도메인 로직)
Step 2 — Server 레이어 (API 라우터·미들웨어·진입점) — 웹 서비스인 경우
Step 3 — Frontend (UI) — 웹 UI가 있는 경우
Step N — Tests (항상 마지막)
```

> CLI/스크립트처럼 해당 없는 step은 생략한다. Backend Core + Server를 하나로 합쳐도 된다 (로직이 단순한 경우).

설계 원칙:

1. **Scope 최소화** — 하나의 step에서 하나의 레이어 또는 모듈만 다룬다. 여러 모듈을 동시에 수정해야 하면 step을 쪼갠다.
2. **자기완결성** — 각 step 파일은 독립된 Claude 세션에서 실행된다. "이전 대화에서 논의한 바와 같이" 같은 외부 참조는 금지한다. 필요한 정보는 전부 파일 안에 적는다.
3. **사전 준비 강제** — 관련 문서 경로와 이전 step에서 생성/수정된 파일 경로를 명시한다. 세션이 코드를 읽고 맥락을 파악한 뒤 작업하도록 유도한다.
4. **시그니처 수준 지시** — 함수/클래스의 인터페이스만 제시하고 내부 구현은 에이전트 재량에 맡긴다. 단, 설계 의도에서 벗어나면 안 되는 핵심 규칙(멱등성, 보안, 데이터 무결성 등)은 반드시 명시한다.
5. **AC는 실행 가능한 커맨드** — "~가 동작해야 한다" 같은 추상적 서술이 아닌 `npm run build && npm test` 같은 실제 실행 가능한 검증 커맨드를 포함한다.
6. **주의사항은 구체적으로** — "조심해라" 대신 "X를 하지 마라. 이유: Y" 형식으로 적는다.
7. **네이밍** — step name은 kebab-case slug로, 해당 step의 핵심 모듈/작업을 한두 단어로 표현한다 (예: `project-setup`, `backend-core`, `server-layer`, `frontend-ui`, `tests`).

### D. 파일 생성

사용자가 승인하면 아래 파일들을 생성한다.

#### D-1. `phases/index.json` (전체 현황)

여러 task를 관리하는 top-level 인덱스. 이미 존재하면 `phases` 배열에 새 항목을 추가한다.

```json
{
  "phases": [
    {
      "dir": "0-mvp",
      "status": "pending"
    }
  ]
}
```

- `dir`: task 디렉토리명.
- `status`: `"pending"` | `"completed"` | `"error"` | `"blocked"`. execute.py가 실행 중 자동으로 업데이트한다.
- 타임스탬프(`completed_at`, `failed_at`, `blocked_at`)는 execute.py가 상태 변경 시 자동 기록한다. 생성 시 넣지 않는다.

#### D-2. `phases/{task-name}/index.json` (task 상세)

```json
{
  "project": "<프로젝트명>",
  "phase": "<task-name>",
  "steps": [
    { "step": 0, "name": "project-setup", "status": "pending" },
    { "step": 1, "name": "core-types", "status": "pending" },
    { "step": 2, "name": "api-layer", "status": "pending" }
  ]
}
```

필드 규칙:

- `project`: 프로젝트명 (CLAUDE.md 참조).
- `phase`: task 이름. 디렉토리명과 일치시킨다.
- `steps[].step`: 0부터 시작하는 순번.
- `steps[].name`: kebab-case slug.
- `steps[].status`: 초기값은 모두 `"pending"`.

상태 전이와 자동 기록 필드:

| 전이 | 기록되는 필드 | 기록 주체 |
|------|-------------|----------|
| → `completed` | `completed_at`, `summary` | Claude 세션 (summary), execute.py (timestamp) |
| → `error` | `failed_at`, `error_message` | Claude 세션 (message), execute.py (timestamp) |
| → `blocked` | `blocked_at`, `blocked_reason` | Claude 세션 (reason), execute.py (timestamp) |

`summary`는 step 완료 시 산출물을 한 줄로 요약한 것으로, execute.py가 다음 step 프롬프트에 컨텍스트로 누적 전달한다. 따라서 다음 step에 유용한 정보(생성된 파일, 핵심 결정 등)를 담아야 한다.

`created_at`은 execute.py가 최초 실행 시 task 레벨에 한 번만 기록한다. step 레벨의 `started_at`도 execute.py가 각 step 시작 시 자동 기록한다. 생성 시 넣지 않는다.

#### D-3. `phases/{task-name}/step{N}.md` (각 step마다 1개)

```markdown
# Step {N}: {이름}

## 읽어야 할 파일

먼저 아래 파일들을 읽고 프로젝트의 아키텍처와 설계 의도를 파악하라:

- `/docs/ARCHITECTURE.md`
- `/docs/ADR.md`
- {이전 step에서 생성/수정된 파일 경로}

이전 step에서 만들어진 코드를 꼼꼼히 읽고, 설계 의도를 이해한 뒤 작업하라.

## 작업

{구체적인 구현 지시. 파일 경로, 클래스/함수 시그니처, 로직 설명을 포함.
코드 스니펫은 인터페이스/시그니처 수준만 제시하고, 구현체는 에이전트에게 맡겨라.
단, 설계 의도에서 벗어나면 안 되는 핵심 규칙은 명확히 박아넣어라.}

## Acceptance Criteria

```bash
npm run build   # 컴파일 에러 없음
npm test        # 테스트 통과
```

## 검증 절차

1. 위 AC 커맨드를 실행한다.
2. 아키텍처 체크리스트를 확인한다:
   - ARCHITECTURE.md 디렉토리 구조를 따르는가?
   - ADR 기술 스택을 벗어나지 않았는가?
   - CLAUDE.md CRITICAL 규칙을 위반하지 않았는가?
3. 결과에 따라 `phases/{task-name}/index.json`의 해당 step을 업데이트한다:
   - 성공 → `"status": "completed"`, `"summary": "산출물 한 줄 요약"`
   - 수정 3회 시도 후에도 실패 → `"status": "error"`, `"error_message": "구체적 에러 내용"`
   - 사용자 개입 필요 (API 키, 외부 인증, 수동 설정 등) → `"status": "blocked"`, `"blocked_reason": "구체적 사유"` 후 즉시 중단

## 금지사항

- {이 step에서 하지 말아야 할 것. "X를 하지 마라. 이유: Y" 형식}
- 기존 테스트를 깨뜨리지 마라
```

### E. 실행

```bash
python3 scripts/execute.py {task-name}        # 순차 실행
python3 scripts/execute.py {task-name} --push  # 실행 후 push
```

execute.py가 자동으로 처리하는 것:

- `feat-{task-name}` 브랜치 생성/checkout
- 가드레일 주입 — CLAUDE.md + docs/*.md 내용을 매 step 프롬프트에 포함
- 컨텍스트 누적 — 완료된 step의 summary를 다음 step 프롬프트에 전달
- 자가 교정 — 실패 시 최대 3회 재시도하며, 이전 에러 메시지를 프롬프트에 피드백
- 2단계 커밋 — 코드 변경(`feat`)과 메타데이터(`chore`)를 분리 커밋
- 타임스탬프 — started_at, completed_at, failed_at, blocked_at 자동 기록

에러 복구:

- **error 발생 시**: `phases/{task-name}/index.json`에서 해당 step의 `status`를 `"pending"`으로 바꾸고 `error_message`를 삭제한 뒤 재실행한다.
- **blocked 발생 시**: `blocked_reason`에 적힌 사유를 해결한 뒤, `status`를 `"pending"`으로 바꾸고 `blocked_reason`을 삭제한 뒤 재실행한다.
