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

#include include/opcodes.def
#include include/bios.inc
#include include/kernel_api.inc
#include include/kilo_def.inc

            extrn   msg_err

            org     PROG_BASE
            db      'E','D','F'     ; ELF-DOS program signature
            db      1,0,0           ; program version, reserved byte

start:      br      main


; Build information

db    'Copyright 2025 by Gaston Williams',0


; Main code starts here, check provided argument
; ra - pointer to argv (table of pointers), rc - argc
main:       glo   rc              ; argv[0] is the program name, so
            smi   2               ; need at least two arguments
            lbnf  k_usage         ; show usage if no filename given

            inc   ra              ; point to argv[1]
            inc   ra
            lda   ra              ; get pointer to filename argument
            phi   rd
            ldn   ra
            plo   rd

            load  rf,fname        ; point to filename storage
            ldi   MAX_PATH        ; limit name to size of storage
            plo   rc
fnamelp:    lda   rd              ; get byte from filename
            str   rf              ; store into buffer
            inc   rf
            lbz   k_good          ; done once terminator is copied
            dec   rc              ; count down space left
            glo   rc
            lbnz  fnamelp         ; loop back until done or out of space

k_usage:    call  K_INMSG         ; otherwise display usage message
              db  'Usage: kilo filename',13,10,0
            ldi   1               ; exit code for error
            return                ; and return to os

     
k_good:     call  K_INMSG
              db 13,10,'Loading...',13,10,0

            call  begin_kilo  
            lbdf  k_error         ; Just show error msg   
                          
            ;----- read and process keys until Ctrl+Q is pressed  
            call  do_kilo
             
            call  end_kilo
            ldi   0               ; exit code for success
            return                ; return to ELF-DOS

k_error:    call  end_kilo        ; clean up before showing message
            load  rf, msg_err 
            call  K_MSG           ; show file error message
            call  K_INMSG
              db 13,10,0
            ldi   1               ; exit code for error
            return                ; return to ELF-DOS

            end     start
