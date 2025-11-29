#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
각 프로젝트에 설정 파일 복사 스크립트
루트의 .env.local.json을 각 프로젝트의 config.json으로 복사
"""

import os
import json
import shutil

# 프로젝트 목록
PROJECTS = ['crm', 'crm_lite_pro', 'myxplanner']

def setup_configs():
    """각 프로젝트에 설정 파일 복사"""
    root_dir = os.path.dirname(os.path.abspath(__file__))
    source_file = os.path.join(root_dir, '.env.local.json')
    
    if not os.path.exists(source_file):
        print(f"❌ 소스 파일 없음: {source_file}")
        print("   루트에 .env.local.json 파일을 먼저 생성하세요.")
        return False
    
    print(f"📋 소스 파일: {source_file}")
    print(f"📁 대상 프로젝트: {', '.join(PROJECTS)}\n")
    
    success_count = 0
    for project in PROJECTS:
        project_dir = os.path.join(root_dir, project)
        target_file = os.path.join(project_dir, 'config.json')
        
        if not os.path.exists(project_dir):
            print(f"⚠️  프로젝트 디렉토리 없음: {project_dir}")
            continue
        
        try:
            shutil.copy2(source_file, target_file)
            print(f"✅ {project}/config.json 생성 완료")
            success_count += 1
        except Exception as e:
            print(f"❌ {project}/config.json 생성 실패: {e}")
    
    print(f"\n📊 결과: {success_count}/{len(PROJECTS)}개 프로젝트 설정 완료")
    return success_count == len(PROJECTS)

if __name__ == '__main__':
    print("=" * 60)
    print("프로젝트 설정 파일 복사")
    print("=" * 60)
    print()
    
    if setup_configs():
        print("\n✅ 모든 프로젝트 설정 완료!")
    else:
        print("\n⚠️  일부 프로젝트 설정 실패")

