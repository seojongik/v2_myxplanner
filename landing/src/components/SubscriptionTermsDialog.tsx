import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from './ui/dialog';
import { ScrollArea } from './ui/scroll-area';

interface SubscriptionTermsDialogProps {
  isOpen: boolean;
  onClose: () => void;
}

export function SubscriptionTermsDialog({ isOpen, onClose }: SubscriptionTermsDialogProps) {
  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-[700px] max-h-[90vh] bg-white">
        <DialogHeader>
          <DialogTitle className="text-2xl font-bold">프로그램 구독약관</DialogTitle>
          <DialogDescription>
            본 약관은 (주) 이네이블테크의 AutoGolf CRM 서비스 이용에 관한 계약조건을 규정합니다.
          </DialogDescription>
        </DialogHeader>

        <ScrollArea className="max-h-[60vh] pr-4">
          <div className="space-y-6 text-sm text-gray-700 leading-relaxed">
            {/* 제1조 목적 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제1조 (목적)</h3>
              <p className="pl-4">
                본 약관은 주식회사 이네이블테크(이하 "회사"라 함)가 제공하는 AutoGolf CRM 서비스(이하 "서비스"라 함)의 이용과 관련하여 회사와 이용자 간의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정함을 목적으로 합니다.
              </p>
            </section>

            {/* 제2조 정의 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제2조 (정의)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li>"서비스"란 회사가 제공하는 골프 연습장 예약 및 운영 관리 시스템을 의미합니다.</li>
                <li>"이용자"란 본 약관에 동의하고 회사가 제공하는 서비스를 이용하는 개인 또는 법인을 의미합니다.</li>
                <li>"구독"이란 이용자가 일정 기간 동안 서비스를 이용하기 위해 요금을 지불하는 것을 의미합니다.</li>
                <li>"시작"이란 예약운영을 위한 매장 설정이 완료되어 실제 서비스 이용이 가능한 시점을 의미합니다.</li>
                <li>"플랜"이란 Basic, Pro, FullAuto 등 서비스 이용 범위를 구분하는 요금제를 의미합니다.</li>
              </ol>
            </section>

            {/* 제3조 약관의 효력 및 변경 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제3조 (약관의 효력 및 변경)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li>본 약관은 서비스를 이용하고자 하는 모든 이용자에 대하여 그 효력을 발생합니다.</li>
                <li>회사는 필요한 경우 관련 법령을 위배하지 않는 범위에서 본 약관을 변경할 수 있습니다.</li>
                <li>약관이 변경되는 경우 회사는 변경 사항을 서비스 내 공지사항 또는 이메일 등을 통해 공지합니다.</li>
                <li>이용자가 변경된 약관에 동의하지 않는 경우 서비스 이용을 중단하고 이용계약을 해지할 수 있습니다.</li>
              </ol>
            </section>

            {/* 제4조 이용계약의 체결 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제4조 (이용계약의 체결)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li>이용계약은 이용자가 본 약관에 동의하고 결제를 완료함으로써 성립합니다.</li>
                <li>이용자는 서비스 이용을 위해 필요한 정보를 정확하게 제공해야 합니다.</li>
                <li>회사는 다음 각 호에 해당하는 경우 이용계약 체결을 거부할 수 있습니다:
                  <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
                    <li>실명이 아니거나 타인의 명의를 사용한 경우</li>
                    <li>허위 정보를 기재한 경우</li>
                    <li>기술상 서비스 제공이 불가능한 경우</li>
                    <li>기타 회사가 정한 이용 신청 요건이 미비한 경우</li>
                  </ul>
                </li>
              </ol>
            </section>

            {/* 제5조 서비스의 제공 및 이용 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제5조 (서비스의 제공 및 이용)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li>회사는 이용자에게 다음 각 호의 서비스를 제공합니다:
                  <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
                    <li>타석 및 레슨 예약 관리 시스템</li>
                    <li>회원권 및 이용권 관리</li>
                    <li>고객 관리 및 마케팅 도구</li>
                    <li>매출 통계 및 리포트</li>
                    <li>기타 회사가 추가로 개발하거나 제휴계약 등을 통해 제공하는 일체의 서비스</li>
                  </ul>
                </li>
                <li>서비스의 이용은 예약운영을 위한 매장 설정이 완료된 시점(이하 "시작"이라 함)부터 가능합니다.</li>
                <li>이용자는 선택한 플랜에 따라 서비스 이용 범위가 결정됩니다.</li>
                <li>회사는 서비스 제공을 위해 필요한 경우 이용자에게 매장 설정 및 초기 설정을 안내할 수 있습니다.</li>
              </ol>
            </section>

            {/* 제6조 이용요금 및 결제 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제6조 (이용요금 및 결제)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li>서비스 이용요금은 선택한 플랜과 타석수, 구독 기간에 따라 결정됩니다.</li>
                <li>이용요금은 선불 방식으로 결제하며, 결제 수단은 신용카드, 계좌이체 등 회사가 제공하는 방법을 사용할 수 있습니다.</li>
                <li>6개월 이상 구독 시 할인 혜택이 적용될 수 있으며, 할인율은 회사가 정한 기준에 따릅니다.</li>
                <li>결제 완료 후 영업일 기준 1일 이내에 결제 확인서가 발송됩니다.</li>
                <li>이용자는 결제 정보를 정확하게 입력해야 하며, 결제 정보 오류로 인한 불이익은 이용자가 부담합니다.</li>
              </ol>
            </section>

            {/* 제7조 서비스 이용의 제한 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제7조 (서비스 이용의 제한)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li>이용자는 다음 각 호에 해당하는 행위를 하여서는 안 됩니다:
                  <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
                    <li>서비스를 이용하여 법령 또는 본 약관이 금지하거나 공서양속에 반하는 행위를 하는 경우</li>
                    <li>타인의 명의를 도용하거나 타인에게 서비스를 제공하는 경우</li>
                    <li>서비스의 안정적 운영을 방해하거나 방해할 우려가 있는 행위</li>
                    <li>회사의 지적재산권을 침해하는 행위</li>
                    <li>기타 회사가 정한 이용 제한 사항을 위반하는 경우</li>
                  </ul>
                </li>
                <li>회사는 전항에 해당하는 행위를 한 이용자에 대하여 서비스 이용을 제한하거나 이용계약을 해지할 수 있습니다.</li>
              </ol>
            </section>

            {/* 제8조 취소 및 환불 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제8조 (취소 및 환불)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li><strong>환불 원칙</strong>
                  <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
                    <li>이용요금은 원칙적으로 환불되지 않습니다.</li>
                    <li>단, 본 조 제2항 내지 제3항에 해당하는 경우에 한하여 환불이 가능합니다.</li>
                  </ul>
                </li>
                <li><strong>청약철회 (결제 후 7일 이내)</strong>
                  <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
                    <li>이용자는 결제일로부터 7일 이내에 청약을 철회할 수 있으며, 이 경우 전액 환불됩니다.</li>
                    <li>단, 서비스 시작(예약운영을 위한 매장 설정 완료)이 이루어진 경우에는 청약철회가 제한됩니다.</li>
                    <li>서비스가 시작된 후에는 이용자가 명백히 동의하고 청약철회권이 제한됨을 인지한 것으로 봅니다.</li>
                  </ul>
                </li>
                <li><strong>회사의 귀책사유로 인한 환불</strong>
                  <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
                    <li>회사의 귀책사유로 서비스를 제공하지 못하거나 정상적인 서비스 이용이 불가능한 경우에는 다음과 같이 환불합니다:
                      <ul className="list-circle list-inside ml-6 mt-1 space-y-1">
                        <li>서비스를 전혀 제공하지 못한 경우: 이용요금 전액 환불</li>
                        <li>서비스를 일부 제공한 경우: 서비스를 제공하지 못한 기간에 해당하는 금액 환불 (일할 계산)</li>
                      </ul>
                    </li>
                    <li>회사의 귀책사유란 시스템 장애, 서버 오류 등 회사의 고의 또는 중대한 과실로 인하여 서비스 제공이 불가능한 경우를 의미하며, 천재지변, 불가항력, 이용자의 귀책사유로 인한 경우는 제외됩니다.</li>
                  </ul>
                </li>
                <li><strong>환불 불가 사유</strong>
                  <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
                    <li>다음 각 호의 경우에는 환불이 불가능합니다:
                      <ul className="list-circle list-inside ml-6 mt-1 space-y-1">
                        <li>서비스 시작 후 이용자의 단순 변심으로 인한 취소</li>
                        <li>이용자의 귀책사유로 인한 계약 해지</li>
                        <li>서비스를 일부라도 이용한 경우 (회사의 귀책사유 제외)</li>
                        <li>할인 혜택을 받아 결제한 경우의 할인 금액</li>
                      </ul>
                    </li>
                  </ul>
                </li>
                <li><strong>환불 처리 절차</strong>
                  <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
                    <li>환불 요청은 회사의 고객지원 이메일 또는 서비스 내 고객지원 기능을 통해 신청할 수 있습니다.</li>
                    <li>회사는 환불 요청 접수 후 영업일 기준 5~7일 이내에 환불 여부를 검토하여 통보합니다.</li>
                    <li>환불이 승인된 경우, 승인일로부터 영업일 기준 3~5일 이내에 처리됩니다.</li>
                    <li>환불은 원래 결제 수단으로 환불되며, 결제 수단별 정책에 따라 실제 환불 완료까지 추가 기간이 소요될 수 있습니다.</li>
                  </ul>
                </li>
              </ol>
            </section>

            {/* 제9조 계약 해지 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제9조 (계약 해지)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li><strong>이용자의 해지</strong>
                  <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
                    <li>이용자는 서비스 이용 중 언제든지 이용계약을 해지할 수 있습니다.</li>
                    <li>계약 해지 시 제8조(취소 및 환불) 규정에 따라 처리되며, 원칙적으로 환불되지 않습니다.</li>
                    <li>계약 해지 후에는 서비스 이용이 즉시 중단되며, 잔여 기간에 대한 보상은 제공되지 않습니다.</li>
                  </ul>
                </li>
                <li><strong>회사의 해지</strong>
                  <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
                    <li>회사는 다음 각 호에 해당하는 경우 이용계약을 해지할 수 있습니다:
                      <ul className="list-circle list-inside ml-6 mt-1 space-y-1">
                        <li>이용자가 본 약관을 위반한 경우</li>
                        <li>이용요금을 정당한 사유 없이 납부하지 않은 경우</li>
                        <li>제7조(서비스 이용의 제한)에 해당하는 행위를 한 경우</li>
                        <li>기타 회사가 정한 해지 사유가 발생한 경우</li>
                      </ul>
                    </li>
                    <li>회사의 해지 시 이용자에게 사전 통지하며, 이용자의 귀책사유로 인한 해지의 경우 환불되지 않습니다.</li>
                  </ul>
                </li>
                <li><strong>계약 해지의 효과</strong>
                  <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
                    <li>계약 해지 시 이용자의 모든 서비스 이용 권한이 즉시 중지됩니다.</li>
                    <li>이용자의 데이터는 관련 법령에 따라 일정 기간 보관된 후 삭제됩니다.</li>
                    <li>해지 후에도 이용자는 본 약관에 따른 의무(손해배상 등)를 부담합니다.</li>
                  </ul>
                </li>
              </ol>
            </section>

            {/* 제10조 손해배상 및 면책 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제10조 (손해배상 및 면책)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li>회사는 천재지변 또는 이에 준하는 불가항력으로 인하여 서비스를 제공할 수 없는 경우에는 서비스 제공에 관한 책임이 면제됩니다.</li>
                <li>회사는 이용자의 귀책사유로 인한 서비스 이용의 장애에 대하여는 책임을 지지 않습니다.</li>
                <li>회사는 이용자가 서비스를 이용하여 기대하는 수익을 상실한 것에 대하여 책임을 지지 않으며, 그 밖의 서비스를 통하여 얻은 자료로 인한 손해에 관하여 책임을 지지 않습니다.</li>
                <li>회사는 이용자 상호간 또는 이용자와 제3자 상호간에 서비스를 매개로 하여 발생한 분쟁에 대해서는 개입할 의무가 없으며, 이로 인한 손해를 배상할 책임도 없습니다.</li>
              </ol>
            </section>

            {/* 제11조 개인정보 보호 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제11조 (개인정보 보호)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li>회사는 이용자의 개인정보 보호를 위하여 노력합니다.</li>
                <li>개인정보의 보호 및 사용에 대해서는 관련 법령 및 회사의 개인정보처리방침이 적용됩니다.</li>
                <li>회사는 서비스 제공을 위해 필요한 최소한의 개인정보만을 수집합니다.</li>
                <li>이용자는 언제든지 자신의 개인정보를 열람하거나 수정할 수 있으며, 회사에 삭제를 요청할 수 있습니다.</li>
              </ol>
            </section>

            {/* 제12조 지적재산권 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제12조 (지적재산권)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li>서비스에 대한 저작권 및 지적재산권은 회사에 귀속됩니다.</li>
                <li>이용자는 회사의 사전 서면 승인 없이 서비스를 복제, 전송, 출판, 배포, 방송 기타 방법에 의하여 영리목적으로 이용하거나 제3자에게 이용하게 하여서는 안 됩니다.</li>
                <li>이용자가 서비스 내에 게시한 게시물의 저작권은 해당 게시물의 저작자에게 귀속됩니다.</li>
              </ol>
            </section>

            {/* 제13조 분쟁의 해결 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제13조 (분쟁의 해결)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li>회사와 이용자 간에 발생한 전자상거래 분쟁에 관한 소송은 제소 당시의 이용자의 주소에 의하고, 주소가 없는 경우에는 거소를 관할하는 지방법원의 전속관할로 합니다.</li>
                <li>회사와 이용자 간에 제기된 전자상거래 소송에는 한국법을 적용합니다.</li>
              </ol>
            </section>

            {/* 제14조 기타 */}
            <section>
              <h3 className="text-base font-bold text-gray-900 mb-2">제14조 (기타)</h3>
              <ol className="pl-4 space-y-2 list-decimal list-inside">
                <li>본 약관에서 정하지 아니한 사항에 대해서는 관련 법령 또는 상관례에 따릅니다.</li>
                <li>본 약관의 해석에 관하여는 회사와 이용자 간에 성실히 협의하여 결정합니다.</li>
                <li>본 약관은 2024년 1월 1일부터 시행됩니다.</li>
              </ol>
            </section>

            {/* 부칙 */}
            <section className="border-t pt-4 mt-6">
              <h3 className="text-base font-bold text-gray-900 mb-2">부칙</h3>
              <p className="pl-4 text-xs text-gray-500">
                본 약관에 동의하시는 경우, 위의 모든 조항을 이해하고 동의한 것으로 간주됩니다.
                서비스 이용 전 반드시 본 약관을 확인하시기 바랍니다.
              </p>
            </section>
          </div>
        </ScrollArea>
      </DialogContent>
    </Dialog>
  );
}

