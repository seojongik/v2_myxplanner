import { Check, X } from 'lucide-react';

export function Pricing() {
  const plans = [
    {
      name: 'Basic',
      price: '99,000',
      description: '소규모 연습장을 위한 기본 플랜',
      color: 'from-blue-500 to-cyan-500',
      features: {
        '예약 관리': true,
        '회원 관리 (최대 500명)': true,
        '기본 마케팅 기능': true,
        '월간 리포트': true,
        'SMS 발송 (월 100건)': true,
        '고급 분석 대시보드': false,
        '자동 캠페인': false,
        '무제한 회원': false,
        'API 연동': false,
        '전담 매니저': false,
        'AI 마케팅 추천': false,
        '맞춤 개발': false
      }
    },
    {
      name: 'Pro',
      price: '249,000',
      description: '중대형 연습장을 위한 프로 플랜',
      color: 'from-green-500 to-emerald-500',
      popular: true,
      features: {
        '예약 관리': true,
        '회원 관리 (최대 500명)': true,
        '기본 마케팅 기능': true,
        '월간 리포트': true,
        'SMS 발송 (월 100건)': true,
        '고급 분석 대시보드': true,
        '자동 캠페인': true,
        '무제한 회원': true,
        'API 연동': true,
        '전담 매니저': false,
        'AI 마케팅 추천': true,
        '맞춤 개발': false
      }
    },
    {
      name: 'FullAuto',
      price: '499,000',
      description: '완전 자동화가 필요한 프리미엄 플랜',
      color: 'from-purple-500 to-pink-500',
      features: {
        '예약 관리': true,
        '회원 관리 (최대 500명)': true,
        '기본 마케팅 기능': true,
        '월간 리포트': true,
        'SMS 발송 (월 100건)': true,
        '고급 분석 대시보드': true,
        '자동 캠페인': true,
        '무제한 회원': true,
        'API 연동': true,
        '전담 매니저': true,
        'AI 마케팅 추천': true,
        '맞춤 개발': true
      }
    }
  ];

  const allFeatures = [
    '예약 관리',
    '회원 관리 (최대 500명)',
    '기본 마케팅 기능',
    '월간 리포트',
    'SMS 발송 (월 100건)',
    '고급 분석 대시보드',
    '자동 캠페인',
    '무제한 회원',
    'API 연동',
    '전담 매니저',
    'AI 마케팅 추천',
    '맞춤 개발'
  ];

  return (
    <section id="pricing" className="py-20 px-4 bg-white">
      <div className="container mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-gray-900 mb-4">Pricing</h2>
          <p className="text-gray-600 max-w-2xl mx-auto">
            업장 규모와 필요에 맞는 플랜을 선택하세요
          </p>
        </div>

        {/* Cards View for Mobile */}
        <div className="grid md:grid-cols-3 gap-8 mb-12 lg:hidden">
          {plans.map((plan, index) => (
            <div
              key={index}
              className={`relative bg-white border-2 rounded-2xl p-8 ${
                plan.popular ? 'border-green-500 shadow-xl' : 'border-gray-200'
              }`}
            >
              {plan.popular && (
                <div className="absolute -top-4 left-1/2 -translate-x-1/2 px-4 py-1 bg-gradient-to-r from-green-500 to-emerald-500 text-white rounded-full text-sm">
                  인기
                </div>
              )}
              <div className={`inline-block px-4 py-2 rounded-lg bg-gradient-to-r ${plan.color} text-white mb-4`}>
                {plan.name}
              </div>
              <div className="mb-4">
                <span className="text-4xl text-gray-900">₩{plan.price}</span>
                <span className="text-gray-600">/월</span>
              </div>
              <p className="text-gray-600 mb-6">{plan.description}</p>
              <div className="space-y-3 mb-8">
                {allFeatures.map((feature, featureIndex) => (
                  <div key={featureIndex} className="flex items-center gap-3">
                    {plan.features[feature] ? (
                      <Check className="w-5 h-5 text-green-500 flex-shrink-0" />
                    ) : (
                      <X className="w-5 h-5 text-gray-300 flex-shrink-0" />
                    )}
                    <span className={plan.features[feature] ? 'text-gray-900' : 'text-gray-400'}>
                      {feature}
                    </span>
                  </div>
                ))}
              </div>
              <button className={`w-full py-3 rounded-lg bg-gradient-to-r ${plan.color} text-white hover:opacity-90 transition-opacity`}>
                시작하기
              </button>
            </div>
          ))}
        </div>

        {/* Table View for Desktop */}
        <div className="hidden lg:block overflow-x-auto">
          <table className="w-full border-collapse">
            <thead>
              <tr>
                <th className="p-4 text-left border-b-2 border-gray-200">
                  <span className="text-gray-900">기능</span>
                </th>
                {plans.map((plan, index) => (
                  <th key={index} className="p-4 border-b-2 border-gray-200">
                    <div className="flex flex-col items-center">
                      {plan.popular && (
                        <span className="px-3 py-1 bg-gradient-to-r from-green-500 to-emerald-500 text-white rounded-full text-sm mb-2">
                          인기
                        </span>
                      )}
                      <div className={`px-4 py-2 rounded-lg bg-gradient-to-r ${plan.color} text-white mb-2`}>
                        {plan.name}
                      </div>
                      <div className="mb-2">
                        <span className="text-3xl text-gray-900">₩{plan.price}</span>
                        <span className="text-gray-600">/월</span>
                      </div>
                      <p className="text-sm text-gray-600 text-center">{plan.description}</p>
                      <button className={`mt-4 px-6 py-2 rounded-lg bg-gradient-to-r ${plan.color} text-white hover:opacity-90 transition-opacity`}>
                        시작하기
                      </button>
                    </div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {allFeatures.map((feature, index) => (
                <tr key={index} className="hover:bg-gray-50">
                  <td className="p-4 border-b border-gray-200 text-gray-900">
                    {feature}
                  </td>
                  {plans.map((plan, planIndex) => (
                    <td key={planIndex} className="p-4 border-b border-gray-200 text-center">
                      {plan.features[feature] ? (
                        <Check className="w-6 h-6 text-green-500 mx-auto" />
                      ) : (
                        <X className="w-6 h-6 text-gray-300 mx-auto" />
                      )}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="mt-12 text-center">
          <p className="text-gray-600">
            모든 플랜은 <span className="text-green-600">14일 무료 체험</span>이 가능합니다. 신용카드 등록 없이 시작하세요.
          </p>
        </div>
      </div>
    </section>
  );
}
