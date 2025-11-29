# Cafe24 데이터베이스 연결 정보

> **주의**: 이 문서는 레거시 시스템(Cafe24 MySQL) 연결 정보를 보관하기 위한 문서입니다.  
> 현재는 Supabase로 전환 완료되었으나, 향후 필요 시 참고용으로 보관합니다.

## 📋 데이터베이스 연결 정보

### 기본 연결 정보
- **호스트**: `222.122.198.185`
- **데이터베이스명**: `autofms`
- **사용자명**: `autofms`
- **비밀번호**: `a131150*`
- **포트**: `3306` (MySQL 기본 포트)
- **문자셋**: `utf8mb4`

### 연결 문자열 예시
```php
// PHP PDO
$pdo = new PDO(
    "mysql:host=222.122.198.185;dbname=autofms;charset=utf8mb4",
    "autofms",
    "a131150*"
);
```

```python
# Python
import pymysql

connection = pymysql.connect(
    host='222.122.198.185',
    user='autofms',
    password='a131150*',
    database='autofms',
    charset='utf8mb4'
)
```

## 📊 주요 테이블 목록

### 회원 관련
- `members` - 회원 기본 정보
- `v2_members` - 회원 정보 (v2)
- `v3_members` - 회원 정보 (v3)
- `Term_member` - 기간 회원
- `v2_Term_member` - 기간 회원 (v2)

### 직원 관련
- `Staff` - 직원 기본 정보
- `v2_staff_pro` - 프로 직원 정보
- `v2_staff_manager` - 관리자 직원 정보
- `v2_staff_access_setting` - 직원 접근 설정
- `Staff_payment` - 직원 급여 정보
- `v2_salary_pro` - 프로 급여 정보
- `v2_salary_manager` - 관리자 급여 정보

### 계약 관련
- `v2_contracts` - 계약 정보
- `contract_history` - 계약 이력
- `v2_contract_history` - 계약 이력 (v2)
- `v3_contract_history` - 계약 이력 (v3)

### 예약/스케줄 관련
- `FMS_LS` - 레슨 예약
- `FMS_TS` - 타석 예약
- `v2_weekly_schedule_pro` - 프로 주간 스케줄
- `v2_weekly_schedule_manager` - 관리자 주간 스케줄
- `v2_weekly_schedule_ts` - 타석 주간 스케줄
- `schedule_adjusted` - 조정된 스케줄
- `v2_schedule_adjusted_pro` - 프로 조정 스케줄
- `v2_schedule_adjusted_manager` - 관리자 조정 스케줄
- `v2_schedule_adjusted_ts` - 타석 조정 스케줄

### 청구/결제 관련
- `bills` - 청구서
- `v2_bills` - 청구서 (v2)
- `v2_bill_times` - 시간별 청구
- `v2_bill_games` - 게임별 청구
- `v2_bill_term` - 기간별 청구
- `v2_portone_payments` - 포트원 결제 정보

### 락커 관련
- `Locker_status` - 락커 상태
- `v2_Locker_status` - 락커 상태 (v2)
- `Locker_bill` - 락커 청구
- `v2_Locker_bill` - 락커 청구 (v2)

### 가격/정책 관련
- `Price_table` - 가격표
- `v2_Price_table` - 가격표 (v2)
- `Priced_FMS` - FMS 가격
- `v2_priced_TS` - 타석 가격 (v2)
- `v3_priced_TS` - 타석 가격 (v3)
- `v2_ts_pricing_policy` - 타석 가격 정책
- `Revisit_discount` - 재방문 할인
- `v2_routine_discount` - 정기 할인
- `v2_discount_coupon` - 할인 쿠폰
- `v2_discount_coupon_setting` - 할인 쿠폰 설정
- `v2_discount_coupon_auto_triggers` - 할인 쿠폰 자동 트리거

### 지점/설정 관련
- `v2_branch` - 지점 정보
- `v2_base_option_setting` - 기본 옵션 설정
- `v2_program_settings` - 프로그램 설정
- `v2_wol_settings` - 월별 설정

### 게시판/메시지 관련
- `Board` - 게시판
- `v2_board` - 게시판 (v2)
- `v2_board_comment` - 게시판 댓글
- `v2_board_by_member` - 회원별 게시판
- `v2_board_by_member_replies` - 회원별 게시판 댓글
- `Comment` - 댓글
- `v2_message` - 메시지
- `v2_message_agreement` - 메시지 동의

### 기타
- `CHN_batch` - 배치 작업
- `CHN_message` - 메시지
- `Event_log` - 이벤트 로그
- `Junior` - 주니어 회원
- `Junior_relation` - 주니어 관계
- `v2_junior_relation` - 주니어 관계 (v2)
- `LS_availability` - 레슨 가용성
- `LS_availability_register` - 레슨 가용성 등록
- `LS_confirm` - 레슨 확인
- `LS_contracts` - 레슨 계약
- `v2_LS_contracts` - 레슨 계약 (v2)
- `LS_countings` - 레슨 집계
- `v2_LS_countings` - 레슨 집계 (v2)
- `v3_LS_countings` - 레슨 집계 (v3)
- `LS_feedback` - 레슨 피드백
- `LS_history` - 레슨 이력
- `LS_orders` - 레슨 주문
- `v2_LS_orders` - 레슨 주문 (v2)
- `LS_search_fail` - 레슨 검색 실패
- `LS_total_history` - 레슨 전체 이력
- `Term_hold` - 기간 보류
- `v2_Term_hold` - 기간 보류 (v2)
- `v2_bill_term_hold` - 청구 기간 보류
- `TS_usage` - 타석 사용
- `v2_eventhandicap_TS` - 타석 이벤트 핸디캡
- `v2_eventhandicap_LS` - 레슨 이벤트 핸디캡
- `v2_group` - 그룹
- `v2_member_pro_match` - 회원-프로 매칭
- `v2_ts_info` - 타석 정보
- `v2_cancellation_policy` - 취소 정책

## 🔧 레거시 API 정보

### dynamic_api.php (비활성화됨)
- **URL**: `https://autofms.mycafe24.com/dynamic_api.php`
- **상태**: 레거시 코드, 현재 사용 안 함
- **대체**: Supabase로 전환 완료

### 지원 작업
- `get` - 데이터 조회
- `add` - 데이터 추가
- `update` - 데이터 업데이트
- `delete` - 데이터 삭제

### 특수 액션
- `update_schedule_adjusted_pro` - 프로 스케줄 업데이트
- `getMemberProPurchaseCount` - 회원별 프로 구매횟수 조회
- `send_sms` - SMS 발송

## 📱 SMS API 정보 (알리고)

### 기본 정보
- **API URL**: `https://apis.aligo.in/send/`
- **API Key**: `djcg4vyirxyswndxi1xjobnoa93h76jr`
- **User ID**: `enables`
- **발신번호**: `010-2364-3612`

### 사용 예시
```php
$aligo_data = array(
    'key' => 'djcg4vyirxyswndxi1xjobnoa93h76jr',
    'userid' => 'enables',
    'sender' => '010-2364-3612',
    'receiver' => '01012345678',
    'msg' => '메시지 내용',
    'msg_type' => 'SMS'
);
```

## ⚠️ 보안 주의사항

1. **비밀번호 노출**: 이 문서는 민감한 정보를 포함하고 있습니다.
2. **Git 커밋 금지**: 이 파일은 `.gitignore`에 추가하거나, 민감 정보는 별도 관리 권장
3. **접근 제한**: 필요 시에만 참조하고, 불필요한 공유 금지

## 📝 마이그레이션 상태

- **현재 상태**: Supabase로 전환 완료
- **마이그레이션 날짜**: 2025년 1월
- **백업 위치**: `supabase_migration/cafe24_backup/`
- **마이그레이션 스크립트**: `supabase_migration/full_migration.py`

## 🔄 향후 사용 시 참고사항

1. **연결 테스트**: 연결 전 반드시 네트워크 접근 가능 여부 확인
2. **데이터 동기화**: Supabase와 Cafe24 DB 간 데이터 불일치 가능성 고려
3. **권한 확인**: 필요한 테이블 접근 권한 확인
4. **백업**: 데이터 조회/수정 전 반드시 백업 수행

---

**작성일**: 2025년 1월  
**최종 업데이트**: 2025년 1월  
**상태**: 레거시 시스템 (현재 사용 안 함)

