# CCDC-CyberHawks
CyberHawks scripts for CCDC 

*This repo is still a work-in-progress - Lucas 2025-04-30*

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
