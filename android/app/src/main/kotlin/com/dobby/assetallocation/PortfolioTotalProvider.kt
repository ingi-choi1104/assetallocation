package com.dobby.assetallocation

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.UriMatcher
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri

/**
 * ContentProvider that exposes the cached total portfolio value (KRW) to other apps.
 * Query URI: content://com.dobby.assetallocation.provider/portfolio_total
 * Returns a single row with column "total_krw" (Double, in KRW).
 *
 * The value is cached by the Flutter app into SharedPreferences ("FlutterSharedPreferences")
 * under the key "flutter.portfolio_total_krw" whenever globalMetricsProvider updates.
 * This avoids any direct SQLite access and WAL-mode issues.
 */
class PortfolioTotalProvider : ContentProvider() {

    companion object {
        const val AUTHORITY = "com.dobby.assetallocation.provider"
        private const val CODE_TOTAL = 1

        // Flutter SharedPreferences stores all keys with "flutter." prefix
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREFS_KEY  = "flutter.portfolio_total_krw"

        private val uriMatcher = UriMatcher(UriMatcher.NO_MATCH).apply {
            addURI(AUTHORITY, "portfolio_total", CODE_TOTAL)
        }
    }

    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<String>?,
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?
    ): Cursor? {
        if (uriMatcher.match(uri) != CODE_TOTAL) return null

        val ctx = context ?: return null
        val result = MatrixCursor(arrayOf("total_krw"))

        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val totalStr = prefs.getString(PREFS_KEY, null)
        val total = totalStr?.toDoubleOrNull() ?: 0.0

        result.addRow(arrayOf(total))
        return result
    }

    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<String>?): Int = 0
}
