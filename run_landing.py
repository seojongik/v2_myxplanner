#!/usr/bin/env python3
"""Landing 실행 스크립트"""
import subprocess
import sys
import os

PROJECT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'landing')

print("🚀 Landing 실행 중...")
subprocess.run(['npm', 'run', 'dev'], cwd=PROJECT_DIR)

