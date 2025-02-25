package com.example.lockedin

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter/large_object"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveLargeObject") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    Log.d("UPLOAD", "📌 Received file path: $filePath")

                    LargeObjectUploader.upload(filePath) { oid ->
                        if (oid != null) {
                            result.success(oid)
                        } else {
                            result.error("UPLOAD_FAILED", "Failed to upload photo", null)
                        }
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "File path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
