#!/usr/bin/env bash
# open-session.sh <prompt-file> [working-dir]
#
# Opens a new terminal tab/window in working-dir (default: current dir) and
# starts a new Claude Code session with the contents of prompt-file as its
# first message. The prompt never goes through a command line: a small
# launcher script reads it from the file, so quotes and newlines survive.
#
# Supported: Windows Terminal (Git Bash / MSYS / WSL), macOS Terminal, tmux,
# and common Linux terminal emulators. Exits 1 if no way to open a new
# terminal was found, so the caller can fall back to copy/paste.

set -u

prompt_file=${1:?usage: open-session.sh <prompt-file> [working-dir]}
workdir=${2:-$PWD}

[ -s "$prompt_file" ] || { echo "Prompt file is empty or missing: $prompt_file" >&2; exit 1; }
claude_bin=$(command -v claude) || { echo "claude was not found on PATH" >&2; exit 1; }

# Keep the prompt and launcher next to each other in a private temp dir.
dir=$(mktemp -d "${TMPDIR:-/tmp}/ship.XXXXXX") || exit 1
cp "$prompt_file" "$dir/prompt.md"

cat >"$dir/run.sh" <<EOF
#!/usr/bin/env bash
cd $(printf '%q' "$workdir") || exit 1
prompt=\$(cat $(printf '%q' "$dir/prompt.md"))
rm -rf $(printf '%q' "$dir")
# The new terminal inherits the environment of the Claude Code session that
# launched it. Drop that session's markers so the new one is a normal,
# top-level session (otherwise it treats itself as a child and doesn't save
# its transcript).
unset CLAUDECODE CLAUDE_CODE_CHILD_SESSION CLAUDE_CODE_SESSION_ID CLAUDE_PID \\
  CLAUDE_EFFORT CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_EXECPATH CLAUDE_CODE_SESSION_ATTENDED \\
  CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_MESSAGING_TOKEN
exec $(printf '%q' "$claude_bin") "\$prompt"
EOF
chmod +x "$dir/run.sh"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v wt.exe >/dev/null 2>&1; then
      git_bash="$(cygpath -w /)bin\\bash.exe"
      wt.exe -w 0 new-tab -d "$(cygpath -w "$workdir")" "$git_bash" -l "$(cygpath -w "$dir/run.sh")" &&
        { echo "Opened a new Windows Terminal tab."; exit 0; }
    fi ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null && command -v wt.exe >/dev/null 2>&1; then
      wt.exe -w 0 new-tab wsl.exe -d "${WSL_DISTRO_NAME:-}" --cd "$workdir" bash -l "$dir/run.sh" &&
        { echo "Opened a new Windows Terminal tab (WSL)."; exit 0; }
    fi ;;
  Darwin)
    osascript -e "tell application \"Terminal\" to do script \"bash $(printf '%q' "$dir/run.sh")\"" \
      -e 'tell application "Terminal" to activate' >/dev/null &&
      { echo "Opened a new Terminal window."; exit 0; } ;;
esac

if [ -n "${TMUX:-}" ]; then
  tmux new-window -c "$workdir" "bash $(printf '%q' "$dir/run.sh")" && { echo "Opened a new tmux window."; exit 0; }
fi
for term in x-terminal-emulator gnome-terminal konsole kitty wezterm alacritty; do
  if command -v "$term" >/dev/null 2>&1; then
    case "$term" in
      wezterm) wezterm start --cwd "$workdir" -- bash "$dir/run.sh" & ;;
      *) "$term" -e bash "$dir/run.sh" & ;;
    esac
    echo "Opened a new $term window."; exit 0
  fi
done

rm -rf "$dir"
echo "Could not find a way to open a new terminal on this system." >&2
exit 1
