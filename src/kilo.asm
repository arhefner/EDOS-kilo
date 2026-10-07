; -------------------------------------------------------------------
; A simple full screen editor based on the Kilo editor, 
; a small text editor in less than 1K lines of code 
; written by Salvatore Sanfilippo aka antirez 
; available at https://github.com/antirez/kilo
; and described step-by-step at the website 
; https://viewsourcecode.org/snaptoken/kilo/index.html
; -------------------------------------------------------------------
; Also based on the Elf/OS edit program written by Michael H Riley
; available https://github.com/rileym65/Elf-Elfos-edit
; -------------------------------------------------------------------
; Copyright 2025 by Gaston Williams
; -------------------------------------------------------------------
; Based on software written by Michael H Riley
; Thanks to the author for making this code available.
; Original author copyright notice:
; *******************************************************************
; *** This software is copyright 2004 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

#include include/ops.inc
#include include/bios.inc
#include include/kernel.inc
#include include/kilo_def.inc

            extrn   msg_err

            org     2000h
start:      br      main


; Build information

ever

db    'Copyright 2025 by Gaston Williams',0


; Main code starts here, check provided argument
main:       lda   ra              ; move past any spaces
            smi   ' '
            lbz   main
            dec   ra              ; move back to non-space character
            load  rf,fname        ; point to filename storage
fnamelp:    lda   ra              ; get byte from filename
            str   rf              ; store int buffer
            inc   rf
            smi   33              ; look for space or less
            lbdf  fnamelp         ; loop back until done
            dec   rf              ; point back to termination byte
            ldi   0               ; and write terminator
            str   rf
            
            load  rf,fname        ; point to filename storage
            ldn   rf              ; get byte from argument
            lbnz  k_good          ; jump if filename given

            call  o_inmsg         ; otherwise display usage message
              db  'Usage: kilo filename',10,13,0
            return                ; and return to os

     
k_good:     call  o_inmsg
              db 10,13,'Loading...',10,13,0

            call  begin_kilo  
            lbdf  k_error         ; Just show error msg   
                          
            ;----- read and process keys until Ctrl+Q is pressed  
            call  do_kilo
             
k_exit:     call  end_kilo
        
            return                ; return to Elf/OS

k_error:    load  rf, msg_err 
            call  o_msg         ; show file error message
            lbr   k_exit          ; and end program
            
            ;------ define end of execution block
            end     start
