package com.example.roombookingapp

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.roombookingapp/momo"
    
    // Package name của app MoMo
    private val MOMO_PACKAGE_NAME = "com.mservice.momotransfer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openMoMoApp") {
                val url = call.argument<String>("url")
                if (url != null) {
                    try {
                        // Parse URL từ MoMo API
                        val uri = Uri.parse(url)
                        
                        // Tạo Intent để mở app MoMo với URL thanh toán
                        // URL này đã chứa đầy đủ thông tin: số tiền, mô tả đơn hàng, etc.
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            data = uri
                            // Chỉ định package name của MoMo để mở trực tiếp app
                            setPackage(MOMO_PACKAGE_NAME)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        }
                        
                        // Kiểm tra xem app MoMo có được cài đặt không
                        val resolveInfo = packageManager.resolveActivity(intent, 0)
                        if (resolveInfo != null) {
                            // App MoMo đã được cài đặt, mở app với URL thanh toán
                            // URL này sẽ hiển thị đầy đủ thông tin thanh toán trong app MoMo
                            startActivity(intent)
                            result.success(true)
                        } else {
                            // App MoMo chưa được cài đặt, mở Play Store
                            val marketIntent = Intent(Intent.ACTION_VIEW).apply {
                                data = Uri.parse("market://details?id=$MOMO_PACKAGE_NAME")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            
                            // Nếu Play Store không có, mở trình duyệt
                            if (marketIntent.resolveActivity(packageManager) != null) {
                                startActivity(marketIntent)
                            } else {
                                val browserIntent = Intent(Intent.ACTION_VIEW).apply {
                                    data = Uri.parse("https://play.google.com/store/apps/details?id=$MOMO_PACKAGE_NAME")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(browserIntent)
                            }
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        // Nếu có lỗi, fallback về mở URL trong trình duyệt
                        try {
                            val fallbackIntent = Intent(Intent.ACTION_VIEW).apply {
                                data = Uri.parse(url)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallbackIntent)
                            result.success(false)
                        } catch (e2: Exception) {
                            result.error("ERROR", "Cannot open MoMo app: ${e.message}", null)
                        }
                    }
                } else {
                    result.error("ERROR", "URL is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
