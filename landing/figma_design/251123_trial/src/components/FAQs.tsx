import { useState } from 'react';
import { Search, ChevronDown, ChevronUp } from 'lucide-react';

export function FAQs() {
  const [searchTerm, setSearchTerm] = useState('');
  const [expandedIndex, setExpandedIndex] = useState<number | null>(null);

  const faqs = [
    {
      category: '서비스 일반',
      question: 'AutoGolfCRM은 어떤 서비스인가요?',
      answer: 'AutoGolfCRM은 골프연습장 전용 CRM 솔루션으로, 예약 앱과 연동하여 회원 관리, 예약 관리, 마케팅, 분석 등을 자동화하는 통합 플랫폼입니다.'
    },
    {
      category: '서비스 일반',
      question: '무료 체험 기간은 얼마나 되나요?',
      answer: '모든 플랜에서 14일 무료 체험이 가능합니다. 신용카드 등록 없이 바로 시작하실 수 있으며, 체험 기간 동안 모든 기능을 제한 없이 사용하실 수 있습니다.'
    },
    {
      category: '서비스 일반',
      question: '중도 해지 시 환불이 가능한가요?',
      answer: '네, 가능합니다. 월 단위 결제의 경우 언제든지 해지 가능하며, 잔여 기간에 대해 일할 계산하여 환불해드립니다.'
    },
    {
      category: '연동 및 설치',
      question: '어떤 예약 앱과 연동이 가능한가요?',
      answer: '네이버 예약, 카카오 예약, 다나와 골프 등 주요 예약 플랫폼과 연동 가능합니다. 자체 앱을 사용 중이시라면 API 연동도 지원합니다.'
    },
    {
      category: '연동 및 설치',
      question: '설치가 어렵지 않을까요?',
      answer: '별도의 프로그램 설치가 필요 없는 웹 기반 서비스입니다. 가입 후 5분 이내에 바로 사용 가능하며, 전담 매니저가 초기 설정을 도와드립니다.'
    },
    {
      category: '연동 및 설치',
      question: '기존 회원 데이터를 옮길 수 있나요?',
      answer: '네, 가능합니다. 엑셀 파일 업로드를 통해 기존 회원 데이터를 일괄 등록할 수 있으며, 데이터 마이그레이션을 무료로 지원해드립니다.'
    },
    {
      category: '기능',
      question: 'SMS 발송 비용은 별도인가요?',
      answer: 'Basic 플랜은 월 100건, Pro 플랜은 월 500건, FullAuto 플랜은 무제한으로 포함되어 있습니다. 추가 발송이 필요한 경우 건당 15원에 이용 가능합니다.'
    },
    {
      category: '기능',
      question: '자동 마케팅은 어떻게 작동하나요?',
      answer: 'AI가 회원의 방문 패턴, 이용 내역을 분석하여 최적의 시간에 맞춤형 메시지를 자동 발송합니다. 날씨, 계절 등을 고려한 프로모션도 자동 실행됩니다.'
    },
    {
      category: '기능',
      question: '타석 예약 현황을 실시간으로 볼 수 있나요?',
      answer: '네, 모든 타석의 예약 현황을 실시간으로 확인할 수 있으며, 예약 앱에서 들어온 예약도 즉시 동기화됩니다.'
    },
    {
      category: '보안',
      question: '회원 정보는 안전하게 관리되나요?',
      answer: '개인정보보호법을 준수하며, 금융권 수준의 보안(SSL 암호화, 정기 보안 점검)을 적용하고 있습니다. AWS 서버에 자동 백업되어 데이터 손실 위험이 없습니다.'
    },
    {
      category: '보안',
      question: '직원별로 권한을 다르게 설정할 수 있나요?',
      answer: '네, 가능합니다. 관리자, 매니저, 직원 등 역할별로 접근 권한을 세분화하여 설정할 수 있습니다.'
    },
    {
      category: '요금',
      question: '플랜 업그레이드는 언제든지 가능한가요?',
      answer: '네, 언제든지 상위 플랜으로 업그레이드 가능합니다. 결제일 기준으로 차액만 정산되며, 즉시 업그레이드된 기능을 사용하실 수 있습니다.'
    },
    {
      category: '요금',
      question: '연간 결제 시 할인 혜택이 있나요?',
      answer: '네, 연간 결제 시 월 요금 대비 20% 할인 혜택을 제공합니다. 장기 사용을 계획하신다면 연간 결제를 추천드립니다.'
    },
    {
      category: '지원',
      question: '고객 지원은 어떻게 받을 수 있나요?',
      answer: '이메일, 채팅, 전화를 통해 지원받으실 수 있습니다. Pro 플랜 이상은 우선 지원이 제공되며, FullAuto 플랜은 전담 매니저가 배정됩니다.'
    },
    {
      category: '지원',
      question: '사용 방법 교육을 받을 수 있나요?',
      answer: '온라인 가이드와 동영상 튜토리얼이 제공되며, 필요 시 1:1 화상 교육도 가능합니다. FullAuto 플랜은 방문 교육도 지원합니다.'
    }
  ];

  const filteredFaqs = faqs.filter(
    (faq) =>
      faq.question.toLowerCase().includes(searchTerm.toLowerCase()) ||
      faq.answer.toLowerCase().includes(searchTerm.toLowerCase()) ||
      faq.category.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const categories = Array.from(new Set(faqs.map((faq) => faq.category)));

  return (
    <section id="faqs" className="py-20 px-4 bg-gray-50">
      <div className="container mx-auto max-w-4xl">
        <div className="text-center mb-12">
          <h2 className="text-gray-900 mb-4">FAQs</h2>
          <p className="text-gray-600 mb-8">
            자주 묻는 질문들을 모았습니다
          </p>

          <div className="relative max-w-2xl mx-auto">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              placeholder="궁금한 내용을 검색하세요..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-12 pr-4 py-4 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
            />
          </div>
        </div>

        {categories.map((category) => {
          const categoryFaqs = filteredFaqs.filter((faq) => faq.category === category);
          
          if (categoryFaqs.length === 0) return null;

          return (
            <div key={category} className="mb-8">
              <h3 className="text-gray-900 mb-4 px-4">{category}</h3>
              <div className="space-y-4">
                {categoryFaqs.map((faq, index) => {
                  const globalIndex = faqs.findIndex(
                    (f) => f.question === faq.question && f.category === faq.category
                  );
                  const isExpanded = expandedIndex === globalIndex;

                  return (
                    <div
                      key={globalIndex}
                      className="bg-white border border-gray-200 rounded-xl overflow-hidden hover:shadow-md transition-shadow"
                    >
                      <button
                        onClick={() => setExpandedIndex(isExpanded ? null : globalIndex)}
                        className="w-full px-6 py-4 flex items-center justify-between text-left hover:bg-gray-50 transition-colors"
                      >
                        <span className="text-gray-900 pr-4">{faq.question}</span>
                        {isExpanded ? (
                          <ChevronUp className="w-5 h-5 text-gray-500 flex-shrink-0" />
                        ) : (
                          <ChevronDown className="w-5 h-5 text-gray-500 flex-shrink-0" />
                        )}
                      </button>
                      {isExpanded && (
                        <div className="px-6 pb-4 text-gray-600 border-t border-gray-100 pt-4">
                          {faq.answer}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}

        {filteredFaqs.length === 0 && (
          <div className="text-center py-12">
            <p className="text-gray-500">검색 결과가 없습니다.</p>
          </div>
        )}

        <div className="mt-12 text-center p-8 bg-white rounded-xl border border-gray-200">
          <h3 className="text-gray-900 mb-2">더 궁금한 점이 있으신가요?</h3>
          <p className="text-gray-600 mb-6">
            언제든지 문의해 주세요. 빠르게 답변드리겠습니다.
          </p>
          <div className="flex flex-wrap justify-center gap-4">
            <a
              href="mailto:support@autogolfcrm.com"
              className="px-6 py-3 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity"
            >
              이메일 문의
            </a>
            <a
              href="tel:1588-0000"
              className="px-6 py-3 border-2 border-green-600 text-green-600 rounded-lg hover:bg-green-50 transition-colors"
            >
              전화 문의: 1588-0000
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}
