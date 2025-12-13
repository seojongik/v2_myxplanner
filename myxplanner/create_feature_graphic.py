#!/usr/bin/env python3
"""
MyGolfPlanner Feature Graphic Generator
실제 스크린샷을 사용한 Google Play Store용 그래픽 이미지 생성 (1024x500)
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

# 이미지 크기
WIDTH = 1024
HEIGHT = 500

# 색상
BG_COLOR = (248, 249, 250)
PRIMARY_COLOR = (0, 112, 74)
TEXT_COLOR = (26, 26, 26)

def add_phone_frame(base_img, screenshot_path, x, y, phone_width=160, rotation=0):
    """실제 스크린샷을 폰 프레임에 넣기"""
    # 스크린샷 로드
    screenshot = Image.open(screenshot_path)
    
    # 폰 비율 계산 (iPhone 비율 약 19.5:9)
    phone_height = int(phone_width * 2.1)
    
    # 스크린 영역 (프레임 두께 고려)
    frame_thickness = 8
    screen_width = phone_width - frame_thickness * 2
    screen_height = phone_height - frame_thickness * 2 - 30  # 상단 노치 공간
    
    # 스크린샷 리사이즈
    screenshot = screenshot.resize((screen_width, screen_height), Image.Resampling.LANCZOS)
    
    # 폰 프레임 이미지 생성
    phone_img = Image.new('RGBA', (phone_width + 20, phone_height + 20), (0, 0, 0, 0))
    phone_draw = ImageDraw.Draw(phone_img)
    
    # 그림자
    shadow_offset = 10
    phone_draw.rounded_rectangle(
        [shadow_offset, shadow_offset, phone_width + shadow_offset, phone_height + shadow_offset],
        radius=24, fill=(0, 0, 0, 60)
    )
    
    # 폰 외곽 (검정)
    phone_draw.rounded_rectangle(
        [0, 0, phone_width, phone_height],
        radius=24, fill=(30, 30, 30, 255)
    )
    
    # 스크린 배경 (흰색)
    phone_draw.rounded_rectangle(
        [frame_thickness, frame_thickness + 25, phone_width - frame_thickness, phone_height - frame_thickness],
        radius=16, fill=(255, 255, 255, 255)
    )
    
    # 노치
    notch_width = 50
    phone_draw.rounded_rectangle(
        [phone_width//2 - notch_width//2, 6, phone_width//2 + notch_width//2, 22],
        radius=8, fill=(30, 30, 30, 255)
    )
    
    # 스크린샷 붙이기
    phone_img.paste(screenshot, (frame_thickness, frame_thickness + 25))
    
    # 회전
    if rotation != 0:
        phone_img = phone_img.rotate(rotation, expand=True, resample=Image.Resampling.BICUBIC)
    
    # 베이스 이미지에 합성
    base_img.paste(phone_img, (x, y), phone_img)
    
    return base_img

def create_feature_graphic():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    screenshots_dir = os.path.join(script_dir, "screenshots")
    
    # 기본 이미지 생성 (RGBA)
    img = Image.new('RGBA', (WIDTH, HEIGHT), BG_COLOR + (255,))
    draw = ImageDraw.Draw(img)
    
    # 폰트 설정
    try:
        font_bold = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", 42)
        font_regular = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", 22)
    except:
        try:
            font_bold = ImageFont.truetype("/Library/Fonts/AppleGothic.ttf", 42)
            font_regular = ImageFont.truetype("/Library/Fonts/AppleGothic.ttf", 22)
        except:
            font_bold = ImageFont.load_default()
            font_regular = ImageFont.load_default()
    
    # ===== 왼쪽 섹션: 로고와 텍스트 =====
    
    # 앱 로고 로드
    logo_path = os.path.join(script_dir, "assets/images/applogo.png")
    if os.path.exists(logo_path):
        logo = Image.open(logo_path)
        logo = logo.resize((90, 90), Image.Resampling.LANCZOS)
        # 로고 배경 (둥근 사각형)
        logo_bg = Image.new('RGBA', (100, 100), (255, 255, 255, 255))
        logo_bg_draw = ImageDraw.Draw(logo_bg)
        logo_bg_draw.rounded_rectangle([0, 0, 100, 100], radius=20, fill=(255, 255, 255, 255))
        # 로고 합성
        logo_x, logo_y = 60, 150
        img.paste(logo_bg, (logo_x, logo_y), logo_bg)
        img.paste(logo, (logo_x + 5, logo_y + 5), logo if logo.mode == 'RGBA' else None)
    
    # 앱 이름
    draw.text((60, 270), "MyGolfPlanner", fill=TEXT_COLOR, font=font_bold)
    
    # 슬로건
    draw.text((60, 330), "스마트 골프 예약", fill=PRIMARY_COLOR, font=font_regular)
    draw.text((60, 360), "타석·레슨·회원권 한번에", fill=PRIMARY_COLOR, font=font_regular)
    
    # ===== 오른쪽 섹션: 실제 스크린샷 =====
    
    # 스크린샷 파일들
    screenshots = [
        os.path.join(screenshots_dir, "screenshot_2.png"),  # 예약내역
        os.path.join(screenshots_dir, "screenshot_4.png"),  # 다른 화면
        os.path.join(screenshots_dir, "screenshot_5.png"),  # 또 다른 화면
    ]
    
    # 파일 존재 확인
    available_screenshots = [s for s in screenshots if os.path.exists(s)]
    
    if len(available_screenshots) < 3:
        # 부족하면 다른 스크린샷으로 채우기
        all_screenshots = [os.path.join(screenshots_dir, f"screenshot_{i}.png") for i in range(1, 11)]
        available_screenshots = [s for s in all_screenshots if os.path.exists(s)][:3]
    
    # 폰 3개 배치
    phone_configs = [
        {"x": 480, "y": 60, "rotation": -8},   # 왼쪽
        {"x": 620, "y": 40, "rotation": 0},    # 중앙
        {"x": 760, "y": 60, "rotation": 8},    # 오른쪽
    ]
    
    for i, config in enumerate(phone_configs):
        if i < len(available_screenshots):
            img = add_phone_frame(
                img, 
                available_screenshots[i],
                config["x"], 
                config["y"],
                phone_width=160,
                rotation=config["rotation"]
            )
    
    # RGB로 변환 (PNG 저장용)
    img_rgb = Image.new('RGB', img.size, BG_COLOR)
    img_rgb.paste(img, mask=img.split()[3] if img.mode == 'RGBA' else None)
    
    # 저장
    output_path = os.path.join(script_dir, "assets/images/feature_graphic.png")
    img_rgb.save(output_path, "PNG", quality=95)
    print(f"✅ Feature graphic 생성 완료: {output_path}")
    
    return output_path

if __name__ == "__main__":
    create_feature_graphic()


