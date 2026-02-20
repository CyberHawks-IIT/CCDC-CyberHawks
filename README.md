# CCDC-CyberHawks
CyberHawks scripts for CCDC 

*This repo is still a work-in-progress - Lucas 2025-04-30*

## Linux Notes 


## Windows Notes
- AD script checks services (NTDS/DNS/DHCP/Netlogon/KDC/W32Time), DNS query, required users, and basic group membership when the AD module is present (ADSI fallback included).
- Web script checks IIS services, default site state, web root content, port 80 listen, and HTTP GET on localhost.
- FTP script checks FTPSVC/W3SVC/WAS, FTP site state (IIS), port 21, and reads the FTP banner if possible.
Workstation audit uses ports + DNS query + LDAP checks for users, and validates HTTP/FTP reachability.

## PowerShell ISE quick start (safe execution policy)
- Open ISE: Start Menu -> search "Windows PowerShell ISE" -> right-click -> Run as administrator (only if you need admin).
- In ISE (or PowerShell), allow scripts for this session only:
  - `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`
- This is temporary and applies only to the current window, so it does not loosen system-wide policy for other users/processes.

## List of Scripts I want to build
- ./services-test.ps1 - Script to test services (will run on Win10)
    - I'd like this to make DNS requests and HTTP requests
    - Check what traffic can make it through the PaloAlto firewall
    - Check Host Firewall
- ./windows-setup.ps1 - Script to setup a Windows Server 2019 machine for CCDC
    - Install all the tools we need
    - Configure the host firewall
    - Check DNS service
- ./windows-check.ps1 - Script to check if the DNS server on a Windows Server 2019 server is working
    - This will run on the external win10 server
    - I want it to help us discover what is wrong with the DNS server
