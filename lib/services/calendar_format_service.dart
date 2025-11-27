import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'holiday_service.dart';

class CalendarFormatService {
  // 공통 달력 스타일 설정
  static CalendarStyle getCalendarStyle({Color? selectedColor, Color? todayColor}) {
    return CalendarStyle(
      outsideDaysVisible: false,
      rowDecoration: BoxDecoration(),
      cellMargin: EdgeInsets.all(2),
      weekendTextStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
      ),
      holidayTextStyle: TextStyle(
        color: Colors.red, // 일요일과 같은 빨간색
        fontWeight: FontWeight.w600,
      ),
      selectedDecoration: BoxDecoration(
        color: selectedColor ?? Color(0xFF3B82F6),
        shape: BoxShape.circle,
      ),
      selectedTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      todayDecoration: BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
      ),
      todayTextStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
      ),
      defaultDecoration: BoxDecoration(
        shape: BoxShape.circle,
      ),
      defaultTextStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
      ),
      disabledDecoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
      ),
      disabledTextStyle: TextStyle(
        color: Color(0xFFD0D0D0),
        fontWeight: FontWeight.w300,
      ),
      markersMaxCount: 1,
      markerDecoration: BoxDecoration(
        color: Color(0xFFFF5722),
        shape: BoxShape.circle,
      ),
      markerSize: 6.0,
      markersAlignment: Alignment.bottomCenter,
    );
  }

  // 공통 헤더 스타일 설정
  static HeaderStyle getHeaderStyle({Color? chevronColor}) {
    return HeaderStyle(
      formatButtonVisible: false,
      titleCentered: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
      ),
      leftChevronIcon: Icon(
        Icons.chevron_left,
        color: chevronColor ?? Color(0xFF3B82F6),
      ),
      rightChevronIcon: Icon(
        Icons.chevron_right,
        color: chevronColor ?? Color(0xFF3B82F6),
      ),
      headerPadding: EdgeInsets.symmetric(vertical: 8),
    );
  }

  // 공통 요일 스타일 설정
  static DaysOfWeekStyle getDaysOfWeekStyle() {
    return DaysOfWeekStyle(
      decoration: BoxDecoration(),
      weekdayStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      weekendStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  // 공통 달력 빌더 설정
  static CalendarBuilders<String> getCalendarBuilders(Map<String, Map<String, dynamic>> scheduleData) {
    return CalendarBuilders<String>(
      defaultBuilder: (context, day, focusedDay) {
        Color textColor = Color(0xFF1A1A1A);
        if (day.weekday == DateTime.saturday) {
          textColor = Color(0xFF3B82F6);
        } else if (day.weekday == DateTime.sunday) {
          textColor = Color(0xFFFF5722);
        }
        
        return FutureBuilder<bool>(
          future: HolidayService.isHoliday(day),
          builder: (context, snapshot) {
            bool isHoliday = snapshot.data ?? false;
            if (isHoliday && day.weekday != DateTime.sunday) {
              textColor = Color(0xFFFF5722); // 공휴일도 빨간색
            }
            
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        );
      },
      markerBuilder: (context, day, events) {
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        final schedule = scheduleData[dateStr];
        
        if (schedule != null && schedule['is_holiday'] == 'close') {
          return Positioned(
            bottom: 4,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Color(0xFFFF5722),
                shape: BoxShape.circle,
              ),
            ),
          );
        }
        return null;
      },
    );
  }

  // 공통 달력 설정
  static Map<String, dynamic> getCommonCalendarConfig() {
    return {
      'rowHeight': 45.0,
      'daysOfWeekHeight': 35.0,
      'calendarHeight': 340.0,
      'locale': 'ko_KR',
      'firstDay': DateTime.now(),
      'lastDay': DateTime.now().add(Duration(days: 365)),
      'calendarFormat': CalendarFormat.month,
      'startingDayOfWeek': StartingDayOfWeek.sunday,
      'availableCalendarFormats': const {
        CalendarFormat.month: '월',
      },
    };
  }

  // 선택된 날짜 표시 위젯
  static Widget buildSelectedDateDisplay(DateTime? selectedDate) {
    if (selectedDate == null) return SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '선택된 날짜',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(selectedDate),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 로딩 표시 위젯
  static Widget buildLoadingIndicator(String message) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(message),
        ],
      ),
    );
  }
} 