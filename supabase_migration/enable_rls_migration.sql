-- ============================================
-- RLS (Row Level Security) 활성화 마이그레이션
-- ============================================
-- 목적: 모든 테이블에 RLS 활성화 및 지점별 접근 제어 정책 설정
-- 날짜: 2025-01
-- 주의: RLS 활성화 전에 정책을 먼저 생성해야 데이터 접근이 차단되지 않음
-- ============================================

-- ============================================
-- 1단계: 기본 정책 생성 (현재 상태 유지 - 모든 접근 허용)
-- ============================================
-- 주의: 이 정책은 임시로 모든 접근을 허용합니다.
-- 이후 점진적으로 제한적인 정책으로 교체해야 합니다.

-- 모든 테이블에 대한 기본 정책 생성 함수
DO $$
DECLARE
    table_record RECORD;
    policy_name TEXT;
BEGIN
    FOR table_record IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
    LOOP
        -- SELECT 정책
        policy_name := 'allow_all_select_' || table_record.tablename;
        BEGIN
            EXECUTE format('
                CREATE POLICY %I ON %I
                FOR SELECT
                USING (true)
            ', policy_name, table_record.tablename);
        EXCEPTION WHEN duplicate_object THEN
            RAISE NOTICE 'Policy % already exists, skipping', policy_name;
        END;

        -- INSERT 정책
        policy_name := 'allow_all_insert_' || table_record.tablename;
        BEGIN
            EXECUTE format('
                CREATE POLICY %I ON %I
                FOR INSERT
                WITH CHECK (true)
            ', policy_name, table_record.tablename);
        EXCEPTION WHEN duplicate_object THEN
            RAISE NOTICE 'Policy % already exists, skipping', policy_name;
        END;

        -- UPDATE 정책
        policy_name := 'allow_all_update_' || table_record.tablename;
        BEGIN
            EXECUTE format('
                CREATE POLICY %I ON %I
                FOR UPDATE
                USING (true)
                WITH CHECK (true)
            ', policy_name, table_record.tablename);
        EXCEPTION WHEN duplicate_object THEN
            RAISE NOTICE 'Policy % already exists, skipping', policy_name;
        END;

        -- DELETE 정책
        policy_name := 'allow_all_delete_' || table_record.tablename;
        BEGIN
            EXECUTE format('
                CREATE POLICY %I ON %I
                FOR DELETE
                USING (true)
            ', policy_name, table_record.tablename);
        EXCEPTION WHEN duplicate_object THEN
            RAISE NOTICE 'Policy % already exists, skipping', policy_name;
        END;
    END LOOP;
END $$;

-- ============================================
-- 2단계: RLS 활성화
-- ============================================
DO $$
DECLARE
    table_record RECORD;
BEGIN
    FOR table_record IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', table_record.tablename);
        RAISE NOTICE 'RLS enabled for table: %', table_record.tablename;
    END LOOP;
END $$;

-- ============================================
-- 3단계: 지점별 접근 제어 정책 생성 (branch_id 기반)
-- ============================================
-- 주의: 이 정책은 branch_id 컬럼이 있는 테이블에만 적용됩니다.
-- branch_id가 없는 테이블은 기본 정책(모든 접근 허용)을 유지합니다.

DO $$
DECLARE
    table_record RECORD;
    has_branch_id BOOLEAN;
    policy_name TEXT;
BEGIN
    FOR table_record IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
    LOOP
        -- branch_id 컬럼 존재 여부 확인
        SELECT EXISTS (
            SELECT 1 
            FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = table_record.tablename 
            AND column_name = 'branch_id'
        ) INTO has_branch_id;

        IF has_branch_id THEN
            -- 기존 정책 삭제 (더 제한적인 정책으로 교체)
            BEGIN
                EXECUTE format('DROP POLICY IF EXISTS allow_all_select_%I ON %I', 
                    table_record.tablename, table_record.tablename);
                EXECUTE format('DROP POLICY IF EXISTS allow_all_insert_%I ON %I', 
                    table_record.tablename, table_record.tablename);
                EXECUTE format('DROP POLICY IF EXISTS allow_all_update_%I ON %I', 
                    table_record.tablename, table_record.tablename);
                EXECUTE format('DROP POLICY IF EXISTS allow_all_delete_%I ON %I', 
                    table_record.tablename, table_record.tablename);
            END;

            -- branch_id 기반 SELECT 정책
            -- 주의: 현재는 모든 branch_id 접근 허용 (애플리케이션 레벨에서 필터링)
            -- 향후 JWT 클레임 기반으로 제한 가능
            policy_name := 'branch_select_' || table_record.tablename;
            BEGIN
                EXECUTE format('
                    CREATE POLICY %I ON %I
                    FOR SELECT
                    USING (true)
                    -- 향후: USING (branch_id = current_setting(''app.branch_id'', true))
                ', policy_name, table_record.tablename);
            EXCEPTION WHEN duplicate_object THEN
                RAISE NOTICE 'Policy % already exists, skipping', policy_name;
            END;

            -- branch_id 기반 INSERT 정책
            policy_name := 'branch_insert_' || table_record.tablename;
            BEGIN
                EXECUTE format('
                    CREATE POLICY %I ON %I
                    FOR INSERT
                    WITH CHECK (true)
                    -- 향후: WITH CHECK (branch_id = current_setting(''app.branch_id'', true))
                ', policy_name, table_record.tablename);
            EXCEPTION WHEN duplicate_object THEN
                RAISE NOTICE 'Policy % already exists, skipping', policy_name;
            END;

            -- branch_id 기반 UPDATE 정책
            policy_name := 'branch_update_' || table_record.tablename;
            BEGIN
                EXECUTE format('
                    CREATE POLICY %I ON %I
                    FOR UPDATE
                    USING (true)
                    WITH CHECK (true)
                    -- 향후: USING (branch_id = current_setting(''app.branch_id'', true))
                    --      WITH CHECK (branch_id = current_setting(''app.branch_id'', true))
                ', policy_name, table_record.tablename);
            EXCEPTION WHEN duplicate_object THEN
                RAISE NOTICE 'Policy % already exists, skipping', policy_name;
            END;

            -- branch_id 기반 DELETE 정책
            policy_name := 'branch_delete_' || table_record.tablename;
            BEGIN
                EXECUTE format('
                    CREATE POLICY %I ON %I
                    FOR DELETE
                    USING (true)
                    -- 향후: USING (branch_id = current_setting(''app.branch_id'', true))
                ', policy_name, table_record.tablename);
            EXCEPTION WHEN duplicate_object THEN
                RAISE NOTICE 'Policy % already exists, skipping', policy_name;
            END;

            RAISE NOTICE 'Branch-based policies created for table: %', table_record.tablename;
        ELSE
            RAISE NOTICE 'Table % does not have branch_id column, keeping default policies', table_record.tablename;
        END IF;
    END LOOP;
END $$;

-- ============================================
-- 4단계: 민감 정보 테이블 추가 보호
-- ============================================
-- 비밀번호, 결제 정보 등 민감한 데이터가 있는 테이블에 추가 제한

-- 비밀번호 필드가 있는 테이블: SELECT 시 비밀번호 필드 제외
-- 주의: PostgreSQL RLS는 컬럼 레벨 보안을 직접 지원하지 않으므로
--       애플리케이션 레벨(SupabaseAdapter)에서 처리하는 것이 더 효과적입니다.

-- ============================================
-- 검증 쿼리
-- ============================================
-- RLS 활성화 상태 확인
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- 정책 개수 확인
SELECT 
    schemaname,
    tablename,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY schemaname, tablename
ORDER BY tablename;

