part of 'native_tray_platform.dart';

/// The tray icon's native menu: building it, updating it in place, releasing it.
extension _NativeTrayMenu on NativeTrayPlatform {
  void _buildMenu(TrayMenu menu, String structure) {
    _disposeMenu();
    final native = Menu.create();
    if (native == null) return;
    _menu = native;
    _structure = structure;
    _addItems(native, menu.entries);
    _icon?.setContextMenu(native);
  }

  void _addItems(Menu parent, List<TrayMenuEntry> entries) {
    for (final entry in entries) {
      switch (entry) {
        case TrayMenuSeparator():
          parent.addSeparator();
        case TrayMenuItem(
          :final id,
          :final label,
          :final enabled,
          :final checked,
        ):
          final item = MenuItem.createWithLabelAndType(
            label,
            checked == null ? MenuItemType.normal : MenuItemType.checkbox,
          );
          if (item == null) continue;
          item.isEnabled = enabled;
          if (checked != null) {
            item.state = checked
                ? MenuItemState.checked
                : MenuItemState.unchecked;
          }
          _itemListeners.add((
            item,
            item.addListener((event) {
              if (event is MenuItemClickedEvent) {
                _modelById[id]?.onSelected?.call();
              }
            }),
          ));
          _items[id] = item;
          parent.addItem(item);
      }
    }
  }

  void _updateItems(List<TrayMenuEntry> entries) {
    for (final entry in entries) {
      switch (entry) {
        case TrayMenuSeparator():
          break;
        case TrayMenuItem(
          :final id,
          :final label,
          :final enabled,
          :final checked,
        ):
          final item = _items[id];
          if (item == null) continue;
          item
            ..label = label
            ..isEnabled = enabled;
          if (checked != null) {
            item.state = checked
                ? MenuItemState.checked
                : MenuItemState.unchecked;
          }
      }
    }
  }

  /// Every row id, but no label: a menu whose rows changed is rebuilt, one
  /// whose traffic text changed is updated in place.
  String _structureOf(List<TrayMenuEntry> entries) => [
    for (final entry in entries)
      switch (entry) {
        TrayMenuSeparator() => '-',
        TrayMenuItem(:final id) => id,
      },
  ].join(',');

  void _disposeMenu() {
    for (final (item, listener) in _itemListeners) {
      item.removeListener(listener);
      item.dispose();
    }
    _itemListeners.clear();
    _items.clear();
    _menu?.dispose();
    _menu = null;
    _modelById = const {};
    _structure = '';
  }

  void _disposeTray() {
    _disposeMenu();
    final icon = _icon;
    final listener = _iconListener;
    _icon = null;
    _iconListener = null;
    if (icon != null) {
      if (listener != null) icon.removeListener(listener);
      icon.dispose();
    }
    final window = _window;
    final windowListener = _windowListener;
    _window = null;
    _windowListener = null;
    if (window != null && windowListener != null) {
      window.removeListener(windowListener);
    }
  }
}
