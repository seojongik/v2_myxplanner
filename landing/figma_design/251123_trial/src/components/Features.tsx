import { useState } from 'react';
import { Calendar, Users, MessageSquare, BarChart3, Settings } from 'lucide-react';

export function Features() {
  const [activeCategory, setActiveCategory] = useState(0);

  const categories = [
    {
      title: '예약 관리',
      icon: Calendar,
      color: 'from-blue-500 to-cyan-500',
      features: [
        { name: '실시간 타석 예약 현황', description: '모든 타석의 예약 상태를 한눈에 확인' },
        { name: '자동 예약 확인 알림', description: 'SMS/카카오톡 자동 발송' },
        { name: '노쇼 방지 시스템', description: '예약 리마인더 및 패널티 관리' },
        { name: '대기자 자동 관리', description: '취소 시 자동 연락' },
        { name: '예약 통계 분석', description: '시간대별 예약 패턴 분석' }
      ]
    },
    {
      title: '회원 관리',
      icon: Users,
      color: 'from-green-500 to-emerald-500',
      features: [
        { name: '통합 회원 데이터베이스', description: '상세한 회원 프로필 관리' },
        { name: '자동 등급 관리', description: '방문 횟수별 등급 자동 부여' },
        { name: '회원권 관리', description: '기간권/횟수권 자동 차감' },
        { name: '생일 자동 축하', description: '특별 할인 쿠폰 자동 발송' },
        { name: '이탈 회원 분석', description: 'AI 기반 재방문 유도' }
      ]
    },
    {
      title: '마케팅',
      icon: MessageSquare,
      color: 'from-purple-500 to-pink-500',
      features: [
        { name: '타겟 메시지 발송', description: '회원 그룹별 맞춤 메시지' },
        { name: '자동 캠페인 실행', description: '날씨, 시간대 기반 자동 프로모션' },
        { name: '쿠폰 관리 시스템', description: '쿠폰 생성 및 사용 내역 관리' },
        { name: 'SNS 연동 관리', description: '인스타그램, 페이스북 통합 관리' },
        { name: '이벤트 성과 분석', description: '마케팅 ROI 측정' }
      ]
    },
    {
      title: '분석 & 리포트',
      icon: BarChart3,
      color: 'from-orange-500 to-red-500',
      features: [
        { name: '실시간 대시보드', description: '오늘의 매출/예약 현황' },
        { name: '매출 분석 리포트', description: '일/주/월별 매출 추이' },
        { name: '회원 행동 분석', description: '방문 패턴 및 선호도 분석' },
        { name: '타석 가동률 분석', description: '최적 운영 시간 추천' },
        { name: '맞춤형 경영 인사이트', description: 'AI 기반 경영 조언' }
      ]
    },
    {
      title: '시스템 설정',
      icon: Settings,
      color: 'from-gray-500 to-slate-600',
      features: [
        { name: '다중 사용자 권한 관리', description: '직원별 접근 권한 설정' },
        { name: '앱 연동 설정', description: '다양한 예약 앱 연동 지원' },
        { name: '결제 시스템 연동', description: 'PG사 자동 연동' },
        { name: '자동 백업 시스템', description: '데이터 안전 보관' },
        { name: '맞춤형 설정', description: '업장 특성에 맞는 설정' }
      ]
    }
  ];

  return (
    <section id="features" className="py-20 px-4 bg-gray-50">
      <div className="container mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-gray-900 mb-4">Features</h2>
          <p className="text-gray-600 max-w-2xl mx-auto">
            골프연습장 운영에 필요한 모든 기능을 하나로
          </p>
        </div>

        <div className="flex flex-wrap justify-center gap-4 mb-12">
          {categories.map((category, index) => (
            <button
              key={index}
              onClick={() => setActiveCategory(index)}
              className={`px-6 py-3 rounded-xl flex items-center gap-2 transition-all ${
                activeCategory === index
                  ? `bg-gradient-to-r ${category.color} text-white shadow-lg`
                  : 'bg-white text-gray-700 hover:bg-gray-100'
              }`}
            >
              <category.icon className="w-5 h-5" />
              {category.title}
            </button>
          ))}
        </div>

        <div className="bg-white rounded-2xl shadow-xl p-8 md:p-12">
          <div className={`inline-flex items-center gap-3 px-6 py-3 rounded-xl bg-gradient-to-r ${categories[activeCategory].color} text-white mb-8`}>
            {(() => {
              const Icon = categories[activeCategory].icon;
              return <Icon className="w-6 h-6" />;
            })()}
            <span className="text-xl">{categories[activeCategory].title}</span>
          </div>

          <div className="grid md:grid-cols-2 gap-6">
            {categories[activeCategory].features.map((feature, index) => (
              <div
                key={index}
                className="p-6 border border-gray-200 rounded-xl hover:border-gray-300 hover:shadow-md transition-all"
              >
                <div className="flex items-start gap-4">
                  <div className="flex-shrink-0 w-8 h-8 rounded-lg bg-gradient-to-br from-gray-100 to-gray-200 flex items-center justify-center">
                    <span className="text-gray-700">{index + 1}</span>
                  </div>
                  <div>
                    <h4 className="text-gray-900 mb-2">{feature.name}</h4>
                    <p className="text-sm text-gray-600">{feature.description}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
