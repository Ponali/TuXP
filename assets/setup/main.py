import queue
import random
import os, sys, subprocess, termios, time
import re
from math import inf
from pathlib import Path
from blessed import Terminal
import threading
import time

def sendRaw(s):
    sys.stdout.write(s)
    sys.stdout.flush()

# disable echo
fd = sys.stdin.fileno()
attr = termios.tcgetattr(fd)
attr[3] &= ~termios.ECHO
termios.tcsetattr(fd,termios.TCSADRAIN,attr)

if os.getlogin()=="root":
    sendRaw("\x1b[?25l")
    os.system("setvtrgb rgb.txt")


skipEarly = True

early = True
term = Terminal()

def closestMode(a,b):
    if a[0]>b[0] or a[1]>b[1]: return inf
    return abs(a[0]-b[0])+abs(a[1]-b[1])

def setRes(xres,yres):
    os.system(f"fbset -g {xres} {yres} {xres} {yres} 32")
    for card in Path("/sys/class/drm/").iterdir():
        cn=card.name
        if not (cn.startswith("card") and "-" in cn):
            continue
        with open(f"/sys/class/drm/{cn}/modes","r") as file:
            txt = file.read()
            modes = [[int(j) for j in i.split("x") if j!=""] for i in txt.split("\n")]
            modes = [m for m in modes if len(m)==2]
            if len(modes)==0: modes.append([xres,yres])
            sorted(modes,key=lambda x: closestMode([xres,yres],x))
        try:
            with open(f"/sys/class/drm/{cn}/mode","w") as file:
                file.write(f"{modes[0][0]}x{modes[0][1]}")
        except: pass
        try:
            with open(f"/sys/class/drm/{cn}/mode","w") as file:
                file.write(f"{xres}x{yres}")
        except: pass


def quit():
    attr[3] |= termios.ECHO
    termios.tcsetattr(fd,termios.TCSADRAIN,attr)
    if os.getlogin()=="root":
        os.system("systemctl poweroff")
    os.system("reset && clear")
    exit()

def drawBG():
    if early:
        os.system("setfont Uni2-SeaBiosVGA16")
        setRes(80*9,25*16)
    else:
        os.system("setfont vgaoem")
        setRes(80*9,33*12)
    name="Windows Setup" if early else " Windows XP Professional Setup"
    sendRaw("\x1b[37;44m\x1b[H\x1b[2J")
    sendRaw(f"\x1b[2H{name}\x1b[3H{"═"*(15 if early else 31)}")

def fakeWindowsFile(pack):
    def shortenName(n):
        if len(n)<=8: return n
        n = re.sub(r"[\-+0-9.]","",n)
        if len(n)<=8: return n
        n = re.sub(r"[aeiou]","",n)
        return n[0:8]
    try:
        pack.replace("thunar","explorer")
        if "firefox" in pack:
            return "iexplore.exe"
        if pack.startswith("linux-image"):
            return "ntoskrnl.exe"
        if pack.startswith("linux-headers"):
            return "ntdll.dll"
        if pack.startswith("man"):
            return "winnt32.hlp"
        if pack.startswith("grub"):
            return "ntldr.exe"
        if pack.startswith("lib"):
            return f"{shortenName(pack[3:])}.dll"
        if pack.startswith("fonts-"):
            fontType="ttf" if random.randint(0,3)<3 else random.choice(["fon","fnt"])
            if "-ttf" in pack:
                pack.replace("-ttf","")
                fontType="ttf"
            return f"{shortenName(pack[6:])}.{fontType}"
        if pack.startswith("xfonts-"):
            return f"{shortenName(pack[7:])}.{random.choice(["fon","fnt"])}"
        if pack=="base":
            return "system"
        if pack=="bash":
            return "cmd.exe"
        ext=random.choice(["dll","exe"])
        if random.randint(0,7)==0: ext=random.choice(["dat","chw"])
        return f"{shortenName(pack)}.{ext}"
    except:
        return pack

def drawStatus(s,copying=False):
    bottomY = 25 if early else 33
    sendRaw(f"\x1b[{bottomY}H\x1b[0;30;47m")
    if copying:
        fn=fakeWindowsFile(s)
        if sum(bytes(fn,"utf8"))%11==1:
            fn=fn.upper()
        elif len(fn)>0 and sum(bytes(fn,"utf8"))%27==2:
            fn=fn[0].upper()+fn[1:].lower()
        else:
            fn=fn.lower()
        sendRaw(f"{" "*57}│Copying: {fn[0:12]} ")
    else:
        sendRaw(f"  {s}")
    sendRaw("\x1b[0J\x1b[0;37;44m")

def drawText(s):
    if len(s)>0:
        if s[0]=="\n": s=s[1:]
        if s[-1]=="\n": s=s[:-1]
    sendRaw("\x1b[5H\x1b[0;37;44m\x1b[0J   "+s.replace("\n","\n\r   ").replace("\x1b[0m","\x1b[0;37;44m"))

simplePipeType = "─│┌┐└┘"
doublePipeType = "═║╔╗╚╝"
def drawBox(x1,y1,x2,y2,pipes,head=""):
    sendRaw(f"\x1b[{y1+1};{x1+1}H{pipes[2]}{pipes[0]*(x2-x1-1)}{pipes[3]}")
    sendRaw(f"\x1b[{y1+2};{x1+1}H"+f"{pipes[1]}\x1b[D\x1b[B"*(y2-y1-1)+pipes[4])
    sendRaw(f"\x1b[{y1+2};{x2+1}H"+f"{pipes[1]}\x1b[D\x1b[B"*(y2-y1-1)+pipes[5])
    sendRaw(f"\x1b[{y2+1};{x1+2}H{pipes[0]*(x2-x1-1)}")
    sendRaw(f"\x1b[{y1+2};{x1+3}H{head}")

def selection(x,y,w,h,arr):
    arr=arr[0:h-1]
    def render(i,sel):
        sendRaw(f"\x1b[{y+i};{x}H")
        if sel:
            sendRaw("\x1b[7m")
        sendRaw((arr[i])[0:w].ljust(w))
        sendRaw("\x1b[27m")
    si = 0
    for i in range(len(arr)):
        render(i,i==0)
    with term.cbreak():
        while True:
            key = term.inkey()
            if key.name=="KEY_F3":
                quit()
            if key.name=="KEY_ENTER":
                return si
            if key.name=="KEY_DOWN" and si!=len(arr)-1:
                render(si,False)
                si=si+1
                render(si,True)
            if key.name=="KEY_UP" and si!=0:
                render(si,False)
                si=si-1
                render(si,True)

def updateProgress(perc,x,y,restart=False):
    txt=f"Your computer will reboot in {int(perc)} seconds.... " if restart else f"{int(perc)}%    "
    sendRaw(f"\x1b[{y+3};{x+(13 if restart else 32)}H\x1b[0;37;44m{txt}")
    if restart:
        # perc=(1-perc/15)*100
        bar = "\x1b[41m"+" "*int(min(1-perc/15,1)*52)
    else:
        bar = "\x1b[93m"+"█"*int(min(perc/100,1)*52)
    sendRaw(f"\x1b[{y+5};{x+8}H{bar}\x1b[0;37;44m")

def progressBox(x,y,head="",restart=False):
    drawBox(x,y,x+65,y+6,doublePipeType,head)
    drawBox(x+6,y+3,x+59,y+5,simplePipeType)
    updateProgress(15 if restart else 0,x,y,restart)

def getSize(d):
    with open(f"/sys/block/{d}/size","r") as file:
        sect = int(file.read())
        byts = sect*512
        return f"{int(byts/1024/1024)} MB"

def serializeDisk(d):
    return f"    {d:<33}{getSize(d):>10}"

def timeoutReboot(installed=True):
    successText = """
This portion of Setup has completed successfully.

If there is a floppy disk in drive A:, remove it.

To restart your computer, press ENTER.
When your computer restarts, Setup will continue.
"""
    failureText = """
Windows XP has not been installed on this computer.

If there is a floppy disk in drive A:, remove it.
To restart your computer, press ENTER.
"""
    drawText(successText if installed else failureText)
    drawStatus("ENTER=Restart Computer")
    progressBox(7,15,"",True)
    with term.cbreak():
        for i in range(15*10):
            key = term.inkey(timeout=0.1)
            if key: break
            if i%10==0:
                updateProgress(15-i//10,7,15,True)
    sendRaw("\x1b[H\x1b[0m\x1b[2J")
    attr[3] |= termios.ECHO
    termios.tcsetattr(fd,termios.TCSADRAIN,attr)
    if os.getlogin()=="root": os.system("reset && clear && systemctl reboot")

def runInstaller(installDisk):
    def drawFormatting():
        drawText("""


                Please wait while Setup formats the disk

    """+serializeDisk(installDisk))
        progressBox(7,22,"Setup is formatting...")
        drawStatus("")

    def drawCopying():
        drawText("""


                   Please wait while Setup copies files
                   to the Windows installation folders.
               This might take several minutes to complete.
""")
        progressBox(7,15,"Setup is copying files...")
        drawStatus("",True)

    def drawPleaseWait():
        drawText("""




    Please wait while Setup initializes your Windows XP configuration.
""")

    logfn=f"/root/{time.strftime("%c").replace(" ","-")}.log" if os.getlogin()=="root" else "./log.txt"
    logfile=open(logfn,"w")

    startperc=0.001
    onCopying=False
    onPleaseWait=False
    finished=False
    drawFormatting()
    def handleLine(line):
        nonlocal startperc,onCopying,onPleaseWait,finished
        logfile.write(line+"\n")
        if line.startswith("PARTITION"):
            cmd=line.split(" ")
            perc=int(line[1])
            updateProgress(perc,7,22)
        if line=="STARTCOPYING" and not onCopying:
            drawCopying()

        if line.startswith("I: Retrieving") or line.startswith("I: Validating"):
            cmd=line.split(" ")
            startperc=1-((1-startperc)**1.013)
            updateProgress(startperc*25,7,15)
            drawStatus(cmd[2],True)
        if line.startswith("I: Extracting") or line.startswith("I: Unpacking") or line.startswith("I: Configuring"):
            cmd=line.split(" ")
            startperc=1-((1-startperc)**1.013)
            updateProgress(startperc*25,7,15)
            drawStatus(cmd[2][0:-3],True)
        if line=="I: Unpacking the base system...":
            drawStatus("base",True)
        if line.startswith("dlstatus"):
            cmd=line.split(":")
            perc=float(cmd[2])
            updateProgress(perc*0.375+25,7,15)
            # drawStatus(cmd[1],True)
        if line.startswith("Get:"):
            cmd=line.split(" ")
            if cmd[4][0]=="[": return
            drawStatus(cmd[4],True)
        if line.startswith("pmstatus"):
            cmd=line.split(":")
            perc=float(cmd[2])
            updateProgress(perc*0.375+62.5,7,15)
            drawStatus(cmd[1],True)

        if line.startswith("PLEASEWAIT"):
            if not onPleaseWait:
                drawPleaseWait()
                onPleaseWait=True
            cmd=line.split(" ")
            drawStatus(" ".join(cmd[1:]))

        if line=="FINISHED":
            finished=True

    # run script
    outqueue = queue.Queue()
    def run():
        process = subprocess.Popen(
            ["bash", "install.sh",installDisk] if os.getlogin()=="root" else ["bash", "test.sh"],
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
            try:
                handleLine(line)
            except: pass

    runThread = threading.Thread(target=run, daemon=True)
    runThread.start()
    while runThread.is_alive():
        check_queue()
    logfile.close()
    if not finished:
        attr[3] |= termios.ECHO
        termios.tcsetattr(fd,termios.TCSADRAIN,attr)
        sendRaw("\x1b[H\x1b[0m\x1b[2J")
        print("An error might have happened with the install, and the installer closed unexpectedly.")
        print("Exiting out of this shell (Ctrl-D, exit...) will reboot the system.")
        print(f"All logs have been saved at \x1b[1m{logfn}\x1b[0m.")
        os.system("bash")
        drawBG()


# early part
if not (skipEarly and os.getlogin()!="root"):
    drawBG()
    drawStatus("Press F6 if you need to install a third party SCSI or RAID driver...")
    time.sleep(4)
    drawStatus("Press F2 to run Automated System Recovery (ASR)...")
    time.sleep(5)
    files = ["Windows Executive","Hardware Abstraction Layer","Kernel Debugger DLL","Windows Setup","PCI Bus Driver","ACPI Plug & Play Bus Driver","ACPI Embedded Controller Driver","IEEE 1394 Bus OHCI Compliant Port Driver","PCMCIA Support"]+[f"{i} Bus Driver" for i in ["PCI IDE","Intel IDE","ACPI Plug & Play"]]+["Partition Manager","IEEE 1394 SBP2 Storage Port Driver","TOSHIBA Floppy Driver (Libretto Type A)","Enhanced Host Controller","Open Host Controller","Universal Host Controller","Generic USB Hub Driver","Human Interface Parser","Serial Port Driver","Serial Port Enumerator","USB Storage Class Driver","Video Driver","XT, AT, or Enhanced Keyboard (83-104 keys)","Keyboard Driver","USB Keyboard","Compaq Drive Array","Adaptec AHA-154X/AHA-164X SCSI Host Adapter","Adaptec AHA-151X/AHA-152X/AIC-6X60 SCSI Adapter","Intelligent I/O Controller","Mylex DAC960/Digital SWXCR-Ex Raid Controller","Advansys 3550 Ultra Wide SCSI Host Adapter","AMI MegaRaid RAID Controller","Initio Ultra SCSI Host Adapter","Adaptec AHA-294XU2/AIC-7890 SCSI Controller","LSI Logic C8xx PCI SCSI Host Adapter","LSI Logic C896 PCI SCSI Host Adapter","IBM Portable PCMCIA CD-ROM Drive","Adaptec AIC-789X/AHA-3960 Ultra160 PCI SCSI Card","Adaptec 2000S/3000S Ultra160 SCSI RAID Controller","Qlogic QLA1080, 64 bit PCI LVD SCSI HBA","Qlogic QLA1280, 64 bit PCI LVD SCSI HBA","QLogic QLA12160, 64 bit PCI DUAL 160M SCSI HBA","Dell PERC 2/3 RAID Controller","CardBus/PCMCIA IDE MiniPort Driver","Mylex EXR2000,3000/AR160,170,352 Raid Controllers","Dynamic Volume Support (dmboot)","SCSI CD-ROM","SCSI Disk","SCSI Floppy Disk","RAM Disk Driver","Kernel Security Provider","FAT File System","Windows NT File System (NTFS)"]
    quicker=False
    for s in files:
        drawStatus(f"Setup is loading files ({s})...")
        loadTime = (9+random.random()*3-len(s)/60)/len(files)
        if random.randint(1,3)==1:
            quicker=True
            time.sleep(loadTime/(1.5+5*(random.random()**2)))
        elif quicker:
            time.sleep(loadTime*2)
        else:
            time.sleep(loadTime)
    drawStatus("Setup is starting Windows")
    time.sleep(3+random.random())

# switch to main part
print("\x1b[0m\x1b[H\x1b[2J")
time.sleep(0.1)
early = False
drawBG()

# "welcome to setup" message
drawText("""
\x1b[1mWelcome to Setup.\x1b[0m

This portion of the Setup program prepares Microsoft(R)
Windows(R) XP to run on your computer.


   \ue000  To set up Windows XP now, press ENTER.

   \ue000  To repair a Windows XP installation using
      Recovery Console, press R.

   \ue000  To quit Setup without installing Windows XP, press F3.
""")
drawStatus("ENTER=Continue  R=Repair  F3=Quit")
with term.cbreak():
    while True:
        key = term.inkey()
        if key.name=="KEY_F3":
            quit()
        if str(key).lower()=="r":
            sendRaw("\x1b[0m")
            attr[3] |= termios.ECHO
            termios.tcsetattr(fd,termios.TCSADRAIN,attr)
            os.system("reset && clear && bash")
            exit()
        if key.name=="KEY_ENTER":
            break
drawText("")
drawStatus("Please wait...")
time.sleep(1)

# skip the eula for now
# TODO: IMPLEMENT EULA

# parititoning
disks=[]
for disk in Path("/sys/block").iterdir():
    if disk.name.startswith(("loop","ram")):
        continue
    disks.append(disk.name)

drawText("""
The following list shows the existing disks on this computer.
Installing will remove ALL data.

Use the UP and DOWN ARROW keys to select an item in the list.

   \ue000  To set up Windows XP on the selected item, press ENTER.

WARNING: The boot device containing Setup may appear here.
""")
drawStatus("ENTER=Install  F3=Quit")
drawBox(2,15,77,30,simplePipeType)
idx = selection(8,19,66,10,[
    serializeDisk(d) for d in disks
])
installDisk = disks[idx]

# actually installing
runInstaller(installDisk)
timeoutReboot(True)
