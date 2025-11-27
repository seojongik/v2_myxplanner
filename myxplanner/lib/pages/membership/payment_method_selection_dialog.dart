import 'package:flutter/material.dart';
import '../../services/portone_payment_service.dart';

/// 결제 수단 선택 결과
class PaymentMethodSelection {
  final String channelKey;
  final String payMethod;
  final String providerName;

  PaymentMethodSelection({
    required this.channelKey,
    required this.payMethod,
    required this.providerName,
  });
}

/// 결제 수단 선택 다이얼로그
class PaymentMethodSelectionDialog extends StatelessWidget {
  const PaymentMethodSelectionDialog({Key? key}) : super(key: key);

  static Future<PaymentMethodSelection?> show(BuildContext context) {
    return showDialog<PaymentMethodSelection>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PaymentMethodSelectionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '결제 수단 선택',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 24),
            
            // 신용카드 선택
            _PaymentMethodCard(
              icon: Icons.credit_card,
              title: '신용카드',
              subtitle: '한국결제네트웍스',
              color: Color(0xFF3B82F6),
              onTap: () {
                Navigator.of(context).pop(PaymentMethodSelection(
                  channelKey: PortonePaymentService.kpnChannelKey,
                  payMethod: 'CARD',
                  providerName: 'KPN',
                ));
              },
            ),
            
            SizedBox(height: 12),
            
            // 간편결제 선택
            _PaymentMethodCard(
              icon: Icons.payment,
              title: '간편결제',
              subtitle: '카카오페이 / 네이버페이',
              color: Color(0xFF10B981),
              onTap: () {
                // 간편결제 상세 선택 다이얼로그 열기
                _showEasyPaySelection(context);
              },
            ),
            
            SizedBox(height: 24),
            
            // 취소 버튼
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '취소',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEasyPaySelection(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '간편결제 선택',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              SizedBox(height: 24),
              
              // 카카오페이
              _PaymentMethodCard(
                icon: Icons.payment,
                title: '카카오페이',
                subtitle: '카카오페이로 결제',
                color: Color(0xFFFEE500),
                textColor: Color(0xFF000000),
                onTap: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop(PaymentMethodSelection(
                  channelKey: PortonePaymentService.kakaoPayChannelKey,
                  payMethod: 'EASY_PAY',
                  providerName: 'KAKAOPAY',
                ));
                },
              ),
              
              SizedBox(height: 12),
              
              // 네이버페이
              _PaymentMethodCard(
                icon: Icons.payment,
                title: '네이버페이',
                subtitle: '네이버페이로 결제',
                color: Color(0xFF03C75A),
                onTap: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop(PaymentMethodSelection(
                  channelKey: PortonePaymentService.naverPayChannelKey,
                  payMethod: 'EASY_PAY',
                  providerName: 'NAVERPAY',
                ));
                },
              ),
              
              SizedBox(height: 24),
              
              // 뒤로가기 버튼
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    '뒤로',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color? textColor;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor?.withOpacity(0.7) ?? Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

