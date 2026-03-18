package com.milkman.mealvanaendurance

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.linusu.flutter_web_auth_2.FlutterWebAuth2Plugin

/**
 * Custom OAuth callback activity that brings MainActivity back to the foreground
 * after receiving the OAuth redirect.
 *
 * On iOS, ASWebAuthenticationSession auto-closes when the callback URL is received.
 * On Android, Custom Tabs don't auto-close — so we explicitly launch MainActivity
 * with FLAG_ACTIVITY_CLEAR_TOP to bring the app back to the foreground and dismiss
 * the Custom Tab.
 */
class OAuthCallbackActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val url = intent?.data
        val scheme = url?.scheme

        if (scheme != null) {
            FlutterWebAuth2Plugin.callbacks.remove(scheme)?.success(url.toString())
        }

        // Bring the existing MainActivity back to the foreground, dismissing the Custom Tab.
        // FLAG_ACTIVITY_NEW_TASK is required because OAuthCallbackActivity runs in a different
        // task than MainActivity (which has taskAffinity=""). Without it, CLEAR_TOP can't find
        // the existing instance and creates a new one, restarting the app.
        val mainIntent = Intent(this, MainActivity::class.java)
        mainIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        startActivity(mainIntent)

        finish()
    }
}
