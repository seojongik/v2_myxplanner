import 'package:flutter/material.dart';

class StepModel {
  final String title;
  final String icon;
  final Color color;
  final Widget content;
  final String? selectedValue;
  final bool isCompleted;

  const StepModel({
    required this.title,
    required this.icon,
    required this.color,
    required this.content,
    this.selectedValue,
    this.isCompleted = false,
  });

  StepModel copyWith({
    String? title,
    String? icon,
    Color? color,
    Widget? content,
    String? selectedValue,
    bool? isCompleted,
  }) {
    return StepModel(
      title: title ?? this.title,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      content: content ?? this.content,
      selectedValue: selectedValue ?? this.selectedValue,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
} 