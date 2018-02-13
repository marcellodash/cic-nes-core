#! /usr/bin/env python
# -*- coding: utf-8 -*-

import struct

with open("nescic-dis.txt", "rb") as f:
    cicdis = f.readlines()

output = bytearray(1024)

for line in cicdis:
    
    line_str = str(line, "utf-8")
    
    if len(line_str) > 3:

        if line_str[3] == ":":
            
            address = int(line_str[0:3], 16)
            data = int(line_str[5:7], 16)
            output[address] = data
            
            if line_str[8] != " ":
        
                data = int(line_str[8:10], 16)
                #find next address
                add_high = address & 0xF80
                address &= 0x7F
                if address & 0x03 == 0 or address & 0x03 == 3:
                    address = (address >> 1) + 0x40 + add_high
                else:
                    address = (address >> 1) + add_high
                    
                output[address] = data
        else:
            pass

with open("cicbytes.bin", "wb+") as f:
    f.write(output)
