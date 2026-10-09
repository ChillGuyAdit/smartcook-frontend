package com.example.smartcook

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorManager
import android.net.TrafficStats
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.GLES20
import android.os.PowerManager
import android.os.SystemClock
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import android.telephony.TelephonyManager
import android.util.DisplayMetrics
import android.view.WindowManager

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.Locale as LLoc

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
                    "liveStats" -> result.success(liveStats())
                    "hardwareInfo" -> result.success(hardwareInfo())
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
    private var lastCpuTicks: Long = 0
    private var lastCpuAt: Long = 0
    private var lastRx: Long = -1
    private var lastTx: Long = -1
    private var lastNetAt: Long = 0
    private var hwCache: Map<String, Any?>? = null

    private fun readLong(path: String): Long? =
        try {
            java.io.File(path).readText().trim().toLong()
        } catch (_: Throwable) {
            null
        }

    private fun readText(path: String): String? =
        try {
            java.io.File(path).readText().trim().ifEmpty { null }
        } catch (_: Throwable) {
            null
        }

    /** Frequency of each core in MHz (null when the phone does not let apps read it). */
    private fun coreMhz(file: String): List<Int>? {
        val n = Runtime.getRuntime().availableProcessors().coerceAtMost(32)
        val out = ArrayList<Int>()
        var any = false
        for (i in 0 until n) {
            val khz = readLong("/sys/devices/system/cpu/cpu$i/cpufreq/$file")
            if (khz != null) any = true
            out.add(if (khz != null) (khz / 1000).toInt() else 0)
        }
        return if (any) out else null
    }

    /** GPU name through a throw-away 1x1 GLES context (the display is shared with Flutter, so it is never terminated). */
    private fun gpuInfo(): Map<String, String?> {
        try {
            val dpy = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            val ver = IntArray(2)
            if (!EGL14.eglInitialize(dpy, ver, 0, ver, 1)) return emptyMap()
            val cfgAttr = intArrayOf(
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_NONE,
            )
            val cfgs = arrayOfNulls<EGLConfig>(1)
            val num = IntArray(1)
            EGL14.eglChooseConfig(dpy, cfgAttr, 0, cfgs, 0, 1, num, 0)
            if (num[0] < 1) return emptyMap()
            val ctx = EGL14.eglCreateContext(
                dpy, cfgs[0], EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
            )
            val surf = EGL14.eglCreatePbufferSurface(
                dpy, cfgs[0], intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0,
            )
            try {
                EGL14.eglMakeCurrent(dpy, surf, surf, ctx)
                return mapOf(
                    "gpu" to GLES20.glGetString(GLES20.GL_RENDERER),
                    "gpuVendor" to GLES20.glGetString(GLES20.GL_VENDOR),
                    "glVersion" to GLES20.glGetString(GLES20.GL_VERSION),
                )
            } finally {
                EGL14.eglMakeCurrent(dpy, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
                EGL14.eglDestroySurface(dpy, surf)
                EGL14.eglDestroyContext(dpy, ctx)
            }
        } catch (_: Throwable) {
            return emptyMap()
        }
    }

    /**
     * What the phone is made of (CPU-Z style), sent once per launch. Only
     * public Android APIs; nothing that identifies a person (no serial, IMEI,
     * accounts or installed apps).
     */
    private fun hardwareInfo(): Map<String, Any?> {
        hwCache?.let { return it }
        val out = HashMap<String, Any?>()
        out["brand"] = Build.MANUFACTURER
        out["model"] = Build.MODEL
        out["device"] = Build.DEVICE
        out["board"] = Build.BOARD
        out["hardware"] = Build.HARDWARE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            out["soc"] = listOf(Build.SOC_MANUFACTURER, Build.SOC_MODEL).filter { it.isNotBlank() && it != "unknown" }.joinToString(" ")
        }
        out["abis"] = Build.SUPPORTED_ABIS.toList()
        out["cores"] = Runtime.getRuntime().availableProcessors()
        coreMhz("cpuinfo_max_freq")?.let { out["coreMaxMhz"] = it }
        coreMhz("cpuinfo_min_freq")?.let { out["coreMinMhz"] = it }
        readText("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")?.let { out["governor"] = it }
        try {
            val mi = ActivityManager.MemoryInfo()
            (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(mi)
            out["ramMb"] = mi.totalMem / 1048576
        } catch (_: Throwable) {}
        try {
            out["storageMb"] = StatFs(Environment.getDataDirectory().path).totalBytes / 1048576
        } catch (_: Throwable) {}
        try {
            val dm = resources.displayMetrics
            out["screen"] = "${dm.widthPixels}x${dm.heightPixels}"
            out["densityDpi"] = dm.densityDpi
            @Suppress("DEPRECATION")
            out["refreshHz"] = (getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.refreshRate.toDouble()
        } catch (_: Throwable) {}
        out["android"] = Build.VERSION.RELEASE
        out["sdk"] = Build.VERSION.SDK_INT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) out["patch"] = Build.VERSION.SECURITY_PATCH
        out["kernel"] = System.getProperty("os.version")
        out["fingerprint"] = Build.FINGERPRINT
        out.putAll(gpuInfo())
        try {
            val i = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            if (i != null) {
                out["batteryTech"] = i.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY)
                out["batteryHealth"] = when (i.getIntExtra(BatteryManager.EXTRA_HEALTH, 0)) {
                    BatteryManager.BATTERY_HEALTH_GOOD -> "good"
                    BatteryManager.BATTERY_HEALTH_OVERHEAT -> "overheat"
                    BatteryManager.BATTERY_HEALTH_DEAD -> "dead"
                    BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "over voltage"
                    BatteryManager.BATTERY_HEALTH_COLD -> "cold"
                    else -> "unknown"
                }
            }
        } catch (_: Throwable) {}
        try {
            val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            out["sensors"] = sm.getSensorList(Sensor.TYPE_ALL).map { it.name }.distinct().take(60)
        } catch (_: Throwable) {}
        try {
            val pm = packageManager
            val feats = ArrayList<String>()
            if (pm.hasSystemFeature(PackageManager.FEATURE_NFC)) feats.add("NFC")
            if (pm.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) feats.add("BLE")
            if (pm.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)) feats.add("Fingerprint")
            if (pm.hasSystemFeature(PackageManager.FEATURE_WIFI)) feats.add("Wi-Fi")
            if (pm.hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)) feats.add("Flash")
            if (pm.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) feats.add("Telephony")
            out["features"] = feats
        } catch (_: Throwable) {}
        hwCache = out
        return out
    }

    /**
     * A handful of cheap readings for the periodic pulse: nothing here
     * identifies a person, and every part is optional (an unavailable value is
     * simply left out).
     */
    private fun liveStats(): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        // CPU used by this app, as a share of the phone's total capacity since
        // the previous call (CLK_TCK is 100 on Android).
        try {
            val stat = java.io.File("/proc/self/stat").readText()
            val tail = stat.substring(stat.lastIndexOf(')') + 2).split(" ")
            val ticks = tail[11].toLong() + tail[12].toLong()
            val now = SystemClock.elapsedRealtime()
            val cores = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)
            if (lastCpuAt > 0 && now > lastCpuAt) {
                val busy = (ticks - lastCpuTicks) / 100.0
                val wall = (now - lastCpuAt) / 1000.0
                out["cpu"] = ((busy / wall) / cores * 100.0).coerceIn(0.0, 100.0)
            }
            lastCpuTicks = ticks
            lastCpuAt = now
        } catch (_: Throwable) {}
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val mi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(mi)
            out["memAvailMb"] = mi.availMem / 1048576
            out["memTotalMb"] = mi.totalMem / 1048576
            out["lowMem"] = mi.lowMemory
            val dbg = android.os.Debug.MemoryInfo()
            android.os.Debug.getMemoryInfo(dbg)
            out["rssMb"] = dbg.totalPss / 1024
        } catch (_: Throwable) {}
        try {
            val i = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            if (i != null) {
                val level = i.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = i.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
                if (level >= 0 && scale > 0) out["battery"] = level * 100 / scale
                val status = i.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                out["charging"] = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
                val temp = i.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
                if (temp != Int.MIN_VALUE) out["tempC"] = temp / 10.0
                val mv = i.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1)
                if (mv > 0) out["voltageMv"] = mv
            }
        } catch (_: Throwable) {}
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                out["thermal"] = pm.currentThermalStatus
            }
        } catch (_: Throwable) {}
        try {
            val stat = StatFs(Environment.getDataDirectory().path)
            out["storageFreeMb"] = stat.availableBytes / 1048576
            out["storageTotalMb"] = stat.totalBytes / 1048576
        } catch (_: Throwable) {}
        try {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            out["net"] = tm.networkType
        } catch (_: Throwable) {}
        try {
            // Device-wide traffic in bytes per second since the previous reading.
            val rx = TrafficStats.getTotalRxBytes()
            val tx = TrafficStats.getTotalTxBytes()
            val now = SystemClock.elapsedRealtime()
            if (rx >= 0 && tx >= 0 && lastRx >= 0 && now > lastNetAt) {
                val sec = (now - lastNetAt) / 1000.0
                out["rxBps"] = ((rx - lastRx) / sec).coerceAtLeast(0.0)
                out["txBps"] = ((tx - lastTx) / sec).coerceAtLeast(0.0)
            }
            lastRx = rx
            lastTx = tx
            lastNetAt = now
        } catch (_: Throwable) {}
        coreMhz("scaling_cur_freq")?.let { out["freq"] = it }
        return out
    }

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
        ) + extra()
}

    private fun extra(): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        // Hardware / chip / brand. `Build.HOST` exposes SoC family on a few
        // vendors (exynos, kirin); `Build.BOARD` is the carrier-board code.
        out["buildBrand"] = Build.BRAND
        out["buildBoard"] = Build.BOARD
        out["buildHardware"] = Build.HARDWARE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) { out["buildSoC"] = Build.SOC_MANUFACTURER } else { out["buildSoC"] = null }
        out["buildHost"] = Build.HOST
        out["supportedAbis"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) Build.SUPPORTED_ABIS.toList() else null
        out["fingerprint"] = Build.FINGERPRINT
        // Identity & install: Android 8+ restricts what can be read. We send
        // only stable, app-derived values - no signature, no IMEI.
        try {
            val pm = packageManager
            out["installer"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) pm.getInstallSourceInfo(packageName).installingPackageName ?: pm.getInstallerPackageName(packageName) else @Suppress("DEPRECATION") pm.getInstallerPackageName(packageName)
        } catch (_: Throwable) { out["installer"] = null }
        out["firstInstallTime"] = try { packageManager.getPackageInfo(packageName, 0).firstInstallTime } catch (_: Throwable) { null }
        out["lastUpdateTime"] = try { packageManager.getPackageInfo(packageName, 0).lastUpdateTime } catch (_: Throwable) { null }
        out["installerPackage"] = try { packageManager.getPackageInfo(packageName, 0).packageName } catch (_: Throwable) { null }
        try {
            val ctx: Context = applicationContext
            out["targetSdk"] = ctx.applicationInfo.targetSdkVersion
            out["minSdk"] = ctx.applicationInfo.minSdkVersion
        } catch (_: Throwable) {}
        // Locale + timezone (server cross-checks these for spurious locales)
        out["country"] = java.util.Locale.getDefault().country
        out["timezone"] = java.util.TimeZone.getDefault().id
        // Display
        try {
            val wm = applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION") wm.defaultDisplay.getRealMetrics(metrics)
            out["screenWidthPx"] = metrics.widthPixels
            out["screenHeightPx"] = metrics.heightPixels
            out["screenDensity"] = metrics.density
        } catch (_: Throwable) {}
        // Memory (low-cardinality)
        try {
            val am = applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val mi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(mi)
            out["totalMemoryBytes"] = mi.totalMem
        } catch (_: Throwable) {}
        // Storage
        try {
            val path = applicationContext.filesDir
            val stat = StatFs(path.absolutePath)
            out["freeInternalStorageBytes"] = stat.availableBytes
            out["totalInternalStorageBytes"] = stat.totalBytes
        } catch (_: Throwable) {}
        out["lowStorage"] = try { Environment.getDataDirectory().path.let { StatFs(it).availableBytes < 50L * 1024 * 1024 } } catch (_: Throwable) { null }
        // Battery + charging state
        try {
            val bm = applicationContext.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            out["batteryLevel"] = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            out["isCharging"] = bm.isCharging
        } catch (_: Throwable) {}
        // Network: a coarse classification is safe to send; carrier identity
        // is permission-gated, so we send the operator name and SIM country
        // when the OS already shows them in Settings.
        try {
            val tm = applicationContext.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            out["networkType"] = tm.networkType // 0=no network, see android.telephony.TelephonyManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                @Suppress("ObsoleteSdkInt") out["carrierName"] = tm.networkOperatorName
            }
        } catch (_: Throwable) {}
        // Network location: reading fine location is fine-only. Coarse is not
        // always granted; report only whether we have any permission to give
        // the server a hint about the user.
        try {
            out["hasFineLocation"] = checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        } catch (_: Throwable) {}
        // RAM runtime headroom
        try {
            val am = applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val mi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(mi)
            out["availableMemoryBytes"] = mi.availMem
        } catch (_: Throwable) {}
        // Locale-region from network, if available (SIM). Operator name and
        // country code are non-personal in most jurisdictions but still gated
        // by read_phone_state on some builds; report only when granted.
        try {
            val tm = applicationContext.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                @Suppress("ObsoleteSdkInt") out["simCountryIso"] = tm.simCountryIso
            }
        } catch (_: Throwable) {}
        return out
    }
}