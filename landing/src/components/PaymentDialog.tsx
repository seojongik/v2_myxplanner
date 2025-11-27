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
import { Minus, Plus, FileText } from 'lucide-react';
import { SubscriptionTermsDialog } from './SubscriptionTermsDialog';

interface PaymentDialogProps {
  isOpen: boolean;
  onClose: () => void;
  planName: string;
  monthlyPrice: number; // 타석당 월 가격
}

const STORE_ID = 'store-58c8f5b8-6bc6-4efb-8dd0-8a98475a4246';
const CHANNEL_KEY = 'channel-key-4103c2a4-ab14-4707-bdb3-6c6254511ba0';

export function PaymentDialog({ isOpen, onClose, planName, monthlyPrice }: PaymentDialogProps) {
  const [months, setMonths] = useState(12);
  const [seatCount, setSeatCount] = useState(10);
  const [isProcessing, setIsProcessing] = useState(false);
  const [termsDialogOpen, setTermsDialogOpen] = useState(false);

  // 할인율 계산
  const getDiscountRate = (months: number): number => {
    if (months >= 12) return 0.2; // 20% 할인
    if (months >= 6) return 0.1; // 10% 할인
    return 0;
  };

  // 기본 금액 계산 (할인 전)
  const baseAmount = monthlyPrice * seatCount * months;

  // 할인 금액 계산
  const discountRate = getDiscountRate(months);
  const discountAmount = Math.floor(baseAmount * discountRate);

  // 최종 결제 금액
  const totalAmount = baseAmount - discountAmount;

  // 할인율 텍스트
  const discountText = discountRate > 0 ? `${(discountRate * 100).toFixed(0)}% 할인` : '';

  // PG사 카드결제 한도 체크 (1000만원)
  const isOverLimit = totalAmount > 10000000;

  const handlePayment = async () => {
    if (totalAmount <= 0) {
      alert('결제 금액이 올바르지 않습니다.');
      return;
    }

    setIsProcessing(true);
    
    // 결제창이 제대로 표시되도록 Dialog를 먼저 닫습니다
    onClose();

    try {
      const paymentId = `payment-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      const orderName = `${planName} 플랜 - ${seatCount}타석 ${months}개월`;

      // Dialog가 완전히 닫힌 후 결제 요청
      setTimeout(async () => {
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
            // 결제 실패
            alert(`결제 실패: ${response.message || '알 수 없는 오류가 발생했습니다.'}`);
            setIsProcessing(false);
            return;
          }

          // 결제 성공 또는 리다이렉트
          // redirectUrl로 이동하는 경우 response가 없을 수 있음
          // 실제 결제 완료는 웹훅이나 리다이렉트 페이지에서 처리해야 함
          
          // 결제 완료 처리 (서버에 결제 정보 전송)
          const apiUrl = import.meta.env.DEV
            ? '/dynamic_api.php'
            : 'https://autofms.mycafe24.com/dynamic_api.php';

          try {
            await fetch(apiUrl, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: JSON.stringify({
                operation: 'payment_complete',
                paymentId: paymentId,
                planName: planName,
                seatCount: seatCount,
                months: months,
                totalAmount: totalAmount,
                discountAmount: discountAmount,
                baseAmount: baseAmount,
              }),
            });
          } catch (error) {
            console.error('결제 정보 저장 오류:', error);
            // 결제는 성공했지만 정보 저장 실패 - 사용자에게 알림
          }

          alert('결제가 완료되었습니다.');
        } catch (error) {
          console.error('결제 오류:', error);
          alert('결제 중 오류가 발생했습니다. 다시 시도해주세요.');
          setIsProcessing(false);
        }
      }, 100);
    } catch (error) {
      console.error('결제 초기화 오류:', error);
      alert('결제 중 오류가 발생했습니다. 다시 시도해주세요.');
      setIsProcessing(false);
    }
  };

  // 다이얼로그가 열릴 때 기본값 설정, 닫힐 때 초기화
  useEffect(() => {
    if (isOpen) {
      setMonths(12);
      setSeatCount(10);
      setIsProcessing(false);
    }
  }, [isOpen]);

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-[500px] bg-white">
        <DialogHeader>
          <DialogTitle>{planName} 플랜 구매</DialogTitle>
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
              <p className="text-xs text-green-600 mt-2">6개월 구매 시 10% 할인 적용</p>
            )}
            {months === 12 && (
              <p className="text-xs text-green-600 mt-2">12개월 구매 시 20% 할인 적용</p>
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

          {/* 결제 금액 정보 */}
          <div className="border-t pt-4 space-y-2">
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
          </div>
        </div>

        {/* 프로그램 구독약관 버튼 - 최종결제금액 아래, 버튼 왼쪽 */}
        <div className="border-t pt-4 pb-4">
          <div className="flex items-start justify-between gap-4">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setTermsDialogOpen(true)}
              className="text-left text-xs text-gray-600 hover:text-gray-900 p-0 h-auto font-normal"
            >
              <FileText className="h-4 w-4 mr-2 flex-shrink-0" />
              <span className="underline">프로그램 구독약관 보기</span>
            </Button>
          </div>
        </div>

        {isOverLimit ? (
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
          {!isOverLimit && (
            <Button
              onClick={handlePayment}
              disabled={isProcessing || totalAmount <= 0}
              className="bg-gradient-to-r from-blue-500 to-cyan-500 hover:opacity-90"
            >
              {isProcessing ? '결제 진행 중...' : '결제하기'}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>

      {/* 약관 다이얼로그 */}
      <SubscriptionTermsDialog
        isOpen={termsDialogOpen}
        onClose={() => setTermsDialogOpen(false)}
      />
    </Dialog>
  );
}

