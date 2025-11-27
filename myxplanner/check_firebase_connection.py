#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Firebase 연결 상태 확인 및 진단 스크립트
"""

import json
import os
from pathlib import Path

def check_firebase_config():
    """Firebase 설정 파일 확인"""
    print("=" * 60)
    print("🔥 Firebase 설정 파일 확인")
    print("=" * 60)
    
    # google-services.json 확인
    google_services_path = Path("android/app/google-services.json")
    if google_services_path.exists():
        print(f"✅ google-services.json 파일 존재: {google_services_path}")
        try:
            with open(google_services_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                print(f"   프로젝트 ID: {data.get('project_info', {}).get('project_id')}")
                print(f"   프로젝트 번호: {data.get('project_info', {}).get('project_number')}")
                
                # Android 앱 확인
                if 'client' in data and len(data['client']) > 0:
                    client = data['client'][0]
                    app_id = client.get('client_info', {}).get('mobilesdk_app_id', 'N/A')
                    package_name = client.get('client_info', {}).get('android_client_info', {}).get('package_name', 'N/A')
                    print(f"   앱 ID: {app_id}")
                    print(f"   패키지명: {package_name}")
        except Exception as e:
            print(f"❌ google-services.json 파싱 실패: {e}")
    else:
        print(f"❌ google-services.json 파일 없음: {google_services_path}")
    
    print()
    
    # firebase_options.dart 확인
    firebase_options_path = Path("lib/firebase_options.dart")
    if firebase_options_path.exists():
        print(f"✅ firebase_options.dart 파일 존재: {firebase_options_path}")
        try:
            with open(firebase_options_path, 'r', encoding='utf-8') as f:
                content = f.read()
                # Android 설정 추출
                if 'static const FirebaseOptions android' in content:
                    print("   Android Firebase 옵션 설정됨")
                    # 프로젝트 ID 추출
                    if 'projectId:' in content:
                        lines = content.split('\n')
                        for i, line in enumerate(lines):
                            if 'static const FirebaseOptions android' in line:
                                # 다음 몇 줄 확인
                                for j in range(i+1, min(i+10, len(lines))):
                                    if 'projectId:' in lines[j]:
                                        project_id = lines[j].split("'")[1] if "'" in lines[j] else "N/A"
                                        print(f"   프로젝트 ID: {project_id}")
                                        break
                                break
        except Exception as e:
            print(f"❌ firebase_options.dart 읽기 실패: {e}")
    else:
        print(f"❌ firebase_options.dart 파일 없음: {firebase_options_path}")
    
    print()

def check_firebase_dependencies():
    """Firebase 의존성 확인"""
    print("=" * 60)
    print("📦 Firebase 의존성 확인")
    print("=" * 60)
    
    pubspec_path = Path("pubspec.yaml")
    if pubspec_path.exists():
        try:
            with open(pubspec_path, 'r', encoding='utf-8') as f:
                content = f.read()
                firebase_packages = []
                if 'firebase_core:' in content:
                    for line in content.split('\n'):
                        if 'firebase' in line.lower() and ':' in line:
                            firebase_packages.append(line.strip())
                
                if firebase_packages:
                    print("✅ Firebase 패키지:")
                    for pkg in firebase_packages:
                        print(f"   {pkg}")
                else:
                    print("❌ Firebase 패키지 없음")
        except Exception as e:
            print(f"❌ pubspec.yaml 읽기 실패: {e}")
    else:
        print("❌ pubspec.yaml 파일 없음")
    
    print()

def check_android_build_config():
    """Android 빌드 설정 확인"""
    print("=" * 60)
    print("🔧 Android 빌드 설정 확인")
    print("=" * 60)
    
    build_gradle_path = Path("android/app/build.gradle.kts")
    if build_gradle_path.exists():
        try:
            with open(build_gradle_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
                # google-services 플러그인 확인
                if 'com.google.gms.google-services' in content:
                    print("✅ google-services 플러그인 설정됨")
                else:
                    print("❌ google-services 플러그인 없음")
                
                # Firebase 의존성 확인
                firebase_deps = []
                if 'firebase' in content.lower():
                    lines = content.split('\n')
                    in_dependencies = False
                    for line in lines:
                        if 'dependencies {' in line:
                            in_dependencies = True
                        if in_dependencies and 'firebase' in line.lower():
                            firebase_deps.append(line.strip())
                        if in_dependencies and '}' in line and firebase_deps:
                            break
                
                if firebase_deps:
                    print("✅ Firebase 의존성:")
                    for dep in firebase_deps:
                        print(f"   {dep}")
                else:
                    print("⚠️ Firebase 의존성 없음 (Flutter 패키지로 관리됨)")
        except Exception as e:
            print(f"❌ build.gradle.kts 읽기 실패: {e}")
    else:
        print("❌ build.gradle.kts 파일 없음")
    
    print()

def check_firebase_plugin_registration():
    """Firebase 플러그인 등록 확인"""
    print("=" * 60)
    print("🔌 Firebase 플러그인 등록 확인")
    print("=" * 60)
    
    registrant_path = Path("android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
    if registrant_path.exists():
        try:
            with open(registrant_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
                if 'FlutterFirebaseCorePlugin' in content:
                    print("✅ FlutterFirebaseCorePlugin 등록됨")
                else:
                    print("❌ FlutterFirebaseCorePlugin 등록 안됨")
                
                if 'FlutterFirebaseFirestorePlugin' in content:
                    print("✅ FlutterFirebaseFirestorePlugin 등록됨")
                else:
                    print("❌ FlutterFirebaseFirestorePlugin 등록 안됨")
        except Exception as e:
            print(f"❌ GeneratedPluginRegistrant.java 읽기 실패: {e}")
    else:
        print("❌ GeneratedPluginRegistrant.java 파일 없음")
    
    print()

def main():
    print("\n" + "=" * 60)
    print("🔥 Firebase 연결 상태 진단")
    print("=" * 60)
    print()
    
    check_firebase_config()
    check_firebase_dependencies()
    check_android_build_config()
    check_firebase_plugin_registration()
    
    print("=" * 60)
    print("✅ 진단 완료")
    print("=" * 60)
    print()
    print("💡 다음 단계:")
    print("   1. 위의 확인 사항 중 ❌ 표시된 항목이 있으면 수정")
    print("   2. Firebase 버전이 최신인지 확인: flutter pub outdated")
    print("   3. FlutterFire CLI로 재설정: flutterfire configure --platforms=android")
    print()

if __name__ == "__main__":
    main()

