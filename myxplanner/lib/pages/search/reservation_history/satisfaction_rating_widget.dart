import 'package:flutter/material.dart';

class SatisfactionRatingWidget extends StatefulWidget {
  final String reservationId;
  final Function(int rating, String feedback)? onSubmit;

  const SatisfactionRatingWidget({
    Key? key,
    required this.reservationId,
    this.onSubmit,
  }) : super(key: key);

  @override
  State<SatisfactionRatingWidget> createState() => _SatisfactionRatingWidgetState();
}

class _SatisfactionRatingWidgetState extends State<SatisfactionRatingWidget> {
  int _rating = 0;
  bool _isSubmitting = false;

  Widget _buildStar(int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _rating = index;
        });
      },
      child: Icon(
        index <= _rating ? Icons.star : Icons.star_border,
        size: 36,
        color: index <= _rating ? Colors.amber : Colors.grey[400],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[600]!, Colors.blue[800]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rate_review, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                '이용 만족도 평가',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // 별점 선택
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '오늘의 경험은 어떠셨나요?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) => _buildStar(index + 1)),
                ),
                if (_rating > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    _getRatingText(_rating),
                    style: TextStyle(
                      fontSize: 14,
                      color: _getRatingColor(_rating),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          
          const SizedBox(height: 20),
          
          // 제출 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _rating > 0 && !_isSubmitting
                  ? () async {
                      setState(() {
                        _isSubmitting = true;
                      });
                      
                      // 콜백 호출
                      if (widget.onSubmit != null) {
                        await widget.onSubmit!(_rating, '');
                      }
                      
                      // 성공 메시지 (로그로 출력)
                      print('평가가 완료되었습니다. 평점: $_rating');
                      
                      setState(() {
                        _isSubmitting = false;
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: Colors.white.withOpacity(0.5),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                      ),
                    )
                  : Text(
                      '평가 제출',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return '매우 불만족';
      case 2:
        return '불만족';
      case 3:
        return '보통';
      case 4:
        return '만족';
      case 5:
        return '매우 만족';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red[600]!;
      case 2:
        return Colors.orange[600]!;
      case 3:
        return Colors.yellow[700]!;
      case 4:
        return Colors.lightGreen[600]!;
      case 5:
        return Colors.green[600]!;
      default:
        return Colors.grey[600]!;
    }
  }
}