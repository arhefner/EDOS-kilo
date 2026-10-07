; -------------------------------------------------------------------
; File functions for a simple full screen editor based on the Kilo 
; editor, a small text editor in less than 1K lines of C code 
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

            extrn   textbuf
            extrn   curline
            extrn   fildes
            extrn   k_dta
            extrn   readln
            extrn   readbyte
            extrn   k_char
            extrn   sfldes
            extrn   s_dta

            
            ;-------------------------------------------------------
            ; Name: find_eob
            ;
            ; Find the end of the text buffer
            ;
            ; Returns: 
            ;   r8 - Line number     
            ;   ra - pointer to line at end of buffer
            ;-------------------------------------------------------       
            proc  find_eob   
            load  ra, textbuf
            ldi   0             ; setup count
            phi   r8
            plo   r8
            
feob_lp:    lda   ra            ; get count
            lbz   feob_done     ; jump if end was found
            str   r2
            glo   ra
            add
            plo   ra
            ghi   ra
            adci  0
            phi   ra
            inc   r8            ; increment line count
            lbr   feob_lp
feob_done:  dec   ra            ; move back to end of buffer byte
            return              ; and return
            endp

            ;-------------------------------------------------------
            ; Name: setcurln
            ;
            ; Set current line to specified value            
            ; Parameters: 
            ;   r8 - line number to set as current
            ; Uses:
            ;   rf - pointer to current line byte
            ; Returns: (None)
            ;-------------------------------------------------------       
            proc  setcurln
            push  rf            ; save consumed register
            load  rf, curline   ; point to current line
            ghi   r8            ; write new current line
            str   rf
            inc   rf
            glo   r8
            str   rf
            pop   rf            ; recover consumed register
            return              ; and return
            endp

            ;-------------------------------------------------------
            ; Name: getcurln
            ;
            ; Get the current line number            
            ; Parameters: (None) 
            ; Uses:
            ;   rf - pointer to current line byte
            ; Returns:
            ;   r8 - line number to set as current
            ;-------------------------------------------------------       
            proc  getcurln
            push  rf            ; save consumed register
            load  rf,curline    ; point to current line
            lda   rf            ; get current line number
            phi   r8
            lda   rf
            plo   r8
            pop   rf            ; restore register
            return              ; and return
            endp                                   

            ;-------------------------------------------------------
            ; Name: load_file
            ;
            ; Open a file and read it into the text buffer, and 
            ; create spill files if necessary.
            ;
            ; Parameters: (file name in fname buffer) 
            ; Uses:
            ;   rf - pointer to text bytes
            ;   rd - pointer to file descripter
            ;   ra - line count
            ;   rc.0 - byte count
            ;   r7.0 - flags register
            ; Returns:
            ;   ra.0 = count of lines
            ;   DF = 1 - not loaded (new file or error)
            ;   DF = 0 - file loaded into buffer
            ;-------------------------------------------------------                       
            proc  load_file
            push  rf            ; save registers used    
            push  rd
            push  rc
            push  rb
            push  r7  

            load  rf, fname
            load  rd, fildes    ; point to file descriptor     
            ldi   0             ; flags
            plo   r7
            call  o_open        ; attempt to open the file
            lbdf  ld_exit       ; exit immediately, if file does not exist

            load  rf, textbuf   ; point to text buffer
            load  rd, fildes    ; point to file descriptor
            ldi   BUF_LINES     ; load up to default buffer size
            plo   rb            ; set limit to up to maximum lines                 
            call  load_text     ; load the text into the first buffer
            lbnf  ld_done       ; if entire file was read then we are done
            
            call  setup_spill   ; create spill files
            lbnf  ld_done       ; if DF = 1, exit with error
   
            ; if spill failed - set error flag 
            load  rf, e_state   ; get editor state byte  
            ldn   rf            
            ori   ERROR_BIT     ; set error bit
            str   rf            ; update editor state byte           
            
            load  rd, fildes    ; point to file descriptor     
            call  o_close       ; attempt close the file
            stc                 ; set DF for error
            lbr   ld_exit 

ld_done:    load  rd, fildes    ; point to file descriptor     
            call  o_close       ; close the file
            clc                 ; clear the DF flag
ld_exit:    pop   r7            ; restore registers
            pop   rb
            pop   rc
            pop   rd
            pop   rf
            return
            endp
            

            ;-------------------------------------------------------
            ; Name: load_text
            ;
            ; Read text from a file into the text buffer
            ;
            ; Parameters: (file name in fname buffer) 
            ;   rf - pointer to text bytes
            ;   rd - pointer to open file descripter
            ;   rb.0 - # lines to read (0 = read all lines)
            ; Uses:
            ;   ra - line count
            ;   rb.1 - memory page
            ;   rc.0 - byte count
            ; Returns:
            ;   ra.0 = count of lines
            ;   DF = 1 - additional lines not loaded
            ;   DF = 0 - entire file loaded into buffer
            ;   (ERROR_BIT in e_state set if an error occurs)
            ;-------------------------------------------------------                       
            proc  load_text        
            load  ra, k_heap    ; check heap address
            ldn   ra            ; get page for bottom of heap
            smi   1             ; set memory limit to one page below
            phi   rb            ; save page limit in rb.1
            
            load  ra, 0         ; clear line counter
            
loadlp:     push  rf            ; save text buffer address
            inc   rf            ; point to position after length
            call  readln        ; read next line
            lbdf  loadeof       ; jump if eof was found

loadnz:     ldi   13            ; write cr/lf to buffer
            str   rf
            inc   rf
            ldi   10
            str   rf
            inc   rc            ; add 2 characters
            inc   rc
            pop   rf            ; recover buffer address
            glo   rc            ; get count
            str   rf            ; and write to buffer
            inc   rf            ; move buffer to next line position
            str   r2
            glo   rf
            add
            plo   rf
            ghi   rf
            adci   0
            phi   rf
            inc   ra            ; bump line count
            
            ; check to see if we reached memory limit after line
            ghi   rf            ; check page for next line address
            str   r2            ; save in M(X)
            ghi   rb            ; get memory page limit 
            sm                  ; current page - limit 
            lbz  ldt_err        ; at the limit page, may not have enough memory
            
            ; check for max line count for buffer
            ; Note: we could expand logic to use rb.1 for > 256 lines per buffer
            glo   rb            ; get line limit
            str   r2            ; put in M(X)
            glo   ra            ; get line count
            sm                  ; check for maximum lines read
            lbnz  loadlp        ; load up to maximum of lines
            stc                 ; set DF to indicate more lines
            lbr   loaddn
            
loadeof:    clc                 ; clear DF flag (no more lines)
            pop   rf            ; recover buffer address
            glo   rc            ; see if bytes were read
            lbz   loaddn        ; jump if not

            ldi   13            ; write cr/lf to buffer
            str   rf
            inc   rf
            ldi   10
            str   rf
            inc   rc            ; add 2 characters
            inc   rc
            glo   rc            ; get count
            str   r2
            glo   rf
            add
            plo   rf
            ghi   rf
            adci  0
            phi   rf
            clc                 ; clear DF flag after arithmetic
loaddn:     ldi   0             ; write termination
            str   rf
            return 
                  
ldt_err:    ldi   0             ; write termination (just in case)
            str   rf
            load  rf, e_state   ; get editor state byte
            ldn   rf
            ori   ERROR_BIT     ; set the error bit to exit with error message
            str   rf            ; ave editor state
            clc                 ; clear DF (no more loading after error)    
            return
            endp
            
            ;-------------------------------------------------------
            ; Name: readln
            ;
            ; Read a line from a file into the text buffer
            ;
            ; Parameters
            ;   rf - pointer to text buffer
            ; Uses:
            ;   rc - byte count    
            ; Returns:
            ;   DF = 0, line read 
            ;   DF = 1, end of file encountered
            ;-------------------------------------------------------            
            proc  readln
            ldi   0             ; set byte count
            phi   rc
            plo   rc
readln1:    call  readbyte      ; read a byte
            lbdf  readlneof     ; jump on eof

            plo   re            ; keep a copy
            smi   10            ; look for first newline character
            lbz   readln2       ; go to possible blank line
            smi   22            ; look for anything else below a space
            lbnf  readln1       ; skip over any other control characters
            lbr   readln3       ; otherwise, process printable characters
            
readln2:    call  readbyte      ; read a byte
            lbdf  readlneof     ; jump on eof

            plo   re            ; keep a copy
            smi   10            ; look for second newline character
            lbz   readln4       ; exit on blank line
            smi   22            ; look for anything else below a space
            lbnf  readln2       ; skip over any other control characters
                            
readln3:    glo   re            ; recover byte
            str   rf            ; store into buffer
            inc   rf            ; point to next position
            inc   rc            ; increment character count
            glo   rc            ; check for text longer than max line size
            smi   MAX_LINE      ; read up to MAX_LINE characters
            lbz   readln4       ; split long text into individual lines
            
            call  readbyte      ; read next byte
            lbdf  readlneof     ; jump if end of file
            plo   re            ; keep a copy of read byte
            smi   32            ; make sure it is positive
            lbdf  readln3       ; loop back on valid characters
readln4:    ldi   0             ; signal valid read
readlncnt:  shr                 ; shift into DF
            return              ; and return to caller
readlneof:  ldi   1             ; signal eof
            lbr   readlncnt
            endp

            ;-------------------------------------------------------
            ; Name: readbyte
            ;
            ; Read a byte from a file into the character buffer
            ;
            ; Parameters
            ;   rf - pointer to text buffer
            ; Uses:
            ;   rc - byte count    
            ; Returns:
            ;   DF = 0, byte read 
            ;   DF = 1, end of file encountered
            ;-------------------------------------------------------
            proc  readbyte
            push  rf
            push  rc
            load  rf, k_char
            ldi   0
            phi   rc
            ldi   1
            plo   rc
            call  o_read
            glo   rc
            lbz   readbno
            ldi   0
readbcnt:   shr
            load  rf, k_char
            ldn   rf
            plo   re
            pop   rc
            pop   rf
            glo   re
            return
readbno:    ldi   1
            lbr   readbcnt
            endp
            
            
            ;-------------------------------------------------------
            ; Name: save_file
            ;
            ; Save the text buffer to a file.

            ; Parameters: (file name in fname buffer) 
            ; Uses:
            ;   rf - pointer to text bytes
            ;   rd - pointer to file descripter
            ;   rc - byte count
            ;   r7.0 - flags register
            ; Returns: 
            ;   DF = 0, file saved successfully
            ;   DF = 1, an error occurred when saving file
            ;-------------------------------------------------------                       
            proc  save_file    
            push  rf            ; save registers used in save
            push  rd
            push  rc
            push  r7

            load  rf, fname     ; point to filename
            load  rd, fildes    ; point to file descriptor
            ldi   3             ; flags for open, create, truncate
            plo   r7
            call  o_open        ; open the destination file
            lbdf  sf_exit       ; if we can't save file exit with error

            load  rf, spill_cnt ; get the spill count
            ldn   rf        
            lbz   sf_text       ; if no spill files, save text to file


            load  rf, e_state   ; get editor state byte  
            ldn   rf            
            ani   BUFFER_CHG    ; check buffer changed bit
            lbz   sf_cont       ; skip if current buffer not changed
            
            call  save_buffer   ; save current buffer to spill file

sf_cont:    call  reset_buf     ; reset to spill file zero
sf_lp:      call  copy_buffer   ; copy spill file to saved file
            call  next_buf      ; point to next spill file
            lbnf  sf_lp         ; keep going until out of spill files
            lbr   sf_done       ; close file after save
            
sf_text:    load  rf, textbuf   ; point to text buffer
            load  rd, fildes    ; point to file descriptor            
            call  save_text     ; save the text buffer to the file
            lbdf  sf_err
            
sf_done:    call  o_close       ; close the file

            load  rf, e_state   ; get editor state byte  
            ldn   rf            
            ani   SAVED_MASK    ; clear new, dirty and buffer changed bits
            str   rf
            clc                 ; clear DF for success
            
sf_exit:    pop   r7            ; restore registers used
            pop   rc
            pop   rd
            pop   rf 
            return 
            
sf_err:     call  o_close       ; attempt to close open file
            stc                 ; set DF=1 for error
            lbr   sf_exit       ; exit with error      
            endp



            ;-------------------------------------------------------
            ; Name: save_text
            ;
            ; Save the text buffer to file.

            ; Parameters: (file name in fname buffer) 
            ;   rf - pointer to text bytes
            ;   rd - pointer to oepn file descripter
            ; Uses:
            ;   rc - byte count
            ;   r7.0 - flags register
            ; Returns: 
            ;   DF = 0, buffer saved successfully
            ;   DF = 1, an error occurred when saving buffer
            ;-------------------------------------------------------                       
            proc  save_text    
            push  rc            ; save registers used in save

st_lp:      ldn   rf            ; get length byte
            lbz   st_dn        ; jump if done

            push  rf            ; save buffer position
            lda   rf            ; get length byte
            plo   rc
            ldi   0             ; clear high byte of count
            phi   rc
            call  o_write       ; write the line
            pop   rf            ; recover buffer
            lbdf  st_err        ; if we had a write error, exit
            
            lda   rf            ; get length byte
            str   r2            ; and add to position
            glo   rf
            add
            plo   rf
            ghi   rf
            adci  0
            phi   rf
            lbr   st_lp         ; loop back for next line

st_err:     stc                 ; set DF=1 for error
            lbr   st_exit       ; exit with error
            
st_dn:      clc                 ; clear DF flag for successful return
st_exit:    pop   rc            ; restore registers used
            return 
            endp
