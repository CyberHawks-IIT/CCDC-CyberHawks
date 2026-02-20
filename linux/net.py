import subprocess
import time
from datetime import datetime
import sys

conns = []
header = ""

while True:
   now = datetime.now()
   hour = now.hour
   minute = now.minute
   second = now.second
   millisecond = now.microsecond // 1000  # Convert microseconds to milliseconds
   # Print in formatted style
   output = subprocess.check_output("sudo ss -plunteia", shell=True).decode().split("\n")
   if header == "":
      print(output[0])
      header = output[0]
   for i in range(1,len(output)):
      conn = output[i].split()
      if not conn == [] and conn not in conns:
         print(f"[{hour:02d}:{minute:02d}:{second:02d}.{millisecond:03d}] {output[i]}")
         conns.append(conn)
      output[i] = conn
   for saved in conns:
      if saved not in output:
         conns.remove(saved)
   time.sleep(0.1)