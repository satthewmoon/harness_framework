이 프로젝트는 Harness 프레임워크를 사용한다. `/harness`는 **가이드라인 제시 + 프로젝트 인프라 셋업**까지만 수행한다.

---

## ⚡ 핵심 규칙 — 컨텍스트가 길어져도 이 3가지는 절대 잊지 않는다

> 1. **문서만 만든다** — `src/`, `main.py`, `*.py`, `*.ts` 구현 코드는 절대 생성하지 않는다
> 2. **질문은 1개씩** — 여러 질문을 한 번에 묶어서 던지지 않는다
> 3. **인프라 완료 후 위임** — `/gsd:plan-phase` 또는 `/feature-dev`로 넘긴다

위 3가지를 위반하려는 순간 즉시 멈추고 방향을 수정한다.

---

## /harness 의 역할과 한계

**할 일**: 탐색 → 1문1답 논의 → docs/·CLAUDE.md·.gitignore 생성/보완 → GSD 위임

**안 하는 일**
- 구현 코드 작성 (src/, main.py, app.py 등 일체)
- phases/ 자동 생성, step*.md 파일 생성
- Phase 자동 실행 (execute.py는 폐기됨 — 존재하지 않는다)

위 경계를 벗어나는 요청에는 "해당 작업은 /gsd 또는 /feature-dev의 영역입니다"라고 안내하고 중단한다.

---

## 워크플로우 — 4단계

### 1. 탐색

프로젝트 루트의 현황을 파악한다. 아래를 확인하고 한 줄 요약을 사용자에게 보고한다:

- 구현 코드 존재 여부 (`src/`, `main.py`, `*.ts`, `package.json` 등)
- `docs/` 하위 문서 상태 (PRD.md, ARCHITECTURE.md, ADR.md)
- CLAUDE.md 여부 및 placeholder 잔존 여부
- `.gitignore`, `.env.example`, `venv/` 상태 (Python 프로젝트)
- GSD `.planning/` 존재 여부

필요 시 Explore 서브에이전트를 사용한다.

> **[ SCOPE CHECK ]** 탐색이 끝났다. 이제 논의를 시작한다. 코드 분석이나 기능 제안은 하지 않는다.

---

### 2. 논의 — Human In The Loop (순차 인터랙티브)

**규칙**: 질문은 **1개씩** 순서대로 한다. 답변을 받은 뒤에만 다음으로 넘어간다.

탐색에서 코드를 읽었다면 Recommended(`★`)를 추론해 표시한다.
조건부 질문(Q6·Q7·Q8)은 해당 조건 아닌 경우 "→ Q{N} 건너뜀" 1줄 표기 후 다음으로 넘어간다.
답변은 모두 모아서 논의 완료 시 한 번에 `docs/PRD.md`와 `CLAUDE.md`에 기록한다.

#### 질문 포맷

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q{N}  {질문 제목}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) {선택지}
  2) {선택지}  ★ Recommended
  3) {선택지}

번호 또는 직접 입력 →
```

---

#### Q1. 언어 구성

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q1  언어 구성은?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) Python만
  2) TypeScript만
  3) Python + TypeScript (풀스택)
  4) C/C++만
  5) 기타 (직접 입력)

번호 또는 직접 입력 →
```

#### Q2. 실행 형태

Q1 답변에 따라 Recommended를 조정한다 (Python이면 CLI/Flask, TS이면 Node 서버 등).

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q2  실행 형태는?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) CLI 스크립트     — python main.py 실행 후 종료
  2) 웹 서버 + UI     — API + 프론트엔드
  3) 웹 서버 (API만)  — 프론트엔드 없음
  4) 데몬/백그라운드  — cron, systemd 등 상시 실행
  5) 기타 (직접 입력)

번호 또는 직접 입력 →
```

#### Q3. 실행 환경

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q3  실행 환경은?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) 로컬 전용        — 개발자 PC에서만 실행  ★ Recommended
  2) 서버 배포        — Linux 서버
  3) Docker 컨테이너
  4) 클라우드         — AWS / GCP / Azure
  5) 기타 (직접 입력)

번호 또는 직접 입력 →
```

#### Q4. 데이터 영속성

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q4  데이터를 어떻게 저장하나요?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) 없음             — 메모리/임시 처리만
  2) 파일             — JSON / CSV / SQLite 파일
  3) RDB              — PostgreSQL / MySQL / SQLite (ORM)
  4) NoSQL            — MongoDB / Redis / 기타
  5) 혼합 (직접 입력)

번호 또는 직접 입력 →
```

#### Q5. 외부 API / 시크릿

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q5  외부 API를 호출하나요?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) 없음
  2) 있음 — API 이름과 .env 키 이름을 알려주세요
           예: "Yahoo Finance API → YAHOO_API_KEY"

번호 또는 직접 입력 →
```

#### Q6. 인증/인가 ← Q2에서 웹 서버를 선택한 경우에만 묻는다. 아니면 "→ Q6 건너뜀"

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q6  사용자 인증이 필요한가요?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) 없음             — 단일 사용자 / 내부 도구  ★ Recommended
  2) API Key
  3) JWT (stateless)
  4) Session 쿠키 (stateful)
  5) OAuth            — Google / GitHub / 기타

번호 또는 직접 입력 →
```

#### Q7. Frontend 프레임워크 ← Q2에서 "웹 서버 + UI"를 선택한 경우에만 묻는다. 아니면 "→ Q7 건너뜀"

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q7  프론트엔드 프레임워크는?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) Jinja2 서버 렌더링  (Python 프로젝트, 간단한 UI)
  2) HTMX               (Python 프로젝트, 동적 UI)  ★ Recommended (Python)
  3) React (Vite)        (TypeScript 프로젝트)       ★ Recommended (TS)
  4) Next.js
  5) Vue
  6) Svelte
  7) 기타 (직접 입력)

번호 또는 직접 입력 →
```

#### Q8. Frontend 스타일링 ← Q7을 답한 경우에만 묻는다. 아니면 "→ Q8 건너뜀"

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q8  스타일링 방식은?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) Tailwind CSS  ★ Recommended
  2) CSS Modules
  3) 기본 CSS
  4) styled-components
  5) 기타 (직접 입력)

  ※ Jinja2/HTMX + Tailwind 조합: CDN 방식(JS 불필요) 또는 npm 빌드 선택 가능.

번호 또는 직접 입력 →
```

---

#### 논의 완료 — 결정 요약 및 승인

모든 질문이 끝나면 아래 형식으로 요약하고 승인을 요청한다. **승인 전까지 파일을 하나도 생성하지 않는다.**

수정할 항목이 있으면 해당 Q번호를 재질문하고 요약으로 돌아온다 (예: "3" 입력 시 Q3만 다시 묻고 요약 재출력).

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
결정 요약 — 확인 후 인프라 셋업을 시작합니다
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  언어:       {답변}
  실행 형태:  {답변}
  실행 환경:  {답변}
  데이터:     {답변}
  외부 API:   {답변}
  인증:       {답변 또는 해당없음}
  Frontend:   {답변 또는 해당없음}
  스타일링:   {답변 또는 해당없음}

y → 인프라 셋업 시작
번호 → 해당 항목 재질문
```

---

### 3. 인프라 셋업

> **[ PRE-FLIGHT CHECK ]** 셋업 시작 전 자기 점검:
> - 생성할 것: `docs/`, `CLAUDE.md`, `.gitignore`, `.env.example`, `README.md`
> - 절대 생성하지 않을 것: `src/`, `main.py`, `app.py`, `*.py` 구현 코드, `*.ts` 파일
> - 이 경계를 넘으려는 순간 즉시 멈춘다.

사용자 승인 후, 아래를 생성하거나 보완한다. **기존 파일을 덮어쓸 때는 사용자에게 먼저 확인받는다.**

#### 3-1. docs/ 문서
- `docs/PRD.md` — 논의 답변으로 섹션별 채우기. 핵심:
  - §1 목표, §2 사용자·실행 형태, §3 MVP 기능(최대 5개), §4 제외 사항, §5 DoD
  - §7 에러 케이스 — 실행 형태에 해당하는 항목만 작성 (DB 없으면 DB 연결 실패 항목 제거)
  - §10 Phase 가이드라인 — **삭제** (GSD의 역할, PRD에 불필요)
- `docs/ARCHITECTURE.md` — 해당 언어 섹션만 남기고 나머지 삭제
- `docs/ADR.md` — "공통 ADR은 harness_framework/docs/ADR.md 참조" 1줄 + ADR-100부터 프로젝트 고유 결정만 기록
- `docs/UI_GUIDE.md` — Frontend 없으면 파일 자체 삭제. Frontend 있으면 AI 슬롭 안티패턴 섹션 유지하고 이후 `/gsd:ui-phase` 작업 시 참조 안내

#### 3-2. README.md
- 프로젝트명, 한 줄 설명, 설치·실행 방법, 환경변수 목록 최소 구성으로 작성한다.
- 기존 README가 있으면 내용을 보완하고 덮어쓰기 전 사용자 확인.

#### 3-3. CLAUDE.md (프로젝트 규칙)
- 프로젝트명, 기술 스택 placeholder 채우기
- 해당하지 않는 언어 섹션 삭제 (Python만이면 C2b TS, C3 C/C++ 삭제 등)
- C7(프로젝트 고유 규칙) — 이번 논의에서 나온 특수 제약 기록

#### 3-4. 메타 파일
- `.gitignore` — 언어별 필수 항목 확인 (venv/, __pycache__/, .env, node_modules/ 등)
- `.env.example` — Q5에서 수집한 시크릿 키 이름만 (실제 값 없이)
- `requirements.txt` + `requirements-dev.txt` + `pyproject.toml` (Python)
- `package.json` + `tsconfig.json` + `biome.json` (TypeScript)

#### 3-5. 훅 검증 (Claude Code 품질 가드)
- `~/.claude/settings.json`의 hooks에 `circuit-breaker.sh`가 등록되어 있는지 확인
- 미등록 시 `harness_framework/docs/QUICKSTART.md §0` 절차를 사용자에게 안내

#### 3-6. 첫 커밋 (신규 프로젝트만)
```bash
git init
git add CLAUDE.md README.md docs/ .gitignore .env.example
# Python 프로젝트라면 추가:
git add requirements.txt requirements-dev.txt pyproject.toml
# TypeScript 프로젝트라면 추가:
git add package.json tsconfig.json biome.json
git commit -m "chore: project skeleton"
```

> **[ 생성 완료 체크 ]** 방금 만든 파일 목록을 훑어본다. `src/`, `main.py`, `app.py`, `.py` 구현 코드가 포함됐다면 즉시 삭제한다.

---

### 4. 위임 — 다음 단계 안내

> **[ HANDOFF ]** 인프라 셋업이 끝났다. 이제 구현은 내 역할이 아니다.

인프라 셋업이 끝나면 반드시 아래 형식으로 종료한다:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
harness 셋업 완료
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
생성/보완된 파일:
  - docs/PRD.md, docs/ARCHITECTURE.md, docs/ADR.md
  - README.md
  - CLAUDE.md (프로젝트 규칙)
  - .gitignore, .env.example
  - [requirements.txt | package.json] (해당 시)

다음 단계 (구현은 아래 명령으로):
  · Phase 계획 수립  →  /gsd:new-project  또는  /gsd:plan-phase
  · 기능 개발        →  /feature-dev
  · 간단한 수정      →  /gsd:fast

harness는 여기까지입니다.
```

---

## 참고: Phase 설계 패턴 (GSD plan-phase에서 참고용)

`/gsd:plan-phase`에서 Phase를 설계할 때 아래 패턴을 참고한다. 실행·상태 관리는 GSD가 담당한다.

- **패턴 A** (CLI/스크립트): Step 0 핵심 로직 / Step 1 Tests
- **패턴 B** (백엔드 API): Step 0 DB / Step 1 Backend Core / Step 2 Server / Step 3 Tests
- **패턴 C** (풀스택): Step 0 DB / Step 1 Backend / Step 2 Server / Step 3 Frontend / Step 4 Tests

자세한 내용은 `harness_framework/docs/ARCHITECTURE.md §Phase 설계 가이드라인` 참조.
