import { Users, Phone, DollarSign, MessageSquare } from 'lucide-react';
import { Category } from './types';

export const customerRelationshipData: Category = {
  title: '고객관계관리',
  subtitle: '당신은 무엇에 집중하고 있나요?',
  icon: Users,
  color: 'from-blue-500 to-cyan-500',
  bgPattern: 'from-blue-50 to-cyan-50',
  placeholderSlots: 2,
  cardNewsList: [
    {
      title: '눈 앞의 고객에 집중하세요',
      icon: Phone,
      slides: [
        {
          title: '레슨 중/상담 중에 걸려오는 전화',
          content: (
            <div className="space-y-6">
              <div className="text-center mb-6">
                <div className="text-6xl mb-4">📞</div>
                <p className="text-xl text-gray-800 font-semibold mb-2">
                  받을 것이냐 말 것이냐?<br />그것이 문제로다.
                </p>
              </div>
              <div className="bg-gradient-to-br from-blue-50 to-cyan-50 p-6 rounded-2xl">
                <h3 className="text-xl font-bold text-gray-900 mb-4">📞 전문상담원 상주 통합 콜센터</h3>
                <p className="text-gray-700 mb-4 italic">"걸려오는 전화까지 모두 처리하는 진정한 Full Auto"</p>
                <div className="space-y-2">
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">타석/레슨 예약 및 일반문의</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">회원권 구매 상담(유선)</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">이용중 불편고객 유선응대</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">오프라인 방문일정 예약</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">유선응대 현황 실시간 공유</span>
                  </div>
                </div>
              </div>
              <p className="text-center text-lg font-semibold text-gray-900">
                눈 앞의 고객에 집중하세요. 전문 CS상담원이 응대합니다.
              </p>
            </div>
          )
        },
        {
          title: '모든 시간대 직원 배치의 부담',
          content: (
            <div className="space-y-6">
              <div className="bg-red-50 p-5 rounded-xl border-l-4 border-red-500 mb-6">
                <p className="text-lg text-gray-800 font-semibold">
                  "모든 시간대에 직원을 쓰기에<br />인건비가 너무 부담되요."
                </p>
              </div>
              <div className="bg-gradient-to-br from-blue-50 to-cyan-50 p-6 rounded-2xl">
                <h3 className="text-xl font-bold text-gray-900 mb-4">📞 전문상담원 상주 통합 콜센터</h3>
                <p className="text-gray-700 mb-4 italic">"걸려오는 전화까지 모두 처리하는 진정한 Full Auto"</p>
                <div className="space-y-2">
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">타석/레슨 예약 및 일반문의</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">회원권 구매 상담(유선)</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">이용중 불편고객 유선응대</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">오프라인 방문일정 예약</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">유선응대 현황 실시간 공유</span>
                  </div>
                </div>
              </div>
              <div className="text-center">
                <p className="text-lg font-semibold text-gray-900">
                  → 과감히 무인운영하세요.<br />
                  <span className="bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">
                    전문 CS상담원이 당신의 빈 시간을 채웁니다.
                  </span>
                </p>
              </div>
            </div>
          )
        },
        {
          title: '직원 서비스 품질 고민',
          content: (
            <div className="space-y-6">
              <div className="bg-red-50 p-5 rounded-xl border-l-4 border-red-500 mb-6">
                <p className="text-lg text-gray-800 font-semibold">
                  "새로 뽑은 직원이 친절하지 않고,<br />내 마음 같지 않아서 답답해요."
                </p>
              </div>
              <div className="bg-gradient-to-br from-blue-50 to-cyan-50 p-6 rounded-2xl">
                <h3 className="text-xl font-bold text-gray-900 mb-4">📞 전문상담원 상주 통합 콜센터</h3>
                <p className="text-gray-700 mb-4 italic">"걸려오는 전화까지 모두 처리하는 진정한 Full Auto"</p>
                <div className="space-y-2">
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">타석/레슨 예약 및 일반문의</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">회원권 구매 상담(유선)</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">이용중 불편고객 유선응대</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">오프라인 방문일정 예약</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">유선응대 현황 실시간 공유</span>
                  </div>
                </div>
              </div>
              <p className="text-center text-lg font-semibold text-gray-900">
                체계적인 메뉴얼, 교육된 CS상담원이<br />
                <span className="bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">
                  당신의 팀원이 됩니다.
                </span>
              </p>
            </div>
          )
        },
        {
          title: '고객 불만 응대의 스트레스',
          content: (
            <div className="space-y-6">
              <div className="bg-red-50 p-5 rounded-xl border-l-4 border-red-500 mb-6">
                <p className="text-lg text-gray-800 font-semibold">
                  "고객 불만을 응대하는게 너무 힘들어요"
                </p>
              </div>
              <div className="bg-gradient-to-br from-blue-50 to-cyan-50 p-6 rounded-2xl">
                <h3 className="text-xl font-bold text-gray-900 mb-4">📞 전문상담원 상주 통합 콜센터</h3>
                <p className="text-gray-700 mb-4 italic">"걸려오는 전화까지 모두 처리하는 진정한 Full Auto"</p>
                <div className="space-y-2">
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">타석/레슨 예약 및 일반문의</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">회원권 구매 상담(유선)</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">이용중 불편고객 유선응대</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">오프라인 방문일정 예약</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">유선응대 현황 실시간 공유</span>
                  </div>
                </div>
              </div>
              <p className="text-center text-lg font-semibold text-gray-900">
                전문 CS상담원에게 맡기고<br />
                <span className="bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">
                  당신의 감정을 보호하세요
                </span>
              </p>
            </div>
          )
        }
      ]
    },
    {
      title: '운영이 아니라 "고객"에 집중하세요',
      icon: DollarSign,
      slides: [
        {
          title: '회계관리도 자동으로',
          content: (
            <div className="space-y-6">
              <div className="bg-red-50 p-5 rounded-xl border-l-4 border-red-500 mb-6">
                <p className="text-lg text-gray-800 font-semibold">
                  "매월 말에는 비용 계산하느라 쉬지도 못해요."
                </p>
              </div>

              <div className="space-y-4">
                <div className="bg-gradient-to-br from-blue-50 to-cyan-50 p-5 rounded-xl">
                  <h3 className="text-lg font-bold text-gray-900 mb-3">💰 예약기반 원클릭 급여계산</h3>
                  <p className="text-gray-700 mb-3">데이터를 기반으로 프로와 직원의 급여를 자동으로 계산합니다.</p>
                  <div className="space-y-2 text-sm">
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">프로계약 × 레슨 데이터 = 월별 프로 급여</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">직원계약 × 근태기록 = 월별 직원 급여</span>
                    </div>
                  </div>
                </div>

                <div className="bg-gradient-to-br from-green-50 to-emerald-50 p-5 rounded-xl">
                  <h3 className="text-lg font-bold text-gray-900 mb-3">💰 골프연습장 특화 회계관리 솔루션</h3>
                  <div className="space-y-2 text-sm">
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">회원권 매출 집계 완전 자동화</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">인건비 집계 완전 자동화</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">정기 지출 자동집계 등록</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">비정기 지출 수동 등록</span>
                    </div>
                  </div>
                </div>

                <div className="bg-gradient-to-br from-purple-50 to-pink-50 p-5 rounded-xl">
                  <h3 className="text-lg font-bold text-gray-900 mb-3">💰 세무신고 지원</h3>
                  <div className="space-y-2 text-sm">
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">급여, 부가세 신고를 위한 회계데이터 세무사 전송</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">세무사로부터 차인지급액/납부액 수집</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">직원/프로별 급여명세서 출력</span>
                    </div>
                  </div>
                </div>
              </div>

              <p className="text-center text-lg font-semibold text-gray-900">
                → AutoGolfCRM에서 물 흐르듯<br />
                <span className="bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">
                  완성되는 회계관리와 세무신고
                </span>
              </p>
            </div>
          )
        }
      ]
    },
    {
      title: '"소통방법"이 아니라 "내용"에 집중하세요',
      icon: MessageSquare,
      slides: [
        {
          title: '고객 소통의 어려움',
          content: (
            <div className="space-y-6">
              <div className="bg-red-50 p-5 rounded-xl border-l-4 border-red-500 mb-6">
                <p className="text-lg text-gray-800 font-semibold">
                  "공지사항 전달하는 것도 일인데<br />도달이 잘 안되요."
                </p>
              </div>

              <div className="space-y-4">
                <div className="bg-gradient-to-br from-blue-50 to-cyan-50 p-5 rounded-xl">
                  <h3 className="text-lg font-bold text-gray-900 mb-3">📧 1:1 채팅 기능 기본제공</h3>
                  <div className="space-y-2">
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">무료 1:1 소통 채널</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">상호 푸시 알림 기능</span>
                    </div>
                  </div>
                </div>

                <div className="bg-gradient-to-br from-green-50 to-emerald-50 p-5 rounded-xl">
                  <h3 className="text-lg font-bold text-gray-900 mb-3">📧 원클릭 대량 메시지 발송</h3>
                  <div className="space-y-2">
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">고객 공지사항 도달률 극대화</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">프로별, 고객유형별 편리한 소통대상 분류</span>
                    </div>
                  </div>
                </div>

                <div className="bg-gradient-to-br from-purple-50 to-pink-50 p-5 rounded-xl">
                  <h3 className="text-lg font-bold text-gray-900 mb-3">📧 고객 Activity기반 메시지 자동발송</h3>
                  <div className="space-y-2">
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">예약내역, 할인정보 등 기본 안내 자동발송</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-green-600">✅</span>
                      <span className="text-gray-700">고객수신동의 기반 알림발송</span>
                    </div>
                  </div>
                </div>
              </div>

              <p className="text-center text-xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">
                생각한다. 쓴다. 보낸다. Done! So Easy
              </p>
            </div>
          )
        },
        {
          title: '골프에 대한 소통',
          content: (
            <div className="space-y-6">
              <div className="bg-red-50 p-5 rounded-xl border-l-4 border-red-500 mb-6">
                <p className="text-lg text-gray-800 font-semibold">
                  "고객과 '골프'에 대해 소통할<br />온라인 수단이 없어요"
                </p>
              </div>

              <div className="bg-gradient-to-br from-blue-50 to-cyan-50 p-6 rounded-xl">
                <h3 className="text-xl font-bold text-gray-900 mb-4">📧 레슨 상호 피드백 솔루션</h3>
                <div className="space-y-3">
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">레슨예약시 중점점검 희망포인트 요청</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">레슨 후 피드백, 다음레슨까지 과제 부여 기능</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600 font-bold">✅</span>
                    <span className="text-gray-700">타석/레슨 서비스 만족도 평가 가능</span>
                  </div>
                </div>
              </div>

              <p className="text-center text-xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent mt-8">
                생각한다. 쓴다. 보낸다. Done! So Easy
              </p>
            </div>
          )
        }
      ]
    }
  ]
};
