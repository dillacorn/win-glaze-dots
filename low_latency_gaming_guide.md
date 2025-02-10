# **Tips to Lower Latency in Gaming (Game-Dependent)**

---
## **Choosing Display Hardware**
Choosing a monitor for ultimate visual clarity and input latency can be tricky especially when you've already had first hand experience with a 100+hz CRT. 

[My personal guide and reasons I decided to pickup a Zowie TN over an OLED.](https://github.com/dillacorn/win-glaze-dots/blob/main/ScreenShots_For_Guides/low_latency/monitor_motion_clarity_comparisons_150dpi.png) ~ preview image

[Download the PDF](https://github.com/dillacorn/win-glaze-dots/blob/main/ScreenShots_For_Guides/low_latency/monitor_motion_clarity_comparisons.pdf) to compare images at a higher resolution.

It's ultimately up to you though.. OLED is a fantastic choice for a solo display and I'm certain I'd also be very happy to own one someday.

---
## **Hardware Recommendations**
1. **High Refresh Rate Monitors**:
   - Invest in a high-refresh-rate monitor with BFI (Black Frame Insertion) technology. TN panels with good BFI (e.g., Zowie monitors) offer excellent performance.
3. **High-Polling-Rate Mice**:
   - I've gamed with a 1k Hz polling rate most of my life, even on a 400Hz Zowie display, and I see no real benefit in going beyond 1k Hz, even for competitive play. The hype around higher polling rates feels like marketing.
   - The only scenario where 4k Hz might make sense is with Motion Sync, which adds 1ms of latency. At 4k Hz, this drops to 0.25ms, but does it improve gameplay? Probably not. Plus, the FPS hit from enabling 4k Hz isn’t worth the trade-off in my opinion.
   - Use the DPI that feels best to you @ 1k hz. I'm using 400dpi as I find there's no latency drawback. If you're wanting to utilize a higher polling rate with motion sync enabled I suggest using 1600dpi.
5. **Fullscreen Mode**:
   - Use exclusive fullscreen mode for the lowest latency. (doesn't always improve latency)

---
## **FrameSync Labs - YT_Videos**
[I Tried Every Windows Optimization for FPS](https://www.youtube.com/watch?v=QWzail3qsX0) ~ Intel CPUs

[I Tested Every Windows and BIOS Optimization for FPS (AMD Ryzen Edition + Benchmarks)](https://www.youtube.com/watch?v=Vp332dU5xOU&t=287s) ~ AMD CPUs

[How to FIX High DPC and ISR Latency in 60 Seconds](https://www.youtube.com/watch?v=FFH8u_283mM)

[How to Optimize Internet Adapter Settings for Lower Ping and No Delay](https://www.youtube.com/watch?v=RCO9zuUb12U&t=26s)

---
## **BIOS configurations - CPU dependant - Remember to take your time.. some of these settings are NOT easy to locate**
1. Enable **XMP** profile for your RAM.
2. Disable **Hyperthreading** on Intel and/or **SMT** on AMD.
3. Disable **Effeciency cores (e-cores)** for Intel CPUs.
4. Disable **L1 & L2 Hardware Prefetcher** for Intel and AMD CPUs.
5. Disable CPU virtulization ~ **AMD-V or SVM** on AMD CPUs ~ **VT-x** on Intel CPUs
6. Disable **FCH Spread Spectrum** ~ AMD CPUs.
7. Enable **Precision Boost Overdrive(PBO)** ~ AMD CPUs.
8. PBO Enabled **All Core -15 Curve Optimizer** ~ AMD CPUs.
9. PBO **10X Scaler** ~ AMD CPUs.
10. PBO **200mhz CPU Boost Clock** ~ AMD CPUs.
11. PBO Enhancement **90 Level 5** ~ AMD CPus. - (90 = 90c max before thermal throttle, Level 5 = max power draw.)

---
## **Graphics and Display Settings**
1. **Frame Rate Cap**:
   - Capping your frame rate can introduce additional latency if you're reaching 100+fps above target in game when it's uncapped on average. Capping your frame rate will however stabilize your frame rate on average and can reduce latency if you're close to the frame target when uncapped. This is for you to decide what's better... (game dependant)
3. **Anti-Aliasing**:
   - Disable anti-aliasing as it CAN introduce input lag. (Avoid *TAA** if you can) ~ [r/FuckTAA](https://www.reddit.com/r/FuckTAA/)
4. **Upscaling**:
   - Turn off upscaling technologies (e.g., DLSS, FSR) for lower latency.
5. **V-Sync and Sync Alternatives**:
   - Avoid V-Sync, FreeSync, G-Sync, and other sync technologies, as they cause input lag. Use screen tearing as a trade-off if necessary.
6. **Dynamic Render Scaling**:
   - Disable this setting for consistent frame rates and lower latency.
7. **Triple Buffering**:
   - Turn off triple buffering as it can add input delay.
8. **Ambient Occlusion**:
   - Disable ambient occlusion unless its visual benefits outweigh the added latency for your gameplay. (game dependant)
9. **Reflections**:
   - Disable dynamic and local reflections.
10. **Reduced Buffering**:
    - Enable reduced buffering in your game settings.
11. **NVIDIA Reflex and AMD Anti-Lag**:
    - These technologies claim to lower your latency but there's no verifiable proof there is any added benifit other than lowering your overall frame rate when enabled. I recommend to leave these settings off as they can introduce unnecessary stuttering.

# Best Upscaler Based on GPU Type

## NVIDIA Users
| Upscaler                  | Latency     | Blur Level         | Notes |
|---------------------------|------------|--------------------|------------------------------------------------|
| **DLAA**                  | ✅ Lowest  | ✅ Sharpest       | Best quality option, but only works at native resolution. |
| **DLSS (Quality Mode)**   | ✅ Low     | ✅ Very sharp    | Best upscaler for performance + image quality. |
| **TSR (if available)**    | ✅ Low     | ✅ Less blur than FSR | A solid alternative if DLSS isn’t an option. |
| **FSR 2/3 (Quality Mode)**| ✅ Low     | ❌ More blur than TSR | If no DLSS or TSR, use FSR as a last resort. |

## AMD Users
| Upscaler                  | Latency     | Blur Level         | Notes |
|---------------------------|------------|--------------------|------------------------------------------------|
| **TSR (if available)**    | ✅ Low     | ✅ Less blur than FSR | Best choice in Unreal Engine 5 games. |
| **FSR 2/3 (Quality Mode)**| ✅ Low     | ❌ More blur than TSR | The best AMD-supported option. |
| **XeSS (DP4a Mode)**      | ❌ Higher  | ❌ Similar to FSR  | Generally performs worse than FSR on AMD GPUs. |
| **FSR 1.0**               | ✅ Very low| ❌ Soft/oversharpened | Minimal latency, but poor image quality. |

## Intel Arc Users
| Upscaler                  | Latency     | Blur Level         | Notes |
|---------------------------|------------|--------------------|------------------------------------------------|
| **XeSS (XMX Mode)**       | ✅ Lower   | ✅ Sharper than FSR | Best choice for Intel Arc GPUs. |
| **TSR (if available)**    | ✅ Low     | ✅ Less blur than FSR | Great alternative if XeSS isn’t available. |
| **FSR 2/3 (Quality Mode)**| ✅ Low     | ❌ More blur than XeSS | Use if no XeSS or TSR available. |
| **XeSS (DP4a Mode)**      | ❌ Higher  | ❌ Similar to FSR  | Performs worse on non-Arc GPUs. |

## General Notes:
- **Native Resolution**: ✅ Lowest latency, ✅ Zero blur (display dependent), ❌ Lower frame rate.  
  - Preferred if achieving **high frame rate** for best responsiveness.  
  - **AMD CAS (Contrast Adaptive Sharpening)** can enhance Native resolution further.
- **DLAA (NVIDIA only)**: Best anti-aliasing but does not upscale.  
- **DLSS (NVIDIA only)**: Best for upscaling and reducing blur.  
- **TSR (Unreal Engine 5 games)**: Best non-NVIDIA upscaler.  
- **FSR 2/3**: Decent, but more blurry than TSR and XeSS (on Arc).  
- **XeSS (Intel Arc GPUs)**: Best on Arc, but worse than FSR on AMD/NVIDIA.
- **Note:** **Sharpening filters should be enabled when available to improve image clarity with upscaling.**  
- **Note:** **TAA and TAAU are not included** as *"one looks bad and the other looks worse."*  

---
## **Input Methods**
1. **DirectXInput Over Raw Input**:
   - Use DirectXInput if available, as it often has lower latency due to direct handling by the game engine. (game dependant)
3. **Raw Input Buffer**:
   - Enable Raw Input Buffer if avaliable in game engine. (game dependant)

---
## **Windows-Specific Optimizations**
1. **Disable Xbox Game Bar**: 
    - Go to Windows Settings > Gaming > Xbox Game Bar > Toggle Off.
2. **Disable Overlays**: 
    - Turn off overlays like Discord to prevent additional input lag.
3. **Unpark CPU cores**:
    - Reduces frame rate but improves latency.

---
## **Note Worthy Software Tweaks**
1. **MSI Afterburner**
   - If you're using "MSI Afterburner" turn off "GPU power monitoring" as it is known to cause micro-stuttering (affecting 1% lows) and hasn't been fixed for over 6+ years.
   - [View this techpowerup post about the issue](https://www.techpowerup.com/forums/threads/msi-afterburner-potential-1-lows-stutter-issues-fixed.330207/)
   - [Video (@ 12:31) Explaining Fix](https://youtu.be/bQH3DYNboM0?t=12m31s)

---
### **Additional Notes**

- Always research the best settings for your specific game. Some games may require specific optimizations beyond this list.
- Test each setting to ensure it aligns with your gameplay preferences, particularly for visibility-critical features like ambient occlusion.
