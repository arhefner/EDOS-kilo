; -------------------------------------------------------------------
; Data buffers and file functions for the kilo editor 
; -------------------------------------------------------------------
; Copyright 2025 by Gaston Williams
; -------------------------------------------------------------------

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


            ; ***************************************
            ; ***    Line and String Functions    ***
            ; ***************************************


            ;-------------------------------------------------------
            ; Name: find_line
            ;
            ; Set current line to specified value            
            ; Parameters: 
            ;   r8 - line number to find
            ; Uses:
            ;   rc - counter for lines
            ; Returns: 
            ;   DF = 0, if found
            ;   DF = 1, if not found
            ;   ra - pointer to line in buffer
            ;-------------------------------------------------------       
            proc  find_line
            push  rc            ; save consumed regsiter
            load  ra, textbuf   ; point to text buffer
            ghi     r8          ; get line number
            phi     rc
            glo     r8
            plo     rc
findlp:     ghi     rc
            lbnz    notfound
            glo     rc          ; see if count is zero
            lbz     found       ; jump if there
notfound:   lda     ra
            lbz     fnderr      ; jump if end of buffer was reached
            str     r2          ; prepare for add
            glo     ra          ; add to address
            add
            plo     ra
            ghi     ra
            adci    0
            phi     ra
            dec     rc          ; decrement count
            lbr     findlp      ; and check line
found:      ldi     0           ; signal line found
            shr
            lbr     fnd_done    ; and return to caller
fnderr:     dec     ra
            ldi     1           ; signal end of buffer reached
            shr
fnd_done:   pop     rc          ; restore register            
            return              ; return to caller
            endp


            ;-------------------------------------------------------
            ; Name: find_string
            ;
            ; Find a text string within the buffer
            
            ; Parameters: 
            ;   r8 - current line
            ;   rd - target string
            ;   rb.0 - character position
            ; Uses:
            ;   rf - pointer to buffer with text bytes
            ;   rc.0 - count of bytes, index of found string
            ;   r9.1 - original character position
            ; Returns:
            ;   DF = 1, match found
            ;   DF = 0, no match found
            ;   r8 - line with match
            ;   rb.0 - character position
            ;-------------------------------------------------------       
            proc  find_string
            push  rf              ; save registers
            push  rd
            push  rc
            push  r9
            
            glo   rb              ; get character position
            phi   r9              ; save in r9.1 in case never found

          
            call  find_line       ; find current line in r8
fs_nextln:  lda   ra              ; ra points to size of line to search
            lbz   fs_notfnd       ; if end of buffer, we never found it

            plo   rc              ; set up count
            load  rf, work_buf    ; set pointer to working buffer
fs_copy:    lda   ra              ; get a byte from the current line
            str   rf              ; put in working buffer 
            inc   rf              ; move pointer to next position
            dec   rc              ; count down
            glo   rc              ; check counter
            lbnz  fs_copy         ; keep going until count exhausted

            ldi   0               ; remove CRLF at end
            dec   rf
            str   rf              ; replace LF with null
            dec   rf              
            str   rf              ; replace CR with null
            
            load  rf, work_buf    ; set pointer back to beginning of source
            glo   rb              ; get original character position
            lbz   fs_search       ; if no offset, search the whole string

            str   r2              ; save cursor position in M(X)
            glo   rf              ; get low byte of buffer pointer
            add                   ; add cursor position to low byte
            plo   rf              ; save updated low byte
            ghi   rf              ; get high byte of buffer pointer
            adci  0               ; add carry to high byte
            phi   rf              ; update high byte of the buffer
            
fs_search:  call  strstr          ; check to see if string is in source
            lbdf  fs_found        ; we found it, exit with line value
            inc   r8              ; increment line count to next line
            ldi   0
            plo   rb              ; set cursor position to zero for next line
            lbr   fs_nextln       ; continue searching buffer
            
fs_found:   glo   rc              ; get offset of matching string
            str   r2              ; save offset in M(X)
            glo   rb              ; get current search position in line
            add                   ; add in offset
            plo   rb              ; set as current character for result
            call  setcurln        ; save matching line in r8 as current line
            stc                   ; set DF = 1, to indicate match 
            lbr   fs_exit
            
fs_notfnd:  call  getcurln        ; restore r8 to current line index
            ghi   r9              ; get original character position
            plo   rb              ; restore character position
            clc                   ; clear DF to indicate not found  
            
fs_exit:    pop   r9              ; restore registers
            pop   rc
            pop   rd
            pop   rf
            return 
            endp

            ;-------------------------------------------------------
            ; Name: insert_line
            ;
            ; Insert a line of text into the text buffer.
            ;
            ; Parameters: 
            ;   rf - pointer to text string
            ;   ra - pointer to current line
            ;   r8 - current line number
            ; Uses:
            ;   rd - destination pointer to text buffer
            ;   rc.0 - byte count
            ;   r9 - source pointer
            ;
            ; Returns:
            ;   DF = 1, out of memory error
            ;   r8 - new current line number
            ;-------------------------------------------------------                       
            proc  insert_line
            push  rd            ; save registers used
            push  rc
            push  r9
            
insertln:   ldi   0             ; setup count
            plo   rc
            phi   rc
            push  rf            ; save buffer position
insertlp1:  inc   rc            ; increment count
            lda   rf            ; get next byte
            lbnz  insertlp1
            glo   rc            ; get count + 1 for size byte
            stxd                ; and save it
            call  find_eob      ; find end of buffer
            glo   rc            ; add in count to get destination
            str   r2
            glo   ra
            plo   r9
            add
            plo   rd
            ghi   ra
            phi   r9            ; r9 points to end of old buffer
            adci  0
            phi   rd            ; rd point to end of new buffer     
            call  getcurln      ; get current line number
            call  find_line     ; find address of line
insertlp2:  ldn   r9            ; read source byte from end
            str   rd            ; place into destination
            glo   ra            ; check for completion
            str   r2
            glo   r9
            sm
            lbnz  inslp2c
            ghi   ra            ; check for completion
            str   r2
            ghi   r9
            sm
            lbnz  inslp2c
            lbr   inslp2d
inslp2c:    dec   r9            ; decrement positions
            dec   rd
            lbr   insertlp2     ; keep going until r9 = ra
inslp2d:    call  getcurln      ; get current line number
            call  find_line     ; find address of line
            irx                 ; recover count
            ldx
            smi    1            ; subtract out length byte from count
            str   ra            ; store into buffer
            inc   ra            ; point ra to next byte in buffer
            plo   rc            ; put into count
            pop   rf            ; recover input buffer
insertlp3:  glo   rc            ; get count
            lbz   insertdn      ; jump if done
            lda   rf            ; get byte from input
            str   ra            ; store into text buffer
            inc   ra
            dec   rc            ; decrement count
            lbr   insertlp3     ; loop back until done
insertdn:   call  getcurln      ; get current line number
            
            call  set_dirty     ; set the dirty bit after buffer change            
            clc                 ; show success (DF = 0)  
ins_err:    pop   r9            ; restore registers used
            pop   rc
            pop   rd
            return              ; return to caller
            endp
            
            ;-------------------------------------------------------
            ; Name: delete_line
            ;
            ; Delete current line from text buffer.

            ; Parameters:  
            ;   r8 - current line number
            ;   ra - pointer to current line
            ; Uses:
            ;   rd - destination pointer
            ;   rc - byte count
            ; Returns: 
            ;   DF = 0, if deleted
            ;   DF = 1, if not deleted
            ;   r8 - new currrent line
            ;-------------------------------------------------------                       

            proc  delete_line
            push  rd            ; save registers used
            push  rc
kill:       call  find_line     ; check if exists
            lbdf  killquit
            ghi   ra            ; save dest pointer
            phi   rd
            glo   ra
            plo   rd
            inc   r8            ; move to next line
            call  find_line     ; get address for line
killline:   ldn   ra            ; get length to next line
            lbz   killdone
            adi   1
            plo   rc
killloop:   lda   ra            ; get source byte
            str   rd            ; place into destintion
            inc   rd
            dec   rc            ; decrement count
            glo   rc            ; get count
            lbnz  killloop      ; loop until line is done
            lbr   killline      ; and loop for next line
killdone:   str   rd
            call  set_dirty     ; set the dirty bit after buffer change
            clc            
killquit:   call  getcurln      ; set r8 back to current line
            pop   rc            ; restore registers
            pop   rd    
            return
            endp      
            
            ;-------------------------------------------------------
            ; Name: update_line
            ;
            ; If the current line exists, insert a line of new text
            ; into the text buffer as the current line and delete
            ; the old line of text.  If the current line is not in  
            ; the buffer, append text to end of buffer. 
            ;
            ; Parameters: 
            ;   rf - pointer to new text string
            ;   r8 - current line number
            ; Uses:
            ;   ra - pointer to current line
            ;   r8 - current line number
            ;
            ; Returns:
            ;   DF = 0, line is updated
            ;   DF = 1, new line appended to buffer
            ;   r8 - new current line number
            ;-------------------------------------------------------                       
            proc  update_line
            push  rf            ; save line pointer
            call  find_line     ; check current line
            call  insert_line   ; insert new text
            
            inc   r8            ; move to the previous line number
            call  setcurln      ; and save it for delete
            
            call  delete_line   ; delete the previous line of text
            dec   r8            ; move back to new line
            call  setcurln      ; save it for refresh
            clc                 ; clear DF to indicate line updated
            pop   rf            ; restore line pointer
            return
            endp


            ; ***************************************
            ; ***      File and Data Buffers      ***
            ; ***************************************

            proc  fname
              ds      80        ; file name
            endp
              
            proc  fildes
              db      0,0,0,0   ; file descriptor
              dw      k_dta
              db      0,0
              db      0
              db      0,0,0,0
              dw      0,0
              db      0,0,0,0
            endp  

            proc  sfldes
              db      0,0,0,0   ; file descriptor
              dw      s_dta
              db      0,0
              db      0
              db      0,0,0,0
              dw      0,0
              db      0,0,0,0
            endp  


            proc  curline
              dw      0         ; current line variable
            endp

            proc  k_char
              db      0         ; character read from file
            endp  

            proc  k_dta
             ds      512        ; data transfer area  
            endp 

            proc  s_dta
             ds      512        ; data transfer area  
            endp 
                     
            proc  s_buf
             ds      256        ; spill transfer buffer  
            endp 

            ; text buffer format
            ; byte size of line (0 if end of buffer), followed by bytes for line
            .link .align para               
            proc  textbuf
              db      0
            endp
