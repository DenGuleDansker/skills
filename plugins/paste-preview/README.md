# paste-preview

See which image you are about to paste into Claude Code before you send it.

`paste-preview.sh` runs in a separate terminal pane and watches the clipboard. Each time you copy a new image, for example a screenshot, it:

1. saves the image as a PNG in a temp directory,
2. shows it with the best method available,
3. prints the file path underneath, so you can paste the path into Claude Code instead of the image.

```
paste-preview — watching the clipboard (windows). Ctrl+C to stop.
Preview: opens in the system image viewer
Saving to: C:\Users\you\AppData\Local\Temp\paste-preview.nTUthS

── 09:48:20  image #1  (214 KB) ──
C:\Users\you\AppData\Local\Temp\paste-preview.nTUthS\clip-20260929-094820-1.png
```

## Installation

```
/plugin marketplace add DenGuleDansker/skills
/plugin install paste-preview@skills
```

Then run `/paste-preview:preview` in Claude Code. It prints the exact command to start the script, with the path filled in.

## Usage

Open a **separate** terminal pane or tab, because the script keeps running until you stop it, and run:

```bash
bash /path/to/plugins/paste-preview/scripts/paste-preview.sh
```

| Option      | Effect                                              |
| ----------- | --------------------------------------------------- |
| `--no-open` | Print paths only; never open an external viewer.   |
| `-h`, `--help` | Show help.                                       |

Press **Ctrl+C** to stop. The temp directory and all saved images are deleted.

## Behaviour

- **Polling:** the clipboard is checked about every 0.5 seconds.
- **No duplicates:** if you copy the same image twice in a row, it is shown once. Images are compared by hash.
- **Text is ignored:** only image content triggers a preview.
- **Startup:** an image that is already on the clipboard when the script starts is shown right away.
- **Cleanup:** saved images older than one hour are deleted while the script runs. Everything is removed on exit.

## Platform support

| Platform              | Clipboard tool                      | Install                                                           |
| --------------------- | ----------------------------------- | ----------------------------------------------------------------- |
| macOS                 | `pngpaste`                          | `brew install pngpaste`                                           |
| Linux (Wayland)       | `wl-paste`                          | `sudo apt install wl-clipboard` (or `dnf` / `pacman`)             |
| Linux (X11)           | `xclip`                             | `sudo apt install xclip` (or `dnf` / `pacman`)                    |
| Windows (Git Bash)    | `powershell.exe`                    | Built in. Run the script from Git Bash, MSYS2 or Cygwin.          |
| WSL                   | `powershell.exe` via WSL interop    | Built in. Requires WSL interop to be enabled.                     |

At startup the script checks that the tool it needs is installed. If it is missing, the script prints exactly what is missing and how to install it.

On Windows and WSL, a single long-running PowerShell process watches the clipboard sequence number. Starting a new `powershell.exe` twice a second would be slow and CPU-heavy.

### How images are shown

The script uses the first method that works:

1. **`kitten icat`**: inline in terminals that support the kitty graphics protocol (kitty, WezTerm, Ghostty, Konsole).
2. **`imgcat`**: inline in iTerm2 or WezTerm.
3. **System image viewer**: `open` on macOS, `xdg-open` on Linux, `explorer.exe` on Windows and WSL (usually the Photos app).

Windows Terminal cannot show images inline this way, so on Windows images open in the system viewer. Use `--no-open` if you only want the paths.

## Requirements

Bash, plus the clipboard tool for your platform and optionally an image viewer. There are no other dependencies.
