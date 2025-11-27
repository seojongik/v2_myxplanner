import {
  TrendingUp,
  Target,
  CalendarClock,
  Clock,
  Briefcase,
  AlertCircle,
  CloudRain,
  Zap,
  Timer,
  Coffee,
  Users,
  CalendarX
} from 'lucide-react';
import { Category } from './types';

export const revenueGrowthData: Category = {
  title: '매출증대',
  subtitle: '당신의 고객은 누구인가요?',
  icon: TrendingUp,
  color: 'from-green-500 to-emerald-500',
  bgPattern: 'from-green-50 to-emerald-50',
  personas: [
    { text: '매일매일 60분 실내연습!', subtext: '', checked: true },
    { text: '잠깐 짬내서 30분 연습 희망 골퍼', subtext: '', checked: false },
    { text: '바쁜 업무로 정기 연습 어려운 골퍼', subtext: '', checked: false },
    { text: '기간권 구매에 트라우마를 가진 골퍼', subtext: '', checked: false },
    { text: '인도어 연습 선호 골퍼', subtext: '', checked: false },
    { text: '필드 잡히고 급히 연습하고 싶은 골퍼', subtext: '', checked: false },
    { text: '60분은 아쉽고 90분이 딱 적당한 골퍼', subtext: '', checked: false },
    { text: '오늘 반차 냈다. 120분 연습 골퍼', subtext: '', checked: false },
    { text: '정각 단위 시작 맞추기 어려운 골퍼', subtext: '', checked: false },
    { text: '피크시 현장 대기가 싫은 골퍼', subtext: '', checked: false },
    { text: '연습중 뒷사람이 불편한 골퍼', subtext: '', checked: false }
  ],
  cardNewsList: [
    {
      title: '새로운 고객을 만나다',
      icon: Target,
      slides: [
        {
          title: '다양한 골퍼 유형',
          content: (
            <div className="space-y-6">
              <p className="text-lg text-gray-700 leading-relaxed">
                골프 연습장을 찾는 고객은 다양합니다. 초보자부터 프로 지망생까지,
                각자의 목적과 수준에 맞는 서비스가 필요합니다.
              </p>
              <div className="grid grid-cols-2 gap-4">
                <div className="p-4 bg-green-50 rounded-xl">
                  <div className="text-2xl mb-2">⛳</div>
                  <div className="font-semibold text-gray-900">초보 골퍼</div>
                  <div className="text-sm text-gray-600 mt-1">기초부터 배우고 싶은 분들</div>
                </div>
                <div className="p-4 bg-blue-50 rounded-xl">
                  <div className="text-2xl mb-2">🏌️</div>
                  <div className="font-semibold text-gray-900">레슨 골퍼</div>
                  <div className="text-sm text-gray-600 mt-1">실력 향상을 원하는 분들</div>
                </div>
                <div className="p-4 bg-purple-50 rounded-xl">
                  <div className="text-2xl mb-2">🎯</div>
                  <div className="font-semibold text-gray-900">정기 이용객</div>
                  <div className="text-sm text-gray-600 mt-1">꾸준히 연습하는 분들</div>
                </div>
                <div className="p-4 bg-pink-50 rounded-xl">
                  <div className="text-2xl mb-2">👔</div>
                  <div className="font-semibold text-gray-900">법인 고객</div>
                  <div className="text-sm text-gray-600 mt-1">단체 이용 고객</div>
                </div>
              </div>
            </div>
          )
        },
        {
          title: '골프 인구 중 몇%가 당신의 고객인가요?',
          content: (
            <div className="space-y-6">
              <p className="text-lg text-gray-700 leading-relaxed">
                국내 골프 인구는 매년 증가하고 있지만, 실제로 당신의 연습장을
                찾는 고객은 얼마나 될까요?
              </p>
              <div className="bg-gradient-to-br from-green-50 to-blue-50 p-6 rounded-2xl">
                <div className="text-center mb-4">
                  <div className="text-5xl font-bold bg-gradient-to-r from-green-600 to-blue-600 bg-clip-text text-transparent mb-2">
                    500만 명+
                  </div>
                  <div className="text-gray-600">국내 골프 인구</div>
                </div>
                <div className="text-center">
                  <div className="text-3xl font-bold text-gray-800 mb-2">❓</div>
                  <div className="text-gray-700 font-medium">하지만 우리 연습장 고객은?</div>
                </div>
              </div>
              <p className="text-gray-600 text-center italic">
                새로운 고객을 발굴하고 유치하는 것이 성장의 핵심입니다
              </p>
            </div>
          )
        },
        {
          title: '낮은 객단가 + 노쇼, 기간권 영업할 수밖에 없는 이유',
          content: (
            <div className="space-y-6">
              <p className="text-lg text-gray-700 leading-relaxed">
                골프 연습장 운영의 가장 큰 고민은 안정적인 수익 확보입니다.
              </p>
              <div className="space-y-4">
                <div className="p-5 bg-red-50 border-l-4 border-red-500 rounded-r-xl">
                  <div className="font-semibold text-gray-900 mb-2">💸 낮은 객단가</div>
                  <div className="text-gray-700">단타 이용객은 수익성이 낮습니다</div>
                </div>
                <div className="p-5 bg-orange-50 border-l-4 border-orange-500 rounded-r-xl">
                  <div className="font-semibold text-gray-900 mb-2">👻 노쇼 문제</div>
                  <div className="text-gray-700">예약 후 나타나지 않는 고객으로 인한 손실</div>
                </div>
                <div className="p-5 bg-green-50 border-l-4 border-green-500 rounded-r-xl">
                  <div className="font-semibold text-gray-900 mb-2">✅ 해결책: 기간권</div>
                  <div className="text-gray-700">안정적 수익과 높은 고객 충성도 확보</div>
                </div>
              </div>
            </div>
          )
        },
        {
          title: 'How it works?',
          content: (
            <div className="space-y-6">
              <p className="text-lg text-gray-700 leading-relaxed mb-6">
                AutoGolfCRM이 신규 고객 유치를 돕는 방법
              </p>
              <div className="space-y-4">
                <div className="flex gap-4 items-start">
                  <div className="w-10 h-10 rounded-full bg-gradient-to-br from-green-500 to-emerald-500 text-white flex items-center justify-center font-bold flex-shrink-0">1</div>
                  <div>
                    <div className="font-semibold text-gray-900 mb-1">데이터 기반 고객 분석</div>
                    <div className="text-gray-600">고객 유형, 방문 패턴, 선호도를 자동으로 분석합니다</div>
                  </div>
                </div>
                <div className="flex gap-4 items-start">
                  <div className="w-10 h-10 rounded-full bg-gradient-to-br from-green-500 to-emerald-500 text-white flex items-center justify-center font-bold flex-shrink-0">2</div>
                  <div>
                    <div className="font-semibold text-gray-900 mb-1">맞춤형 마케팅 자동화</div>
                    <div className="text-gray-600">고객별 최적 시점에 맞춤 프로모션을 자동 발송합니다</div>
                  </div>
                </div>
                <div className="flex gap-4 items-start">
                  <div className="w-10 h-10 rounded-full bg-gradient-to-br from-green-500 to-emerald-500 text-white flex items-center justify-center font-bold flex-shrink-0">3</div>
                  <div>
                    <div className="font-semibold text-gray-900 mb-1">회원권 전환 유도</div>
                    <div className="text-gray-600">단기 고객을 장기 회원으로 전환하는 최적 타이밍 제안</div>
                  </div>
                </div>
              </div>
            </div>
          )
        }
      ]
    }
  ]
};
