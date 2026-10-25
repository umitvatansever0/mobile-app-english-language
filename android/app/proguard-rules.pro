# WorkManager (Google Mobile Ads tarafından kullanılır) Room veritabanını
# yansıma ile oluşturur. R8 bu sınıfları silerse uygulama açılışta çöker:
# "Failed to create an instance of androidx.work.impl.WorkDatabase"
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { <init>(); }

# Google Mobile Ads / UMP
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }

# RevenueCat
-keep class com.revenuecat.purchases.** { *; }
