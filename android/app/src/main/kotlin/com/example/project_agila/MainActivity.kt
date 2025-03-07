package com.example.project_agila

import io.flutter.embedding.android.FlutterFragmentActivity
import android.os.Build
import android.view.WindowManager


class MainActivity : FlutterFragmentActivity(){
    override fun onResume() {
        super.onResume()
        setHighRefreshRate()
    }

    private fun setHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window?.setAttributes(window.attributes)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
