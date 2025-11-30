#!/usr/bin/env python3
"""MyXPlanner 실행 스크립트"""
import subprocess
import sys
import os

PROJECT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'myxplanner')

# iOS 시뮬레이터 디바이스 ID 가져오기
result = subprocess.run(['flutter', 'devices'], capture_output=True, text=True, cwd=PROJECT_DIR)
device_id = None
for line in result.stdout.split('\n'):
    if 'simulator' in line.lower() and 'ios' in line.lower():
        parts = line.split('•')
        if len(parts) >= 2:
            device_id = parts[1].strip()
            break

if not device_id:
    print("❌ iOS 시뮬레이터를 찾을 수 없습니다.")
    sys.exit(1)

print(f"🚀 MyXPlanner 실행 중... (디바이스: {device_id})")
subprocess.run(['flutter', 'run', '-d', device_id], cwd=PROJECT_DIR)

