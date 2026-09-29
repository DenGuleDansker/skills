#!/usr/bin/env bash
# paste-preview.sh — watch the clipboard and preview every new image, so you
# can see what you are about to paste into Claude Code.
#
# Run it in a separate terminal pane. Each new image is saved as a PNG in a
# temp directory, shown with the best available method (kitten icat, imgcat,
# or the system image viewer) and its path is printed underneath.
#
# Supported: macOS (pngpaste), Linux Wayland (wl-paste), Linux X11 (xclip),
# Windows via Git Bash/MSYS2/Cygwin and WSL (powershell.exe).
#
# Options:
#   --no-open   never open an external viewer, only print the path
#   -h, --help  show this help

set -u

POLL_INTERVAL=0.5   # seconds between clipboard checks
MAX_AGE_MIN=60      # delete saved images older than this
NO_OPEN=0

for arg in "$@"; do
  case "$arg" in
    --no-open) NO_OPEN=1 ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------- platform --

detect_platform() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then echo wsl
      elif [ -n "${WAYLAND_DISPLAY:-}" ]; then echo wayland
      else echo x11
      fi ;;
    *) echo unknown ;;
  esac
}

PLATFORM=$(detect_platform)

have() { command -v "$1" >/dev/null 2>&1; }

# Convert a local path to the form the rest of the OS (and Claude Code) uses.
native_path() {
  case "$PLATFORM" in
    windows) cygpath -w "$1" ;;
    wsl) wslpath -w "$1" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# Path printed for pasting into Claude Code. In WSL, Claude Code normally
# runs inside Linux too, so the Linux path is the useful one.
display_path() {
  if [ "$PLATFORM" = windows ]; then cygpath -w "$1"; else printf '%s\n' "$1"; fi
}

hash_file() {
  if have sha256sum; then sha256sum "$1" | cut -d' ' -f1
  elif have shasum; then shasum -a 256 "$1" | cut -d' ' -f1
  else cksum "$1" | cut -d' ' -f1-2
  fi
}

# ------------------------------------------------------------ dependencies --

MISSING=()

check_clipboard_tool() {
  case "$PLATFORM" in
    macos)
      have pngpaste || MISSING+=("pngpaste — install with: brew install pngpaste") ;;
    wayland)
      have wl-paste || MISSING+=("wl-paste — install the wl-clipboard package: sudo apt install wl-clipboard  (Fedora: sudo dnf install wl-clipboard, Arch: sudo pacman -S wl-clipboard)") ;;
    x11)
      have xclip || MISSING+=("xclip — install with: sudo apt install xclip  (Fedora: sudo dnf install xclip, Arch: sudo pacman -S xclip)") ;;
    windows|wsl)
      have powershell.exe || MISSING+=("powershell.exe — ships with Windows; make sure C:\\Windows\\System32\\WindowsPowerShell\\v1.0 is on PATH (in WSL: enable interop and appendWindowsPath in /etc/wsl.conf)") ;;
    *)
      MISSING+=("a supported OS — detected '$(uname -s)'; supported are macOS, Linux (X11/Wayland), Windows (Git Bash) and WSL") ;;
  esac
  [ "$PLATFORM" = windows ] && ! have cygpath && MISSING+=("cygpath — run this script from Git Bash, MSYS2 or Cygwin")
  [ "$PLATFORM" = wsl ] && ! have wslpath && MISSING+=("wslpath — update WSL: wsl --update (from Windows)")
}

# Pick how to show images: kitten icat > imgcat > system viewer > none.
VIEWER=none
choose_viewer() {
  if have kitten && kitten icat --detect-support >/dev/null 2>&1; then
    VIEWER=kitten; return
  fi
  if have imgcat && { [ "${TERM_PROGRAM:-}" = iTerm.app ] || [ "${TERM_PROGRAM:-}" = WezTerm ]; }; then
    VIEWER=imgcat; return
  fi
  [ "$NO_OPEN" = 1 ] && return
  case "$PLATFORM" in
    macos) VIEWER=system ;;  # 'open' is always present
    windows|wsl) have explorer.exe && VIEWER=system ;;
    wayland|x11) have xdg-open && VIEWER=system ;;
  esac
}

viewer_hint() {
  case "$VIEWER" in
    kitten) echo "Preview: inline via kitten icat" ;;
    imgcat) echo "Preview: inline via imgcat" ;;
    system)
      echo "Preview: opens in the system image viewer"
      echo "  (for inline previews use kitty/WezTerm/Ghostty with 'kitten icat', or iTerm2 with 'imgcat')" ;;
    none)
      if [ "$NO_OPEN" = 1 ]; then echo "Preview: off (--no-open), paths only"
      else
        echo "Preview: no image viewer found — only paths will be printed."
        case "$PLATFORM" in
          wayland|x11) echo "  Install xdg-open with: sudo apt install xdg-utils" ;;
          windows|wsl) echo "  explorer.exe was not found on PATH." ;;
        esac
      fi ;;
  esac
}

# ----------------------------------------------------------------- temp dir --

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/paste-preview.XXXXXX") || { echo "Could not create temp dir" >&2; exit 1; }
PRODUCER_PID=

cleanup() {
  trap - EXIT INT TERM
  rm -rf "$TMP_DIR"            # also tells the PowerShell watcher to exit
  [ -n "$PRODUCER_PID" ] && kill "$PRODUCER_PID" 2>/dev/null
  echo
  echo "paste-preview stopped, temp files removed."
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

prune_old_files() {
  find "$TMP_DIR" -name 'clip-*.png' -mmin +"$MAX_AGE_MIN" -delete 2>/dev/null
}

# ---------------------------------------------------------------- producers --
# A producer prints the path of a freshly grabbed PNG on stdout each time it
# sees an image on the clipboard. Text and other content are ignored.

grab_unix() {  # $1 = output file; succeeds only if an image was written
  case "$PLATFORM" in
    macos) pngpaste "$1" >/dev/null 2>&1 ;;
    wayland)
      wl-paste --list-types 2>/dev/null | grep -qx 'image/png' &&
        wl-paste --no-newline --type image/png >"$1" 2>/dev/null ;;
    x11)
      xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -qx 'image/png' &&
        xclip -selection clipboard -t image/png -o >"$1" 2>/dev/null ;;
  esac && [ -s "$1" ]
}

unix_producer() {
  local i=0 f
  while [ -d "$TMP_DIR" ]; do
    i=$((i + 1))
    f="$TMP_DIR/incoming-$i.png"
    if grab_unix "$f"; then echo "$f"; else rm -f "$f"; fi
    sleep "$POLL_INTERVAL"
  done
}

# On Windows a PowerShell start costs ~0.5 s, so instead of launching it every
# poll we keep one watcher running. It only reads the clipboard when Windows'
# clipboard sequence number changes, and exits when the temp dir disappears.
windows_producer() {
  local ps1="$TMP_DIR/watch.ps1"
  cat >"$ps1" <<'PS'
param([string]$Dir, [int]$IntervalMs)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace PastePreview -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber();
'@
$last = [uint32]0
$i = 0
while (Test-Path -LiteralPath $Dir) {
  $seq = [PastePreview.Native]::GetClipboardSequenceNumber()
  if ($seq -ne $last) {
    try {
      if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
        $img = [System.Windows.Forms.Clipboard]::GetImage()
        if ($img) {
          $i++
          $path = Join-Path $Dir "incoming-$i.png"
          $img.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
          $img.Dispose()
          [Console]::Out.WriteLine($path)
          [Console]::Out.Flush()
        }
      }
      $last = $seq
    } catch {
      # Clipboard is briefly locked by another app; retry on the next tick.
    }
  }
  Start-Sleep -Milliseconds $IntervalMs
}
PS
  local interval_ms
  interval_ms=$(awk -v s="$POLL_INTERVAL" 'BEGIN { printf "%d", s * 1000 }')
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -STA \
    -File "$(native_path "$ps1")" -Dir "$(native_path "$TMP_DIR")" -IntervalMs "$interval_ms" 2>/dev/null |
    while IFS= read -r line; do
      line=${line%$'\r'}
      # PowerShell prints Windows paths; map them back to local ones.
      case "$PLATFORM" in
        windows) cygpath -u "$line" ;;
        wsl) wslpath -u "$line" ;;
      esac
    done
}

# ------------------------------------------------------------------ display --

show_image() {
  case "$VIEWER" in
    kitten) kitten icat --align left "$1" ;;
    imgcat) imgcat "$1" ;;
    system)
      case "$PLATFORM" in
        macos) open "$1" ;;
        windows|wsl) explorer.exe "$(native_path "$1")" >/dev/null 2>&1 & ;;
        *) xdg-open "$1" >/dev/null 2>&1 & ;;
      esac ;;
  esac
}

human_size() {
  local b
  b=$(wc -c <"$1" | tr -d ' ')
  if [ "$b" -ge 1048576 ]; then awk -v b="$b" 'BEGIN { printf "%.1f MB", b / 1048576 }'
  else awk -v b="$b" 'BEGIN { printf "%.0f KB", b / 1024 }'
  fi
}

# --------------------------------------------------------------------- main --

check_clipboard_tool
if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "paste-preview cannot start — missing:" >&2
  for m in "${MISSING[@]}"; do echo "  - $m" >&2; done
  exit 1
fi
choose_viewer

echo "paste-preview — watching the clipboard ($PLATFORM). Ctrl+C to stop."
viewer_hint
echo "Saving to: $(display_path "$TMP_DIR")"
echo

case "$PLATFORM" in
  windows|wsl) exec 3< <(windows_producer) ;;
  *) exec 3< <(unix_producer) ;;
esac
PRODUCER_PID=$!

last_hash=
count=0
while :; do
  if IFS= read -r -t 30 incoming <&3; then
    [ -f "$incoming" ] || continue
    h=$(hash_file "$incoming")
    if [ "$h" = "$last_hash" ]; then
      rm -f "$incoming"
      continue
    fi
    last_hash=$h
    count=$((count + 1))
    saved="$TMP_DIR/clip-$(date +%Y%m%d-%H%M%S)-$count.png"
    mv "$incoming" "$saved"
    echo "── $(date +%H:%M:%S)  image #$count  ($(human_size "$saved")) ──"
    show_image "$saved"
    display_path "$saved"
    echo
  elif [ $? -le 128 ]; then
    echo "Clipboard watcher stopped unexpectedly." >&2
    exit 1
  fi
  prune_old_files   # runs at least every 30 s, even when nothing is copied
done
