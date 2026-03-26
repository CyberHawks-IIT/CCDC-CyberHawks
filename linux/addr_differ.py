import subprocess

def cmd(command):
    try:
        output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT).decode() # .split("\n")
        return output
    except subprocess.CalledProcessError as e:
        return ""

uname = cmd("echo $(uname -r)").strip()

with open(f"/boot/System.map-{uname}", 'r') as file:
    sysmap_lines = file.read().splitlines()

sysmap = {}
for line in sysmap_lines:
    splt = line.split()
    if len(splt) == 3 and splt[2] not in sysmap:
        sysmap[splt[2]] = int(splt[0], 16)

with open(f"/proc/kallsyms", 'r') as file:
    kallsyms_lines = file.read().splitlines()

kallsyms = {}
for line in kallsyms_lines:
    splt = line.split()
    if len(splt) == 3 and splt[2] not in kallsyms:
        kallsyms[splt[2]] = int(splt[0], 16)

assert "_text" in sysmap and "_text" in kallsyms

diff = kallsyms['_text'] - sysmap['_text']

tocheck = [name for name in sysmap if name in kallsyms]
misaligned = [name for name in tocheck if kallsyms[name] != sysmap[name] + diff]

print("Misaligned/Potentially Hooked:", misaligned)