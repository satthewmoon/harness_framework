# QUICKSTART: 새 프로젝트 시작부터 실행까지

> 이 가이드는 `harness_framework`를 템플릿으로 삼아 새 프로젝트를 만들고 첫 번째 `/harness` 실행을 마치기까지의 순서를 기술한다.
> 명령어는 모두 WSL/Linux 기준이다.

---

## 0. Circuit-Breaker Hook 최초 등록 (최초 1회만)

> Claude Code Stop 훅으로 등록해야 `circuit-breaker.sh`가 실행된다. 등록하지 않으면 lint/테스트 자동 검증이 작동하지 않는다.

```bash
# 1. settings.json 위치 확인 (없으면 생성)
mkdir -p ~/.claude

# 2. 훅 등록 (기존 settings.json에 hooks 항목 추가)
# 아래 명령을 실행하거나 ~/.claude/settings.json을 직접 편집
python3 - <<'EOF'
import json, pathlib

settings_path = pathlib.Path.home() / ".claude" / "settings.json"
settings = {}
if settings_path.exists():
    settings = json.loads(settings_path.read_text())

hook_cmd = "bash /home/shmoon/claude/coding/harness_framework/scripts/hooks/circuit-breaker.sh"
hook_entry = {"type": "command", "command": hook_cmd}
hook_block = {"matcher": ".*", "hooks": [hook_entry]}

hooks = settings.setdefault("hooks", {})
stop_hooks = hooks.setdefault("Stop", [])

# 이미 등록된 경우 스킵
if not any(h.get("hooks", [{}])[0].get("command", "") == hook_cmd for h in stop_hooks):
    stop_hooks.append(hook_block)
    settings_path.write_text(json.dumps(settings, indent=2, ensure_ascii=False))
    print("✓ circuit-breaker.sh 훅 등록 완료")
else:
    print("✓ 이미 등록되어 있음 — 스킵")
EOF

# 3. 등록 확인
grep -c "circuit-breaker" ~/.claude/settings.json && echo "등록 확인됨"
```

> **경로 주의**: 위 경로는 `/home/shmoon/claude/coding/harness_framework/`를 기준으로 한다. 다른 위치에 설치했다면 `hook_cmd` 경로를 수정한다.

---

## 1. 사전 준비

프로젝트를 시작하기 전에 아래 도구가 설치되어 있어야 한다.

```bash
# Python 버전 확인 (3.10 이상 필요)
python3 --version

# Claude Code CLI 확인
claude --version

# ruff 설치 (없으면)
pip install --user ruff

# git 설정 확인
git config --global user.name
git config --global user.email
```

| 도구 | 최소 버전 | 설치 방법 |
|------|-----------|-----------|
| Python | 3.10 | `sudo apt install python3.10` |
| git | 2.x | `sudo apt install git` |
| Claude Code | 최신 | `npm install -g @anthropic-ai/claude-code` |
| ruff | 0.4+ | `pip install --user ruff` |
| pytest | 7.x | `pip install --user pytest` (dev 의존성으로 관리) |

---

## 2. 프로젝트 폴더 준비

```bash
# 1. harness_framework의 템플릿만 선택적으로 복사
#    (scripts/, .git/, .claude/ 등 프레임워크 내부 자산은 제외)
#    HARNESS 환경변수로 루트를 한 번만 정의하면 다른 머신에서도 경로만 바꾸면 된다.
HARNESS=$HOME/claude/coding/harness_framework
PROJECT=$HOME/claude/coding/projects/{프로젝트명}
mkdir -p "$PROJECT"
cp -r "$HARNESS/docs" "$PROJECT/docs"
cp "$HARNESS/CLAUDE.md" "$PROJECT/CLAUDE.md"

# 2. 프로젝트 폴더로 이동
cd "$PROJECT"

# 3. git 초기화 (독립 저장소로 시작)
git init
```

> **폴더명 규칙**: `snake_case` 소문자만 허용. 예: `telegram_bot`, `auction_crawler`, `price_tracker`.
> **절대 하지 말 것**: `cp -r "$HARNESS" "$PROJECT"`로 전체 복사 — `.git`, `scripts/hooks/`, `.claude/commands/` 등 프로젝트에 속하지 않는 자산이 따라 들어온다.

---

## 3. Placeholder 채우기

`{중괄호}` placeholder가 있는 파일을 순서대로 채운다.
**이 단계를 건너뛰면 AI가 잘못된 컨텍스트로 동작한다.**

| 순서 | 파일 | 채울 내용 | 비고 |
|------|------|-----------|------|
| 1 | `docs/PRD.md` | 1~7섹션 전체 | 목표·기능·제외·DoD·에러케이스 |
| 2 | `docs/ARCHITECTURE.md` | 해당하지 않는 언어 섹션 삭제 | Python만 쓰면 C/C++ 섹션 삭제 |
| 3 | `docs/ADR.md` | ADR-100부터 프로젝트 고유 결정 추가 | 없으면 예시 삭제 |
| 4 | `CLAUDE.md` | 프로젝트명·기술스택·C7 | 프로젝트 고유 규칙 |
| 5 | `docs/UI_GUIDE.md` | 웹 UI 없으면 "웹 프론트엔드" 섹션 삭제 | CLI만이면 CLI 섹션만 남김 |

### Placeholder 잔존 확인

```bash
# 채우지 않은 {중괄호} 검출 — 코드블록(```), ADR-1NN, placeholder 설명 라인은 제외
grep -rn '{[^}]\+}' docs/ CLAUDE.md \
  | grep -vE '예:|ADR-1[0-9]{2}|placeholder|`{[^`]*}`'
```

위 명령의 출력이 0줄이어야 진행 가능하다. (일부 거짓 양성은 검토 후 무시해도 됨)

---

## 4. venv 및 의존성 초기화 (Python 프로젝트)

> C/C++ 프로젝트는 이 섹션을 건너뛴다.

```bash
# 1. 프로젝트 루트에서 venv 생성 (폴더명 venv 고정)
python3 -m venv venv

# 2. 활성화 (이후 모든 pip 명령은 활성화 상태에서)
source venv/bin/activate

# 3. requirements.txt 초안 작성 (런타임 의존성만)
cat > requirements.txt << 'EOF'
python-dotenv==1.0.0
# 예: requests==2.31.0
# 예: sqlalchemy==2.0.0
EOF

# 4. requirements-dev.txt 작성 (린트·테스트 도구)
cat > requirements-dev.txt << 'EOF'
-r requirements.txt
ruff==0.4.4
pytest==7.4.4
pytest-cov==4.1.0
EOF

# 5. 의존성 설치
pip install -r requirements-dev.txt

# 6. 버전 고정 (설치 후 즉시)
pip freeze > requirements.txt
```

> **주의**: `venv/` 폴더는 절대 git에 커밋하지 않는다. 다음 단계에서 `.gitignore`로 제외한다.

---

## 5. 환경변수 설정

```bash
# 1. .env.example에 필요한 키를 먼저 작성
cat > .env.example << 'EOF'
# API 키 목록 (실제 값은 .env에만)
SOME_API_KEY=your_api_key_here
DATABASE_URL=sqlite:///data.db
LOG_LEVEL=INFO
EOF

# 2. .env.example을 .env로 복사 후 실제 값 입력
cp .env.example .env
# 편집기로 .env 열어서 실제 값 입력
nano .env
```

> `.env`는 절대 git에 커밋하지 않는다. `.env.example`만 커밋한다.

---

## 6. .gitignore 확인

아래 항목이 `.gitignore`에 모두 포함되어 있어야 한다.

```bash
cat .gitignore
```

필수 항목:
```
venv/
__pycache__/
*.pyc
.env
```

누락된 항목이 있으면 추가:
```bash
echo "venv/" >> .gitignore
echo "__pycache__/" >> .gitignore
echo "*.pyc" >> .gitignore
echo ".env" >> .gitignore
```

---

## 7. 첫 커밋

```bash
# 추가할 파일 확인 (venv/, .env는 절대 포함 금지)
git status

# 프로젝트 골격 커밋 (README.md는 /harness 실행 중 §3-2에서 생성된 후 포함)
git add CLAUDE.md README.md docs/ .gitignore .env.example requirements.txt requirements-dev.txt
git commit -m "chore: project skeleton"
```

---

## 8. Harness 실행 및 다음 단계

```bash
# Claude Code에서 /harness 슬래시 커맨드 실행
/harness
```

`/harness`는 **탐색 → 1문1답 논의 → 인프라 셋업(docs/, CLAUDE.md 등) → 위임** 순서로 진행한다.
실제 구현 코드는 생성하지 않는다.

인프라 셋업 완료 후 아래 명령으로 개발을 시작한다:

```
Phase 단위 계획 수립  →  /gsd:new-project  또는  /gsd:plan-phase
기능 개발             →  /feature-dev
간단한 수정           →  /gsd:fast
```

---

## 9. 트러블슈팅

| 증상 | 원인 | 해결 방법 |
|------|------|-----------|
| `ruff check` 실패 | 린트 오류 | `ruff check --fix .` 실행 |
| `pytest` 실패 | 테스트 실패 | 실패 테스트 로그 확인 → 코드 수정 |
| circuit-breaker 실패 | 코드 품질 미달 | 출력된 에러 메시지 따라 수정 |
| `.env git 추적` 경고 | `.env`가 git에 add됨 | `git rm --cached .env` 실행 |
| cmake 빌드 실패 | C/C++ 빌드 오류 | `build/` 삭제 후 `cmake -S . -B build` 재실행 |
| `/harness`가 코드를 생성함 | Context Rot 발생 | 세션 재시작 후 `/harness` 재실행 |

---

## 완료 후 Wrap-up 절차

모든 step이 완료되면 아래 wrap-up을 수행한다.

```bash
# 1. 의존성 버전 최종 고정
source venv/bin/activate
pip freeze > requirements.txt
git add requirements.txt
git commit -m "chore: freeze dependencies"

# 2. 최종 품질 검증 (회귀 방지 — 전체 스위트 실행)
ruff check .
pytest --cov=src --cov-report=term-missing --cov-fail-under=70

# 3. 버전 태그
git tag v1.0.0
git push origin main --tags

# 4. .env.example 최신화 확인
# .env의 키가 모두 .env.example에 있는지 비교
diff <(grep '=' .env | cut -d= -f1 | sort) \
     <(grep '=' .env.example | cut -d= -f1 | sort)
```

---

## 빠른 참조 — 매 세션 시작 루틴

```bash
cd /coding/projects/{프로젝트명}
source venv/bin/activate        # 항상 먼저
git status                       # 현재 상태 확인
/gsd:progress                    # 작업 현황 파악 (Claude Code에서)
```
