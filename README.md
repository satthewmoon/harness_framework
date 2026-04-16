# {프로젝트명}

> {이 프로젝트가 무엇을 하는지 한 문장}

---

## 빠른 시작

```bash
# 1. 저장소 클론
git clone {저장소_URL}
cd {프로젝트명}

# 2. venv 생성 및 활성화
python3 -m venv venv
source venv/bin/activate

# 3. 의존성 설치
pip install -r requirements-dev.txt

# 4. 환경변수 설정
cp .env.example .env
# .env 파일을 열어 실제 값 입력

# 5. 실행
python main.py
```

---

## 개발 명령어

```bash
# 린트 검사
ruff check .

# import 정렬
ruff check --select I --fix .

# 코드 포맷
ruff format .

# 테스트 실행
pytest

# 테스트 + 커버리지
pytest --cov=. --cov-report=term-missing

# 의존성 버전 고정 (패키지 추가/변경 후)
pip freeze > requirements.txt
```

---

## 문서

| 문서 | 설명 |
|------|------|
| [QUICKSTART.md](docs/QUICKSTART.md) | 처음부터 끝까지 실행 순서 |
| [PRD.md](docs/PRD.md) | 프로젝트 요구사항 정의 |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | 시스템 설계 및 기술 결정 |
| [ADR.md](docs/ADR.md) | 아키텍처 의사결정 기록 |
| [UI_GUIDE.md](docs/UI_GUIDE.md) | UI/CLI 가이드라인 |
| [CLAUDE.md](CLAUDE.md) | AI 에이전트 실행 규칙 |

---

## 환경변수

| 변수명 | 설명 | 예시 | 필수 |
|--------|------|------|------|
| `SOME_API_KEY` | {API 설명} | `sk-...` | 필수 |
| `DATABASE_URL` | DB 연결 문자열 | `sqlite:///data.db` | 필수 |
| `LOG_LEVEL` | 로그 레벨 | `INFO` | 선택 (기본: INFO) |

> `.env.example`을 복사해 `.env`를 만든 후 실제 값을 입력한다.

---

## 라이선스

MIT
