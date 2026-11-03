# Starts, stops or reports the Yukari service, which runs the networks the
# Yukari app saved. Run as root: sh yukari.sh start|stop|status
#
# The service is the Linux build of packages/yukari_core/bin/yukari_service.dart,
# as Dart cannot build for Android, so it runs on the glibc bundled in lib/.
MODDIR=${0%/*}
APP_DATA=/data/user/0/top.simonshiki.yukari
# The restart loop of the running service.
PIDFILE=/dev/yukari_service.pid
# Matches the service, run from whichever copy of the module.
PATTERN='yukari-service\.aot run'

running() { pgrep -f "$PATTERN" >/dev/null; }

looping() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

case $1 in
  start)
    if running || looping; then exit 0; fi
    if [ -f "$MODDIR/disable" ]; then
      echo "The Yukari service module is disabled" >&2
      exit 1
    fi
    if [ ! -d "$APP_DATA/files" ]; then
      echo "Open Yukari before starting the service" >&2
      exit 1
    fi
    # EasyTier's Linux build opens /dev/net/tun, which Android keeps at /dev/tun.
    if [ ! -e /dev/net/tun ]; then
      mkdir -p /dev/net && ln -s /dev/tun /dev/net/tun
    fi
    # Android routes through tables of its own; consult the main table, where
    # EasyTier adds its routes, as well.
    ip rule show | grep -qE '^[0-9]+:[[:space:]]+from all lookup main$' ||
      ip rule add from all lookup main
    # A new shell, unlike a subshell, holds none of the caller's descriptors,
    # which would keep su's output, and so the app, waiting.
    setsid sh "$0" supervise </dev/null >"$MODDIR/service.log" 2>&1 &
    echo $! >"$PIDFILE"
    ;;
  supervise)
    owner=$(stat -c %u "$APP_DATA")
    set -- "$MODDIR"/lib/ld-linux-*
    loader=$1
    # Restarts the service after it fails, not after it is stopped.
    # The Linux build is told it runs on Android, where only packet
    # interception can send a zone's lookups to Magic DNS.
    until YUKARI_ANDROID_DNS=1 "$loader" --library-path "$MODDIR/lib" \
      "$MODDIR/bin/dartaotruntime" \
      "$MODDIR/bin/yukari-service.aot" run \
      --data-dir "$APP_DATA/files" --owner-uid "$owner"; do
      sleep 2
    done
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      kill "$(cat "$PIDFILE")" 2>/dev/null
      rm -f "$PIDFILE"
    fi
    pkill -f "$PATTERN" || exit 0
    # The service stops its networks first.
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      running || exit 0
      sleep 1
    done
    pkill -9 -f "$PATTERN"
    ;;
  status)
    if running; then echo running; else echo stopped; fi
    ;;
  *)
    echo "Usage: sh yukari.sh start|stop|status" >&2
    exit 64
    ;;
esac
