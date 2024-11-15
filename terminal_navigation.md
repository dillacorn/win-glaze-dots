## **Windows Terminal Navigation Guide!**

### **Using Alacritty**

#### **Navigation Commands**:
- `cd \` ← **Go to Root (C:\)**
- `cd ~` ← **Go to Home Directory (%UserProfile%)**
- `cd ..` ← **Go Back a Folder**
- `ls` / `dir` ← **List Files in the Current Directory**

#### **File and Directory Management**:
- `mkdir <foldername>` ← **Create a New Folder**
- `rmdir <foldername>` ← **Remove an Empty Folder**
- `del <filename>` ← **Delete a File**
- `mv <source> <destination>` ← **Move/Rename Files or Folders**
  - **Example**: `mv file.txt Documents\` ← Move `file.txt` to `Documents`
  - Note: Use `move` in CMD for Windows-native commands.
- `cp <source> <destination>` ← **Copy Files**
  - **Example**: `cp file.txt Documents\` ← Copy `file.txt` to `Documents`
  - Note: Use `copy` in CMD for Windows-native commands.
- `rm <filename>` ← **Remove a File**
- `cp -r <source> <destination>` ← **Copy Folders Recursively**

#### **File Viewing and Editing**:
- `type <filename>` / `cat <filename>` ← **View File Contents**
- `notepad <filename>` / `micro <filename>` ← **Open File in Notepad++ or micro**

#### **System Commands**:
- `cls` / `ctrl+l` ← **Clear Terminal Screen**
- `exit` ← **Close Terminal**

#### **Tips**:
- Use `TAB` for **autocompletion** of file and folder names.
- Use `Up/Down Arrows` to navigate through your command history.
- Use `Ctrl + C` to cancel a running command.
