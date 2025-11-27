import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final String branchId;
  final String memberId;
  final String memberName;
  final String memberPhone;
  final String memberType;
  final DateTime createdAt;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int adminUnreadCount;
  final int memberUnreadCount;
  final bool isActive;

  ChatRoom({
    required this.id,
    required this.branchId,
    required this.memberId,
    required this.memberName,
    required this.memberPhone,
    required this.memberType,
    required this.createdAt,
    required this.lastMessage,
    required this.lastMessageTime,
    this.adminUnreadCount = 0,
    this.memberUnreadCount = 0,
    this.isActive = true,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // createdAt 파싱 (여러 형태 지원)
    DateTime createdAt;
    if (data['createdAt'] != null) {
      final createdAtData = data['createdAt'];
      if (createdAtData is Timestamp) {
        createdAt = createdAtData.toDate();
      } else if (createdAtData is Map && createdAtData.containsKey('seconds')) {
        // Firestore Timestamp 형태
        final seconds = createdAtData['seconds'] ?? 0;
        final nanoseconds = createdAtData['nanoseconds'] ?? 0;
        createdAt = DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000) + (nanoseconds ~/ 1000000),
          isUtc: true,
        ).toLocal();
      } else if (createdAtData is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtData);
      } else if (createdAtData is String) {
        createdAt = DateTime.parse(createdAtData);
      } else {
        print('⚠️ [ChatRoom] 알 수 없는 createdAt 형태: $createdAtData');
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }
    
    // lastMessageTime 파싱 (여러 형태 지원)
    DateTime lastMessageTime;
    if (data['lastMessageTime'] != null) {
      final lastMessageTimeData = data['lastMessageTime'];
      if (lastMessageTimeData is Timestamp) {
        lastMessageTime = lastMessageTimeData.toDate();
      } else if (lastMessageTimeData is Map && lastMessageTimeData.containsKey('seconds')) {
        // Firestore Timestamp 형태
        final seconds = lastMessageTimeData['seconds'] ?? 0;
        final nanoseconds = lastMessageTimeData['nanoseconds'] ?? 0;
        lastMessageTime = DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000) + (nanoseconds ~/ 1000000),
          isUtc: true,
        ).toLocal();
      } else if (lastMessageTimeData is int) {
        lastMessageTime = DateTime.fromMillisecondsSinceEpoch(lastMessageTimeData);
      } else if (lastMessageTimeData is String) {
        lastMessageTime = DateTime.parse(lastMessageTimeData);
      } else {
        print('⚠️ [ChatRoom] 알 수 없는 lastMessageTime 형태: $lastMessageTimeData');
        lastMessageTime = DateTime.now();
      }
    } else {
      lastMessageTime = DateTime.now();
    }
    
    return ChatRoom(
      id: doc.id,
      branchId: data['branchId'] ?? '',
      memberId: data['memberId'] ?? '',
      memberName: data['memberName'] ?? '',
      memberPhone: data['memberPhone'] ?? '',
      memberType: data['memberType'] ?? '',
      createdAt: createdAt,
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: lastMessageTime,
      adminUnreadCount: data['adminUnreadCount'] ?? 0,
      memberUnreadCount: data['memberUnreadCount'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  factory ChatRoom.fromMap(Map<String, dynamic> data) {
    return ChatRoom(
      id: data['id'] ?? '',
      branchId: data['branchId'] ?? '',
      memberId: data['memberId'] ?? '',
      memberName: data['memberName'] ?? '',
      memberPhone: data['memberPhone'] ?? '',
      memberType: data['memberType'] ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(_toInt(data['createdAt']))
          : DateTime.now(),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: data['lastMessageTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(_toInt(data['lastMessageTime']))
          : DateTime.now(),
      adminUnreadCount: _toInt(data['adminUnreadCount']) ?? 0,
      memberUnreadCount: _toInt(data['memberUnreadCount']) ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'branchId': branchId,
      'memberId': memberId,
      'memberName': memberName,
      'memberPhone': memberPhone,
      'memberType': memberType,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'adminUnreadCount': adminUnreadCount,
      'memberUnreadCount': memberUnreadCount,
      'isActive': isActive,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchId': branchId,
      'memberId': memberId,
      'memberName': memberName,
      'memberPhone': memberPhone,
      'memberType': memberType,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'adminUnreadCount': adminUnreadCount,
      'memberUnreadCount': memberUnreadCount,
      'isActive': isActive,
    };
  }

  static String generateChatRoomId(String branchId, String memberId) {
    return '${branchId}_${memberId}';
  }
}

class ChatMessage {
  final String id;
  final String chatRoomId;
  final String branchId;
  final String senderId;
  final String senderType;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.branchId,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // timestamp 파싱 (여러 형태 지원)
    DateTime timestamp;
    if (data['timestamp'] != null) {
      final timestampData = data['timestamp'];
      if (timestampData is Timestamp) {
        timestamp = timestampData.toDate();
      } else if (timestampData is Map && timestampData.containsKey('seconds')) {
        // Firestore Timestamp 형태
        final seconds = timestampData['seconds'] ?? 0;
        final nanoseconds = timestampData['nanoseconds'] ?? 0;
        timestamp = DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000) + (nanoseconds ~/ 1000000),
          isUtc: true,
        ).toLocal();
      } else if (timestampData is int) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(timestampData);
      } else if (timestampData is String) {
        timestamp = DateTime.parse(timestampData);
      } else {
        print('⚠️ [ChatMessage] 알 수 없는 timestamp 형태: $timestampData');
        timestamp = DateTime.now();
      }
    } else {
      timestamp = DateTime.now();
    }
    
    return ChatMessage(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      branchId: data['branchId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderType: data['senderType'] ?? 'member',
      senderName: data['senderName'] ?? '',
      message: data['message'] ?? '',
      timestamp: timestamp,
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatRoomId': chatRoomId,
      'branchId': branchId,
      'senderId': senderId,
      'senderType': senderType,
      'senderName': senderName,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  static String generateMessageId(String branchId, String memberId) {
    return '${branchId}_${memberId}_${DateTime.now().millisecondsSinceEpoch}';
  }
}