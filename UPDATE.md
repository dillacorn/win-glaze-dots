# Update WGDot / win-glaze-dots

For normal updates:

```powershell
wgdot update
```

WGDot updates the installed runtime when needed and applies managed dotfiles from the latest compatible stable release. Local differences are reviewed/backed up through WGDot's normal managed-file safeguards.

Useful commands:

```powershell
wgdot                 # maintenance menu
wgdot review          # preview managed-file changes
wgdot reset           # reset/reconfigure managed files
wgdot software        # software/startup manager
wgdot gpu-driver      # GPU driver maintenance
wgdot status          # runtime/config state
```

Unreleased branch testing stays separate from stable updates:

```powershell
wgdot git-review --branch <branch> --revision <40-character-sha>
wgdot git-update --branch <branch> --revision <40-character-sha>
wgdot git-reset --branch <branch> --revision <40-character-sha>
```

For a fresh machine, use [INSTALL.md](INSTALL.md).
