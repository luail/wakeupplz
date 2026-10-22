# 구현 구조 · 포커스 디자인 확정

SwiftUI 기반 네이티브 iOS 앱을 사용한다. Tailwind CSS는 웹 DOM/CSS를 대상으로 하므로 네이티브 앱에 도입하지 않는다. 그 대신 DesignSystem에 팔레트, typography, spacing, corner radius와 반복적으로 쓰는 소수의 컴포넌트를 정의한다.

처음에는 하나의 앱 타깃과 명확한 폴더 경계로 시작한다. 각 화면마다 별도의 Swift Package를 만들지 않는다. 공유할 실제 필요가 생기거나 테스트/확장 프로세스 분리가 요구될 때만 패키지로 추출한다.

```text
WakeUpPlz/
  App/                    앱 진입점, 화면 연결, 의존성 조립
  DesignSystem/           Theme, Typography, 공통 버튼·설정 행
  Features/
    Home/                 HomeView와 홈 전용 UI/상태
    Verification/         채팅 UI, 입력 검증, 인증 상태
    Settings/             알람/문자/연락처/문구 설정
    DaysOff/              달력, 날짜 범위 편집
    Sounds/               목록, 미리 듣기, 파일 가져오기
  Domain/                 순수 Swift 모델 및 일정·인증·회차 규칙
  Services/
    Persistence/          온디바이스 저장
    Alarms/               AlarmKit 예약/취소/재알림
    Messaging/            로컬 알림 및 단축어에 넘길 발송 요청
    Holidays/             한국 공휴일 데이터와 유효기간
  AppIntents/             단축어 공개 동작, 실행 직전 인증 확인
  Resources/              사운드, 색상/아이콘 자산, 공휴일 자료
Tests/                    시간 경계, 휴무, 중복 요청, 인증 후 취소
scripts/                  검증된 빌드·설치·만료일 확인 도구
```

화면에서만 쓰는 작은 컴포넌트는 같은 파일의 private View 또는 해당 Feature 폴더에 둔다. 실제로 여러 화면에 반복되는 패턴만 공통화한다. 모든 화면에 관성적으로 ViewModel/Repository/Protocol을 만들지 않는다.

SwiftUI의 State/Binding/Observation으로 UI 상태를 다룬다. 일정 계산과 저장/OS 연동은 화면에서 분리한다. 메시지 처리는 전송 요청과 실제 수신 성공을 구분하며 자동화 연결을 검증하기 전 연결 완료라고 표시하지 않는다.

디자인 미리보기는 화면 결정을 위한 별도 산출물이다. HTML 코드를 네이티브 앱에 감싸서 배포하지 않는다.
