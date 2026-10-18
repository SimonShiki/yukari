package top.simonshiki.yukari

import android.app.PendingIntent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * The "Yukari" Quick Settings tile: it toggles what the active mode runs, the
 * network in app mode and the background service in service mode.
 *
 * The tile's state comes from [TileStateStore], which Flutter writes; the tap
 * goes to Flutter through [SystemUiChannel] while the engine can take it, and
 * otherwise opens the app with the toggle pending.
 */
class YukariTileService : TileService() {
    companion object {
        /** The bound tile while the panel is open, so it redraws at once. */
        @Volatile
        var listening: YukariTileService? = null
    }

    override fun onStartListening() {
        super.onStartListening()
        listening = this
        render()
    }

    override fun onStopListening() {
        if (listening === this) listening = null
        super.onStopListening()
    }

    override fun onDestroy() {
        if (listening === this) listening = null
        super.onDestroy()
    }

    /** Draws the state Flutter last wrote; the store calls this when bound. */
    fun render() {
        val tile = qsTile ?: return
        val state = TileStateStore.read(this)
        tile.state = if (state.active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = state.label
        tile.contentDescription = state.label
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        if (SystemUiChannel.dispatch("toggle", SystemUiChannel.SOURCE_TILE)) return
        launchApp("toggle")
    }

    /**
     * Launches the app with [action] pending, collapsing the panel. Also what
     * Flutter asks for when a background tap needs the foreground.
     */
    fun launchApp(action: String) {
        val intent = SystemUiChannel.launchIntent(this, action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // The Intent overload throws from Android 14 on.
            startActivityAndCollapse(
                PendingIntent.getActivity(
                    this,
                    0,
                    intent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
