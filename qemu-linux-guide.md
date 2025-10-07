# 🖥️ Running Linux in QEMU on Windows ~ Wayland Compatible

This guide shows you how to create and run a virtual machine with **Arch Linux** using **QEMU**, managed entirely via **PowerShell** on Windows.

(note: you can use any linux iso of your choosing)

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

- `-cpu EPYC` gives great performance and compatibility for AMD CPUs.
- `-cpu qemu64` for Intel CPUs.
- `-display sdl,gl=on` enables 3D acceleration for better UI experience.
- You can backup your `.img` file anytime by copying it to the `backup` folder.
- Black screen? CTRL+ALT+2 then close window that spawns and image should come back.

---

## 🧼 To Shut Down the VM

Use `poweroff` from inside the Arch shell or shutdown from the installed system (after you set it up).



