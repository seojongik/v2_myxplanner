import { Menu, LogOut, Building2, ArrowLeftRight } from 'lucide-react';
import { useState, useEffect } from 'react';

interface HeaderProps {
  onLoginClick: () => void;
  onRegisterClick: () => void;
}

interface UserData {
  role: string;
  staff_name?: string;
  pro_name?: string;
  manager_name?: string;
}

interface BranchData {
  branch_name: string;
  branch_id: string;
}

export function Header({ onLoginClick, onRegisterClick }: HeaderProps) {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [userData, setUserData] = useState<UserData | null>(null);
  const [branchData, setBranchData] = useState<BranchData | null>(null);
  const [demoButtonText, setDemoButtonText] = useState('데모체험');
  const [isShimmering, setIsShimmering] = useState(false);
  const [textOpacity, setTextOpacity] = useState(1);

  useEffect(() => {
    checkLoginStatus();

    // 로그인 상태 변경 이벤트 리스너 추가
    const handleLoginStatusChange = () => {
      checkLoginStatus();
    };

    window.addEventListener('loginStatusChanged', handleLoginStatusChange);

    // 클린업
    return () => {
      window.removeEventListener('loginStatusChanged', handleLoginStatusChange);
    };
  }, []);

  // 데모체험 버튼 텍스트 전환 애니메이션 (부드러운 shimmer 효과)
  useEffect(() => {
    const interval = setInterval(() => {
      // shimmer 시작
      setIsShimmering(true);

      // 0.5초 후 텍스트 fade out 시작
      setTimeout(() => {
        setTextOpacity(0);
      }, 500);

      // 0.75초 후 텍스트 변경 (완전히 투명해진 후)
      setTimeout(() => {
        setDemoButtonText((prev) => prev === '데모체험' ? '회원가입' : '데모체험');
      }, 750);

      // 1초 후 텍스트 fade in 시작
      setTimeout(() => {
        setTextOpacity(1);
      }, 1000);

      // 1.5초 후 shimmer 종료
      setTimeout(() => {
        setIsShimmering(false);
      }, 1500);
    }, 3000); // 3초 주기 (1.5초 전환 + 1.5초 유지)

    return () => clearInterval(interval);
  }, []);

  const checkLoginStatus = () => {
    try {
      const currentUser = localStorage.getItem('currentUser');
      const currentBranch = localStorage.getItem('currentBranch');

      if (currentUser && currentBranch) {
        setUserData(JSON.parse(currentUser));
        setBranchData(JSON.parse(currentBranch));
        setIsLoggedIn(true);
      } else {
        setIsLoggedIn(false);
        setUserData(null);
        setBranchData(null);
      }
    } catch (error) {
      console.error('로그인 상태 확인 오류:', error);
      setIsLoggedIn(false);
    }
  };

  const handleLogout = () => {
    if (confirm('로그아웃 하시겠습니까?')) {
      localStorage.removeItem('currentUser');
      localStorage.removeItem('currentBranch');
      setIsLoggedIn(false);
      setUserData(null);
      setBranchData(null);
      window.location.reload();
    }
  };

  const handleCRMClick = () => {
    if (isLoggedIn) {
      window.location.href = '/crm/';
    } else {
      onLoginClick();
    }
  };

  const scrollToSection = (id: string) => {
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
      setMobileMenuOpen(false);
    }
  };

  const getUserName = () => {
    if (!userData) return '';
    return userData.staff_name || userData.pro_name || userData.manager_name || '';
  };

  return (
    <>
      <style>{`
        @keyframes shimmer {
          0% {
            transform: translateX(-150%) translateY(-150%) rotate(30deg);
            opacity: 0;
          }
          20% {
            opacity: 0.3;
          }
          50% {
            opacity: 0.5;
          }
          80% {
            opacity: 0.3;
          }
          100% {
            transform: translateX(150%) translateY(150%) rotate(30deg);
            opacity: 0;
          }
        }
        .shimmer-button {
          position: relative;
          overflow: hidden;
        }
        .shimmer-button::before {
          content: '';
          position: absolute;
          top: -100%;
          left: -100%;
          width: 300%;
          height: 300%;
          background: linear-gradient(
            120deg,
            transparent 0%,
            transparent 40%,
            rgba(255, 255, 255, 0.3) 50%,
            transparent 60%,
            transparent 100%
          );
          animation: shimmer 1.5s ease-in-out;
        }
      `}</style>
      <header className="fixed top-0 left-0 right-0 bg-white shadow-md z-50">
        <div className="container mx-auto px-4">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-3">
              <img
                src="/images/logo.svg"
                alt="AutoGolfCRM Logo"
                className="w-10 h-10"
              />
              <div className="flex items-center gap-2">
                <span className="text-lg md:text-xl font-bold bg-gradient-to-r from-green-600 to-emerald-600 bg-clip-text text-transparent">AutoGolfCRM</span>
                <ArrowLeftRight className="w-4 h-4 md:w-5 md:h-5 text-blue-600 flex-shrink-0" />
                <span className="text-lg md:text-xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">MyGolfPlanner</span>
              </div>
              {isLoggedIn && branchData && (
                <div className="hidden md:flex items-center gap-1.5 ml-2 px-3 py-1 bg-gray-50 rounded-md border border-gray-200">
                  <Building2 className="w-3.5 h-3.5 text-gray-500" />
                  <span className="text-xs text-gray-600">
                    {branchData.branch_name}
                  </span>
                </div>
              )}
            </div>

            {/* Desktop Menu */}
            <nav className="hidden md:flex items-center gap-6">
            <button
              onClick={() => scrollToSection('why')}
              className="text-gray-700 hover:text-green-600 transition-colors"
            >
              Why AutoGolfCRM?
            </button>
            <button
              onClick={() => scrollToSection('features')}
              className="text-gray-700 hover:text-green-600 transition-colors"
            >
              Features
            </button>
            <button
              onClick={() => scrollToSection('pricing')}
              className="text-gray-700 hover:text-green-600 transition-colors"
            >
              Pricing
            </button>
            <button
              onClick={() => scrollToSection('faqs')}
              className="text-gray-700 hover:text-green-600 transition-colors"
            >
              FAQs
            </button>

            {isLoggedIn ? (
              <div className="flex items-center gap-3">
                <button
                  onClick={handleCRMClick}
                  className="px-6 py-2 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity font-medium"
                >
                  CRM 접속
                </button>
                <button
                  onClick={handleLogout}
                  className="flex items-center gap-2 px-4 py-2 text-gray-700 hover:text-red-600 transition-colors font-medium"
                >
                  <LogOut className="w-4 h-4" />
                  <span>로그아웃</span>
                </button>
              </div>
            ) : (
              <div className="flex items-center gap-3">
                <button
                  onClick={onRegisterClick}
                  className={`px-6 py-2 border-2 border-green-500 text-green-600 rounded-lg hover:bg-green-50 font-medium ${isShimmering ? 'shimmer-button' : ''}`}
                >
                  <span
                    className="inline-block min-w-[4rem] transition-opacity duration-500"
                    style={{ opacity: textOpacity }}
                  >
                    {demoButtonText}
                  </span>
                </button>
                <button
                  onClick={onLoginClick}
                  className="px-6 py-2 border-2 border-blue-600 text-blue-600 rounded-lg hover:bg-blue-50 transition-colors font-medium"
                >
                  Log-in
                </button>
              </div>
            )}
            </nav>

            {/* Mobile Menu Button */}
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="md:hidden p-2"
            >
              <Menu className="w-6 h-6" />
            </button>
          </div>

          {/* Mobile Menu */}
          {mobileMenuOpen && (
            <nav className="md:hidden py-4 border-t">
            <div className="flex flex-col gap-4">
              <button
                onClick={() => scrollToSection('why')}
                className="text-gray-700 hover:text-green-600 transition-colors text-left"
              >
                Why AutoGolfCRM?
              </button>
              <button
                onClick={() => scrollToSection('features')}
                className="text-gray-700 hover:text-green-600 transition-colors text-left"
              >
                Features
              </button>
              <button
                onClick={() => scrollToSection('pricing')}
                className="text-gray-700 hover:text-green-600 transition-colors text-left"
              >
                Pricing
              </button>
              <button
                onClick={() => scrollToSection('faqs')}
                className="text-gray-700 hover:text-green-600 transition-colors text-left"
              >
                FAQs
              </button>

              {isLoggedIn ? (
                <>
                  <button
                    onClick={handleCRMClick}
                    className="px-6 py-2 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity font-medium"
                  >
                    CRM 접속
                  </button>
                  <button
                    onClick={handleLogout}
                    className="flex items-center gap-2 px-4 py-2 text-gray-700 hover:text-red-600 transition-colors font-medium"
                  >
                    <LogOut className="w-4 h-4" />
                    <span>로그아웃</span>
                  </button>
                </>
              ) : (
                <>
                  <button
                    onClick={onRegisterClick}
                    className={`px-6 py-2 border-2 border-green-500 text-green-600 rounded-lg hover:bg-green-50 font-medium ${isShimmering ? 'shimmer-button' : ''}`}
                  >
                    <span
                      className="inline-block min-w-[4rem] transition-opacity duration-500"
                      style={{ opacity: textOpacity }}
                    >
                      {demoButtonText}
                    </span>
                  </button>
                  <button
                    onClick={onLoginClick}
                    className="px-6 py-2 border-2 border-blue-600 text-blue-600 rounded-lg hover:bg-blue-50 transition-colors font-medium"
                  >
                    Log-in
                  </button>
                </>
              )}
              </div>
            </nav>
          )}
        </div>
      </header>
    </>
  );
}
