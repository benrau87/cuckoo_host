# cuckoo_host
Host installation script

Usage:

1) Run setup.sh on fresh Ubuntu/Debian install

2) Follow prompts to create a local Cuckoo user

3) When installation is complete you should switch accounts to the one created in the second step

4) Launch virtualbox and create your first guest VM, The default name should be Win7 and take a snapshot once the agent is installed.

5) At your home folder (~) you will find various files/folders/tools, the cuckoo folder is under here as well

6) The virtaulbox.conf and cuckoo.conf files found at your home folder will need to be modified to include the virtual machine name that you created, snapshot name, along with the host information. Replace the .conf files under the cuckoo folder with all the modified/unmodified .conf files found at your home directory.

7) Back at ~ you will find a script that is called start_server.sh, this will launch a simple http file server for you to download the agent onto the VMs. Record the host IP address.

8) On the VM guest just navigate using the guest's browser to http://<host ip>:8181. For Windows machines you will need to install Python from the windows_python_exe folder as well as the agent in the cuckoo folder

9) Start the agent on the guest machine(s)

10) Back on the host start the cuckoo.py script under ~ with 'python cuckoo.py', also start the web interface under /cuckoo/web with 'python manage.py runserver 0.0.0.0:8000'

11) Navigate to http://localhost:8000 
