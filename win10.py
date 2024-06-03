#!/usr/bin/python3
import libvirt
import subprocess
import time
import tkinter as tk
from tkinter import ttk

# Define the connection URI and VM name and Delay
uri = "qemu:///system"
vm_name = "win10-2"
time_delay = 10

# Function to update the progress bar
def update_progress_bar(progress, label_text, window, progress_var, progress_label):
    progress_var.set(progress)
    progress_label.config(text=label_text)
    window.update_idletasks()

# Function to close the GUI window
def close_window(window):
    print("Closing the window.")
    window.destroy()

# Function to check the state of the VM
def check_vm_state():
    conn = libvirt.open(uri)
    if conn is None:
        print("Failed to open connection to the hypervisor")
        return None

    try:
        vm = conn.lookupByName(vm_name)
        if vm.isActive():
            print(f"The {vm_name} virtual machine is running.")
            return vm
        else:
            print(f"The {vm_name} virtual machine is not running.")
            print("Starting the VM...")
            vm.create()
            return vm
    finally:
        conn.close()

# Function to start the VM and show the progress bar
def start_vm_and_show_progress(window, progress_var, progress_label):
    vm = check_vm_state()

    if vm is not None:
        for i in range(1, 6):
            update_progress_bar(i * 20, f'{i * 20}% completed', window, progress_var, progress_label)
            time.sleep(time_delay)

    print("Launching looking-glass-client")
    subprocess.Popen(['looking-glass-client', '-a' , '-m 88'])
    print("looking-glass-client launched")
    close_window(window)

# Create the main window
window = tk.Tk()
window.title("VM Startup Progress")
window.geometry("300x100")

# Create a progress bar
progress_var = tk.IntVar()
progress_bar = ttk.Progressbar(window, variable=progress_var, maximum=100)
progress_bar.pack(pady=20)

# Create a label for progress text
progress_label = tk.Label(window, text="0% completed")
progress_label.pack()

# Start the VM and show the progress bar
start_vm_and_show_progress(window, progress_var, progress_label)

# Run the GUI event loop
window.mainloop()
