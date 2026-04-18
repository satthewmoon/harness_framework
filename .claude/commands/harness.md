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

### 2. 논의 — Human In The Loop

PRD에서 명확히 읽을 수 없는 항목은 **절대 자율 판단하지 않는다.** 아래 항목을 한 번에 묶어 사용자에게 제시한다. 답변은 `docs/PRD.md`와 CLAUDE.md의 해당 섹션에 기록한다.

#### 2-1. 실행 형태 (필수)
- [ ] CLI 스크립트 — `python main.py`처럼 실행 후 종료
- [ ] 데몬 / 백그라운드 — cron, systemd, supervisor 등 상시 실행
- [ ] 웹 서버 (API만) — HTTP 엔드포인트, Frontend 없음
- [ ] 웹 서버 + Frontend UI — API + React/Vue/Svelte 등
- [ ] 데스크톱 GUI — Tkinter, Qt, Electron 등
- [ ] 라이브러리 모듈 — 다른 프로젝트에서 import 하는 모듈

#### 2-2. 실행 환경
- 로컬(개발자 PC) / 서버 배포 / Docker / 클라우드
- 대상 OS: Linux / macOS / Windows / 크로스플랫폼

#### 2-3. 데이터 영속성
- [ ] 없음 — 메모리/임시 처리만
- [ ] 파일 — JSON/CSV/SQLite
- [ ] RDB — PostgreSQL / MySQL / SQLite (ORM/raw SQL)
- [ ] NoSQL — MongoDB / Redis / 기타

#### 2-4. 외부 API / 시크릿
- 호출 API 목록, 인증 방식(API Key / OAuth / Token)
- `.env`에 들어갈 시크릿 키 이름 목록 (예: `OPENAI_API_KEY`, `TELEGRAM_BOT_TOKEN`)

#### 2-5. 인증/인가 (웹 서버인 경우)
- [ ] 없음 (단일 사용자 / 내부 도구)
- [ ] API Key / JWT / Session 쿠키 / OAuth

#### 2-6. Frontend (UI가 있는 경우)
- 프레임워크: React(Vite) / Next.js / Vue / Svelte / 서버 렌더링 / 없음
- 스타일링: Tailwind / CSS Modules / styled-components / 기본 CSS

#### 2-7. 언어 구성
- [ ] Python만 / TypeScript만 / C/C++만 / Python+TS 풀스택 / 기타 혼합

#### 2-8. 그 외
- 기존 코드에 기능 추가 vs 새로 만드는 건지
- 로깅/모니터링 요구사항 (stdout만 / 파일 로그 / 외부 알림)
- 배포/운영 특수 요구사항

답변을 받으면 핵심 결정 사항을 요약해 사용자 승인을 한 번 더 받는다.

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
