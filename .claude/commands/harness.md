이 프로젝트는 Harness 프레임워크를 사용한다. `/harness`는 **가이드라인 제시 + 프로젝트 인프라 셋업**까지만 수행한다. 실제 기능 구현은 `/gsd:new-project`, `/gsd:plan-phase`, `/gsd:execute-phase`, `/feature-dev`로 위임한다.

---

## /harness 의 역할과 한계 — 먼저 읽는다

**할 일**
- 기존 docs·코드를 탐색해 프로젝트 현황을 파악한다.
- 사용자와 기술 스택·실행 형태·데이터·보안 등 핵심 결정을 한 번에 논의한다.
- 프로젝트 루트에 필요한 인프라(docs/, CLAUDE.md, .gitignore, .env.example, hooks)를 생성하거나 보완한다.
- 이후 개발을 위임할 곳(`/gsd:new-project`, `/gsd:plan-phase`, `/feature-dev`)을 안내한다.

**안 하는 일**
- 기능 구현 코드 작성 (src/, main.py 등 어떤 실행 코드도 생성하지 않는다)
- phases/ 디렉토리 자동 생성, step*.md 파일 생성
- Phase 자동 실행 (execute.py는 폐기됐다 — 존재하지 않는다)

위 경계를 벗어나는 요청이 오면 "해당 작업은 /gsd 또는 /feature-dev의 영역입니다"라고 안내하고 중단한다.

---

## 워크플로우 — 4단계

### 1. 탐색

프로젝트 루트의 현황을 파악한다. 아래를 확인하고 한 줄 요약을 사용자에게 보고한다:

- 구현 코드 존재 여부 (`src/`, `main.py`, `*.ts`, `package.json` 등)
- `docs/` 하위 문서 상태 (PRD.md, ARCHITECTURE.md, ADR.md)
- CLAUDE.md 여부 및 placeholder 잔존 여부
- `.gitignore`, `.env.example`, `venv/` 상태 (Python 프로젝트)
- GSD `.planning/` 존재 여부 (GSD와 연계된 프로젝트인지)

필요 시 Explore 서브에이전트를 병렬로 사용한다.

---

### 2. 논의 — Human In The Loop (순차 인터랙티브)

**규칙**: 질문은 반드시 **1개씩** 순서대로 한다. 사용자 답변을 받은 뒤에만 다음 질문으로 넘어간다. 절대 여러 질문을 한 번에 묶어서 던지지 않는다.

탐색(1단계)에서 코드를 이미 읽었다면 Recommended 선택지를 추론해 `★` 표시한다. 답변은 모두 모아서 마지막에 `docs/PRD.md`와 `CLAUDE.md`에 기록한다.

#### 질문 포맷 (매 질문마다 이 형식을 따른다)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q{N}/{총개수}  {질문 제목}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) {선택지}
  2) {선택지}  ★ Recommended
  3) {선택지}
  ...
  직접 입력도 가능합니다.

번호 또는 답변 입력 →
```

#### Q1. 실행 형태

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q1/7  이 프로젝트의 실행 형태는?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) CLI 스크립트     — python main.py 실행 후 종료
  2) 웹 서버 + UI     — Flask/FastAPI + 프론트엔드
  3) 웹 서버 (API만)  — HTTP 엔드포인트, 프론트엔드 없음
  4) 데몬/백그라운드  — cron, systemd 등 상시 실행
  5) 라이브러리 모듈  — 다른 프로젝트에서 import
  6) 기타 (직접 입력)

번호 또는 답변 입력 →
```

#### Q2. 실행 환경

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q2/7  실행 환경은?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) 로컬 전용        — 개발자 PC에서만 실행  ★ Recommended
  2) 서버 배포        — Linux 서버
  3) Docker 컨테이너
  4) 클라우드         — AWS / GCP / Azure
  5) 크로스플랫폼 (직접 입력)

번호 또는 답변 입력 →
```

#### Q3. 데이터 영속성

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q3/7  데이터를 어떻게 저장하나요?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) 없음             — 메모리/임시 처리만
  2) 파일             — JSON / CSV / SQLite 파일
  3) RDB              — PostgreSQL / MySQL / SQLite (ORM)
  4) NoSQL            — MongoDB / Redis / 기타
  5) 혼합 (직접 입력)

번호 또는 답변 입력 →
```

#### Q4. 외부 API / 시크릿

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q4/7  외부 API를 호출하나요?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) 없음
  2) 있음 — API 이름과 .env 키 이름을 알려주세요
           (예: "Yahoo Finance API, YAHOO_API_KEY")

번호 또는 답변 입력 →
```

#### Q5. 인증/인가 (Q1에서 웹 서버를 선택한 경우에만 묻는다. 아니면 건너뛴다)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q5/7  사용자 인증이 필요한가요?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) 없음             — 단일 사용자 / 내부 도구  ★ Recommended
  2) API Key
  3) JWT (stateless)
  4) Session 쿠키 (stateful)
  5) OAuth            — Google / GitHub / 기타

번호 또는 답변 입력 →
```

#### Q6. Frontend (Q1에서 웹 서버+UI를 선택한 경우에만 묻는다. 아니면 건너뛴다)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q6/7  프론트엔드 구성은?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  프레임워크:
  1) Jinja2 서버 렌더링  ★ Recommended (Python 프로젝트)
  2) React (Vite)
  3) Next.js
  4) Vue
  5) Svelte
  6) 기타 (직접 입력)

  스타일링 (프레임워크 선택 후 이어서):
  1) Tailwind CSS  ★ Recommended
  2) CSS Modules
  3) 기본 CSS
  4) 기타

번호 또는 답변 입력 →
```

#### Q7. 언어 구성

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q7/7  언어 구성은?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) Python만          ★ Recommended
  2) TypeScript만
  3) Python + TypeScript (풀스택)
  4) C/C++만
  5) 기타 (직접 입력)

번호 또는 답변 입력 →
```

#### 논의 완료 후 처리

모든 답변을 받으면 아래 형식으로 **결정 요약을 출력하고 승인을 요청**한다. 승인 전까지 인프라 생성을 시작하지 않는다.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
결정 요약 — 확인 후 진행합니다
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  실행 형태:  {답변}
  실행 환경:  {답변}
  데이터:     {답변}
  외부 API:   {답변}
  인증:       {답변 또는 해당없음}
  Frontend:   {답변 또는 해당없음}
  언어:       {답변}

이대로 인프라 셋업을 진행할까요? (y / 수정할 항목 번호)
```

---

### 3. 인프라 셋업

사용자 승인 후, 아래를 생성하거나 보완한다. **기존 파일을 덮어쓸 때는 반드시 사용자에게 먼저 확인받는다.**

#### 3-1. docs/ 문서
- `docs/PRD.md` — 논의 답변을 섹션별로 채워 넣는다. 특히:
  - §1 목표, §2 사용자·실행 형태, §3 MVP 기능(최대 5개), §4 제외 사항, §5 DoD, §7 에러 케이스
- `docs/ARCHITECTURE.md` — 해당 언어 섹션만 남기고 나머지 삭제 (Python만이면 C/C++ 섹션 삭제 등)
- `docs/ADR.md` — ADR-001~015 기본값 유지. 이번 논의의 특수 결정은 ADR-100부터 추가
- `docs/UI_GUIDE.md` — UI 없으면 삭제, CLI만이면 CLI 섹션만 남김

기존 프로젝트라면 현재 코드 구조를 역추적해 작성한다.

#### 3-2. CLAUDE.md (프로젝트 규칙)
- 프로젝트명, 기술 스택 placeholder를 채운다
- 해당하지 않는 언어 섹션 삭제 (Python만이면 C2b TS, C3 C/C++ 삭제 등)
- C7(프로젝트 고유 규칙) — 이번 논의에서 나온 프로젝트 특수 제약을 기록

#### 3-3. 메타 파일
- `.gitignore` — 언어별 필수 항목 확인 (venv/, __pycache__/, .env, node_modules/ 등)
- `.env.example` — 2-4에서 수집한 시크릿 키 이름만 (실제 값 없이)
- `.env` — `.env.example` 복사본 안내 (실제 값은 사용자가 채움). **git에 커밋되지 않는지 반드시 확인**
- `requirements.txt` + `requirements-dev.txt` + `pyproject.toml` (Python 프로젝트)
- `package.json` + `tsconfig.json` + `biome.json` (TypeScript 프로젝트)

#### 3-4. 훅 검증 (Claude Code 품질 가드)
- 전역 `~/.claude/settings.json`의 hooks 섹션에 `circuit-breaker.sh`, `dangerous-cmd-guard.sh`, `tdd-guard.sh`가 등록되어 있는지 확인한다
- 미등록 시 `harness_framework/docs/QUICKSTART.md §0`의 절차를 사용자에게 안내한다

#### 3-5. 첫 커밋 (신규 프로젝트만)
```bash
git init
git add CLAUDE.md docs/ .gitignore .env.example README.md
git commit -m "chore: project skeleton"
```

**절대 금지**: src/, main.py, *.ts 등 실제 기능 코드 생성 — 이는 `/feature-dev` 또는 `/gsd:execute-phase`의 영역이다.

---

### 4. 위임 — 다음 단계 안내

인프라 셋업이 끝나면 반드시 아래 형식으로 종료한다:

```
harness 셋업 완료.
생성/보완된 파일:
  - docs/PRD.md, docs/ARCHITECTURE.md, docs/ADR.md
  - CLAUDE.md (프로젝트 규칙, placeholder 채워짐)
  - .gitignore, .env.example, [requirements.txt | package.json]
  - (옵션) 첫 커밋: chore: project skeleton

다음 단계:
  · Phase 단위 계획 수립 → /gsd:new-project 또는 /gsd:plan-phase
  · 개별 기능 개발       → /feature-dev
  · 간단한 수정          → /gsd:fast
  · Phase 실행           → /gsd:execute-phase

harness는 여기까지입니다. 실제 구현은 위 명령으로 진행하세요.
```

---

## 참고: Phase 설계 패턴 (GSD plan-phase에서 참고)

`/gsd:plan-phase`에서 Phase 구조를 설계할 때 `docs/PRD.md §10`의 패턴 A/B/C를 참고하라. harness가 제공하는 것은 템플릿과 가이드라인이며, 실제 Phase 실행·상태 관리는 GSD가 담당한다.

- **패턴 A** (CLI/스크립트): Step 0 핵심 로직 + 설정 / Step 1 Tests
- **패턴 B** (백엔드 API): Step 0 DB / Step 1 Backend Core / Step 2 Server / Step 3 Tests
- **패턴 C** (풀스택): Step 0 DB / Step 1 Backend / Step 2 Server / Step 3 Frontend / Step 4 Tests
