import 'package:flutter/material.dart';

class PolicyAccountPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const PolicyAccountPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _PolicyAccountPageState createState() => _PolicyAccountPageState();
}

class _PolicyAccountPageState extends State<PolicyAccountPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('약관 및 정책'),
        backgroundColor: Color(0xFF9C27B0),
        foregroundColor: Colors.white,
      ),
      body: PolicyAccountContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

// 임베드 가능한 약관 및 정책 콘텐츠 위젯
class PolicyAccountContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const PolicyAccountContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _PolicyAccountContentState createState() => _PolicyAccountContentState();
}

class _PolicyAccountContentState extends State<PolicyAccountContent> {
  final List<Map<String, dynamic>> _policyItems = [
    {
      'title': '개인정보 취급방침',
      'icon': Icons.privacy_tip,
      'color': Color(0xFF9C27B0),
      'type': 'privacy',
    },
    {
      'title': '서비스 이용약관',
      'icon': Icons.description,
      'color': Color(0xFF3F51B5),
      'type': 'terms',
    },
    {
      'title': '위치기반 서비스 이용약관',
      'icon': Icons.location_on,
      'color': Color(0xFF00BCD4),
      'type': 'location',
    },
    {
      'title': '마케팅 정보 수신 동의',
      'icon': Icons.campaign,
      'color': Color(0xFFFF9800),
      'type': 'marketing',
    },
  ];

  void _showPolicyDetail(BuildContext context, Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PolicyDetailPage(
          title: item['title'],
          type: item['type'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF8F9FA),
      child: Column(
        children: [
          // 상단 안내 영역
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Icon(
                  Icons.article,
                  color: Color(0xFF9C27B0),
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '서비스 이용에 필요한 약관과 정책을 확인하세요',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          // 정책 목록
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _policyItems.length,
              itemBuilder: (context, index) {
                final item = _policyItems[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _buildPolicyCard(context, item),
                );
              },
            ),
          ),

          // 하단 안내 문구
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Color(0xFF757575),
                  size: 20,
                ),
                SizedBox(height: 8),
                Text(
                  '약관 및 정책은 법적 요구사항에 따라\n수시로 업데이트될 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF757575),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(BuildContext context, Map<String, dynamic> item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPolicyDetail(context, item),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                // 아이콘
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item['icon'],
                    color: item['color'],
                    size: 24,
                  ),
                ),

                SizedBox(width: 16),

                // 제목
                Expanded(
                  child: Text(
                    item['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),

                // 화살표 아이콘
                Icon(
                  Icons.chevron_right,
                  color: Color(0xFFBDBDBD),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 정책 상세 페이지
class PolicyDetailPage extends StatelessWidget {
  final String title;
  final String type;

  const PolicyDetailPage({
    Key? key,
    required this.title,
    required this.type,
  }) : super(key: key);

  String _getPolicyContent(String type) {
    switch (type) {
      case 'privacy':
        return _getPrivacyPolicy();
      case 'terms':
        return _getTermsOfService();
      case 'location':
        return _getLocationPolicy();
      case 'marketing':
        return _getMarketingPolicy();
      default:
        return '내용이 없습니다.';
    }
  }

  String _getPrivacyPolicy() {
    return '''
개인정보 취급방침

마이골프플래너(이하 "회사")는 정보통신망 이용촉진 및 정보보호 등에 관한 법률, 개인정보보호법 등 관련 법령상의 개인정보보호 규정을 준수하며, 관련 법령에 의거한 개인정보취급방침을 정하여 이용자 권익 보호에 최선을 다하고 있습니다.

1. 수집하는 개인정보의 항목
회사는 회원가입, 서비스 제공을 위해 아래와 같은 개인정보를 수집하고 있습니다.

[필수항목]
- 이름
- 휴대전화번호
- 비밀번호

[선택항목]
- 생년월일
- 성별
- 주소

2. 개인정보의 수집 및 이용목적
회사는 수집한 개인정보를 다음의 목적을 위해 활용합니다.

가. 회원관리
- 회원제 서비스 이용에 따른 본인확인
- 개인식별, 불량회원의 부정 이용 방지와 비인가 사용 방지
- 가입 의사 확인, 연령확인, 불만처리 등 민원처리
- 회원가입 시 본인인증을 위한 SMS 인증번호 발송

나. 서비스 제공
- 골프 레슨 및 타석 예약 서비스
- 예약 내역 관리 및 알림 (앱 푸시알림)
- 결제 및 환불 처리

3. 개인정보의 보유 및 이용기간
회사는 개인정보 수집 및 이용목적이 달성된 후에는 해당 정보를 지체없이 파기합니다. 단, 관계법령의 규정에 의하여 보존할 필요가 있는 경우 회사는 아래와 같이 관계법령에서 정한 일정한 기간 동안 회원정보를 보관합니다.

- 계약 또는 청약철회 등에 관한 기록: 5년
- 대금결제 및 재화 등의 공급에 관한 기록: 5년
- 소비자의 불만 또는 분쟁처리에 관한 기록: 3년

4. 개인정보의 파기절차 및 방법
회사는 원칙적으로 개인정보 수집 및 이용목적이 달성된 후에는 해당 정보를 지체없이 파기합니다.

가. 파기절차
- 회원님이 회원가입 등을 위해 입력하신 정보는 목적이 달성된 후 별도의 DB로 옮겨져 내부 방침 및 기타 관련 법령에 의한 정보보호 사유에 따라 일정 기간 저장된 후 파기됩니다.

나. 파기방법
- 전자적 파일형태로 저장된 개인정보는 기록을 재생할 수 없는 기술적 방법을 사용하여 삭제합니다.
- 종이에 출력된 개인정보는 분쇄기로 분쇄하거나 소각을 통하여 파기합니다.

5. 개인정보 제공 및 공유
회사는 원칙적으로 이용자의 개인정보를 외부에 제공하지 않습니다. 다만, 아래의 경우에는 예외로 합니다.

- 이용자들이 사전에 동의한 경우
- 법령의 규정에 의거하거나, 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우

6. 이용자 및 법정대리인의 권리와 그 행사방법
이용자 및 법정 대리인은 언제든지 등록되어 있는 자신 혹은 당해 만 14세 미만 아동의 개인정보를 조회하거나 수정할 수 있으며 가입해지를 요청할 수도 있습니다.

7. 개인정보 자동 수집 장치의 설치·운영 및 거부에 관한 사항
회사는 회원에게 개별적인 맞춤서비스를 제공하기 위해 이용정보를 저장하고 수시로 불러오는 '쿠키(cookie)'를 사용합니다. 쿠키는 웹사이트를 운영하는데 이용되는 서버(http)가 이용자의 브라우저에게 보내는 소량의 정보이며 이용자의 PC 컴퓨터 내의 하드디스크에 저장되기도 합니다.

8. 개인정보의 기술적·관리적 보호 대책
회사는 이용자들의 개인정보를 처리함에 있어 개인정보가 분실, 도난, 유출, 변조 또는 훼손되지 않도록 안전성 확보를 위하여 다음과 같은 기술적·관리적 대책을 강구하고 있습니다.

가. 개인정보 암호화
이용자의 개인정보는 비밀번호에 의해 보호되며, 파일 및 전송 데이터를 암호화하거나 파일 잠금기능(Lock)을 사용하여 중요한 데이터는 별도의 보안기능을 통해 보호되고 있습니다.

나. 해킹 등에 대비한 대책
회사는 해킹이나 컴퓨터 바이러스 등에 의해 회원의 개인정보가 유출되거나 훼손되는 것을 막기 위해 최선을 다하고 있습니다.

다. 개인정보 취급 직원의 최소화 및 교육
회사의 개인정보관련 취급 직원은 담당자에 한정시키고 있고 이를 위한 별도의 비밀번호를 부여하여 정기적으로 갱신하고 있으며, 담당자에 대한 수시 교육을 통하여 개인정보취급방침의 준수를 항상 강조하고 있습니다.

9. 개인정보 보호책임자
회사는 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보 처리와 관련한 정보주체의 불만처리 및 피해구제 등을 위하여 아래와 같이 개인정보 보호책임자를 지정하고 있습니다.

[개인정보 보호책임자]
- 성명: 조스테파노
- 직책: 대표
- 연락처: 02-6953-7398
- 이메일: support@mygolfplanner.com

10. 고지의 의무
현 개인정보취급방침의 내용 추가, 삭제 및 수정이 있을 시에는 개정 최소 7일전부터 홈페이지의 '공지사항'을 통해 고지할 것입니다.

시행일자: 2025년 11월 15일
''';
  }

  String _getTermsOfService() {
    return '''
서비스 이용약관

제1조 (목적)
본 약관은 마이골프플래너(이하 "회사")가 제공하는 골프 예약 서비스(이하 "서비스")의 이용과 관련하여 회사와 회원의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정함을 목적으로 합니다.

제2조 (용어의 정의)
본 약관에서 사용하는 용어의 정의는 다음과 같습니다.
1. "서비스"란 회사가 제공하는 골프 레슨 및 타석 예약 서비스를 의미합니다.
2. "회원"이란 본 약관에 동의하고 회사와 서비스 이용계약을 체결한 자를 말합니다.
3. "아이디(ID)"란 회원의 식별과 서비스 이용을 위하여 회원이 설정하고 회사가 승인하는 전화번호를 말합니다.

제3조 (약관의 효력 및 변경)
1. 본 약관은 서비스를 이용하고자 하는 모든 회원에 대하여 그 효력을 발생합니다.
2. 회사는 필요한 경우 관련 법령을 위배하지 않는 범위에서 본 약관을 변경할 수 있습니다.
3. 회사가 약관을 개정할 경우에는 적용일자 및 개정사유를 명시하여 현행약관과 함께 서비스 초기화면에 그 적용일자 7일 이전부터 적용일자 전일까지 공지합니다.

제4조 (서비스의 제공 및 변경)
1. 회사는 다음과 같은 서비스를 제공합니다.
   가. 골프 레슨 예약 서비스
   나. 타석 예약 서비스
   다. 예약 내역 조회 및 관리
   라. 기타 회사가 추가 개발하거나 다른 회사와의 제휴계약 등을 통해 회원에게 제공하는 일체의 서비스

2. 회사는 서비스의 내용을 변경할 경우에는 변경사유 및 변경내용을 지체 없이 공지합니다.

제5조 (서비스의 중단)
1. 회사는 컴퓨터 등 정보통신설비의 보수점검, 교체 및 고장, 통신의 두절 등의 사유가 발생한 경우에는 서비스의 제공을 일시적으로 중단할 수 있습니다.
2. 회사는 제1항의 사유로 서비스의 제공이 일시적으로 중단됨으로 인하여 이용자 또는 제3자가 입은 손해에 대하여 배상합니다. 단, 회사에 고의 또는 과실이 없음을 입증하는 경우에는 그러하지 아니합니다.

제6조 (회원가입)
1. 이용자는 회사가 정한 가입 양식에 따라 회원정보를 기입한 후 이 약관에 동의한다는 의사표시를 함으로서 회원가입을 신청합니다.
2. 회원가입 시 휴대전화번호 인증을 통해 본인 확인을 진행합니다.
3. 회사는 제1항과 같이 회원으로 가입할 것을 신청한 이용자 중 다음 각 호에 해당하지 않는 한 회원으로 등록합니다.
   가. 등록 내용에 허위, 기재누락, 오기가 있는 경우
   나. 기타 회원으로 등록하는 것이 회사의 기술상 현저히 지장이 있다고 판단되는 경우

제7조 (회원 탈퇴 및 자격 상실 등)
1. 회원은 회사에 언제든지 탈퇴를 요청할 수 있으며 회사는 즉시 회원탈퇴를 처리합니다.
2. 회원이 다음 각 호의 사유에 해당하는 경우, 회사는 회원자격을 제한 및 정지시킬 수 있습니다.
   가. 가입 신청 시에 허위 내용을 등록한 경우
   나. 다른 사람의 서비스 이용을 방해하거나 그 정보를 도용하는 등 전자상거래 질서를 위협하는 경우
   다. 서비스를 이용하여 법령 또는 이 약관이 금지하거나 공서양속에 반하는 행위를 하는 경우

제8조 (회원에 대한 통지)
1. 회사가 회원에 대한 통지를 하는 경우, 회원이 회사와 미리 약정하여 지정한 앱 푸시알림으로 할 수 있습니다.
2. 회사는 불특정다수 회원에 대한 통지의 경우 1주일이상 서비스 공지사항에 게시함으로서 개별 통지에 갈음할 수 있습니다.
3. 회원은 앱 내 '계정관리 > 메시지 수신동의' 메뉴에서 알림 수신 설정을 관리할 수 있습니다.

제9조 (예약 및 결제)
1. 회원은 서비스를 통해 골프 레슨 및 타석을 예약할 수 있습니다.
2. 예약의 성립은 회원의 예약 신청과 회사의 승인으로 이루어집니다.
3. 결제는 회사가 제공하는 결제 수단을 통해 이루어집니다.

제10조 (취소 및 환불)
1. 회원은 예약 시간 전까지 예약을 취소할 수 있습니다.
2. 취소 시점에 따라 환불 금액이 달라질 수 있으며, 자세한 환불 정책은 별도로 공지합니다.

제11조 (면책조항)
1. 회사는 천재지변 또는 이에 준하는 불가항력으로 인하여 서비스를 제공할 수 없는 경우에는 서비스 제공에 관한 책임이 면제됩니다.
2. 회사는 회원의 귀책사유로 인한 서비스 이용의 장애에 대하여 책임을 지지 않습니다.

제12조 (분쟁해결)
1. 회사는 회원이 제기하는 정당한 의견이나 불만을 반영하고 그 피해를 보상처리하기 위하여 피해보상처리기구를 설치, 운영합니다.
2. 회사와 회원 간에 발생한 분쟁은 전자문서 및 전자거래 기본법 제32조 및 동 시행령 제15조에 의하여 설치된 전자문서, 전자거래 분쟁조정위원회의 조정에 따를 수 있습니다.

부칙
본 약관은 2025년 11월 15일부터 시행합니다.
''';
  }

  String _getLocationPolicy() {
    return '''
위치기반 서비스 이용약관

제1조 (목적)
본 약관은 마이골프플래너(이하 "회사")가 제공하는 위치기반서비스와 관련하여 회사와 개인위치정보주체와의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정함을 목적으로 합니다.

제2조 (약관 외 준칙)
이 약관에 명시되지 않은 사항은 위치정보의 보호 및 이용 등에 관한 법률, 정보통신망 이용촉진 및 정보보호 등에 관한 법률, 전기통신기본법, 전기통신사업법 등 관계법령과 회사의 이용약관 및 개인정보취급방침, 회사가 별도로 정한 지침 등에 의합니다.

제3조 (서비스 내용 및 요금)
1. 회사는 직접 위치정보를 수집하거나 위치정보사업자로부터 위치정보를 전달받아 아래와 같은 위치기반서비스를 제공합니다.
   가. 골프장 위치 정보 제공
   나. 주변 골프장 검색 서비스
   다. 길찾기 및 내비게이션 연동

2. 제1항 위치기반서비스의 이용요금은 무료입니다.

제4조 (개인위치정보주체의 권리)
1. 개인위치정보주체는 개인위치정보 수집 범위 및 이용약관의 내용 중 일부 또는 개인위치정보의 이용ㆍ제공 목적, 제공받는 자의 범위 및 위치기반서비스의 일부에 대하여 동의를 유보할 수 있습니다.

2. 개인위치정보주체는 개인위치정보의 수집ㆍ이용ㆍ제공에 대한 동의의 전부 또는 일부를 철회할 수 있습니다.

3. 개인위치정보주체는 언제든지 개인위치정보의 수집ㆍ이용ㆍ제공의 일시적인 중지를 요구할 수 있습니다.

4. 개인위치정보주체는 회사에 대하여 아래 자료의 열람 또는 고지를 요구할 수 있고, 당해 자료에 오류가 있는 경우에는 그 정정을 요구할 수 있습니다.
   가. 개인위치정보주체에 대한 위치정보 수집ㆍ이용ㆍ제공사실 확인자료
   나. 개인위치정보주체의 개인위치정보가 위치정보의 보호 및 이용 등에 관한 법률 또는 다른 법률 규정에 의하여 제3자에게 제공된 이유 및 내용

제5조 (법정대리인의 권리)
1. 회사가 14세 미만의 아동으로부터 개인위치정보를 수집ㆍ이용 또는 제공하고자 하는 경우에는 14세 미만의 아동과 그 법정대리인의 동의를 받아야 합니다.

2. 법정대리인은 14세 미만의 아동의 개인위치정보를 수집ㆍ이용ㆍ제공에 동의하는 경우 동의유보권, 동의철회권 및 일시중지권, 열람ㆍ고지요구권을 행사할 수 있습니다.

제6조 (위치정보 이용ㆍ제공사실 확인자료 보유근거 및 보유기간)
회사는 위치정보의 보호 및 이용 등에 관한 법률 제16조 제2항에 근거하여 개인위치정보주체에 대한 위치정보 수집ㆍ이용ㆍ제공사실 확인자료를 위치정보시스템에 자동으로 기록하며, 6개월 이상 보관합니다.

제7조 (서비스의 변경 및 중지)
1. 회사는 위치정보사업자의 정책변경 등과 같이 회사의 제반 사정 또는 법률상의 장애 등으로 서비스를 유지할 수 없는 경우, 서비스의 전부 또는 일부를 제한, 변경하거나 중지할 수 있습니다.

2. 제1항에 의한 서비스 중단의 경우에는 회사는 사전에 인터넷 등에 공지하거나 개인위치정보주체에게 통지합니다.

제8조 (개인위치정보 제3자 제공 시 즉시 통보)
1. 회사는 개인위치정보주체의 동의 없이 당해 개인위치정보주체의 개인위치정보를 제3자에게 제공하지 아니하며, 제3자 제공 서비스를 제공하는 경우에는 제공 받는 자 및 제공목적을 사전에 개인위치정보주체에게 고지하고 동의를 받습니다.

2. 회사는 개인위치정보를 개인위치정보주체가 지정하는 제3자에게 제공하는 경우에는 매회 개인위치정보주체에게 제공받는 자, 제공일시 및 제공목적을 즉시 통보합니다.

제9조 (8세 이하의 아동 등의 보호의무자의 권리)
1. 회사는 아래의 경우에 해당하는 자(이하 "8세 이하의 아동 등")의 보호의무자가 8세 이하의 아동 등의 생명 또는 신체보호를 위하여 개인위치정보의 이용 또는 제공에 동의하는 경우에는 본인의 동의가 있는 것으로 봅니다.
   가. 8세 이하의 아동
   나. 피성년후견인
   다. 장애인복지법 제2조제2항제2호의 규정에 의한 정신적 장애를 가진 자로서 장애인고용촉진 및 직업재활법 제2조제2호의 규정에 의한 중증장애인에 해당하는 자(장애인복지법 제32조의 규정에 의하여 장애인등록을 한 자에 한한다)

2. 8세 이하의 아동 등의 생명 또는 신체의 보호를 위하여 개인위치정보의 이용 또는 제공에 동의를 하고자 하는 보호의무자는 서면동의서에 보호의무자임을 증명하는 서면을 첨부하여 회사에 제출하여야 합니다.

제10조 (손해배상)
회사가 위치정보의 보호 및 이용 등에 관한 법률 제15조 내지 제26조의 규정을 위반한 행위로 회원에게 손해가 발생한 경우 회원은 회사에 대하여 손해배상 청구를 할 수 있습니다. 이 경우 회사는 고의, 과실이 없음을 입증하지 못하는 경우 책임을 면할 수 없습니다.

제11조 (분쟁의 조정)
1. 회사는 위치정보와 관련된 분쟁에 대하여 당사자간 협의가 이루어지지 아니하거나 협의를 할 수 없는 경우에는 위치정보의 보호 및 이용 등에 관한 법률 제28조의 규정에 의한 방송통신위원회에 재정을 신청할 수 있습니다.

2. 회사 또는 고객은 위치정보와 관련된 분쟁에 대해 당사자간 협의가 이루어지지 아니하거나 협의를 할 수 없는 경우에는 개인정보보호법 제43조의 규정에 의한 개인정보분쟁조정위원회에 조정을 신청할 수 있습니다.

제12조 (위치정보관리책임자의 지정)
회사는 위치정보를 적절히 관리·보호하고, 개인위치정보주체의 불만을 원활히 처리할 수 있도록 실질적인 책임을 질 수 있는 지위에 있는 자를 위치정보관리책임자로 지정해 운영하고 있습니다.

[위치정보관리책임자]
- 성명: 조스테파노
- 직책: 대표
- 연락처: 02-6953-7398
- 이메일: support@mygolfplanner.com

부칙
본 약관은 2025년 11월 15일부터 시행합니다.
''';
  }

  String _getMarketingPolicy() {
    return '''
마케팅 정보 수신 동의

마이골프플래너(이하 "회사")는 회원님께 다양한 혜택과 유용한 정보를 제공하기 위해 마케팅 정보 수신 동의를 받고 있습니다.

1. 수신 정보의 종류
회사는 다음과 같은 마케팅 정보를 발송합니다:

가. 신규 서비스 및 기능 안내
- 새로운 골프 프로그램 출시 정보
- 서비스 기능 업데이트 소식
- 신규 제휴 혜택 안내

나. 프로모션 및 이벤트 정보
- 시즌별 할인 프로모션
- 회원 대상 특별 이벤트
- 경품 추첨 및 이벤트 당첨 안내

다. 맞춤형 추천 정보
- 이용 패턴 기반 프로그램 추천
- 선호도에 맞는 강사 추천
- 개인화된 예약 혜택 정보

라. 설문조사 및 의견 수렴
- 서비스 만족도 조사
- 신규 서비스 개발 의견 요청
- 회원 피드백 수집

2. 발송 방법
마케팅 정보는 앱 내 푸시알림을 통해서만 발송됩니다.
※ 회사는 카카오톡 알림톡 및 SMS 문자메시지를 통한 마케팅 정보를 발송하지 않습니다.

3. 수신 동의 관리
가. 회원은 언제든지 마케팅 정보 수신 동의를 철회하거나 변경할 수 있습니다.

나. 수신 동의 관리 방법:
- 앱 내 '계정관리 > 메시지 수신동의' 메뉴에서 활동별 수신 설정 변경
- 고객센터를 통한 변경 요청

다. 수신 동의 철회 후에는 마케팅 정보가 발송되지 않습니다.
(단, 서비스 이용에 필수적인 거래 관련 정보는 계속 발송될 수 있습니다)

4. 개인정보의 이용
마케팅 정보 발송을 위해 다음의 개인정보가 이용됩니다:
- 이름 (개인화된 메시지 발송)
- 서비스 이용 내역 (맞춤형 정보 제공)
- 앱 푸시 토큰 (푸시알림 발송)

5. 제3자 제공 및 위탁
가. 회사는 마케팅 정보 발송을 위해 개인정보를 제3자에게 제공하지 않습니다.

나. 회사는 앱 푸시알림 발송을 위해 다음과 같이 업무를 위탁할 수 있습니다:

[위탁업체 및 위탁업무]
- 푸시알림 발송: Firebase Cloud Messaging (Google)

다. 회사는 위탁계약 체결 시 개인정보보호법에 따라 위탁업무 수행목적 외 개인정보 처리금지, 기술적·관리적 보호조치, 재위탁 제한, 수탁자에 대한 관리·감독, 손해배상 등 책임에 관한 사항을 계약서 등 문서에 명시하고, 수탁자가 개인정보를 안전하게 처리하는지를 감독합니다.

6. 필수 알림과 마케팅 알림의 구분
가. 필수 알림 (수신 동의와 무관하게 발송)
- 예약 확인 및 취소 알림
- 결제 및 환불 관련 알림
- 서비스 이용에 필수적인 거래 정보
- 중요 공지사항 및 약관 변경 안내

나. 마케팅 알림 (수신 동의 시에만 발송)
- 프로모션 및 이벤트 안내
- 신규 서비스 소개
- 맞춤형 추천 정보
- 설문조사 요청

7. 메시지 수신동의 활동별 설정
회원은 '계정관리 > 메시지 수신동의' 메뉴에서 다음 활동별로 알림 수신 여부를 개별 설정할 수 있습니다:
- 회원권 등록/취소
- 크레딧 적립/차감
- 예약 접수/취소
- 그룹활동 초대
- 1:1메시지
- 할인권 등록/사용
- 공지사항
- 일반안내

8. 동의를 거부할 권리 및 불이익
회원은 마케팅 정보 수신 동의를 거부할 권리가 있으며, 동의를 거부하더라도 서비스 이용에는 제한이 없습니다.

다만, 마케팅 정보를 수신하지 않으실 경우 각종 혜택, 이벤트 안내를 받아보실 수 없습니다.

9. 유효기간
마케팅 정보 수신 동의의 유효기간은 동의일로부터 회원 탈퇴 시 또는 동의 철회 시까지입니다.

10. 문의처
마케팅 정보 수신과 관련하여 문의사항이 있으시면 아래로 연락주시기 바랍니다.

[고객센터]
- 전화: 02-6953-7398
- 이메일: support@mygolfplanner.com
- 운영시간: 평일 09:00 ~ 18:00 (주말 및 공휴일 휴무)

동의일: 2025년 11월 15일
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.all(24),
          child: SelectableText(
            _getPolicyContent(type),
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ),
    );
  }
}
