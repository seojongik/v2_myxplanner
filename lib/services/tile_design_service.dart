import 'package:flutter/material.dart';

class TileDesignService {
  // 색상 팔레트 정의 (순서대로 적용)
  static final List<Color> colorPalette = [
    Color(0xFF00A86B), // 초록색
    Color(0xFF2196F3), // 파란색
    Color(0xFFFF8C00), // 주황색
    Color(0xFF8E44AD), // 보라색
    Color(0xFFE74C3C), // 빨간색
    Color(0xFF1ABC9C), // 청록색
    Color(0xFFF39C12), // 노란색
    Color(0xFF9B59B6), // 자주색
  ];

  // 인덱스에 따른 색상 반환
  static Color getColorByIndex(int index) {
    return colorPalette[index % colorPalette.length];
  }

  // 공통 타일 위젯 생성
  static Widget buildTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isEnabled = true,
    String? disabledMessage,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // 회원권 스타일: 아이콘 + 텍스트 수직 구조
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? color.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 36,
                          color: isEnabled ? color : Colors.grey,
                        ),
                      ),
                      SizedBox(height: 12),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isEnabled ? Color(0xFF1F2937) : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // 비활성화 상태 표시
                if (!isEnabled)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[400],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '회원권 필요',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 공통 그리드 위젯 생성 (자동 색상 적용)
  static Widget buildGrid({
    required List<Map<String, dynamic>> items,
    required Function(String) onItemTap,
  }) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2열
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0, // 정사각형 (회원권 스타일)
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final color = getColorByIndex(index); // 인덱스별 자동 색상
          final isEnabled = item['isEnabled'] ?? true; // 활성화 상태 (기본값: true)
          final disabledMessage = item['disabledMessage'] as String?;

          return buildTile(
            title: item['title'],
            icon: item['icon'],
            color: color,
            onTap: () => onItemTap(item['type']),
            isEnabled: isEnabled,
            disabledMessage: disabledMessage,
          );
        },
      ),
    );
  }

  // 공통 로딩 위젯
  static Widget buildLoading({
    required String title,
    required String message,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A86B)),
          strokeWidth: 2.5,
        ),
        SizedBox(height: 20),
        Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF8E8E8E),
          ),
        ),
      ],
    );
  }

  // 공통 에러 위젯
  static Widget buildError({
    required String errorMessage,
    required VoidCallback onRetry,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: Color(0xFFE74C3C),
        ),
        SizedBox(height: 16),
        Text(
          '문제가 발생했습니다',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
          ),
        ),
        SizedBox(height: 8),
        Text(
          errorMessage,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF8E8E8E),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF00A86B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            '다시 시도',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
} 