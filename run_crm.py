#!/usr/bin/env python3
"""CRM 실행 스크립트"""
import subprocess
import sys
import os

PROJECT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'crm')

print("🚀 CRM 실행 중...")
subprocess.run(['flutter', 'run', '-d', 'chrome', '--web-port=8080'], cwd=PROJECT_DIR)



