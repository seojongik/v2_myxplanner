#!/usr/bin/env python3
"""
FCM 푸시 알림 테스트 스크립트
"""

import json
import time
import jwt
import requests

# Firebase 서비스 계정 정보
SERVICE_ACCOUNT_FILE = 'non-git/firebase-service-account.json'

def get_access_token():
    """서비스 계정으로 OAuth 2.0 Access Token 발급"""
    with open(SERVICE_ACCOUNT_FILE) as f:
        service_account = json.load(f)
    
    # JWT 생성
    now = int(time.time())
    payload = {
        'iss': service_account['client_email'],
        'sub': service_account['client_email'],
        'aud': 'https://oauth2.googleapis.com/token',
        'iat': now,
        'exp': now + 3600,
        'scope': 'https://www.googleapis.com/auth/firebase.messaging'
    }
    
    # RS256으로 서명
    token = jwt.encode(
        payload,
        service_account['private_key'],
        algorithm='RS256'
    )
    
    # Access Token 요청
    response = requests.post(
        'https://oauth2.googleapis.com/token',
        data={
            'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion': token
        }
    )
    
    if response.status_code == 200:
        return response.json()['access_token']
    else:
        print(f"❌ 토큰 발급 실패: {response.text}")
        return None

def send_fcm_push(token, title, body):
    """FCM HTTP v1 API로 푸시 발송"""
    access_token = get_access_token()
    if not access_token:
        return False
    
    project_id = 'autogolfcrm-messaging'
    url = f'https://fcm.googleapis.com/v1/projects/{project_id}/messages:send'
    
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    
    message = {
        'message': {
            'token': token,
            'notification': {
                'title': title,
                'body': body
            },
            'data': {
                'type': 'test',
                'timestamp': str(int(time.time()))
            },
            'android': {
                'notification': {
                    'sound': 'hole_in',
                    'channel_id': 'chat_messages'
                }
            },
            'apns': {
                'payload': {
                    'aps': {
                        'sound': 'hole_in.mp3'
                    }
                }
            }
        }
    }
    
    response = requests.post(url, headers=headers, json=message)
    
    if response.status_code == 200:
        print(f"✅ 푸시 발송 성공!")
        print(f"   응답: {response.json()}")
        return True
    else:
        print(f"❌ 푸시 발송 실패: {response.status_code}")
        print(f"   응답: {response.text}")
        return False

if __name__ == '__main__':
    # MyXPlanner 회원 앱 (iOS) 토큰으로 테스트
    FCM_TOKEN = 'drX_B1LPwUzEs29gtgqq-J:APA91bHNEN-cY1rX480WbtwQFQu6o42VZcnw7wAMsKzjlHuixz0vu6xJ4WpYY_-NoqgXWnvO21CH3AM0SfUKu_5CFCvS_F-Bv_xbdMn-aUZXRLekL3jlvy0'
    
    print("🔔 FCM 푸시 알림 테스트")
    print(f"📱 대상: MyXPlanner 회원 앱 (iOS)")
    print(f"📱 토큰: {FCM_TOKEN[:30]}...")
    print()
    
    send_fcm_push(
        token=FCM_TOKEN,
        title='🏌️ 새 메시지',
        body='관리자로부터 메시지가 도착했습니다!'
    )

