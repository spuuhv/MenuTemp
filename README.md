# MenuTemp

MenuTemp is a lightweight macOS menu bar application that monitors CPU temperature in real-time. It displays detailed temperature metrics and supports enabling/disabling launch at login.

---

## Features

- Shows package temperature, average core temperature, minimum and maximum temperatures  
- Real-time updates in the macOS menu bar  
- Toggle launch at login feature directly from the menu  
- Uses Intel Power Gadget for accurate temperature readings  
- Employs a helper C program that reads CPU temperatures and communicates via FIFO  

---

## Introduction

MenuTemp is specifically designed for Hackintosh users who find that popular monitoring tools like **Stats**, **iStat Menus**, and others do not display CPU temperatures properly. By leveraging Intel Power Gadget combined with a custom helper program, MenuTemp provides reliable and real-time CPU temperature readings on systems where traditional tools fail.

---

## Download and Installation

Precompiled binaries are provided for easy installation — no need to compile from source.

You can download the latest release from the [Releases](https://github.com/your-username/MenuTemp/releases) page.

To install:

1. Download the `.dmg` or `.zip` file for the latest version.  
2. Open the downloaded file and drag the app to your `Applications` folder.  
3. Run the app from `Applications`.  
4. (Optional) Enable “Launch at Login” from the menu to start automatically with your Mac.

---

## Usage

- The menu bar icon shows the current package temperature.  
- Click the icon to see detailed CPU temperature information.  
- Use the "Launch at Login" menu option to enable or disable automatic startup.  
- Select "Quit" to exit the application.

---

## Development

- The helper program (written in C) reads temperature data and sends it through a named pipe (FIFO).  
- The main app uses Swift and Combine to observe and update the UI.  
- The launch at login feature is implemented with the ServiceManagement framework.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- Thanks to Intel Power Gadget for providing the CPU temperature API.  
- Thanks to the open source community.
