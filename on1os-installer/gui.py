#!/usr/bin/env python3
"""
on1OS Live Installer GUI
A comprehensive GUI installer for on1OS Linux distribution
"""

import tkinter as tk
from tkinter import ttk, messagebox
import subprocess
import os
import sys
import json
import threading
import re

class On1OSInstaller:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("on1OS Installer")
        self.root.geometry("600x500")
        self.root.resizable(False, False)
        
        # Installation configuration
        self.config = {
            'target_disk': None,
            'filesystem': 'ext4',
            'desktop_environment': 'xfce',
            'root_password': '',
            'username': '',
            'user_password': '',
            'user_fullname': '',
            'hostname': 'on1os',
            'language': 'en_US',
            'keyboard': 'us',
            'timezone': 'UTC',
            'mirror_country': 'global',
            'install_nvidia': False,
            'install_nonfree': False
        }
        
        self.current_step = 0
        self.steps = [
            self.welcome_step,
            self.language_step,
            self.keyboard_step,
            self.network_step,
            self.timezone_step,
            self.partition_step,
            self.desktop_step,
            self.drivers_step,
            self.users_step,
            self.summary_step,
            self.install_step
        ]
        
        self.setup_ui()
        
    def setup_ui(self):
        # Main frame
        self.main_frame = ttk.Frame(self.root, padding="20")
        self.main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Header
        header_frame = ttk.Frame(self.main_frame)
        header_frame.grid(row=0, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 20))
        
        title_label = ttk.Label(header_frame, text="on1OS Installer", 
                               font=("Arial", 24, "bold"))
        title_label.grid(row=0, column=0, sticky=tk.W)
        
        # Progress bar
        self.progress = ttk.Progressbar(header_frame, length=400, mode='determinate')
        self.progress.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(10, 0))
        
        # Content frame
        self.content_frame = ttk.Frame(self.main_frame)
        self.content_frame.grid(row=1, column=0, columnspan=3, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(0, 20))
        
        # Navigation buttons
        nav_frame = ttk.Frame(self.main_frame)
        nav_frame.grid(row=2, column=0, columnspan=3, sticky=(tk.W, tk.E))
        
        self.back_btn = ttk.Button(nav_frame, text="Back", command=self.prev_step)
        self.back_btn.grid(row=0, column=0, sticky=tk.W)
        
        self.next_btn = ttk.Button(nav_frame, text="Next", command=self.next_step)
        self.next_btn.grid(row=0, column=2, sticky=tk.E)
        
        self.quit_btn = ttk.Button(nav_frame, text="Quit", command=self.quit_installer)
        self.quit_btn.grid(row=0, column=1, padx=20)
        
        # Configure grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        self.main_frame.columnconfigure(1, weight=1)
        self.main_frame.rowconfigure(1, weight=1)
        
        # Start with first step
        self.show_step()
        
    def clear_content(self):
        for widget in self.content_frame.winfo_children():
            widget.destroy()
            
    def show_step(self):
        self.clear_content()
        self.progress['value'] = (self.current_step / (len(self.steps) - 1)) * 100
        
        # Update navigation buttons
        self.back_btn['state'] = 'normal' if self.current_step > 0 else 'disabled'
        if self.current_step == len(self.steps) - 1:
            self.next_btn['text'] = 'Restart'
            self.next_btn['command'] = lambda: os.system('reboot')
        elif self.current_step == len(self.steps) - 2:
            self.next_btn['text'] = 'Install'
        else:
            self.next_btn['text'] = 'Next'
            self.next_btn['command'] = self.next_step
            
        self.steps[self.current_step]()
        
    def next_step(self):
        if self.current_step == len(self.steps) - 2:  # Summary step
            if self.validate_current_step():
                self.current_step += 1
                self.show_step()
        elif self.current_step == len(self.steps) - 1:  # Install step
            # Start installation
            pass
        else:
            if self.validate_current_step():
                self.current_step += 1
                self.show_step()
                
    def prev_step(self):
        if self.current_step > 0:
            self.current_step -= 1
            self.show_step()
            
    def validate_current_step(self):
        if self.current_step == 5:  # Partition step
            if not self.config.get('target_disk'):
                messagebox.showerror("Error", "Please select a target disk.")
                return False
        elif self.current_step == 8:  # Users step
            if hasattr(self, 'root_pass_entry'):
                root_pass = self.root_pass_entry.get()
                root_confirm = self.root_pass_confirm.get()
                username = self.username_entry.get()
                user_pass = self.user_pass_entry.get()
                user_confirm = self.user_pass_confirm.get()
                hostname = self.hostname_entry.get()
                user_fullname = self.fullname_entry.get() if hasattr(self, 'fullname_entry') else ""
                
                if not root_pass:
                    messagebox.showerror("Error", "Root password is required.")
                    return False
                if root_pass != root_confirm:
                    messagebox.showerror("Error", "Root passwords do not match.")
                    return False
                if not username:
                    messagebox.showerror("Error", "Username is required.")
                    return False
                if not re.match(r'^[a-z][a-z0-9]*$', username):
                    messagebox.showerror("Error", "Username must start with a letter and contain only lowercase letters and numbers.")
                    return False
                if not user_pass:
                    messagebox.showerror("Error", "User password is required.")
                    return False
                if user_pass != user_confirm:
                    messagebox.showerror("Error", "User passwords do not match.")
                    return False
                if not hostname:
                    messagebox.showerror("Error", "Computer name is required.")
                    return False
                if not re.match(r'^[a-zA-Z0-9-]+$', hostname):
                    messagebox.showerror("Error", "Computer name can only contain letters, numbers, and hyphens.")
                    return False
                    
                # Update config with current values
                self.update_config('root_password', root_pass)
                self.update_config('user_password', user_pass)
                self.update_config('username', username)
                self.update_config('hostname', hostname)
                self.update_config('user_fullname', user_fullname)
        return True
                 
    def welcome_step(self):
        ttk.Label(self.content_frame, text="Welcome to on1OS", 
                 font=("Arial", 18, "bold")).grid(row=0, column=0, pady=20)
        
        welcome_text = """
Welcome to the on1OS installer!

This installer will copy the current live system to your hard drive.

The installation process will:
• Partition and format your selected disk
• Copy the live system to the new partition
• Set up user accounts and passwords
• Install the GRUB bootloader

⚠️ WARNING: This will erase all data on the selected disk!

Click Next to begin the installation process.
        """
        
        ttk.Label(self.content_frame, text=welcome_text, 
                 justify=tk.LEFT).grid(row=1, column=0, sticky=(tk.W, tk.E), padx=20)
                 
    def language_step(self):
        ttk.Label(self.content_frame, text="Select Language", 
                 font=("Arial", 16, "bold")).grid(row=0, column=0, pady=20)
        
        languages = [
            ("English (US)", "en_US"),
            ("English (UK)", "en_GB"),
            ("Español", "es_ES"),
            ("Français", "fr_FR"),
            ("Deutsch", "de_DE"),
            ("Português", "pt_BR"),
            ("Italiano", "it_IT"),
            ("日本語", "ja_JP"),
            ("中文", "zh_CN"),
            ("Русский", "ru_RU")
        ]
        
        self.language_var = tk.StringVar(value=self.config['language'])
        
        for i, (name, code) in enumerate(languages):
            ttk.Radiobutton(self.content_frame, text=name, variable=self.language_var,
                           value=code, command=lambda: self.update_config('language', self.language_var.get())
                           ).grid(row=i+1, column=0, sticky=tk.W, padx=20, pady=2)
                           
    def keyboard_step(self):
        ttk.Label(self.content_frame, text="Select Keyboard Layout", 
                 font=("Arial", 16, "bold")).grid(row=0, column=0, pady=20)
        
        keyboards = [
            ("US English", "us"),
            ("UK English", "gb"),
            ("Spanish", "es"),
            ("French", "fr"),
            ("German", "de"),
            ("Portuguese", "pt"),
            ("Italian", "it"),
            ("Japanese", "jp"),
            ("Russian", "ru")
        ]
        
        self.keyboard_var = tk.StringVar(value=self.config['keyboard'])
        
        for i, (name, code) in enumerate(keyboards):
            ttk.Radiobutton(self.content_frame, text=name, variable=self.keyboard_var,
                           value=code, command=lambda: self.update_config('keyboard', self.keyboard_var.get())
                           ).grid(row=i+1, column=0, sticky=tk.W, padx=20, pady=2)
                           
    def network_step(self):
        ttk.Label(self.content_frame, text="Network Configuration", 
                 font=("Arial", 16, "bold")).grid(row=0, column=0, pady=20)
        
        ttk.Label(self.content_frame, text="Network will be configured automatically.").grid(row=1, column=0, padx=20)
        
        # Mirror selection
        ttk.Label(self.content_frame, text="Select package mirror:").grid(row=2, column=0, sticky=tk.W, padx=20, pady=(20,5))
        
        mirrors = [
            ("Global (deb.debian.org)", "global"),
            ("United States", "us"),
            ("United Kingdom", "uk"),
            ("Germany", "de"),
            ("France", "fr"),
            ("Japan", "jp"),
            ("Australia", "au"),
            ("Brazil", "br")
        ]
        
        self.mirror_var = tk.StringVar(value=self.config['mirror_country'])
        mirror_combo = ttk.Combobox(self.content_frame, textvariable=self.mirror_var, 
                                   values=[name for name, code in mirrors], state="readonly")
        mirror_combo.grid(row=3, column=0, sticky=(tk.W, tk.E), padx=20, pady=5)
        mirror_combo.bind('<<ComboboxSelected>>', 
                         lambda e: self.update_config('mirror_country', 
                         [code for name, code in mirrors if name == self.mirror_var.get()][0]))
                         
    def timezone_step(self):
        ttk.Label(self.content_frame, text="Select Timezone", 
                 font=("Arial", 16, "bold")).grid(row=0, column=0, pady=20)
        
        timezones = [
            "UTC",
            "America/New_York",
            "America/Chicago", 
            "America/Denver",
            "America/Los_Angeles",
            "Europe/London",
            "Europe/Paris",
            "Europe/Berlin",
            "Asia/Tokyo",
            "Asia/Shanghai",
            "Australia/Sydney"
        ]
        
        self.timezone_var = tk.StringVar(value=self.config['timezone'])
        timezone_combo = ttk.Combobox(self.content_frame, textvariable=self.timezone_var,
                                     values=timezones, state="readonly")
        timezone_combo.grid(row=1, column=0, sticky=(tk.W, tk.E), padx=20, pady=5)
        timezone_combo.bind('<<ComboboxSelected>>', 
                           lambda e: self.update_config('timezone', self.timezone_var.get()))
                 
    def desktop_step(self):
        ttk.Label(self.content_frame, text="Select Desktop Environment", 
                 font=("Arial", 16, "bold")).grid(row=0, column=0, pady=20)
        
        desktops = [
            ("XFCE (Recommended)", "xfce", "Lightweight and user-friendly"),
            ("GNOME", "gnome", "Modern and feature-rich"),
            ("KDE Plasma", "kde", "Highly customizable"),
            ("Openbox", "openbox", "Minimal window manager")
        ]
        
        self.desktop_var = tk.StringVar(value=self.config['desktop_environment'])
        
        for i, (name, code, desc) in enumerate(desktops):
            frame = ttk.Frame(self.content_frame)
            frame.grid(row=i+1, column=0, sticky=(tk.W, tk.E), padx=20, pady=5)
            
            ttk.Radiobutton(frame, text=name, variable=self.desktop_var,
                           value=code, command=lambda: self.update_config('desktop_environment', self.desktop_var.get())
                           ).grid(row=0, column=0, sticky=tk.W)
            ttk.Label(frame, text=desc, foreground="gray").grid(row=1, column=0, sticky=tk.W, padx=20)
            
    def drivers_step(self):
        ttk.Label(self.content_frame, text="Graphics Drivers & Firmware", 
                 font=("Arial", 16, "bold")).grid(row=0, column=0, pady=20)
        
        # NVIDIA driver option
        self.nvidia_var = tk.BooleanVar(value=self.config['install_nvidia'])
        nvidia_check = ttk.Checkbutton(self.content_frame, text="Install proprietary NVIDIA drivers", 
                                      variable=self.nvidia_var,
                                      command=lambda: self.update_config('install_nvidia', self.nvidia_var.get()))
        nvidia_check.grid(row=1, column=0, sticky=tk.W, padx=20, pady=5)
        
        ttk.Label(self.content_frame, text="Recommended for NVIDIA graphics cards", 
                 foreground="gray").grid(row=2, column=0, sticky=tk.W, padx=40)
        
        # Non-free firmware option
        self.nonfree_var = tk.BooleanVar(value=self.config['install_nonfree'])
        nonfree_check = ttk.Checkbutton(self.content_frame, text="Install non-free firmware", 
                                       variable=self.nonfree_var,
                                       command=lambda: self.update_config('install_nonfree', self.nonfree_var.get()))
        nonfree_check.grid(row=3, column=0, sticky=tk.W, padx=20, pady=(20,5))
        
        ttk.Label(self.content_frame, text="Required for some WiFi cards and other hardware", 
                 foreground="gray").grid(row=4, column=0, sticky=tk.W, padx=40)
                           
    def partition_step(self):
        ttk.Label(self.content_frame, text="Disk Partitioning", 
                 font=("Arial", 16, "bold")).grid(row=0, column=0, pady=20)
        
        # Get available disks
        try:
            result = subprocess.run(['lsblk', '-ndo', 'NAME,SIZE,TYPE'], 
                                  capture_output=True, text=True)
            disks = []
            for line in result.stdout.strip().split('\n'):
                if line and 'disk' in line:
                    parts = line.split()
                    if len(parts) >= 3:
                        disks.append(f"/dev/{parts[0]} ({parts[1]})")
        except:
            disks = ["/dev/sda (Unknown size)"]
            
        ttk.Label(self.content_frame, text="Select target disk:").grid(row=1, column=0, sticky=tk.W, padx=20)
        
        self.disk_var = tk.StringVar()
        disk_combo = ttk.Combobox(self.content_frame, textvariable=self.disk_var,
                                 values=disks, state="readonly")
        disk_combo.grid(row=2, column=0, sticky=(tk.W, tk.E), padx=20, pady=5)
        disk_combo.bind('<<ComboboxSelected>>', 
                       lambda e: self.update_config('target_disk', self.disk_var.get().split()[0]))
        
        # Filesystem selection
        ttk.Label(self.content_frame, text="Filesystem:").grid(row=3, column=0, sticky=tk.W, padx=20, pady=(20,5))
        
        filesystems = ["ext4", "btrfs", "xfs"]
        self.fs_var = tk.StringVar(value=self.config['filesystem'])
        fs_combo = ttk.Combobox(self.content_frame, textvariable=self.fs_var,
                               values=filesystems, state="readonly")
        fs_combo.grid(row=4, column=0, sticky=(tk.W, tk.E), padx=20, pady=5)
        fs_combo.bind('<<ComboboxSelected>>', 
                     lambda e: self.update_config('filesystem', self.fs_var.get()))
        
        # Warning
        ttk.Label(self.content_frame, text="⚠️ Warning: This will erase all data on the selected disk!", 
                 foreground="red").grid(row=5, column=0, padx=20, pady=20)
                 
    def users_step(self):
        ttk.Label(self.content_frame, text="User Accounts", 
                 font=("Arial", 16, "bold")).grid(row=0, column=0, pady=20)
        
        # Root password
        ttk.Label(self.content_frame, text="Root password:").grid(row=1, column=0, sticky=tk.W, padx=20)
        self.root_pass_entry = ttk.Entry(self.content_frame, show="*", width=30)
        self.root_pass_entry.grid(row=1, column=1, sticky=(tk.W, tk.E), padx=10, pady=5)
        
        ttk.Label(self.content_frame, text="Confirm root password:").grid(row=2, column=0, sticky=tk.W, padx=20)
        self.root_pass_confirm = ttk.Entry(self.content_frame, show="*", width=30)
        self.root_pass_confirm.grid(row=2, column=1, sticky=(tk.W, tk.E), padx=10, pady=5)
        
        # User account
        ttk.Label(self.content_frame, text="Full name:").grid(row=3, column=0, sticky=tk.W, padx=20, pady=(20,5))
        self.fullname_entry = ttk.Entry(self.content_frame, width=30)
        self.fullname_entry.grid(row=3, column=1, sticky=(tk.W, tk.E), padx=10, pady=5)
        
        ttk.Label(self.content_frame, text="Username:").grid(row=4, column=0, sticky=tk.W, padx=20)
        self.username_entry = ttk.Entry(self.content_frame, width=30)
        self.username_entry.grid(row=4, column=1, sticky=(tk.W, tk.E), padx=10, pady=5)
        
        ttk.Label(self.content_frame, text="Password:").grid(row=5, column=0, sticky=tk.W, padx=20)
        self.user_pass_entry = ttk.Entry(self.content_frame, show="*", width=30)
        self.user_pass_entry.grid(row=5, column=1, sticky=(tk.W, tk.E), padx=10, pady=5)
        
        ttk.Label(self.content_frame, text="Confirm password:").grid(row=6, column=0, sticky=tk.W, padx=20)
        self.user_pass_confirm = ttk.Entry(self.content_frame, show="*", width=30)
        self.user_pass_confirm.grid(row=6, column=1, sticky=(tk.W, tk.E), padx=10, pady=5)
        
        # Hostname
        ttk.Label(self.content_frame, text="Computer name:").grid(row=7, column=0, sticky=tk.W, padx=20, pady=(20,5))
        self.hostname_entry = ttk.Entry(self.content_frame, width=30)
        self.hostname_entry.grid(row=7, column=1, sticky=(tk.W, tk.E), padx=10, pady=5)
        self.hostname_entry.insert(0, self.config['hostname'])
        
    def summary_step(self):
        ttk.Label(self.content_frame, text="Installation Summary", 
                 font=("Arial", 16, "bold")).grid(row=0, column=0, pady=20)
        
        # Collect user input
        if hasattr(self, 'root_pass_entry'):
            self.config['root_password'] = self.root_pass_entry.get()
            self.config['username'] = self.username_entry.get()
            self.config['user_password'] = self.user_pass_entry.get()
            self.config['user_fullname'] = self.fullname_entry.get()
            self.config['hostname'] = self.hostname_entry.get()
        
        summary_text = f"""
Target Disk: {self.config['target_disk'] or 'Not selected'}
Filesystem: {self.config['filesystem']}
Username: {self.config['username']}
Computer Name: {self.config['hostname']}

The installer will:
1. Partition and format {self.config['target_disk']}
2. Copy the live system to the new disk
3. Configure user accounts
4. Install GRUB bootloader
        """
        
        ttk.Label(self.content_frame, text=summary_text, 
                 justify=tk.LEFT).grid(row=1, column=0, sticky=(tk.W, tk.E), padx=20)
        
        ttk.Label(self.content_frame, text="Click Install to begin the installation process.", 
                 font=("Arial", 12, "bold")).grid(row=2, column=0, pady=20)
                 
    def install_step(self):
        ttk.Label(self.content_frame, text="Installing on1OS", 
                 font=("Arial", 16, "bold")).grid(row=0, column=0, pady=20)
        
        self.install_progress = ttk.Progressbar(self.content_frame, length=400, mode='indeterminate')
        self.install_progress.grid(row=1, column=0, pady=20)
        self.install_progress.start()
        
        self.install_status = ttk.Label(self.content_frame, text="Preparing installation...")
        self.install_status.grid(row=2, column=0, pady=10)
        
        # Disable navigation
        self.back_btn['state'] = 'disabled'
        self.next_btn['state'] = 'disabled'
        
        # Start installation in background thread
        thread = threading.Thread(target=self.perform_installation)
        thread.daemon = True
        thread.start()
        
    def perform_installation(self):
        try:
            # Check if backend script exists
            backend_script = '/usr/local/share/on1os-installer/backend.sh'
            if not os.path.exists(backend_script):
                self.root.after(0, lambda: self.installation_error(f"Backend script not found: {backend_script}"))
                return
                
            # Save configuration to JSON file
            config_file = "/tmp/on1os-install-config.json"
            with open(config_file, 'w') as f:
                json.dump(self.config, f, indent=2)
            
            # Run the installation backend
            self.root.after(0, lambda: self.install_status.config(text="Starting installation..."))
            
            process = subprocess.Popen([backend_script], 
                                     stdout=subprocess.PIPE, 
                                     stderr=subprocess.STDOUT, 
                                     universal_newlines=True)
            
            # Monitor installation progress
            while process.poll() is None:
                line = process.stdout.readline()
                if line:
                    # Extract status from log line
                    if "] " in line:
                        status = line.split("] ", 1)[1].strip()
                        self.root.after(0, lambda s=status: self.install_status.config(text=s))
            
            # Check exit code
            if process.returncode == 0:
                self.root.after(0, self.installation_complete)
            else:
                error_output = process.communicate()[0] if process.stdout else "Unknown error"
                self.root.after(0, lambda: self.installation_error(error_output))
                
        except Exception as e:
            self.root.after(0, lambda: self.installation_error(str(e)))
            
    def installation_complete(self):
        self.install_progress.stop()
        self.install_status.config(text="Installation completed successfully!")
        
        messagebox.showinfo("Installation Complete", 
                           "on1OS has been installed successfully!\n\nPlease reboot your computer.")
        
        self.quit_installer()
        
    def installation_error(self, error_msg):
        self.install_progress.stop()
        self.install_status.config(text="Installation failed!")
        
        messagebox.showerror("Installation Error", 
                            f"Installation failed with error:\n{error_msg}")
        
        self.back_btn['state'] = 'normal'
        self.next_btn['state'] = 'normal'
        
    def update_config(self, key, value):
        self.config[key] = value
        
    def quit_installer(self):
        if messagebox.askokcancel("Quit", "Are you sure you want to quit the installer?"):
            self.root.quit()
            
    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    if os.geteuid() != 0:
        messagebox.showerror("Error", "This installer must be run as root.")
        sys.exit(1)
        
    installer = On1OSInstaller()
    installer.run()
