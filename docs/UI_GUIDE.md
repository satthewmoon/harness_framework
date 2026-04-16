# UI 가이드

> 이 프로젝트의 기본 타겟은 **CLI / 서비스 프로젝트**다.
> 웹 UI가 없으면 "CLI 출력" 섹션만 지키고 "웹 프론트엔드" 섹션은 삭제한다.
> 웹 UI가 있으면 두 섹션 모두 채운다.

---

## 적용 범위 (해당 항목 체크)

- [ ] CLI 출력 (stdout/stderr, 로그, 프롬프트)
- [ ] TUI (rich, textual, curses)
- [ ] 알림 메시지 (Telegram, Slack, 이메일)
- [ ] 웹 프론트엔드 (해당 시만)

---

## CLI 출력 원칙

### 기본 규칙

1. **조용한 성공, 시끄러운 실패** — 정상 경로는 필수 출력만. 에러는 상세히 (스택트레이스 포함).
2. **사람과 스크립트 모두 고려** — `--json` 플래그로 파이프 친화 구조화 출력 지원.
3. **진행 상황 표시** — 10초 이상 걸리는 작업은 진행률 또는 상태 메시지 출력.
4. **색상은 보조 수단** — 색상이 사라져도 정보 전달 가능해야 한다. `NO_COLOR` 환경변수 존중.
5. **stderr vs stdout 분리** — 에러·경고는 stderr. 실제 결과(파이프 가능한 데이터)는 stdout.

### 로그 레벨 규칙

| 레벨 | 언제 쓰는가 | 예시 |
|------|------------|------|
| DEBUG | 내부 상태, 변수 덤프 — 개발 중에만 (`--debug` 플래그로 활성화) | `DEBUG: HTTP GET https://... (200, 0.3s)` |
| INFO | 주요 이벤트 — 시작, 완료, 주요 단계 | `INFO: 크롤링 시작 (총 50개 대상)` |
| WARNING | 복구 가능한 이상 — 재시도 성공, 데이터 스킵 | `WARNING: 항목 #23 파싱 실패, 스킵` |
| ERROR | 작업 실패 — 해당 단위는 중단, 전체는 계속 | `ERROR: DB 저장 실패 — {에러 메시지}` |
| CRITICAL | 프로세스 종료 필요 — 복구 불가 에러 | `CRITICAL: API 키 없음. .env 확인 필요.` |

### 종료 코드 규칙

| 코드 | 의미 |
|------|------|
| 0 | 정상 종료 |
| 1 | 일반 에러 (에러 메시지 출력 후 종료) |
| 2 | 잘못된 사용법 (인자 오류 등) |
| 3 | 부분 성공 (일부 항목 실패, 나머지 성공) |

### 권장 출력 형식

```
# 시작 시
INFO: {프로젝트명} 시작 (v{버전})
INFO: 대상: {N}개

# 진행 중
INFO: [1/N] 처리 중: {항목명}...
WARNING: [3/N] {항목명} 스킵 — {이유}

# 완료 시
INFO: 완료 — 성공 {N}개 / 스킵 {M}개 / 실패 {K}개
INFO: 소요 시간: {X}초
```

### 권장 라이브러리 (Python)

```python
import logging
from rich.logging import RichHandler  # 선택: 컬러 로그

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s: %(message)s",
    handlers=[RichHandler(rich_tracebacks=True)]  # 또는 StreamHandler
)
logger = logging.getLogger(__name__)
```

---

## 알림 메시지 (Telegram / Slack 등)

### 작성 규칙

- 제목은 한 줄, 이모지 최대 1개. 과도한 이모지 금지.
- 본문은 5줄 이내. 상세 내용은 링크 또는 첨부 파일로.
- 시간은 KST ISO 8601 형식 (`2026-04-15T09:30:00+09:00`).
- **민감 정보 절대 포함 금지**: API 키, 비밀번호, 개인정보, 전체 스택트레이스.

### 메시지 템플릿

```
# 정상 완료
✅ {프로젝트명} 완료
- 처리: {N}건 성공, {M}건 스킵
- 소요: {X}초
- {주요 결과 한 줄}

# 에러 발생
❌ {프로젝트명} 에러
- 에러: {에러 요약 — 민감정보 제거}
- 발생 시각: {KST 시각}
- 확인 필요: {서버/로그 파일 경로}

# 경고 (부분 실패)
⚠️ {프로젝트명} 부분 완료
- 성공: {N}건, 실패: {M}건
- 주요 실패 원인: {요약}
```

---

## 웹 프론트엔드 (해당 프로젝트만 — 없으면 이 섹션 전체 삭제)

### 디자인 원칙

1. **도구처럼 보여야 한다** — 매일 쓰는 대시보드이지 마케팅 랜딩이 아니다.
2. **정보 밀도 우선** — 장식보다 데이터. 화면 공간을 낭비하지 않는다.
3. **키보드 단축키 필수** — 마우스 전용 UI 금지. 주요 동작은 키보드로 가능해야 한다.
4. **상태를 명확히** — 로딩/에러/빈 상태를 모두 디자인한다. "데이터 없음" 상태 필수.
5. **일관성** — 같은 액션은 같은 UI 패턴을 쓴다. 예외 없음.

---

### AI 슬롭 안티패턴 — 절대 금지

> AI가 생성한 기본 UI는 아래 패턴을 자주 포함한다. 명시적으로 금지하지 않으면 적용한다.

| 금지 패턴 | 이유 |
|-----------|------|
| `backdrop-filter: blur()` (글래스모피즘) | AI 생성 UI의 가장 흔한 징후 |
| `gradient-text` (배경 그라데이션 텍스트) | AI SaaS 랜딩의 1번 특징 |
| "Powered by AI" 배지 | 기능이 아닌 장식. 사용자 가치 없음 |
| `box-shadow` 글로우 애니메이션 | 네온 글로우 = AI 슬롭 |
| 보라/인디고 브랜드 색상 | "AI = 보라색" 클리셰 |
| 모든 카드 동일 `rounded-2xl` | 균일한 둥근 모서리는 템플릿 느낌 |
| 배경 gradient orb (`blur-3xl` 원형) | 모든 AI 랜딩에 있는 장식 |
| 무한 루프 애니메이션 (loading spinner 외) | 사용자 집중력 방해 |
| 중앙 정렬된 전체 레이아웃 | 랜딩 페이지 패턴. 도구에는 부적합 |

---

### 색상 팔레트 (다크 테마 기본)

#### 배경
| 용도 | 값 | Tailwind |
|------|-----|----------|
| 페이지 배경 | `#0a0a0a` | `bg-[#0a0a0a]` |
| 카드·패널 배경 | `#141414` | `bg-[#141414]` |
| 입력 필드 배경 | `#1a1a1a` | `bg-neutral-900` |
| 호버 상태 | `#1f1f1f` | `bg-neutral-800/50` |
| 경계선 | `#262626` | `border-neutral-800` |

#### 텍스트
| 용도 | 값 | Tailwind |
|------|-----|----------|
| 주 텍스트 | `#ffffff` | `text-white` |
| 본문 | `#d4d4d4` | `text-neutral-300` |
| 보조 | `#a3a3a3` | `text-neutral-400` |
| 비활성·placeholder | `#737373` | `text-neutral-500` |

#### 시맨틱 색상
| 용도 | 값 | Tailwind |
|------|-----|----------|
| 성공·긍정 | `#22c55e` | `text-green-500` |
| 경고 | `#eab308` | `text-yellow-500` |
| 에러·부정 | `#ef4444` | `text-red-500` |
| 정보·중립 | `#3b82f6` | `text-blue-500` |
| 강조(accent) | `#e5e5e5` | `text-neutral-200` |

---

### 상태별 UI 요구사항

> 모든 데이터 표시 컴포넌트는 아래 4개 상태를 모두 구현한다.

| 상태 | UI 처리 |
|------|---------|
| **로딩** | 스켈레톤 UI 또는 스피너 (1초 이상 소요 시) |
| **빈 데이터** | "결과 없음" 메시지 + 다음 행동 안내 (예: "새로 추가하기") |
| **에러** | 에러 메시지 + 재시도 버튼 + 에러 코드 (개발 모드) |
| **정상** | 실제 데이터 표시 |

---

### 컴포넌트 스타일

#### 카드
```
rounded-lg bg-[#141414] border border-neutral-800 p-6
hover: border-neutral-700 transition-colors duration-150
```

#### 버튼
```
Primary:   rounded-md bg-white text-black text-sm font-medium px-4 py-2
           hover:bg-neutral-200 active:bg-neutral-300
           disabled: opacity-40 cursor-not-allowed

Secondary: rounded-md border border-neutral-700 text-neutral-300 text-sm px-4 py-2
           hover:border-neutral-500 hover:text-white

Danger:    rounded-md bg-red-500/10 border border-red-500/30 text-red-400 text-sm px-4 py-2
           hover:bg-red-500/20

Text:      text-neutral-500 text-sm hover:text-neutral-300 transition-colors
```

#### 입력 필드
```
rounded-md bg-neutral-900 border border-neutral-800 px-3 py-2 text-sm text-white
placeholder:text-neutral-500
focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600
disabled: opacity-40 cursor-not-allowed
error:    border-red-500/50 focus:border-red-500 focus:ring-red-500/30
```

#### 배지 / 태그
```
Status OK:      rounded-full bg-green-500/10 border border-green-500/30 text-green-400 text-xs px-2 py-0.5
Status Warning: rounded-full bg-yellow-500/10 border border-yellow-500/30 text-yellow-400 text-xs px-2 py-0.5
Status Error:   rounded-full bg-red-500/10 border border-red-500/30 text-red-400 text-xs px-2 py-0.5
Status Neutral: rounded-full bg-neutral-800 border border-neutral-700 text-neutral-400 text-xs px-2 py-0.5
```

#### 테이블
```
테이블 컨테이너: rounded-lg border border-neutral-800 overflow-hidden
헤더 행:        bg-neutral-900 border-b border-neutral-800
헤더 셀:        text-xs font-medium text-neutral-400 uppercase tracking-wider px-4 py-3
데이터 행:      border-b border-neutral-800/50 hover:bg-neutral-800/20
데이터 셀:      text-sm text-neutral-300 px-4 py-3
```

---

### 레이아웃

- **최대 너비**: `max-w-5xl mx-auto` (1024px)
- **페이지 패딩**: `px-6 py-8`
- **정렬**: 좌측 정렬 기본. 중앙 정렬은 에러 페이지·빈 상태·모달에만 허용.
- **컴포넌트 내 간격**: `gap-3` ~ `gap-4`
- **섹션 간 간격**: `space-y-6` ~ `space-y-8`
- **사이드바 너비**: `w-64` (256px) — 사이드바가 있는 경우

---

### 타이포그래피

| 용도 | 스타일 |
|------|--------|
| 페이지 제목 | `text-2xl font-semibold text-white` |
| 섹션 제목 | `text-lg font-medium text-neutral-200` |
| 카드 제목 | `text-sm font-medium text-neutral-300` |
| 본문 | `text-sm text-neutral-300 leading-relaxed` |
| 캡션·메타 | `text-xs text-neutral-500` |
| 에러 메시지 | `text-sm text-red-400` |
| 성공 메시지 | `text-sm text-green-400` |

---

### 애니메이션

**허용**:
- `fade-in`: `opacity-0 → opacity-100`, 0.2s ease-out
- `slide-up`: `translateY(8px) → translateY(0)` + `opacity-0 → opacity-100`, 0.3s ease-out
- 로딩 스피너: `animate-spin` (로딩 상태에만)
- 호버 트랜지션: `transition-colors duration-150`

**금지**:
- `animate-pulse` (로딩 스켈레톤 제외)
- `animate-bounce`
- 모든 무한 루프 애니메이션 (스피너 제외)
- 글로우 효과
- `transform scale` hover 효과

---

### 아이콘

- **라이브러리**: Lucide React 또는 SVG 인라인
- **크기**: `w-4 h-4` (기본), `w-5 h-5` (강조)
- **두께**: `strokeWidth={1.5}` — 1 또는 2는 사용 금지
- **색상**: 텍스트 색상과 동일 (`currentColor`)
- **금지**: 아이콘 전용 둥근 컨테이너 박스로 감싸기

---

### 접근성 최소 요구사항

- 모든 인터랙티브 요소는 키보드로 접근 가능해야 한다 (`Tab`, `Enter`, `Escape`).
- 포커스 링 숨기기 금지 (`outline: none` 단독 사용 금지).
- 이미지·아이콘에 `alt` 또는 `aria-label` 필수.
- 에러 메시지는 `role="alert"` 또는 `aria-live="polite"`.

---

### 반응형 (해당 시)

| 브레이크포인트 | 너비 | 주요 변경사항 |
|---------------|------|--------------|
| mobile | < 768px | 사이드바 숨김, 단일 컬럼 |
| tablet | 768px ~ 1024px | 사이드바 축소 또는 오버레이 |
| desktop | > 1024px | 전체 레이아웃 |
