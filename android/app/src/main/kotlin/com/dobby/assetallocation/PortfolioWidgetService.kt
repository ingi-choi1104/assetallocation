package com.dobby.assetallocation

import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class PortfolioWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        PortfolioWidgetFactory(applicationContext)
}

class PortfolioWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private data class PortfolioItem(val name: String, val value: Double)

    private val items = mutableListOf<PortfolioItem>()

    private val PORTFOLIO_SQL = """
        SELECT p.name,
               COALESCE(SUM(
                   COALESCE(h.net_qty, 0) * COALESCE(a.last_price, 0) *
                   CASE WHEN UPPER(a.currency) = 'USD'
                       THEN COALESCE((
                           SELECT t2.exchange_rate FROM transactions t2
                           JOIN portfolio_assets pa2 ON pa2.id = t2.portfolio_asset_id
                           WHERE pa2.asset_id = a.id AND t2.exchange_rate > 1
                           ORDER BY t2.transaction_date DESC LIMIT 1
                       ), 1300.0)
                       ELSE 1.0
                   END
               ), 0.0) AS portfolio_value
        FROM portfolios p
        LEFT JOIN portfolio_assets pa ON pa.portfolio_id = p.id
        LEFT JOIN assets a ON a.id = pa.asset_id
        LEFT JOIN (
            SELECT portfolio_asset_id,
                   SUM(CASE WHEN type = 'buy' THEN quantity ELSE -quantity END) AS net_qty
            FROM transactions GROUP BY portfolio_asset_id
        ) h ON h.portfolio_asset_id = pa.id
        GROUP BY p.id, p.name
        ORDER BY portfolio_value DESC
    """.trimIndent()

    override fun onCreate() = loadData()
    override fun onDataSetChanged() = loadData()
    override fun onDestroy() = items.clear()

    override fun getCount() = items.size
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = true
    override fun getViewTypeCount() = 1
    override fun getLoadingView() = null

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_portfolio_item)
        if (position < items.size) {
            val item = items[position]
            views.setTextViewText(R.id.item_name, item.name)
            views.setTextViewText(R.id.item_value, PortfolioWidget.formatKRW(item.value))
        }
        return views
    }

    private fun loadData() {
        items.clear()
        val dbFile = context.getDatabasePath("asset_allocation")
        if (!dbFile.exists()) return
        try {
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
            val cursor = db.rawQuery(PORTFOLIO_SQL, null)
            while (cursor.moveToNext()) {
                items.add(PortfolioItem(
                    name = cursor.getString(0) ?: "",
                    value = cursor.getDouble(1)
                ))
            }
            cursor.close()
            db.close()
        } catch (_: Exception) {
            // DB 접근 실패 시 빈 목록 유지
        }
    }
}
