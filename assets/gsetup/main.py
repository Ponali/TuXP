import tkinter as tk
import os
import subprocess
import threading
import queue
import socket
if os.getlogin()=="root":
    os.system("bash ../setres.sh 640 480")

# main window layout
root = tk.Tk()
root.geometry("640x480+0+0")
root.resizable(False,False)
root.attributes('-fullscreen',True) #root.overrideredirect(True)
canvas = tk.Canvas(root,width=640,height=480,background="#3A6CA3")
root.configure(borderwidth=0, highlightthickness=0)
canvas.configure(borderwidth=0, highlightthickness=0)
canvas.place(x=0,y=0)

# label1=tk.Label(root, text="Nothing will work unless you do.", fg="white")
# label1.place(x=20,y=60)
label1=canvas.create_text(20,60,width=600,anchor="nw", text="Nothing will work unless you do.", fill="white")

# handle when a line is met
def handleLine(line):
    canvas.itemconfig(label1,text="SCRIPT LINE: "+line)
    if "REBOOT-70F8FA016722C807ED0EDF22CD688AFA" in line:
        os.system("systemctl reboot")

# when it gets clicked on while there's a popup it'll go down
def lower_window(event):
    root.lower()
root.bind('<FocusIn>', lower_window)

# run script
outqueue = queue.Queue()
def run():
    process = subprocess.Popen(
        ["bash", "install.sh"] if os.getlogin()=="root" else ["bash", "test.sh"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )
    for line in process.stdout:
        outqueue.put(line.strip())
    process.wait()
def check_queue():
    while not outqueue.empty():
        line = outqueue.get()
        handleLine(line)
    root.after(100, check_queue)

threading.Thread(target=run, daemon=True).start()
check_queue()
root.mainloop()
