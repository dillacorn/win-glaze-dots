# RNNoise microphone suppression on Windows

WGDot can configure low-latency microphone noise suppression using [Equalizer APO](https://sourceforge.net/projects/equalizerapo/) and [Werman's noise-suppression-for-voice](https://github.com/werman/noise-suppression-for-voice).

The integration is optional and defaults OFF.

## WGDot setup

From the interactive installer or **Windows tweaks / integrations**, enable:

`RNNoise microphone suppression (Equalizer APO, default microphone)`

WGDot then:

- installs the official x64 Equalizer APO 1.4.2 build after verifying its published SHA-256;
- installs Werman's official Windows RNNoise VST release;
- detects the current Windows default multimedia capture endpoint;
- registers Equalizer APO on that microphone only;
- keeps the RNNoise filter in a dedicated `wgdot-mic-suppression.txt` file and adds one bounded `Include:` block to Equalizer APO's main config;
- defaults to the lower-overhead mono RNNoise plugin.

Werman RNNoise requires a **48000 Hz** microphone format. If the default microphone is using another rate, WGDot first asks Windows to switch that endpoint to 48000 Hz while preserving its channel/bit-depth format. WGDot verifies the result before installing or activating RNNoise. If the driver rejects the change, WGDot restores the original endpoint format and stops with a precise manual-fix message. If WGDot successfully changes the rate but a later RNNoise setup stage fails, it restores the original microphone format before returning the failure.

A newly registered Equalizer APO capture endpoint requires one Windows restart. After that, enabling/disabling the include or switching mono/stereo reloads through Equalizer APO's normal config-file behavior.

## Scriptable controls

```powershell
wgdot mic-suppression status
wgdot mic-suppression enable
wgdot mic-suppression disable
wgdot mic-suppression mono
wgdot mic-suppression stereo
```

`disable` removes only WGDot's active RNNoise include. It intentionally leaves Equalizer APO, the VST files, and the endpoint registration installed so suppression can be toggled back on without rebuilding the audio stack.

Use `mono` unless the microphone actually needs independent left/right processing. Stereo runs two RNNoise processing paths and costs more CPU.

## Historical manual screenshots

These screenshots document the older manual Equalizer APO workflow that this automation replaces and remain useful for troubleshooting:

![step 1](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%231.png)

![step 2](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%232.png)

![step 3](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%233.png)

![step 4](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%234.png)

![step 5](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%235.png)

![step 6](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%236.png)

![step 7](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%237.png)

![step 8](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%238.png)

![step 9](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%239.png)

![step 10](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%2310.png)

![step 11](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%2311.png)

![step 12](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%2312.png)

![step 13](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%2313.png)

![step 14](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%2314.png)

![step 15](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%2315.png)

![step 16](https://raw.githubusercontent.com/dillacorn/win-glaze-dots/refs/heads/main/ScreenShots_For_Guides/mic_suppression_apo/APO_mic_suppression_%2316.png)
