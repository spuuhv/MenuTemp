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

## Installation

1. Clone the repository:  
```bash
git clone https://github.com/your-username/MenuTemp.git
cd MenuTemp
