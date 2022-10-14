#!/usr/bin/env bash

i=0
while [ $i -ne 20 ]
do
        usbreset 001/00$i
        usbreset 002/00$i
        i=$(($i+1))
done
systemctl restart deepracer-core