import { useState, useEffect } from 'react';
import * as PortOne from '@portone/browser-sdk/v2';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from './ui/dialog';
import { Button } from './ui/button';
import { Minus, Plus, FileText, CreditCard, RefreshCw, CheckCircle2 } from 'lucide-react';
import { SubscriptionTermsDialog } from './SubscriptionTermsDialog';
import { supabase } from '../lib/supabase';

interface PaymentDialogProps {
  isOpen: boolean;
  onClose: () => void;
  planName: string;
  monthlyPrice: number;
  userEmail?: string;
  userName?: string;
  companyName?: string;
}

// 포트원 설정
const STORE_ID = 'store-58c8f5b8-6bc6-4efb-8dd0-8a98475a4246';
const CHANNEL_KEY = 'channel-key-4ba942b1-404c-4b2b-86b5-143093f9d21f'; // 실연동 (MID: im_ineibl8beo)
// 정기결제용 채널키 (토스페이먼츠 테스트 MID: iamporttest_4)
const BILLING_CHANNEL_KEY = 'channel-key-1d9b30a1-2ce2-4879-adce-1420174d4e1a';

export function PaymentDialog({ 
  isOpen, 
  onClose, 
  planName, 
  monthlyPrice,
  userEmail = '',
  userName = '',
  companyName = ''
}: PaymentDialogProps) {
  const [months, setMonths] = useState(12);
  const [seatCount, setSeatCount] = useState(10);
  const [isProcessing, setIsProcessing] = useState(false);
  const [termsDialogOpen, setTermsDialogOpen] = useState(false);
  const [isAutoBilling, setIsAutoBilling] = useState(false);
  const [agreedToTerms, setAgreedToTerms] = useState(false);

  // 할인율 계산
  const getDiscountRate = (months: number): number => {
    if (months >= 12) return 0.2;
    if (months >= 6) return 0.1;
    return 0;
  };

  // 기본 금액 계산 (할인 전)
  const baseAmount = monthlyPrice * seatCount * months;

  // 할인 금액 계산
  const discountRate = getDiscountRate(months);
  const discountAmount = Math.floor(baseAmount * discountRate);

  // 최종 결제 금액
  const totalAmount = baseAmount - discountAmount;

  // 월 결제 금액 (자동결제용)
  const monthlyAmount = monthlyPrice * seatCount;

  // 할인율 텍스트
  const discountText = discountRate > 0 ? `${(discountRate * 100).toFixed(0)}% 할인` : '';

  // PG사 카드결제 한도 체크 (1000만원)
  const isOverLimit = totalAmount > 10000000;

  // 1개월 선택 시에만 자동결제 옵션 표시
  const showAutoBillingOption = months === 1;

  // 개월 변경 시 자동결제 옵션 초기화
  useEffect(() => {
    if (months !== 1) {
      setIsAutoBilling(false);
    }
  }, [months]);

  // 고유 ID 생성
  const generateId = (prefix: string) => {
    return `${prefix}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  };

  // 일회성 결제 처리
  const handleOneTimePayment = async () => {
    const paymentId = generateId('payment');
    const orderName = `${planName} 플랜 - ${seatCount}타석 ${months}개월`;

    try {
      const response = await PortOne.requestPayment({
        storeId: STORE_ID,
        channelKey: CHANNEL_KEY,
        paymentId: paymentId,
        orderName: orderName,
        totalAmount: totalAmount,
        currency: 'CURRENCY_KRW',
        payMethod: 'CARD',
        redirectUrl: `${window.location.origin}/payment-complete`,
      });

      if (response?.code) {
        throw new Error(response.message || '결제 실패');
      }

      // 구독 정보 저장
      const periodStart = new Date();
      const periodEnd = new Date();
      periodEnd.setMonth(periodEnd.getMonth() + months);
      const validEmail = getValidEmail();

      const { error: subscriptionError } = await supabase
        .from('v2_subscriptions')
        .insert({
          user_email: validEmail,
          user_name: userName,
          company_name: companyName,
          plan_name: planName,
          seat_count: seatCount,
          monthly_price: monthlyPrice,
          status: 'active',
          is_auto_billing: false,
          billing_cycle: months >= 12 ? 'yearly' : 'monthly',
          months: months,
          current_period_start: periodStart.toISOString(),
          current_period_end: periodEnd.toISOString(),
        });

      if (subscriptionError) {
        console.error('구독 정보 저장 오류:', subscriptionError);
      }

      // 결제 내역 저장
      const { error: paymentError } = await supabase
        .from('v2_subscription_payments')
        .insert({
          payment_id: paymentId,
          portone_tx_id: response?.txId,
          amount: totalAmount,
          discount_amount: discountAmount,
          base_amount: baseAmount,
          status: 'paid',
          plan_name: planName,
          seat_count: seatCount,
          months: months,
          is_auto_billing: false,
          paid_at: new Date().toISOString(),
          period_start: periodStart.toISOString(),
          period_end: periodEnd.toISOString(),
        });

      if (paymentError) {
        console.error('결제 내역 저장 오류:', paymentError);
      }

      alert('결제가 완료되었습니다.');
      return true;
    } catch (error) {
      console.error('결제 오류:', error);
      throw error;
    }
  };

  // 이메일 형식 검증
  const isValidEmail = (email: string) => {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  };

  // 유효한 이메일 생성 (없으면 임시 이메일 생성)
  const getValidEmail = () => {
    if (userEmail && isValidEmail(userEmail)) {
      return userEmail;
    }
    // 유효한 이메일이 없으면 타임스탬프 기반 임시 이메일 생성
    return `user_${Date.now()}@autogolfcrm.com`;
  };

  // 빌링키 발급 + 정기결제 처리
  const handleBillingKeyPayment = async () => {
    const customerId = generateId('customer');
    const billingKeyId = generateId('billing');
    const validEmail = getValidEmail();

    try {
      // 1. 빌링키 발급 요청
      const billingKeyResponse = await PortOne.requestIssueBillingKey({
        storeId: STORE_ID,
        channelKey: BILLING_CHANNEL_KEY,
        billingKeyMethod: 'CARD',
        issueId: billingKeyId,
        issueName: `${planName} 플랜 정기결제`,
        customer: {
          customerId: customerId,
          email: validEmail,
          fullName: userName || undefined,
        },
        redirectUrl: `${window.location.origin}/billing-complete`,
      });

      if (billingKeyResponse?.code) {
        throw new Error(billingKeyResponse.message || '빌링키 발급 실패');
      }

      const billingKey = billingKeyResponse?.billingKey;
      if (!billingKey) {
        throw new Error('빌링키를 받지 못했습니다.');
      }

      // 2. 구독 정보 저장
      const periodStart = new Date();
      const periodEnd = new Date();
      periodEnd.setMonth(periodEnd.getMonth() + 1);
      
      const nextBillingDate = new Date(periodEnd);

      const { data: subscription, error: subscriptionError } = await supabase
        .from('v2_subscriptions')
        .insert({
          user_email: validEmail,
          user_name: userName,
          company_name: companyName,
          plan_name: planName,
          seat_count: seatCount,
          monthly_price: monthlyPrice,
          billing_key: billingKey,
          customer_id: customerId,
          status: 'active',
          is_auto_billing: true,
          billing_cycle: 'monthly',
          months: 1,
          current_period_start: periodStart.toISOString(),
          current_period_end: periodEnd.toISOString(),
          next_billing_date: nextBillingDate.toISOString(),
        })
        .select()
        .single();

      if (subscriptionError) {
        console.error('구독 정보 저장 오류:', subscriptionError);
        throw new Error('구독 정보 저장 실패');
      }

      // 3. 빌링키 이력 저장
      await supabase
        .from('v2_billing_keys')
        .insert({
          subscription_id: subscription.id,
          billing_key: billingKey,
          customer_id: customerId,
          is_active: true,
        });

      // 4. 첫 결제 진행 (서버에서 처리해야 함 - 여기서는 결제 내역만 기록)
      // 실제로는 Edge Function에서 빌링키로 결제 요청
      const paymentId = generateId('payment');

      const { error: paymentError } = await supabase
        .from('v2_subscription_payments')
        .insert({
          subscription_id: subscription.id,
          payment_id: paymentId,
          amount: monthlyAmount,
          discount_amount: 0,
          base_amount: monthlyAmount,
          status: 'pending', // 서버에서 실제 결제 후 paid로 변경
          plan_name: planName,
          seat_count: seatCount,
          months: 1,
          is_auto_billing: true,
          period_start: periodStart.toISOString(),
          period_end: periodEnd.toISOString(),
        });

      if (paymentError) {
        console.error('결제 내역 저장 오류:', paymentError);
      }

      alert(`정기결제가 등록되었습니다.\n\n카드 등록이 완료되었으며, 매월 ${monthlyAmount.toLocaleString()}원이 자동 결제됩니다.\n\n첫 결제는 잠시 후 진행됩니다.`);
      return true;
    } catch (error) {
      console.error('빌링키 발급 오류:', error);
      throw error;
    }
  };

  // 결제 버튼 클릭
  const handlePayment = async () => {
    if (totalAmount <= 0 && !isAutoBilling) {
      alert('결제 금액이 올바르지 않습니다.');
      return;
    }

    if (!agreedToTerms) {
      alert('프로그램 구독약관에 동의해주세요.');
      return;
    }

    setIsProcessing(true);
    onClose();

    setTimeout(async () => {
      try {
        if (isAutoBilling) {
          await handleBillingKeyPayment();
        } else {
          await handleOneTimePayment();
        }
      } catch (error: unknown) {
        const errorMessage = error instanceof Error ? error.message : '알 수 없는 오류가 발생했습니다.';
        alert(`결제 실패: ${errorMessage}`);
      } finally {
        setIsProcessing(false);
      }
    }, 100);
  };

  // 다이얼로그 열릴 때 초기화
  useEffect(() => {
    if (isOpen) {
      setMonths(12);
      setSeatCount(10);
      setIsProcessing(false);
      setIsAutoBilling(false);
      setAgreedToTerms(false);
    }
  }, [isOpen]);

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-[520px] bg-white max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <CreditCard className="h-5 w-5 text-blue-500" />
            {planName} 플랜 구매
          </DialogTitle>
          <DialogDescription>
            구매 개월수와 타석수를 선택해주세요.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-6 py-4">
          {/* 구매 개월수 */}
          <div>
            <label className="text-sm font-medium text-gray-700 mb-2 block">
              구매 개월수
            </label>
            <div className="flex items-center gap-4">
              <Button
                variant="outline"
                size="icon"
                onClick={() => setMonths(Math.max(1, months - 1))}
                disabled={months <= 1}
              >
                <Minus className="h-4 w-4" />
              </Button>
              <div className="flex-1 text-center">
                <span className="text-2xl font-bold">{months}</span>
                <span className="text-gray-600 ml-2">개월</span>
                {discountText && (
                  <span className="ml-2 text-green-600 font-semibold">
                    ({discountText})
                  </span>
                )}
              </div>
              <Button
                variant="outline"
                size="icon"
                onClick={() => setMonths(Math.min(12, months + 1))}
                disabled={months >= 12}
              >
                <Plus className="h-4 w-4" />
              </Button>
            </div>
            {months === 6 && (
              <p className="text-xs text-green-600 mt-2 text-center">6개월 구매 시 10% 할인 적용</p>
            )}
            {months === 12 && (
              <p className="text-xs text-green-600 mt-2 text-center">12개월 구매 시 20% 할인 적용</p>
            )}
          </div>

          {/* 타석수 */}
          <div>
            <label className="text-sm font-medium text-gray-700 mb-2 block">
              타석수
            </label>
            <div className="flex items-center gap-4">
              <Button
                variant="outline"
                size="icon"
                onClick={() => setSeatCount(Math.max(1, seatCount - 1))}
                disabled={seatCount <= 1}
              >
                <Minus className="h-4 w-4" />
              </Button>
              <div className="flex-1 text-center">
                <span className="text-2xl font-bold">{seatCount}</span>
                <span className="text-gray-600 ml-2">타석</span>
              </div>
              <Button
                variant="outline"
                size="icon"
                onClick={() => setSeatCount(seatCount + 1)}
              >
                <Plus className="h-4 w-4" />
              </Button>
            </div>
          </div>

          {/* 자동결제 옵션 (1개월 선택 시에만 표시) */}
          {showAutoBillingOption && (
            <div className="bg-gradient-to-r from-blue-50 to-cyan-50 border border-blue-200 rounded-lg p-4">
              <label className="flex items-start gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={isAutoBilling}
                  onChange={(e) => setIsAutoBilling(e.target.checked)}
                  className="mt-1 h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                />
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <RefreshCw className="h-4 w-4 text-blue-600" />
                    <span className="font-medium text-gray-900">매월 자동결제</span>
                  </div>
                  <p className="text-sm text-gray-600 mt-1">
                    매월 <strong>{monthlyAmount.toLocaleString()}원</strong>이 자동으로 결제됩니다.
                    <br />
                    <span className="text-xs text-gray-500">언제든지 해지 가능합니다.</span>
                  </p>
                </div>
              </label>
            </div>
          )}

          {/* 결제 금액 정보 */}
          <div className="border-t pt-4 space-y-2">
            {isAutoBilling ? (
              <>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">월 결제 금액</span>
                  <span className="text-gray-900">
                    {monthlyAmount.toLocaleString()}원
                  </span>
                </div>
                <div className="flex justify-between text-lg font-bold pt-2 border-t">
                  <span>첫 결제 금액</span>
                  <span className="text-blue-600">
                    {monthlyAmount.toLocaleString()}원
                  </span>
                </div>
                <p className="text-xs text-gray-500 mt-2">
                  * 다음 달부터 매월 같은 날짜에 자동 결제됩니다.
                </p>
              </>
            ) : (
              <>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">기본 금액</span>
                  <span className="text-gray-900">
                    {baseAmount.toLocaleString()}원
                  </span>
                </div>
                {discountAmount > 0 && (
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-600">할인 금액</span>
                    <span className="text-green-600">
                      -{discountAmount.toLocaleString()}원
                    </span>
                  </div>
                )}
                <div className="flex justify-between text-lg font-bold pt-2 border-t">
                  <span>최종 결제 금액</span>
                  <span className="text-blue-600">
                    {totalAmount.toLocaleString()}원
                  </span>
                </div>
              </>
            )}
          </div>

          {/* 약관 동의 */}
          <div className="border-t pt-4">
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={agreedToTerms}
                onChange={(e) => setAgreedToTerms(e.target.checked)}
                className="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              />
              <span className="text-sm text-gray-700">
                <button
                  type="button"
                  onClick={() => setTermsDialogOpen(true)}
                  className="text-blue-600 underline hover:text-blue-800"
                >
                  프로그램 구독약관
                </button>
                에 동의합니다.
              </span>
            </label>
            {isAutoBilling && (
              <p className="text-xs text-gray-500 mt-2 ml-6">
                * 정기결제 등록 시 카드 정보가 안전하게 저장되며, 매월 자동 결제됩니다.
              </p>
            )}
          </div>
        </div>

        {isOverLimit && !isAutoBilling ? (
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <h4 className="font-semibold text-yellow-900 mb-2">
              💳 1천만원 이상 거래 안내
            </h4>
            <p className="text-sm text-yellow-800 mb-3">
              카드결제는 1천만원까지만 가능합니다.<br />
              1천만원 이상 거래는 <strong>계좌이체 및 세금계산서 발행</strong>으로 진행됩니다.
            </p>
            <p className="text-sm text-yellow-900 font-semibold">
              📞 고객센터로 문의주세요: <a href="tel:02-6953-7398" className="text-blue-600 underline">02-6953-7398</a>
            </p>
          </div>
        ) : null}

        <DialogFooter className="flex-row justify-end gap-2">
          <Button variant="outline" onClick={onClose} disabled={isProcessing}>
            취소
          </Button>
          {(!isOverLimit || isAutoBilling) && (
            <Button
              onClick={handlePayment}
              disabled={isProcessing || (!isAutoBilling && totalAmount <= 0) || !agreedToTerms}
              className="bg-gradient-to-r from-blue-500 to-cyan-500 hover:opacity-90 gap-2"
            >
              {isProcessing ? (
                '처리 중...'
              ) : isAutoBilling ? (
                <>
                  <CheckCircle2 className="h-4 w-4" />
                  정기결제 등록
                </>
              ) : (
                '결제하기'
              )}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>

      <SubscriptionTermsDialog
        isOpen={termsDialogOpen}
        onClose={() => setTermsDialogOpen(false)}
      />
    </Dialog>
  );
}
