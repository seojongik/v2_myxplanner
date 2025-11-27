import 'package:flutter/material.dart';
import 'sp_step0_structure.dart';

class SpecialReservationPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final String? specialType;

  const SpecialReservationPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.specialType,
  }) : super(key: key);

  @override
  _SpecialReservationPageState createState() => _SpecialReservationPageState();
}

class _SpecialReservationPageState extends State<SpecialReservationPage> {
  @override
  Widget build(BuildContext context) {
    return SpStep0Structure(
      isAdminMode: widget.isAdminMode,
      selectedMember: widget.selectedMember,
      branchId: widget.branchId,
      specialType: widget.specialType,
    );
  }
}

// 임베드 가능한 특수 예약 콘텐츠 위젯
class SpecialReservationContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final String? specialType;
  final Function(bool)? onUnsavedChanges;

  const SpecialReservationContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.specialType,
    this.onUnsavedChanges,
  }) : super(key: key);

  @override
  _SpecialReservationContentState createState() => _SpecialReservationContentState();
}

class _SpecialReservationContentState extends State<SpecialReservationContent> {
  @override
  Widget build(BuildContext context) {
    return SpStep0Structure(
      isAdminMode: widget.isAdminMode,
      selectedMember: widget.selectedMember,
      branchId: widget.branchId,
      specialType: widget.specialType,
    );
  }
} 