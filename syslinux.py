# patch isolinux.asm
lines=[]

with open("core/isolinux.asm","r") as file:
    needsCommenting = False
    i=0
    for l in file:
        i=i+1
        line = l.strip()
        if "global" in line and "copyright_str" in line:
            print("found global at line",i)
            print(line)
            lines.append(line)
            lines.append("syslinux_banner\tdb 0")
            lines.append("copyright_str\tdb CR, LF, \"Setup is inspecting your computer\'s hardware configuration...\", 0")
            continue
        if needsCommenting and len(line)>=1:
            if not (line[0] in [" " or "\t"] or (line.split(" ")+[""])[0] in ["db","asciidec"]):
                needsCommenting = False

        if line.startswith("syslinux_banner") and "db" in line:
            needsCommenting = True
            print("found existing banner def at line",i)
            print(line)
        if line.startswith("copyright_str") and "db" in line:
            needsCommenting = True
            print("found existing copyright string at line",i)
            print(line)

        if needsCommenting:
            print(f"commented out line: {line}")
            lines.append(f"; {line}")
        else:
            lines.append(line)
    file.close()

with open("core/isolinux.asm","w") as file:
    i=0
    for line in lines:
        i=i+1
        if i>1040 and i<1060:
            print(line)
        file.write(line+"\n")
    file.close()


# patch bios.c
lines=[]

with open("core/bios.c","r") as file:
    for l in file:
        line = l.strip()
        lines.append(line)
    file.close()

with open("core/bios.c","w") as file:
    for line in lines:
        if "dprintf" in line:
            file.write("""com32sys_t ireg, oreg;
	memset(&ireg, 0, sizeof(ireg));
	ireg.eax.b[1] = 0x06;      /* AH = Scroll Up Window */
	ireg.eax.b[0] = 0x00;      /* AL = 0 => clear entire window */
	ireg.ebx.b[1] = 0x07;      /* BH = attribute */
	ireg.ecx.w[0] = 0x0000;    /* CH=0, CL=0 (upper left) */
	ireg.edx.b[0] = 79;        /* DL = right column */
	ireg.edx.b[1] = 24;        /* DH = bottom row */
	__intcall(0x10, &ireg, &oreg);
	bios_set_cursor(0, 0, false);
"""+line+"\n")
        else:
            file.write(line+"\n")
    file.close()
