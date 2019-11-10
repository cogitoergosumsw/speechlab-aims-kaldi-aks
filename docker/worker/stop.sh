#!/bin/bash

#kill worker
ps axf | grep worker.py | grep -v grep | awk '{print "kill -15 " $1}' | sh

