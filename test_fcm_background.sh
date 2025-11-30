#!/bin/bash

# FCM 백그라운드 알림 테스트 스크립트
# 사용법: ./test_fcm_background.sh

echo "🧪 FCM 백그라운드 알림 테스트"
echo "================================"
echo ""

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Edge Function 환경 변수 확인
echo "1️⃣ Edge Function 환경 변수 확인"
echo "   Supabase 대시보드에서 다음 환경 변수가 설정되어 있는지 확인하세요:"
echo "   - FCM_SERVER_KEY"
echo "   - SUPABASE_URL"
echo "   - SUPABASE_SERVICE_ROLE_KEY"
echo ""
read -p "   환경 변수가 모두 설정되었나요? (y/n): " env_setup
if [ "$env_setup" != "y" ]; then
    echo -e "${RED}❌ 환경 변수를 먼저 설정해주세요.${NC}"
    echo "   가이드: SETUP_FCM_ENV_VARS.md 파일 참조"
    exit 1
fi
echo -e "${GREEN}✅ 환경 변수 설정 확인${NC}"
echo ""

# 2. FCM 토큰 확인
echo "2️⃣ FCM 토큰 확인"
echo "   Supabase 대시보드 > Table Editor > fcm_tokens 테이블에서"
echo "   테스트할 branch_id의 토큰이 있는지 확인하세요."
echo ""
read -p "   FCM 토큰이 저장되어 있나요? (y/n): " token_exists
if [ "$token_exists" != "y" ]; then
    echo -e "${YELLOW}⚠️  FCM 토큰이 없습니다. 앱을 실행하여 토큰을 발급받으세요.${NC}"
    echo "   앱 실행 후 로그인하면 자동으로 토큰이 저장됩니다."
    exit 1
fi
echo -e "${GREEN}✅ FCM 토큰 확인${NC}"
echo ""

# 3. 테스트 메시지 전송 안내
echo "3️⃣ 테스트 메시지 전송"
echo ""
echo "   다음 단계를 따라 테스트하세요:"
echo ""
echo "   📱 준비:"
echo "   - 기기 A: 회원 계정으로 로그인"
echo "   - 기기 B: 관리자 계정으로 로그인"
echo ""
echo "   🔄 테스트 시나리오 1: 회원 → 관리자"
echo "   1. 기기 B를 백그라운드로 전환 (홈 버튼)"
echo "   2. 기기 A에서 관리자에게 메시지 전송"
echo "   3. 기기 B에서 백그라운드 알림 확인"
echo ""
read -p "   테스트를 진행하시겠습니까? (y/n): " test1
if [ "$test1" == "y" ]; then
    echo -e "${YELLOW}⏳ 테스트 진행 중...${NC}"
    echo "   메시지 전송 후 기기 B에서 알림을 확인하세요."
    echo ""
    read -p "   알림이 수신되었나요? (y/n): " result1
    if [ "$result1" == "y" ]; then
        echo -e "${GREEN}✅ 테스트 1 성공!${NC}"
    else
        echo -e "${RED}❌ 테스트 1 실패${NC}"
        echo "   Edge Function 로그를 확인하세요:"
        echo "   Supabase 대시보드 > Edge Functions > send-chat-notification > Logs"
    fi
fi
echo ""

# 4. Edge Function 로그 확인 안내
echo "4️⃣ Edge Function 로그 확인"
echo ""
echo "   Supabase 대시보드에서 로그를 확인하세요:"
echo "   - Edge Functions > send-chat-notification > Logs"
echo ""
echo "   확인할 로그:"
echo "   ✅ '🔔 [Edge Function] 새 메시지 수신'"
echo "   ✅ '✅ [Edge Function] FCM 발송 완료'"
echo "   ❌ 에러 메시지가 없어야 함"
echo ""
read -p "   로그를 확인하셨나요? (y/n): " log_check
if [ "$log_check" == "y" ]; then
    echo -e "${GREEN}✅ 로그 확인 완료${NC}"
else
    echo -e "${YELLOW}⚠️  로그 확인을 권장합니다.${NC}"
fi
echo ""

# 5. 종료 상태 테스트 안내
echo "5️⃣ 종료 상태 테스트"
echo ""
echo "   📱 테스트 시나리오:"
echo "   1. 앱을 완전히 종료 (스와이프로 종료)"
echo "   2. 다른 기기에서 메시지 전송"
echo "   3. 종료된 앱에서 알림 확인"
echo ""
read -p "   종료 상태 테스트를 진행하시겠습니까? (y/n): " test2
if [ "$test2" == "y" ]; then
    echo -e "${YELLOW}⏳ 테스트 진행 중...${NC}"
    echo "   앱을 종료한 후 메시지를 전송하세요."
    echo ""
    read -p "   알림이 수신되었나요? (y/n): " result2
    if [ "$result2" == "y" ]; then
        echo -e "${GREEN}✅ 테스트 2 성공!${NC}"
    else
        echo -e "${RED}❌ 테스트 2 실패${NC}"
        echo "   Edge Function 로그와 FCM 토큰을 확인하세요."
    fi
fi
echo ""

# 최종 결과
echo "================================"
echo "🎉 테스트 완료!"
echo ""
echo "📝 다음 단계:"
echo "   1. 정기적으로 Edge Function 로그 확인"
echo "   2. 에러 발생 시 즉시 대응"
echo "   3. Database Webhooks 전환 검토 (운영 관점)"
echo ""



