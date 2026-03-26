import subprocess

def cmd(command):
    try:
        output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT).decode()
        return output
    except subprocess.CalledProcessError as e:
        return ""

def print_proto(proto):
    print(f"{proto}\n-------")
    proc_tcp = cmd(f"sudo cat /proc/net/{proto}").splitlines()
    conns = []
    for i in range(1,len(proc_tcp)):
        entries = proc_tcp[i].split()
        conns.append({"local_address":entries[1], "inode":entries[9]})

    for conn in conns:
        addr = conn['local_address'].split(":")
        iphex = addr[0]
        port = addr[1]
        ip = ".".join([str(int(iphex[i:i+2],16)) for i in range(0,len(iphex),2)][::-1])
        print(f"{ip}:{int(port,16)}, INODE={conn['inode']}")
        print(cmd(f"sudo lsof | grep {conn['inode']}"))

print_proto("tcp")
print_proto("udp")