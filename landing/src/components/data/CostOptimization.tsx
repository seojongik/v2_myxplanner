import { Clock, Smartphone, Zap, Shield, Building } from 'lucide-react';
import { Category } from './types';

export const costOptimizationData: Category = {
  title: '비용최적화',
  subtitle: '고객만족과 비용절감을 동시에',
  icon: Clock,
  color: 'from-purple-500 to-pink-500',
  bgPattern: 'from-purple-50 to-pink-50',
  placeholderSlots: 1,
  cardNewsList: [
    {
      title: '무료지만 강력한 예약 APP',
      icon: Smartphone,
      slides: [
        {
          title: '무료 예약 APP 솔루션',
          content: (
            <div className="space-y-5">
              <div className="text-center mb-6">
                <div className="text-5xl mb-3">📱</div>
                <h3 className="text-2xl font-bold text-gray-900">💸 무료지만 강력한 예약APP 솔루션</h3>
              </div>

              <div className="space-y-3">
                <div className="flex items-start gap-3">
                  <span className="text-green-600 text-xl">✅</span>
                  <span className="text-gray-700">고객응대 부담을 대폭 줄이는 편리한 APP 설계</span>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-green-600 text-xl">✅</span>
                  <span className="text-gray-700">보기만 해도 알 수 있는 직관적인 UI</span>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-green-600 text-xl">✅</span>
                  <span className="text-gray-700">셀프 조회기능 (회원권, 예약이력, 보유쿠폰 등)</span>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-green-600 text-xl">✅</span>
                  <span className="text-gray-700">생각의 흐름대로 클릭하면 예약 완료</span>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-green-600 text-xl">✅</span>
                  <span className="text-gray-700">설정된 CRM 취소정책 기반 패널티 자동부여</span>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-green-600 text-xl">✅</span>
                  <span className="text-gray-700">예약권 부족시 원클릭 회원권 결제</span>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-green-600 text-xl">✅</span>
                  <span className="text-gray-700">OTP 기반 예약타석 오픈기능 제공</span>
                </div>
              </div>
            </div>
          )
        }
      ]
    },
    {
      title: '예약기반 타석제어',
      icon: Zap,
      slides: [
        {
          title: '스마트 타석 운영',
          content: (
            <div className="space-y-6">
              <div className="text-center mb-6">
                <div className="text-5xl mb-3">⚡</div>
                <h3 className="text-2xl font-bold text-gray-900 mb-2">
                  고객이 떠나는 순간 꺼진다
                </h3>
                <p className="text-lg text-gray-600">예약기반 타석제어 솔루션</p>
              </div>

              <div className="bg-gradient-to-br from-purple-50 to-pink-50 p-6 rounded-xl space-y-4">
                <div className="flex items-start gap-3">
                  <span className="text-green-600 text-xl">✅</span>
                  <div>
                    <div className="font-semibold text-gray-900">예약기반 스마트 타석운영</div>
                    <div className="text-sm text-gray-600 mt-1">
                      예약종료: 절전모드 진입 | 예약시간 5분전: 활성화
                    </div>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-green-600 text-xl">✅</span>
                  <span className="text-gray-700">전기료 최적화</span>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-green-600 text-xl">✅</span>
                  <span className="text-gray-700">전원관리를 위한 모니터링 최소화 (예약기반!)</span>
                </div>
              </div>

              <div className="bg-green-50 p-5 rounded-xl text-center">
                <p className="text-lg font-semibold text-gray-900">
                  전기료 절감과 편리함을<br />동시에 잡는 스마트 솔루션
                </p>
              </div>
            </div>
          )
        }
      ]
    },
    {
      title: 'Serviced 무인운영',
      icon: Shield,
      slides: [
        {
          title: '진정한 무인운영',
          content: (
            <div className="space-y-6">
              <div className="text-center mb-6">
                <div className="text-5xl mb-3">🌟</div>
                <h3 className="text-xl font-bold text-gray-900">
                  쉴 수 없는 내 일상의 작은 쉼표,<br />
                  <span className="bg-gradient-to-r from-purple-600 to-pink-600 bg-clip-text text-transparent">
                    'Serviced 무인운영' 솔루션
                  </span>
                </h3>
              </div>

              <div className="bg-red-50 p-5 rounded-xl border-l-4 border-red-500">
                <div className="flex items-start gap-2">
                  <span className="text-red-600 text-xl">❌</span>
                  <span className="text-gray-800 font-medium">
                    고객을 끝내 이탈시키는 PC 전원 on/off 중심의 기존 무인운영
                  </span>
                </div>
              </div>

              <div className="bg-gradient-to-br from-purple-50 to-pink-50 p-6 rounded-xl">
                <div className="flex items-start gap-2 mb-4">
                  <span className="text-purple-600 text-2xl">✨</span>
                  <h4 className="text-lg font-bold text-gray-900">
                    고객경험을 오히려 '향상'시키는<br />Serviced 무인운영 솔루션
                  </h4>
                </div>
                <div className="space-y-3">
                  <div className="flex items-start gap-2">
                    <span className="text-green-600">✅</span>
                    <span className="text-gray-700">전문 CS 상담원의 고객 문의 실시간 유선 응대</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600">✅</span>
                    <span className="text-gray-700">예약 및 결제, 방문상담 예약 지원</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600">✅</span>
                    <span className="text-gray-700">타석 문제 발생시 대응 지원 (필요시 AS 직원 출동요청)</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-green-600">✅</span>
                    <span className="text-gray-700">점주님과 실시간 소통</span>
                  </div>
                </div>
              </div>

              <div className="bg-green-50 p-5 rounded-xl text-center">
                <p className="text-lg font-semibold text-gray-900">
                  <span className="bg-gradient-to-r from-purple-600 to-pink-600 bg-clip-text text-transparent">
                    ✨ 비활성 시간대 무인운영 확대로<br />추가 인건비 절감
                  </span>
                </p>
              </div>
            </div>
          )
        }
      ]
    },
    {
      title: '프랜차이즈 시스템 독립',
      icon: Building,
      slides: [
        {
          title: '시스템 독립선언',
          content: (
            <div className="space-y-6">
              <div className="text-center mb-6">
                <div className="text-5xl mb-3">🔓</div>
                <h3 className="text-2xl font-bold text-gray-900">
                  프랜차이즈 본사로부터<br />
                  <span className="bg-gradient-to-r from-purple-600 to-pink-600 bg-clip-text text-transparent">
                    시스템 독립선언
                  </span>
                </h3>
              </div>

              <div className="space-y-4">
                <div className="bg-gradient-to-br from-purple-50 to-pink-50 p-6 rounded-xl">
                  <div className="space-y-4">
                    <div className="flex items-start gap-3">
                      <span className="text-green-600 text-xl">✅</span>
                      <div>
                        <div className="font-semibold text-gray-900">점주의 개선 요청은 후순위 업무</div>
                        <div className="text-sm text-gray-600 mt-1">
                          → AutoGolfCRM은 고객의 목소리를 최우선으로
                        </div>
                      </div>
                    </div>
                    <div className="flex items-start gap-3">
                      <span className="text-green-600 text-xl">✅</span>
                      <div>
                        <div className="font-semibold text-gray-900">시스템 독립으로 로열티 최소화</div>
                        <div className="text-sm text-gray-600 mt-1">
                          → 본사 수수료 없이 합리적인 비용으로
                        </div>
                      </div>
                    </div>
                    <div className="flex items-start gap-3">
                      <span className="text-green-600 text-xl">✅</span>
                      <div>
                        <div className="font-semibold text-gray-900">프랜차이즈 본사에 종속된 심리상태 개선</div>
                        <div className="text-sm text-gray-600 mt-1">
                          → 내 사업을 내가 컨트롤하는 자유
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div className="bg-gradient-to-r from-purple-100 to-pink-100 p-5 rounded-xl text-center">
                <p className="text-lg font-bold text-gray-900">
                  진정한 독립,<br />
                  <span className="bg-gradient-to-r from-purple-600 to-pink-600 bg-clip-text text-transparent">
                    AutoGolfCRM과 함께 시작하세요
                  </span>
                </p>
              </div>
            </div>
          )
        }
      ]
    }
  ]
};
