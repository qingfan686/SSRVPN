package com.qingfanvpn.android

internal object NativeApiSecretResolver {
    fun resolve(explicitSecret: String?, storedSecret: String?): String =
        explicitSecret?.takeIf { it.isNotBlank() }
            ?: storedSecret?.takeIf { it.isNotBlank() }
            ?: ""

    fun resolve(explicitSecret: String?, storedSecret: () -> String?): String =
        explicitSecret?.takeIf { it.isNotBlank() }
            ?: storedSecret()?.takeIf { it.isNotBlank() }
            ?: ""
}
