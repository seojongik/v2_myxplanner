#!/bin/bash
# APK 설치 스크립트

export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

APK_PATH="/Users/seojongik/MyGolfPlanner/build/app/outputs/flutter-apk/app-release.apk"

echo "📱 연결된 기기 확인 중..."
DEVICES=$(adb devices | grep -v "List" | grep "device" | wc -l | tr -d ' ')

if [ "$DEVICES" -eq 0 ]; then
    echo "❌ 연결된 Android 기기나 에뮬레이터가 없습니다."
    echo ""
    echo "다음 중 하나를 선택하세요:"
    echo "1. Android 기기를 USB로 연결하고 USB 디버깅 활성화"
    echo "2. Android Studio에서 에뮬레이터 실행"
    echo ""
    echo "연결 후 다시 실행하세요: ./install_apk.sh"
    exit 1
fi

echo "✅ 기기 연결됨"
echo ""
echo "📦 APK 설치 중..."
adb install -r "$APK_PATH"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 설치 완료!"
    echo "📱 앱을 실행하려면: adb shell am start -n mygolfplanner.app/.MainActivity"
else
    echo ""
    echo "❌ 설치 실패"
fi
