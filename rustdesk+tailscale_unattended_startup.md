# rustdesk+tailscale_unattended_startup.md

## Overview

This guide will walk you through the process of setting up **Tailscale** and **RustDesk** to start automatically and unattended when your system starts. We’ll achieve this using **Task Scheduler** in Windows.

---

## Requirements

- **Tailscale** installed and running on your system.
- **RustDesk** installed and configured.

---

## Setting Up Tailscale to Start Unattended

### Step 1: Open Task Scheduler via the Run Box
1. Press `Win + R` to open the **Run** dialog.
2. Type `taskschd.msc` and press **Enter**. This will open the **Task Scheduler**.

### Step 2: Create a New Task for Tailscale
1. In the **Task Scheduler** window, click **Create Task** from the right panel.
2. Name your task **Tailscale Unattended Startup**.
3. Under the **Security Options** section, select **Run whether user is logged on or not**.
4. Check **Run with highest privileges**.

### Step 3: Configure the Trigger
1. Switch to the **Triggers** tab.
2. Click **New** and set the following:
   - **Begin the task**: **At startup**.
   - Click **OK**.

### Step 4: Set the Action for Tailscale
1. Switch to the **Actions** tab.
2. Click **New** and configure the action:
   - **Action**: Start a program.
   - **Program/script**: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
   - **Arguments**: `-Command "tailscale up --unattended"`
   - Click **OK**.

### Step 5: Set Conditions (Optional)
1. Switch to the **Conditions** tab (you can leave the defaults or adjust to your needs).

### Step 6: Save the Task
1. Click **OK** to create the task.
2. When prompted, enter your user credentials.

Tailscale is now configured to automatically run in unattended mode when your PC starts up.

---

## Setting Up RustDesk to Start Unattended

### Step 1: Open Task Scheduler via the Run Box
1. Press `Win + R` to open the **Run** dialog.
2. Type `taskschd.msc` and press **Enter** to open the **Task Scheduler**.

### Step 2: Create a New Task for RustDesk
1. In the **Task Scheduler** window, click **Create Task**.
2. Name your task **RustDesk Unattended Startup**.
3. Under the **Security Options**, select **Run whether user is logged on or not**.
4. Check **Run with highest privileges**.

### Step 3: Configure the Trigger
1. Switch to the **Triggers** tab.
2. Click **New** and set the following:
   - **Begin the task**: **At startup**.
   - Click **OK**.

### Step 4: Set the Action for RustDesk
1. Switch to the **Actions** tab.
2. Click **New** and configure the action:
   - **Action**: Start a program.
   - **Program/script**: `"C:\Program Files\RustDesk\RustDesk.exe"`
   - **Arguments**: `--tray`
   - Click **OK**.

### Step 5: Set Conditions (Optional)
1. Switch to the **Conditions** tab (again, leave the defaults or adjust according to your needs).

### Step 6: Save the Task
1. Click **OK** to create the task.
2. When prompted, enter your user credentials.

RustDesk is now configured to start in the system tray unattended on startup.

---

## Conclusion

With these steps, both **Tailscale** and **RustDesk** will run automatically and unattended when your Windows machine starts up. This ensures you are always connected via Tailscale and your RustDesk session is ready to go without needing manual intervention.

Happy automating!
