# WorkManager's Room-backed WorkDatabase_Impl is only referenced via
# reflection, so R8 strips it as unused, which crashes the app on launch
# with "Unable to get provider androidx.startup.InitializationProvider" /
# "Failed to create an instance of androidx.work.impl.WorkDatabase".
# WorkManager is pulled in transitively by google_mobile_ads; this app does
# not use it directly.
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.ListenableWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}
