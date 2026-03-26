import subprocess

def cmd(command, return_error=False):
    try:
        output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT).decode() # .split("\n")
        return output
    except subprocess.CalledProcessError as e:
        if return_error:
            return e.output
        else:
            return ""

# Brute force PIDs
print("\nSearch for hidden pids (will also display threads):")
proc_files = cmd("sudo ls /proc").splitlines()
pids = []
for file in proc_files:
    try:
        pids.append(int(file))
    except:
        pass

pids.sort()

def get_exe(pid):
    out = cmd(f"sudo ls -l /proc/{pid}/exe").strip().splitlines()
    if out:
        return out[0].split(" -> ")[1]
    else:
        return None

for brutepid in range(pids[0],pids[-1]):
    if brutepid not in pids:
        # tryout = cmd(f"sudo file /proc/{brutepid}/stat")
        try:
            with open(f"/proc/{brutepid}/stat", 'rb') as file:
                tmp = file.readline()
                exists = True
        except:        
            exists = False
        
        # if "No such file or directory" not in tryout:
        if exists:
            exe = get_exe(brutepid)
            # status = {line.split("\t")[0][:-1]:int(line.split("\t")[1]) for line in cmd(f"sudo cat /proc/{brutepid}/status | grep -E '^Tgid|^Pid'").splitlines() if line.strip()}

            with open(f"/proc/{brutepid}/status", 'r') as file:
                status = {line.split("\t")[0][:-1]:int(line.split("\t")[1]) for line in file.read().splitlines() if line.strip().startswith("Tgid") or line.strip().startswith("Pid")}
                # print([f"'{line}'" for line in file.read()])


            if status['Tgid'] != status['Pid']:
                print(f"(thread) pid={brutepid}, exe={exe}, parent_exe={get_exe(status['Tgid'])}")
            else:
                print(f"HIDDEN PROCESS DETECTED!!!! PID={brutepid}, exe={exe}")
