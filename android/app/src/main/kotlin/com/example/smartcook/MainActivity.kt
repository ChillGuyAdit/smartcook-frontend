package com.example.smartcook

import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "kelilink/app_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "signingCertSha256" -> result.success(signingCertSha256Hex())
                    "versionCode" -> result.success(versionCode())
                    "versionName" -> result.success(versionName())
                    "deviceInfo" -> result.success(deviceInfo())
                    "packageName" -> result.success(packageName)
                    "canRequestPackageInstalls" ->
                        result.success(canRequestPackageInstalls())
                    "openInstallPermissionSettings" -> {
                        openInstallPermissionSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (t: Throwable) {
                result.error("native_error", t.message, null)
            }
        }
    }

    private fun canRequestPackageInstalls(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        return packageManager.canRequestPackageInstalls()
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
            .setData(Uri.parse("package:$packageName"))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun firstSignature(): Signature? {
        val pkg = packageName
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = packageManager.getPackageInfo(
                pkg,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
            val signing = info.signingInfo ?: return null
            val signers: Array<Signature>? = signing.signingCertificateHistory
                ?: signing.apkContentsSigners
            signers?.firstOrNull()
        } else {
            @Suppress("DEPRECATION")
            val info = packageManager.getPackageInfo(pkg, PackageManager.GET_SIGNATURES)
            @Suppress("DEPRECATION")
            info.signatures?.firstOrNull()
        }
    }

    private fun signingCertSha256Hex(): String? {
        val signature = firstSignature() ?: return null
        val digest = MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())
        val sb = StringBuilder(digest.size * 2)
        for (b in digest) {
            sb.append("%02x".format(b))
        }
        return sb.toString()
    }

    private fun versionCode(): Int =
        try {
            packageManager.getPackageInfo(packageName, 0).versionCode
        } catch (_: Throwable) {
            0
        }

    private fun versionName(): String =
        try {
            packageManager.getPackageInfo(packageName, 0).versionName ?: ""
        } catch (_: Throwable) {
            ""
        }

    /**
     * Device facts for the developer debug log. Read from the platform rather
     * than scraped, so the values are the real ones Android reports.
     */
    private fun deviceInfo(): Map<String, Any?> {
        val abi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            Build.SUPPORTED_ABIS.firstOrNull()
        } else {
            null
        }
        val locale = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                resources.configuration.locales[0].toLanguageTag()
            } else {
                @Suppress("DEPRECATION")
                resources.configuration.locale.toLanguageTag()
            }
        } catch (_: Throwable) {
            null
        }
        return mapOf(
            "platform" to "Android",
            "osVersion" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "deviceModel" to Build.MODEL,
            "deviceManufacturer" to Build.MANUFACTURER,
            "abi" to abi,
            "deviceLocale" to locale,
            "appVersion" to versionName(),
        )
    }
}