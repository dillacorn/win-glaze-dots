# 🖥️ Running Linux in QEMU on Windows — Wayland-Compatible (Software Virtualization Only)

This guide shows you how to create and run a virtual machine with **Arch Linux** using **QEMU**, managed entirely via **PowerShell** on Windows.

> ⚠️ **Important:**  
> Windows **blocks direct GPU passthrough (KVM/VFIO)** and **hardware acceleration** for virtual machines at the kernel level.  
> This setup runs entirely in **software virtualization (TCG)** mode.  
> It will work for graphical Linux environments like **Hyprland**, **Sway**, or **GNOME**, but **3D performance is CPU-bound and limited**.  
> For real hardware acceleration and native Wayland support, **run QEMU + KVM on a Linux host** instead —  
> or install **Linux on bare metal** *(preferred)* for direct GPU access and full compositor performance.

---

## 📦 Prerequisites

- Install QEMU with winget:

```powershell
winget install SoftwareFreedomConservancy.QEMU
```

---

## 📁 Folder Structure

Make sure your folder is set up like this:

```
C:\Users\<your-name>\qemu
├── HDA\                  # Contains img
    └── archlinux.img     # Main virtual hard disk
├── ISO\                  # Contains the Arch Linux ISO
│   └── archlinux.iso
├── create_img.txt        # Your image creation notes
└── powershell_code.txt   # Your QEMU run script
```

---

## 💿 Step 1: Create a Virtual Hard Disk

```powershell
& 'C:\Program Files\qemu\qemu-img.exe' create -f qcow2 "$env:USERPROFILE\qemu\HDA\archlinux.img" 20G
```

This creates a 20GB `.img` file for Arch Linux.

---

## 🚀 Step 2: Boot Arch Linux ISO with QEMU

```powershell
$exe = "C:\Program Files\qemu\qemu-system-x86_64.exe"

& $exe `
-m 4096 `
-smp 4 `
-cpu qemu64 `
-accel tcg `
-boot d `
-cdrom "$env:USERPROFILE\qemu\ISO\archlinux.iso" `
-hda "$env:USERPROFILE\qemu\HDA\archlinux.img" `
-display sdl,gl=on `
-device virtio-vga-gl `
-device qemu-xhci `
-serial mon:stdio
```

This will launch the Arch ISO and allow you to install it onto your `.img` drive.

---

## 💡 Notes

- `-m 4096` 4gb of RAM allocation. (adjust to preference)
- `-smp 4` 4 cpu threads allocated. (adjust to preference)
- `-cpu EPYC` gives great performance and compatibility for AMD CPUs.
- `-cpu qemu64` for Intel CPUs.
- `-display sdl,gl=on` enables 3D acceleration for better UI experience.
- You can backup your `.img` file anytime by copying it to the `backup` folder.
- Black screen? CTRL+ALT+2 then close window that spawns and image should come back.

---

## 🧼 To Shut Down the VM

Use `poweroff` from inside the Arch shell or shutdown from the installed system (after you set it up).





