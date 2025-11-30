-- 채팅 메시지 읽음 상태를 sender_type별로 개별 추적하기 위한 마이그레이션
-- 기존 is_read 컬럼은 유지하되, read_by JSONB 컬럼 추가

-- 1. read_by JSONB 컬럼 추가
ALTER TABLE chat_messages 
ADD COLUMN IF NOT EXISTS read_by JSONB DEFAULT '{"member": false, "pro": false, "manager": false, "admin": false}'::jsonb;

-- 2. 기존 is_read 데이터를 read_by로 마이그레이션
-- 회원이 보낸 메시지: admin, pro, manager가 읽었는지 확인
UPDATE chat_messages
SET read_by = jsonb_set(
  jsonb_set(
    jsonb_set(
      '{"member": false, "pro": false, "manager": false, "admin": false}'::jsonb,
      '{admin}',
      to_jsonb(is_read)
    ),
    '{pro}',
    to_jsonb(is_read)
  ),
  '{manager}',
  to_jsonb(is_read)
)
WHERE sender_type = 'member' AND is_read = true;

-- 관리자/프로/매니저가 보낸 메시지: member가 읽었는지 확인
UPDATE chat_messages
SET read_by = jsonb_set(
  '{"member": false, "pro": false, "manager": false, "admin": false}'::jsonb,
  '{member}',
  to_jsonb(is_read)
)
WHERE sender_type IN ('admin', 'pro', 'manager') AND is_read = true;

-- 3. 인덱스 추가 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_chat_messages_read_by_member 
ON chat_messages ((read_by->>'member'))
WHERE (read_by->>'member')::boolean = false;

CREATE INDEX IF NOT EXISTS idx_chat_messages_read_by_admin 
ON chat_messages ((read_by->>'admin'))
WHERE (read_by->>'admin')::boolean = false;

CREATE INDEX IF NOT EXISTS idx_chat_messages_read_by_pro 
ON chat_messages ((read_by->>'pro'))
WHERE (read_by->>'pro')::boolean = false;

CREATE INDEX IF NOT EXISTS idx_chat_messages_read_by_manager 
ON chat_messages ((read_by->>'manager'))
WHERE (read_by->>'manager')::boolean = false;

-- 4. 코멘트 추가
COMMENT ON COLUMN chat_messages.read_by IS '각 sender_type별 읽음 상태를 저장하는 JSONB 필드. 예: {"member": true, "pro": false, "manager": false, "admin": true}';

