import 'package:flutter/material.dart';
import '../services/chat_eula_service.dart';

/// 채팅 EULA 동의 다이얼로그
/// Apple App Store 가이드라인 1.2 준수
class ChatEulaDialog extends StatefulWidget {
  const ChatEulaDialog({Key? key}) : super(key: key);

  /// 다이얼로그 표시 및 동의 여부 반환
  static Future<bool> show(BuildContext context) async {
    // 이미 동의했으면 바로 true 반환
    if (await ChatEulaService.hasAcceptedEula()) {
      return true;
    }

    // 동의 다이얼로그 표시
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ChatEulaDialog(),
    );

    return result ?? false;
  }

  @override
  State<ChatEulaDialog> createState() => _ChatEulaDialogState();
}

class _ChatEulaDialogState extends State<ChatEulaDialog> {
  bool _isChecked = false;
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToEnd) {
        setState(() {
          _hasScrolledToEnd = true;
        });
      }
    }
  }

  Future<void> _onAgree() async {
    if (!_isChecked) return;
    
    await ChatEulaService.acceptEula();
    Navigator.of(context).pop(true);
  }

  void _onDecline() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.policy_outlined, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '커뮤니티 이용약관',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            // 약관 내용
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.all(12),
                    child: Text(
                      ChatEulaService.getChatTermsContent(),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // 동의 체크박스
            InkWell(
              onTap: () {
                setState(() {
                  _isChecked = !_isChecked;
                });
              },
              child: Row(
                children: [
                  Checkbox(
                    value: _isChecked,
                    onChanged: (value) {
                      setState(() {
                        _isChecked = value ?? false;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                  Expanded(
                    child: Text(
                      '위 약관을 읽고 이해했으며, 이에 동의합니다.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 안내 문구
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '부적절한 콘텐츠 게시 시 서비스 이용이 제한될 수 있습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _onDecline,
          child: Text(
            '취소',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: _isChecked ? _onAgree : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: Text('동의 및 시작'),
        ),
      ],
    );
  }
}

