# WGDot v4.6.0 Yazi

WGDot v4.6.0 is the biggest Yazi-focused update to the Windows dots so far, turning Yazi into a much more complete mouse-and-keyboard file manager while keeping its fast terminal workflow.

## Install and update

- **Install:** [INSTALL.md](https://github.com/dillacorn/win-glaze-dots/blob/main/INSTALL.md)
- **Update:** [UPDATE.md](https://github.com/dillacorn/win-glaze-dots/blob/main/UPDATE.md)

## Yazi

- Mouse-first file management now supports first-click selection, second-click open/enter, middle-click new tabs, selection-aware context menus, drag-to-folder copy/move, and keyboard parity for the same core actions.
- Persistent bookmarks and recently opened items now use real filesystem collection folders instead of a custom VFS. `g b` and `g r` open those collections, markers resolve safely to their real targets, collection deletion never deletes the real file, stale entries are pruned lazily on activation, and history is bounded to 1000 entries.
- Preview handling received a major usability pass: `m v` hides/shows preview, `m x` maximizes/restores it, clickable controls now teach those shortcuts directly, text wrapping reflows naturally, and preview resizing relies on Yazi's native `app:resize` path instead of redundant forced regeneration that caused PDF/image flicker.
- `m c` opens highlighted text-like files in a selectable plain-text terminal view without requiring preview maximization first. Windows Terminal owns mouse selection/copy while Yazi is suspended, and Enter returns to Yazi.
- Yazi now includes clickable breadcrumbs, a searchable `Ctrl+F` chooser, a safer delete chooser, tab shortcuts, Git status signs, drive navigation, task feedback, square managed styling, and clearer active-command header coloring.
- WGDot now detects a running Yazi before an update that will overwrite managed Yazi files. It asks before closing Yazi and cancels before partial managed writes if the user declines or Yazi cannot be closed cleanly.

## Other polish

- WGDot's managed Micro colorschemes now install in Micro's normal config path and stay aligned with WGDot theme selection.
- Windows Terminal theme/ANSI handling was refined so terminal and Yazi colors remain readable across managed themes.

## Validation

- Exact release target: `1b2a87f619e14a15fd29c52913372dd434691493`.
- All 4 WGDot checks passed on the exact merged `main` release target.
- The maintainer runtime-tested the Windows Yazi work before merge, including bookmarks/recents, delete behavior, preview maximize/restore and redraw, clickable breadcrumbs, text selection, and the real-folder collection model.
