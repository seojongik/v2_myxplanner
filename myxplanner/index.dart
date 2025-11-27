// ========== MyGolfPlanner App - CRM 연동용 Export ==========
// 버전: 2.0.0
// 설명: CRM에서 골프 예약 관리 시스템에 접근하기 위한 Export 파일

// 독립 프로젝트 파일들을 CRM에서 사용할 수 있도록 re-export
export 'lib/login_page.dart';
export 'lib/main_page.dart';
export 'lib/login_by_admin.dart';
export 'lib/login_branch_select.dart';
export 'lib/services/api_service.dart';

/// CRM에서 MyGolfPlanner App 사용 예시:
/// 
/// ```dart
/// import 'package:your_app/pages/mygolfplanner_app/index.dart';
/// 
/// // 플로팅 버튼으로 접근
/// FloatingActionButton(
///   onPressed: () => Navigator.push(
///     context,
///     MaterialPageRoute(builder: (context) => LoginByAdminPage()),
///   ),
///   child: Icon(Icons.add),
/// )
/// ```

// 모듈 정보
const String appVersion = '2.0.0';
const String appName = 'MyGolfPlanner';
const String appDescription = 'CRM 연동용 골프 예약 관리 시스템';

// 앱 정보를 반환하는 함수
Map<String, String> getAppInfo() {
  return {
    'name': appName,
    'version': appVersion,
    'description': appDescription,
    'author': 'FAMD Team',
    'created': '2025-01-22',
    'updated': '2025-01-22',
  };
} 