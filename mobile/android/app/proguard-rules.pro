# uCrop references OkHttp for remote URI loading, but this app crops only
# local user-selected files. Suppress those optional warnings so release
# shrinking does not fail on unused classes.
-dontwarn okhttp3.Call
-dontwarn okhttp3.Dispatcher
-dontwarn okhttp3.OkHttpClient
-dontwarn okhttp3.Request
-dontwarn okhttp3.Request$Builder
-dontwarn okhttp3.Response
-dontwarn okhttp3.ResponseBody
