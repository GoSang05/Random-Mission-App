# Random Mission App - Project Context

## Unified Home Story Feed (2026-08-30)

* Opening a story from the home screen uses one continuous feed containing today's photo stories from every joined private room.
* Opening a story from inside a room or its history remains scoped to that room.
* A horizontal swipe moves through the feed. A short tap in the left or right third of the photo moves backward or forward.
* A recognized long press never changes the story, including when the finger is released.
* The story viewer follows the playful warm-cream, bold black outline, purple/lime visual system used by the rest of the app.

## 1. Project Overview

이 프로젝트는 친구 또는 혼자서 수행할 수 있는 랜덤 미션을 제공하고, 사용자가 사진/영상 등으로 인증하며 추억을 기록하는 모바일 소셜 앱이다.

Android와 iOS를 모두 지원하는 것을 목표로 하며, 하나의 코드베이스를 유지하기 위해 Flutter를 사용한다.

초기 개발 및 테스트는 Android를 우선으로 진행하고, 이후 동일한 Flutter 프로젝트를 기반으로 iOS를 지원한다.

---

# 2. Core Product Idea

앱의 핵심은 단순히 "랜덤 챌린지를 주는 앱"이 아니다.

핵심 제품 가치는 다음과 같다.

> 친구들과 추억이 생길 핑계를 만들어주는 앱

또는

> 평범한 하루에 작은 사건을 만들어주는 소셜 앱

사용자가 앱을 열고 랜덤 미션을 받은 뒤, 실제 생활에서 행동하고 인증하는 것이 기본 경험이다.

기본 사용자 루프:

```text
앱 실행
↓
랜덤 미션 확인
↓
미션 시작
↓
현실에서 미션 수행
↓
사진 / 영상 등으로 인증
↓
친구들과 공유
↓
반응 / 기록 확인
↓
다음 미션
```

---

# 3. Example Missions

예시 미션:

* 처음 가보는 가게 방문하기
* 친구가 골라준 옷 입기
* 학교에서 특정 색 물건 5개 찾기
* 5,000원으로 가장 웃긴 물건 사기
* 같은 장소에서 각자 다른 콘셉트로 사진 찍기
* 편의점에서 서로에게 3,000원 이하 간식 골라주기
* 오늘 처음 들어본 노래 하나 저장하기
* 평소 가지 않던 길로 집에 가기
* 처음 보는 음료 사서 마셔보기
* 친구가 정해준 메뉴 먹기
* 서로를 가장 잘 표현하는 물건 찾아오기
* 영화 포스터처럼 사진 찍기
* 오늘 가장 웃긴 간판 찾기
* 앨범 커버 같은 사진 찍기
* 친구에게 뜬금없는 칭찬하기

---

# 4. Mission Categories

미션은 완전한 무작위가 아니라 카테고리와 사용자 상황을 고려해서 추천하는 구조를 고려한다.

## 4.1 Daily Exploration

평소 하지 않던 행동을 유도하는 미션.

예:

* 처음 가보는 카페 방문
* 새로운 길로 귀가
* 먹어보지 않은 음식 주문
* 처음 보는 제품 구매

목표:

일상의 반복에서 벗어나 작은 새로운 경험을 만들기.

---

## 4.2 Friend Missions

친구와 함께해야 하는 미션.

예:

* 친구가 골라준 옷 입기
* 서로 프로필 사진 찍어주기
* 상대방에게 간식 골라주기
* 서로 가장 안 어울리는 음료 골라주기

이 카테고리는 앱의 소셜성과 바이럴에 중요한 역할을 한다.

---

## 4.3 Photo Challenges

결과 사진 자체가 재미있는 미션.

예:

* 빨간색 물건 5개 찍기
* 영화 포스터처럼 사진 찍기
* 같은 장소에서 다른 콘셉트로 촬영하기
* 재미있는 간판 찾기

사진 인증 피드와 잘 어울리는 미션이다.

---

## 4.4 Budget Challenges

정해진 금액 내에서 수행하는 미션.

예:

* 5,000원으로 가장 웃긴 물건 구매
* 3,000원으로 최고의 간식 조합 만들기
* 10,000원 이하 데이트 코스 만들기

예산 제한 자체가 게임 룰이 된다.

---

## 4.5 Social Missions

사람 사이의 행동을 유도하는 미션.

예:

* 친구에게 먼저 칭찬하기
* 오랜만에 친구에게 연락하기
* 부모님에게 오늘 사진 보내기

주의:

모르는 사람에게 무리하게 접근하게 만드는 미션 등 안전 문제가 있는 미션은 피한다.

---

# 5. Context-Based Random Mission System

단순 랜덤 대신 사용자 상황을 입력하거나 추론하여 적합한 미션을 제공하는 기능을 고려한다.

예시 조건:

```text
현재 인원
- 혼자
- 친구 1명
- 친구 여러 명
- 연인

현재 장소
- 집
- 학교
- 밖
- 여행 중

사용 가능한 시간
- 10분
- 30분
- 1시간 이상

사용 가능한 예산
- 무료
- 5,000원 이하
- 10,000원 이하
- 제한 없음
```

예시 결과:

```text
MISSION

편의점에서 서로에게
"가장 안 어울리는 음료"를 골라주세요.

예상 시간: 20분
예산: 5,000원 이하
추천 인원: 2명 이상

[미션 시작]
```

---

# 6. Authentication / Mission Verification

사용자는 미션 수행 후 인증할 수 있다.

초기 인증 방식:

* 사진 인증
* 짧은 텍스트
* 미션 완료 상태

추후 확장:

* 짧은 영상 인증
* 여러 명 공동 인증
* 위치 기반 인증
* 친구 태그

초기 버전에서는 사진 인증을 가장 중요하게 본다.

영상은 서버 비용과 개발 복잡성이 크므로 처음부터 핵심 기능으로 만들지 않는다.

---

# 7. Social Features

장기적으로 다음 소셜 기능을 고려한다.

## Friends

* 친구 추가
* 친구 프로필 보기
* 친구 미션 기록 보기

## Feed

친구들이 수행한 미션 인증을 볼 수 있다.

예:

```text
민수

MISSION
처음 보는 음료 마셔보기

[인증 사진]

❤️ 12    😂 5
```

## Reactions

초기에는 복잡한 댓글 기능보다 간단한 반응 중심도 고려한다.

예:

* 좋아요
* 웃겨요
* 대단해요

## Friend Mission

사용자가 친구에게 직접 미션을 보낼 수 있는 기능.

예:

```text
민수가 지훈에게 미션을 보냈습니다.

오늘 하루 빨간색 음식 하나 먹기

[수락]
[거절]
```

이 기능은 장기적으로 앱의 핵심 소셜 기능이 될 가능성이 있다.

---

# 8. Mission History

사용자의 인증은 단순 게시물이 아니라 개인의 추억 기록으로 쌓인다.

프로필 예시:

```text
@username

Completed Missions: 137
Current Streak: 12 days

이번 달

새로운 장소: 7
친구 미션: 11
사진 미션: 9
```

아래에는 과거 인증 사진들이 시간순 또는 캘린더 형태로 쌓인다.

제품적으로 다음 개념을 중요하게 본다.

> Life Quest Album

사용자가 앱을 오래 사용할수록 개인의 작은 경험과 추억들이 기록된다.

---

# 9. Daily Global Mission

장기적으로 모든 사용자에게 동일한 미션을 제공하는 기능도 고려한다.

예:

```text
TODAY'S GLOBAL MISSION

오늘 가장 마음에 드는 하늘을 찍어주세요.
```

사용자는 다른 사람이 같은 미션을 어떻게 수행했는지 볼 수 있다.

또는:

```text
5,000원으로 가장 이상한 물건 사기
```

같은 미션을 전체 사용자에게 제공하고 투표 기능을 붙이는 것도 가능하다.

---

# 10. Target Users

초기 핵심 타겟:

* 고등학생 후반
* 대학생
* 20대 초반
* 친구들과 자주 만나는 사용자
* 데이트 중 무엇을 할지 고민하는 사용자

주요 사용 상황:

* 공강
* 학교 끝난 뒤
* 친구들과 만났는데 할 일이 없을 때
* 데이트
* 여행
* 주말
* MT / 모임

마케팅 문구 후보:

> 친구들이랑 뭐 하지? 할 때 켜는 앱

---

# 11. Product Differentiation

이 앱은 TikTok / Instagram처럼 사용자를 계속 화면 안에 붙잡는 것이 핵심이 아니다.

오히려 반대 방향을 목표로 한다.

> 사람을 스마트폰 화면 밖으로 움직이게 만드는 소셜 앱

핵심 조합:

```text
Randomness
+
Real World Action
+
Friends
+
Verification
+
Memory
```

---

# 12. MVP Scope

초기 MVP에서는 기능을 과도하게 만들지 않는다.

가장 먼저 검증해야 할 것은:

> 랜덤 미션을 친구와 수행하고 인증하는 경험 자체가 재미있는가?

초기 MVP 기능 우선순위:

1. 앱 기본 구조
2. 홈 화면
3. 랜덤 미션 표시
4. 미션 시작
5. 미션 완료
6. 사진 인증
7. 사용자 로그인 / 회원가입
8. 내 미션 기록
9. 친구 추가
10. 친구 인증 피드
11. 간단한 반응

초기 MVP에서 우선순위가 낮은 기능:

* DM
* 실시간 채팅
* 긴 영상
* 공개 글로벌 피드
* 복잡한 랭킹
* 복잡한 XP 시스템
* AI 미션 생성
* 유료 구독

이 기능들은 핵심 경험이 검증된 뒤 추가한다.

---

# 13. Development Platform

앱은 Flutter로 개발한다.

목표 플랫폼:

```text
Android
iOS
```

개발 순서:

```text
Android 우선 개발
↓
Android 실기기 / Emulator 테스트
↓
MVP 완성
↓
Mac + Xcode 환경에서 iOS 테스트
↓
App Store 지원
```

Flutter를 선택한 이유:

* Android / iOS 코드베이스 공유
* UI 개발 속도가 빠름
* Hot Reload 지원
* 초기 스타트업 / 개인 프로젝트에 적합
* Dart 한 언어로 모바일 앱 대부분 구현 가능

---

# 14. Main Development Environment

메인 코드 에디터:

```text
VS Code
```

이유:

* 개발자가 VS Code에 익숙함
* Codex를 자주 사용함
* Flutter / Dart 개발에 충분함
* 가볍고 빠름

VS Code에서 주로 수행:

```text
Flutter 코드 작성
Dart 코드 작성
Codex 사용
Git
Supabase 연동
디버깅
Hot Reload
Flutter 실행
```

---

# 15. Android Studio Role

Android Studio는 메인 코딩 환경으로 사용하지 않아도 된다.

주요 용도:

```text
Android SDK 관리
Android Emulator 관리
AVD 생성
Android 관련 세부 설정
Android 빌드 문제 해결
```

평소 개발 과정:

```text
VS Code
↓
Flutter 개발
↓
Android Emulator 실행
↓
Hot Reload
```

Android Studio는 필요할 때만 실행한다.

---

# 16. Current Development Environment

운영체제:

```text
Windows 11
```

현재 Flutter:

```text
Flutter 3.44.9
Channel stable
```

현재 Android SDK:

```text
Android SDK 36.0.0
```

Flutter Doctor에서 확인된 상태:

```text
Flutter: 정상
Windows: 정상
Chrome: 정상
Connected Devices: 정상

Android Toolchain:
일부 Android License 동의 필요

Visual Studio:
설치되어 있지 않음
```

Visual Studio는 Windows Desktop Flutter 앱을 만들 때 필요하므로 현재 모바일 앱 개발에는 필수적이지 않다.

Android License 문제 해결 명령어:

```bash
flutter doctor --android-licenses
```

이후 다시:

```bash
flutter doctor
```

를 실행한다.

---

# 17. Current Project

현재 Flutter 프로젝트 경로:

```text
C:\Users\leejo\random_mission
```

Flutter 프로젝트는 이미 생성되어 있다.

실행 명령:

```bash
cd C:\Users\leejo\random_mission
flutter run
```

현재 `flutter run` 실행 시 확인된 디바이스:

```text
Windows
Chrome
Edge
```

Android Emulator는 아직 실행된 상태가 아니었기 때문에 목록에 표시되지 않았다.

---

# 18. Android Emulator

Android Emulator는 컴퓨터 안에서 실행되는 가상 Android 스마트폰이다.

Flutter 앱을 개발하면서 실제 스마트폰 없이 빠르게 UI와 기능을 테스트하는 데 사용한다.

관련 명령:

설치된 Emulator 확인:

```bash
flutter emulators
```

Emulator 실행:

```bash
flutter emulators --launch <EMULATOR_ID>
```

현재 연결된 장치 확인:

```bash
flutter devices
```

앱 실행:

```bash
flutter run
```

Android Emulator를 한 번 만들어 놓으면 매번 Android Studio를 켤 필요는 없다.

VS Code 또는 Flutter CLI에서 직접 실행 가능하다.

---

# 19. Important Development Concepts

## VS Code

코드를 작성하는 메인 개발 환경.

## Flutter

Android와 iOS 앱을 하나의 코드베이스로 만들기 위한 프레임워크.

## Dart

Flutter에서 사용하는 프로그래밍 언어.

## Flutter SDK

Flutter 앱을 개발하고 빌드하기 위한 도구 모음.

## Android SDK

Android 앱을 빌드하고 실행하는 데 필요한 Android 개발 도구 모음.

## Emulator

PC 안에서 실행되는 가상 Android 스마트폰.

## AVD

Android Virtual Device.

어떤 가상 스마트폰을 사용할지 정의한 설정.

예:

```text
Pixel
Android 16
API 36
```

## API Level

Android 버전을 개발자가 사용하는 숫자로 표현한 것.

예:

```text
Android 14 = API 34
Android 15 = API 35
Android 16 = API 36
```

## APK

Android 기기에 설치할 수 있는 앱 파일.

## AAB

Google Play Store 배포에 주로 사용하는 Android App Bundle.

---

# 20. Backend Recommendation

초기 백엔드는 Supabase 사용을 우선 고려한다.

예상 구조:

```text
Flutter App
     │
     ▼
Supabase
├── Auth
├── PostgreSQL
├── Realtime
├── Storage
└── Edge Functions
```

Push Notification:

```text
Firebase Cloud Messaging
```

---

# 21. Why Supabase

앱 데이터는 관계형 구조가 많을 가능성이 높다.

예:

```text
User
↓
Friends
↓
Mission
↓
Mission Participants
↓
Verification Post
↓
Reaction
↓
Comment
```

따라서 PostgreSQL 기반 Supabase가 적합하다고 판단한다.

예상 데이터 테이블:

```text
users
profiles
missions
mission_assignments
mission_participants
posts
post_media
friendships
reactions
comments
notifications
```

추후 필요하면:

```text
chat_rooms
chat_members
messages
```

추가.

---

# 22. Media Storage Strategy

## Initial Stage

초기 사용자 규모에서는 Supabase Storage 사용.

```text
Flutter
↓
Supabase Storage
```

주요 저장 데이터:

* 인증 사진
* 프로필 사진
* 필요할 경우 짧은 영상

## Growth Stage

사진 사용량과 트래픽이 커지면 Cloudflare R2 검토.

예상 구조:

```text
Supabase
├── DB
├── Auth
└── Realtime

Cloudflare R2
└── Photos
```

DB에는 실제 이미지가 아니라 파일 위치만 저장한다.

예:

```text
post_id
user_id
mission_id
media_type
media_key
created_at
```

---

# 23. Video Strategy

초기에는 영상 중심 서비스로 만들지 않는다.

이유:

* 저장 용량
* 네트워크 트래픽
* 인코딩
* 스트리밍
* 썸네일
* 앱 성능
* 서버 비용

등의 복잡도가 사진보다 훨씬 높다.

초기 전략:

```text
사진 인증 중심
```

영상이 필요하다면:

```text
10~15초 정도로 제한
720p 수준 압축
```

사용량이 커지면 Cloudflare Stream 같은 영상 전용 서비스를 검토한다.

---

# 24. Server Cost Philosophy

소셜 앱에서 가장 위험한 비용은 DB보다 미디어 트래픽일 가능성이 높다.

특히:

```text
Video >> Photo >> Text
```

순으로 비용이 커진다.

따라서 초기 MVP에서는 사진 중심으로 시작한다.

유저가 충분히 생기고 영상의 제품 가치가 검증된 이후 영상 시스템을 확장한다.

---

# 25. Proposed Flutter Project Structure

초기에는 지나치게 복잡한 Clean Architecture를 사용하지 않는다.

초보자가 이해하기 쉬운 구조를 우선한다.

예상 구조:

```text
lib/
│
├── main.dart
│
├── screens/
│   ├── home_screen.dart
│   ├── mission_screen.dart
│   ├── verification_screen.dart
│   ├── feed_screen.dart
│   ├── profile_screen.dart
│   └── auth/
│       ├── login_screen.dart
│       └── signup_screen.dart
│
├── widgets/
│   ├── mission_card.dart
│   ├── mission_button.dart
│   └── verification_card.dart
│
├── models/
│   ├── mission.dart
│   ├── user_profile.dart
│   └── verification.dart
│
├── services/
│   ├── supabase_service.dart
│   ├── auth_service.dart
│   ├── mission_service.dart
│   └── storage_service.dart
│
└── utils/
    ├── constants.dart
    └── theme.dart
```

프로젝트 규모가 커지면 추후 feature 기반 구조 등으로 리팩터링한다.

---

# 26. Suggested Development Order

Codex가 개발을 도울 때 다음 순서를 기본으로 한다.

## Phase 1 - Environment

```text
Flutter Doctor 정상화
Android Emulator 생성
VS Code에서 Emulator 실행
기본 Flutter 앱 실행
```

## Phase 2 - UI Prototype

서버 없이 먼저 화면을 만든다.

```text
Home
↓
Mission Card
↓
Mission Start
↓
Mission Complete
```

미션 데이터는 임시 하드코딩.

예:

```dart
final missions = [
  '처음 가보는 가게 방문하기',
  '파란색 물건 5개 찾기',
  '5,000원으로 가장 웃긴 물건 사기',
];
```

## Phase 3 - Mission Logic

랜덤 미션 기능 구현.

```text
Mission List
↓
Random Selection
↓
Mission Start
↓
Mission Completion
```

## Phase 4 - Authentication

Supabase 연결.

```text
Signup
Login
Logout
User Profile
```

## Phase 5 - Mission Verification

```text
Camera / Gallery
↓
Photo Selection
↓
Supabase Storage Upload
↓
Verification Post
```

## Phase 6 - Mission History

사용자의 완료한 미션과 사진 기록.

## Phase 7 - Friends

```text
Friend Search
Friend Request
Friend Acceptance
Friend List
```

## Phase 8 - Social Feed

친구 인증 피드.

## Phase 9 - Reactions

간단한 좋아요 / 웃겨요 등의 반응.

## Phase 10 - Push Notifications

Firebase Cloud Messaging 사용.

---

# 27. Development Principles

Codex는 아래 원칙을 따라 개발을 도와야 한다.

## Principle 1

사용자는 모바일 앱 개발 초보자다.

따라서 코드를 생성할 때 결과만 제공하지 말고 중요한 개념을 간단히 설명한다.

## Principle 2

필요 이상으로 복잡한 Architecture를 도입하지 않는다.

초기 MVP에서는 개발 속도와 이해하기 쉬운 구조를 우선한다.

## Principle 3

가능하면 Flutter 표준 패턴과 널리 사용하는 패키지를 사용한다.

## Principle 4

Android 전용 코드 사용은 최소화한다.

향후 iOS 지원을 고려하여 가능한 경우 Flutter 공통 API를 사용한다.

## Principle 5

큰 기능을 한 번에 구현하기보다 작게 나눈다.

예:

```text
Home UI
→ Random Mission
→ Mission State
→ Authentication
→ Storage
→ Feed
```

## Principle 6

새 패키지를 설치하기 전에 왜 필요한지 설명한다.

## Principle 7

코드 수정 시 기존 프로젝트 구조를 먼저 확인한다.

기존 파일을 무시하고 프로젝트 전체를 불필요하게 다시 작성하지 않는다.

## Principle 8

에러가 발생하면 원인을 먼저 설명하고 가장 작은 수정으로 해결한다.

## Principle 9

보안 관련 값은 코드에 직접 넣지 않는다.

예:

```text
API Key
Service Role Key
Database Password
```

등을 GitHub에 노출하지 않는다.

## Principle 10

사용자의 최우선 목표는 빠르게 실제 동작하는 MVP를 만드는 것이다.

---

# 28. Codex Instructions

이 파일을 읽은 Codex는 앞으로 다음 내용을 프로젝트 기본 컨텍스트로 사용한다.

1. 이 프로젝트는 Flutter 기반 랜덤 미션 소셜 앱이다.
2. Android를 먼저 개발하지만 최종적으로 iOS도 지원한다.
3. VS Code가 메인 개발환경이다.
4. Android Studio는 SDK와 Emulator 관리 용도로 사용한다.
5. Backend는 Supabase를 우선 사용한다.
6. Push Notification은 Firebase Cloud Messaging을 고려한다.
7. 초기 MVP는 사진 인증 중심으로 만든다.
8. 영상 / 채팅 / 글로벌 피드는 후순위다.
9. 사용자는 앱 개발 초보자이므로 설명을 생략하지 않는다.
10. 과도한 Architecture와 불필요한 패키지 사용을 피한다.
11. 현재 프로젝트 상태와 기존 코드를 확인한 후 수정한다.
12. 하나의 기능을 작은 단계로 나누어 개발한다.

---

# 29. Current Immediate Goal

현재 가장 먼저 해야 할 것은 Android Emulator에서 기본 Flutter 앱을 실행하는 것이다.

현재 단계:

```text
Flutter project created
↓
Flutter run executed
↓
Windows / Chrome / Edge detected
↓
Android Emulator not running
```

다음 작업:

```text
1. Android licenses 확인
2. flutter emulators 실행
3. 필요한 경우 Android Studio에서 AVD 생성
4. Android Emulator 실행
5. flutter devices로 Android 확인
6. flutter run
7. Android Emulator에서 Flutter 기본 앱 실행 확인
```

이 과정이 완료된 후 실제 Random Mission 앱 UI 개발을 시작한다.

---

# 30. Product North Star

개발 과정에서 기능을 추가할지 고민될 경우 다음 질문을 기준으로 판단한다.

> 이 기능이 사용자가 친구와 새로운 경험을 만들고 그것을 추억으로 남기는 데 도움이 되는가?

그렇지 않다면 초기 MVP에서는 우선순위를 낮춘다.

---

# 31. Current Product Rules (2026-08-29)

아래 규칙은 기존 문서와 충돌할 경우 우선한다.

* 미션 인증 업로드는 사진만 허용한다. 영상 업로드 UI를 제공하지 않는다.
* 미션 원본은 `lib/data/default_missions.dart`에 하드코딩한다.
* 사용자는 앱에서 미션을 추가하거나 수정할 수 없다.
* 매일 한국 시간 자정에 미션 목록에서 정해진 개수를 무작위 선택한다.
* Global 방은 같은 날짜에 모든 사용자가 같은 미션을 본다.
* Private 방은 같은 방의 모든 구성원이 같은 미션을 보며 방마다 선택 결과가 다를 수 있다.
* 오늘 업로드한 사진만 기본 화면에 표시한다.
* Private 방은 History에서 지난 사진을 확인할 수 있다. Global 방에는 History를 제공하지 않는다.
* 채팅은 방 화면의 채팅 버튼으로 진입하며 날짜가 지나도 유지한다. 최신 메시지는 아래에 표시한다.
* Guest도 닉네임과 프로필 사진을 설정할 수 있으며 설정 화면에서만 Guest 여부를 표시한다.
* 방 생성 시 비밀 방과 입장 비밀번호를 선택할 수 있다.
* 카메라는 앱 내부 실시간 프리뷰와 촬영 UI를 사용한다. 앱 최초 실행과 촬영 재시도 시 권한을 요청한다.
* 카메라 프리뷰 프레임과 촬영 결과는 원본 종횡비에 맞춰 표시하며 정사각형 강제 확대나 왜곡을 하지 않는다.
* Snackbar는 새 메시지가 오면 이전 메시지를 즉시 교체하여 대기열이 누적되지 않게 한다.

---

# 32. Home Visual Direction (2026-08-29)

* 홈 화면은 따뜻한 off-white 배경, 두꺼운 검은 outline, purple + lime green을 핵심 스타일로 사용한다.
* 카드와 버튼은 둥글고 playful한 형태와 짧은 검은 offset shadow를 사용한다.
* star, heart, sparkle 같은 작은 doodle을 장식으로 사용한다.
* My Rooms는 가로 스크롤 카드, Friends Stories는 반응형 2열 카드로 표시한다.
* 홈 일러스트는 외부 임시 이미지 대신 Flutter `CustomPainter` 기반 벡터 드로잉을 사용한다.
* 홈 UI가 변경되어도 기존 방 참여/생성, 글로벌 방, 프로필, 방/스토리 진입 동작과 위젯 키는 유지한다.

---

# 33. Core Screen Visual Direction (2026-08-29)

* 개인 방, Global Mission Room, 사진 인증, 방 채팅도 홈과 같은 playful 디자인 시스템을 사용한다.
* 밝은 화면은 warm off-white 점 배경, 검은 outline, purple shadow와 star/cloud/sparkle doodle을 사용한다.
* 사진 인증 화면은 dark navy 점 배경과 lavender 컨트롤을 사용한다.
* 개인 방 미션은 outline 카드와 미션별 카메라 버튼으로 표시하고 오늘 사진은 반응형 2열로 표시한다.
* 로컬 채팅과 Supabase 채팅은 동일한 말풍선·헤더·메시지 입력창 스타일을 사용한다.
* 스타일 변경 시 채팅, 히스토리, 설정, 촬영, 스토리 진입과 기존 테스트 키를 유지한다.
* Global Mission Room에는 "모든 사용자에게 같은 미션" 안내 배너를 표시하지 않는다.
* 개인 방 히스토리·방 설정·홈 프로필 설정·닉네임 편집 팝업도 playful outlined 테마를 사용한다.
* 매거진 화면은 별도 요청이 없는 한 이 디자인 변경 범위에 포함하지 않는다.
