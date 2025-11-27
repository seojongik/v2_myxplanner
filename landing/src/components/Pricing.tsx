import { Check, X, HelpCircle } from 'lucide-react';
import { useState, Fragment, useEffect } from 'react';
import { FeatureModal } from './FeatureModal';
import { PaymentDialog } from './PaymentDialog';

interface FeatureDetail {
  title: string;
  description: string;
  image: string;
  benefits: string[];
}

interface PricingProps {
  onLoginClick: () => void;
  onRegisterClick: () => void;
}

export function Pricing({ onLoginClick, onRegisterClick }: PricingProps) {
  const [selectedFeature, setSelectedFeature] = useState<FeatureDetail | null>(null);
  const [paymentDialogOpen, setPaymentDialogOpen] = useState(false);
  const [selectedPlan, setSelectedPlan] = useState<{ name: string; monthlyPrice: number } | null>(null);
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [showAuthChoiceModal, setShowAuthChoiceModal] = useState(false);

  useEffect(() => {
    // 로그인 상태 확인
    const checkLoginStatus = () => {
      const currentUser = localStorage.getItem('currentUser');
      const currentBranch = localStorage.getItem('currentBranch');
      setIsLoggedIn(!!(currentUser && currentBranch));
    };

    checkLoginStatus();

    // 로그인 상태 변경 이벤트 리스너
    const handleLoginStatusChange = () => {
      checkLoginStatus();
    };

    window.addEventListener('loginStatusChanged', handleLoginStatusChange);

    return () => {
      window.removeEventListener('loginStatusChanged', handleLoginStatusChange);
    };
  }, []);

  const featureDetails: Record<string, FeatureDetail> = {
    '타석 + 레슨 통합 예약 시스템': {
      title: '타석 + 레슨 통합 예약 시스템',
      description: '타석 예약과 레슨 예약을 하나의 시스템에서 통합 관리합니다. 고객은 원하는 시간대에 타석과 레슨을 동시에 예약할 수 있으며, 실시간으로 예약 현황을 확인할 수 있습니다.',
      image: 'https://images.unsplash.com/photo-1587174486073-ae5e5cff23aa?w=800&auto=format&fit=crop',
      benefits: [
        '타석과 레슨 예약을 한 곳에서 관리',
        '실시간 예약 현황 확인',
        '중복 예약 방지 자동화',
        '모바일/PC 모두 지원'
      ]
    },
    '온라인 회원권 판매': {
      title: '온라인 회원권 판매',
      description: '24시간 언제든지 온라인으로 회원권을 판매할 수 있습니다. 다양한 회원권 옵션을 설정하고, 자동 결제 시스템으로 편리하게 관리하세요.',
      image: 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=800&auto=format&fit=crop',
      benefits: [
        '24/7 온라인 판매 자동화',
        '다양한 회원권 옵션 설정',
        '자동 결제 및 갱신',
        '회원권 사용 내역 추적'
      ]
    },
    '1:1 채팅 기능': {
      title: '1:1 채팅 기능',
      description: '고객과 실시간으로 소통할 수 있는 1:1 채팅 기능입니다. 문의사항에 즉시 답변하고, 고객 만족도를 높일 수 있습니다.',
      image: 'https://images.unsplash.com/photo-1577563908411-5077b6dc7624?w=800&auto=format&fit=crop',
      benefits: [
        '실시간 고객 응대',
        '문의 내역 자동 저장',
        '모바일 알림 지원',
        '파일 및 이미지 전송'
      ]
    },
    '고객 Activity 기반 자동 메시지': {
      title: '고객 Activity 기반 자동 메시지',
      description: '고객의 활동 패턴을 분석하여 맞춤형 메시지를 자동으로 발송합니다. 장기 미방문 고객, 생일 축하, 레슨 리마인더 등 다양한 시나리오를 설정할 수 있습니다.',
      image: 'https://images.unsplash.com/photo-1596526131083-e8c633c948d2?w=800&auto=format&fit=crop',
      benefits: [
        '고객 행동 패턴 자동 분석',
        '맞춤형 메시지 자동 발송',
        '재방문율 향상',
        '고객 이탈 방지'
      ]
    },
    '대량 마케팅/공지 메시지': {
      title: '대량 마케팅/공지 메시지',
      description: '모든 회원에게 한 번에 마케팅 메시지나 공지사항을 전송할 수 있습니다. 타겟팅 옵션으로 특정 그룹만 선택하여 발송도 가능합니다.',
      image: 'https://images.unsplash.com/photo-1563986768609-322da13575f3?w=800&auto=format&fit=crop',
      benefits: [
        '전체/그룹별 메시지 발송',
        '예약 발송 기능',
        '발송 결과 분석',
        'SMS/카카오톡 지원'
      ]
    },
    '예약기반 타석 제어 (전기료 최적화)': {
      title: '예약기반 타석 제어 (전기료 최적화)',
      description: '예약 상황에 따라 타석을 자동으로 제어하여 불필요한 전기 사용을 줄입니다. 예약이 없는 시간대의 타석은 자동으로 전원을 차단하여 전기료를 절감합니다.',
      image: 'https://images.unsplash.com/photo-1473341304170-971dccb5ac1e?w=800&auto=format&fit=crop',
      benefits: [
        '예약 기반 자동 전원 제어',
        '전기료 최대 30% 절감',
        '원격 타석 제어',
        '실시간 전력 사용량 모니터링'
      ]
    },
    '기본 통계 및 리포트': {
      title: '기본 통계 및 리포트',
      description: '일일/주간/월간 매출, 예약 현황, 회원 통계 등 기본적인 운영 데이터를 한눈에 확인할 수 있습니다.',
      image: 'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&auto=format&fit=crop',
      benefits: [
        '매출 통계 실시간 확인',
        '예약률 분석',
        '회원 증가 추이',
        'PDF 리포트 다운로드'
      ]
    },
    '자유시간 예약제': {
      title: '자유시간 예약제',
      description: '30분, 60분, 90분, 120분 등 다양한 시간대 옵션을 제공하여 고객의 선택폭을 넓힙니다. 짧은 시간 연습을 원하는 직장인부터 장시간 연습을 원하는 마니아까지 모두 만족시킬 수 있습니다.',
      image: 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=800&auto=format&fit=crop',
      benefits: [
        '유연한 시간 옵션 제공',
        '고객 선택권 확대',
        '타석 회전율 향상',
        '매출 증대 효과'
      ]
    },
    '유연한 이용권 판매': {
      title: '유연한 이용권 판매',
      description: '10회권, 20회권, 무제한 이용권 등 다양한 형태의 이용권을 생성하고 판매할 수 있습니다. 시간대별, 요일별로 다른 가격 정책도 설정 가능합니다.',
      image: 'https://images.unsplash.com/photo-1554224311-beee460201e1?w=800&auto=format&fit=crop',
      benefits: [
        '다양한 이용권 상품 생성',
        '시간대/요일별 차등 가격',
        '자동 만료 관리',
        '이용권 양도 관리'
      ]
    },
    '예약기반 원클릭 급여계산': {
      title: '예약기반 원클릭 급여계산',
      description: '레슨 예약 데이터를 기반으로 강사 급여를 자동으로 계산합니다. 레슨 횟수, 시간, 수강생 수 등을 반영하여 정확한 급여를 산출합니다.',
      image: 'https://images.unsplash.com/photo-1554224154-26032ffc0d07?w=800&auto=format&fit=crop',
      benefits: [
        '급여 자동 계산',
        '엑셀 다운로드 지원',
        '급여 명세서 자동 생성',
        '계산 오류 제로'
      ]
    },
    '회계관리 및 세무신고 지원': {
      title: '회계관리 및 세무신고 지원',
      description: '매출/비용 자동 집계, 부가세 신고 자료 생성, 세무사 연동 등 회계 업무를 간소화합니다.',
      image: 'https://images.unsplash.com/photo-1554224311-beee460201e1?w=800&auto=format&fit=crop',
      benefits: [
        '매출/비용 자동 집계',
        '부가세 신고 자료 생성',
        '세무사 시스템 연동',
        '전자세금계산서 발행'
      ]
    },
    '고급 통계 및 분석': {
      title: '고급 통계 및 분석',
      description: '시간대별 예약률, 고객 재방문율, 이탈 고객 분석, 매출 예측 등 심화된 데이터 분석을 제공합니다.',
      image: 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=800&auto=format&fit=crop',
      benefits: [
        '시간대별 수익성 분석',
        '고객 이탈 예측',
        'AI 기반 매출 예측',
        '맞춤형 대시보드'
      ]
    },
    '24/7 전화 응대': {
      title: '24/7 전화 응대',
      description: '전문 상담원이 24시간 365일 고객 전화를 대신 받아드립니다. 영업시간 외에도 고객 문의를 놓치지 않습니다.',
      image: 'https://images.unsplash.com/photo-1423666639041-f56000c27a9a?w=800&auto=format&fit=crop',
      benefits: [
        '24시간 전화 응대',
        '전문 상담원 배치',
        '통화 내역 자동 기록',
        '긴급 상황 즉시 전달'
      ]
    },
    '예약 및 문의 처리': {
      title: '예약 및 문의 처리',
      description: '상담원이 고객의 예약 요청과 문의사항을 직접 처리합니다. 시스템에 자동으로 예약을 등록하고, 문의 내용을 기록합니다.',
      image: 'https://images.unsplash.com/photo-1486312338219-ce68d2c6f44d?w=800&auto=format&fit=crop',
      benefits: [
        '전화 예약 대행',
        '문의사항 처리',
        '예약 변경/취소 처리',
        '시스템 자동 연동'
      ]
    },
    '결제 지원': {
      title: '결제 지원',
      description: '상담원이 전화로 결제 안내 및 처리를 도와드립니다. 회원권 구매, 이용권 충전 등을 전화로 편리하게 처리할 수 있습니다.',
      image: 'https://images.unsplash.com/photo-1563013544-824ae1b704d3?w=800&auto=format&fit=crop',
      benefits: [
        '전화 결제 안내',
        '결제 오류 해결',
        '환불 처리 지원',
        '결제 확인서 발송'
      ]
    },
    '긴급 상황 대응': {
      title: '긴급 상황 대응',
      description: '시설 고장, 고객 민원 등 긴급 상황 발생 시 즉시 연락을 받고 대응합니다. 관리자에게 즉시 전달하여 신속한 처리가 가능합니다.',
      image: 'https://images.unsplash.com/photo-1584438784894-089d6a62b8fa?w=800&auto=format&fit=crop',
      benefits: [
        '긴급 상황 즉시 대응',
        '관리자 즉시 연락',
        '대응 매뉴얼 숙지',
        '사후 처리 확인'
      ]
    },
    '방문 상담 예약 조율': {
      title: '방문 상담 예약 조율',
      description: '신규 고객의 시설 방문 상담을 상담원이 일정 조율하여 예약합니다. 관리자의 스케줄을 확인하고 최적의 시간을 안내합니다.',
      image: 'https://images.unsplash.com/photo-1552581234-26160f608093?w=800&auto=format&fit=crop',
      benefits: [
        '방문 상담 일정 조율',
        '관리자 스케줄 확인',
        '사전 안내 메시지 발송',
        '노쇼 방지 리마인더'
      ]
    }
  };
  const plans = [
    {
      name: 'Basic',
      price: '무료',
      priceUnit: '',
      monthlyPrice: 0, // 무료
      description: '기본 기능으로 시작하기',
      color: 'from-blue-500 to-cyan-500',
      features: {
        '타석 + 레슨 통합 예약 시스템': true,
        '온라인 회원권 판매': true,
        '1:1 채팅 기능': true,
        '고객 Activity 기반 자동 메시지': true,
        '대량 마케팅/공지 메시지': true,
        '예약기반 타석 제어 (전기료 최적화)': true,
        '기본 통계 및 리포트': true,
        '자유시간 예약제': false,
        '유연한 이용권 판매': false,
        '예약기반 원클릭 급여계산': false,
        '회계관리 및 세무신고 지원': false,
        '고급 통계 및 분석': false,
        '24/7 전화 응대': false,
        '예약 및 문의 처리': false,
        '결제 지원': false,
        '긴급 상황 대응': false,
        '방문 상담 예약 조율': false
      }
    },
    {
      name: 'Pro',
      price: '타석당 월 3,900원',
      priceUnit: '',
      monthlyPrice: 3900, // 타석당 월 3,900원
      description: '고객 확장 및 운영 자동화',
      color: 'from-green-500 to-emerald-500',
      features: {
        '타석 + 레슨 통합 예약 시스템': true,
        '온라인 회원권 판매': true,
        '1:1 채팅 기능': true,
        '고객 Activity 기반 자동 메시지': true,
        '대량 마케팅/공지 메시지': true,
        '예약기반 타석 제어 (전기료 최적화)': true,
        '기본 통계 및 리포트': true,
        '자유시간 예약제': true,
        '유연한 이용권 판매': true,
        '예약기반 원클릭 급여계산': true,
        '회계관리 및 세무신고 지원': true,
        '고급 통계 및 분석': true,
        '24/7 전화 응대': false,
        '예약 및 문의 처리': false,
        '결제 지원': false,
        '긴급 상황 대응': false,
        '방문 상담 예약 조율': false
      }
    },
    {
      name: 'FullAuto',
      price: '타석당 월 39,000원',
      priceUnit: '',
      monthlyPrice: 39000, // 타석당 월 39,000원
      description: '전문상담원 통합 콜센터 포함',
      color: 'from-purple-500 to-pink-500',
      features: {
        '타석 + 레슨 통합 예약 시스템': true,
        '온라인 회원권 판매': true,
        '1:1 채팅 기능': true,
        '고객 Activity 기반 자동 메시지': true,
        '대량 마케팅/공지 메시지': true,
        '예약기반 타석 제어 (전기료 최적화)': true,
        '기본 통계 및 리포트': true,
        '자유시간 예약제': true,
        '유연한 이용권 판매': true,
        '예약기반 원클릭 급여계산': true,
        '회계관리 및 세무신고 지원': true,
        '고급 통계 및 분석': true,
        '24/7 전화 응대': true,
        '예약 및 문의 처리': true,
        '결제 지원': true,
        '긴급 상황 대응': true,
        '방문 상담 예약 조율': true
      }
    }
  ];

  const featureGroups = [
    {
      title: '기본 기능',
      features: [
        '타석 + 레슨 통합 예약 시스템',
        '온라인 회원권 판매',
        '1:1 채팅 기능',
        '고객 Activity 기반 자동 메시지',
        '대량 마케팅/공지 메시지',
        '예약기반 타석 제어 (전기료 최적화)',
        '기본 통계 및 리포트'
      ]
    },
    {
      title: '새로운 고객 확장 솔루션',
      features: [
        '자유시간 예약제',
        '유연한 이용권 판매'
      ]
    },
    {
      title: '운영 자동화 솔루션',
      features: [
        '예약기반 원클릭 급여계산',
        '회계관리 및 세무신고 지원',
        '고급 통계 및 분석'
      ]
    },
    {
      title: '전문상담원 상주 통합 콜센터',
      features: [
        '24/7 전화 응대',
        '예약 및 문의 처리',
        '결제 지원',
        '긴급 상황 대응',
        '방문 상담 예약 조율'
      ]
    }
  ];


  const handleStartClick = (plan: typeof plans[0]) => {
    // 로그인 상태 확인
    if (isLoggedIn) {
      // 로그인 상태: 결제창으로 이동
      if (plan.monthlyPrice === 0) {
        // Basic 플랜은 무료
        alert('Basic 플랜은 무료로 이용 중입니다.');
        return;
      }
      setSelectedPlan({ name: plan.name, monthlyPrice: plan.monthlyPrice });
      setPaymentDialogOpen(true);
    } else {
      // 비로그인 상태: 로그인/회원가입 선택 모달 표시
      setShowAuthChoiceModal(true);
    }
  };

  const handleLoginChoice = () => {
    setShowAuthChoiceModal(false);
    onLoginClick();
  };

  const handleRegisterChoice = () => {
    setShowAuthChoiceModal(false);
    onRegisterClick();
  };

  return (
    <section id="pricing" className="py-20 px-3 md:px-4 bg-white">
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
              className="relative bg-white border-2 rounded-2xl p-8 border-gray-200"
            >
              <div className={`inline-block px-4 py-2 rounded-lg bg-gradient-to-r ${plan.color} text-white mb-4`}>
                {plan.name}
              </div>
              <div className="mb-4">
                <span className="text-2xl text-gray-900">{plan.price}</span>
              </div>
              <p className="text-gray-600 mb-6">{plan.description}</p>
              <div className="space-y-4 mb-8">
                {featureGroups.map((group, groupIndex) => (
                  <div key={groupIndex}>
                    <h4 className="text-sm font-semibold text-gray-900 mb-2">{group.title}</h4>
                    <div className="space-y-2">
                      {group.features.map((feature, featureIndex) => (
                        <div key={featureIndex} className="flex items-center gap-2">
                          {(plan.features as Record<string, boolean>)[feature] ? (
                            <Check className="w-5 h-5 text-green-500 flex-shrink-0" />
                          ) : (
                            <X className="w-5 h-5 text-gray-300 flex-shrink-0" />
                          )}
                          <span className={(plan.features as Record<string, boolean>)[feature] ? 'text-gray-900 text-sm flex-1' : 'text-gray-400 text-sm flex-1'}>
                            {feature}
                          </span>
                          {featureDetails[feature] && (
                            <button
                              onClick={() => setSelectedFeature(featureDetails[feature])}
                              className="p-1 hover:bg-gray-100 rounded-full transition-colors flex-shrink-0"
                              aria-label={`${feature} 상세 정보`}
                            >
                              <HelpCircle className="w-4 h-4 text-gray-400 hover:text-gray-600" />
                            </button>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
              <button
                onClick={() => handleStartClick(plan)}
                className={`w-full py-3 rounded-lg bg-gradient-to-r ${plan.color} text-white hover:opacity-90 transition-opacity`}
              >
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
                      <div className={`px-4 py-2 rounded-lg bg-gradient-to-r ${plan.color} text-white mb-2`}>
                        {plan.name}
                      </div>
                      <div className="mb-2">
                        <span className="text-xl text-gray-900">{plan.price}</span>
                      </div>
                      <p className="text-sm text-gray-600 text-center">{plan.description}</p>
                      <button
                        onClick={() => handleStartClick(plan)}
                        className={`mt-4 px-6 py-2 rounded-lg bg-gradient-to-r ${plan.color} text-white hover:opacity-90 transition-opacity`}
                      >
                        시작하기
                      </button>
                    </div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {featureGroups.map((group, groupIndex) => (
                <Fragment key={`group-${groupIndex}`}>
                  <tr className="bg-gray-50">
                    <td colSpan={4} className="p-3 border-b border-gray-300">
                      <span className="font-semibold text-gray-900">{group.title}</span>
                    </td>
                  </tr>
                  {group.features.map((feature, featureIndex) => (
                    <tr key={`${groupIndex}-${featureIndex}`} className="hover:bg-gray-50">
                      <td className="p-4 border-b border-gray-200 text-gray-700 pl-8">
                        <div className="flex items-center gap-2">
                          <span className="flex-1">{feature}</span>
                          {featureDetails[feature] && (
                            <button
                              onClick={() => setSelectedFeature(featureDetails[feature])}
                              className="p-1 hover:bg-gray-100 rounded-full transition-colors"
                              aria-label={`${feature} 상세 정보`}
                            >
                              <HelpCircle className="w-4 h-4 text-gray-400 hover:text-gray-600" />
                            </button>
                          )}
                        </div>
                      </td>
                      {plans.map((plan, planIndex) => (
                        <td key={planIndex} className="p-4 border-b border-gray-200 text-center">
                          {(plan.features as Record<string, boolean>)[feature] ? (
                            <Check className="w-6 h-6 text-green-500 mx-auto" />
                          ) : (
                            <X className="w-6 h-6 text-gray-300 mx-auto" />
                          )}
                        </td>
                      ))}
                    </tr>
                  ))}
                </Fragment>
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

      <FeatureModal feature={selectedFeature} onClose={() => setSelectedFeature(null)} />

      {selectedPlan && (
        <PaymentDialog
          isOpen={paymentDialogOpen}
          onClose={() => {
            setPaymentDialogOpen(false);
            setSelectedPlan(null);
          }}
          planName={selectedPlan.name}
          monthlyPrice={selectedPlan.monthlyPrice}
        />
      )}

      {/* 로그인/회원가입 선택 모달 */}
      {showAuthChoiceModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-8 shadow-2xl">
            <h3 className="text-2xl font-bold text-gray-900 mb-4 text-center">
              계정이 필요합니다
            </h3>
            <p className="text-gray-600 mb-8 text-center">
              플랜을 시작하려면 로그인하거나 새 계정을 만들어주세요.
            </p>
            <div className="space-y-3">
              <button
                onClick={handleLoginChoice}
                className="w-full py-3 bg-gradient-to-r from-blue-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity font-medium"
              >
                로그인하기
              </button>
              <button
                onClick={handleRegisterChoice}
                className="w-full py-3 bg-gradient-to-r from-green-500 to-emerald-600 text-white rounded-lg hover:opacity-90 transition-opacity font-medium"
              >
                회원가입 (데모체험)
              </button>
              <button
                onClick={() => setShowAuthChoiceModal(false)}
                className="w-full py-3 border-2 border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors font-medium"
              >
                취소
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
