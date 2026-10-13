# Only applied to the synthetic release integration target, never lib/main.dart.
# AndroidJUnitRunner references tracing APIs otherwise inlined by app R8.
-keep class androidx.tracing.** { *; }
# The runner shares the app's Kotlin runtime. Facades such as LazyKt are
# normally inlined away, but the independently compiled test APK still uses them.
-keep class kotlin.** { *; }
-keep class androidx.fragment.app.FragmentActivity {
    public androidx.fragment.app.FragmentManager getSupportFragmentManager();
}
-keep class androidx.fragment.app.FragmentManager {
    public java.util.List getFragments();
}
# Result delivery connects to the real Flutter engine from the test APK.
-keep class io.flutter.embedding.android.FlutterFragment { public *; }
-keep class io.flutter.embedding.engine.FlutterEngine {
    public io.flutter.embedding.engine.dart.DartExecutor getDartExecutor();
}
-keep class io.flutter.embedding.engine.dart.DartExecutor {
    public io.flutter.plugin.common.BinaryMessenger getBinaryMessenger();
}
-keep class io.flutter.plugin.common.MethodChannel { public *; }
-keep interface io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep interface io.flutter.plugin.common.MethodChannel$Result { *; }
-keep class io.flutter.plugin.common.MethodCall { public *; }
