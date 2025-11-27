import { ChevronRight, ChevronLeft, X, Sparkles, Check, ArrowLeftRight } from 'lucide-react';
import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { revenueGrowthData } from './data/RevenueGrowth';
import { customerRelationshipData } from './data/CustomerRelationship';
import { costOptimizationData } from './data/CostOptimization';
import { Category } from './data/types';

export function WhyAutoGolfCRM() {
  const [selectedCardNews, setSelectedCardNews] = useState<{ category: number, cardNewsIndex: number } | null>(null);
  const [currentSlide, setCurrentSlide] = useState(0);
  const [hoveredCard, setHoveredCard] = useState<number | null>(null);
  const [slideDirection, setSlideDirection] = useState<'left' | 'right'>('right');

  const categories: Category[] = [
    revenueGrowthData,
    customerRelationshipData,
    costOptimizationData
  ];

  const handleOpenCardNews = (categoryIndex: number, cardNewsIndex: number) => {
    setSelectedCardNews({ category: categoryIndex, cardNewsIndex });
    setCurrentSlide(0);
  };

  const handleCloseCardNews = () => {
    setSelectedCardNews(null);
    setCurrentSlide(0);
  };

  const handleNextSlide = () => {
    if (selectedCardNews) {
      const totalSlides = categories[selectedCardNews.category].cardNewsList[selectedCardNews.cardNewsIndex].slides.length;
      if (currentSlide < totalSlides - 1) {
        setSlideDirection('right');
        setCurrentSlide(currentSlide + 1);
      }
    }
  };

  const handlePrevSlide = () => {
    if (currentSlide > 0) {
      setSlideDirection('left');
      setCurrentSlide(currentSlide - 1);
    }
  };

  const slideVariants = {
    enter: (direction: string) => ({
      x: direction === 'right' ? 1000 : -1000,
      opacity: 0
    }),
    center: {
      x: 0,
      opacity: 1
    },
    exit: (direction: string) => ({
      x: direction === 'right' ? -1000 : 1000,
      opacity: 0
    })
  };

  return (
    <section id="why" className="py-32 px-3 md:px-4 bg-gradient-to-br from-gray-50 via-white to-gray-50 relative overflow-hidden">
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
          <h2 className="text-gray-900 mb-6 text-5xl md:text-6xl font-bold">
            Why <span className="bg-gradient-to-r from-green-500 to-blue-600 bg-clip-text text-transparent">AutoGolfCRM</span>?
          </h2>
          <p className="text-xl text-gray-600 max-w-3xl mx-auto">
            골프연습장 운영의 모든 것을 하나의 플랫폼으로 해결하세요<br />
            3가지 핵심 가치로 비즈니스를 성장시킵니다
          </p>
        </motion.div>

        <div className="grid lg:grid-cols-3 gap-4 md:gap-8 mb-16 items-start">
          {categories.map((category, categoryIndex) => (
            <motion.div
              key={categoryIndex}
              initial={{ opacity: 0, y: 40 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: categoryIndex * 0.2 }}
              onHoverStart={() => setHoveredCard(categoryIndex)}
              onHoverEnd={() => setHoveredCard(null)}
              className="group relative h-full"
            >
              <div className={`absolute inset-0 bg-gradient-to-br ${category.color} rounded-3xl opacity-0 group-hover:opacity-10 blur-xl transition-all duration-500`}></div>

              <div className="relative bg-white rounded-3xl p-6 shadow-lg hover:shadow-2xl transition-all duration-500 border-2 border-gray-100 hover:border-transparent overflow-hidden h-[600px] flex flex-col">
                {/* Gradient Background on Hover */}
                <div className={`absolute inset-0 bg-gradient-to-br ${category.bgPattern} opacity-0 group-hover:opacity-100 transition-opacity duration-500`}></div>

                <div className="relative z-10 flex flex-col h-full">
                  {/* Icon, Title & Subtitle */}
                  <div className="flex items-start gap-4 mb-4 flex-shrink-0">
                    <motion.div
                      animate={{
                        scale: hoveredCard === categoryIndex ? 1.1 : 1,
                        rotate: hoveredCard === categoryIndex ? 5 : 0
                      }}
                      transition={{ duration: 0.3 }}
                      className={`w-16 h-16 rounded-2xl bg-gradient-to-br ${category.color} flex items-center justify-center shadow-lg flex-shrink-0`}
                    >
                      <category.icon className="w-8 h-8 text-white" />
                    </motion.div>
                    <div className="flex-1 min-w-0">
                      <h3 className="text-gray-900 mb-1 text-2xl font-bold">
                        <span className={`bg-gradient-to-r ${category.color} bg-clip-text text-transparent`}>
                          {category.title}
                        </span>
                      </h3>
                      <p className="text-base text-gray-900 font-bold leading-relaxed">{category.subtitle}</p>
                    </div>
                  </div>

                  <div className="space-y-2.5">
                    {/* Personas List - 4 slots */}
                    {category.personas && (
                      <div className="flex-shrink-0" style={{ height: 'calc(4 * 76px + 3 * 10px)' }}>
                        <div className="h-full overflow-hidden flex flex-col justify-between">
                          {category.personas.map((persona, personaIndex) => (
                            <div key={personaIndex} className="flex items-center gap-2 text-gray-700">
                              <div className="flex-shrink-0">
                                {persona.checked ? (
                                  <Check className="w-4 h-4 text-green-500" />
                                ) : (
                                  <X className="w-4 h-4 text-red-400" />
                                )}
                              </div>
                              <div className="flex-1 text-sm">
                                {persona.text}
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}

                    {/* Placeholder for future content */}
                    {category.placeholderSlots && category.placeholderSlots > 0 && (
                      <div className="flex-shrink-0" style={{ height: `calc(${category.placeholderSlots} * 76px + ${category.placeholderSlots - 1} * 10px)` }}>
                        {categoryIndex === 2 ? (
                          /* 비용최적화 - Integration Visual */
                          <div className="h-full flex items-center justify-between gap-2">
                            <div className="flex-[3] text-center">
                              <div className="mb-2">
                                <div className="text-sm font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent mb-1">MyGolfPlanner</div>
                                <div className="h-0.5 w-24 mx-auto bg-gradient-to-r from-blue-600 to-cyan-600 rounded-full"></div>
                              </div>
                              <div className="flex flex-nowrap gap-1 justify-center">
                                <span className="text-xs px-2 py-1 bg-gray-100 text-gray-700 rounded font-medium">예약</span>
                                <span className="text-xs px-2 py-1 bg-gray-100 text-gray-700 rounded font-medium">조회</span>
                                <span className="text-xs px-2 py-1 bg-gray-100 text-gray-700 rounded font-medium">구매</span>
                              </div>
                            </div>

                            <div className="flex items-center">
                              <ArrowLeftRight className="w-5 h-5 text-gray-400" />
                            </div>

                            <div className="flex-[5]">
                              <div className="mb-2">
                                <div className="text-sm font-bold bg-gradient-to-r from-green-600 to-emerald-600 bg-clip-text text-transparent mb-1 text-center">AutoGolfCRM</div>
                                <div className="h-0.5 w-40 mx-auto bg-gradient-to-r from-green-600 to-emerald-600 rounded-full"></div>
                              </div>
                              <div className="flex flex-nowrap gap-1 justify-center">
                                <span className="text-xs px-2 py-1 bg-gray-100 text-gray-700 rounded font-medium">고객</span>
                                <span className="text-xs px-2 py-1 bg-gray-100 text-gray-700 rounded font-medium">레슨</span>
                                <span className="text-xs px-2 py-1 bg-gray-100 text-gray-700 rounded font-medium">급여</span>
                                <span className="text-xs px-2 py-1 bg-gray-100 text-gray-700 rounded font-medium">타석</span>
                                <span className="text-xs px-2 py-1 bg-gray-100 text-gray-700 rounded font-medium">CS</span>
                              </div>
                            </div>
                          </div>
                        ) : categoryIndex === 1 ? (
                          /* 고객관계관리 - Word Cloud Visual */
                          <div className="h-full relative overflow-hidden bg-white rounded-xl flex items-center justify-center group/visual">
                            {/* Word Cloud Background */}
                            <div className="absolute inset-0">
                              {[
                                // Inner Circle
                                { text: "전화응대", top: "25%", left: "25%", size: "text-sm", delay: 0 },
                                { text: "예약관리", top: "20%", right: "25%", size: "text-sm", delay: 0.1 },
                                { text: "레슨관리", bottom: "25%", left: "25%", size: "text-sm", delay: 0.2 },
                                { text: "회원관리", bottom: "22%", right: "25%", size: "text-sm", delay: 0.3 },

                                // Middle Circle
                                { text: "직원급여", top: "15%", left: "10%", size: "text-xs", delay: 0.4 },
                                { text: "매출정산", top: "12%", right: "12%", size: "text-xs", delay: 0.5 },
                                { text: "자동알림", bottom: "15%", left: "10%", size: "text-xs", delay: 0.6 },
                                { text: "노쇼관리", bottom: "12%", right: "12%", size: "text-xs", delay: 0.7 },
                                { text: "마케팅", top: "45%", left: "5%", size: "text-xs", delay: 0.8 },
                                { text: "매출분석", top: "42%", right: "5%", size: "text-xs", delay: 0.9 },

                                // Outer/Scattered
                                { text: "회원권상담", top: "8%", left: "35%", size: "text-[10px]", delay: 1.0 },
                                { text: "수강생관리", top: "8%", right: "35%", size: "text-[10px]", delay: 1.1 },
                                { text: "상담일지", bottom: "8%", left: "38%", size: "text-[10px]", delay: 1.2 },
                                { text: "재등록관리", bottom: "8%", right: "38%", size: "text-[10px]", delay: 1.3 },
                                { text: "프로스케줄", top: "30%", left: "2%", size: "text-[10px]", delay: 1.4 },
                                { text: "이용권관리", top: "30%", right: "2%", size: "text-[10px]", delay: 1.5 },
                                { text: "이벤트", bottom: "30%", left: "2%", size: "text-[10px]", delay: 1.6 },
                                { text: "세금신고", bottom: "30%", right: "2%", size: "text-[10px]", delay: 1.7 },

                                // The Highlighted One
                                { text: "고객관계관리", top: "15%", left: "50%", x: "-50%", size: "text-xs", delay: 2.0 },
                              ].map((item, i) => (
                                <motion.div
                                  key={i}
                                  initial={{ opacity: 0, scale: 0.5 }}
                                  whileInView={{ opacity: 1, scale: 1 }}
                                  animate={{
                                    y: [0, -8, 0, 8, 0],
                                    x: [0, 6, 0, -6, 0],
                                    scale: [1, 1.08, 1, 1.05, 1]
                                  }}
                                  transition={{
                                    opacity: { duration: 0.5, delay: item.delay },
                                    y: { duration: 5 + Math.random() * 3, repeat: Infinity, ease: "easeInOut", delay: Math.random() * 2 },
                                    x: { duration: 6 + Math.random() * 3, repeat: Infinity, ease: "easeInOut", delay: Math.random() * 2 },
                                    scale: { duration: 4 + Math.random() * 2, repeat: Infinity, ease: "easeInOut", delay: Math.random() * 2 }
                                  }}
                                  className={`absolute whitespace-nowrap select-none ${item.size} text-gray-400 z-0`}
                                  style={{
                                    top: item.top,
                                    left: item.left,
                                    right: item.right,
                                    bottom: item.bottom,
                                    transform: item.x ? `translateX(${item.x})` : 'none'
                                  }}
                                >
                                  {item.text}
                                </motion.div>
                              ))}
                            </div>

                            {/* Central Focus */}
                            <motion.div
                              initial={{ scale: 0.9, opacity: 0 }}
                              whileInView={{ scale: 1, opacity: 1 }}
                              transition={{ delay: 0.5, type: "spring" }}
                              className="relative z-10 w-full text-center px-2"
                            >
                              <p className="font-extrabold text-lg md:text-xl whitespace-nowrap drop-shadow-sm bg-white/90 py-2 shadow-sm bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">
                                정말 중요한 것에만 집중하세요
                              </p>
                            </motion.div>
                          </div>
                        ) : (
                          /* 기본 Placeholder */
                          <div className="h-full border-2 border-dashed border-gray-200 rounded-xl flex items-center justify-center">
                            <div className="text-gray-400 text-sm">
                              정말 중요한 것에만 집중하세요
                            </div>
                          </div>
                        )}
                      </div>
                    )}

                    {/* Card News List - Each button is 1 slot (76px) */}
                    {category.cardNewsList.map((cardNews, cardNewsIndex) => (
                      <motion.button
                        key={cardNewsIndex}
                        onClick={() => handleOpenCardNews(categoryIndex, cardNewsIndex)}
                        whileHover={{ scale: 1.02, x: 4 }}
                        whileTap={{ scale: 0.98 }}
                        className="w-full flex items-center justify-between p-5 rounded-xl bg-white border-2 border-gray-200 hover:border-gray-300 hover:shadow-md transition-all group/item relative overflow-hidden h-[76px]"
                      >
                        <div className={`absolute inset-0 bg-gradient-to-r ${category.color} opacity-0 group-hover/item:opacity-5 transition-opacity`}></div>

                        <div className="flex items-center gap-4 relative z-10">
                          <div className={`w-10 h-10 rounded-lg bg-gradient-to-br ${category.color} flex items-center justify-center flex-shrink-0 shadow-sm`}>
                            <cardNews.icon className="w-5 h-5 text-white" />
                          </div>
                          <div className="text-left">
                            <p className="text-gray-900 font-medium">{cardNews.title}</p>
                            {cardNews.subtitle && (
                              <p className="text-sm text-gray-500 mt-1">{cardNews.subtitle}</p>
                            )}
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
              지금 바로 <span className="bg-gradient-to-r from-green-500 to-blue-600 bg-clip-text text-transparent font-bold">무료 체험</span>으로 경험해보세요
            </p>
            <button
              onClick={() => {
                const element = document.getElementById('pricing');
                if (element) {
                  element.scrollIntoView({ behavior: 'smooth' });
                }
              }}
              className="px-8 py-4 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-xl hover:shadow-2xl hover:scale-105 transition-all duration-300 text-lg font-semibold"
            >
              14일 무료 체험 시작하기
            </button>
          </div>
        </motion.div>

        {/* Card News Slide Modal */}
        <AnimatePresence>
          {selectedCardNews !== null && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 bg-black bg-opacity-60 backdrop-blur-sm flex items-center justify-center p-4 z-50"
              onClick={handleCloseCardNews}
            >
              <motion.div
                initial={{ scale: 0.9, opacity: 0, y: 20 }}
                animate={{ scale: 1, opacity: 1, y: 0 }}
                exit={{ scale: 0.9, opacity: 0, y: 20 }}
                transition={{ type: "spring", duration: 0.5 }}
                className="bg-white rounded-3xl p-10 max-w-4xl w-full shadow-2xl relative max-h-[90vh] overflow-y-auto"
                onClick={(e) => e.stopPropagation()}
              >
                {/* Close Button */}
                <button
                  onClick={handleCloseCardNews}
                  className="absolute top-6 right-6 w-10 h-10 rounded-full bg-gray-100 hover:bg-gray-200 flex items-center justify-center transition-colors z-20"
                >
                  <X className="w-5 h-5 text-gray-600" />
                </button>

                {/* Header */}
                <div className="flex items-start gap-6 mb-8">
                  <div className={`w-20 h-20 rounded-2xl bg-gradient-to-br ${categories[selectedCardNews.category].color} flex items-center justify-center flex-shrink-0 shadow-lg`}>
                    {(() => {
                      const Icon = categories[selectedCardNews.category].cardNewsList[selectedCardNews.cardNewsIndex].icon;
                      return <Icon className="w-10 h-10 text-white" />;
                    })()}
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-3">
                      <span className={`px-4 py-1.5 rounded-full bg-gradient-to-r ${categories[selectedCardNews.category].color} text-white text-sm font-semibold`}>
                        {categories[selectedCardNews.category].title}
                      </span>
                    </div>
                    <h3 className="text-gray-900 mb-2 text-3xl font-bold">
                      {categories[selectedCardNews.category].cardNewsList[selectedCardNews.cardNewsIndex].title}
                    </h3>
                  </div>
                </div>

                {/* Slide Content */}
                <div className="relative min-h-[400px]">
                  <AnimatePresence initial={false} custom={slideDirection} mode="wait">
                    <motion.div
                      key={currentSlide}
                      custom={slideDirection}
                      variants={slideVariants}
                      initial="enter"
                      animate="center"
                      exit="exit"
                      transition={{
                        x: { type: "spring", stiffness: 300, damping: 30 },
                        opacity: { duration: 0.2 }
                      }}
                      className="w-full"
                    >
                      <div className="mb-6">
                        <h4 className="text-2xl font-bold text-gray-900 mb-6">
                          {categories[selectedCardNews.category].cardNewsList[selectedCardNews.cardNewsIndex].slides[currentSlide].title}
                        </h4>
                      </div>
                      <div className="prose max-w-none">
                        {categories[selectedCardNews.category].cardNewsList[selectedCardNews.cardNewsIndex].slides[currentSlide].content}
                      </div>
                    </motion.div>
                  </AnimatePresence>
                </div>

                {/* Navigation */}
                <div className="flex items-center justify-between mt-8 pt-6 border-t border-gray-200">
                  <button
                    onClick={handlePrevSlide}
                    disabled={currentSlide === 0}
                    className={`flex items-center gap-2 px-6 py-3 rounded-xl transition-all ${currentSlide === 0
                      ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                      : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                      }`}
                  >
                    <ChevronLeft className="w-5 h-5" />
                    <span>이전</span>
                  </button>

                  {/* Slide Indicator */}
                  <div className="flex items-center gap-2">
                    {categories[selectedCardNews.category].cardNewsList[selectedCardNews.cardNewsIndex].slides.map((_, index) => (
                      <button
                        key={index}
                        onClick={() => {
                          setSlideDirection(index > currentSlide ? 'right' : 'left');
                          setCurrentSlide(index);
                        }}
                        className={`h-2 rounded-full transition-all ${index === currentSlide
                          ? `w-8 bg-gradient-to-r ${categories[selectedCardNews.category].color}`
                          : 'w-2 bg-gray-300 hover:bg-gray-400'
                          }`}
                      />
                    ))}
                  </div>

                  <button
                    onClick={handleNextSlide}
                    disabled={currentSlide === categories[selectedCardNews.category].cardNewsList[selectedCardNews.cardNewsIndex].slides.length - 1}
                    className={`flex items-center gap-2 px-6 py-3 rounded-xl transition-all ${currentSlide === categories[selectedCardNews.category].cardNewsList[selectedCardNews.cardNewsIndex].slides.length - 1
                      ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                      : `bg-gradient-to-r ${categories[selectedCardNews.category].color} text-white hover:shadow-lg`
                      }`}
                  >
                    <span>다음</span>
                    <ChevronRight className="w-5 h-5" />
                  </button>
                </div>

                {/* CTA Button */}
                <div className="mt-6">
                  <button
                    onClick={() => {
                      handleCloseCardNews();
                      const element = document.getElementById('pricing');
                      if (element) {
                        element.scrollIntoView({ behavior: 'smooth' });
                      }
                    }}
                    className={`w-full px-6 py-4 bg-gradient-to-r ${categories[selectedCardNews.category].color} text-white rounded-xl hover:shadow-lg hover:scale-105 transition-all font-semibold text-lg`}
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
