MODDIR=${0%/*}
# The app's data stays encrypted until the first unlock after boot.
until [ "$(getprop sys.boot_completed)" = 1 ] &&
  [ -d /data/user/0/top.simonshiki.yukari/files ]; do
  sleep 5
done
sh "$MODDIR/yukari.sh" start
