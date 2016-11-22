#!/bin/bash
VBoxManage startvm --type headless Win7
./cuckoo.py
./web/manage.py runserver 0.0.0.0:8000
