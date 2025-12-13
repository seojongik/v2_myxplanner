import { useState } from 'react';
import { ArrowLeft, Phone, Lock, Eye, EyeOff, ArrowLeftRight, Building2, User, ChevronRight } from 'lucide-react';
import { ImageWithFallback } from './figma/ImageWithFallback';
import { getData } from '../lib/supabase';
import { verifyPassword } from '../lib/password-service';

interface LoginProps {
  onBack: () => void;
  onRegisterClick?: () => void;
}

interface StaffAccount {
  staff_access_id: string;
  branch_id: string;
  branch_name: string;
  role: 'pro' | 'manager';
  staff_name: string;
  userData: any;
}

export function Login({ onBack, onRegisterClick }: LoginProps) {
  const [phoneNumber, setPhoneNumber] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  
  // 다중 계정 선택 관련 상태
  const [staffAccounts, setStaffAccounts] = useState<StaffAccount[]>([]);
  const [showAccountSelection, setShowAccountSelection] = useState(false);

  // 전화번호 정규화 (하이픈 등 제거)
  const normalizePhoneNumber = (phone: string) => {
    return phone.replace(/[^0-9]/g, '');
  };

  // 전화번호 형식 검증
  const validatePhoneNumber = (phone: string) => {
    const normalized = normalizePhoneNumber(phone);
    return normalized.length >= 10 && normalized.length <= 11 && normalized.startsWith('01');
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // 전화번호 형식 검증
    if (!validatePhoneNumber(phoneNumber)) {
      alert('올바른 전화번호 형식을 입력해주세요. (예: 010-1234-5678)');
      return;
    }

    setIsLoading(true);
    const normalizedPhone = normalizePhoneNumber(phoneNumber);

    try {
      console.log('🔐 전화번호 로그인 시도:', normalizedPhone);

      const allMatchedStaff: any[] = [];

      // 1단계: v2_staff_pro 테이블에서 전화번호로 조회
      const proResult = await getData({
        table: 'v2_staff_pro',
        where: [
          { field: 'pro_phone', operator: '=', value: normalizedPhone },
          { field: 'staff_status', operator: '=', value: '재직' },
        ],
      });

      if (proResult.success && proResult.data) {
        for (const userData of proResult.data) {
          userData.role = 'pro';
          userData.staff_name = userData.pro_name;
          allMatchedStaff.push(userData);
        }
      }

      // 2단계: v2_staff_manager 테이블에서 전화번호로 조회
      const managerResult = await getData({
        table: 'v2_staff_manager',
        where: [
          { field: 'manager_phone', operator: '=', value: normalizedPhone },
          { field: 'staff_status', operator: '=', value: '재직' },
        ],
      });

      if (managerResult.success && managerResult.data) {
        for (const userData of managerResult.data) {
          userData.role = 'manager';
          userData.staff_name = userData.manager_name;
          allMatchedStaff.push(userData);
        }
      }

      // 계정이 없으면 실패
      if (allMatchedStaff.length === 0) {
        alert('전화번호 또는 비밀번호가 올바르지 않습니다.');
        setIsLoading(false);
        return;
      }

      // 첫 번째 계정의 비밀번호로 검증 (전화번호당 비밀번호 1개)
      const firstAccount = allMatchedStaff[0];
      const storedPassword = firstAccount.staff_access_password || '';
      const isValid = await verifyPassword(password, storedPassword);

      if (!isValid) {
        console.log('❌ 비밀번호 불일치');
        alert('전화번호 또는 비밀번호가 올바르지 않습니다.');
        setIsLoading(false);
        return;
      }

      console.log('✅ 비밀번호 검증 성공!');

      // 지점+역할 기준 중복 제거
      const uniqueAccounts: StaffAccount[] = [];
      const seenCombinations = new Set<string>();

      // 지점 정보 조회
      const branchIds = [...new Set(allMatchedStaff.map(s => s.branch_id).filter(Boolean))];
      const branchMap = new Map<string, any>();

      if (branchIds.length > 0) {
        for (const branchId of branchIds) {
          const branchResult = await getData({
            table: 'v2_branch',
            where: [{ field: 'branch_id', operator: '=', value: branchId }],
          });
          if (branchResult.success && branchResult.data && branchResult.data.length > 0) {
            branchMap.set(branchId, branchResult.data[0]);
          }
        }
      }

      for (const staff of allMatchedStaff) {
        const branchId = staff.branch_id?.toString() || 'unknown';
        const role = staff.role || 'unknown';
        const combination = `${branchId}-${role}`;

        if (!seenCombinations.has(combination)) {
          const branchInfo = branchMap.get(branchId);
          uniqueAccounts.push({
            staff_access_id: staff.staff_access_id,
            branch_id: branchId,
            branch_name: branchInfo?.branch_name || '지점 정보 없음',
            role: role as 'pro' | 'manager',
            staff_name: staff.staff_name || '',
            userData: { ...staff, branch_info: branchInfo },
          });
          seenCombinations.add(combination);
        }
      }

      console.log(`📊 유효한 계정 수: ${uniqueAccounts.length}개`);

      if (uniqueAccounts.length === 1) {
        // 단일 계정이면 바로 로그인
        await handleLoginSuccess(uniqueAccounts[0]);
      } else {
        // 다중 계정이면 선택 화면 표시
        setStaffAccounts(uniqueAccounts);
        setShowAccountSelection(true);
      }

    } catch (error) {
      console.error('Login error:', error);
      alert('로그인 중 오류가 발생했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleLoginSuccess = async (account: StaffAccount) => {
    const userData = account.userData;
    const branchInfo = userData.branch_info;

    if (!branchInfo) {
      alert('지점 정보를 찾을 수 없습니다.');
      return;
    }

    // localStorage에 저장 (CRM에서 사용)
    if (typeof window !== 'undefined' && window.localStorage) {
      window.localStorage.setItem('currentUser', JSON.stringify(userData));
      window.localStorage.setItem('currentBranch', JSON.stringify(branchInfo));
    }

    // 로그인 성공 알림
    alert(`${account.branch_name}에 ${account.role === 'pro' ? '프로' : '매니저'}로 로그인했습니다.`);

    // 로그인 상태 변경 이벤트 발생 (Header가 감지하여 UI 업데이트)
    window.dispatchEvent(new CustomEvent('loginStatusChanged'));

    // 랜딩 페이지로 돌아가기
    onBack();
  };

  // 계정 선택 화면으로 돌아가기
  const handleBackToLogin = () => {
    setShowAccountSelection(false);
    setStaffAccounts([]);
  };

  // 계정 선택 화면
  if (showAccountSelection) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-green-50 to-blue-50 flex items-center justify-center p-4">
        <div className="w-full max-w-md">
          <div className="bg-white rounded-2xl shadow-xl p-8">
            <button
              onClick={handleBackToLogin}
              className="flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-6 transition-colors"
            >
              <ArrowLeft className="w-5 h-5" />
              돌아가기
            </button>

            <div className="text-center mb-8">
              <div className="w-16 h-16 bg-gradient-to-r from-green-500 to-blue-600 rounded-full flex items-center justify-center mx-auto mb-4">
                <User className="w-8 h-8 text-white" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900 mb-2">계정 선택</h2>
              <p className="text-gray-600">
                로그인할 지점과 역할을 선택해주세요
              </p>
              <p className="text-sm text-gray-500 mt-1">
                {staffAccounts.length}개의 계정이 있습니다
              </p>
            </div>

            <div className="space-y-3">
              {staffAccounts.map((account, index) => (
                <button
                  key={`${account.branch_id}-${account.role}`}
                  onClick={() => handleLoginSuccess(account)}
                  className="w-full p-4 bg-gray-50 hover:bg-gray-100 rounded-xl border border-gray-200 hover:border-green-300 transition-all text-left group"
                >
                  <div className="flex items-center gap-4">
                    <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                      account.role === 'pro' 
                        ? 'bg-green-100 text-green-600' 
                        : 'bg-purple-100 text-purple-600'
                    }`}>
                      {account.role === 'pro' ? (
                        <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                      ) : (
                        <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                        </svg>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1">
                        <Building2 className="w-4 h-4 text-gray-400" />
                        <span className="font-semibold text-gray-900 truncate">
                          {account.branch_name}
                        </span>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className={`px-2 py-0.5 text-xs font-medium rounded ${
                          account.role === 'pro'
                            ? 'bg-green-100 text-green-700'
                            : 'bg-purple-100 text-purple-700'
                        }`}>
                          {account.role === 'pro' ? '프로' : '매니저'}
                        </span>
                        <span className="text-sm text-gray-500">
                          {account.staff_name}
                        </span>
                      </div>
                    </div>
                    <ChevronRight className="w-5 h-5 text-gray-400 group-hover:text-green-500 transition-colors" />
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

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
              <label htmlFor="phoneNumber" className="block text-gray-700 mb-2">
                전화번호
              </label>
              <div className="relative">
                <Phone className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  id="phoneNumber"
                  type="tel"
                  value={phoneNumber}
                  onChange={(e) => setPhoneNumber(e.target.value)}
                  placeholder="010-1234-5678"
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
