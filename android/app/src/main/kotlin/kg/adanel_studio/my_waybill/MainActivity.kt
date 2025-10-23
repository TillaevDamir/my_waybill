package kg.adanel_studio.my_waybill

import io.flutter.embedding.android.FlutterActivity
import androidx.core.view.WindowCompat // Для Edge-to-Edge
import android.os.Bundle // Необходим для переопределения onCreate

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // 1. Установка Edge-to-Edge (от края до края)
        // Позволяет приложению рисовать контент под системными панелями
        WindowCompat.setDecorFitsSystemWindows(window, false)

        super.onCreate(savedInstanceState)
    }
}