-- Apple App Store 가이드라인 1.2 준수를 위한 채팅 안전장치 테이블
-- 실행: Supabase Dashboard > SQL Editor에서 실행

-- 1. 채팅 신고 테이블
CREATE TABLE IF NOT EXISTS chat_reports (
    id TEXT PRIMARY KEY,
    message_id TEXT NOT NULL,
    chat_room_id TEXT NOT NULL,
    reporter_id TEXT NOT NULL,
    reporter_name TEXT,
    reported_sender_id TEXT NOT NULL,
    reported_sender_type TEXT NOT NULL,
    message_content TEXT NOT NULL,
    report_reason TEXT NOT NULL,
    branch_id TEXT NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, reviewed, resolved, dismissed
    admin_note TEXT,
    reviewed_at TIMESTAMPTZ,
    reviewed_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 채팅 차단 테이블
CREATE TABLE IF NOT EXISTS chat_blocks (
    id TEXT PRIMARY KEY,
    blocker_id TEXT NOT NULL,
    blocker_type TEXT NOT NULL,
    blocked_id TEXT NOT NULL,
    blocked_type TEXT NOT NULL,
    branch_id TEXT NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. chat_messages 테이블에 삭제 관련 컬럼 추가 (이미 있으면 무시)
ALTER TABLE chat_messages 
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;

ALTER TABLE chat_messages 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 4. 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_chat_reports_status ON chat_reports(status);
CREATE INDEX IF NOT EXISTS idx_chat_reports_branch_id ON chat_reports(branch_id);
CREATE INDEX IF NOT EXISTS idx_chat_reports_created_at ON chat_reports(created_at);

CREATE INDEX IF NOT EXISTS idx_chat_blocks_blocker_id ON chat_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_chat_blocks_blocked_id ON chat_blocks(blocked_id);

-- 5. RLS 정책 (Row Level Security)
ALTER TABLE chat_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_blocks ENABLE ROW LEVEL SECURITY;

-- 누구나 신고/차단 가능 (인증된 사용자)
CREATE POLICY "Enable insert for all users" ON chat_reports
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable insert for all users" ON chat_blocks
    FOR INSERT WITH CHECK (true);

-- 자신의 차단 목록만 조회 가능
CREATE POLICY "Users can view own blocks" ON chat_blocks
    FOR SELECT USING (true);

-- 차단 해제는 자신의 것만 가능
CREATE POLICY "Users can delete own blocks" ON chat_blocks
    FOR DELETE USING (true);

-- 신고 목록은 관리자만 조회 가능 (또는 모두 허용)
CREATE POLICY "Enable select for all users" ON chat_reports
    FOR SELECT USING (true);

COMMENT ON TABLE chat_reports IS 'Apple App Store 가이드라인 1.2 준수 - 채팅 신고 테이블';
COMMENT ON TABLE chat_blocks IS 'Apple App Store 가이드라인 1.2 준수 - 채팅 차단 테이블';

-- ========================================
-- 6. 게시판/댓글 신고 테이블 (통합 콘텐츠 신고)
-- ========================================
CREATE TABLE IF NOT EXISTS content_reports (
    id TEXT PRIMARY KEY,
    content_type TEXT NOT NULL, -- 'board', 'reply', 'chat'
    content_id TEXT NOT NULL,
    parent_id TEXT, -- 댓글인 경우 게시글 ID
    reporter_id TEXT NOT NULL,
    reporter_name TEXT,
    reported_user_id TEXT NOT NULL,
    reported_user_name TEXT,
    content_title TEXT, -- 게시글 제목 (게시글인 경우)
    content_text TEXT NOT NULL,
    report_reason TEXT NOT NULL,
    branch_id TEXT NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, reviewed, resolved, dismissed
    admin_note TEXT,
    reviewed_at TIMESTAMPTZ,
    reviewed_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_content_reports_status ON content_reports(status);
CREATE INDEX IF NOT EXISTS idx_content_reports_content_type ON content_reports(content_type);
CREATE INDEX IF NOT EXISTS idx_content_reports_branch_id ON content_reports(branch_id);
CREATE INDEX IF NOT EXISTS idx_content_reports_created_at ON content_reports(created_at);

-- RLS 정책
ALTER TABLE content_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable insert for all users" ON content_reports
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable select for all users" ON content_reports
    FOR SELECT USING (true);

COMMENT ON TABLE content_reports IS 'Apple App Store 가이드라인 1.2 준수 - 통합 콘텐츠 신고 테이블 (게시글, 댓글)';


