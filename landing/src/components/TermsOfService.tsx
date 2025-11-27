import { X } from 'lucide-react';

interface TermsOfServiceProps {
  isOpen: boolean;
  onClose: () => void;
}

export function TermsOfService({ isOpen, onClose }: TermsOfServiceProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4" onClick={onClose}>
      <div
        className="bg-white rounded-2xl max-w-4xl w-full max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="sticky top-0 bg-white border-b border-gray-200 p-6 flex items-center justify-between rounded-t-2xl">
          <h1 className="text-2xl font-bold text-gray-900">서비스 이용약관</h1>
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
            <h2 className="text-xl font-bold mb-4">제1조 (목적)</h2>
            <p className="text-gray-700 leading-relaxed">
              본 약관은 주식회사 이네이블테크(이하 "회사")가 제공하는 AutoGolfCRM 서비스(이하 "서비스")의 이용과 관련하여 회사와 이용자 간의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정함을 목적으로 합니다.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제2조 (용어의 정의)</h2>
            <p className="text-gray-700 leading-relaxed mb-2">본 약관에서 사용하는 용어의 정의는 다음과 같습니다.</p>
            <ul className="list-disc pl-6 space-y-2 text-gray-700">
              <li>"서비스"란 회사가 제공하는 골프연습장 예약 및 운영 관리 시스템을 의미합니다.</li>
              <li>"이용자"란 본 약관에 따라 회사가 제공하는 서비스를 이용하는 자를 말합니다.</li>
              <li>"회원"이란 회사와 서비스 이용계약을 체결하고 아이디를 부여받은 이용자를 말합니다.</li>
              <li>"계정"이란 서비스 이용을 위해 회원이 설정한 아이디와 비밀번호의 조합을 말합니다.</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제3조 (약관의 효력 및 변경)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>본 약관은 서비스를 이용하고자 하는 모든 이용자에게 그 효력이 발생합니다.</li>
              <li>회사는 필요한 경우 관련 법령을 위배하지 않는 범위에서 본 약관을 변경할 수 있습니다.</li>
              <li>약관이 변경되는 경우 회사는 변경사항을 시행일자 7일 전부터 서비스 내 공지사항을 통해 공지합니다.</li>
              <li>회원이 변경된 약관에 동의하지 않는 경우, 서비스 이용을 중단하고 이용계약을 해지할 수 있습니다.</li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제4조 (서비스의 제공 및 변경)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>회사는 다음과 같은 서비스를 제공합니다:
                <ul className="list-disc pl-6 mt-2 space-y-1">
                  <li>골프연습장 타석 및 레슨 예약 시스템</li>
                  <li>회원권 및 이용권 판매 관리</li>
                  <li>고객 관리 및 마케팅 메시지 발송</li>
                  <li>통계 및 분석 리포트 제공</li>
                  <li>기타 회사가 정하는 부가 서비스</li>
                </ul>
              </li>
              <li>회사는 서비스의 내용을 변경할 경우 그 사유와 변경 내용을 사전에 공지합니다.</li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제5조 (서비스 이용계약의 성립)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>이용계약은 이용자가 본 약관에 동의하고 회사가 정한 절차에 따라 회원가입을 신청한 후, 회사가 이를 승낙함으로써 성립합니다.</li>
              <li>회사는 다음 각 호에 해당하는 경우 회원가입을 거부할 수 있습니다:
                <ul className="list-disc pl-6 mt-2 space-y-1">
                  <li>실명이 아니거나 타인의 명의를 사용한 경우</li>
                  <li>허위 정보를 기재한 경우</li>
                  <li>기술상 서비스 제공이 불가능한 경우</li>
                  <li>기타 회사가 정한 이용 신청 요건이 미비한 경우</li>
                </ul>
              </li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제6조 (이용요금 및 결제)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>서비스의 이용요금은 회사가 정한 요금표에 따릅니다.</li>
              <li>이용요금은 선불 또는 후불 방식으로 결제할 수 있으며, 구체적인 결제 방법은 서비스 내에서 안내합니다.</li>
              <li>회원이 결제한 이용요금은 원칙적으로 환불되지 않으나, 회사의 귀책사유로 서비스를 제공하지 못한 경우에는 환불합니다.</li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제7조 (회원의 의무)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>회원은 계정 정보를 타인에게 양도하거나 대여할 수 없습니다.</li>
              <li>회원은 본 약관 및 관련 법령을 준수해야 합니다.</li>
              <li>회원은 다음 행위를 해서는 안 됩니다:
                <ul className="list-disc pl-6 mt-2 space-y-1">
                  <li>허위 정보 등록 또는 타인의 정보 도용</li>
                  <li>회사의 저작권, 제3자의 저작권 등 기타 권리 침해</li>
                  <li>서비스의 안정적 운영을 방해하는 행위</li>
                  <li>기타 관련 법령에 위배되는 행위</li>
                </ul>
              </li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제8조 (회사의 의무)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>회사는 관련 법령과 본 약관이 금지하거나 미풍양속에 반하는 행위를 하지 않으며, 계속적이고 안정적으로 서비스를 제공하기 위해 최선을 다합니다.</li>
              <li>회사는 회원의 개인정보 보호를 위해 개인정보 처리방침을 수립하고 이를 공시합니다.</li>
              <li>회사는 서비스 이용과 관련하여 회원으로부터 제기된 의견이나 불만이 정당하다고 인정할 경우, 이를 처리하기 위해 노력합니다.</li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제9조 (서비스의 중단)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>회사는 다음 각 호의 경우 서비스 제공을 일시적으로 중단할 수 있습니다:
                <ul className="list-disc pl-6 mt-2 space-y-1">
                  <li>시스템 정기점검, 서버의 증설 및 교체</li>
                  <li>서비스 설비의 장애 또는 서비스 이용의 폭주</li>
                  <li>전기통신사업법에 규정된 기간통신사업자의 서비스 중단</li>
                  <li>기타 불가항력적 사유</li>
                </ul>
              </li>
              <li>회사는 서비스 중단 시 사전에 공지하며, 불가피한 경우 사후에 공지할 수 있습니다.</li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제10조 (계약의 해지)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>회원은 언제든지 서비스 이용계약 해지를 요청할 수 있으며, 회사는 즉시 처리합니다.</li>
              <li>회사는 회원이 본 약관을 위반한 경우 사전 통지 후 계약을 해지할 수 있습니다.</li>
              <li>계약 해지 시 관련 법령 및 개인정보 처리방침에 따라 회원 정보를 보유하는 경우를 제외하고는 회원 정보를 즉시 삭제합니다.</li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제11조 (면책사항)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>회사는 천재지변 또는 이에 준하는 불가항력으로 인해 서비스를 제공할 수 없는 경우 서비스 제공에 관한 책임이 면제됩니다.</li>
              <li>회사는 회원의 귀책사유로 인한 서비스 이용 장애에 대하여 책임을 지지 않습니다.</li>
              <li>회사는 회원이 서비스를 이용하여 기대하는 수익을 얻지 못하거나 상실한 것에 대하여 책임을 지지 않습니다.</li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">제12조 (준거법 및 관할법원)</h2>
            <ol className="list-decimal pl-6 space-y-2 text-gray-700">
              <li>본 약관의 해석 및 회사와 회원 간의 분쟁에 대하여는 대한민국 법을 적용합니다.</li>
              <li>서비스 이용과 관련하여 회사와 회원 간에 발생한 분쟁에 대해서는 회사 본사 소재지를 관할하는 법원을 전속 관할법원으로 합니다.</li>
            </ol>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-bold mb-4">부칙</h2>
            <p className="text-gray-700">본 약관은 2025년 1월 1일부터 시행됩니다.</p>
          </section>
        </div>
        </div>
      </div>
    </div>
  );
}
