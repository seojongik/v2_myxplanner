import { ImageWithFallback } from './figma/ImageWithFallback';
import { ArrowRight } from 'lucide-react';
import { useState, useEffect } from 'react';

interface HeroProps {
  onRegisterClick: () => void;
}

export function Hero({ onRegisterClick }: HeroProps) {
  const [isLoggedIn, setIsLoggedIn] = useState(false);

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

  const handleDemoClick = () => {
    if (isLoggedIn) {
      // 로그인 상태: CRM으로 이동
      window.location.href = '/crm/';
    } else {
      // 비로그인 상태: 데모체험 등록 화면으로
      onRegisterClick();
    }
  };

  const scrollToSection = (id: string) => {
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <section className="pt-32 pb-20 px-3 md:px-4 bg-gradient-to-br from-green-50 to-blue-50">
      <div className="container mx-auto">
        <div className="grid md:grid-cols-2 gap-12 items-center">
          <div>
            <h1 className="text-gray-900 mb-6">
              골프연습장을 위한<br />
              스마트 CRM 솔루션
            </h1>
            <p className="text-gray-600 mb-8">
              예약 앱과 완벽하게 연동되는 AutoGolfCRM으로 회원 관리부터 마케팅까지 자동화하세요.
              골프연습장 운영을 더 쉽고 효율적으로 만들어드립니다.
            </p>
            <div className="flex flex-wrap gap-4">
              <button
                onClick={handleDemoClick}
                className="px-8 py-3 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity flex items-center gap-2"
              >
                데모체험 시작하기
                <ArrowRight className="w-5 h-5" />
              </button>
              <button
                onClick={() => scrollToSection('features')}
                className="px-8 py-3 border-2 border-green-600 text-green-600 rounded-lg hover:bg-green-50 transition-colors"
              >
                기능 둘러보기
              </button>
            </div>
          </div>
          <div className="relative">
            <ImageWithFallback
              src="https://images.unsplash.com/photo-1609196276438-e9ee7a8f2d19?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxnb2xmJTIwcHJhY3RpY2UlMjBkcml2aW5nJTIwcmFuZ2V8ZW58MXx8fHwxNzYzODY5Njk3fDA&ixlib=rb-4.1.0&q=80&w=1080&utm_source=figma&utm_medium=referral"
              alt="Golf driving range"
              className="w-full h-[400px] object-cover rounded-2xl shadow-2xl"
            />
          </div>
        </div>
      </div>
    </section>
  );
}
