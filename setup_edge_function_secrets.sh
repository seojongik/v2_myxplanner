#!/bin/bash

# Supabase Edge Function 환경 변수 설정 스크립트
# 사용법: ./setup_edge_function_secrets.sh

echo "🔧 Supabase Edge Function 환경 변수 설정"
echo "=========================================="
echo ""

# Service Account Key 파일 경로
SERVICE_ACCOUNT_KEY_FILE="/Users/seojongik/Downloads/autogolfcrm-chat-1e1b0bd599ee.json"

# Service Account Key 읽기 (한 줄로 변환)
SERVICE_ACCOUNT_KEY=$(cat "$SERVICE_ACCOUNT_KEY_FILE" | jq -c .)

echo "📋 설정할 환경 변수:"
echo ""
echo "1. FIREBASE_PROJECT_ID=autogolfcrm-chat"
echo "2. FIREBASE_SERVICE_ACCOUNT_KEY=(JSON 파일 내용)"
echo "3. SUPABASE_URL=https://yejialakeivdhwntmagf.supabase.co"
echo "4. SUPABASE_SERVICE_ROLE_KEY=(Supabase에서 복사 필요)"
echo ""

echo "⚠️  Supabase CLI 로그인이 필요합니다."
echo ""
echo "다음 명령어를 실행하세요:"
echo ""
echo "1. supabase login (브라우저에서 로그인)"
echo "2. supabase link --project-ref yejialakeivdhwntmagf"
echo "3. supabase secrets set FIREBASE_PROJECT_ID=autogolfcrm-chat"
echo "4. supabase secrets set FIREBASE_SERVICE_ACCOUNT_KEY='$SERVICE_ACCOUNT_KEY'"
echo "5. supabase secrets set SUPABASE_URL=https://yejialakeivdhwntmagf.supabase.co"
echo "6. supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<YOUR_SERVICE_ROLE_KEY>"
echo ""
echo "또는 Supabase 대시보드에서 직접 설정하세요:"
echo "1. Edge Functions > send-chat-notification > Settings > Secrets"
echo "2. 각 환경 변수를 하나씩 추가"
echo ""



