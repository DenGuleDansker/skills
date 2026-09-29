---
description: Explain how to start the clipboard image preview in a separate terminal pane
---

Tell the user how to start **paste-preview**, a watcher that shows every new image they copy to the clipboard so they can check it before pasting it into Claude Code. Keep the answer short and practical.

The script is at:

```
${CLAUDE_PLUGIN_ROOT}/scripts/paste-preview.sh
```

Explain:

1. Open a **separate** terminal pane or tab (it runs until stopped, so it must not run inside this Claude Code session) and run:
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/paste-preview.sh"`
   On Windows, run it from Git Bash (or WSL). Show the path with forward slashes if the user is on Windows.
2. Copy a screenshot or image. Each new image is shown (inline with `kitten icat` in kitty/WezTerm/Ghostty, `imgcat` in iTerm2, otherwise in the system image viewer) and its saved PNG path is printed underneath. The same image copied twice in a row is shown once; text on the clipboard is ignored.
3. They can paste the image into Claude Code as usual, or paste the printed path.
4. `--no-open` prints paths only, without opening a viewer. Ctrl+C stops it and deletes the temp files; files older than an hour are removed automatically.
5. At startup the script checks for the clipboard tool it needs (pngpaste on macOS, wl-paste on Wayland, xclip on X11, powershell.exe on Windows/WSL) and prints the exact install command if something is missing.

If the user passed arguments ("$ARGUMENTS"), answer any follow-up question they contain.
