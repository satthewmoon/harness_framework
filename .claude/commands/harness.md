이 프로젝트는 Harness 프레임워크를 사용한다. `/harness`는 **가이드라인 제시 + 프로젝트 인프라 셋업**까지만 수행한다.

---

## ⚡ 핵심 규칙 — 컨텍스트가 길어져도 이 3가지는 절대 잊지 않는다

> 1. **문서만 만든다** — `src/`, `main.py`, `*.py`, `*.ts` 구현 코드는 절대 생성하지 않는다
> 2. **질문은 1개씩** — 여러 질문을 한 번에 묶어서 던지지 않는다
> 3. **인프라 완료 후 위임** — `/gsd:plan-phase` 또는 `/feature-dev`로 넘긴다

위 3가지를 위반하려는 순간 즉시 멈추고 방향을 수정한다.

---

## 🔄 세션 재개 — /compact 또는 /clear 이후

컨텍스트가 초기화된 후 `/harness` 세션을 재개할 때:

1. 위 ⚡ 핵심 규칙 3가지를 재확인한다
2. 사용자에게 진행 단계를 확인한다: `"논의 Q{N}까지 완료했었나요? Q{N+1}부터 재개합니다"`
3. 이미 완료된 단계(탐색·논의·인프라)는 건너뛰고 **중단된 지점부터** 시작한다
4. `/clear` 후에는 `CLAUDE.md`가 자동 재로드되지만 이 파일은 재로드되지 않으므로, 사용자가 `/harness`를 다시 입력해야 이 파일이 활성화된다

---

## /harness 의 역할과 한계

**할 일**: 탐색 → 1문1답 논의 → docs/·CLAUDE.md·.gitignore 생성/보완 → GSD 위임

**안 하는 일**
- 구현 코드 작성 (src/, main.py, app.py 등 일체)
- phases/ 자동 생성, step*.md 파일 생성
- Phase 자동 실행 (execute.py는 폐기됨 — 존재하지 않는다)

위 경계를 벗어나는 요청에는 "해당 작업은 /gsd 또는 /feature-dev의 영역입니다"라고 안내하고 중단한다.

---

## 워크플로우 — 4단계 (기존 프로젝트는 5단계)

```
1. 탐색 (파일 존재 + 내용 분석)
   └─ 기존 코드가 있으면:
2. 코드 선행 분석 + 사용자 확인     ← 기존 프로젝트 전용
3. 논의 (Q0~Q8, 확정된 답은 자동 채움)
4. 인프라 셋업
5. 위임
```

### 1. 탐색 — 파일 존재 확인 + 핵심 파일 내용 분석

프로젝트 루트의 현황을 파악한다. **파일 존재만 확인하지 않고, 핵심 파일의 내용을 읽어 실행 형태를 자동 추론한다.**

#### 1-1. 기본 현황 파악

- 구현 코드 존재 여부 (`src/`, `main.py`, `app.py`, `index.ts`, `*.cpp`, `package.json` 등)
- `docs/` 하위 문서 상태 (PRD.md, ARCHITECTURE.md, ADR.md)
- CLAUDE.md 여부 및 placeholder 잔존 여부
- `.gitignore`, `.env.example`, `venv/` 상태 (Python 프로젝트)
- GSD `.planning/` 존재 여부

#### 1-2. 분기 판정 — 신규 vs 기존 프로젝트

구현 코드의 실질 존재 여부로 분기한다:
- **신규 프로젝트 모드**: `src/`·`main.py`·`app.py`·`index.ts`·`*.cpp` 등 실행 코드가 **없음**
  → 코드 선행 분석(Step 2) 건너뛰고 바로 Q0부터 시작
- **기존 프로젝트 모드**: 실행 코드가 **있음** (한 파일이라도)
  → 반드시 Step 2(코드 선행 분석)를 수행한 뒤 Q0로 진입

#### 1-3. 기존 프로젝트의 경우 — 핵심 파일 내용 읽기

아래 파일이 존재하면 **내용을 읽어** 실행 형태·언어·의존성을 추론한다. 파일명만 보고 판단하지 않는다.

**진입점 후보 (내용 분석 필수):**
- `main.py`, `app.py`, `server.py`, `run.py`, `cli.py`
- `src/main.py`, `src/app.py`, `src/index.ts`, `src/main.cpp`
- `index.ts`, `index.js`, `server.ts`

**의존성 파일 (내용 전체 확인):**
- `requirements.txt`, `requirements-dev.txt`, `pyproject.toml`
- `package.json` (dependencies, devDependencies, scripts 모두 확인)
- `CMakeLists.txt`, `Cargo.toml`, `go.mod`

**UI/템플릿 관련 디렉토리·파일:**
- `templates/`의 `*.html` 파일 (Jinja2 템플릿이면 서버 렌더링 웹)
- `static/` 디렉토리 (CSS/JS/이미지)
- `frontend/`, `client/`, `web/`, `ui/` 디렉토리

#### 1-4. 자동 감지 패턴 — 내용에서 찾아야 하는 시그널

**웹 서버 + UI (Flask/FastAPI/Django + 서버 렌더링 또는 SPA):**
- Python 파일에 `Flask(`, `FastAPI(`, `Starlette(`, `django` 임포트
- + `templates/` 디렉토리 또는 `render_template(`, `Jinja2Templates(`, `TemplateResponse(` 호출
- + `*.html` 파일에 `<html`, `<body>` 포함
- 또는 `package.json`에 `react`, `vue`, `svelte`, `next`, `nuxt`, `vite` 의존성

**웹 서버 (API만, UI 없음):**
- Flask/FastAPI/Starlette 있으나 `templates/`·HTML 파일 없음
- `@app.route`, `@app.get`, `@router.get` 등 라우터 정의만
- 주로 `jsonify(`, `JSONResponse(`, `return {...}` 반환

**CLI 스크립트:**
- `argparse`, `click`, `typer`, `sys.argv` 사용
- `if __name__ == "__main__"` + `print(`·`logging` 출력
- 네트워크 서버 바인딩(`app.run()`, `uvicorn.run()`) 없음

**데몬/백그라운드:**
- `schedule`, `apscheduler`, `celery`, `rq` 임포트
- `while True:` 루프 + `time.sleep()` 또는 cron 표현식

**언어 추론:**
- `*.py` → Python
- `package.json` + `*.ts`/`*.tsx` → TypeScript
- `package.json` + `*.js`만 → JavaScript
- `CMakeLists.txt` + `*.cpp`/`*.hpp` → C++
- `*.c`/`*.h`만 → C
- 위 여러 개 공존 → 혼합

#### 1-5. 탐색 결과 출력 (콘솔에 반드시 출력)

```
[ 탐색 결과 ]
- 모드:           신규 / 기존 (실행 코드 {있음/없음})
- 구현 코드:      {있음: 파일 목록 / 없음}
- 감지된 실행 형태: {Flask 웹서버+UI / FastAPI API만 / CLI / 데몬 / 불명확}
                  근거: {예: app.py:12 에서 `app = Flask(__name__)`, templates/ 디렉토리 존재}
- 언어:           {Python / TypeScript / C++ / 혼합(Python+TS)}
- Frontend:       {Jinja2 템플릿(templates/*.html N개) / React(package.json 확인) / 없음}
- 외부 의존성:    {requirements.txt/package.json 기준 주요 라이브러리 5개 이내}
- docs/:          PRD.md {있음/없음}, ARCHITECTURE.md {있음/없음}, ADR.md {있음/없음}
- CLAUDE.md:      {있음(placeholder 잔존 여부) / 없음}
- .env.example:   {있음 / 없음}
- .gitignore:     {있음 / 없음}
```

필요 시 Explore 서브에이전트를 사용해 내용 분석을 병렬 수행한다.

> **[ SCOPE CHECK ]** 탐색이 끝났다. 기존 프로젝트면 Step 2(코드 선행 분석), 신규면 Step 3(논의)로 간다. 코드 수정이나 기능 제안은 하지 않는다.

---

### 2. 코드 선행 분석 + 사용자 확인 — 기존 프로젝트 전용

> **신규 프로젝트 모드**(실행 코드 없음)에서는 이 단계를 **건너뛰고** 바로 Step 3(논의)의 Q0부터 시작한다.

기존 프로젝트가 있는 경우 Q0 이전에 **탐색 결과를 사용자에게 먼저 보여주고 확인받는다.** 이 단계는 "우리가 코드를 잘못 읽지 않았는지" 확인하는 게이트다.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
탐색 완료 — 코드 분석 결과
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
감지된 실행 형태: {예: 웹 서버 + UI}
                 근거: {app.py:5 `app = Flask(__name__)`, templates/ 존재, *.html 3개}
언어:           {Python}
Frontend:       {Jinja2 템플릿 (templates/*.html)}
외부 의존성:    {Flask, pandas, plotly (requirements.txt 기준)}
데이터 영속성:  {SQLite 파일 data.db 감지 / 없음 / 불명확}
외부 API:       {감지된 API 클라이언트 코드 / 없음 / 불명확}

이 분석이 맞나요?
  y              → 맞음, Q0로 진행
  수정할 부분   → 직접 입력 (예: "Frontend 없음, API만 제공" / "실행 형태는 CLI")
→
```

**사용자 확인 처리 규칙:**
1. `y`로 확인된 항목은 이후 Q1~Q8에서 "자동 확정"으로 처리한다.
   - 실행 형태(Q2), 언어(Q1), Frontend(Q7), 외부 API(Q5) 등 코드에서 명확히 드러난 항목은 **질문을 생략하고 확정값을 표시만 한 뒤 다음 질문으로 넘어간다.**
   - 예: `Q2. 실행 형태는? → 웹 서버 + UI (탐색에서 확정, 건너뜀)`
2. 사용자가 수정했다면 수정된 값을 확정으로 기록한다.
3. 분석이 **불명확**(예: Flask 있으나 templates/ 없음 — API인지 UI 일부만 있는지 모호)이면, 그 항목만 Q 단계에서 정상적으로 묻는다.
4. Q0(프로젝트 컨셉)은 **어떤 경우에도 건너뛰지 않는다.** 코드만으로는 "왜 만들었나"를 알 수 없기 때문이다. Q0는 "이 코드가 어떤 의도인지 간단히 설명해 주세요" 형태로 보완 서술 용도로 활용한다.

> **[ SCOPE CHECK ]** 사용자 확인이 끝났다. 이제 Q0부터 시작한다. 확정된 항목은 재질문하지 않는다.

---

### 3. 논의 — Human In The Loop (순차 인터랙티브)

**규칙**: 질문은 **1개씩** 순서대로 한다. 답변을 받은 뒤에만 다음으로 넘어간다.

**Recommended 결정 원칙**: `★ Recommended`는 **Q0에서 사용자가 설명한 프로젝트 컨셉을 기반으로 동적으로 결정**한다.
정적 인기도(많이 쓰는 스택)가 아니라, 해당 컨셉에 가장 적합한 선택지에 ★를 붙인다.
탐색에서 기존 코드를 확인했다면 그 언어·구조도 추론에 반영한다.

조건부 질문(Q6·Q7·Q8)은 해당 조건이 아닌 경우 "→ Q{N} 건너뜀" 1줄 표기 후 다음으로 넘어간다.
- Q6: Q2에서 "웹 서버 + UI" 또는 "웹 서버 (API만)"을 선택한 경우에만 묻는다
- Q7: Q2에서 "웹 서버 + UI"를 선택한 경우에만 묻는다
- Q8: Q7을 답한 경우에만 묻는다

답변은 각 질문마다 Claude가 내부 메모에 기록해 두고, 논의 완료 시 결정 요약 출력 → 사용자 승인 → 한 번에 `docs/PRD.md`와 `CLAUDE.md`에 기록한다.
논의 도중에는 어떠한 파일도 생성하지 않는다.

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

#### Q0. 프로젝트 컨셉 (자유 서술) — 가장 먼저 묻는다

**신규 프로젝트 모드:** "어떤 것을 만들고 싶으신가요?" 원래대로 묻는다.
**기존 프로젝트 모드:** 코드에서 실행 형태·언어·구조는 이미 확정됐으므로 "이 프로젝트가 무엇을 목적으로 하는지, 특이사항·제약이 있는지" 간단히 보완 서술을 요청한다.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q0  프로젝트 컨셉
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[신규 프로젝트] 어떤 것을 만들고 싶으신가요?
  짧게 설명해 주세요. 목적·데이터·사용자·특이사항 등을 자유롭게.
  예: "주식 데이터를 수집해서 백테스팅하는 CLI 스크립트"
  예: "팀 내부에서 쓰는 REST API + 간단한 관리 대시보드"

[기존 프로젝트] 이미 아래 구조가 확인되었습니다:
  {탐색 요약 한 줄 — 예: "Flask 웹서버 + Jinja2 UI, 주식 백테스팅"}
  이 프로젝트가 무엇을 목적으로 하는지, 제약이나 특이사항이 있는지 알려주세요.

→
```

Q0 답변을 받으면:
1. 답변 내용을 분석해 프로젝트의 핵심 특성을 파악한다 (성능 중요도, 데이터 규모, 사용자 수, UI 필요 여부 등)
2. Q1~Q8의 `★ Recommended`를 이 컨셉에 맞게 결정한다 — **정적 인기 순위가 아닌 컨셉 적합성 기준**
3. **기존 프로젝트 모드**: Step 2에서 확정된 항목(실행 형태·언어·Frontend 등)은 Q 질문 시 **재질문하지 않고 확정값 표시 1줄만 출력**한 뒤 넘어간다:
   ```
   Q2  실행 형태는?  → 웹 서버 + UI (Step 2에서 확정, 건너뜀)
   ```
4. Recommended 예시:
   - "고성능 알고리즘 트레이딩 엔진" → C++ ★
   - "주식 데이터 수집·분석 스크립트" → Python ★, CLI ★, SQLite ★
   - "실시간 트레이딩 대시보드" → TypeScript ★, 웹 서버+UI ★, WebSocket 언급
   - "내부 관리 도구 (간단한 UI)" → Python ★, Jinja2+HTMX ★ (React 오버킬)

---

#### Q1. 언어 구성

Q0 컨셉을 바탕으로 `★ Recommended`를 결정한다.

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

Q0 컨셉과 Q1 언어를 바탕으로 Recommended를 결정한다.

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

Q0 컨셉을 바탕으로 Recommended를 결정한다.
(개인 도구·스크립트 → 로컬 ★, 팀 공유 서비스 → 서버 ★, 배포 자동화 언급 → Docker ★)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q3  실행 환경은?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) 로컬 전용        — 개발자 PC에서만 실행
  2) 서버 배포        — Linux 서버
  3) Docker 컨테이너
  4) 클라우드         — AWS / GCP / Azure
  5) 기타 (직접 입력)

번호 또는 직접 입력 →
```

#### Q4. 데이터 영속성

Q0 컨셉을 바탕으로 Recommended를 결정한다.
(단순 분석 스크립트 → 파일/없음 ★, 다중 사용자·대용량 → RDB ★, 캐싱·실시간 → NoSQL ★)

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

Q0 컨셉을 바탕으로 Recommended를 결정한다.
(내부 도구·단일 사용자 → 없음 ★, 서버 간 API → API Key ★, 외부 사용자 대면 → JWT 또는 OAuth ★)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q6  사용자 인증이 필요한가요?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) 없음             — 단일 사용자 / 내부 도구
  2) API Key
  3) JWT (stateless)
  4) Session 쿠키 (stateful)
  5) OAuth            — Google / GitHub / 기타

번호 또는 직접 입력 →
```

#### Q7. Frontend 프레임워크 ← Q2에서 "웹 서버 + UI"를 선택한 경우에만 묻는다. 아니면 "→ Q7 건너뜀"

Q0 컨셉과 Q1 언어를 바탕으로 Recommended를 결정한다.
(Python + 간단한 관리 도구 → Jinja2/HTMX ★, TypeScript + 외부 사용자 대면 → React ★, SEO 중요 → Next.js ★)
React/Next.js가 오버킬인 경우(내부 도구, 단순 대시보드)는 솔직하게 "Jinja2+HTMX로 충분합니다"라고 안내한다.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q7  프론트엔드 프레임워크는?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) Jinja2 서버 렌더링  — Python, 간단한 UI, JS 불필요
  2) HTMX               — Python, 동적 상호작용, JS 최소화
  3) React (Vite)        — TypeScript, SPA, 풍부한 인터랙션
  4) Next.js             — TypeScript, SSR/SEO 필요
  5) Vue
  6) Svelte
  7) 기타 (직접 입력)

번호 또는 직접 입력 →
```

#### Q8. Frontend 스타일링 ← Q7을 답한 경우에만 묻는다. 아니면 "→ Q8 건너뜀"

Q7 프레임워크와 Q0 컨셉을 바탕으로 Recommended를 결정한다.
(Jinja2/HTMX + 빠른 개발 → Tailwind CDN ★, React 복잡 UI → Tailwind npm ★, 브랜드 디자인 시스템 → CSS Modules ★)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Q8  스타일링 방식은?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) Tailwind CSS
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
Q0(프로젝트 컨셉)이 수정되면 Recommended를 재평가해야 하므로, "0" 입력 시 Q0 재질문 후 영향을 받은 항목(Q1~Q8 중 Recommended가 바뀔 수 있는 것)도 사용자에게 재확인 요청한다.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
결정 요약 — 확인 후 인프라 셋업을 시작합니다
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  프로젝트 컨셉 (Q0): {Q0 자유 서술 원문 요약 1~2줄}
  언어 (Q1):          {답변}
  실행 형태 (Q2):     {답변}
  실행 환경 (Q3):     {답변}
  데이터 (Q4):        {답변}
  외부 API (Q5):      {답변}
  인증 (Q6):          {답변 또는 해당없음}
  Frontend (Q7):      {답변 또는 해당없음}
  스타일링 (Q8):      {답변 또는 해당없음}

y → 인프라 셋업 시작
번호(0~8) → 해당 항목 재질문
```

---

### 4. 인프라 셋업

> **[ PRE-FLIGHT CHECK ]** 셋업 시작 전 자기 점검:
> - 생성할 것: `docs/`, `CLAUDE.md`, `.gitignore`, `.env.example`, `README.md`
> - 절대 생성하지 않을 것: `src/`, `main.py`, `app.py`, `*.py` 구현 코드, `*.ts` 파일
> - 이 경계를 넘으려는 순간 즉시 멈춘다.

사용자 승인 후, 아래를 생성하거나 보완한다. **기존 파일을 덮어쓸 때는 사용자에게 먼저 확인받는다.**

#### 4-1. docs/ 문서
- `docs/PRD.md` — 논의 답변으로 섹션별 채우기. 핵심:
  - §1 목표 — Q0 자유 서술을 바탕으로 한 줄 요약·상세 배경·성공 지표 작성
  - §2 사용자·실행 형태 — §2-1 체크박스는 Q2 답변에 해당하는 항목만 `[x]`로 표시, "결정값" 필드에도 같은 값을 기입
  - §3 MVP 기능(최대 5개), §4 제외 사항, §5 DoD
  - §7 에러 케이스 — 실행 형태·데이터·외부 API에 해당하는 항목만 작성 (DB 없으면 DB 연결 실패 제거, 외부 API 없으면 §7-2 전체 제거 등)
  - §8 데이터 모델 — Q4가 "없음"이면 섹션 삭제
  - §10 향후 확장 — 지금 구현하지 않을 항목만 간단히. 없으면 섹션 삭제
- `docs/ARCHITECTURE.md` — 해당 언어 섹션만 남기고 나머지 삭제
- `docs/ADR.md` — "공통 ADR은 harness_framework/docs/ADR.md 참조" 1줄 + ADR-100부터 프로젝트 고유 결정만 기록
- `docs/UI_GUIDE.md` — Frontend 없으면 파일 자체 삭제. Frontend 있으면 AI 슬롭 안티패턴 섹션 유지하고 이후 `/gsd:ui-phase` 작업 시 참조 안내

#### 4-2. README.md
- 프로젝트명, 한 줄 설명, 설치·실행 방법, 환경변수 목록 최소 구성으로 작성한다.
- 기존 README가 있으면 내용을 보완하고 덮어쓰기 전 사용자 확인.

#### 4-3. CLAUDE.md (프로젝트 규칙)
- 프로젝트명, 기술 스택 placeholder 채우기
- 해당하지 않는 언어 섹션 삭제:
  - Python만이면 C2b(TS), C3(C/C++) 삭제. C2, C2a 유지
  - TypeScript만이면 C2, C2a, C3 삭제. C2b 유지
  - C/C++만이면 C2, C2a, C2b 삭제. C3 유지
  - 혼합이면 해당 언어 섹션 모두 유지
- C7(프로젝트 고유 규칙) — 이번 논의에서 나온 특수 제약 기록. 없으면 C7 섹션 자체 삭제
- C7b(Step별 AC 차등화)는 그대로 유지 (GSD 실행과 연계)

#### 4-4. 메타 파일
- `.gitignore` — 언어별 필수 항목 확인 (venv/, __pycache__/, .env, node_modules/, build/ 등)
- `.env.example` — Q5에서 수집한 시크릿 키 이름만 기입. 실제 값은 `your_xxx_here` 같은 placeholder. 예:
  ```
  # 외부 API
  SOME_API_KEY=your_api_key_here
  # 데이터베이스 (Q4가 DB인 경우)
  DATABASE_URL=sqlite:///data.db
  # 로깅
  LOG_LEVEL=INFO
  ```
- `requirements.txt` + `requirements-dev.txt` + `pyproject.toml` (Python)
- `package.json` + `tsconfig.json` + `biome.json` (TypeScript)
- `CMakeLists.txt` + `.clang-format` + `.clang-tidy` (C/C++)

#### 4-5. 훅 검증 (Claude Code 품질 가드)
- `~/.claude/settings.json`의 hooks에 `circuit-breaker.sh`가 등록되어 있는지 확인
- 미등록 시 `harness_framework/docs/QUICKSTART.md §0` 절차를 사용자에게 안내

#### 4-6. 첫 커밋 (신규 프로젝트만)
```bash
# git init은 QUICKSTART §2에서 이미 수행했을 수 있다. 중복 실행해도 무해하지만 먼저 확인한다.
[ -d .git ] || git init

git add CLAUDE.md README.md docs/ .gitignore .env.example
# Python 프로젝트라면 추가:
git add requirements.txt requirements-dev.txt pyproject.toml
# TypeScript 프로젝트라면 추가:
git add package.json tsconfig.json biome.json
# C/C++ 프로젝트라면 추가:
git add CMakeLists.txt .clang-format .clang-tidy
git commit -m "chore: project skeleton"
```

> **[ 생성 완료 체크 ]** 방금 만든 파일 목록을 훑어본다. `src/`, `main.py`, `app.py`, `.py` 구현 코드가 포함됐다면 즉시 삭제한다.

---

### 5. 위임 — 다음 단계 안내

> **[ HANDOFF ]** 인프라 셋업이 끝났다. 이제 구현은 내 역할이 아니다.

인프라 셋업이 끝나면 반드시 아래 형식으로 종료한다:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
harness 셋업 완료
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
생성/보완된 파일:
  - docs/PRD.md, docs/ARCHITECTURE.md, docs/ADR.md (+ Frontend 있으면 UI_GUIDE.md)
  - README.md
  - CLAUDE.md (프로젝트 규칙)
  - .gitignore, .env.example
  - Python: requirements.txt, requirements-dev.txt, pyproject.toml
  - TypeScript: package.json, tsconfig.json, biome.json
  - C/C++: CMakeLists.txt, .clang-format, .clang-tidy

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
