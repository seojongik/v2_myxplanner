import { useState, useEffect } from 'react';
import { ArrowLeft, User, Lock, Eye, EyeOff, Phone, MapPin, Building2, CheckCircle2, UserCheck, X, ArrowLeftRight } from 'lucide-react';
import { ImageWithFallback } from './figma/ImageWithFallback';

interface RegisterProps {
  onBack: () => void;
  onLoginClick?: () => void;
}

export function Register({ onBack, onLoginClick }: RegisterProps) {
  const [step, setStep] = useState(1); // 1: 지점정보, 2: 관리자계정, 3: 타석설정, 4: 프로설정, 5: 직원설정

  // 천단위 콤마 포맷
  const formatNumber = (value: number | string) => {
    const num = typeof value === 'string' ? parseInt(value.replace(/,/g, '')) : value;
    return isNaN(num) ? '' : num.toLocaleString('ko-KR');
  };

  // 콤마 제거하고 숫자만 추출
  const parseNumber = (value: string) => {
    const num = parseInt(value.replace(/,/g, ''));
    return isNaN(num) ? 0 : num;
  };

  // 지점 정보
  const [branchName, setBranchName] = useState('');
  const [branchAddress, setBranchAddress] = useState('');
  const [branchAddressDetail, setBranchAddressDetail] = useState('');
  const [branchPostcode, setBranchPostcode] = useState('');
  const [branchPhone, setBranchPhone] = useState('');
  const [branchDirectorName, setBranchDirectorName] = useState('');
  const [branchBusinessRegNo, setBranchBusinessRegNo] = useState('');

  // 관리자 계정
  const [managerName, setManagerName] = useState('');
  const [loginId, setLoginId] = useState('');
  const [password, setPassword] = useState('');
  const [passwordConfirm, setPasswordConfirm] = useState('');
  const [managerPhone, setManagerPhone] = useState('');

  // 데모 데이터 - 타석 설정
  const [tsCount, setTsCount] = useState(10);
  const [tsPrice, setTsPrice] = useState(20000);

  // 데모 데이터 - 프로 설정
  const [pros, setPros] = useState([
    { id: 1, name: '김오전', shift: 'morning', baseSalary: 1000000, lessonFee: 13000, offDays: [] as string[], gender: 'male', certification: 'KPGA투어프로', sessionTime: 20 },
    { id: 2, name: '김오후', shift: 'afternoon', baseSalary: 1000000, lessonFee: 13000, offDays: [] as string[], gender: 'male', certification: 'KPGA투어프로', sessionTime: 20 },
  ]);

  // 데모 데이터 - 직원 설정
  const [staff, setStaff] = useState([
    { id: 1, name: '', position: '대표', baseSalary: 0, hourlyWage: 12000, isManager: true },
  ]);

  const [showPassword, setShowPassword] = useState(false);
  const [showPasswordConfirm, setShowPasswordConfirm] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [idCheckStatus, setIdCheckStatus] = useState<'idle' | 'checking' | 'available' | 'unavailable'>('idle');
  const [bizNoCheckStatus, setBizNoCheckStatus] = useState<'idle' | 'checking' | 'available' | 'unavailable'>('idle');

  // Daum 우편번호 API 스크립트 로드
  useEffect(() => {
    const script = document.createElement('script');
    script.src = '//t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js';
    script.async = true;
    document.body.appendChild(script);

    return () => {
      document.body.removeChild(script);
    };
  }, []);

  // 사업자등록번호 중복 검사
  const checkBizNoDuplicate = async () => {
    if (!branchBusinessRegNo || branchBusinessRegNo.length < 10) {
      alert('사업자등록번호를 정확히 입력해주세요.');
      return;
    }

    setBizNoCheckStatus('checking');

    try {
      const apiUrl = import.meta.env.DEV
        ? '/dynamic_api.php'
        : 'https://autofms.mycafe24.com/dynamic_api.php';

      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({
          operation: 'get',
          table: 'v2_branch',
          where: [{ field: 'branch_business_reg_no', operator: '=', value: branchBusinessRegNo }],
        }),
      });

      const data = await response.json();

      if (data.success && data.data?.length > 0) {
        setBizNoCheckStatus('unavailable');
        alert('이미 등록된 사업자등록번호입니다.');
      } else {
        setBizNoCheckStatus('available');
        alert('사용 가능한 사업자등록번호입니다.');
      }
    } catch (error) {
      console.error('사업자등록번호 중복 검사 오류:', error);
      setBizNoCheckStatus('idle');
      alert('중복 검사 중 오류가 발생했습니다.');
    }
  };

  // ID 중복 검사
  const checkIdDuplicate = async () => {
    if (!loginId || loginId.length < 4) {
      alert('아이디는 4자 이상 입력해주세요.');
      return;
    }

    setIdCheckStatus('checking');

    try {
      const apiUrl = import.meta.env.DEV
        ? '/dynamic_api.php'
        : 'https://autofms.mycafe24.com/dynamic_api.php';

      // Pro와 Manager 테이블 모두 확인
      const proResponse = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({
          operation: 'get',
          table: 'v2_staff_pro',
          where: [{ field: 'staff_access_id', operator: '=', value: loginId }],
        }),
      });

      const managerResponse = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({
          operation: 'get',
          table: 'v2_staff_manager',
          where: [{ field: 'staff_access_id', operator: '=', value: loginId }],
        }),
      });

      const proData = await proResponse.json();
      const managerData = await managerResponse.json();

      if ((proData.success && proData.data?.length > 0) ||
          (managerData.success && managerData.data?.length > 0)) {
        setIdCheckStatus('unavailable');
        alert('이미 사용 중인 아이디입니다.');
      } else {
        setIdCheckStatus('available');
        alert('사용 가능한 아이디입니다.');
      }
    } catch (error) {
      console.error('ID 중복 검사 오류:', error);
      setIdCheckStatus('idle');
      alert('ID 중복 검사 중 오류가 발생했습니다.');
    }
  };

  // 주소 검색
  const openAddressSearch = () => {
    if (!(window as any).daum) {
      alert('주소 검색 서비스를 불러오는 중입니다. 잠시 후 다시 시도해주세요.');
      return;
    }

    new (window as any).daum.Postcode({
      oncomplete: function (data: any) {
        setBranchPostcode(data.zonecode);
        setBranchAddress(data.address);
        setBranchAddressDetail('');
      },
    }).open();
  };

  // 1단계 유효성 검사 (지점 정보)
  const validateStep1 = () => {
    if (!branchName) {
      alert('상호명을 입력해주세요.');
      return false;
    }
    if (!branchAddress) {
      alert('주소를 입력해주세요.');
      return false;
    }
    if (!branchPhone) {
      alert('전화번호를 입력해주세요.');
      return false;
    }
    if (!branchDirectorName) {
      alert('대표자명을 입력해주세요.');
      return false;
    }
    if (!branchBusinessRegNo) {
      alert('사업자등록번호를 입력해주세요.');
      return false;
    }
    if (bizNoCheckStatus !== 'available') {
      alert('사업자등록번호 중복 검사를 완료해주세요.');
      return false;
    }
    return true;
  };

  // 2단계 유효성 검사 (관리자 계정)
  const validateStep2 = () => {
    if (!managerName) {
      alert('관리자 이름을 입력해주세요.');
      return false;
    }
    if (!loginId || loginId.length < 4) {
      alert('아이디는 4자 이상 입력해주세요.');
      return false;
    }
    if (idCheckStatus !== 'available') {
      alert('ID 중복 검사를 완료해주세요.');
      return false;
    }
    if (!password || password.length < 6) {
      alert('비밀번호는 6자 이상 입력해주세요.');
      return false;
    }
    if (password !== passwordConfirm) {
      alert('비밀번호가 일치하지 않습니다.');
      return false;
    }
    if (!managerPhone) {
      alert('관리자 전화번호를 입력해주세요.');
      return false;
    }
    return true;
  };

  // 다음 단계로
  const handleNextStep = () => {
    if (validateStep1()) {
      // 1단계에서 입력한 대표자명을 2단계 관리자 이름에 자동 입력
      setManagerName(branchDirectorName);
      setStep(2);
    }
  };

  // 데모 계정 등록 처리
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!validateStep2()) {
      return;
    }

    setIsLoading(true);

    try {
      const apiUrl = import.meta.env.DEV
        ? '/dynamic_api.php'
        : 'https://autofms.mycafe24.com/dynamic_api.php';

      console.log('🏢 지점 등록 시작');

      // branch_id 생성 (타임스탬프 기반 유니크 ID)
      const branchId = 'demo_' + Date.now();

      // 1단계: v2_branch 테이블에 지점 등록
      // 실제 테이블 스키마에 맞춰 데이터 구성
      const fullAddress = branchAddressDetail
        ? `${branchAddress} ${branchAddressDetail}`
        : branchAddress;

      const branchData: any = {
        branch_id: branchId,
        branch_password: '1111', // 기본 비밀번호
        branch_name: branchName,
        branch_status: 'demo', // 데모 계정
        branch_address: fullAddress,
        branch_phone: branchPhone,
        branch_director_name: branchDirectorName,
        branch_business_reg_no: branchBusinessRegNo,
        branch_manager_id: 1, // 임시값, 나중에 업데이트
      };

      // 빈 문자열 필드는 제외 (선택적 필드)
      // branch_director_phone, tax_type, branch_director_birthday,
      // portone_api_secret, online_sales_term_type

      console.log('📤 전송할 지점 데이터:', branchData);

      const branchResponse = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({
          operation: 'add',
          table: 'v2_branch',
          data: branchData,
        }),
      });

      if (!branchResponse.ok) {
        const errorText = await branchResponse.text();
        console.error('❌ HTTP 에러:', branchResponse.status, errorText);
        throw new Error(`지점 등록 API 호출 실패 (${branchResponse.status}): ${errorText}`);
      }

      const branchResult = await branchResponse.json();
      console.log('✅ 지점 등록 결과:', branchResult);

      if (!branchResult.success) {
        console.error('❌ 지점 등록 실패:', branchResult);
        throw new Error(branchResult.error || '지점 등록 실패');
      }

      console.log('✅ 지점 등록 완료, Branch ID:', branchId);

      // 2-1단계: 가장 큰 manager_id 조회 (새 관리자 ID 생성)
      console.log('🔍 최대 manager_id 조회 중...');

      const maxIdResponse = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({
          operation: 'get',
          table: 'v2_staff_manager',
          fields: ['manager_id'],
          order: { field: 'manager_id', direction: 'DESC' },
          limit: 1,
        }),
      });

      const maxIdResult = await maxIdResponse.json();
      let nextManagerId = 1; // 기본값

      if (maxIdResult.success && maxIdResult.data && maxIdResult.data.length > 0) {
        const maxManagerId = maxIdResult.data[0].manager_id;
        nextManagerId = parseInt(maxManagerId) + 1;
        console.log('✅ 최대 manager_id:', maxManagerId, '→ 다음 ID:', nextManagerId);
      } else {
        console.log('ℹ️ 기존 데이터 없음, 첫 번째 ID 사용:', nextManagerId);
      }

      // 계약 날짜 설정 (오늘부터 1년)
      const today = new Date();
      const nextYear = new Date(today);
      nextYear.setFullYear(today.getFullYear() + 1);

      const contractStartDate = today.toISOString().split('T')[0];
      const contractEndDate = nextYear.toISOString().split('T')[0];

      // 2-2단계: v2_staff_manager 테이블에 관리자 계정 등록
      // 실제 테이블 스키마에 맞춰 데이터 구성
      const managerData: any = {
        branch_id: branchId,
        manager_id: nextManagerId, // 새 관리자 ID
        staff_type: '직원',
        manager_name: managerName,
        manager_phone: managerPhone,
        staff_access_id: loginId,
        staff_access_password: password,
        staff_status: '재직',
        manager_position: '운영자',
        manager_contract_startdate: contractStartDate,
        manager_contract_enddate: contractEndDate,
        contract_type: '프리랜서',
        manager_contract_status: '활성',
        severance_pay: '무',
        salary_base: 0,
        salary_hour: 0,
        salary_incentive: 0,
        manager_contract_round: 1,
        updated_at: new Date().toISOString().replace('T', ' ').split('.')[0],
        salary_meal: 0,
        salary_meal_minimum_hours: 8,
      };

      // 빈 문자열 필드는 제외 (선택적 필드)
      // manager_gender, manager_birthday
      // manager_contract_id는 AUTO_INCREMENT이므로 제외

      console.log('📤 전송할 관리자 데이터:', managerData);

      console.log('👤 관리자 계정 등록 시작, Manager ID:', nextManagerId);

      const managerResponse = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({
          operation: 'add',
          table: 'v2_staff_manager',
          data: managerData,
        }),
      });

      if (!managerResponse.ok) {
        const errorText = await managerResponse.text();
        console.error('❌ 관리자 등록 HTTP 에러:', managerResponse.status, errorText);
        throw new Error(`관리자 계정 등록 API 호출 실패 (${managerResponse.status}): ${errorText}`);
      }

      const managerResult = await managerResponse.json();
      console.log('✅ 관리자 계정 등록 결과:', managerResult);

      if (!managerResult.success) {
        console.error('❌ 관리자 계정 등록 실패:', managerResult);
        throw new Error(managerResult.error || '관리자 계정 등록 실패');
      }

      // 등록된 manager_id는 위에서 설정한 값 사용
      const managerId = nextManagerId;
      console.log('✅ 관리자 계정 등록 완료, Manager ID:', managerId);

      // 3단계: v2_staff_access_setting에 관리자 권한 설정 (모든 권한 허용)
      const accessSettingData: any = {
        staff_access_id: loginId,
        branch_id: branchId,
        member_registration: '허용',
        member_page: '허용',
        communication: '허용',
        ts_management: '허용',
        lesson_status: '전체',
        salary_view: '본인',
        staff_schedule: '전체',
        pro_schedule: '전체',
        hr_management: '허용',
        locker: '허용',
        branch_settings: '허용',
        branch_operation: '허용',
        staff_name: managerName,
        salary_management: '허용',
        client_app: '허용',
      };

      // pro_name은 빈 문자열이므로 제외

      console.log('🔐 관리자 권한 설정 시작');

      const accessSettingResponse = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({
          operation: 'add',
          table: 'v2_staff_access_setting',
          data: accessSettingData,
        }),
      });

      const accessSettingResult = await accessSettingResponse.json();
      if (accessSettingResult.success) {
        console.log('✅ 관리자 권한 설정 완료');
      } else {
        console.warn('⚠️ 권한 설정 실패:', accessSettingResult.error);
      }

      // 4단계: branch_manager_id 업데이트
      if (managerId) {
        console.log('🔄 지점의 branch_manager_id 업데이트 시작, Manager ID:', managerId);

        const updateResponse = await fetch(apiUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: JSON.stringify({
            operation: 'update',
            table: 'v2_branch',
            data: { branch_manager_id: managerId },
            where: [{ field: 'branch_id', operator: '=', value: branchId }],
          }),
        });

        const updateResult = await updateResponse.json();
        if (updateResult.success) {
          console.log('✅ branch_manager_id 업데이트 완료');
        }
      }

      alert(`데모 체험 계정이 등록되었습니다!\n지점명: ${branchName}\n로그인 ID: ${loginId}\n\n이제 데모 데이터를 설정해주세요.`);

      // 직원 설정의 1번 직원 이름을 관리자 이름으로 설정
      setStaff(prevStaff =>
        prevStaff.map(s => s.id === 1 ? { ...s, name: managerName } : s)
      );

      // 3단계로 이동 (데모 데이터 설정)
      setStep(3);

    } catch (error) {
      console.error('등록 오류:', error);
      alert('등록 중 오류가 발생했습니다: ' + (error instanceof Error ? error.message : '알 수 없는 오류'));
    } finally {
      setIsLoading(false);
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
              {step === 1 || step === 2 ? '데모 체험 계정 등록' :
               step === 3 ? '타석 데모 데이터' :
               step === 4 ? '프로 데모 데이터' :
               step === 5 ? '직원 데모 데이터' : '데모 데이터 설정'}
            </h1>
            <p className="text-gray-600 mb-8">
              {step === 1 || step === 2 ? '지점 정보를 입력하고 AutoGolfCRM을 무료로 체험해보세요' :
               step === 3 ? '타석 정보를 설정하면 시스템 기능을 체험할 수 있습니다' :
               step === 4 ? '프로 정보를 설정하면 레슨 관리 기능을 체험할 수 있습니다' :
               step === 5 ? '직원 정보를 설정하면 인사 관리 기능을 체험할 수 있습니다' : ''}
            </p>
          </div>
          <ImageWithFallback
            src={
              step === 1 || step === 2
                ? "https://images.unsplash.com/photo-1759752394755-1241472b589d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxidXNpbmVzcyUyMGRhc2hib2FyZCUyMHNvZnR3YXJlfGVufDF8fHx8MTc2Mzg2OTY5OHww&ixlib=rb-4.1.0&q=80&w=1080&utm_source=figma&utm_medium=referral"
                : step === 3
                ? "https://images.unsplash.com/photo-1587825140708-dfaf72ae4b04?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080"
                : step === 4
                ? "https://images.unsplash.com/photo-1535131749006-b7f58c99034b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080"
                : "https://images.unsplash.com/photo-1522202176988-66273c2fd55f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080"
            }
            alt={
              step === 1 || step === 2 ? "CRM Dashboard" :
              step === 3 ? "Golf Practice Range" :
              step === 4 ? "Golf Instructor" :
              "Team Collaboration"
            }
            className="w-full h-[400px] object-cover rounded-2xl shadow-2xl"
          />
        </div>

        {/* Right side - Register Form */}
        <div className="bg-white rounded-2xl shadow-xl p-8 md:p-12">
          <button
            onClick={onBack}
            className="flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-6 transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
            돌아가기
          </button>

          <h2 className="text-gray-900 mb-2">
            {step === 1 ? '데모 체험 계정 등록' :
             step === 2 ? '관리자 계정 설정' :
             step === 3 ? '타석 설정' :
             step === 4 ? '프로 설정' :
             step === 5 ? '직원 설정' : '데모 체험 계정 등록'}
          </h2>
          <p className="text-gray-600 mb-8">
            {step === 1 ? '지점 정보를 입력해주세요' :
             step === 2 ? '관리자 계정 정보를 입력해주세요' :
             step === 3 ? '타석 수와 단가를 설정해주세요' :
             step === 4 ? '프로 정보를 입력해주세요' :
             step === 5 ? '직원 정보를 입력해주세요' : ''}
          </p>

          {/* Progress Indicator */}
          <div className="flex items-center gap-2 mb-8">
            <div className={`flex-1 h-2 rounded-full ${step >= 1 ? 'bg-green-500' : 'bg-gray-200'}`} />
            <div className={`flex-1 h-2 rounded-full ${step >= 2 ? 'bg-green-500' : 'bg-gray-200'}`} />
            <div className={`flex-1 h-2 rounded-full ${step >= 3 ? 'bg-green-500' : 'bg-gray-200'}`} />
            <div className={`flex-1 h-2 rounded-full ${step >= 4 ? 'bg-green-500' : 'bg-gray-200'}`} />
            <div className={`flex-1 h-2 rounded-full ${step >= 5 ? 'bg-green-500' : 'bg-gray-200'}`} />
          </div>

          {step === 1 && (
            <form onSubmit={(e) => { e.preventDefault(); handleNextStep(); }} className="space-y-6">
              {/* 상호명 */}
              <div>
                <label htmlFor="branchName" className="block text-gray-700 mb-2">
                  상호명 *
                </label>
                <div className="relative">
                  <Building2 className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    id="branchName"
                    type="text"
                    value={branchName}
                    onChange={(e) => setBranchName(e.target.value)}
                    placeholder="예: 강남골프연습장"
                    required
                    className="w-full pl-12 pr-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  />
                </div>
              </div>

              {/* 사업자등록번호 */}
              <div>
                <label htmlFor="branchBusinessRegNo" className="block text-gray-700 mb-2">
                  사업자등록번호 * (10자리)
                </label>
                <div className="flex gap-2">
                  <input
                    id="branchBusinessRegNo"
                    type="text"
                    value={branchBusinessRegNo}
                    onChange={(e) => {
                      setBranchBusinessRegNo(e.target.value);
                      setBizNoCheckStatus('idle');
                    }}
                    placeholder="123-45-67890"
                    required
                    maxLength={12}
                    className="flex-1 px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  />
                  <button
                    type="button"
                    onClick={checkBizNoDuplicate}
                    disabled={bizNoCheckStatus === 'checking'}
                    className={`px-4 py-3 rounded-lg font-medium transition-colors whitespace-nowrap ${
                      bizNoCheckStatus === 'available'
                        ? 'bg-green-500 text-white'
                        : bizNoCheckStatus === 'unavailable'
                        ? 'bg-red-500 text-white'
                        : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                    }`}
                  >
                    {bizNoCheckStatus === 'checking' ? '확인중...' :
                     bizNoCheckStatus === 'available' ? <CheckCircle2 className="w-5 h-5" /> :
                     bizNoCheckStatus === 'unavailable' ? '사용불가' : '중복확인'}
                  </button>
                </div>
              </div>

              {/* 대표자명 */}
              <div>
                <label htmlFor="branchDirectorName" className="block text-gray-700 mb-2">
                  대표자명 *
                </label>
                <div className="relative">
                  <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    id="branchDirectorName"
                    type="text"
                    value={branchDirectorName}
                    onChange={(e) => setBranchDirectorName(e.target.value)}
                    placeholder="대표자명을 입력하세요"
                    required
                    className="w-full pl-12 pr-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  />
                </div>
              </div>

              {/* 주소 */}
              <div>
                <label htmlFor="branchAddress" className="block text-gray-700 mb-2">
                  주소 *
                </label>
                <div className="space-y-2">
                  <div className="flex gap-2">
                    <input
                      id="branchPostcode"
                      type="text"
                      value={branchPostcode}
                      placeholder="우편번호"
                      readOnly
                      className="w-32 px-4 py-3 border border-gray-300 rounded-lg bg-gray-50"
                    />
                    <button
                      type="button"
                      onClick={openAddressSearch}
                      className="px-4 py-3 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors flex items-center gap-2"
                    >
                      <MapPin className="w-5 h-5" />
                      주소 검색
                    </button>
                  </div>
                  <input
                    id="branchAddress"
                    type="text"
                    value={branchAddress}
                    placeholder="주소 검색 버튼을 클릭하세요"
                    readOnly
                    required
                    className="w-full px-4 py-3 border border-gray-300 rounded-lg bg-gray-50"
                  />
                  <input
                    id="branchAddressDetail"
                    type="text"
                    value={branchAddressDetail}
                    onChange={(e) => setBranchAddressDetail(e.target.value)}
                    placeholder="상세 주소를 입력하세요"
                    className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  />
                </div>
              </div>

              {/* 전화번호 */}
              <div>
                <label htmlFor="branchPhone" className="block text-gray-700 mb-2">
                  전화번호 *
                </label>
                <div className="relative">
                  <Phone className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    id="branchPhone"
                    type="tel"
                    value={branchPhone}
                    onChange={(e) => setBranchPhone(e.target.value)}
                    placeholder="02-1234-5678"
                    required
                    className="w-full pl-12 pr-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  />
                </div>
              </div>

              <button
                type="submit"
                className="w-full py-3 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity"
              >
                다음 단계
              </button>

              <div className="mt-6 pt-6 border-t border-gray-200">
                <p className="text-center text-gray-600">
                  이미 계정이 있으신가요?{' '}
                  <button
                    type="button"
                    onClick={onLoginClick || onBack}
                    className="text-green-600 hover:text-green-700 transition-colors font-medium"
                  >
                    로그인하기
                  </button>
                </p>
              </div>
            </form>
          )}

          {step === 2 && (
            <form onSubmit={handleSubmit} className="space-y-6">
              {/* 관리자 이름 */}
              <div>
                <label htmlFor="managerName" className="block text-gray-700 mb-2">
                  관리자 이름 *
                </label>
                <div className="relative">
                  <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    id="managerName"
                    type="text"
                    value={managerName}
                    onChange={(e) => setManagerName(e.target.value)}
                    placeholder="이름을 입력하세요"
                    required
                    className="w-full pl-12 pr-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  />
                </div>
              </div>

              {/* 로그인 ID */}
              <div>
                <label htmlFor="loginId" className="block text-gray-700 mb-2">
                  로그인 아이디 * (4자 이상)
                </label>
                <div className="flex gap-2">
                  <input
                    id="loginId"
                    type="text"
                    value={loginId}
                    onChange={(e) => {
                      setLoginId(e.target.value);
                      setIdCheckStatus('idle');
                    }}
                    placeholder="아이디를 입력하세요"
                    required
                    className="flex-1 px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  />
                  <button
                    type="button"
                    onClick={checkIdDuplicate}
                    disabled={idCheckStatus === 'checking'}
                    className={`px-4 py-3 rounded-lg font-medium transition-colors whitespace-nowrap ${
                      idCheckStatus === 'available'
                        ? 'bg-green-500 text-white'
                        : idCheckStatus === 'unavailable'
                        ? 'bg-red-500 text-white'
                        : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                    }`}
                  >
                    {idCheckStatus === 'checking' ? '확인중...' :
                     idCheckStatus === 'available' ? <CheckCircle2 className="w-5 h-5" /> :
                     idCheckStatus === 'unavailable' ? '사용불가' : '중복확인'}
                  </button>
                </div>
              </div>

              {/* 비밀번호 */}
              <div>
                <label htmlFor="password" className="block text-gray-700 mb-2">
                  비밀번호 * (6자 이상)
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
                    {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                  </button>
                </div>
              </div>

              {/* 비밀번호 확인 */}
              <div>
                <label htmlFor="passwordConfirm" className="block text-gray-700 mb-2">
                  비밀번호 확인 *
                </label>
                <div className="relative">
                  <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    id="passwordConfirm"
                    type={showPasswordConfirm ? 'text' : 'password'}
                    value={passwordConfirm}
                    onChange={(e) => setPasswordConfirm(e.target.value)}
                    placeholder="••••••••"
                    required
                    className="w-full pl-12 pr-12 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPasswordConfirm(!showPasswordConfirm)}
                    className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  >
                    {showPasswordConfirm ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                  </button>
                </div>
                {passwordConfirm && password !== passwordConfirm && (
                  <p className="text-red-500 text-sm mt-1">비밀번호가 일치하지 않습니다.</p>
                )}
              </div>

              {/* 관리자 전화번호 */}
              <div>
                <label htmlFor="managerPhone" className="block text-gray-700 mb-2">
                  관리자 전화번호 *
                </label>
                <div className="relative">
                  <Phone className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    id="managerPhone"
                    type="tel"
                    value={managerPhone}
                    onChange={(e) => setManagerPhone(e.target.value)}
                    placeholder="010-1234-5678"
                    required
                    className="w-full pl-12 pr-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  />
                </div>
              </div>

              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => setStep(1)}
                  className="flex-1 py-3 border-2 border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  이전
                </button>
                <button
                  type="submit"
                  disabled={isLoading}
                  className="flex-1 py-3 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isLoading ? '등록 중...' : '등록 완료'}
                </button>
              </div>
            </form>
          )}

          {step === 3 && (
            <div className="space-y-6">
              <p className="text-sm text-blue-600 bg-blue-50 p-3 rounded-lg">
                💡 데모데이터는 매장설정에서 수정 가능합니다.
              </p>

              {/* 타석 수 */}
              <div>
                <label htmlFor="tsCount" className="block text-gray-700 mb-2 font-medium">
                  타석 수 *
                </label>
                <input
                  id="tsCount"
                  type="number"
                  value={tsCount}
                  onChange={(e) => setTsCount(parseInt(e.target.value) || 0)}
                  min="1"
                  max="50"
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                />
              </div>

              {/* 타석 단가 */}
              <div>
                <label htmlFor="tsPrice" className="block text-gray-700 mb-2 font-medium">
                  타석 단가 (원) *
                </label>
                <input
                  id="tsPrice"
                  type="number"
                  value={tsPrice}
                  onChange={(e) => setTsPrice(parseInt(e.target.value) || 0)}
                  min="0"
                  step="1000"
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                />
                <p className="text-sm text-gray-500 mt-1">1시간 이용 요금</p>
              </div>

              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => setStep(2)}
                  className="flex-1 py-3 border-2 border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  이전
                </button>
                <button
                  type="button"
                  onClick={() => {
                    if (tsCount < 1) {
                      alert('시스템 기능을 테스트 하기 위해서 데모데이터 설정이 필요합니다.');
                      return;
                    }
                    setStep(4);
                  }}
                  className="flex-1 py-3 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity"
                >
                  다음
                </button>
              </div>
            </div>
          )}

          {step === 4 && (
            <div className="space-y-6">
              <p className="text-sm text-blue-600 bg-blue-50 p-3 rounded-lg">
                💡 데모데이터는 매장설정에서 수정 가능합니다.
              </p>

              <div className="space-y-4">
                {pros.map((pro, index) => {
                  const maleCerts = ['KPGA투어프로', 'KPGA프로', 'USGTF', '기타'];
                  const femaleCerts = ['KLPGA정회원', 'KLPGA준회원', 'KLPGA티칭프로', 'USGTF', '기타'];
                  const certOptions = pro.gender === 'male' ? maleCerts : femaleCerts;

                  return (
                    <div key={pro.id} className="p-5 border-2 border-gray-200 rounded-xl space-y-4 bg-gradient-to-br from-white to-gray-50 hover:border-green-300 transition-colors">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                            pro.shift === 'morning' ? 'bg-orange-100' : 'bg-indigo-100'
                          }`}>
                            <UserCheck className={`w-5 h-5 ${
                              pro.shift === 'morning' ? 'text-orange-600' : 'text-indigo-600'
                            }`} />
                          </div>
                          <span className="text-sm font-semibold text-gray-700">프로 {index + 1}</span>

                          <div className="flex gap-1.5 bg-gray-100 p-1 rounded-lg ml-2">
                            <button
                              type="button"
                              onClick={() => {
                                const updated = pros.map(p =>
                                  p.id === pro.id ? { ...p, gender: 'male', certification: 'KPGA투어프로' } : p
                                );
                                setPros(updated);
                              }}
                              className={`px-3 py-1 rounded-md text-xs font-medium transition-all ${
                                pro.gender === 'male'
                                  ? 'bg-white text-blue-600 shadow-sm'
                                  : 'text-gray-600 hover:text-gray-900'
                              }`}
                            >
                              남
                            </button>
                            <button
                              type="button"
                              onClick={() => {
                                const updated = pros.map(p =>
                                  p.id === pro.id ? { ...p, gender: 'female', certification: 'KLPGA정회원' } : p
                                );
                                setPros(updated);
                              }}
                              className={`px-3 py-1 rounded-md text-xs font-medium transition-all ${
                                pro.gender === 'female'
                                  ? 'bg-white text-pink-600 shadow-sm'
                                  : 'text-gray-600 hover:text-gray-900'
                              }`}
                            >
                              여
                            </button>
                          </div>

                          <select
                            value={pro.certification}
                            onChange={(e) => {
                              const updated = pros.map(p =>
                                p.id === pro.id ? { ...p, certification: e.target.value } : p
                              );
                              setPros(updated);
                            }}
                            className="px-3 py-1 text-xs bg-white border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500"
                          >
                            {certOptions.map(cert => (
                              <option key={cert} value={cert}>{cert}</option>
                            ))}
                          </select>
                        </div>
                        {pros.length > 1 && (
                          <button
                            type="button"
                            onClick={() => setPros(pros.filter(p => p.id !== pro.id))}
                            className="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        )}
                      </div>

                      <div className="flex gap-3">
                        <input
                          type="text"
                          value={pro.name}
                          onChange={(e) => {
                            const updated = pros.map(p =>
                              p.id === pro.id ? { ...p, name: e.target.value } : p
                            );
                            setPros(updated);
                          }}
                          placeholder="프로 이름"
                          className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500"
                        />

                        <div className="flex gap-2 bg-gray-100 p-1 rounded-lg">
                          <button
                            type="button"
                            onClick={() => {
                              const updated = pros.map(p =>
                                p.id === pro.id ? { ...p, shift: 'morning' } : p
                              );
                              setPros(updated);
                            }}
                            className={`px-4 py-1.5 rounded-md text-sm font-medium transition-all ${
                              pro.shift === 'morning'
                                ? 'bg-white text-orange-600 shadow-sm'
                                : 'text-gray-600 hover:text-gray-900'
                            }`}
                          >
                            오전
                          </button>
                          <button
                            type="button"
                            onClick={() => {
                              const updated = pros.map(p =>
                                p.id === pro.id ? { ...p, shift: 'afternoon' } : p
                              );
                              setPros(updated);
                            }}
                            className={`px-4 py-1.5 rounded-md text-sm font-medium transition-all ${
                              pro.shift === 'afternoon'
                                ? 'bg-white text-indigo-600 shadow-sm'
                                : 'text-gray-600 hover:text-gray-900'
                            }`}
                          >
                            오후
                          </button>
                        </div>
                      </div>

                      <div className="flex items-center gap-5">
                        <label className="text-xs font-medium text-gray-600 whitespace-nowrap">휴무일</label>
                        <div className="flex gap-1.5 flex-1">
                          {['일', '월', '화', '수', '목', '금', '토'].map((day, idx) => {
                            const isSelected = pro.offDays?.includes(day) || false;
                            return (
                              <button
                                key={day}
                                type="button"
                                onClick={() => {
                                  const updated = pros.map(p => {
                                    if (p.id === pro.id) {
                                      const currentOffDays = p.offDays || [];
                                      const newOffDays = isSelected
                                        ? currentOffDays.filter(d => d !== day)
                                        : [...currentOffDays, day];
                                      return { ...p, offDays: newOffDays };
                                    }
                                    return p;
                                  });
                                  setPros(updated);
                                }}
                                className={`flex-1 px-1.5 py-2 rounded-lg text-xs font-medium transition-all ${
                                  isSelected
                                    ? idx === 0
                                      ? 'bg-red-500 text-white shadow-md'
                                      : idx === 6
                                      ? 'bg-blue-500 text-white shadow-md'
                                      : 'bg-gray-700 text-white shadow-md'
                                    : idx === 0
                                    ? 'bg-red-50 text-red-300 border border-red-200'
                                    : idx === 6
                                    ? 'bg-blue-50 text-blue-300 border border-blue-200'
                                    : 'bg-gray-50 text-gray-400 border border-gray-200'
                                }`}
                              >
                                {day}
                              </button>
                            );
                          })}
                        </div>
                      </div>

                      <div className="grid grid-cols-3 gap-3">
                        <div>
                          <label className="block text-xs font-medium text-gray-600 mb-1">기본급 (원)</label>
                          <input
                            type="text"
                            value={formatNumber(pro.baseSalary)}
                            onChange={(e) => {
                              const updated = pros.map(p =>
                                p.id === pro.id ? { ...p, baseSalary: parseNumber(e.target.value) } : p
                              );
                              setPros(updated);
                            }}
                            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
                          />
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-600 mb-1">레슨단가 (원)</label>
                          <input
                            type="text"
                            value={formatNumber(pro.lessonFee)}
                            onChange={(e) => {
                              const updated = pros.map(p =>
                                p.id === pro.id ? { ...p, lessonFee: parseNumber(e.target.value) } : p
                              );
                              setPros(updated);
                            }}
                            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
                          />
                        </div>
                        <div>
                          <label className="block text-xs font-medium text-gray-600 mb-1">세션시간</label>
                          <select
                            value={pro.sessionTime}
                            onChange={(e) => {
                              const updated = pros.map(p =>
                                p.id === pro.id ? { ...p, sessionTime: parseInt(e.target.value) } : p
                              );
                              setPros(updated);
                            }}
                            className="w-full px-3 py-2 bg-white border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
                          >
                            <option value={15}>15분</option>
                            <option value={20}>20분</option>
                            <option value={25}>25분</option>
                            <option value={30}>30분</option>
                          </select>
                        </div>
                      </div>
                    </div>
                  );
                })}

                <button
                  type="button"
                  onClick={() => {
                    const newId = Math.max(...pros.map(p => p.id)) + 1;
                    setPros([...pros, { id: newId, name: '', shift: 'morning', baseSalary: 1000000, lessonFee: 13000, offDays: [], gender: 'male', certification: 'KPGA투어프로', sessionTime: 20 }]);
                  }}
                  className="w-full py-3 border-2 border-dashed border-gray-300 text-gray-600 rounded-lg hover:border-green-500 hover:text-green-600 hover:bg-green-50 transition-all font-medium"
                >
                  + 프로 추가
                </button>
              </div>

              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => setStep(3)}
                  className="flex-1 py-3 border-2 border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  이전
                </button>
                <button
                  type="button"
                  onClick={() => {
                    if (pros.length === 0 || pros.some(p => !p.name)) {
                      alert('시스템 기능을 테스트 하기 위해서 데모데이터 설정이 필요합니다.');
                      return;
                    }
                    setStep(5);
                  }}
                  className="flex-1 py-3 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity"
                >
                  다음
                </button>
              </div>
            </div>
          )}

          {step === 5 && (
            <div className="space-y-6">
              <p className="text-sm text-blue-600 bg-blue-50 p-3 rounded-lg">
                💡 데모데이터는 매장설정에서 수정 가능합니다.
              </p>

              <div className="space-y-4">
                {staff.map((person, index) => (
                  <div key={person.id} className="p-5 border-2 border-gray-200 rounded-xl space-y-4 bg-gradient-to-br from-white to-gray-50 hover:border-green-300 transition-colors">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full flex items-center justify-center bg-purple-100">
                          <User className="w-5 h-5 text-purple-600" />
                        </div>
                        <span className="text-sm font-semibold text-gray-700">직원 {index + 1}</span>
                        {person.isManager && (
                          <span className="px-2 py-0.5 bg-blue-100 text-blue-700 text-xs font-medium rounded">관리자</span>
                        )}
                      </div>
                      {staff.length > 1 && !person.isManager && (
                        <button
                          type="button"
                          onClick={() => setStaff(staff.filter(s => s.id !== person.id))}
                          className="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      )}
                    </div>

                    <div className="flex gap-3">
                      <input
                        type="text"
                        value={person.name}
                        onChange={(e) => {
                          if (person.isManager) return; // 관리자는 수정 불가
                          const updated = staff.map(s =>
                            s.id === person.id ? { ...s, name: e.target.value } : s
                          );
                          setStaff(updated);
                        }}
                        placeholder="직원 이름"
                        disabled={person.isManager}
                        className={`flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 ${
                          person.isManager ? 'bg-gray-100 cursor-not-allowed' : ''
                        }`}
                      />

                      <select
                        value={person.position}
                        onChange={(e) => {
                          const updated = staff.map(s =>
                            s.id === person.id ? { ...s, position: e.target.value } : s
                          );
                          setStaff(updated);
                        }}
                        className="px-4 py-2 bg-white border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
                      >
                        <option value="대표">대표</option>
                        <option value="실장">실장</option>
                        <option value="매니저">매니저</option>
                        <option value="Staff">Staff</option>
                        <option value="수습">수습</option>
                      </select>
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs font-medium text-gray-600 mb-1">기본급 (원)</label>
                        <input
                          type="text"
                          value={formatNumber(person.baseSalary)}
                          onChange={(e) => {
                            const updated = staff.map(s =>
                              s.id === person.id ? { ...s, baseSalary: parseNumber(e.target.value) } : s
                            );
                            setStaff(updated);
                          }}
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-600 mb-1">시급 (원)</label>
                        <input
                          type="text"
                          value={formatNumber(person.hourlyWage)}
                          onChange={(e) => {
                            const updated = staff.map(s =>
                              s.id === person.id ? { ...s, hourlyWage: parseNumber(e.target.value) } : s
                            );
                            setStaff(updated);
                          }}
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
                        />
                      </div>
                    </div>
                  </div>
                ))}

                <button
                  type="button"
                  onClick={() => {
                    const newId = Math.max(...staff.map(s => s.id)) + 1;
                    setStaff([...staff, { id: newId, name: '', position: 'Staff', baseSalary: 0, hourlyWage: 12000, isManager: false }]);
                  }}
                  className="w-full py-3 border-2 border-dashed border-gray-300 text-gray-600 rounded-lg hover:border-green-500 hover:text-green-600 hover:bg-green-50 transition-all font-medium"
                >
                  + 직원 추가
                </button>
              </div>

              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => setStep(4)}
                  className="flex-1 py-3 border-2 border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  이전
                </button>
                <button
                  type="button"
                  onClick={() => {
                    if (staff.length === 0 || staff.some(s => !s.name)) {
                      alert('시스템 기능을 테스트 하기 위해서 데모데이터 설정이 필요합니다.');
                      return;
                    }
                    // 완료 처리
                    alert('데모 데이터 설정이 완료되었습니다!\n로그인 페이지로 이동합니다.');
                    if (onLoginClick) {
                      onLoginClick();
                    } else {
                      onBack();
                    }
                  }}
                  className="flex-1 py-3 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity"
                >
                  완료
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
