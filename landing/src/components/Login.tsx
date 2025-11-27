import { useState } from 'react';
import { ArrowLeft, User, Lock, Eye, EyeOff, ArrowLeftRight } from 'lucide-react';
import { ImageWithFallback } from './figma/ImageWithFallback';

interface LoginProps {
  onBack: () => void;
  onRegisterClick?: () => void;
}

export function Login({ onBack, onRegisterClick }: LoginProps) {
  const [loginId, setLoginId] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [userData, setUserData] = useState<any>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      const apiUrl = import.meta.env.DEV
        ? '/dynamic_api.php'
        : 'https://autofms.mycafe24.com/dynamic_api.php';

      console.log('🔐 로그인 시도:', loginId);

      // 1단계: v2_staff_pro 테이블 조회
      const proRequestData = {
        operation: 'get',
        table: 'v2_staff_pro',
        where: [
          {
            field: 'staff_access_id',
            operator: '=',
            value: loginId,
          },
          {
            field: 'staff_status',
            operator: '=',
            value: '재직',
          },
        ],
      };

      const proResponse = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify(proRequestData),
      });

      if (proResponse.ok) {
        const proData = await proResponse.json();

        if (proData.success && proData.data && proData.data.length > 0) {
          // Pro 테이블에서 비밀번호 확인
          for (const userData of proData.data) {
            if (userData.staff_access_password === password) {
              userData.role = 'pro';
              console.log('✅ Pro로 로그인 성공');
              await handleLoginSuccess(userData);
              return;
            }
          }
        }
      }

      // 2단계: v2_staff_manager 테이블 조회
      const managerRequestData = {
        operation: 'get',
        table: 'v2_staff_manager',
        where: [
          {
            field: 'staff_access_id',
            operator: '=',
            value: loginId,
          },
          {
            field: 'staff_status',
            operator: '=',
            value: '재직',
          },
        ],
      };

      const managerResponse = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify(managerRequestData),
      });

      if (managerResponse.ok) {
        const managerData = await managerResponse.json();

        if (managerData.success && managerData.data && managerData.data.length > 0) {
          // Manager 테이블에서 비밀번호 확인
          for (const userData of managerData.data) {
            if (userData.staff_access_password === password) {
              userData.role = 'manager';
              console.log('✅ Manager로 로그인 성공');
              await handleLoginSuccess(userData);
              return;
            }
          }
        }
      }

      // 로그인 실패
      alert('로그인에 실패했습니다. 아이디와 비밀번호를 확인해주세요.');
    } catch (error) {
      console.error('Login error:', error);
      alert('로그인 중 오류가 발생했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleLoginSuccess = async (userData: any) => {
    setUserData(userData);

    // 해당 지점 정보 조회
    const branchId = userData.branch_id;
    if (!branchId) {
      alert('직원의 지점 정보가 없습니다.');
      return;
    }

    const apiUrl = import.meta.env.DEV
      ? '/dynamic_api.php'
      : 'https://autofms.mycafe24.com/dynamic_api.php';

    const branchRequestData = {
      operation: 'get',
      table: 'v2_branch',
      where: [
        {
          field: 'branch_id',
          operator: '=',
          value: branchId,
        }
      ],
    };

    try {
      const branchResponse = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify(branchRequestData),
      });

      if (branchResponse.ok) {
        const branchData = await branchResponse.json();

        if (branchData.success && branchData.data && branchData.data.length > 0) {
          const branch = branchData.data[0];

          // localStorage에 저장 (CRM에서 사용)
          if (typeof window !== 'undefined' && window.localStorage) {
            window.localStorage.setItem('currentUser', JSON.stringify(userData));
            window.localStorage.setItem('currentBranch', JSON.stringify(branch));
          }

          // 로그인 성공 알림
          alert('로그인에 성공했습니다.');

          // 로그인 상태 변경 이벤트 발생 (Header가 감지하여 UI 업데이트)
          window.dispatchEvent(new CustomEvent('loginStatusChanged'));

          // 랜딩 페이지로 돌아가기
          onBack();
        } else {
          alert('지점 정보를 찾을 수 없습니다.');
        }
      }
    } catch (error) {
      console.error('Branch fetch error:', error);
      alert('지점 정보를 가져오는 중 오류가 발생했습니다.');
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 to-blue-50 flex items-center justify-center p-4">
      <div className="w-full max-w-6xl grid md:grid-cols-2 gap-8 items-center">
        {/* Left side - Branding */}
        <div className="hidden md:block">
          <div className="mb-8">
            <div className="flex items-center gap-3 mb-6">
              <img
                src="/images/logo.svg"
                alt="AutoGolfCRM Logo"
                className="w-10 h-10"
              />
              <div className="flex items-center gap-2">
                <span className="text-3xl font-bold bg-gradient-to-r from-green-600 to-emerald-600 bg-clip-text text-transparent">AutoGolfCRM</span>
                <ArrowLeftRight className="w-6 h-6 text-blue-600 flex-shrink-0" />
                <span className="text-3xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">MyGolfPlanner</span>
              </div>
            </div>
            <h1 className="text-gray-900 mb-4">
              골프연습장 운영의<br />
              새로운 기준
            </h1>
            <p className="text-gray-600 mb-8">
              AutoGolfCRM으로 더 스마트한 운영을 시작하세요
            </p>
          </div>
          <ImageWithFallback
            src="https://images.unsplash.com/photo-1759752394755-1241472b589d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxidXNpbmVzcyUyMGRhc2hib2FyZCUyMHNvZnR3YXJlfGVufDF8fHx8MTc2Mzg2OTY5OHww&ixlib=rb-4.1.0&q=80&w=1080&utm_source=figma&utm_medium=referral"
            alt="CRM Dashboard"
            className="w-full h-[400px] object-cover rounded-2xl shadow-2xl"
          />
        </div>

        {/* Right side - Login Form */}
        <div className="bg-white rounded-2xl shadow-xl p-8 md:p-12">
          <button
            onClick={onBack}
            className="flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-6 transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
            돌아가기
          </button>

          <h2 className="text-gray-900 mb-2">로그인</h2>
          <p className="text-gray-600 mb-8">
            AutoGolfCRM 계정으로 로그인하세요
          </p>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label htmlFor="loginId" className="block text-gray-700 mb-2">
                아이디
              </label>
              <div className="relative">
                <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  id="loginId"
                  type="text"
                  value={loginId}
                  onChange={(e) => setLoginId(e.target.value)}
                  placeholder="아이디를 입력하세요"
                  required
                  className="w-full pl-12 pr-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                />
              </div>
            </div>

            <div>
              <label htmlFor="password" className="block text-gray-700 mb-2">
                비밀번호
              </label>
              <div className="relative">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  className="w-full pl-12 pr-12 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  {showPassword ? (
                    <EyeOff className="w-5 h-5" />
                  ) : (
                    <Eye className="w-5 h-5" />
                  )}
                </button>
              </div>
            </div>

            <div className="flex items-center justify-between">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={rememberMe}
                  onChange={(e) => setRememberMe(e.target.checked)}
                  className="w-4 h-4 text-green-600 border-gray-300 rounded focus:ring-green-500"
                />
                <span className="text-gray-700">로그인 상태 유지</span>
              </label>
              <a href="#" className="text-green-600 hover:text-green-700 transition-colors">
                비밀번호 찾기
              </a>
            </div>

            <button
              type="submit"
              disabled={isLoading}
              className="w-full py-3 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isLoading ? '로그인 중...' : '로그인'}
            </button>
          </form>

          <div className="mt-8 pt-8 border-t border-gray-200">
            <p className="text-center text-gray-600">
              아직 계정이 없으신가요?{' '}
              <button
                onClick={onRegisterClick || onBack}
                className="text-green-600 hover:text-green-700 transition-colors font-medium"
              >
                데모체험 시작하기
              </button>
            </p>
          </div>

          <div className="mt-6 text-center">
            <a href="#" className="text-sm text-gray-500 hover:text-gray-700 transition-colors">
              데모 계정으로 둘러보기
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
