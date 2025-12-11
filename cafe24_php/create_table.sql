-- =====================================================
-- SMS 인증번호 저장 테이블
-- 카페24 phpMyAdmin에서 실행
-- =====================================================

CREATE TABLE IF NOT EXISTS sms_verification (
    id INT AUTO_INCREMENT PRIMARY KEY,
    phone VARCHAR(20) NOT NULL COMMENT '전화번호 (010-1234-5678)',
    code VARCHAR(6) NOT NULL COMMENT '6자리 인증번호',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시간',
    expires_at DATETIME NOT NULL COMMENT '만료 시간',
    verified_at DATETIME DEFAULT NULL COMMENT '인증 완료 시간',
    attempts INT DEFAULT 0 COMMENT '검증 시도 횟수',
    status ENUM('pending', 'verified', 'expired') DEFAULT 'pending' COMMENT '상태',
    
    INDEX idx_phone (phone),
    INDEX idx_phone_code (phone, code),
    INDEX idx_expires (expires_at),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='SMS 인증번호 저장';

-- =====================================================
-- 오래된 레코드 정리 (선택사항)
-- 매일 크론잡으로 실행하거나, 수동 정리
-- =====================================================

-- 7일 이상 지난 레코드 삭제
-- DELETE FROM sms_verification WHERE created_at < DATE_SUB(NOW(), INTERVAL 7 DAY);



