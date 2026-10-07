; -------------------------------------------------------------------
; Scrolling and Line utility functions for the kilo editor
; -------------------------------------------------------------------
; Copyright 2025 by Gaston Williams
; -------------------------------------------------------------------

;-------------------------------------------------------------------------------
;                      General Register Usage                     
;  r7 - Cursor position                                      
;  r8 - Current line                                         
;  r9 - cursor limits, window size, line counter
;  ra - Text buffer pointer
;  rb.1 - line size                                  
;  rb.0 - char position in line 
;  rc.0 - counter, dimension value (for count)                                           
;  rc.1 - column offset
;  rd - Destination pointer, parameter register
;  rf - General buffer pointer                               
;-------------------------------------------------------------------------------

#include include/ops.inc
#include include/bios.inc
#include include/kernel.inc
#include include/kilo_def.inc
            
            extrn   size_h
            extrn   size_w
            extrn   row_offset
            extrn   col_offset

            
            ;*******************************************************************
            ;***                 Scrolling Utilities                         ***
            ;*******************************************************************

            ;-------------------------------------------------------
            ; Name: scroll_up
            ;
            ; Calculate the row offset after the current line is  
            ; moved up towards the top of the file
            ; 
            ; Parameters: 
            ;   r8 - current line
            ; Uses:
            ;   rf - buffer pointer
            ;   r9 - row offset value
            ; Returns: 
            ;   rc.1 - column offset 
            ;   rb.1 - size of line 
            ;   rb.0 - character position clipped to end of line
            ;   r7.1 - updated cursor y position
            ;   r7.0 - updated cursor x position 
            ;-------------------------------------------------------            
            proc  scroll_up
            push  rf
            push  r9
            
            glo   rb              ; get current character position
            str   r2              ; save in M(X) for arithmetic
            ghi   rb              ; get size of line
            sm                    ; check character position
            lbdf  sup_x_ok        ; if len >= char position, no change
            ghi   rb              ; set current position to line length
            plo   rb              
            
sup_x_ok:   call  set_col_offset  ; set the column offset
            load  rf, row_offset  ; top line index
            lda   rf              ; get high byte
            phi   r9            
            ldn   rf              ; get low index byte
            plo   r9
            
            copy  r8, rf          ; copy current line for arithmetic
            sub16 rf, r9          ; subtract row offset from current line
            ldi   0               ; set DF value for no scroll 
            lbdf  no_upscrl       ; if current row >= row offset, no scroll
            call  set_row_offset  ; set row offset to current line
no_upscrl:  call  set_cursor      ; update cursor position

            call  flush_keys      ; flush the key buffer                                           

            pop  r9               ; restore registers
            pop  rf 
            return
            endp

            ;-------------------------------------------------------
            ; Name: scroll_down
            ;
            ; Calculate the row offset after the current line is  
            ; moved down towards the bottom of the file
            ; 
            ; Parameters: 
            ;   r8 - current row
            ; Uses:
            ;   rf - buffer pointer
            ;   r9 - row offset value
            ;   rc.0 - screen rows
            ; Returns: 
            ;   rb.0 - character position clipped to end of line
            ;   r7.1 - updated cursor y position
            ;   r7.0 - updated cursor x position 
            ;-------------------------------------------------------            
            proc  scroll_down
            push  rf              ; save registers used
            push  rc
            push  r9
            push  r8

            glo   rb              ; get current character position
            str   r2              ; save in M(X) for arithmetic
            ghi   rb              ; get size of line
            sm                    ; check character position
            lbdf  sdn_x_ok        ; if len >= char position, no change
            ghi   rb              ; set current position to line length
            plo   rb              
            
sdn_x_ok:   call  set_col_offset  ; set the column offset
            load  rf, row_offset  ; top line index
            lda   rf              ; get high byte
            phi   r9            
            ldn   rf              ; get low index byte
            plo   r9
              
            load  rf, size_h      ; height value
            ldn   rf              ; get byte value
            smi   2               ; subtract one for status line, and one for zero index
            plo   rc              ; save bottom line index
            
            str   r2              ; put on-screen rows in M(X)
            glo   r9              ; get low byte of row offset
            add                   ; add rows on-screen to row offset
            plo   r9              ; update low byte of sum 
            ghi   r9              ; update high byte with carry flag
            adci  0
            phi   r9              ; r9 = row offset + on-screen rows (bottom line)
          
            sub16 r9, r8          ; compare bottom index to current line
            ldi   0               ; set DF value for no scroll
            lbdf  no_dnscrl       ; bottom line >= current line we are okay            

            push  r8              ; save r8 for arithmetic
            glo   rc              ; get screen rows
            str   r2              ; save in M(X)
            glo   r8              ; get low byte of row index
            sm                    ; subtract screen rows from current line
            plo   r8              ; save low byte
            ghi   r8              ; adjust highbyte for borrow
            smbi  0
            phi   r8              ; row offset = current line - screen rows
            call  set_row_offset  ; save new row offset
            pop   r8              ; restore r8 after arithmetic

no_dnscrl:  call  set_cursor      ; adjust the cursor position

            call  flush_keys      ; flush the key buffer                                           

            pop   r8              ; restore registers used
            pop   r9  
            pop   rc
            pop   rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: scroll_left
            ;
            ; Calculate the column offset after the character   
            ; position is moved towards the beginning of the line.
            ; 
            ; Parameters: 
            ;   rb.0 - character position
            ;   rc.1 - column offset
            ; Uses:
            ;   rf - buffer pointer
            ; Returns: 
            ;   rc.1 - column offset 
            ;-------------------------------------------------------            
            proc  scroll_left
            push  rf              ; save register used
            load  rf, col_offset  ; horizontal index
            ldn   rf              ; get col offset 
            str   r2              ; save offset in M(X)
            glo   rb              ; get char position value
            sm                    ; subtract offset from Ex
            lbdf  no_lfscrl       ; if char position > col_offset, no scroll
            
            glo   rb              ; get the char position
            lbz   lfs_updt        ; if we went home, set offset to zero
            
            ldn   rf
            smi   SCREEN_TAB      ; move left a block of lines
            lbdf  lfs_updt        ; if 0 or positive, update  position
            ldi   0               ; if negative, set to zero (home)
lfs_updt:   str   rf              ; set new column offset
            phi   rc              ; set rc.1 to column offset

            load  rf, line_buf    ; check line buffer for text change
            lda   rf              ; get dirty byte, rf points to string
            lbz   lfs_line        ; if no change in line, ready to scroll
            call  update_line     ; update line in txt buffer for refresh
            dec   rf              ; clear dirty byte
            ldi   0
            str   rf

lfs_line:   load  rf, e_state     ; set refresh bit
            ldn   rf
            ori   REFRESH_BIT
            str   rf
no_lfscrl:  call  set_cursor      ; update cursor position
            pop   rf              ; restore register
            return 
            endp 

            ;-------------------------------------------------------
            ; Name: scroll_right
            ;
            ; Calculate the column offset after the character   
            ; position is moved towards the end of the line.
            ; 
            ; Parameters: 
            ;   rb.0 - character position
            ; Uses:
            ;   rf - buffer pointer
            ; Returns: 
            ;   DF = 0, if no scrolling occurred
            ;   DF = 1, if scrolling occurred 
            ;   rc.1 - column offset,  rc.0 is consumed 
            ;-------------------------------------------------------            
            proc  scroll_right
            push  rf              ; save register used
            
            load  rf, col_offset  ; horizontal index
            ldn   rf              ; get col offset 
            str   r2              ; save offset in M(X)
            load  rf, size_w      ; window width value
            ldn   rf              ; get width value
            add                   ; add width to column offset
            smi   1               ; subtract one for 1 based index
            str   r2              ; save sum as edge of screen in M(X)      
            glo   rb              ; get char position value
            sd                    ; subtract char position from edge of screen
            lbdf  no_rtscrl       ; if char position < edge of screen, no scroll
            
            sdi   0               ; negate difference to get surplus (position - edge)   
            str  r2               ; save surplus in M(X)
            ldi   0               ; set up counter
            plo   rc              ; to check for surplus requiring multiple screen tabs 
            
rts_lp:     inc   rc              ; bump counter for each screen tab value
            ldi   SCREEN_TAB      ; check size of surplus
            sd                    ; diff = surplus - SCREEN_TAB
            str   r2              ; save new surplus in M(X)
            lbdf  rts_lp          ; keep going until surplus < SCREEN_TAB
            
            load  rf, col_offset  ; update column offset with number of screen tabs
rts_adj:    ldn   rf              ; get column offset
            adi   SCREEN_TAB      ; move screen to the left a block of columns            
            str   rf              ; update screen offset
            phi   rc              ; save screen offset in rc.1
            dec   rc              ; decrement counter
            glo   rc              ; check if counter is done
            lbnz  rts_adj
            
            load  rf, line_buf    ; check line buffer for text change
            lda   rf              ; get dirty byte, rf points to string
            lbz   rts_line        ; if no change in line, ready to scroll
            call  update_line     ; update line in txt buffer for refresh
            dec   rf              ; clear dirty byte
            ldi   0
            str   rf              ; after line was saved


rts_line:   load  rf, e_state     ; set refresh bit
            ldn   rf
            ori   REFRESH_BIT
            str   rf
              
no_rtscrl:  call  set_cursor      ; update cursor position
            pop   rf              ; restore register
            return 
            endp 


            ;*******************************************************************
            ;***                      Line Utilities                         ***
            ;*******************************************************************
                    
            ;-------------------------------------------------------
            ; Name: refresh_line
            ;
            ; Send the ANSI sequences and text to refresh a line 
            ; on the screen.
            ; 
            ; Parameters: 
            ;   r7 - cursor position
            ; Uses:
            ;   rf - buffer pointer 
            ;   rc.1 - column offset
            ;   r7 - cursor position
            ; Returns: (None)
            ;-------------------------------------------------------            
            proc  refresh_line
            push  rf              

            load  rf, line_buf    ; point to current line buffer
            lda   rf              ; get dirty flag
            lbz   rl_done         ; if no changes, exit 
            
            call  get_col_offset  ; get column offset in rc.1
            ghi   rc              ; get character offset
            str   r2              ; save in rf
            glo   rf
            add                   ; add offset to rf
            plo   rf              ; update low byte
            ghi   rf              ; update high byte
            adci  0               ; with carry flag 
            phi   rf              ; rf now points to first on-screen character
            
            push  r7              ; save cursor position  
            
            ldi   0               ; clear out char counter
            plo   r7              ; set cursor position to beginning of line                          

            call  o_inmsg
              db 27,'[?25l',0     ; hide cursor        

            call  move_cursor     ; position cursor

            call  o_inmsg
              db 27,'[2K',0       ; erase line

            call  move_cursor     ; position cursor to beginning of line

rl_next:    lda   rf              ; get character from buffer
            lbz   rl_eol          ; null marks the end of line
            call  o_type          ; print character to screen          
            lbr   rl_next

rl_eol:     pop   r7              ; restore cursor position
            call  move_cursor     ; position cursor 
              
            call  o_inmsg
              db 27,'[?25h',0     ; show cursor        

rl_done:    pop   rf              ; restore register
            return 
            endp  

            ;-------------------------------------------------------
            ; Name: split_line
            ;
            ; Split the current line into two lines.
            ; Parameters:
            ;   rb.1 - line length
            ;   rb.0 - character position
            ; Uses:
            ;   rf - buffer pointer
            ;   ra - pointer to line in text buffer
            ;   rc.0 - count of bytes
            ;   rc.1 - remaining count
            ; Returns:
            ;   DF = 0, success
            ;   DF = 1, error, unable to split line
            ;-------------------------------------------------------               
            proc  split_line
            push  rf              ; save registers used
            push  rd              
            push  rc
            
            glo   rb              ; get the character position in line
            lbz   sl_err          ; no split at beginning of line
            str   r2              ; save in M(X)
            ghi   rb              ; get length of line
            sm                    ; check position with length of line
            lbz  sl_err           ; no split at end of line
            lbnf sl_err           ; if negative, that's an error
            phi  rc               ; save difference in rc.1
            
            ;----- set r8 for current line
            call  getcurln
            call  find_line       ; ra points to line length
            inc   ra              ; skip over length
            
            load  rd, work_buf    ; destination in work buffer
            glo   rb              ; get character position
            plo   rc
            
sl_left:    lda   ra              ; get a byte from the left side 
            str   rd              ; save in work buffer
            inc   rd              ; move ptr to next character in buffer
            dec   rc              ; count down 
            glo   rc              ; check count
            lbnz  sl_left       ; keep going until all left characters are copied
            
            ldi   13              ; end line with CRLF and null
            str   rd              ; save CR
            inc   rd
            ldi   10              
            str   rd              ; save LF
            inc   rd
            ldi    0              ; save Null at end of line
            str   rd
            
            load  rf, work_buf    ; set rf to insert left part of line
            call  insert_line

            load  rd, work_buf    ; reset destination to start of work buffer
            ghi   rc              ; get remaining character count
            plo   rc
            call  getcurln        ; current line is new inserted line
            inc   r8
            call  setcurln        ; so set it back to original line
            call  find_line       ; go back to get original line
            inc   ra              ; jump over size
            glo   rb              ; get cursor position
            str   r2              ; save at M(X)
            glo   ra              ; move ra to character position
            add                   
            plo   ra    
            ghi   ra              ; update high byte with carry
            adci  0
            phi   ra
            
            
sl_rght:    lda   ra              ; get a byte from the left side 
            str   rd              ; save in work buffer
            inc   rd              ; move ptr to next character in buffer
            dec   rc              ; count down 
            glo   rc              ; check count
            lbnz  sl_rght         ; keep going until all left characters are copied
                        
            ldi   13              ; end line with CRLF and null
            str   rd              ; save CR
            inc   rd
            ldi   10              
            str   rd              ; save LF
            inc   rd
            ldi    0              ; save Null at end of line
            str   rd
            
            load  rf, work_buf    ; set rf to insert right part of line
            call  insert_line

            inc   r8              ; point r8 to original line
            call  delete_line     ; delete the old line
            call  put_line_buffer ; set the split line as current line
            
            dec   r8              ; move back to newly split line
            call  setcurln        ; set as current line
            
            load  rf, e_state     ; set refresh bit for update
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     
            str   rf

            ;---- increment total number of lines in the file
            call  inc_num_lines
            clc                   ; set DF = 0, for success
            lbr   sl_exit
            
sl_err:     stc                   ; set DF = 1, to indicate no split
sl_exit:    pop   rc              ; restore registers
            pop   rd
            pop   rf
            return
            endp



            ;-------------------------------------------------------
            ; Name: join_lines
            ;
            ; Join the current line with the next line.
            ; Parameters:
            ;   rb.1 - line length
            ;   rb.0 - character position
            ; Uses:
            ;   rf - buffer pointer
            ;   ra - pointer to line in text buffer
            ;   rc.0 - count of bytes
            ;   rc.1 - remaining count
            ; Returns:
            ;   DF = 0, success
            ;   DF = 1, error, unable to split line
            ;-------------------------------------------------------               
            proc  join_lines
            push  rf              ; save registers used
            push  rd              
            push  rc
            
            ghi   rb              ; get the length of the line
            plo   rc              ; set up count for first line bytes
            sdi   MAX_LINE+2      ; calculate maximum remaining size (plus CRLF)
            phi   rc              ; also save for calculating total size

            ;----- set r8 for current line
            call  getcurln
            call  find_line       ; ra points to line length
            inc   ra              ; skip over length
            
            load  rd, work_buf    ; set destination for working buffer
jl_fill:    lda   ra              ; get byte from first line
            str   rd              ; store in buffer
            inc   rd              ; move to next character position
            dec   rc              ; count down
            glo   rc              ; check count
            lbnz  jl_fill
            
            
            inc   r8              ; move to next line
            call  find_line       ; set ra to next line in text buffer
            lda   ra              ; get size
            lbz   jl_exit         ; if end of file, don't join 
            str   r2              ; save size in M(X)
            ghi   rc              ; get maximum
            sm                    ; subtract size from maximum 
            lbnf  jl_err          ; if size over maximum, don't join lines
            
            ldx                   ; get size in M(X)
            plo   rc              ; set up count to copy bytes
            
jl_add:     lda   ra              ; get byte from first line
            str   rd              ; store in buffer
            inc   rd              ; move to next character position
            dec   rc              ; count down
            glo   rc              ; check count
            lbnz  jl_add
            
            ldi   0               ; make sure buffer string ends in null
            str   rd
                    
jl_update:  call  getcurln        ; restore current line
            call  find_line        
        
            load  rf, work_buf    ; point buffer to joined lines 
            call  update_line     ; update it with joined line
            
            inc   r8              ; move down one line 
            call  delete_line     ; and delete second line
  
            call  dec_num_lines   ; decrement number of lines  
            
            load  rf, e_state     ; set refresh  bit to redraw screen
            ldn   rf
            ori   REFRESH_BIT
            str   rf

            clc    
            lbr   jl_exit

jl_err:     stc                   ; DF = 1, too indicate lines too long
jl_exit:    pop   rc              ; restore registers
            pop   rd
            pop   rf
            return
            endp
            
            ;-------------------------------------------------------
            ; Name: put_line_buffer
            ;
            ; Copy the current line of text into the line buffer.
            ; 
            ; Parameters: 
            ;   ra - text line ptr
            ;   r8 - current line number
            ; Uses:
            ;   rf - buffer pointer
            ;   rc.0 - counter for bytes
            ; Returns: (None)
            ;-------------------------------------------------------            
            proc  put_line_buffer
            push  rf              ; save registers used
            push  rc
            
            load  rf, line_buf    ; set buffer pointer
            ldi   0
            str   rf              ; set dirty flag to false
            inc   rf              ; move buffer ptr  
            call  getcurln        ; get current line number
            call  find_line       ; set ra to line in text buffer
            lbdf  plb_err         ; if not found set to CRLF and null
            
            lda   ra              ; get size of line
            plo   rc              ; set counter
plb_lp:     lbz   plb_done        ; if size is zero, we are done
            lda   ra              ; get next character
            str   rf              ; save in buffer
            inc   rf              ; move to next position
            dec   rc
            glo   rc              
            lbr   plb_lp          ; copy characters until done
            
plb_err:    ldi   13              ; write CR (10)
            str   rf
            inc   rf
            ldi   10              ; write LF (13)
            str   rf
            inc   rf              ; empty line has CRLF and null
             
plb_done:   ldi   0               ; line ends in null
            str   rf              ; save null in buffer
            inc   rf
            
            pop   rc              ; restore registers
            pop   rf            
            return
            endp
