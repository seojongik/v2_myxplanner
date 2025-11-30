#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MySQL/MariaDB → Supabase 통합 마이그레이션 스크립트
1. MySQL에서 모든 테이블 구조와 데이터를 백업
2. 백업된 데이터를 Supabase로 마이그레이션
한 번에 실행 가능한 통합 스크립트
"""

import pymysql
import json
import os
import re
from datetime import datetime
from typing import Dict, List, Any, Optional
import psycopg2
from psycopg2.extras import execute_values
from psycopg2 import sql

# MySQL 데이터베이스 연결 정보
MYSQL_CONFIG = {
    'host': '222.122.198.185',
    'port': 3306,
    'user': 'autofms',
    'password': 'a131150*',
    'db': 'autofms',
    'charset': 'utf8mb4'
}

# Supabase 설정
SUPABASE_CONFIG = {
    'project_id': 'yejialakeivdhwntmagf',
    'host': 'aws-1-ap-northeast-2.pooler.supabase.com',  # 직접 연결 (Dashboard에서 확인됨)
    'port': 5432,  # 직접 연결 포트 (마이그레이션용)
    'database': 'postgres',
    'user': 'postgres.yejialakeivdhwntmagf',  # 프로젝트 ID 포함 사용자 이름
    'password': None  # Supabase 비밀번호는 별도로 설정 필요
}

# 백업 디렉토리 설정
BACKUP_DIR = os.path.join(os.path.dirname(__file__), 'cafe24_backup')
SCHEMA_DIR = os.path.join(BACKUP_DIR, 'schemas')
DATA_DIR = os.path.join(BACKUP_DIR, 'data')

# 백업에서 제외할 테이블 목록
EXCLUDED_TABLES = {
    'Board',
    'CHN_batch',
    'CHN_message',
    'Comment',
    'Event_log',
    'FMS_LS',
    'FMS_TS',
    'Junior',
    'Junior_relation',
    'LS_availability',
    'LS_availability_register',
    'LS_confirm',
    'LS_contracts',
    'LS_countings',
    'LS_feedback',
    'LS_history',
    'LS_orders',
    'LS_search_fail',
    'LS_total_history',
    'Locker_bill',
    'Locker_status',
    'Price_table',
    'Priced_FMS',
    'Revisit_discount',
    'Staff',
    'Staff_payment',
    'TS_usage',
    'Term_hold',
    'Term_member',
    'bills',
    'contract_history',
    'contract_history_view',
    'contracts',
    'member_pro_match',
    'members',
    'schedule_adjusted',
    'schedule_weekly_base',
    'staff_pro_mapping',
    'v2_LS_contracts',
    'v2_LS_countings',
    'v2_contract_history',
}


# ==================== 백업 관련 함수 ====================

def ensure_directories():
    """백업 디렉토리 생성"""
    os.makedirs(BACKUP_DIR, exist_ok=True)
    os.makedirs(SCHEMA_DIR, exist_ok=True)
    os.makedirs(DATA_DIR, exist_ok=True)
    print(f"백업 디렉토리 준비 완료: {BACKUP_DIR}")


def get_table_list(cursor) -> List[str]:
    """데이터베이스의 모든 테이블 목록 가져오기 (제외 테이블 필터링)"""
    cursor.execute("SHOW TABLES")
    all_tables = [table[0] for table in cursor.fetchall()]
    
    # 제외할 테이블 필터링
    tables = [table for table in all_tables if table not in EXCLUDED_TABLES]
    
    excluded_count = len(all_tables) - len(tables)
    if excluded_count > 0:
        excluded_list = [table for table in all_tables if table in EXCLUDED_TABLES]
        print(f"총 {len(all_tables)}개의 테이블 발견")
        print(f"제외된 테이블 ({excluded_count}개): {', '.join(excluded_list)}")
        print(f"백업 대상 테이블 ({len(tables)}개): {', '.join(tables)}")
    else:
        print(f"총 {len(tables)}개의 테이블 발견: {', '.join(tables)}")
    
    return tables


def get_table_structure(cursor, table_name: str) -> Dict[str, Any]:
    """테이블 구조 정보 가져오기"""
    # 컬럼 정보 가져오기
    cursor.execute(f"DESCRIBE `{table_name}`")
    columns = cursor.fetchall()
    
    # 컬럼 정보를 딕셔너리 리스트로 변환
    column_info = []
    for col in columns:
        column_info.append({
            'Field': col[0],
            'Type': col[1],
            'Null': col[2],
            'Key': col[3],
            'Default': str(col[4]) if col[4] is not None else None,
            'Extra': col[5]
        })
    
    # CREATE TABLE 문 가져오기
    cursor.execute(f"SHOW CREATE TABLE `{table_name}`")
    create_table_result = cursor.fetchone()
    create_statement = create_table_result[1] if create_table_result else None
    
    # Check constraint 정보 추출 (CREATE TABLE 문에서)
    check_constraints = []
    if create_statement:
        # CHECK 제약 조건 찾기 (정규식 사용)
        check_pattern = r'CHECK\s*\(([^)]+)\)'
        matches = re.finditer(check_pattern, create_statement, re.IGNORECASE)
        for match in matches:
            constraint_expr = match.group(1)
            # 제약 조건 이름 추출 시도 (CONSTRAINT name CHECK ...)
            constraint_name_match = re.search(r'CONSTRAINT\s+(\w+)\s+CHECK', create_statement[:match.start()], re.IGNORECASE)
            constraint_name = constraint_name_match.group(1) if constraint_name_match else None
            check_constraints.append({
                'name': constraint_name,
                'expression': constraint_expr
            })
    
    # 인덱스 정보 가져오기
    cursor.execute(f"SHOW INDEX FROM `{table_name}`")
    indexes = cursor.fetchall()
    
    index_info = []
    for idx in indexes:
        index_info.append({
            'Table': idx[0],
            'Non_unique': idx[1],
            'Key_name': idx[2],
            'Seq_in_index': idx[3],
            'Column_name': idx[4],
            'Collation': idx[5],
            'Cardinality': idx[6],
            'Sub_part': idx[7],
            'Packed': idx[8],
            'Null': idx[9],
            'Index_type': idx[10],
            'Comment': idx[11] if len(idx) > 11 else None
        })
    
    return {
        'table_name': table_name,
        'columns': column_info,
        'create_statement': create_statement,
        'indexes': index_info,
        'check_constraints': check_constraints,
        'backup_timestamp': datetime.now().isoformat()
    }


def save_table_structure(table_name: str, structure: Dict[str, Any]):
    """테이블 구조를 JSON 파일로 저장"""
    filename = os.path.join(SCHEMA_DIR, f"{table_name}_schema.json")
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(structure, f, ensure_ascii=False, indent=2)
    print(f"  ✓ 구조 저장: {filename}")


def backup_table_data(cursor, table_name: str):
    """테이블 데이터 백업"""
    try:
        # 데이터 가져오기
        cursor.execute(f"SELECT * FROM `{table_name}`")
        columns = [desc[0] for desc in cursor.description]
        rows = cursor.fetchall()
        
        # 데이터를 딕셔너리 리스트로 변환
        data = []
        for row in rows:
            row_dict = {}
            for i, col in enumerate(columns):
                value = row[i]
                # datetime, date 등의 객체를 문자열로 변환
                if isinstance(value, (datetime,)):
                    value = value.isoformat()
                elif hasattr(value, 'isoformat'):
                    value = value.isoformat()
                row_dict[col] = value
            data.append(row_dict)
        
        # JSON 파일로 저장
        json_filename = os.path.join(DATA_DIR, f"{table_name}_data.json")
        with open(json_filename, 'w', encoding='utf-8') as f:
            json.dump({
                'table_name': table_name,
                'row_count': len(data),
                'backup_timestamp': datetime.now().isoformat(),
                'data': data
            }, f, ensure_ascii=False, indent=2, default=str)
        
        print(f"  ✓ 데이터 저장 (JSON): {json_filename} ({len(data)}개 행)")
        
    except Exception as e:
        print(f"  ✗ 데이터 백업 실패: {str(e)}")


def create_summary_file(tables: List[str], backup_timestamp: str):
    """백업 요약 파일 생성"""
    summary = {
        'database': MYSQL_CONFIG['db'],
        'host': MYSQL_CONFIG['host'],
        'backup_timestamp': backup_timestamp,
        'total_tables': len(tables),
        'tables': tables,
        'backup_locations': {
            'schemas': SCHEMA_DIR,
            'data_json': DATA_DIR,
        }
    }
    
    summary_filename = os.path.join(BACKUP_DIR, 'backup_summary.json')
    with open(summary_filename, 'w', encoding='utf-8') as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)
    
    print(f"\n백업 요약 파일 생성: {summary_filename}")


def backup_from_mysql():
    """MySQL에서 백업 수행"""
    print("=" * 60)
    print("1단계: MySQL 데이터베이스 백업 시작")
    print("=" * 60)
    
    backup_timestamp = datetime.now().isoformat()
    
    # 디렉토리 준비
    ensure_directories()
    
    # 데이터베이스 연결
    try:
        print(f"\n데이터베이스 연결 중...")
        db = pymysql.connect(**MYSQL_CONFIG)
        cursor = db.cursor()
        print(f"✓ 데이터베이스 연결 성공: {MYSQL_CONFIG['db']}")
    except Exception as e:
        print(f"✗ 데이터베이스 연결 실패: {str(e)}")
        return None
    
    try:
        # 테이블 목록 가져오기
        print(f"\n테이블 목록 조회 중...")
        tables = get_table_list(cursor)
        
        if not tables:
            print("백업할 테이블이 없습니다.")
            return None
        
        # 각 테이블 백업
        print(f"\n테이블 백업 시작...")
        print("-" * 60)
        
        for i, table_name in enumerate(tables, 1):
            print(f"\n[{i}/{len(tables)}] 테이블: {table_name}")
            
            try:
                # 테이블 구조 백업
                structure = get_table_structure(cursor, table_name)
                save_table_structure(table_name, structure)
                
                # 테이블 데이터 백업
                backup_table_data(cursor, table_name)
                
            except Exception as e:
                print(f"  ✗ 테이블 백업 중 오류 발생: {str(e)}")
                continue
        
        # 백업 요약 파일 생성
        print(f"\n" + "-" * 60)
        create_summary_file(tables, backup_timestamp)
        
        print(f"\n" + "=" * 60)
        print("백업 완료!")
        print("=" * 60)
        
        return tables
        
    except Exception as e:
        print(f"\n✗ 백업 중 오류 발생: {str(e)}")
        import traceback
        traceback.print_exc()
        return None
    
    finally:
        # 연결 종료
        cursor.close()
        db.close()
        print("\nMySQL 데이터베이스 연결 종료")


# ==================== 마이그레이션 관련 함수 ====================

def load_supabase_password():
    """Supabase 비밀번호 로드 (환경 변수 또는 설정 파일에서)"""
    # 환경 변수에서 먼저 확인
    password = os.getenv('SUPABASE_DB_PASSWORD')
    if password:
        return password
    
    # 설정 파일에서 확인
    keys_file = os.path.join(os.path.dirname(__file__), 'supabase_keys.json')
    if os.path.exists(keys_file):
        with open(keys_file, 'r', encoding='utf-8') as f:
            keys = json.load(f)
            password = keys.get('db_password')
            if password:
                return password
    
    return None


def mysql_type_to_postgresql(mysql_type: str) -> str:
    """MySQL/MariaDB 타입을 PostgreSQL 타입으로 변환"""
    mysql_type = mysql_type.lower().strip()
    
    # int 타입 변환
    if mysql_type.startswith('int(') or mysql_type == 'int':
        return 'INTEGER'
    elif mysql_type.startswith('bigint(') or mysql_type == 'bigint':
        return 'BIGINT'
    elif mysql_type.startswith('smallint(') or mysql_type == 'smallint':
        return 'SMALLINT'
    elif mysql_type.startswith('tinyint(') or mysql_type == 'tinyint':
        if '1' in mysql_type:
            return 'BOOLEAN'
        return 'SMALLINT'
    
    # varchar, char 타입
    if mysql_type.startswith('varchar('):
        match = re.search(r'varchar\((\d+)\)', mysql_type)
        if match:
            size = match.group(1)
            return f'VARCHAR({size})'
        return 'VARCHAR'
    elif mysql_type.startswith('char('):
        match = re.search(r'char\((\d+)\)', mysql_type)
        if match:
            size = match.group(1)
            return f'CHAR({size})'
        return 'CHAR'
    elif mysql_type == 'text':
        return 'TEXT'
    elif mysql_type == 'longtext':
        return 'TEXT'
    elif mysql_type == 'mediumtext':
        return 'TEXT'
    
    # 숫자 타입
    elif mysql_type.startswith('decimal(') or mysql_type.startswith('numeric('):
        return mysql_type.replace('decimal', 'NUMERIC').replace('numeric', 'NUMERIC')
    elif mysql_type.startswith('float(') or mysql_type == 'float':
        return 'REAL'
    elif mysql_type.startswith('double(') or mysql_type == 'double':
        return 'DOUBLE PRECISION'
    
    # 날짜/시간 타입
    elif mysql_type == 'date':
        return 'DATE'
    elif mysql_type == 'time':
        return 'TIME'
    elif mysql_type == 'datetime':
        return 'TIMESTAMP'
    elif mysql_type == 'timestamp':
        return 'TIMESTAMP'
    elif mysql_type.startswith('year(') or mysql_type == 'year':
        return 'INTEGER'
    
    # 기타
    elif mysql_type == 'blob':
        return 'BYTEA'
    elif mysql_type == 'longblob':
        return 'BYTEA'
    elif mysql_type == 'json':
        return 'JSONB'
    
    return mysql_type.upper()


def convert_default_value(default: Optional[str], pg_type: str) -> Optional[str]:
    """MySQL 기본값을 PostgreSQL 기본값으로 변환"""
    if default is None:
        return None
    
    default = str(default).strip()
    
    if default.upper() == 'NULL':
        return None
    
    # MySQL의 잘못된 날짜 형식 처리
    if default in ('0000-00-00 00:00:00', '0000-00-00', '00:00:00'):
        return None
    
    # CURRENT_TIMESTAMP 변환 (괄호 제거)
    if default.upper() in ('CURRENT_TIMESTAMP', 'CURRENT_TIMESTAMP()', 'NOW()', 'NOW'):
        return 'CURRENT_TIMESTAMP'
    
    # PostgreSQL에서 함수 호출은 괄호 없이 사용
    if default.upper().endswith('()'):
        func_name = default.upper().replace('()', '')
        if func_name in ('CURRENT_TIMESTAMP', 'NOW', 'CURRENT_DATE', 'CURRENT_TIME'):
            return func_name
    
    # 문자열 타입 처리
    if pg_type.upper().startswith(('VARCHAR', 'CHAR', 'TEXT')):
        if not (default.startswith("'") and default.endswith("'")):
            default = default.replace("'", "''")
            return f"'{default}'"
    
    return default


def generate_postgresql_create_table(schema: Dict[str, Any]) -> tuple:
    """백업된 스키마를 기반으로 PostgreSQL CREATE TABLE 문 생성"""
    table_name = schema['table_name']
    columns = schema['columns']
    check_constraints = schema.get('check_constraints', [])
    
    pg_table_name = table_name.lower()
    
    column_definitions = []
    primary_keys = []
    
    for col in columns:
        field_name = col['Field'].lower()
        mysql_type = col['Type']
        is_nullable = col['Null'] == 'YES'
        is_primary = col['Key'] == 'PRI'
        default_val = col['Default']
        extra = col.get('Extra', '')
        
        pg_type = mysql_type_to_postgresql(mysql_type)
        
        col_def = f'  {field_name} {pg_type}'
        
        if not is_nullable:
            col_def += ' NOT NULL'
        
        if 'auto_increment' in extra.lower():
            if pg_type == 'INTEGER':
                col_def = col_def.replace('INTEGER', 'SERIAL')
            elif pg_type == 'BIGINT':
                col_def = col_def.replace('BIGINT', 'BIGSERIAL')
        elif default_val is not None:
            pg_default = convert_default_value(default_val, pg_type)
            if pg_default:
                col_def += f' DEFAULT {pg_default}'
        
        column_definitions.append(col_def)
        
        if is_primary:
            primary_keys.append(field_name)
    
    create_sql = f'CREATE TABLE IF NOT EXISTS {pg_table_name} (\n'
    create_sql += ',\n'.join(column_definitions)
    
    if primary_keys:
        create_sql += f',\n  PRIMARY KEY ({", ".join(primary_keys)})\n'
    
    # Check constraint 처리
    for constraint in check_constraints:
        constraint_expr = constraint['expression']
        constraint_name = constraint.get('name')
        
        # chat_messages 테이블의 sender_type check constraint 수정
        if pg_table_name == 'chat_messages' and 'sender_type' in constraint_expr.lower():
            # sender_type check constraint를 pro, manager 포함하도록 수정
            # MySQL: sender_type IN ('member', 'admin')
            # PostgreSQL: sender_type IN ('member', 'admin', 'pro', 'manager')
            constraint_expr = "sender_type IN ('member', 'admin', 'pro', 'manager')"
            constraint_name = 'chat_messages_sender_type_check'
        
        # PostgreSQL CHECK 제약 조건 추가
        if constraint_name:
            create_sql += f',\n  CONSTRAINT {constraint_name} CHECK ({constraint_expr})\n'
        else:
            create_sql += f',\n  CHECK ({constraint_expr})\n'
    
    create_sql += ');'
    
    return create_sql, pg_table_name


def load_table_schema(table_name: str) -> Optional[Dict[str, Any]]:
    """테이블 스키마 로드"""
    schema_file = os.path.join(SCHEMA_DIR, f"{table_name}_schema.json")
    if not os.path.exists(schema_file):
        return None
    
    with open(schema_file, 'r', encoding='utf-8') as f:
        return json.load(f)


def load_table_data(table_name: str) -> Optional[List[Dict[str, Any]]]:
    """테이블 데이터 로드"""
    data_file = os.path.join(DATA_DIR, f"{table_name}_data.json")
    if not os.path.exists(data_file):
        return None
    
    with open(data_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
        return data.get('data', [])


def drop_table_if_exists(cursor, table_name: str):
    """테이블이 존재하면 삭제"""
    try:
        cursor.execute(f'DROP TABLE IF EXISTS {table_name} CASCADE;')
        print(f"  ✓ 기존 테이블 삭제: {table_name}")
    except Exception as e:
        print(f"  ⚠ 테이블 삭제 중 오류 (무시): {str(e)}")


def create_table(cursor, create_sql: str, table_name: str):
    """테이블 생성 및 RLS 활성화"""
    try:
        cursor.execute(create_sql)
        print(f"  ✓ 테이블 생성 완료: {table_name}")
        
        # RLS 활성화 및 기본 정책 생성
        enable_rls_for_table(cursor, table_name)
        
        return True
    except Exception as e:
        print(f"  ✗ 테이블 생성 실패: {str(e)}")
        print(f"    SQL: {create_sql[:200]}...")
        return False


def enable_rls_for_table(cursor, table_name: str):
    """테이블에 RLS 활성화 및 기본 정책 생성"""
    try:
        # 1. RLS 활성화
        cursor.execute(f'ALTER TABLE {table_name} ENABLE ROW LEVEL SECURITY')
        print(f"  ✓ RLS 활성화: {table_name}")
        
        # 2. 기본 정책 생성 (모든 접근 허용 - 기존 동작 유지)
        # 기존 정책이 있으면 삭제
        for policy_suffix in ['allow_all_select', 'allow_all_insert', 'allow_all_update', 'allow_all_delete']:
            full_policy_name = f'{policy_suffix}_{table_name}'
            try:
                cursor.execute(f'DROP POLICY IF EXISTS {full_policy_name} ON {table_name}')
            except:
                pass
        
        # SELECT 정책
        try:
            cursor.execute(f'''
                CREATE POLICY allow_all_select_{table_name} ON {table_name}
                FOR SELECT
                USING (true)
            ''')
        except Exception as e:
            print(f"  ⚠ SELECT 정책 생성 중 오류 (무시): {str(e)[:50]}")
        
        # INSERT 정책
        try:
            cursor.execute(f'''
                CREATE POLICY allow_all_insert_{table_name} ON {table_name}
                FOR INSERT
                WITH CHECK (true)
            ''')
        except Exception as e:
            print(f"  ⚠ INSERT 정책 생성 중 오류 (무시): {str(e)[:50]}")
        
        # UPDATE 정책
        try:
            cursor.execute(f'''
                CREATE POLICY allow_all_update_{table_name} ON {table_name}
                FOR UPDATE
                USING (true)
                WITH CHECK (true)
            ''')
        except Exception as e:
            print(f"  ⚠ UPDATE 정책 생성 중 오류 (무시): {str(e)[:50]}")
        
        # DELETE 정책
        try:
            cursor.execute(f'''
                CREATE POLICY allow_all_delete_{table_name} ON {table_name}
                FOR DELETE
                USING (true)
            ''')
        except Exception as e:
            print(f"  ⚠ DELETE 정책 생성 중 오류 (무시): {str(e)[:50]}")
        
        print(f"  ✓ RLS 정책 생성 완료: {table_name}")
        
    except Exception as e:
        print(f"  ⚠ RLS 활성화 중 오류 (무시): {str(e)[:50]}")
        # RLS 활성화 실패해도 테이블 생성은 성공으로 처리


def get_value_case_insensitive(row: Dict[str, Any], col: str) -> Any:
    """대소문자 무관하게 딕셔너리에서 값 찾기"""
    # 정확히 일치하는 키 먼저 찾기
    if col in row:
        return row[col]
    # 대소문자 무관하게 찾기
    col_lower = col.lower()
    for key in row.keys():
        if key.lower() == col_lower:
            return row[key]
    return None


def insert_table_data(cursor, table_name: str, data: List[Dict[str, Any]]):
    """테이블 데이터 삽입"""
    if not data:
        print(f"  ⚠ 데이터 없음: {table_name}")
        return
    
    try:
        # 모든 행에서 키를 수집하여 완전한 키 목록 생성 (대소문자 무관)
        all_keys = set()
        for row in data:
            for key in row.keys():
                all_keys.add(key.lower())
        
        # 원본 키와 소문자 키 매핑 생성 (모든 행에서 수집)
        key_mapping = {}
        for row in data:
            for key in row.keys():
                key_lower = key.lower()
                if key_lower not in key_mapping:
                    key_mapping[key_lower] = key
        
        columns = list(all_keys)
        
        # 스키마 로드하여 컬럼 타입 확인
        schema = load_table_schema(table_name)
        column_types = {}
        if schema:
            for col in schema.get('columns', []):
                col_name = col['Field'].lower()
                mysql_type = col['Type'].lower()
                column_types[col_name] = mysql_type
        
        values_list = []
        for row in data:
            values = []
            for col in columns:
                # 대소문자 무관하게 값 가져오기
                value = get_value_case_insensitive(row, col)
                
                if value is None:
                    values.append(None)
                elif isinstance(value, bool):
                    values.append(value)
                elif isinstance(value, (int, float)):
                    values.append(value)
                elif isinstance(value, str):
                    # TIME 타입에 interval 값이 들어가는 경우 처리
                    col_type = column_types.get(col, '')
                    if 'time' in col_type and ('interval' in str(value).lower() or 'day' in str(value).lower()):
                        # "1 day, 0:00:00" 같은 값을 TIME으로 변환 시도
                        try:
                            # interval에서 시간 부분만 추출 시도
                            if ':' in value:
                                time_part = value.split(',')[-1].strip() if ',' in value else value
                                if ':' in time_part:
                                    values.append(time_part)
                                else:
                                    values.append(None)
                            else:
                                values.append(None)
                        except:
                            values.append(None)
                    # MySQL의 잘못된 날짜 형식 처리
                    elif value in ('0000-00-00 00:00:00', '0000-00-00', '00:00:00'):
                        values.append(None)
                    else:
                        values.append(value)
                else:
                    values.append(str(value))
            
            values_list.append(tuple(values))
        
        table_ident = sql.Identifier(table_name)
        cols_ident = [sql.Identifier(col) for col in columns]
        cols_str = sql.SQL(', ').join(cols_ident)
        
        insert_sql = sql.SQL('INSERT INTO {} ({}) VALUES %s').format(
            table_ident,
            cols_str
        )
        
        batch_size = 1000
        total_inserted = 0
        
        for i in range(0, len(values_list), batch_size):
            batch = values_list[i:i + batch_size]
            execute_values(cursor, insert_sql, batch, page_size=batch_size)
            total_inserted += len(batch)
        
        print(f"  ✓ 데이터 삽입 완료: {table_name} ({total_inserted}개 행)")
        
    except Exception as e:
        print(f"  ✗ 데이터 삽입 실패: {str(e)}")
        import traceback
        traceback.print_exc()


def migrate_table(cursor, table_name: str):
    """단일 테이블 마이그레이션"""
    schema = load_table_schema(table_name)
    if not schema:
        print(f"  ✗ 스키마 파일을 찾을 수 없습니다: {table_name}")
        return False
    
    create_sql, pg_table_name = generate_postgresql_create_table(schema)
    
    drop_table_if_exists(cursor, pg_table_name)
    
    if not create_table(cursor, create_sql, pg_table_name):
        return False
    
    data = load_table_data(table_name)
    if data:
        insert_table_data(cursor, pg_table_name, data)
    else:
        print(f"  ⚠ 데이터 파일을 찾을 수 없습니다: {table_name}")
    
    return True


def parse_connection_string(conn_str: str) -> dict:
    """Supabase 연결 문자열을 파싱하여 설정 추출"""
    import urllib.parse
    # postgresql://postgres:password@host:port/database 형식 파싱
    parsed = urllib.parse.urlparse(conn_str)
    return {
        'host': parsed.hostname,
        'port': parsed.port or 5432,
        'database': parsed.path.lstrip('/') if parsed.path else 'postgres',
        'user': parsed.username,
        'password': parsed.password
    }


def migrate_to_supabase(tables: List[str]):
    """Supabase로 마이그레이션 수행"""
    print("\n" + "=" * 60)
    print("2단계: Supabase 마이그레이션 시작")
    print("=" * 60)
    
    project_url = f"https://supabase.com/dashboard/project/{SUPABASE_CONFIG['project_id']}"
    print(f"\n📋 Supabase 프로젝트 정보:")
    print(f"   프로젝트 ID: {SUPABASE_CONFIG['project_id']}")
    print(f"   프로젝트 URL: {project_url}")
    
    # 연결 문자열이 설정 파일에 있는지 확인
    keys_file = os.path.join(os.path.dirname(__file__), 'supabase_keys.json')
    connection_string = None
    if os.path.exists(keys_file):
        with open(keys_file, 'r', encoding='utf-8') as f:
            keys = json.load(f)
            connection_string = keys.get('connection_string')
    
    # 연결 문자열이 있으면 파싱하여 사용
    if connection_string:
        print(f"\n✓ 연결 문자열 발견, 파싱 중...")
        try:
            parsed = parse_connection_string(connection_string)
            # 비밀번호는 설정 파일에서 로드한 것을 사용 (연결 문자열의 비밀번호 무시)
            password_backup = SUPABASE_CONFIG.get('password')
            SUPABASE_CONFIG.update(parsed)
            # 비밀번호는 설정 파일에서 로드한 것을 사용
            if password_backup:
                SUPABASE_CONFIG['password'] = password_backup
            print(f"   호스트: {SUPABASE_CONFIG['host']}")
            print(f"   포트: {SUPABASE_CONFIG['port']}")
            print(f"   사용자: {SUPABASE_CONFIG['user']}")
            print(f"   데이터베이스: {SUPABASE_CONFIG['database']}")
        except Exception as e:
            print(f"   ⚠ 연결 문자열 파싱 실패: {str(e)}")
            print(f"   기본 설정 사용")
    else:
        print(f"\n📋 현재 연결 설정:")
        print(f"   호스트: {SUPABASE_CONFIG['host']}")
        print(f"   포트: {SUPABASE_CONFIG['port']}")
        print(f"   사용자: {SUPABASE_CONFIG['user']}")
        print(f"   데이터베이스: {SUPABASE_CONFIG['database']}")
    
    # Supabase 비밀번호 확인
    password = load_supabase_password()
    if not password:
        print("\n✗ Supabase 데이터베이스 비밀번호를 찾을 수 없습니다.")
        print("   supabase_keys.json 파일에 'db_password' 키를 추가하거나")
        print("   환경 변수 SUPABASE_DB_PASSWORD를 설정하세요.")
        return False
    
    SUPABASE_CONFIG['password'] = password
    print(f"✓ 비밀번호 확인 완료 (설정 파일에서 로드됨)")
    
    # Supabase 연결
    try:
        print(f"\nSupabase 직접 연결 시도 중...")
        print(f"호스트: {SUPABASE_CONFIG['host']}")
        print(f"포트: {SUPABASE_CONFIG['port']}")
        print(f"데이터베이스: {SUPABASE_CONFIG['database']}")
        print(f"사용자: {SUPABASE_CONFIG['user']}")
        
        # 연결 문자열에서 파싱한 정보 사용 (직접 연결)
        conn_params = {
            'host': SUPABASE_CONFIG['host'],
            'port': SUPABASE_CONFIG['port'],
            'database': SUPABASE_CONFIG['database'],
            'user': SUPABASE_CONFIG['user'],
            'password': SUPABASE_CONFIG['password'],
            'sslmode': 'require',
            'connect_timeout': 10
        }
        
        conn = psycopg2.connect(**conn_params)
        conn.autocommit = False
        cursor = conn.cursor()
        print(f"✓ Supabase 연결 성공!")
        
    except Exception as e:
        print(f"✗ 직접 연결 실패: {str(e)}")
        print(f"\n풀러 연결로 재시도 중...")
        
        # 풀러 연결로 재시도
        try:
            # 풀러 연결 문자열 확인
            keys_file = os.path.join(os.path.dirname(__file__), 'supabase_keys.json')
            pooler_connection_string = None
            if os.path.exists(keys_file):
                with open(keys_file, 'r', encoding='utf-8') as f:
                    keys = json.load(f)
                    pooler_connection_string = keys.get('pooler_connection_string')
            
            if pooler_connection_string:
                # 풀러 연결 문자열 파싱
                parsed = parse_connection_string(pooler_connection_string)
                pooler_params = {
                    'host': parsed['host'],
                    'port': parsed['port'],
                    'database': parsed['database'],
                    'user': parsed['user'],
                    'password': SUPABASE_CONFIG['password'],
                    'sslmode': 'require',
                    'connect_timeout': 10
                }
            else:
                # 기본 풀러 설정
                pooler_params = {
                    'host': 'aws-1-ap-northeast-2.pooler.supabase.com',
                    'port': 6543,
                    'database': 'postgres',
                    'user': 'postgres.yejialakeivdhwntmagf',
                    'password': SUPABASE_CONFIG['password'],
                    'sslmode': 'require',
                    'connect_timeout': 10
                }
            
            print(f"  호스트: {pooler_params['host']}")
            print(f"  포트: {pooler_params['port']}")
            print(f"  사용자: {pooler_params['user']}")
            
            conn = psycopg2.connect(**pooler_params)
            conn.autocommit = False
            cursor = conn.cursor()
            print(f"✓ Supabase 연결 성공 (풀러 연결)")
            
        except Exception as e2:
            print(f"✗ 풀러 연결도 실패: {str(e2)}")
            print(f"\n✗ 모든 연결 시도 실패")
            print(f"\n연결 정보 확인:")
            print(f"  프로젝트 ID: {SUPABASE_CONFIG['project_id']}")
            print(f"  Supabase Dashboard에서 연결 문자열을 확인하세요:")
            print(f"  https://supabase.com/dashboard/project/{SUPABASE_CONFIG['project_id']}/settings/database")
            print(f"\n연결 문자열을 supabase_keys.json의 'connection_string'에 정확히 입력하세요.")
            import traceback
            traceback.print_exc()
            return False
    
    # 직접 연결 성공 시 기존 방식 사용
    try:
        print(f"\n테이블 마이그레이션 시작 (직접 연결)...")
        print("-" * 60)
        
        success_count = 0
        fail_count = 0
        
        for i, table_name in enumerate(tables, 1):
            print(f"\n[{i}/{len(tables)}] {table_name}")
            
            try:
                if migrate_table(cursor, table_name):
                    conn.commit()
                    success_count += 1
                else:
                    conn.rollback()
                    fail_count += 1
            except Exception as e:
                print(f"  ✗ 마이그레이션 중 오류: {str(e)}")
                conn.rollback()
                fail_count += 1
                import traceback
                traceback.print_exc()
                continue
        
        print(f"\n" + "=" * 60)
        print("마이그레이션 완료!")
        print(f"성공: {success_count}개 테이블")
        print(f"실패: {fail_count}개 테이블")
        print("=" * 60)
        
        # 시퀀스 재설정
        print(f"\n" + "=" * 60)
        print("3단계: 시퀀스 재설정")
        print("=" * 60)
        reset_all_sequences(cursor)
        conn.commit()
        
        return True
        
    except Exception as e:
        print(f"\n✗ 마이그레이션 중 오류 발생: {str(e)}")
        import traceback
        traceback.print_exc()
        conn.rollback()
        return False
    
    finally:
        cursor.close()
        conn.close()
        print("\nSupabase 연결 종료")


# ==================== 시퀀스 재설정 함수 ====================

# SERIAL(자동 증가) 컬럼이 있는 테이블 목록
# supabase_adapter.dart의 _tableAutoIncrementColumns와 동기화 필요
SERIAL_COLUMNS = {
    # v3 테이블
    'v3_contract_history': 'contract_history_id',
    'v3_ls_countings': 'ls_counting_id',
    'v3_members': 'member_id',
    # v2 결제/청구 관련
    'v2_bills': 'bill_id',
    'v2_bill_term': 'bill_term_id',
    'v2_bill_term_hold': 'term_hold_id',
    'v2_bill_times': 'bill_min_id',
    'v2_bill_games': 'bill_game_id',
    'v2_bill_games_group': 'group_play_id',
    # v2 회원/계약 관련
    'v2_members': 'member_id',
    'v2_contracts': 'contract_id',
    'v2_member_pro_match': 'member_pro_relation_id',
    # v2 게시판 관련
    'v2_board': 'board_id',
    'v2_board_by_member': 'memberboard_id',
    'v2_board_by_member_replies': 'reply_id',
    'v2_board_comment': 'comment_id',
    # v2 락커 관련
    'v2_locker_status': 'locker_id',
    'v2_locker_bill': 'locker_bill_id',
    # v2 메시지/결제
    'v2_message': 'msg_id',
    'v2_portone_payments': 'portone_payment_id',
    # v2 스케줄/직원 관련
    'v2_schedule_adjusted_pro': 'scheduled_staff_id',
    'v2_schedule_adjusted_manager': 'scheduled_staff_id',
    'v2_staff_pro': 'pro_contract_id',
    'v2_staff_manager': 'manager_contract_id',
    # v2 기타
    'v2_term_member': 'term_id',
    'v2_discount_coupon': 'coupon_id',
    'v2_discount_coupon_auto_triggers': 'trigger_id',
    'v2_ls_orders': 'ls_order_id',
    'v2_wol_settings': 'pc_id',
}


def reset_all_sequences(cursor):
    """마이그레이션 후 모든 SERIAL 컬럼의 시퀀스를 재설정"""
    print("\n시퀀스 재설정 시작...")
    print("-" * 60)
    
    success_count = 0
    fail_count = 0
    
    for table_name, column_name in SERIAL_COLUMNS.items():
        try:
            # 해당 테이블의 최대 ID 조회
            cursor.execute(f"SELECT MAX({column_name}) FROM {table_name}")
            result = cursor.fetchone()
            max_id = result[0] if result[0] is not None else 0
            
            # 시퀀스 재설정
            cursor.execute(f"""
                SELECT setval(
                    pg_get_serial_sequence('{table_name}', '{column_name}'), 
                    {max_id}, 
                    true
                )
            """)
            
            print(f"  ✓ {table_name}.{column_name}: 시퀀스를 {max_id}로 재설정")
            success_count += 1
            
        except Exception as e:
            # 테이블이나 시퀀스가 없는 경우 무시
            print(f"  ⚠ {table_name}.{column_name}: 건너뜀 ({str(e)[:50]}...)")
            fail_count += 1
            continue
    
    print("-" * 60)
    print(f"시퀀스 재설정 완료: 성공 {success_count}개, 건너뜀 {fail_count}개")


# ==================== 메인 함수 ====================

def migrate_single_table(table_name: str):
    """단일 테이블만 마이그레이션 (백업 파일에서)"""
    print("=" * 60)
    print(f"단일 테이블 마이그레이션: {table_name}")
    print("=" * 60)
    
    # 스키마 파일 확인
    schema = load_table_schema(table_name)
    if not schema:
        print(f"✗ 스키마 파일을 찾을 수 없습니다: {table_name}")
        return False
    
    # 데이터 파일 확인
    data = load_table_data(table_name)
    if data is None:
        print(f"✗ 데이터 파일을 찾을 수 없습니다: {table_name}")
        return False
    
    print(f"✓ 스키마 파일 발견: {table_name}")
    print(f"✓ 데이터 파일 발견: {len(data)}개 행")
    
    # Supabase 연결
    password = load_supabase_password()
    if not password:
        print("✗ Supabase 비밀번호를 찾을 수 없습니다.")
        return False
    
    keys_file = os.path.join(os.path.dirname(__file__), 'supabase_keys.json')
    connection_string = None
    if os.path.exists(keys_file):
        with open(keys_file, 'r', encoding='utf-8') as f:
            keys = json.load(f)
            connection_string = keys.get('connection_string')
    
    try:
        if connection_string:
            parsed = parse_connection_string(connection_string)
            conn_params = {
                'host': parsed['host'],
                'port': parsed['port'],
                'database': parsed['database'],
                'user': parsed['user'],
                'password': password,
                'sslmode': 'require',
                'connect_timeout': 10
            }
        else:
            conn_params = {
                'host': SUPABASE_CONFIG['host'],
                'port': SUPABASE_CONFIG['port'],
                'database': SUPABASE_CONFIG['database'],
                'user': SUPABASE_CONFIG['user'],
                'password': password,
                'sslmode': 'require',
                'connect_timeout': 10
            }
        
        print(f"\nSupabase 연결 중...")
        conn = psycopg2.connect(**conn_params)
        conn.autocommit = False
        cursor = conn.cursor()
        print(f"✓ Supabase 연결 성공!")
        
        # 테이블 마이그레이션
        if migrate_table(cursor, table_name):
            conn.commit()
            print(f"\n✓ 마이그레이션 완료: {table_name}")
            return True
        else:
            conn.rollback()
            print(f"\n✗ 마이그레이션 실패: {table_name}")
            return False
        
    except Exception as e:
        print(f"✗ 오류 발생: {str(e)}")
        import traceback
        traceback.print_exc()
        return False
    
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()
        print("Supabase 연결 종료")


def migrate_tables_from_backup(table_names: List[str]):
    """백업 파일에서 특정 테이블들만 마이그레이션"""
    print("=" * 60)
    print(f"백업에서 테이블 마이그레이션: {len(table_names)}개")
    print("=" * 60)
    
    success_count = 0
    fail_count = 0
    
    for table_name in table_names:
        print(f"\n{'='*40}")
        if migrate_single_table(table_name):
            success_count += 1
        else:
            fail_count += 1
    
    print(f"\n" + "=" * 60)
    print(f"마이그레이션 결과: 성공 {success_count}개, 실패 {fail_count}개")
    print("=" * 60)


def main():
    """통합 메인 함수"""
    import sys
    
    # 명령줄 인수 확인
    if len(sys.argv) > 1:
        if sys.argv[1] == '--table':
            # 특정 테이블만 마이그레이션
            if len(sys.argv) > 2:
                table_names = sys.argv[2:]
                migrate_tables_from_backup(table_names)
                return
            else:
                print("사용법: python full_migration.py --table <테이블명1> [테이블명2] ...")
                return
        elif sys.argv[1] == '--help':
            print("사용법:")
            print("  전체 마이그레이션: python full_migration.py")
            print("  특정 테이블만: python full_migration.py --table <테이블명1> [테이블명2] ...")
            return
    
    print("=" * 60)
    print("MySQL/MariaDB → Supabase 통합 마이그레이션")
    print("=" * 60)
    
    # 1단계: MySQL 백업
    tables = backup_from_mysql()
    
    if not tables:
        print("\n✗ 백업 실패로 인해 마이그레이션을 중단합니다.")
        return
    
    # 2단계: Supabase 마이그레이션
    success = migrate_to_supabase(tables)
    
    if success:
        print("\n" + "=" * 60)
        print("전체 프로세스 완료!")
        print("=" * 60)
    else:
        print("\n" + "=" * 60)
        print("마이그레이션 중 오류가 발생했습니다.")
        print("백업 파일은 저장되었으므로 나중에 다시 시도할 수 있습니다.")
        print("=" * 60)


if __name__ == '__main__':
    main()

