# 릴리즈 노트 관리

## 한국어 릴리즈 노트 필수

App Store Connect에서는 한국어 "이 버전에서 업그레이드된 사항" 필드가 필수입니다.

## 자동 설정

Fastlane이 자동으로 다음 릴리즈 노트를 설정합니다:

```
MyGolfPlanner 업데이트

새로운 기능 및 개선사항:
- 성능 최적화 및 안정성 개선
- 버그 수정 및 사용자 경험 향상
```

## 수정 방법

`Fastfile`의 `release` 또는 `submit` lane에서 `release_notes` 변수를 수정하세요:

```ruby
release_notes = "여기에 실제 업데이트 내용을 작성하세요"
```

## App Store Connect에서 직접 수정

빌드가 업로드된 후 App Store Connect에서도 직접 수정할 수 있습니다:

1. App Store Connect 접속
2. "내 앱" → "MyGolfPlanner" 선택
3. "버전" 또는 "TestFlight" 탭 선택
4. 해당 빌드 선택
5. "이 버전에서 업그레이드된 사항" 필드에 한국어로 입력
