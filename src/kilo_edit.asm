; -------------------------------------------------------------------
; Text editing key handlers for the kilo editor
; -------------------------------------------------------------------
; Copyright 2025 by Gaston Williams
; -------------------------------------------------------------------

#include include/ops.inc
#include include/bios.inc
#include include/kernel.inc
#include include/kilo_def.inc

            extrn   eol_msg

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


; *******************************************************************
; ***              Key Handlers for Text Edit Keyss               ***
; *******************************************************************

            ;-------------------------------------------------------
            ; Name: do_kill
            ;
            ; Delete a line. 
            ;-------------------------------------------------------                                                
            proc  do_kill
            push  rf              ; save registers used
            push  r9
            ;---  no need to save changes in line buffer if deleting line
            call  get_num_lines
            ghi   r9              ; check current count of lines
            lbnz  dk_cont         ; if non-zero continue on
            glo   r9              ; check low byte of count
            lbz   dk_skip         ; if no lines left, just quit
            
            ;----- set r8 for current line
dk_cont:    call  getcurln
            call  is_eof          ; check if line index points to end of file
            lbdf  dk_skip         ; if line not deleted, skip update
            
            call  delete_line
            
            load  rf, e_state     ; get status byte
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     ; set refresh bit
            str   rf
            
            ;---- decrement total number of lines in the file
            call  dec_num_lines
            
dk_skip:    pop   r9
            pop   rf              
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_insline
            ;
            ; Insert a blank line in the buffer
            ;-------------------------------------------------------                                                
            proc  do_insline
            push  rf              ; save registers used
      
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dins_rdy        ; if no change in line, ready to insert line
            call  update_line     ; update line in txt buffer
      
            ;----- set r8 for current line
dins_rdy:   call  getcurln
          
            load  rf, ins_blank   ; set rf to insert blank line
            call  insert_line
            lbdf  dins_err
          
            load  rf, e_state     ; get state byte
            ldn   rf              
            ori   REFRESH_BIT     ; set status bit
            str   rf

            ;---- increment total number of lines in the file
            call  inc_num_lines
            
dins_exit:  pop   rf              ; restore registers
            return
            
dins_err:   load  rf, e_state     ; get editor state byte
            ldn   rf              
            ori   ERROR_BIT       ; set error bit for exit     
            str   rf
            lbr   dins_exit       ; exit with status bit set
            
ins_blank:    db 13,10,0            
            endp


            ;-------------------------------------------------------
            ; Name: do_copy
            ;
            ; Copy the current line of text to the clip board.
            ;
            ; Parameters: 
            ;   r8 - current line 
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   r8 - new current line
            ;-------------------------------------------------------                                                
            proc  do_copy
            push  rf              ; save registers used
            push  rd
            push  r8              ; save current line in case not found
            
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dc_rdy          ; if no change in line, ready to copy
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


            ;----- set r8 for current line
dc_rdy:     call  getcurln
            call  find_line         ; get the current line of text
            ldn   ra                ; check size 
            lbz   dc_empty          ; if not found, just set to empty line
            
            call  put_line_buffer   ; put text in line buffer
            load  rf, line_buf + 1  ; skip over dirty flag
            load  rd, clip_brd      ; set rd to insert blank line
            
            call  f_strcpy          ; copy text string to clip board buffer

            load  rf, dc_copied     ; show not found message
            call  set_status        ; in the status bar
            call  prt_status      
            call  get_cursor        ; restore cursor after status message update
            call  move_cursor

            load  rf, e_state     ; get editor state byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after eol msg
            str   rf

            lbr   dc_exit
            
dc_empty:   ldi   0                 ; set null for empty string
            str   rd  
            
dc_exit:    pop   r8                ; restore registers
            pop   rd    
            pop   rf
            return
dc_copied:    db '*Line copied to clip board.*',0
            endp
            
            ;-------------------------------------------------------
            ; Name: do_paste
            ;
            ; Insert a line from the clip board before the current 
            ; line of text.
            ; Parameters: 
            ;   r8 - current line 
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   r8 - new current line
            ;-------------------------------------------------------                                                
            proc  do_paste
            push  rf              ; save registers used

            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dp_rdy          ; if no change in line, ready to paste
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


            ;----- set r8 for current line
dp_rdy:     call  getcurln
          
            load  rf, clip_brd    ; set rf to insert blank line
            call  insert_line
          
            load  rf, e_state     ; get editor state byte
            ldn   rf               
            ori   REFRESH_BIT     ; set refresh bit
            str   rf

            ;---- increment total number of lines in the file
            call  inc_num_lines
            
            call  put_line_buffer ; put current line in line buffer
            ldi   0               ; move to beginning column
            plo   rb

            pop   rf              ; restore registers
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_split
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
            ;   DF = 1, line inserted (before or after)
            ;   DF = 0, line split in middle
            ;-------------------------------------------------------                                                
            proc  do_split
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   split_rdy       ; if no change in line, ready to split
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update

            
split_rdy:  ghi   rb              ; get the line size
            lbz   splt_after      ; insert line if empty line
            
            str   r2              ; save line size in M(X)
            glo   rb              ; get the current position
            lbz   splt_bfore      ; insert line before  
            sm                    ; subtract line size from char position
            lbdf  splt_after      ; insert line after
  
split_ln:   call  split_line
            call  setcurln        ; set the new current line
            call  find_line       ; set ra to the line in the text buffer
            ldn   ra              ; get the line size of new current line
            smi   2               ; subtract CRLF
            lbdf  splt_size       ; if positive, update the size       
            ldi   0               ; if less than zero, set to zero
splt_size:  phi   rb 
            call  put_line_buffer ; put current line in line buffer
            ldi   0               ; move to beginning column
            plo   rb
            clc                   ; clear DF to indicate line split
            return 
        
splt_after: call  do_down         ; move down to next line
splt_bfore: call  do_insline
            call  put_line_buffer ; put current line in line buffer
            ldi   0               ; move to beginning column
            plo   rb              ; set character position to zero
            phi   rb              ; set line size to zero
            call  set_cursor      ; make sure cursor is updated
            stc                   ; set DF to indicate line inserted
            return
            endp
            
            ;-------------------------------------------------------
            ; Name: do_join
            ;
            ; Join two lines into a single line.
            ;
            ; Parameters:
            ;   r8 - current line number
            ; Uses:
            ;   r9 - number lines above end of file
            ; Returns:
            ;   DF = 1, error (lines not joined)
            ;   DF = 0, success (lines joined)
            ;-------------------------------------------------------                                                
            proc do_join
            push  r9              ; save register used
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dj_rdy          ; if no change in line, ready to paste
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update

      
dj_rdy:     call  getcurln        ; make sure r8 is at current line
            call  is_eof          ; check if end of file, r9 has lines above eof
            lbdf  dj_none         ; nothing to join at eof, exit with DF set
            
            sub16 r9, 2           ; need at least two lines above eof, to join
            lbnf  dj_none         ; if less than 2 lines, don't join

            ghi   rb              ; check size of line
            lbnz  dj_join         ; if one or more characters, join with next line
            call  do_kill         ; if empty, just delete the line
            clc                   ; clear DF for success
            lbr   dj_exit       
                            
dj_join:    call  join_lines      ; attempt join the two lines
            lbdf  dj_err          ; if error, show message
            call  setcurln        ; set the new current line
            call  find_line       ; set ra to the line in the text buffer
            ldn   ra              ; get the line size of new current line
            smi   2               ; subtract CRLF
            lbdf  dj_size       
            ldi   0               ; if less than zero, set to zero
dj_size:    phi   rb 
            call  put_line_buffer ; put joined line in buffer
            clc                   ; clear DF for success
            lbr   dj_exit
                   
dj_err:     load  rf, dj_long     ; if error, show status message
            call  set_status
            call  prt_status      
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor
            
            load  rf, e_state     ; get editor state byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after error msg
            str   rf
            
dj_none:    stc                   ; set DF to indicate error
dj_exit:    pop   r9              ; restore register
            return
dj_long:       db '*Lines too long to join!*',0
            endp
