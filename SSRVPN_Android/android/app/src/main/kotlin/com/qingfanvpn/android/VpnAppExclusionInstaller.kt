package com.qingfanvpn.android

import android.content.pm.PackageManager
import android.net.VpnService

internal object VpnAppExclusionInstaller {
    private val adbPackages = listOf(
        "com.android.adb",
        "com.google.android.adb"
    )

    fun install(
        builder: VpnService.Builder,
        bypassDomesticApps: Boolean,
        perAppMode: String = "none",
        perAppPackages: List<String> = emptyList()
    ): List<String> = install(bypassDomesticApps, perAppMode, perAppPackages) { packageName ->
        addIfInstalled(builder, packageName)
    }

    internal fun install(
        bypassDomesticApps: Boolean,
        perAppMode: String,
        perAppPackages: List<String>,
        addDisallowedApplication: (String) -> Boolean
    ): List<String> {
        val bypassedDomesticApps = if (bypassDomesticApps) {
            DomesticAppBypassPolicy.applyInstalled(addDisallowedApplication)
        } else {
            emptyList()
        }
        adbPackages.forEach { packageName ->
            addDisallowedApplication(packageName)
        }
        // 黑名单模式：选中的应用不走代理（排除）
        if (perAppMode == "blacklist") {
            perAppPackages.forEach { packageName ->
                addDisallowedApplication(packageName)
            }
        }
        return bypassedDomesticApps
    }

    /**
     * 白名单模式：只允许选中的应用走代理。
     * 需要调用 builder.addAllowedApplication()，与黑名单逻辑不同。
     */
    fun installWhitelist(
        builder: VpnService.Builder,
        allowedPackages: List<String>
    ) {
        allowedPackages.forEach { packageName ->
            try {
                builder.addAllowedApplication(packageName)
            } catch (_: PackageManager.NameNotFoundException) {
            }
        }
    }

    private fun addIfInstalled(
        builder: VpnService.Builder,
        packageName: String
    ): Boolean = try {
        builder.addDisallowedApplication(packageName)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }
}
