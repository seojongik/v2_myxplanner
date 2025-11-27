#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
from datetime import datetime
import json

# Firebase 서비스 계정 키 설정
service_account_key = {
    "type": "service_account",
    "project_id": "mgpfunctions",
    "private_key_id": "YOUR_PRIVATE_KEY_ID",
    "private_key": "YOUR_PRIVATE_KEY",
    "client_email": "YOUR_CLIENT_EMAIL",
    "client_id": "YOUR_CLIENT_ID",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "YOUR_CERT_URL"
}

def setup_firebase_data():
    """Firebase Firestore에 테스트 데이터 설정"""
    
    try:
        # Firebase Admin SDK 초기화
        cred = credentials.Certificate(service_account_key)
        firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        print("✅ Firebase 연결 성공")
        
        # 채팅방 데이터 생성
        chat_room_id = "test_901"
        chat_room_data = {
            "branchId": "test",
            "memberId": "901",
            "memberName": "서종익",
            "memberPhone": "010-6250-7373",
            "memberType": "웰빙클럽",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "lastMessage": "안녕하세요! 문의사항이 있으신가요?",
            "lastMessageTime": firestore.SERVER_TIMESTAMP,
            "adminUnreadCount": 0,
            "memberUnreadCount": 1,
            "isActive": True
        }
        
        # 채팅방 문서 생성 또는 업데이트
        doc_ref = db.collection('chatRooms').document(chat_room_id)
        doc_ref.set(chat_room_data)
        print(f"✅ 채팅방 생성/업데이트 완료: {chat_room_id}")
        
        # 샘플 메시지 추가
        messages = [
            {
                "chatRoomId": chat_room_id,
                "branchId": "test",
                "senderId": "admin",
                "senderType": "admin",
                "senderName": "관리자",
                "message": "안녕하세요! 문의사항이 있으신가요?",
                "timestamp": firestore.SERVER_TIMESTAMP,
                "isRead": False
            }
        ]
        
        for msg in messages:
            msg_ref = db.collection('messages').add(msg)
            print(f"✅ 메시지 추가 완료")
        
        # 데이터 확인
        doc = doc_ref.get()
        if doc.exists:
            print(f"\n📄 채팅방 데이터:")
            print(json.dumps(doc.to_dict(), indent=2, ensure_ascii=False, default=str))
        
        # 메시지 확인
        messages_query = db.collection('messages').where('chatRoomId', '==', chat_room_id).stream()
        print(f"\n💬 메시지 목록:")
        for msg in messages_query:
            print(json.dumps(msg.to_dict(), indent=2, ensure_ascii=False, default=str))
        
        print("\n✅ Firebase 설정 완료!")
        print("이제 Flutter 앱에서 채팅 기능을 테스트할 수 있습니다.")
        
    except Exception as e:
        print(f"❌ 에러 발생: {e}")
        print("\n서비스 계정 키를 설정해야 합니다.")
        print("Firebase Console에서 다음 단계를 따르세요:")
        print("1. Firebase Console > 프로젝트 설정 > 서비스 계정")
        print("2. '새 비공개 키 생성' 클릭")
        print("3. 다운로드한 JSON 파일의 내용을 이 스크립트에 복사")

if __name__ == "__main__":
    print("🔥 Firebase Firestore 설정 시작")
    print("프로젝트: mgpfunctions")
    print("채팅방 ID: test_901")
    print("-" * 50)
    
    # 서비스 계정 키가 설정되지 않은 경우 안내
    if service_account_key.get("private_key") == "YOUR_PRIVATE_KEY":
        print("⚠️ 서비스 계정 키를 먼저 설정해야 합니다.")
        print("\n다음 단계를 따르세요:")
        print("1. Firebase Console (https://console.firebase.google.com)")
        print("2. mgpfunctions 프로젝트 선택")
        print("3. 프로젝트 설정 > 서비스 계정")
        print("4. Python > '새 비공개 키 생성'")
        print("5. 다운로드한 JSON 파일의 내용을 이 스크립트에 복사")
    else:
        setup_firebase_data()