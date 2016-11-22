#!/bin/bash
VBoxManage startvm --type headless Win7
cd web/
./manage.py runserver 0.0.0.0:8000 &
cd ..
./cuckoo.py
