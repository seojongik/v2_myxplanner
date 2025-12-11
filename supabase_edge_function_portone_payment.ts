import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// 포트원 API 설정
const PORTONE_API_SECRET = Deno.env.get("PORTONE_API_SECRET") || "";
const PORTONE_STORE_ID = Deno.env.get("PORTONE_STORE_ID") || "store-58c8f5b8-6bc6-4efb-8dd0-8a98475a4246";
const PORTONE_API_BASE_URL = "https://api.portone.io";

// Supabase 설정
const SUPABASE_URL = Deno.env.get("PROJECT_URL") || Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

/**
 * 포트원 결제 Edge Function
 * 
 * 지원하는 액션:
 * - verify: 결제 검증 (회원권 부여 전 필수)
 * - cancel: 결제 취소/환불
 * - get: 결제 정보 조회
 * 
 * 사용 방법:
 * 1. Supabase Secrets에 PORTONE_API_SECRET 설정
 *    supabase secrets set PORTONE_API_SECRET="your-api-secret-here"
 * 
 * 2. Edge Function 배포
 *    supabase functions deploy portone-payment
 */

Deno.serve(async (req) => {
  try {
    // CORS 헤더
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    };

    // Preflight 요청 처리
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    // API Secret 확인
    if (!PORTONE_API_SECRET) {
      console.error("❌ PORTONE_API_SECRET 환경 변수가 설정되지 않았습니다");
      return new Response(
        JSON.stringify({
          success: false,
          error: "서버 설정 오류: API Secret이 설정되지 않았습니다",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const payload = await req.json();
    const { action, paymentId, expectedAmount, cancelAmount, cancelReason } = payload;

    console.log(`🔐 [PortOne Edge Function] 액션: ${action}, paymentId: ${paymentId}`);

    switch (action) {
      case "verify":
        return await verifyPayment(paymentId, expectedAmount, corsHeaders);
      
      case "cancel":
        return await cancelPayment(paymentId, cancelAmount, cancelReason, corsHeaders);
      
      case "get":
        return await getPayment(paymentId, corsHeaders);
      
      default:
        return new Response(
          JSON.stringify({
            success: false,
            error: `알 수 없는 액션: ${action}`,
          }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
    }
  } catch (error) {
    console.error("❌ [PortOne Edge Function] 에러:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});

/**
 * 포트원 API에서 결제 정보 조회
 */
async function getPayment(paymentId: string, corsHeaders: Record<string, string>) {
  try {
    console.log(`📋 [PortOne] 결제 정보 조회: ${paymentId}`);

    const response = await fetch(`${PORTONE_API_BASE_URL}/payments/${paymentId}`, {
      method: "GET",
      headers: {
        "Authorization": `PortOne ${PORTONE_API_SECRET}`,
        "Content-Type": "application/json",
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ [PortOne] 결제 조회 실패: ${response.status} - ${errorText}`);
      return new Response(
        JSON.stringify({
          success: false,
          error: `결제 조회 실패: ${response.status}`,
          details: errorText,
        }),
        {
          status: response.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const data = await response.json();
    console.log(`✅ [PortOne] 결제 정보 조회 성공`);

    return new Response(
      JSON.stringify({
        success: true,
        data: data,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error(`❌ [PortOne] 결제 조회 오류:`, error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
}

/**
 * 결제 검증 (회원권 부여 전 필수!)
 * 결제가 실제로 완료되었는지 확인하고, 결제 금액도 검증
 */
async function verifyPayment(
  paymentId: string,
  expectedAmount: number,
  corsHeaders: Record<string, string>
) {
  try {
    console.log(`🔐 [PortOne] 결제 검증 시작: ${paymentId}`);
    console.log(`🔐 [PortOne] 예상 결제 금액: ${expectedAmount}원`);

    // 포트원 API 호출
    const response = await fetch(`${PORTONE_API_BASE_URL}/payments/${paymentId}`, {
      method: "GET",
      headers: {
        "Authorization": `PortOne ${PORTONE_API_SECRET}`,
        "Content-Type": "application/json",
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ [PortOne] API 호출 실패: ${response.status} - ${errorText}`);
      return new Response(
        JSON.stringify({
          success: false,
          verified: false,
          error: `포트원 API 호출 실패: ${response.status}`,
        }),
        {
          status: 200, // 클라이언트에서 처리할 수 있도록 200 반환
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const paymentData = await response.json();
    console.log(`📋 [PortOne] 결제 데이터:`, JSON.stringify(paymentData));

    // 결제 상태 확인 (status가 PAID여야 함)
    const status = paymentData.status;
    if (status !== "PAID") {
      console.log(`❌ [PortOne] 결제 상태가 PAID가 아닙니다: ${status}`);
      return new Response(
        JSON.stringify({
          success: true,
          verified: false,
          error: `결제가 완료되지 않았습니다. 상태: ${status}`,
          status: status,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 결제 금액 확인
    const amount = paymentData.amount;
    const totalAmount = amount?.total;
    const paidAmount = amount?.paid;
    const actualAmount = paidAmount ?? totalAmount;

    if (actualAmount == null) {
      console.log(`❌ [PortOne] 결제 금액 정보가 없습니다`);
      return new Response(
        JSON.stringify({
          success: true,
          verified: false,
          error: "결제 금액 정보를 확인할 수 없습니다.",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (actualAmount !== expectedAmount) {
      console.log(`❌ [PortOne] 결제 금액 불일치: 예상 ${expectedAmount}원, 실제 ${actualAmount}원`);
      return new Response(
        JSON.stringify({
          success: true,
          verified: false,
          error: `결제 금액이 일치하지 않습니다. 예상: ${expectedAmount}원, 실제: ${actualAmount}원`,
          expectedAmount: expectedAmount,
          actualAmount: actualAmount,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 결제 시간 확인
    const paidAt = paymentData.paidAt;
    if (!paidAt) {
      console.log(`❌ [PortOne] 결제 완료 시간이 없습니다`);
      return new Response(
        JSON.stringify({
          success: true,
          verified: false,
          error: "결제 완료 시간을 확인할 수 없습니다.",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 채널 정보에서 테스트 여부 확인
    const channel = paymentData.channel;
    const channelType = channel?.type;
    const isTest = channelType === "TEST";

    console.log(`✅ [PortOne] 결제 검증 성공!`);
    console.log(`   - 상태: ${status}`);
    console.log(`   - 금액: ${actualAmount}원`);
    console.log(`   - 결제 시간: ${paidAt}`);
    console.log(`   - 채널 타입: ${channelType} (${isTest ? "테스트" : "실결제"})`);

    return new Response(
      JSON.stringify({
        success: true,
        verified: true,
        status: status,
        amount: actualAmount,
        paidAt: paidAt,
        isTest: isTest,
        paymentData: paymentData,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error(`❌ [PortOne] 결제 검증 오류:`, error);
    return new Response(
      JSON.stringify({
        success: false,
        verified: false,
        error: `결제 검증 중 오류: ${error.message}`,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
}

/**
 * 결제 취소/환불
 */
async function cancelPayment(
  paymentId: string,
  cancelAmount: number | null,
  cancelReason: string,
  corsHeaders: Record<string, string>
) {
  try {
    console.log(`💳 [PortOne] 결제 취소 요청: ${paymentId}`);
    console.log(`   - 취소 금액: ${cancelAmount != null ? `${cancelAmount}원` : "전액"}`);
    console.log(`   - 취소 사유: ${cancelReason}`);

    const requestBody: Record<string, unknown> = {
      storeId: PORTONE_STORE_ID,
      reason: cancelReason || "고객 요청에 의한 환불",
    };

    // 부분 취소인 경우에만 금액 포함
    if (cancelAmount != null) {
      requestBody.amount = cancelAmount;
    }

    const response = await fetch(`${PORTONE_API_BASE_URL}/payments/${paymentId}/cancel`, {
      method: "POST",
      headers: {
        "Authorization": `PortOne ${PORTONE_API_SECRET}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    console.log(`📋 [PortOne] 취소 응답 상태: ${response.status}`);

    if (response.ok) {
      const responseData = await response.json();
      console.log(`✅ [PortOne] 결제 취소 성공`);
      
      return new Response(
        JSON.stringify({
          success: true,
          data: responseData,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    } else {
      const errorData = await response.json();
      const errorType = errorData.type || "UnknownError";
      const errorMessage = errorData.message || "결제 취소 실패";

      console.error(`❌ [PortOne] 결제 취소 실패: ${errorType} - ${errorMessage}`);

      return new Response(
        JSON.stringify({
          success: false,
          error: errorMessage,
          errorType: errorType,
          statusCode: response.status,
        }),
        {
          status: 200, // 클라이언트에서 처리할 수 있도록 200 반환
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }
  } catch (error) {
    console.error(`❌ [PortOne] 결제 취소 오류:`, error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
}



