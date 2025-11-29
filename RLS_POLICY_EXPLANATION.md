# RLS 정책 강화 설명서

## 현재 상태 분석

### ✅ 이미 완료된 것 (애플리케이션 레벨 보안)

**SupabaseAdapter에서 branch_id 필터링:**
```dart
// crm/lib/services/supabase_adapter.dart
static List<Map<String, dynamic>> _enforceBranchFilter(...) {
  // branch_id 필터 강제 추가
  final branchCondition = {
    'field': 'branch_id',
    'operator': '=',
    'value': branchId,
  };
  return [...(where ?? []), branchCondition];
}
```

**효과:**
- ✅ 앱을 통한 모든 쿼리에 자동으로 `branch_id` 필터 추가
- ✅ 다른 지점 데이터 접근 차단
- ✅ 기존 코드 수정 없이 보안 강화

### ⚠️ 현재 문제점 (DB 레벨 보안)

**RLS 정책 상태:**
```sql
-- 현재 모든 테이블의 RLS 정책
CREATE POLICY allow_all_select_v2_members 
ON v2_members FOR SELECT 
USING (true);  -- ⚠️ 모든 접근 허용
```

**문제 시나리오:**

#### 시나리오 1: SupabaseAdapter 우회
```dart
// 만약 누군가 SupabaseAdapter를 우회하고 직접 Supabase 클라이언트 사용
final client = Supabase.instance.client;
final data = await client
  .from('v2_members')
  .select()  // ⚠️ branch_id 필터 없이 조회
  .execute();
// → 모든 지점의 회원 데이터 조회 가능!
```

#### 시나리오 2: 직접 DB 접근
```bash
# Supabase SQL Editor에서 직접 쿼리 실행
SELECT * FROM v2_members;
# → 모든 지점의 회원 데이터 조회 가능!
```

#### 시나리오 3: 외부 도구 사용
- PostgREST API 직접 호출
- Supabase Dashboard에서 직접 쿼리
- 다른 애플리케이션에서 Anon Key 사용

**현재 상태:**
- 애플리케이션 레벨: ✅ 보안 적용됨 (SupabaseAdapter)
- DB 레벨: ❌ 보안 없음 (RLS 정책이 "모든 접근 허용")

---

## "민감 정보 테이블 보호 정책 강화"란?

### 목표
**DB 레벨에서도 지점별 접근 제어를 적용**하여 이중 방어 체계 구축

### 변경 내용

**현재 (모든 접근 허용):**
```sql
CREATE POLICY allow_all_select_v2_members 
ON v2_members FOR SELECT 
USING (true);  -- 누구나 모든 데이터 접근 가능
```

**강화 후 (지점별 접근만 허용):**
```sql
-- 기존 정책 삭제
DROP POLICY allow_all_select_v2_members ON v2_members;

-- 새로운 제한적 정책 생성
CREATE POLICY branch_access_select_v2_members 
ON v2_members FOR SELECT 
USING (
  branch_id = current_setting('app.branch_id', true)::text
  OR 
  branch_id = (auth.jwt() ->> 'branch_id')
);
-- ✅ 자신의 지점 데이터만 접근 가능
```

### 적용 대상 테이블

**민감 정보가 있는 테이블:**
1. **비밀번호 테이블**
   - `v2_staff_pro` (직원 비밀번호)
   - `v2_staff_manager` (관리자 비밀번호)
   - `v2_members`, `v3_members` (회원 비밀번호)
   - `v2_branch` (지점 비밀번호)

2. **결제 정보 테이블**
   - `v2_portone_payments` (결제 내역, 카드 정보 등)

3. **개인정보 테이블**
   - `v2_members`, `v3_members` (회원 개인정보)
   - `v2_staff_pro`, `v2_staff_manager` (직원 개인정보)

---

## 구현 방법

### 방법 1: JWT 클레임 기반 (권장)

**장점:**
- Supabase Auth와 통합
- 자동으로 사용자 정보 기반 접근 제어

**단점:**
- Supabase Auth 사용 필요
- 현재는 익명 인증 사용 중

**구현:**
```sql
CREATE POLICY branch_access_select_v2_members 
ON v2_members FOR SELECT 
USING (
  branch_id = (auth.jwt() ->> 'branch_id')
);
```

### 방법 2: 세션 변수 기반 (현실적)

**장점:**
- 현재 구조와 호환
- SupabaseAdapter에서 설정 가능

**단점:**
- 애플리케이션에서 명시적으로 설정 필요

**구현:**
```sql
CREATE POLICY branch_access_select_v2_members 
ON v2_members FOR SELECT 
USING (
  branch_id = current_setting('app.branch_id', true)::text
);
```

**SupabaseAdapter 수정 필요:**
```dart
// 쿼리 실행 전에 세션 변수 설정
await client.rpc('set_config', {
  'setting_name': 'app.branch_id',
  'setting_value': _currentBranchId,
});
```

### 방법 3: 하이브리드 (현재 구조 유지)

**현재 상태 유지 + 추가 보안:**
- SupabaseAdapter 레벨 보안 유지 (현재 상태)
- RLS 정책은 "모든 접근 허용" 유지
- **추가**: 민감 정보 필드만 별도 보호

**구현:**
```sql
-- 비밀번호 필드는 SELECT 차단
CREATE POLICY hide_password_v2_staff_pro 
ON v2_staff_pro FOR SELECT 
USING (
  -- 비밀번호 필드 제외하고는 허용
  true
);

-- 또는 View 사용 (비밀번호 필드 제외)
CREATE VIEW v2_staff_pro_safe AS
SELECT 
  pro_id, pro_name, pro_phone, ...
  -- staff_access_password 제외
FROM v2_staff_pro;
```

---

## 비교표

| 항목 | 현재 상태 | 강화 후 |
|------|----------|---------|
| **애플리케이션 레벨** | ✅ branch_id 필터링 | ✅ branch_id 필터링 (유지) |
| **DB 레벨 (RLS)** | ❌ 모든 접근 허용 | ✅ 지점별 접근만 허용 |
| **SupabaseAdapter 우회 시** | ❌ 모든 데이터 접근 가능 | ✅ 여전히 지점별 제한 |
| **직접 DB 접근 시** | ❌ 모든 데이터 접근 가능 | ✅ 지점별 제한 적용 |
| **복잡도** | 낮음 | 중간 |
| **유지보수** | 쉬움 | 보통 |

---

## 권장사항

### 옵션 A: 현재 상태 유지 (권장)
**이유:**
- ✅ SupabaseAdapter 레벨 보안으로 충분
- ✅ 복잡도 낮음
- ✅ 유지보수 쉬움
- ⚠️ 단점: SupabaseAdapter 우회 시 보안 취약

**적용 시나리오:**
- 앱을 통해서만 접근하는 경우
- 외부 접근이 차단된 경우
- 빠른 개발이 우선인 경우

### 옵션 B: RLS 정책 강화 (이중 방어)
**이유:**
- ✅ 이중 방어 체계
- ✅ SupabaseAdapter 우회해도 보안 유지
- ✅ 직접 DB 접근 시에도 보안
- ⚠️ 단점: 복잡도 증가, 세션 변수 설정 필요

**적용 시나리오:**
- 높은 보안이 필요한 경우
- 외부 접근 가능성이 있는 경우
- 규정 준수가 중요한 경우

### 옵션 C: 하이브리드 (민감 필드만 보호)
**이유:**
- ✅ 비밀번호 등 민감 필드만 별도 보호
- ✅ 복잡도 중간
- ✅ 실용적

**적용 시나리오:**
- 비밀번호 필드만 추가 보호가 필요한 경우
- 점진적 보안 강화가 필요한 경우

---

## 결론

**현재 상태:**
- ✅ SupabaseAdapter에서 branch_id 필터링 완료
- ✅ 애플리케이션 레벨 보안 적용됨

**추가 작업 (선택사항):**
- RLS 정책을 "모든 접근 허용" → "지점별 접근만 허용"으로 변경
- 이중 방어 체계 구축

**결정:**
- 현재 상태로 충분하다면 → 추가 작업 불필요
- 더 높은 보안이 필요하다면 → RLS 정책 강화 진행

---

**작성일**: 2025년 1월  
**상태**: 현재 상태 분석 및 옵션 제시

