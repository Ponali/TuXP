import tkinter as tk
from tkinter import ttk
import os
import subprocess
import threading
import queue
import socket
if os.getlogin()=="root":
    os.system("bash ../setres.sh 800 600")

# main window layout
root = tk.Tk()
root.geometry("800x600+0+0")
root.resizable(False,False)
root.attributes('-fullscreen',True) #root.overrideredirect(True)
canvas = tk.Canvas(root,width=800,height=600,background="#3A6CA3")
root.configure(borderwidth=0, highlightthickness=0)
canvas.configure(borderwidth=0, highlightthickness=0)
canvas.place(x=0,y=0)

label1=canvas.create_text(20,40,width=600,anchor="nw", text="Who will use this computer?", fill="white")

entries = [ttk.Entry(root) for i in range(5)]
for i in range(5):
    entries[i].place(x=20,y=60+20*i)

with open("../realname.txt","r") as file:
    rn = file.read()
    rn.replace("\n","")
    rn.strip()
    entries[0].delete(0,tk.END)
    entries[0].insert(0,rn)
    file.close()

def onNextPress():
    subprocess.run(["bash","setup.sh"]+[e.get() for e in entries])

nxbutton = ttk.Button(root,text="Next",command=onNextPress)
nxbutton.place(x=600,y=500)

root.mainloop()
