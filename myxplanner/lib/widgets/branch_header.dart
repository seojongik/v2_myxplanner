import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BranchHeader extends StatelessWidget {
  final String? customBranchName;
  final Color? textColor;
  final double? fontSize;
  
  const BranchHeader({
    Key? key,
    this.customBranchName,
    this.textColor,
    this.fontSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final branchData = ApiService.getCurrentBranch();
    final branchName = customBranchName ?? _safeGetBranchName(branchData) ?? '지점명 없음';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Text(
        branchName,
        style: TextStyle(
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w600,
          color: textColor ?? Colors.black.withOpacity(0.7),
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  String? _safeGetBranchName(Map<String, dynamic>? branchData) {
    if (branchData == null) return null;
    try {
      final name = branchData['branch_name'];
      return name?.toString();
    } catch (e) {
      print('Error getting branch name: $e');
      return null;
    }
  }
} 