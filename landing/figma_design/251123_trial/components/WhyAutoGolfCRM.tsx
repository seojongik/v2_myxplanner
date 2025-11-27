import { Clock, TrendingUp, Users, Zap, Shield, Target, ChevronRight, X, Sparkles } from 'lucide-react';
import { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';

export function WhyAutoGolfCRM() {
  const [selectedValue, setSelectedValue] = useState<{category: number, valueIndex: number} | null>(null);
  const [hoveredCard, setHoveredCard] = useState<number | null>(null);

  const reasons = [
    {
      title: '매출증대',
      subtitle: '새로운 고객을 만나다',
      icon: TrendingUp,
      color: 'from-green-500 to-emerald-500',
      bgPattern: 'from-green-50 to-emerald-50',
      stat: '+30%',
      statLabel: '평균 매출 증가',
      values: [
        { 
          icon: Target, 
          text: 'AI 기반 타겟 마케팅', 
          shortDescription: '데이터로 신규 고객 유치',
          detailDescription: '고객 데이터를 AI가 분석하여 잠재 고객을 발굴하고, 맞춤형 프로모션을 자동 제안합니다. 주변 골프장 이용객, 시즌별 수요 패턴을 분석하여 신규 고객 유입을 극대화합니다.'
        },
        { 
          icon: TrendingUp, 
          text: '재방문율 30% 증가', 
          shortDescription: '고객 이탈 방지 시스템',
          detailDescription: '방문 주기가 늘어난 회원을 자동 감지하여 맞춤형 할인 쿠폰과 이벤트 정보를 발송합니다. 생일, 기념일 등 특별한 날을 기억하여 고객과의 관계를 강화합니다.'
        },
        { 
          icon: Users, 
          text: '회원권 판매 자동화', 
          shortDescription: '최적 타이밍 추천',
          detailDescription: '단기 이용 고객의 패턴을 분석하여 회원권 구매가 유리한 시점을 자동 계산하고 제안합니다. 회원권 만료 예정 고객에게 갱신 혜택을 적시에 안내합니다.'
        }
      ]
    },
    {
      title: '고객관계관리',
      subtitle: '정말로 중요한 것에 집중하세요',
      icon: Users,
      color: 'from-blue-500 to-cyan-500',
      bgPattern: 'from-blue-50 to-cyan-50',
      stat: '90%',
      statLabel: '업무 자동화',
      values: [
        { 
          icon: Zap, 
          text: '반복 업무 90% 자동화', 
          shortDescription: '핵심 업무에만 집중',
          detailDescription: '예약 확인, 리마인더 발송, 회원권 차감, 결제 처리 등 반복적인 업무를 자동화합니다. 직원들은 고객 응대와 서비스 품질 향상에만 집중할 수 있습니다.'
        },
        { 
          icon: Shield, 
          text: '개인화된 고객 관리', 
          shortDescription: 'VIP 고객 특별 관리',
          detailDescription: '고객별 선호 타석, 방문 시간대, 이용 패턴을 자동 기록하여 맞춤형 서비스를 제공합니다. 우수 고객을 자동 식별하여 특별 혜택과 우선 예약권을 제공합니다.'
        },
        { 
          icon: Users, 
          text: '통합 커뮤니케이션', 
          shortDescription: '모든 채널 한 곳에서',
          detailDescription: 'SMS, 카카오톡, 이메일, 앱 푸시 등 모든 커뮤니케이션 채널을 하나의 대시보드에서 관리합니다. 고객 문의 내역이 자동 저장되어 언제든 확인 가능합니다.'
        }
      ]
    },
    {
      title: '비용최적화',
      subtitle: '고객만족과 비용절감을 동시에',
      icon: Clock,
      color: 'from-purple-500 to-pink-500',
      bgPattern: 'from-purple-50 to-pink-50',
      stat: '50%',
      statLabel: '비용 절감',
      values: [
        { 
          icon: Clock, 
          text: '인건비 절감', 
          shortDescription: '적은 인원으로 효율 운영',
          detailDescription: '자동화된 예약 관리와 회원 관리로 추가 인력 고용 없이 업무를 처리할 수 있습니다. 평균적으로 직원 1명분의 인건비를 절감하며, 연간 최대 3,600만원의 비용 절감 효과가 있습니다.'
        },
        { 
          icon: Target, 
          text: '마케팅 비용 50% 절감', 
          shortDescription: '정확한 타겟팅으로',
          detailDescription: '무분별한 광고 대신 데이터 기반 타겟 마케팅으로 효율을 극대화합니다. 반응률이 높은 고객층만 선별하여 메시지를 발송하므로 마케팅 비용이 절반으로 감소합니다.'
        },
        { 
          icon: Shield, 
          text: '타석 가동률 최적화', 
          shortDescription: '유휴시간 최소화',
          detailDescription: '시간대별 예약 데이터를 분석하여 비수기 시간대 특별 프로모션을 자동 제안합니다. 타석 가동률을 최대 25% 향상시켜 동일한 시설로 더 많은 매출을 창출합니다.'
        }
      ]
    }
  ];

  return (
    <section id="why" className="py-32 px-4 bg-gradient-to-br from-gray-50 via-white to-gray-50 relative overflow-hidden">
      {/* Background Decorative Elements */}
      <div className="absolute top-0 left-0 w-96 h-96 bg-green-200 rounded-full blur-3xl opacity-20 -translate-x-1/2 -translate-y-1/2"></div>
      <div className="absolute bottom-0 right-0 w-96 h-96 bg-blue-200 rounded-full blur-3xl opacity-20 translate-x-1/2 translate-y-1/2"></div>
      
      <div className="container mx-auto relative z-10">
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center mb-20"
        >
          <div className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-full mb-6">
            <Sparkles className="w-4 h-4" />
            <span className="text-sm">가장 중요한 선택</span>
          </div>
          <h2 className="text-gray-900 mb-6 text-5xl md:text-6xl">Why AutoGolfCRM?</h2>
          <p className="text-xl text-gray-600 max-w-3xl mx-auto">
            골프연습장 운영의 모든 것을 하나의 플랫폼으로 해결하세요<br/>
            3가지 핵심 가치로 비즈니스를 성장시킵니다
          </p>
        </motion.div>

        <div className="grid lg:grid-cols-3 gap-8 mb-16">
          {reasons.map((reason, index) => (
            <motion.div
              key={index}
              initial={{ opacity: 0, y: 40 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: index * 0.2 }}
              onHoverStart={() => setHoveredCard(index)}
              onHoverEnd={() => setHoveredCard(null)}
              className="group relative"
            >
              <div className={`absolute inset-0 bg-gradient-to-br ${reason.color} rounded-3xl opacity-0 group-hover:opacity-10 blur-xl transition-all duration-500`}></div>
              
              <div className="relative bg-white rounded-3xl p-8 shadow-lg hover:shadow-2xl transition-all duration-500 border-2 border-gray-100 hover:border-transparent overflow-hidden">
                {/* Gradient Background on Hover */}
                <div className={`absolute inset-0 bg-gradient-to-br ${reason.bgPattern} opacity-0 group-hover:opacity-100 transition-opacity duration-500`}></div>
                
                <div className="relative z-10">
                  {/* Icon & Badge */}
                  <div className="flex items-start justify-between mb-6">
                    <motion.div 
                      animate={{ 
                        scale: hoveredCard === index ? 1.1 : 1,
                        rotate: hoveredCard === index ? 5 : 0
                      }}
                      transition={{ duration: 0.3 }}
                      className={`w-20 h-20 rounded-2xl bg-gradient-to-br ${reason.color} flex items-center justify-center shadow-lg`}
                    >
                      <reason.icon className="w-10 h-10 text-white" />
                    </motion.div>
                    <div className="text-right">
                      <div className={`text-4xl bg-gradient-to-r ${reason.color} bg-clip-text text-transparent`}>
                        {reason.stat}
                      </div>
                      <div className="text-sm text-gray-600 mt-1">{reason.statLabel}</div>
                    </div>
                  </div>

                  {/* Title & Subtitle */}
                  <h3 className="text-gray-900 mb-3 text-2xl">{reason.title}</h3>
                  <p className="text-lg text-gray-600 mb-8 leading-relaxed">{reason.subtitle}</p>

                  {/* Values List */}
                  <div className="space-y-3">
                    {reason.values.map((value, valueIndex) => (
                      <motion.button
                        key={valueIndex}
                        onClick={() => setSelectedValue({ category: index, valueIndex })}
                        whileHover={{ scale: 1.02, x: 4 }}
                        whileTap={{ scale: 0.98 }}
                        className="w-full flex items-center justify-between p-5 rounded-xl bg-white border-2 border-gray-200 hover:border-gray-300 hover:shadow-md transition-all group/item relative overflow-hidden"
                      >
                        <div className={`absolute inset-0 bg-gradient-to-r ${reason.color} opacity-0 group-hover/item:opacity-5 transition-opacity`}></div>
                        
                        <div className="flex items-center gap-4 relative z-10">
                          <div className={`w-10 h-10 rounded-lg bg-gradient-to-br ${reason.color} flex items-center justify-center flex-shrink-0 shadow-sm`}>
                            <value.icon className="w-5 h-5 text-white" />
                          </div>
                          <div className="text-left">
                            <p className="text-gray-900">{value.text}</p>
                            <p className="text-sm text-gray-500 mt-1">{value.shortDescription}</p>
                          </div>
                        </div>
                        <ChevronRight className="w-5 h-5 text-gray-400 group-hover/item:text-gray-600 group-hover/item:translate-x-1 transition-all relative z-10 flex-shrink-0" />
                      </motion.button>
                    ))}
                  </div>
                </div>
              </div>
            </motion.div>
          ))}
        </div>

        {/* CTA Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.4 }}
          className="text-center"
        >
          <div className="inline-block bg-white rounded-2xl p-8 shadow-xl border-2 border-gray-100">
            <p className="text-xl text-gray-700 mb-4">
              지금 바로 <span className="bg-gradient-to-r from-green-500 to-blue-600 bg-clip-text text-transparent">무료 체험</span>으로 경험해보세요
            </p>
            <button
              onClick={() => {
                const element = document.getElementById('pricing');
                if (element) {
                  element.scrollIntoView({ behavior: 'smooth' });
                }
              }}
              className="px-8 py-4 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-xl hover:shadow-2xl hover:scale-105 transition-all duration-300 text-lg"
            >
              14일 무료 체험 시작하기
            </button>
          </div>
        </motion.div>

        {/* Detail Modal */}
        <AnimatePresence>
          {selectedValue !== null && (
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 bg-black bg-opacity-60 backdrop-blur-sm flex items-center justify-center p-4 z-50"
              onClick={() => setSelectedValue(null)}
            >
              <motion.div 
                initial={{ scale: 0.9, opacity: 0, y: 20 }}
                animate={{ scale: 1, opacity: 1, y: 0 }}
                exit={{ scale: 0.9, opacity: 0, y: 20 }}
                transition={{ type: "spring", duration: 0.5 }}
                className="bg-white rounded-3xl p-10 max-w-3xl w-full shadow-2xl relative"
                onClick={(e) => e.stopPropagation()}
              >
                <button
                  onClick={() => setSelectedValue(null)}
                  className="absolute top-6 right-6 w-10 h-10 rounded-full bg-gray-100 hover:bg-gray-200 flex items-center justify-center transition-colors"
                >
                  <X className="w-5 h-5 text-gray-600" />
                </button>

                <div className="flex items-start gap-6 mb-8">
                  <div className={`w-20 h-20 rounded-2xl bg-gradient-to-br ${reasons[selectedValue.category].color} flex items-center justify-center flex-shrink-0 shadow-lg`}>
                    {(() => {
                      const Icon = reasons[selectedValue.category].values[selectedValue.valueIndex].icon;
                      return <Icon className="w-10 h-10 text-white" />;
                    })()}
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-3">
                      <span className={`px-4 py-1.5 rounded-full bg-gradient-to-r ${reasons[selectedValue.category].color} text-white`}>
                        {reasons[selectedValue.category].title}
                      </span>
                    </div>
                    <h3 className="text-gray-900 mb-2 text-3xl">
                      {reasons[selectedValue.category].values[selectedValue.valueIndex].text}
                    </h3>
                    <p className="text-lg text-gray-600">
                      {reasons[selectedValue.category].values[selectedValue.valueIndex].shortDescription}
                    </p>
                  </div>
                </div>
                
                <div className="bg-gray-50 rounded-2xl p-6 mb-8">
                  <p className="text-gray-700 leading-relaxed text-lg">
                    {reasons[selectedValue.category].values[selectedValue.valueIndex].detailDescription}
                  </p>
                </div>

                <div className="flex justify-end gap-4">
                  <button
                    onClick={() => setSelectedValue(null)}
                    className="px-6 py-3 border-2 border-gray-300 text-gray-700 rounded-xl hover:bg-gray-50 transition-colors"
                  >
                    닫기
                  </button>
                  <button
                    onClick={() => {
                      setSelectedValue(null);
                      const element = document.getElementById('pricing');
                      if (element) {
                        element.scrollIntoView({ behavior: 'smooth' });
                      }
                    }}
                    className={`px-6 py-3 bg-gradient-to-r ${reasons[selectedValue.category].color} text-white rounded-xl hover:shadow-lg hover:scale-105 transition-all`}
                  >
                    지금 시작하기
                  </button>
                </div>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </section>
  );
}
