package top.simonshiki.yukari

import android.content.ComponentName
import android.content.Context
import android.service.quicksettings.TileService

/**
 * The Quick Settings tile's last known state.
 *
 * Flutter writes it through [SystemUiChannel] whenever the signals change; the
 * tile reads it in a later binding, when the Flutter engine may be gone.
 */
object TileStateStore {
    private const val PREFS = "yukari_tile"
    private const val ACTIVE = "active"
    private const val LABEL = "label"

    data class State(val active: Boolean, val label: String)

    /** Writes the state, or answers false when it is already that. */
    fun write(context: Context, active: Boolean, label: String): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val unchanged = prefs.getBoolean(ACTIVE, false) == active &&
            prefs.getString(LABEL, null) == label
        if (unchanged) return false
        prefs.edit().putBoolean(ACTIVE, active).putString(LABEL, label).apply()
        return true
    }

    fun read(context: Context): State {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return State(
            active = prefs.getBoolean(ACTIVE, false),
            label = prefs.getString(LABEL, null) ?: context.getString(R.string.tile_label),
        )
    }

    /** Shows the state just written, on the open panel or on the next bind. */
    fun requestUpdate(context: Context) {
        val bound = YukariTileService.listening
        if (bound != null) {
            bound.render()
            return
        }
        try {
            TileService.requestListeningState(
                context,
                ComponentName(context, YukariTileService::class.java),
            )
        } catch (error: Exception) {
            // Only the current user may ask, and only while the tile is added.
        }
    }
}
