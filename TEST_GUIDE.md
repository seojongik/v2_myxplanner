# 보안 강화 테스트 가이드

## 📋 테스트 항목

### 1. 자동화 테스트 (Python 스크립트)

**실행 방법:**
```bash
python3 test_security_rls.py
```

**테스트 내용:**
- ✅ RLS 활성화 상태 확인 (51개 테이블 모두 활성화)
- ✅ branch_id 필터링 동작 확인
- ✅ RLS 정책 상세 확인

**결과:**
- 모든 테이블에 RLS 활성화됨
- 총 204개의 RLS 정책 생성됨 (평균 4개/테이블)
- branch_id 필터링 정상 작동 확인

---

## 2. 앱에서 직접 테스트

### 테스트 시나리오 1: 정상 케이스 (같은 지점 데이터 접근)

**목적:** 로그인한 지점의 데이터만 조회되는지 확인

**절차:**
1. 앱 실행 및 로그인
   - 지점: `test` (또는 다른 지점)
   - 로그인 성공 확인

2. 회원 목록 조회
   - 회원 관리 화면 진입
   - 회원 목록이 표시되는지 확인
   - **예상 결과:** 현재 로그인한 지점의 회원만 표시

3. 콘솔 로그 확인
   ```
   🔒 [CRM] SupabaseAdapter branch_id 설정: test
   📡 [ApiService] _getDataRaw() 호출: v2_members 테이블
   ✅ [ApiService] _getDataRaw() 성공: v2_members - X개
   ```

**검증 포인트:**
- ✅ branch_id가 설정되었는지 로그 확인
- ✅ 조회된 데이터가 현재 지점의 데이터인지 확인
- ✅ 다른 지점 데이터가 포함되지 않는지 확인

---

### 테스트 시나리오 2: 비정상 케이스 (branch_id 없이 접근 시도)

**목적:** branch_id가 없을 때 예외가 발생하는지 확인

**절차:**
1. 앱 실행 (로그인 전)
2. SupabaseAdapter 직접 호출 시도
   ```dart
   // 테스트 코드 (개발자 콘솔에서)
   await SupabaseAdapter.getData(table: 'v2_members');
   ```

**예상 결과:**
```
❌ 보안 오류: 지점 정보가 설정되지 않았습니다. 로그인 후 다시 시도하세요.
```

**검증 포인트:**
- ✅ 예외가 발생하는지 확인
- ✅ 적절한 오류 메시지가 표시되는지 확인

---

### 테스트 시나리오 3: 제외 테이블 확인

**목적:** 제외 테이블(v2_branch, Staff 등)은 branch_id 필터링이 적용되지 않는지 확인

**절차:**
1. 로그인 후 지점 목록 조회
   ```dart
   // v2_branch 테이블 조회
   await ApiService.getData(
     table: 'v2_branch',
   );
   ```

**예상 결과:**
- ✅ 모든 지점 목록이 조회됨 (branch_id 필터 없음)
- ✅ 콘솔에 branch_id 필터 추가 메시지 없음

**제외 테이블 목록:**
- `v2_branch`
- `Staff`
- `v2_staff_pro`
- `v2_staff_manager`

---

### 테스트 시나리오 4: 민감 필드 자동 제거 확인

**목적:** 응답에서 비밀번호 등 민감 필드가 자동으로 제거되는지 확인

**절차:**
1. 직원 정보 조회
   ```dart
   await ApiService.getData(
     table: 'v2_staff_pro',
     fields: ['*'],
   );
   ```

2. 응답 데이터 확인
   - `staff_access_password` 필드가 없는지 확인
   - 다른 민감 필드도 제거되었는지 확인

**예상 결과:**
```json
{
  "pro_contract_id": 1,
  "pro_name": "홍길동",
  // "staff_access_password": 제거됨 ✅
  "branch_id": "test"
}
```

**민감 필드 목록:**
- `staff_access_password`
- `member_password`
- `branch_password`
- `password`
- `api_secret`, `secret_key`, `private_key`

---

### 테스트 시나리오 5: 로그아웃 후 접근 차단

**목적:** 로그아웃 후 데이터 접근이 차단되는지 확인

**절차:**
1. 로그인 후 데이터 조회 성공 확인
2. 로그아웃 실행
3. 데이터 조회 시도

**예상 결과:**
```
❌ 보안 오류: 지점 정보가 설정되지 않았습니다. 로그인 후 다시 시도하세요.
```

---

## 3. 수동 검증 체크리스트

### 기본 기능 테스트
- [ ] 로그인 후 회원 목록 조회 (현재 지점 데이터만 표시)
- [ ] 로그인 후 청구 내역 조회 (현재 지점 데이터만 표시)
- [ ] 로그인 후 계약 정보 조회 (현재 지점 데이터만 표시)
- [ ] 지점 목록 조회 (모든 지점 표시 - 제외 테이블)
- [ ] 직원 정보 조회 (민감 필드 제거 확인)

### 보안 테스트
- [ ] 로그인 전 데이터 조회 시도 → 예외 발생 확인
- [ ] 로그아웃 후 데이터 조회 시도 → 예외 발생 확인
- [ ] SupabaseAdapter 직접 호출 → branch_id 필터 자동 추가 확인
- [ ] 다른 지점 데이터 접근 시도 → 차단 확인

### 성능 테스트
- [ ] RLS 활성화 후 쿼리 성능 확인 (이전과 비교)
- [ ] 대량 데이터 조회 시 성능 확인

---

## 4. 디버깅 팁

### 콘솔 로그 확인
```dart
// branch_id 설정 확인
🔒 [CRM] SupabaseAdapter branch_id 설정: test

// 쿼리 실행 확인
📡 [ApiService] _getDataRaw() 호출: v2_members 테이블
✅ [ApiService] _getDataRaw() 성공: v2_members - 10개

// 보안 오류 확인
❌ 보안 오류: 지점 정보가 설정되지 않았습니다.
```

### Supabase Dashboard에서 확인
1. Supabase Dashboard → Table Editor
2. RLS 정책 확인: Authentication → Policies
3. 쿼리 로그 확인: Logs → Postgres Logs

---

## 5. 문제 해결

### 문제: branch_id가 설정되지 않음
**원인:** `ApiService.setCurrentBranch()` 호출 전에 쿼리 실행
**해결:** 로그인 후 지점 설정이 완료된 후 쿼리 실행

### 문제: 모든 데이터가 조회됨
**원인:** 제외 테이블이거나 branch_id 필터가 적용되지 않음
**해결:** 테이블명 확인 및 SupabaseAdapter 코드 확인

### 문제: 성능 저하
**원인:** RLS 정책이 복잡하거나 인덱스 부족
**해결:** 인덱스 추가 및 정책 최적화

---

## 6. 테스트 결과 기록

**테스트 일시:** 2025-01-XX
**테스트자:** 
**환경:** 
- 앱 버전: 
- Supabase 프로젝트: yejialakeivdhwntmagf

**결과:**
- [ ] 모든 테스트 통과
- [ ] 일부 테스트 실패 (상세 기록)

**이슈:**
1. 
2. 
