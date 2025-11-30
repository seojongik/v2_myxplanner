import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// HTTP v1 API를 사용하기 위한 설정
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") || "autogolfcrm-messaging";
const FIREBASE_SERVICE_ACCOUNT_KEY = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY") || "";
// Supabase 제약: SUPABASE_ 접두사 사용 불가
const SUPABASE_URL = Deno.env.get("PROJECT_URL") || Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

// OAuth 2.0 액세스 토큰 생성 (Service Account Key 사용)
async function getAccessToken() {
  if (!FIREBASE_SERVICE_ACCOUNT_KEY) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_KEY 환경 변수가 설정되지 않았습니다");
  }
  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_KEY);
  const { JWT } = await import("npm:google-auth-library@9");
  const jwtClient = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes: [
      "https://www.googleapis.com/auth/firebase.messaging"
    ]
  });
  const tokens = await jwtClient.authorize();
  if (!tokens.access_token) {
    throw new Error("액세스 토큰을 가져올 수 없습니다");
  }
  return tokens.access_token;
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    console.log("🔔 [Edge Function] 새 메시지 수신:", payload.message_id);
    console.log("🔔 [Edge Function] 발신자:", payload.sender_type, payload.sender_id);
    
    const { message_id, chat_room_id, branch_id, sender_id, sender_type, sender_name, message } = payload;
    
    // 채팅방 정보 조회
    const chatRoomResponse = await fetch(`${SUPABASE_URL}/rest/v1/chat_rooms?id=eq.${chat_room_id}&select=*`, {
      headers: {
        "apikey": SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json"
      }
    });
    
    if (!chatRoomResponse.ok) {
      console.error("❌ [Edge Function] 채팅방 조회 실패:", await chatRoomResponse.text());
      return new Response(JSON.stringify({
        error: "채팅방 조회 실패"
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json"
        }
      });
    }
    
    const chatRooms = await chatRoomResponse.json();
    if (!chatRooms || chatRooms.length === 0) {
      console.log("⚠️ [Edge Function] 채팅방을 찾을 수 없음");
      return new Response(JSON.stringify({
        success: false,
        message: "채팅방 없음"
      }), {
        status: 200,
        headers: {
          "Content-Type": "application/json"
        }
      });
    }
    
    const chatRoom = chatRooms[0];
    
    if (sender_type === "member") {
      // 회원이 보낸 메시지 - 관리자에게 알림 발송
      console.log("🔔 [Edge Function] 회원 메시지 - 관리자에게 알림 발송");
      
      // 관리자 FCM 토큰 조회 (is_admin=true 사용)
      const adminTokensResponse = await fetch(`${SUPABASE_URL}/rest/v1/fcm_tokens?branch_id=eq.${branch_id}&is_admin=eq.true&select=token`, {
        headers: {
          "apikey": SUPABASE_SERVICE_ROLE_KEY,
          "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          "Content-Type": "application/json"
        }
      });
      
      if (!adminTokensResponse.ok) {
        console.error("❌ [Edge Function] 관리자 토큰 조회 실패:", await adminTokensResponse.text());
        return new Response(JSON.stringify({
          error: "토큰 조회 실패"
        }), {
          status: 500,
          headers: {
            "Content-Type": "application/json"
          }
        });
      }
      
      const adminTokens = await adminTokensResponse.json();
      const tokens = adminTokens.map((t) => t.token).filter(Boolean);
      
      if (tokens.length === 0) {
        console.log("⚠️ [Edge Function] 관리자 토큰 없음");
        return new Response(JSON.stringify({
          success: false,
          message: "토큰 없음"
        }), {
          status: 200,
          headers: {
            "Content-Type": "application/json"
          }
        });
      }
      
      const memberName = chatRoom.member_name || "회원";
      const notificationTitle = `${memberName}님의 메시지`;
      const notificationBody = message.length > 50 ? message.substring(0, 50) + "..." : message;
      
      // HTTP v1 API로 여러 토큰에 발송
      const accessToken = await getAccessToken();
      const results = [];
      
      for (const token of tokens) {
        const fcmPayload = {
          message: {
            token: token,
            notification: {
              title: notificationTitle,
              body: notificationBody
            },
            data: {
              type: "chat",
              chatRoomId: chat_room_id,
              branchId: branch_id,
              memberId: chatRoom.member_id,
              senderId: sender_id,
              messageId: message_id,
              senderName: memberName,
              message: message,
              click_action: "FLUTTER_NOTIFICATION_CLICK"
            },
            android: {
              priority: "high",
              notification: {
                channelId: "chat_notifications",
                sound: "hole_in" // 커스텀 사운드
              }
            },
            apns: {
              payload: {
                aps: {
                  sound: "hole_in.mp3", // 커스텀 사운드
                  badge: 1
                }
              }
            }
          }
        };
        
        const fcmResponse = await fetch(`https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify(fcmPayload)
        });
        
        if (!fcmResponse.ok) {
          const errorText = await fcmResponse.text();
          console.error(`❌ [Edge Function] FCM 발송 실패 (토큰: ${token.substring(0, 20)}...):`, errorText);
          results.push({
            token,
            success: false,
            error: errorText
          });
        } else {
          const result = await fcmResponse.json();
          console.log(`✅ [Edge Function] FCM 발송 완료: ${token.substring(0, 20)}...`);
          results.push({
            token,
            success: true,
            result
          });
        }
      }
      
      // 실패한 토큰 정리
      const failedTokens = results.filter((r) => !r.success).map((r) => r.token);
      if (failedTokens.length > 0) {
        for (const token of failedTokens) {
          await fetch(`${SUPABASE_URL}/rest/v1/fcm_tokens?token=eq.${token}`, {
            method: "DELETE",
            headers: {
              "apikey": SUPABASE_SERVICE_ROLE_KEY,
              "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
            }
          });
        }
        console.log(`🗑️ [Edge Function] 유효하지 않은 토큰 삭제: ${failedTokens.length}`);
      }
      
      return new Response(JSON.stringify({
        success: true,
        message: "알림 발송 완료",
        results
      }), {
        status: 200,
        headers: {
          "Content-Type": "application/json"
        }
      });
      
    } else if (sender_type === "admin" || sender_type === "pro" || sender_type === "manager") {
      // 관리자/프로/매니저가 보낸 메시지 - 회원에게 알림 발송
      console.log("🔔 [Edge Function] 관리자/프로/매니저 메시지 - 회원에게 알림 발송");
      
      const memberId = chatRoom.member_id;
      if (!memberId) {
        console.log("⚠️ [Edge Function] 회원 ID 없음");
        return new Response(JSON.stringify({
          success: false,
          message: "회원 ID 없음"
        }), {
          status: 200,
          headers: {
            "Content-Type": "application/json"
          }
        });
      }
      
      // 회원 FCM 토큰 조회 (member_id와 is_admin=false 사용)
      const memberTokensResponse = await fetch(`${SUPABASE_URL}/rest/v1/fcm_tokens?branch_id=eq.${branch_id}&member_id=eq.${memberId}&is_admin=eq.false&select=token`, {
        headers: {
          "apikey": SUPABASE_SERVICE_ROLE_KEY,
          "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          "Content-Type": "application/json"
        }
      });
      
      if (!memberTokensResponse.ok) {
        console.error("❌ [Edge Function] 회원 토큰 조회 실패:", await memberTokensResponse.text());
        return new Response(JSON.stringify({
          error: "토큰 조회 실패"
        }), {
          status: 500,
          headers: {
            "Content-Type": "application/json"
          }
        });
      }
      
      const memberTokens = await memberTokensResponse.json();
      if (!memberTokens || memberTokens.length === 0) {
        console.log("⚠️ [Edge Function] 회원 토큰 없음");
        return new Response(JSON.stringify({
          success: false,
          message: "토큰 없음"
        }), {
          status: 200,
          headers: {
            "Content-Type": "application/json"
          }
        });
      }
      
      const token = memberTokens[0].token;
      if (!token) {
        console.log("⚠️ [Edge Function] 유효한 토큰 없음");
        return new Response(JSON.stringify({
          success: false,
          message: "토큰 없음"
        }), {
          status: 200,
          headers: {
            "Content-Type": "application/json"
          }
        });
      }
      
      const branchName = "골프연습장";
      const notificationTitle = `${branchName}과의 1:1대화`;
      const notificationBody = message.length > 50 ? message.substring(0, 50) + "..." : message;
      
      // HTTP v1 API로 발송
      const accessToken = await getAccessToken();
      const fcmPayload = {
        message: {
          token: token,
          notification: {
            title: notificationTitle,
            body: notificationBody
          },
          data: {
            type: "chat",
            chatRoomId: chat_room_id,
            branchId: branch_id,
            memberId: memberId,
            senderId: sender_id,
            messageId: message_id,
            senderName: sender_name || "관리자",
            message: message,
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          },
          android: {
            priority: "high",
            notification: {
              channelId: "chat_notifications",
              sound: "hole_in" // 커스텀 사운드
            }
          },
          apns: {
            payload: {
              aps: {
                sound: "hole_in.mp3", // 커스텀 사운드
                badge: 1
              }
            }
          }
        }
      };
      
      const fcmResponse = await fetch(`https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(fcmPayload)
      });
      
      if (!fcmResponse.ok) {
        const errorText = await fcmResponse.text();
        console.error("❌ [Edge Function] FCM 발송 실패:", errorText);
        
        // 실패한 토큰 삭제
        await fetch(`${SUPABASE_URL}/rest/v1/fcm_tokens?branch_id=eq.${branch_id}&member_id=eq.${memberId}&is_admin=eq.false`, {
          method: "DELETE",
          headers: {
            "apikey": SUPABASE_SERVICE_ROLE_KEY,
            "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
          }
        });
        
        return new Response(JSON.stringify({
          error: "FCM 발송 실패",
          details: errorText
        }), {
          status: 500,
          headers: {
            "Content-Type": "application/json"
          }
        });
      }
      
      const fcmResult = await fcmResponse.json();
      console.log("✅ [Edge Function] FCM 발송 완료:", fcmResult);
      
      return new Response(JSON.stringify({
        success: true,
        message: "알림 발송 완료",
        result: fcmResult
      }), {
        status: 200,
        headers: {
          "Content-Type": "application/json"
        }
      });
    }
    
    return new Response(JSON.stringify({
      success: false,
      message: "알 수 없는 발신자 타입"
    }), {
      status: 200,
      headers: {
        "Content-Type": "application/json"
      }
    });
    
  } catch (error) {
    console.error("❌ [Edge Function] 에러:", error);
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: {
        "Content-Type": "application/json"
      }
    });
  }
});

