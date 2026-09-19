# GPU driver maintenance

WGDot detects present Windows display adapters directly through SetupAPI and classifies AMD, NVIDIA, and Intel devices from their PCI vendor IDs.

## Normal install/reconcile behavior

After software reconciliation, WGDot checks each detected GPU vendor:

- matching active vendor driver: no action required;
- Microsoft/basic or unconfirmed driver: recommends the matching official vendor installer;
- active provider from another GPU vendor: flags a mismatch and directs the user to GPU driver maintenance;
- stale vendor display-driver package with no matching physical GPU: flags it as a cleanup candidate.

Hybrid graphics are supported. Intel + NVIDIA and Intel + AMD are legitimate when both adapters are physically present.

## Official driver tooling

WGDot resolves/downloads only from vendor-owned HTTPS endpoints:

- AMD: Auto-Detect and Install tool from `drivers.amd.com`;
- NVIDIA: NVIDIA App from `us.download.nvidia.com`;
- Intel: Intel Driver & Support Assistant from `dsadata.intel.com`.

The vendor tool remains responsible for identifying and installing the exact compatible driver.

## Clean reinstall / refresh with DDU

The GPU driver maintenance menu can clean/reinstall a detected vendor driver or clean a stale/mismatched vendor.

WGDot does not run DDU automatically. The user must explicitly approve the Safe Mode workflow.

Before reboot WGDot:

1. ensures `Wagnardsoft.DisplayDriverUninstaller` is installed locally;
2. stores the target vendor and cleanup state;
3. creates `*WGDotGpuSafeModeResume` in HKLM RunOnce so the handoff also runs in Safe Mode;
4. sets the current Windows boot entry to `safeboot minimal`;
5. reboots only after confirmation.

After Safe Mode login WGDot:

1. removes the forced `safeboot` value first;
2. refuses to launch DDU if normal boot cannot be restored;
3. records `driver-needed` state;
4. launches DDU and tells the user which vendor to select;
5. expects DDU's Clean and restart path to return to normal Windows.

On the next normal `wgdot` run, WGDot checks whether the correct vendor driver is active. If not, it displays `GPU DRIVER ACTION REQUIRED` and directs the user to install the correct vendor tooling.

Before DDU, follow Wagnardsoft's precautions: know the account password, have the BitLocker/device-encryption recovery key available when applicable, and disconnect networking until the replacement driver is installed.
