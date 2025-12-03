import { useState } from 'react';
import { TermsOfService } from './TermsOfService';
import { PrivacyPolicy } from './PrivacyPolicy';

export function Footer() {
  const [showTerms, setShowTerms] = useState(false);
  const [showPrivacy, setShowPrivacy] = useState(false);

  return (
    <>
      <footer className="bg-gray-900 text-white py-12">
        <div className="container mx-auto px-4">
          <div className="text-center mb-6">
            <div className="text-sm text-gray-400 space-y-2">
              <p>주식회사 이네이블테크 | 대표 조스테파노</p>
              <p>서울시 양천구 신월로 376 8층 k16호</p>
              <p>사업자등록번호 746-87-03818 | 통신판매업신고번호: 신청중</p>
              <p>전화번호 02-6953-7398</p>
              <p className="mt-4">EnableTech Co., Ltd</p>
            </div>
          </div>

          <div className="flex justify-center gap-6 mb-6">
            <button
              onClick={() => setShowTerms(true)}
              className="text-sm text-gray-400 hover:text-white transition-colors underline"
            >
              서비스 이용약관
            </button>
            <span className="text-gray-600">|</span>
            <button
              onClick={() => setShowPrivacy(true)}
              className="text-sm text-gray-400 hover:text-white transition-colors underline"
            >
              개인정보 처리방침
            </button>
          </div>

          <div className="text-center text-sm text-gray-500">
            <p>Copyright &copy; 2025 EnableTech Co., Ltd. All rights reserved.</p>
          </div>
        </div>
      </footer>

      <TermsOfService isOpen={showTerms} onClose={() => setShowTerms(false)} />
      <PrivacyPolicy isOpen={showPrivacy} onClose={() => setShowPrivacy(false)} />
    </>
  );
}
