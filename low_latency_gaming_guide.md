# **Tips to Lower Latency in Gaming (Game-Dependent)**

## **Graphics and Display Settings**
1. **Frame Rate Cap**: Cap your frame rate to your monitor's refresh rate for improved stability and reduced latency.
2. **Anti-Aliasing**: Disable anti-aliasing as it can introduce input lag.
3. **Upscaling**: Turn off upscaling technologies (e.g., DLSS, FSR) for lower latency.
4. **V-Sync and Sync Alternatives**: Avoid V-Sync, FreeSync, G-Sync, and other sync technologies, as they cause input lag. Use screen tearing as a trade-off if necessary.
5. **Dynamic Render Scaling**: Disable this setting for consistent frame rates and lower latency.
6. **Triple Buffering**: Turn off triple buffering as it can add input delay.
7. **Ambient Occlusion**: Disable ambient occlusion unless its visual benefits outweigh the added latency for your gameplay.
8. **Reflections**: Disable dynamic and local reflections.
9. **Reduced Buffering**: Enable reduced buffering in your game settings.
10. **NVIDIA Reflex**: Turn on NVIDIA Reflex with "On + Boost" if available in your game.

## **Hardware Recommendations**
11. **High Refresh Rate Monitors**: Invest in a high-refresh-rate monitor with BFI (Black Frame Insertion) technology. TN panels with good BFI (e.g., Zowie monitors) offer optimal performance.
12. **High-Polling-Rate Mice**: Use a mouse with a 4k Hz polling rate for marginal input latency improvements.
13. **Fullscreen Mode**: Always use exclusive fullscreen mode for the lowest latency.

## **Input Methods**
14. **DirectXInput Over Raw Input**: Use DirectXInput if available, as it often has lower latency due to direct handling by the game engine. Varies from Game to game..usually "Raw Input" is what you want.
15. **Raw Input Buffer**: Enable Raw Input Buffer if avaliable in game engine.

## **Windows-Specific Optimizations**
15. **Disable Fullscreen Optimizations**:
    - Navigate to the game's executable (e.g., `overwatch.exe`).
    - Right-click > Properties > Compatibility > Check "Disable fullscreen optimizations."
16. **Disable Xbox Game Bar**: 
    - Go to Windows Settings > Gaming > Xbox Game Bar > Toggle Off.
17. **Disable Overlays**: 
    - Turn off overlays like Discord to prevent additional input lag.

## **System Commands (UAC Required)**
Run the following commands in an elevated Command Prompt (Admin mode):

### **Disable Dynamic Tick**
```cmd
bcdedit /set disabledynamictick yes
```

### **Disable Hyper-V** (if not needed)
```cmd
bcdedit /set hypervisorlaunchtype off
```

### **Set High Performance Power Plan**
```cmd
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
```

### **Disable CPU Core Parking**
```cmd
powercfg /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0
```

### **Disable CPU Idle States**
```cmd
powercfg /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
```

### **Additional Notes**

- Always research the best settings for your specific game. Some games may require specific optimizations beyond this list.
- Test each setting to ensure it aligns with your gameplay preferences, particularly for visibility-critical features like ambient occlusion.
