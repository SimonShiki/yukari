# Keeps the build for this device's architecture.
case $ARCH in
  arm64 | x64) ;;
  *) abort "! The Yukari service supports arm64 and x64, not $ARCH" ;;
esac
mv "$MODPATH/$ARCH/bin" "$MODPATH/$ARCH/lib" "$MODPATH/"
rm -rf "$MODPATH/arm64" "$MODPATH/x64"
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm_recursive "$MODPATH/bin" 0 0 0755 0755
set_perm_recursive "$MODPATH/lib" 0 0 0755 0755
ui_print "- In Yukari, choose Settings > Service to run networks here"
