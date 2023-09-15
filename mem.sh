#!/bin/bash

#This is a simple calc for looking glass
#Licenced by WTFPL
#by NeoTheFox 2018

#USAGE:
#glasscalc.sh WidthxHeight

function printhelp 
{
	echo "Usage:"
	echo "    glasscalc.sh widthxheight"
	echo "Example:"
	echo "    glasscalc.sh 800x600"
}

if [ -z $1 ]
then
	echo "No arguments provided"
	printhelp
	exit 0
fi

WIDTH=$(echo $1 | cut -d "x" -f1) 
HEIGHT=$(echo $1 | cut -d "x" -f2)

((M=$WIDTH*HEIGHT*4*2))
((M=M/1024/1024))
((M+=1))
((M|=M>>1))
((M|=M>>2))
((M|=M>>4))
((M|=M>>8))
((M|=M>>16))
((M+=1))

echo "$M"
