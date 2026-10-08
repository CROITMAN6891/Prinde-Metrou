# google_mobile_ads pulls in WorkManager 2.7.0 / Room 2.2.5, whose keep rule
# (-keep class * extends androidx.room.RoomDatabase) does not keep the
# no-arg constructor under R8 full mode (default since AGP 8). Room creates
# WorkDatabase_Impl reflectively at startup, so without it the release app
# crashes before the first frame.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
