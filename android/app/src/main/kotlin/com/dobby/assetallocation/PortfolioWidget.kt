package com.dobby.assetallocation

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Locale

class PortfolioWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        private val TOTAL_SQL = """
            SELECT COALESCE(SUM(
                h.net_qty * COALESCE(a.last_price, 0) *
                CASE WHEN UPPER(a.currency) = 'USD'
                    THEN COALESCE((
                        SELECT t2.exchange_rate FROM transactions t2
                        JOIN portfolio_assets pa2 ON pa2.id = t2.portfolio_asset_id
                        WHERE pa2.asset_id = a.id AND t2.exchange_rate > 1
                        ORDER BY t2.transaction_date DESC LIMIT 1
                    ), 1300.0)
                    ELSE 1.0
                END
            ), 0.0)
            FROM assets a
            JOIN portfolio_assets pa ON pa.asset_id = a.id
            JOIN (
                SELECT portfolio_asset_id,
                       SUM(CASE WHEN type = 'buy' THEN quantity ELSE -quantity END) AS net_qty
                FROM transactions GROUP BY portfolio_asset_id
            ) h ON h.portfolio_asset_id = pa.id
            WHERE a.last_price IS NOT NULL AND h.net_qty > 0
        """.trimIndent()

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_portfolio)

            // 앱 실행 PendingIntent
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pi = PendingIntent.getActivity(
                    context, 0, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_total, pi)
            }

            // 총 자산
            val total = queryTotal(context)
            views.setTextViewText(R.id.widget_total, formatKRW(total))

            // ListView 어댑터
            val serviceIntent = Intent(context, PortfolioWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = android.net.Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
        }

        private fun queryTotal(context: Context): Double {
            val dbFile = context.getDatabasePath("asset_allocation")
            if (!dbFile.exists()) return 0.0
            return try {
                val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
                val cursor = db.rawQuery(TOTAL_SQL, null)
                val value = if (cursor.moveToFirst()) cursor.getDouble(0) else 0.0
                cursor.close()
                db.close()
                value
            } catch (_: Exception) {
                0.0
            }
        }

        fun formatKRW(value: Double): String {
            return when {
                value >= 100_000_000 -> "₩${String.format(Locale.getDefault(), "%.1f", value / 100_000_000)}억"
                value >= 10_000 -> "₩${String.format(Locale.getDefault(), "%.0f", value / 10_000)}만"
                else -> "₩${NumberFormat.getNumberInstance(Locale.KOREA).format(value.toLong())}"
            }
        }
    }
}
