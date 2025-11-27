# Git 구조 분석 문서

## 📊 전체 구조 개요

이 프로젝트는 **Monorepo 구조**로, 하나의 Git 저장소에 여러 프로젝트가 포함되어 있습니다.

```
autogolf-project/                    # 메인 저장소 (Monorepo)
├── .git/                            # 루트 Git 저장소
├── crm/                             # CRM 앱 (Flutter)
│   ├── .gitmodules                  # 서브모듈 설정 파일 ⚠️
│   ├── myxplanner_app/              # 서브모듈 (현재 미초기화)
│   └── crm_landing_page/           # 서브모듈 (현재 미초기화)
├── landing/                         # 랜딩 페이지 (React/TypeScript)
└── myxplanner/                      # 골프 플래너 앱 (Flutter)
```

## 🔗 GitHub 저장소 연결

### 메인 저장소
- **URL**: `https://github.com/seojongik/autogolf-project.git`
- **브랜치**: `main`
- **타입**: Monorepo (단일 저장소)

### 서브모듈 (crm/.gitmodules에 정의됨)
1. **myxplanner_app**
   - **URL**: `https://github.com/seojongik/myxplanner_app.git`
   - **경로**: `crm/myxplanner_app/`
   - **상태**: ⚠️ 현재 디렉토리가 존재하지 않음 (미초기화)

2. **crm_landing_page**
   - **URL**: `https://github.com/seojongik/crm_landing_page.git`
   - **경로**: `crm/crm_landing_page/`
   - **상태**: ⚠️ 현재 디렉토리가 존재하지 않음 (미초기화)

### 독립 프로젝트 (README.md 참조)
- **랜딩 페이지**: `https://github.com/seojongik/crm_landing_page`
- **CRM 앱**: `https://github.com/seojongik/autogolfcrm.com`
- **플래너 앱**: `https://github.com/seojongik/myxplanner_app`

## 📁 디렉토리별 Git 상태

### 루트 디렉토리 (`/`)
- **Git 저장소**: ✅ 활성화
- **Remote**: `origin` → `https://github.com/seojongik/autogolf-project.git`
- **브랜치**: `main`
- **상태**: Clean (변경사항 없음)

### crm/ 디렉토리
- **Git 저장소**: ❌ 독립 저장소 아님 (루트 저장소 공유)
- **서브모듈 설정**: ✅ `.gitmodules` 파일 존재
- **서브모듈 상태**: ⚠️ 미초기화 (디렉토리 없음)

### landing/ 디렉토리
- **Git 저장소**: ❌ 독립 저장소 아님 (루트 저장소 공유)
- **상태**: 루트 저장소의 일부로 관리됨

### myxplanner/ 디렉토리
- **Git 저장소**: ❌ 독립 저장소 아님 (루트 저장소 공유)
- **상태**: 루트 저장소의 일부로 관리됨

## 🔍 현재 상태 분석

### ✅ 정상 동작
1. **루트 저장소**: 정상적으로 GitHub에 연결됨
2. **Monorepo 구조**: 모든 프로젝트가 하나의 저장소에서 관리됨
3. **Push/Pull 스크립트**: 각 프로젝트별로 독립적인 push 스크립트 존재
   - `push_all.py`: 전체 프로젝트 push
   - `crm/crm_push.py`: CRM만 push
   - `landing/landing_push.py`: Landing만 push
   - `myxplanner/planner_push.py`: Planner만 push

### ⚠️ 주의사항
1. **서브모듈 미초기화**: `crm/.gitmodules`에 정의된 서브모듈이 실제로 초기화되지 않음
   - `crm/myxplanner_app/` 디렉토리 없음
   - `crm/crm_landing_page/` 디렉토리 없음

2. **서브모듈 vs 독립 디렉토리 혼재**
   - `crm/.gitmodules`에는 `myxplanner_app` 서브모듈이 정의되어 있음
   - 하지만 루트에 `myxplanner/` 디렉토리가 별도로 존재함
   - 이는 구조적 혼란을 야기할 수 있음

## 🛠️ 서브모듈 초기화 방법

서브모듈을 사용하려면 다음 명령어로 초기화해야 합니다:

```bash
# crm 디렉토리로 이동
cd crm/

# 서브모듈 초기화 및 업데이트
git submodule update --init --recursive

# 또는 루트에서
cd /Users/seojongik/enableTech/autogolf-project
git submodule update --init --recursive
```

## 📝 Git 워크플로우

### 전체 프로젝트 Push
```bash
python3 push_all.py
```

### 개별 프로젝트 Push
```bash
# CRM만
cd crm/
python3 crm_push.py "커밋 메시지"

# Landing만
cd landing/
python3 landing_push.py "커밋 메시지"

# Planner만
cd myxplanner/
python3 planner_push.py "커밋 메시지"
```

## 🔄 서브모듈 업데이트

서브모듈이 초기화된 후:

```bash
# 서브모듈 최신화
cd crm/
git submodule update --remote

# 특정 서브모듈만 업데이트
git submodule update --remote myxplanner_app
git submodule update --remote crm_landing_page
```

## 📌 권장사항

1. **서브모듈 사용 여부 결정**
   - 현재 `myxplanner/`가 루트에 독립적으로 존재함
   - `crm/myxplanner_app/` 서브모듈과의 관계를 명확히 해야 함
   - 필요하다면 서브모듈을 초기화하거나 `.gitmodules`를 정리해야 함

2. **구조 통일**
   - Monorepo로 관리할지
   - 서브모듈로 관리할지
   - 독립 저장소로 관리할지
   - 명확한 전략 수립 필요

3. **문서화**
   - 각 디렉토리의 역할과 관계를 명확히 문서화
   - 서브모듈 사용 여부와 이유를 문서에 기록

## 🔗 관련 파일

- `README.md`: 프로젝트 전체 개요
- `crm/.gitmodules`: 서브모듈 설정
- `crm/PLANNER_INTEGRATION.md`: 플래너 통합 가이드
- `push_all.py`: 전체 프로젝트 push 스크립트
- `crm/sync_planner.py`: 플래너 동기화 스크립트

