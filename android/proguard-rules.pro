# Added alongside build.gradle's buildTypes.release.minifyEnabled — see that
# file's comment for why R8 is on at all. Kept deliberately conservative:
# this app has no native Android SDKs to account for (Google Sign-In and
# Firebase both go through plain QNetworkAccessManager HTTPS calls, not
# native client libraries — see GoogleSignInHelper's and FirebaseAiHelper's
# own header comments), so the only things that actually need protecting
# from R8 are Qt's own bridge and this app's one custom Activity.

# Qt's own Android bridge (QtActivityBase, QtNative, etc.) reaches across
# the Java/native boundary by class and method name — Qt's own Android
# deployment docs call for keeping all of it rather than picking apart
# which specific members are reflectively accessed.
-keep class org.qtproject.qt.** { *; }
-keep interface org.qtproject.qt.** { *; }

# This app's own Activity — referenced by fully-qualified name from
# AndroidManifest.xml's android:name attribute. If R8 renames it, Android's
# manifest-based instantiation throws ClassNotFoundException and the app
# never launches. Its nativeOnNewIntent() native method is also looked up
# by C++ via that exact class+method name (see PassepartoutActivity.java).
-keep class com.alphahamster.passepartout.PassepartoutActivity { *; }

# Any class with a native method, anywhere — JNI registration matches
# against its Java-side name and signature, whichever class it's on.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Referenced by fully-qualified name from AndroidManifest.xml's <provider>
# entry (this app's own share-file provider). androidx.core's AAR already
# ships its own consumer rules for this, but keeping it explicitly here
# costs nothing and doesn't depend on that still being true in some future
# androidx.core version.
-keep class androidx.core.content.FileProvider { *; }

# Standard boilerplate: any Android framework component subclass, even
# though the two above (QtApplication, PassepartoutActivity) are the only
# ones this app actually declares — cheap insurance against anything else
# reached by the OS via reflection rather than an obvious call from source.
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Silences R8 warnings about optional annotation classes some dependencies
# reference at compile time but never actually need present at runtime.
-dontwarn org.jetbrains.annotations.**
