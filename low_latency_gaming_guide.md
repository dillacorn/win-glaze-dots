# **Tips to Lower Latency in Gaming (Game-Dependent)**

---
## **Choosing Display Hardware**
Choosing a monitor for ultimate visual clarity and input latency can be tricky especially when you've already had first hand experience with a 100+hz CRT. 

[My personal guide and reasons I decided to pickup a Zowie TN over an OLED.](https://github.com/dillacorn/win-glaze-dots/blob/main/ScreenShots_For_Guides/low_latency/monitor_motion_clarity_comparisons_150dpi.png) ~ preview image

[Download the PDF](https://github.com/dillacorn/win-glaze-dots/blob/main/ScreenShots_For_Guides/low_latency/monitor_motion_clarity_comparisons.pdf) to compare images at a higher resolution.

It's ultimately up to you though.. OLED is a fantastic choice for a solo display and I'm certain I'd also be very happy to own one someday.

---
## **FrameSync Labs - YT_Videos**
[I Tried Every Windows Optimization for FPS](https://www.youtube.com/watch?v=QWzail3qsX0)

[How to FIX High DPC and ISR Latency in 60 Seconds](https://www.youtube.com/watch?v=FFH8u_283mM)

[How to Optimize Internet Adapter Settings for Lower Ping and No Delay](https://www.youtube.com/watch?v=RCO9zuUb12U&t=26s)

---
## **Graphics and Display Settings**
1. **Frame Rate Cap**: Capping your frame rate can introduce additional latency if you're reaching 100+fps above target in game when it's uncapped on average. Capping your frame rate will however stabilize your frame rate on average and can reduce latency if you're close to the frame target when uncapped. This is for you to decide what's better... (game dependant)
2. **Anti-Aliasing**: Disable anti-aliasing as it CAN introduce input lag. (Avoid *TAA** if you can) ~ [r/FuckTAA](https://www.reddit.com/r/FuckTAA/)
3. **Upscaling**: Turn off upscaling technologies (e.g., DLSS, FSR) for lower latency.
4. **V-Sync and Sync Alternatives**: Avoid V-Sync, FreeSync, G-Sync, and other sync technologies, as they cause input lag. Use screen tearing as a trade-off if necessary.
5. **Dynamic Render Scaling**: Disable this setting for consistent frame rates and lower latency.
6. **Triple Buffering**: Turn off triple buffering as it can add input delay.
7. **Ambient Occlusion**: Disable ambient occlusion unless its visual benefits outweigh the added latency for your gameplay. (game dependant)
8. **Reflections**: Disable dynamic and local reflections.
9. **Reduced Buffering**: Enable reduced buffering in your game settings.
10. **NVIDIA Reflex and AMD Anti-Lag**: These technologies claim to lower your latency but there's no verifiable proof there is any added benifit other than lowering your overall frame rate when enabled. I recommend to leave these settings off as they can introduce unnecessary stuttering.

---
## **Hardware Recommendations**
11. **High Refresh Rate Monitors**: Invest in a high-refresh-rate monitor with BFI (Black Frame Insertion) technology. TN panels with good BFI (e.g., Zowie monitors) offer optimal performance.
12. **High-Polling-Rate Mice**: Use a mouse with a 4k Hz polling rate for marginal input latency improvements.
13. **Fullscreen Mode**: Always use exclusive fullscreen mode for the lowest latency.

---
## **Input Methods**
14. **DirectXInput Over Raw Input**: Use DirectXInput if available, as it often has lower latency due to direct handling by the game engine. (game dependant)
15. **Raw Input Buffer**: Enable Raw Input Buffer if avaliable in game engine. (game dependant)

---
## **Windows-Specific Optimizations**
16. **Disable Xbox Game Bar**: 
    - Go to Windows Settings > Gaming > Xbox Game Bar > Toggle Off.
17. **Disable Overlays**: 
    - Turn off overlays like Discord to prevent additional input lag.

---
## **System Commands (UAC Required)**
Run the following commands in an elevated Command Prompt (Admin mode):

### **Disable Dynamic Tick**
```cmd
bcdedit /set disabledynamictick yes
```
---
### **Disable CPU virtualization in BIOS**

---
### **Additional Notes**

- Always research the best settings for your specific game. Some games may require specific optimizations beyond this list.
- Test each setting to ensure it aligns with your gameplay preferences, particularly for visibility-critical features like ambient occlusion.
