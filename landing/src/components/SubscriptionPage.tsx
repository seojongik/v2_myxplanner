import { useState, useEffect } from 'react';
import {
  CreditCard,
  Calendar,
  Package,
  RefreshCw,
  AlertCircle,
  CheckCircle,
  XCircle,
  ChevronRight,
  Settings,
  Receipt,
  Clock,
} from 'lucide-react';
import { Button } from './ui/button';
import { supabase } from '../lib/supabase';

interface Subscription {
  id: string;
  plan_name: string;
  seat_count: number;
  monthly_price: number;
  status: string;
  is_auto_billing: boolean;
  billing_cycle: string;
  months: number;
  current_period_start: string;
  current_period_end: string;
  next_billing_date: string | null;
  card_last_four: string | null;
  card_company: string | null;
  created_at: string;
}

interface Payment {
  id: string;
  payment_id: string;
  amount: number;
  status: string;
  plan_name: string;
  seat_count: number;
  months: number;
  is_auto_billing: boolean;
  paid_at: string | null;
  created_at: string;
  period_start: string;
  period_end: string;
}

interface SubscriptionPageProps {
  userEmail: string;
  onClose: () => void;
}

export function SubscriptionPage({ userEmail, onClose }: SubscriptionPageProps) {
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'overview' | 'payments'>('overview');
  const [cancelling, setCancelling] = useState(false);

  // 구독 정보 로드
  useEffect(() => {
    loadSubscriptionData();
  }, [userEmail]);

  const loadSubscriptionData = async () => {
    setLoading(true);
    try {
      // 이메일이 없거나 유효하지 않으면 조회하지 않음
      if (!userEmail || userEmail.length < 3) {
        setLoading(false);
        return;
      }

      // 구독 정보 조회 (이메일에 @가 포함되어 있으면 정확한 이메일로, 아니면 like 검색)
      let subscriptionQuery = supabase
        .from('v2_subscriptions')
        .select('*')
        .eq('status', 'active')
        .order('created_at', { ascending: false })
        .limit(1);

      if (userEmail.includes('@')) {
        subscriptionQuery = subscriptionQuery.eq('user_email', userEmail);
      } else {
        // branch_id 등 이메일 형식이 아닌 경우 like 검색
        subscriptionQuery = subscriptionQuery.ilike('user_email', `%${userEmail}%`);
      }

      const { data: subData, error: subError } = await subscriptionQuery.single();

      if (!subError && subData) {
        setSubscription(subData);

        // 구독이 있을 때만 결제 내역 조회
        const { data: payData, error: payError } = await supabase
          .from('v2_subscription_payments')
          .select('*')
          .eq('subscription_id', subData.id)
          .order('created_at', { ascending: false });

        if (!payError && payData) {
          setPayments(payData);
        }
      } else {
        // 구독 정보가 없으면 전체 결제 내역에서 user_email로 검색
        // (구독 없이 일회성 결제만 한 경우 대비)
        setSubscription(null);
        setPayments([]);
      }
    } catch (error) {
      console.error('구독 정보 로드 오류:', error);
    } finally {
      setLoading(false);
    }
  };

  // 구독 해지
  const handleCancelSubscription = async () => {
    if (!subscription) return;

    const confirmed = confirm(
      '정말 구독을 해지하시겠습니까?\n\n' +
      '해지하더라도 현재 결제 기간이 끝날 때까지 서비스를 이용하실 수 있습니다.'
    );

    if (!confirmed) return;

    setCancelling(true);
    try {
      const { error } = await supabase
        .from('v2_subscriptions')
        .update({
          status: 'cancelled',
          cancelled_at: new Date().toISOString(),
        })
        .eq('id', subscription.id);

      if (error) throw error;

      alert('구독이 해지되었습니다.\n현재 결제 기간이 끝날 때까지 서비스를 이용하실 수 있습니다.');
      loadSubscriptionData();
    } catch (error) {
      console.error('구독 해지 오류:', error);
      alert('구독 해지 중 오류가 발생했습니다.');
    } finally {
      setCancelling(false);
    }
  };

  // 날짜 포맷
  const formatDate = (dateString: string | null) => {
    if (!dateString) return '-';
    return new Date(dateString).toLocaleDateString('ko-KR', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  };

  // 상태 뱃지
  const StatusBadge = ({ status }: { status: string }) => {
    const statusConfig: Record<string, { color: string; icon: typeof CheckCircle; text: string }> = {
      active: { color: 'bg-green-100 text-green-800', icon: CheckCircle, text: '이용중' },
      cancelled: { color: 'bg-red-100 text-red-800', icon: XCircle, text: '해지됨' },
      expired: { color: 'bg-gray-100 text-gray-800', icon: Clock, text: '만료됨' },
      paused: { color: 'bg-yellow-100 text-yellow-800', icon: AlertCircle, text: '일시정지' },
      pending: { color: 'bg-blue-100 text-blue-800', icon: Clock, text: '대기중' },
      paid: { color: 'bg-green-100 text-green-800', icon: CheckCircle, text: '결제완료' },
      failed: { color: 'bg-red-100 text-red-800', icon: XCircle, text: '결제실패' },
    };

    const config = statusConfig[status] || statusConfig.pending;
    const Icon = config.icon;

    return (
      <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium ${config.color}`}>
        <Icon className="w-3 h-3" />
        {config.text}
      </span>
    );
  };

  if (loading) {
    return (
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div className="bg-white rounded-2xl p-8 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
          <div className="flex items-center justify-center py-12">
            <RefreshCw className="w-8 h-8 animate-spin text-blue-500" />
            <span className="ml-3 text-gray-600">로딩 중...</span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-2xl max-w-3xl w-full mx-4 max-h-[90vh] overflow-hidden shadow-2xl">
        {/* 헤더 */}
        <div className="bg-gradient-to-r from-blue-500 to-cyan-500 text-white p-6">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-2xl font-bold mb-1">구독 관리</h2>
              <p className="text-blue-100">{userEmail}</p>
            </div>
            <button
              onClick={onClose}
              className="text-white/80 hover:text-white transition-colors"
            >
              <XCircle className="w-8 h-8" />
            </button>
          </div>
        </div>

        {/* 탭 */}
        <div className="border-b border-gray-200">
          <div className="flex">
            <button
              onClick={() => setActiveTab('overview')}
              className={`flex-1 py-4 text-center font-medium transition-colors ${
                activeTab === 'overview'
                  ? 'text-blue-600 border-b-2 border-blue-600'
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              <Package className="w-4 h-4 inline-block mr-2" />
              구독 현황
            </button>
            <button
              onClick={() => setActiveTab('payments')}
              className={`flex-1 py-4 text-center font-medium transition-colors ${
                activeTab === 'payments'
                  ? 'text-blue-600 border-b-2 border-blue-600'
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              <Receipt className="w-4 h-4 inline-block mr-2" />
              결제 내역
            </button>
          </div>
        </div>

        {/* 컨텐츠 */}
        <div className="p-6 overflow-y-auto max-h-[calc(90vh-200px)]">
          {activeTab === 'overview' && (
            <div className="space-y-6">
              {subscription ? (
                <>
                  {/* 현재 플랜 */}
                  <div className="bg-gradient-to-br from-gray-50 to-blue-50 rounded-xl p-6 border border-gray-200">
                    <div className="flex items-start justify-between mb-4">
                      <div>
                        <div className="flex items-center gap-3 mb-2">
                          <h3 className="text-xl font-bold text-gray-900">
                            {subscription.plan_name} 플랜
                          </h3>
                          <StatusBadge status={subscription.status} />
                        </div>
                        <p className="text-gray-600">
                          {subscription.seat_count}타석 ·{' '}
                          {subscription.is_auto_billing ? '월 자동결제' : `${subscription.months}개월 선불`}
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="text-2xl font-bold text-blue-600">
                          {(subscription.monthly_price * subscription.seat_count).toLocaleString()}원
                        </p>
                        <p className="text-sm text-gray-500">
                          {subscription.is_auto_billing ? '/ 월' : '/ 총'}
                        </p>
                      </div>
                    </div>

                    {/* 구독 정보 */}
                    <div className="grid grid-cols-2 gap-4 pt-4 border-t border-gray-200">
                      <div className="flex items-center gap-3">
                        <Calendar className="w-5 h-5 text-gray-400" />
                        <div>
                          <p className="text-xs text-gray-500">이용 기간</p>
                          <p className="text-sm font-medium text-gray-900">
                            {formatDate(subscription.current_period_start)} ~{' '}
                            {formatDate(subscription.current_period_end)}
                          </p>
                        </div>
                      </div>

                      {subscription.is_auto_billing && subscription.next_billing_date && (
                        <div className="flex items-center gap-3">
                          <RefreshCw className="w-5 h-5 text-gray-400" />
                          <div>
                            <p className="text-xs text-gray-500">다음 결제일</p>
                            <p className="text-sm font-medium text-gray-900">
                              {formatDate(subscription.next_billing_date)}
                            </p>
                          </div>
                        </div>
                      )}

                      {subscription.card_last_four && (
                        <div className="flex items-center gap-3">
                          <CreditCard className="w-5 h-5 text-gray-400" />
                          <div>
                            <p className="text-xs text-gray-500">결제 카드</p>
                            <p className="text-sm font-medium text-gray-900">
                              {subscription.card_company || '카드'} ****{subscription.card_last_four}
                            </p>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* 액션 버튼 */}
                  <div className="space-y-3">
                    {subscription.is_auto_billing && subscription.status === 'active' && (
                      <button
                        className="w-full flex items-center justify-between p-4 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
                      >
                        <div className="flex items-center gap-3">
                          <CreditCard className="w-5 h-5 text-gray-400" />
                          <span className="text-gray-700">결제수단 변경</span>
                        </div>
                        <ChevronRight className="w-5 h-5 text-gray-400" />
                      </button>
                    )}

                    <button
                      className="w-full flex items-center justify-between p-4 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
                    >
                      <div className="flex items-center gap-3">
                        <Settings className="w-5 h-5 text-gray-400" />
                        <span className="text-gray-700">플랜 변경</span>
                      </div>
                      <ChevronRight className="w-5 h-5 text-gray-400" />
                    </button>

                    {subscription.status === 'active' && (
                      <button
                        onClick={handleCancelSubscription}
                        disabled={cancelling}
                        className="w-full flex items-center justify-between p-4 bg-white border border-red-200 rounded-lg hover:bg-red-50 transition-colors text-red-600"
                      >
                        <div className="flex items-center gap-3">
                          <XCircle className="w-5 h-5" />
                          <span>{cancelling ? '처리 중...' : '구독 해지'}</span>
                        </div>
                        <ChevronRight className="w-5 h-5" />
                      </button>
                    )}
                  </div>
                </>
              ) : (
                <div className="text-center py-12">
                  <Package className="w-16 h-16 text-gray-300 mx-auto mb-4" />
                  <h3 className="text-lg font-medium text-gray-900 mb-2">
                    활성 구독이 없습니다
                  </h3>
                  <p className="text-gray-500 mb-6">
                    플랜을 선택하여 서비스를 시작하세요.
                  </p>
                  <Button
                    onClick={onClose}
                    className="bg-gradient-to-r from-blue-500 to-cyan-500"
                  >
                    플랜 보기
                  </Button>
                </div>
              )}
            </div>
          )}

          {activeTab === 'payments' && (
            <div className="space-y-4">
              {payments.length > 0 ? (
                payments.map((payment) => (
                  <div
                    key={payment.id}
                    className="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-sm transition-shadow"
                  >
                    <div className="flex items-start justify-between">
                      <div>
                        <div className="flex items-center gap-2 mb-1">
                          <h4 className="font-medium text-gray-900">
                            {payment.plan_name} 플랜
                          </h4>
                          <StatusBadge status={payment.status} />
                        </div>
                        <p className="text-sm text-gray-500">
                          {payment.seat_count}타석 · {payment.is_auto_billing ? '월 자동결제' : `${payment.months}개월`}
                        </p>
                        <p className="text-xs text-gray-400 mt-1">
                          {formatDate(payment.period_start)} ~ {formatDate(payment.period_end)}
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="text-lg font-bold text-gray-900">
                          {payment.amount.toLocaleString()}원
                        </p>
                        <p className="text-xs text-gray-500">
                          {payment.paid_at ? formatDate(payment.paid_at) : formatDate(payment.created_at)}
                        </p>
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="text-center py-12">
                  <Receipt className="w-16 h-16 text-gray-300 mx-auto mb-4" />
                  <h3 className="text-lg font-medium text-gray-900 mb-2">
                    결제 내역이 없습니다
                  </h3>
                  <p className="text-gray-500">
                    아직 결제 내역이 없습니다.
                  </p>
                </div>
              )}
            </div>
          )}
        </div>

        {/* 푸터 */}
        <div className="border-t border-gray-200 p-4 bg-gray-50">
          <div className="flex items-center justify-between text-sm text-gray-500">
            <p>문의: 02-6953-7398</p>
            <Button variant="outline" onClick={onClose}>
              닫기
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}

