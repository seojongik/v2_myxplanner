package com.enabletech.autogolfcrm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.enabletech.autogolfcrm/intent_launcher"
    private val VIBRATION_CHANNEL = "com.enabletech.autogolfcrm/vibration"
    private val NOTIFICATION_CHANNEL = "com.enabletech.autogolfcrm/notification"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Firebase 플러그인이 먼저 등록되도록 super 호출
        // GeneratedPluginRegistrant.registerWith()가 자동으로 호출됨
        super.configureFlutterEngine(flutterEngine)
        
        // Firebase 플러그인 등록 확인 로그
        Log.d("MainActivity", "Flutter 엔진 설정 완료 - Firebase 플러그인 등록 확인")
        
        // Android 시스템 알림 채널 생성
        createNotificationChannel()
        
        // 알림 채널 설정 (진동 + 소리)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playNotification" -> {
                    val enableSound = call.argument<Boolean>("enableSound") ?: true
                    val enableVibration = call.argument<Boolean>("enableVibration") ?: true
                    try {
                        playNotification(enableSound, enableVibration)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "알림 재생 실패", e)
                        result.error("NOTIFICATION_ERROR", e.message, null)
                    }
                }
                "getRingerMode" -> {
                    try {
                        val mode = getRingerModeString()
                        result.success(mode)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "기기 모드 확인 실패", e)
                        result.error("RINGER_MODE_ERROR", e.message, null)
                    }
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                            putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "알림 설정 열기 실패", e)
                        // 대체 방법: 앱 정보 페이지로 이동
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("SETTINGS_ERROR", e2.message, null)
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 진동 채널 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIBRATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> {
                    val duration = call.argument<Int>("duration") ?: 200
                    try {
                        vibrate(duration)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "진동 실행 실패", e)
                        result.error("VIBRATION_ERROR", e.message, null)
                    }
                }
                "vibratePattern" -> {
                    val patternList = call.argument<List<Int>>("pattern")
                    val repeat = call.argument<Int>("repeat") ?: -1
                    try {
                        if (patternList != null) {
                            val pattern = patternList.map { it.toLong() }.toLongArray()
                            vibratePattern(pattern, repeat)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "패턴이 제공되지 않았습니다", null)
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "진동 패턴 실행 실패", e)
                        result.error("VIBRATION_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchIntent" -> {
                    val intentUrl = call.argument<String>("url")
                    if (intentUrl != null) {
                        try {
                            val success = launchIntentUrl(intentUrl)
                            result.success(success)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Intent 실행 오류", e)
                            result.error("INTENT_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "URL이 제공되지 않았습니다", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun launchIntentUrl(intentUrl: String): Boolean {
        Log.d("MainActivity", "Intent URL 처리: $intentUrl")
        
        return try {
            // intent:// 또는 intent: 로 시작하는 경우 처리
            val normalizedUrl = if (intentUrl.startsWith("intent:") && !intentUrl.startsWith("intent://")) {
                // intent:SCHEME://... -> intent://SCHEME/... (://를 /로 변경)
                // 예: intent:hdcardappcardansimclick://appcard -> intent://hdcardappcardansimclick/appcard
                intentUrl.replace(Regex("intent:([^:]+)://"), "intent://\$1/")
            } else {
                intentUrl
            }
            
            if (normalizedUrl.startsWith("intent://") || intentUrl.startsWith("intent:")) {
                Log.d("MainActivity", "정규화된 URL: $normalizedUrl")
                
                // intent:// URL에서 패키지와 실제 스킴 URL 추출
                val hashIndex = normalizedUrl.indexOf("#Intent")
                if (hashIndex == -1) {
                    Log.e("MainActivity", "Intent 섹션을 찾을 수 없음")
                    return false
                }
                
                val urlPart = normalizedUrl.substring(0, hashIndex)
                val intentPart = normalizedUrl.substring(hashIndex + 7) // "#Intent" 제거
                
                // 패키지 추출
                var packageName: String? = null
                val packageMatch = Regex("package=([^;]+)").find(intentPart)
                if (packageMatch != null) {
                    packageName = packageMatch.groupValues[1]
                }
                
                Log.d("MainActivity", "추출된 패키지: $packageName")
                Log.d("MainActivity", "URL 부분: $urlPart")
                
                // intent://SCHEME/path 형식에서 실제 스킴 URL 추출
                // intent://hdcardappcardansimclick/appcard?... -> hdcardappcardansimclick://appcard?...
                val schemeMatch = Regex("intent://([^/]+)/(.+)").find(urlPart)
                if (schemeMatch != null) {
                    val scheme = schemeMatch.groupValues[1]
                    val pathAndQuery = schemeMatch.groupValues[2]
                    val actualSchemeUrl = "$scheme://$pathAndQuery"
                    
                    Log.d("MainActivity", "실제 스킴 URL: $actualSchemeUrl")
                    
                    // 패키지가 있으면 해당 패키지로 Intent 생성
                    if (packageName != null) {
                        try {
                            packageManager.getPackageInfo(packageName, 0)
                            Log.d("MainActivity", "패키지 확인됨: $packageName")
                            
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(actualSchemeUrl))
                            intent.setPackage(packageName)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            intent.addCategory(Intent.CATEGORY_DEFAULT)
                            intent.addCategory(Intent.CATEGORY_BROWSABLE)
                            
                            // Intent 해결 가능 여부 확인
                            val resolved = intent.resolveActivity(packageManager)
                            if (resolved != null) {
                                Log.d("MainActivity", "Intent 해결 가능: ${resolved.packageName}")
                                startActivity(intent)
                                Log.d("MainActivity", "Intent 실행 성공: $packageName")
                                return true
                            } else {
                                Log.w("MainActivity", "Intent 해결 불가: $packageName")
                            }
                        } catch (e: PackageManager.NameNotFoundException) {
                            Log.w("MainActivity", "패키지를 찾을 수 없음: $packageName")
                        } catch (e: android.content.ActivityNotFoundException) {
                            Log.w("MainActivity", "Activity를 찾을 수 없음: ${e.message}")
                        } catch (e: Exception) {
                            Log.e("MainActivity", "앱 실행 실패: ${e.message}", e)
                        }
                    }
                    
                    // 패키지 지정 실패 시 일반 스킴으로 시도
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(actualSchemeUrl))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        intent.addCategory(Intent.CATEGORY_DEFAULT)
                        intent.addCategory(Intent.CATEGORY_BROWSABLE)
                        
                        val resolved = intent.resolveActivity(packageManager)
                        if (resolved != null) {
                            Log.d("MainActivity", "일반 스킴으로 Intent 해결 가능: ${resolved.packageName}")
                            startActivity(intent)
                            Log.d("MainActivity", "일반 스킴으로 Intent 실행 성공")
                            return true
                        }
                    } catch (e: Exception) {
                        Log.w("MainActivity", "일반 스킴 실행 실패: ${e.message}")
                    }
                }
                
                // 기존 방식으로 fallback 시도
                val intent = Intent.parseUri(normalizedUrl, Intent.URI_INTENT_SCHEME)
                
                // FLAG_ACTIVITY_NEW_TASK 추가 (필수)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                
                // 패키지가 지정되어 있으면 해당 앱 실행 시도
                if (intent.`package` != null) {
                    val pkgName = intent.`package`
                    Log.d("MainActivity", "패키지 지정 Intent (fallback): $pkgName")
                    
                    // Intent에 카테고리 추가 (일부 앱에서 필요)
                    if (!intent.hasCategory(Intent.CATEGORY_DEFAULT)) {
                        intent.addCategory(Intent.CATEGORY_DEFAULT)
                    }
                    if (!intent.hasCategory(Intent.CATEGORY_BROWSABLE)) {
                        intent.addCategory(Intent.CATEGORY_BROWSABLE)
                    }
                    
                    // 패키지가 설치되어 있는지 확인 (로깅용)
                    try {
                        packageManager.getPackageInfo(pkgName!!, 0)
                        Log.d("MainActivity", "패키지 확인됨: $pkgName")
                    } catch (e: Exception) {
                        Log.w("MainActivity", "패키지 확인 실패하지만 실행 시도: $pkgName")
                    }
                    
                    try {
                        startActivity(intent)
                        Log.d("MainActivity", "Intent 실행 성공: $pkgName")
                        true
                    } catch (e: android.content.ActivityNotFoundException) {
                        Log.w("MainActivity", "Activity를 찾을 수 없음, fallback 시도: ${e.message}")
                        
                        // fallback URL 시도 (여러 방법)
                        var fallbackUrl: String? = null
                        
                        // 1. S.browser_fallback_url 파라미터 확인
                        fallbackUrl = intent.getStringExtra("S.browser_fallback_url")
                        
                        // 2. browser_fallback_url 파라미터 확인
                        if (fallbackUrl == null) {
                            fallbackUrl = intent.getStringExtra("browser_fallback_url")
                        }
                        
                        // 3. intent:// URL에서 url 쿼리 파라미터 추출
                        if (fallbackUrl == null) {
                            try {
                                val uri = Uri.parse(intentUrl)
                                fallbackUrl = uri.getQueryParameter("url")
                            } catch (e2: Exception) {
                                Log.w("MainActivity", "URL 파라미터 추출 실패: ${e2.message}")
                            }
                        }
                        
                        if (fallbackUrl != null) {
                            Log.d("MainActivity", "Fallback URL로 이동: $fallbackUrl")
                            val fallbackIntent = Intent(Intent.ACTION_VIEW, Uri.parse(fallbackUrl))
                            fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(fallbackIntent)
                            true
                        } else {
                            Log.e("MainActivity", "앱이 설치되지 않았고 fallback URL도 없음")
                            false
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "앱 실행 실패: ${e.message}", e)
                        false
                    }
                } else {
                    // 패키지가 없으면 scheme으로 시도
                    val scheme = intent.scheme
                    if (scheme != null) {
                        Log.d("MainActivity", "스킴으로 Intent 실행 시도: $scheme")
                        val schemeIntent = Intent(Intent.ACTION_VIEW, Uri.parse("$scheme://"))
                        schemeIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        try {
                            startActivity(schemeIntent)
                            Log.d("MainActivity", "스킴 Intent 실행 성공: $scheme")
                            true
                        } catch (e: android.content.ActivityNotFoundException) {
                            Log.w("MainActivity", "스킴으로 앱을 찾을 수 없음: $scheme")
                            false
                        } catch (e: Exception) {
                            Log.e("MainActivity", "스킴 Intent 실행 실패: ${e.message}", e)
                            false
                        }
                    } else {
                        Log.w("MainActivity", "스킴도 패키지도 없음")
                        false
                    }
                }
            } else {
                // 일반 URL 스킴 (kakaotalk://, payco://, kftc-bankpay://, ispmobile://, hdcardapp:// 등)
                val uri = Uri.parse(intentUrl)
                val scheme = uri.scheme
                Log.d("MainActivity", "일반 URL 스킴 파싱: scheme=$scheme, host=${uri.host}, path=${uri.path}, query=${uri.query}")
                
                // 현대카드 앱카드 특별 처리
                if (scheme == "hdcardapp" || scheme == "hdcard" || scheme == "hdcardappcardansimclick" || 
                    scheme == "smhyundaiansimclick" || scheme == "hyundaicardappcardid" ||
                    uri.host?.contains("hyundai") == true || uri.host?.contains("hdcard") == true) {
                    Log.d("MainActivity", "현대카드 앱 감지, 특별 처리 시작: scheme=$scheme, host=${uri.host}")
                    
                    // 먼저 설치된 모든 앱에서 현대카드 관련 패키지 찾기
                    val installedPackages = packageManager.getInstalledPackages(0)
                    val hyundaiRelatedPackages = mutableListOf<String>()
                    
                    for (pkg in installedPackages) {
                        val packageName = pkg.packageName
                        if (packageName.contains("hyundai", ignoreCase = true) || 
                            packageName.contains("hdcard", ignoreCase = true)) {
                            hyundaiRelatedPackages.add(packageName)
                            Log.d("MainActivity", "현대카드 관련 패키지 발견: $packageName")
                        }
                    }
                    
                    // 알려진 현대카드 앱 패키지명들 시도 (실제 기기에서 확인된 패키지 포함)
                    val knownHyundaiPackages = listOf(
                        "com.hyundaicard.appcard",  // 앱카드 앱 (확인됨)
                        "com.ehyundai.mcard",        // 현대카드 모바일 (확인됨)
                        "com.ehyundai.mobile",      // 현대카드 모바일 (확인됨)
                        "com.hyundaiCard.HyundaiCardMPoint",  // 현대카드 M포인트 (확인됨)
                        "com.hyundai.oneapp.kr",    // 현대 원앱 (확인됨)
                        "com.hyundaicard.members",
                        "com.hyundaicard.app",
                        "com.hyundaicard",
                        "com.hyundaicard.appcard.ansimclick",
                        "com.hyundaicard.appcardansimclick"
                    )
                    
                    // 발견된 패키지와 알려진 패키지 합치기
                    val allPackages = (hyundaiRelatedPackages + knownHyundaiPackages).distinct()
                    
                    Log.d("MainActivity", "시도할 패키지 목록: $allPackages")
                    
                    var success = false
                    for (packageName in allPackages) {
                        try {
                            packageManager.getPackageInfo(packageName, 0)
                            Log.d("MainActivity", "현대카드 패키지 확인됨: $packageName")
                            
                            // 패키지가 있으면 해당 패키지로 Intent 생성
                            val intent = Intent(Intent.ACTION_VIEW, uri)
                            intent.setPackage(packageName)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            intent.addCategory(Intent.CATEGORY_DEFAULT)
                            intent.addCategory(Intent.CATEGORY_BROWSABLE)
                            
                            // Intent가 해결 가능한지 확인
                            val resolved = intent.resolveActivity(packageManager)
                            if (resolved != null) {
                                Log.d("MainActivity", "Intent 해결 가능: $packageName -> ${resolved.packageName}")
                                startActivity(intent)
                                Log.d("MainActivity", "현대카드 앱 실행 성공: $packageName")
                                success = true
                                break
                            } else {
                                Log.w("MainActivity", "Intent 해결 불가: $packageName")
                            }
                        } catch (e: PackageManager.NameNotFoundException) {
                            // 패키지 없음, 다음 시도
                            continue
                        } catch (e: Exception) {
                            Log.w("MainActivity", "현대카드 앱 실행 실패 ($packageName): ${e.message}", e)
                            // 다음 패키지 시도
                            continue
                        }
                    }
                    
                    if (success) {
                        return true
                    }
                    
                    // 패키지 지정 실패 시 일반 방법으로 시도
                    Log.d("MainActivity", "패키지 지정 실패, 일반 방법으로 시도")
                }
                
                // 일반 URL 스킴 처리
                val intent = Intent(Intent.ACTION_VIEW, uri)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                intent.addCategory(Intent.CATEGORY_DEFAULT)
                intent.addCategory(Intent.CATEGORY_BROWSABLE)
                
                try {
                    // 먼저 resolveActivity로 확인 (로깅용)
                    val resolved = intent.resolveActivity(packageManager)
                    if (resolved != null) {
                        Log.d("MainActivity", "앱 확인됨: ${resolved.packageName}")
                    } else {
                        Log.w("MainActivity", "resolveActivity가 null이지만 실행 시도: $intentUrl")
                    }
                    
                    // 직접 실행 시도
                    startActivity(intent)
                    Log.d("MainActivity", "일반 URL 스킴 실행 성공: $intentUrl")
                    true
                } catch (e: android.content.ActivityNotFoundException) {
                    Log.w("MainActivity", "Activity를 찾을 수 없음: $intentUrl - ${e.message}")
                    
                    // 현대카드의 경우 추가 시도
                    if (scheme == "hdcardapp" || scheme == "hdcard") {
                        Log.d("MainActivity", "현대카드 앱을 찾을 수 없음, 설치 확인 필요")
                    }
                    
                    // 앱이 없으면 false 반환하여 WebView에서 원래 페이지로 돌아가도록 함
                    false
                } catch (e: Exception) {
                    Log.e("MainActivity", "앱 실행 실패: $intentUrl - ${e.message}", e)
                    // 기타 오류도 false 반환
                    false
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "URL 실행 실패: $intentUrl", e)
            false
        }
    }
    
    private fun getVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }
    
    private fun vibrate(duration: Int) {
        val vibrator = getVibrator() ?: run {
            Log.w("MainActivity", "진동 기능을 사용할 수 없습니다")
            return
        }
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createOneShot(duration.toLong(), VibrationEffect.DEFAULT_AMPLITUDE)
                vibrator.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(duration.toLong())
            }
            Log.d("MainActivity", "진동 실행: ${duration}ms")
        } catch (e: Exception) {
            Log.e("MainActivity", "진동 실행 중 오류", e)
        }
    }
    
    private fun vibratePattern(pattern: LongArray, repeat: Int) {
        val vibrator = getVibrator() ?: run {
            Log.w("MainActivity", "진동 기능을 사용할 수 없습니다")
            return
        }
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createWaveform(pattern, repeat)
                vibrator.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, repeat)
            }
            Log.d("MainActivity", "진동 패턴 실행: ${pattern.contentToString()}, repeat=$repeat")
        } catch (e: Exception) {
            Log.e("MainActivity", "진동 패턴 실행 중 오류", e)
        }
    }
    
    private fun getRingerMode(): Int {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return audioManager.ringerMode
    }
    
    private fun getRingerModeString(): String {
        return when (getRingerMode()) {
            AudioManager.RINGER_MODE_SILENT -> "무음 모드"
            AudioManager.RINGER_MODE_VIBRATE -> "진동 모드"
            AudioManager.RINGER_MODE_NORMAL -> "벨소리 모드"
            else -> "알 수 없음"
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "chat_notifications"
            val channelName = "채팅 알림"
            val description = "1:1 채팅 메시지 알림"
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                this.description = description
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 200, 300, 200)
                enableLights(true)
                setShowBadge(true)
                // 커스텀 사운드 설정
                val soundUri = Uri.parse("android.resource://${packageName}/raw/hole_in")
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build()
                setSound(soundUri, audioAttributes)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d("MainActivity", "알림 채널 생성 완료: $channelId")
        }
    }
    
    private fun getNotificationChannelImportance(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = notificationManager.getNotificationChannel("chat_notifications")
            return channel?.importance ?: NotificationManager.IMPORTANCE_DEFAULT
        }
        return NotificationManager.IMPORTANCE_DEFAULT
    }
    
    private fun shouldPlaySound(): Boolean {
        val importance = getNotificationChannelImportance()
        // IMPORTANCE_HIGH 또는 IMPORTANCE_DEFAULT면 소리 재생
        return importance >= NotificationManager.IMPORTANCE_DEFAULT
    }
    
    private fun shouldVibrate(): Boolean {
        val importance = getNotificationChannelImportance()
        // IMPORTANCE_HIGH, IMPORTANCE_DEFAULT, IMPORTANCE_LOW면 진동 가능
        return importance >= NotificationManager.IMPORTANCE_LOW
    }
    
    private fun playNotification(enableSound: Boolean, enableVibration: Boolean) {
        val ringerMode = getRingerMode()
        val channelImportance = getNotificationChannelImportance()
        
        Log.d("MainActivity", "알림 재생: 소리=$enableSound, 진동=$enableVibration, 기기모드=$ringerMode, 채널중요도=$channelImportance")
        
        // 시스템 설정에서 알림이 완전히 차단되어 있으면 재생 안함
        if (channelImportance == NotificationManager.IMPORTANCE_NONE) {
            Log.d("MainActivity", "시스템 설정에서 알림이 차단됨 - 알림 재생 안함")
            return
        }
        
        // 무음 모드: 아무것도 재생 안함
        if (ringerMode == AudioManager.RINGER_MODE_SILENT) {
            Log.d("MainActivity", "무음 모드 - 알림 재생 안함")
            return
        }
        
        // 시스템 설정 확인 (채널 중요도 기반)
        val systemSoundEnabled = shouldPlaySound()
        val systemVibrationEnabled = shouldVibrate()
        
        // 진동 모드: 진동만 재생
        if (ringerMode == AudioManager.RINGER_MODE_VIBRATE) {
            if (enableVibration && systemVibrationEnabled) {
                try {
                    val pattern = longArrayOf(0, 200, 300, 200)
                    vibratePattern(pattern, -1)
                    Log.d("MainActivity", "진동 모드 - 진동 재생")
                } catch (e: Exception) {
                    Log.e("MainActivity", "진동 실행 실패", e)
                }
            }
            return
        }
        
        // 벨소리 모드: 소리와 진동 재생
        if (ringerMode == AudioManager.RINGER_MODE_NORMAL) {
            // 진동 실행
            if (enableVibration && systemVibrationEnabled) {
                try {
                    val pattern = longArrayOf(0, 200, 300, 200)
                    vibratePattern(pattern, -1)
                    Log.d("MainActivity", "벨소리 모드 - 진동 재생")
                } catch (e: Exception) {
                    Log.e("MainActivity", "진동 실행 실패", e)
                }
            }
            
            // 소리 재생
            if (enableSound && systemSoundEnabled) {
                try {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
                    
                    if (currentVolume > 0) {
                        val notificationUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        if (notificationUri != null) {
                            val ringtone = RingtoneManager.getRingtone(applicationContext, notificationUri)
                            if (ringtone != null) {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                    val audioAttributes = AudioAttributes.Builder()
                                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                        .build()
                                    ringtone.audioAttributes = audioAttributes
                                }
                                ringtone.play()
                                Log.d("MainActivity", "벨소리 모드 - 알림 소리 재생 성공")
                                
                                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                    if (ringtone.isPlaying) {
                                        ringtone.stop()
                                    }
                                }, 1000)
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e("MainActivity", "소리 재생 실패", e)
                }
            }
        }
    }
}





