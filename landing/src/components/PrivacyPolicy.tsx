import { X } from 'lucide-react';

interface PrivacyPolicyProps {
  isOpen: boolean;
  onClose: () => void;
}

export function PrivacyPolicy({ isOpen, onClose }: PrivacyPolicyProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4" onClick={onClose}>
      <div
        className="bg-white rounded-2xl max-w-4xl w-full max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="sticky top-0 bg-white border-b border-gray-200 p-6 flex items-center justify-between rounded-t-2xl">
          <h1 className="text-2xl font-bold text-gray-900">개인정보 처리방침</h1>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-6 h-6 text-gray-600" />
          </button>
        </div>

        <div className="px-6 py-8 max-w-4xl">
        <div className="prose prose-gray max-w-none">
          <section className="mb-8">
            <p className="text-gray-700 leading-relaxed mb-4">
              주식회사 이네이블테크(이하 "회사")는 정보주체의 자유와 권리 보호를 위해 「개인정보 보호법」 및 관계 법령이 정한 바를 준수하여, 적법하게 개인정보를 처리하고 안전하게 관리하고 있습니다.
            </p>
            <p className="text-gray-700 leading-relaxed">
              본 개인정보 처리방침은 회사가 제공하는 AutoGolfCRM 서비스(이하 "서비스")에 적용됩니다.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제1조 (개인정보의 처리 목적)</h2>
            <p className="text-gray-700 leading-relaxed mb-2">회사는 다음의 목적을 위하여 개인정보를 처리합니다. 처리하고 있는 개인정보는 다음의 목적 이외의 용도로는 이용되지 않으며, 이용 목적이 변경되는 경우에는 「개인정보 보호법」 제18조에 따라 별도의 동의를 받는 등 필요한 조치를 이행할 예정입니다.</p>
            <ul className="list-disc pl-6 space-y-2 text-gray-700">
              <li>회원 가입 및 관리: 회원 자격 유지·관리, 서비스 부정이용 방지, 각종 고지·통지</li>
              <li>서비스 제공: 골프연습장 예약 및 운영 관리 서비스 제공, 콘텐츠 제공, 본인인증</li>
              <li>마케팅 및 광고 활용: 신규 서비스 개발 및 맞춤 서비스 제공, 이벤트 및 광고성 정보 제공</li>
              <li>고객 문의 처리: 민원처리, 고객 상담 및 분쟁 조정</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제2조 (처리하는 개인정보의 항목)</h2>
            <p className="text-gray-700 leading-relaxed mb-2">회사는 다음의 개인정보 항목을 처리하고 있습니다.</p>

            <div className="mb-4">
              <h3 className="font-semibold text-gray-900 mb-2">1. 회원가입 시</h3>
              <ul className="list-disc pl-6 space-y-1 text-gray-700">
                <li>필수항목: 성명, 이메일 주소, 휴대전화번호, 비밀번호</li>
                <li>선택항목: 사업장명, 사업자등록번호, 주소</li>
              </ul>
            </div>

            <div className="mb-4">
              <h3 className="font-semibold text-gray-900 mb-2">2. 서비스 이용 시</h3>
              <ul className="list-disc pl-6 space-y-1 text-gray-700">
                <li>서비스 이용기록, 접속 로그, 쿠키, 접속 IP 정보, 결제기록</li>
              </ul>
            </div>

            <div className="mb-4">
              <h3 className="font-semibold text-gray-900 mb-2">3. 결제 시</h3>
              <ul className="list-disc pl-6 space-y-1 text-gray-700">
                <li>신용카드 정보, 계좌번호, 거래기록</li>
              </ul>
            </div>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제3조 (개인정보의 처리 및 보유기간)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>회사는 법령에 따른 개인정보 보유·이용기간 또는 정보주체로부터 개인정보를 수집 시에 동의받은 개인정보 보유·이용기간 내에서 개인정보를 처리·보유합니다.</li>
              <li>각각의 개인정보 처리 및 보유 기간은 다음과 같습니다:
                <ul className="list-disc pl-6 mt-2 space-y-1">
                  <li>회원 정보: 회원 탈퇴 시까지 (단, 관계 법령 위반에 따른 수사·조사 등이 진행 중인 경우에는 해당 수사·조사 종료 시까지)</li>
                  <li>결제 정보: 「전자상거래 등에서의 소비자보호에 관한 법률」에 따라 5년간 보관</li>
                  <li>접속 로그 기록: 「통신비밀보호법」에 따라 3개월간 보관</li>
                </ul>
              </li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제4조 (개인정보의 제3자 제공)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>회사는 정보주체의 개인정보를 제1조(개인정보의 처리 목적)에서 명시한 범위 내에서만 처리하며, 정보주체의 동의, 법률의 특별한 규정 등 「개인정보 보호법」 제17조 및 제18조에 해당하는 경우에만 개인정보를 제3자에게 제공합니다.</li>
              <li>회사는 다음과 같이 개인정보를 제3자에게 제공하고 있습니다:
                <ul className="list-disc pl-6 mt-2 space-y-1">
                  <li>결제 처리를 위한 결제대행업체(PG사)에 결제 정보 제공</li>
                  <li>SMS/카카오톡 발송을 위한 메시지 발송 대행업체에 연락처 정보 제공</li>
                </ul>
              </li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제5조 (개인정보 처리의 위탁)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>회사는 원활한 개인정보 업무처리를 위하여 다음과 같이 개인정보 처리업무를 위탁하고 있습니다:
                <ul className="list-disc pl-6 mt-2 space-y-1">
                  <li>클라우드 서비스 제공: AWS 또는 기타 클라우드 서비스 제공자</li>
                  <li>결제 처리: 결제대행업체(PG사)</li>
                  <li>메시지 발송: SMS/카카오톡 발송 대행업체</li>
                </ul>
              </li>
              <li>회사는 위탁계약 체결 시 「개인정보 보호법」 제26조에 따라 위탁업무 수행목적 외 개인정보 처리금지, 기술적·관리적 보호조치, 재위탁 제한, 수탁자에 대한 관리·감독, 손해배상 등 책임에 관한 사항을 계약서 등 문서에 명시하고, 수탁자가 개인정보를 안전하게 처리하는지를 감독하고 있습니다.</li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제6조 (정보주체의 권리·의무 및 행사방법)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>정보주체는 회사에 대해 언제든지 다음 각 호의 개인정보 보호 관련 권리를 행사할 수 있습니다:
                <ul className="list-disc pl-6 mt-2 space-y-1">
                  <li>개인정보 열람 요구</li>
                  <li>오류 등이 있을 경우 정정 요구</li>
                  <li>삭제 요구</li>
                  <li>처리정지 요구</li>
                </ul>
              </li>
              <li>제1항에 따른 권리 행사는 회사에 대해 서면, 전화, 전자우편 등을 통하여 하실 수 있으며, 회사는 이에 대해 지체 없이 조치하겠습니다.</li>
              <li>정보주체가 개인정보의 오류 등에 대한 정정 또는 삭제를 요구한 경우에는 회사는 정정 또는 삭제를 완료할 때까지 당해 개인정보를 이용하거나 제공하지 않습니다.</li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제7조 (개인정보의 파기)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>회사는 개인정보 보유기간의 경과, 처리목적 달성 등 개인정보가 불필요하게 되었을 때에는 지체 없이 해당 개인정보를 파기합니다.</li>
              <li>개인정보 파기의 절차 및 방법은 다음과 같습니다:
                <ul className="list-disc pl-6 mt-2 space-y-1">
                  <li>파기절차: 불필요하게 된 개인정보는 개인정보 보호책임자의 승인 절차를 거쳐 파기합니다.</li>
                  <li>파기방법: 전자적 파일 형태의 정보는 기록을 재생할 수 없는 기술적 방법을 사용하여 삭제하며, 종이에 출력된 개인정보는 분쇄기로 분쇄하거나 소각하여 파기합니다.</li>
                </ul>
              </li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제8조 (개인정보의 안전성 확보조치)</h2>
            <p className="text-gray-700 leading-relaxed mb-2">회사는 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다:</p>
            <ul className="list-disc pl-6 space-y-2 text-gray-700">
              <li>관리적 조치: 내부관리계획 수립·시행, 정기적 직원 교육</li>
              <li>기술적 조치: 개인정보처리시스템 등의 접근권한 관리, 접근통제시스템 설치, 개인정보의 암호화, 보안프로그램 설치</li>
              <li>물리적 조치: 전산실, 자료보관실 등의 접근통제</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제9조 (개인정보 보호책임자)</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              회사는 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보 처리와 관련한 정보주체의 불만처리 및 피해구제 등을 위하여 아래와 같이 개인정보 보호책임자를 지정하고 있습니다.
            </p>
            <div className="bg-gray-50 p-4 rounded-lg">
              <p className="text-gray-700"><strong>개인정보 보호책임자</strong></p>
              <ul className="list-none space-y-1 text-gray-700 mt-2">
                <li>성명: 조스테파노</li>
                <li>직책: 대표이사</li>
                <li>이메일: privacy@enabletech.co.kr</li>
                <li>전화번호: 문의는 이메일로 부탁드립니다</li>
              </ul>
            </div>
            <p className="text-gray-700 leading-relaxed mt-4">
              정보주체는 회사의 서비스를 이용하시면서 발생한 모든 개인정보 보호 관련 문의, 불만처리, 피해구제 등에 관한 사항을 개인정보 보호책임자에게 문의하실 수 있습니다.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제10조 (개인정보 처리방침의 변경)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>이 개인정보 처리방침은 2025년 1월 1일부터 적용됩니다.</li>
              <li>본 개인정보 처리방침의 내용 추가, 삭제 및 수정이 있을 경우에는 시행 최소 7일 전에 서비스 내 공지사항을 통해 사전 공지합니다.</li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제11조 (권익침해 구제방법)</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              정보주체는 개인정보침해로 인한 구제를 받기 위하여 개인정보분쟁조정위원회, 한국인터넷진흥원 개인정보침해신고센터 등에 분쟁해결이나 상담 등을 신청할 수 있습니다.
            </p>
            <ul className="list-disc pl-6 space-y-2 text-gray-700">
              <li>개인정보분쟁조정위원회: (국번없이) 1833-6972 (www.kopico.go.kr)</li>
              <li>개인정보침해신고센터: (국번없이) 118 (privacy.kisa.or.kr)</li>
              <li>대검찰청: (국번없이) 1301 (www.spo.go.kr)</li>
              <li>경찰청: (국번없이) 182 (ecrm.cyber.go.kr)</li>
            </ul>
          </section>
        </div>
        </div>
      </div>
    </div>
  );
}
