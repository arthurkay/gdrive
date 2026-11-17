#!/bin/bash
# Regenerates the README screenshots in docs/screenshots/ from the demo
# build. Linux only; needs an unlocked X11/XWayland desktop, xwininfo and
# ImageMagick. Each shot starts the app with a scene (see
# lib/dev/demo_director.dart), waits, and captures its window.
#
#   tool/screenshots.sh            # all shots
#   tool/screenshots.sh browse     # only the named ones
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=docs/screenshots
APP=build/linux/x64/debug/bundle/gdrive
mkdir -p "$OUT"

flutter build linux --debug --dart-define=DEMO=true | tail -1

shoot() { # name scene [kit] [seconds to wait before capturing]
  local name=$1 scene=$2 kit=${3:-} wait=${4:-9}
  if [ ${#ONLY[@]} -gt 0 ] && [[ ! " ${ONLY[*]} " =~ " $name " ]]; then return; fi
  env GDK_BACKEND=x11 GDRIVE_DEMO_SCENE="$scene" ${kit:+GDRIVE_UI_KIT=$kit} \
    "$APP" >/dev/null 2>&1 &
  local pid=$!
  sleep "$wait"
  local id
  id=$(xwininfo -root -tree | grep '"GDrive"' | head -1 | awk '{print $1}')
  local captured=no
  if [ -n "$id" ]; then
    # Grabbing the window occasionally fails for a moment; try a few times.
    for _ in 1 2 3 4; do
      if import -window "$id" "$OUT/$name.png" 2>/dev/null; then
        captured=yes
        break
      fi
      sleep 1
    done
  fi
  if [ "$captured" = no ]; then
    echo "!! $name: could not capture the window"
  else
    # Cut away the black margin the window manager's shadow leaves behind,
    # then round the corners onto a transparent background.
    convert "$OUT/$name.png" -fuzz 4% -trim +repage \
      -shave 1x1 -gravity South -chop 0x3 +repage \
      \( +clone -alpha extract \
         -draw 'fill black polygon 0,0 0,10 10,0 fill white circle 10,10 10,0' \
         \( +clone -flip \) -compose Multiply -composite \
         \( +clone -flop \) -compose Multiply -composite \) \
      -alpha off -compose CopyOpacity -composite "$OUT/$name.png"
    echo "ok $name"
  fi
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

ONLY=("$@")
L="theme=light"

shoot browse      "$L;select=Quarterly report.pdf"
shoot thumbnails  "$L;grid;sync=Pictures;open=Pictures;select=Morning lake.png" "" 11
shoot preview-image "$L;sync=Pictures;open=Pictures;preview=Sunset over the hills.png" "" 11
shoot preview-pdf "$L;preview=Quarterly report.pdf"
shoot preview-code "$L;open=Projects;preview=word_count.dart"
shoot activity    "$L;sync=Pictures,Documents;page=activity" "" 11
shoot transfers   "$L;sync=Pictures,Documents;page=transfers" "" 11
shoot settings    "$L;page=settings"
shoot sign-in     "$L;signedout"
shoot dark        "theme=dark;grid;sync=Pictures;open=Pictures;select=Northern night.png" "" 11
shoot windows-look "$L;select=Team notes.md" fluent
