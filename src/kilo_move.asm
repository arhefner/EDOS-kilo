; -------------------------------------------------------------------
; Cursor movement key handlers for the kilo editor
; -------------------------------------------------------------------
; Copyright 2025 by Gaston Williams
; -------------------------------------------------------------------

#include include/ops.inc
#include include/bios.inc
#include include/kernel.inc
#include include/kilo_def.inc

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
; ***           Key Handlers for Text Movement Keys               ***
; *******************************************************************

            ;-------------------------------------------------------
            ; Name: do_home
            ;
            ; Handle the action when the Home key is pressed
            ; Parameters: 
            ;   rb.0 - current character position
            ; Uses: (None)
            ; Returns:
            ;   rb.0 - current character position
            ;-------------------------------------------------------                      
            proc  do_home
            ldi   0             ; set char position to far left
            plo   rb     
            call  scroll_left   ; update the cursor position
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_end
            ;
            ; Handle the action when the End key is pressed
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current cursor position
            ; Uses:
            ; Returns:
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                       
            proc  do_end
            ghi   rb            ; get the line length
de_set:     plo   rb            ; set character position to end of line
            call  scroll_right  ; update cursor position
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_pgup
            ;
            ; Handle the action when the Page Up key is pressed
            ; Parameters: (None) 
            ; Uses:
            ;   r9 - window size
            ;   r8 - current line
            ; Returns:
            ;   r8 - current line 
            ;-------------------------------------------------------                                  
            proc  do_pgup
            load  rf, line_buf      ; set pointer to line buffer
            lda   rf                ; check dirty byte, rf points to string
            lbz   pup_rdy           ; if no change in line, ready to scroll
            call  update_line       ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update

pup_rdy:    call  getcurln
            glo   r8                ; check for top of file
            lbnz  pup_cont          ; if r8 is non-zero, continue
            ghi   r8          
            lbnz  pup_cont          ; if r8 is non-zero, continue

            ;-------------------------------------------------------                                  
            ; If at top of buffer, move to previous buffer  
            ;-------------------------------------------------------                                  
            call  prev_spill 
            lbdf  pup_skip          ; if no more buffers just skip
  
            call  clear_screen    ; clear the screen
            load  rf, e_state     ; get status byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to show status msg after clear
            str   rf
            
            dec   r8                ; move ack to last line  in buffer  

pup_cont:   call  window_size       ; get the window dimensions
            ghi   r9                ; get the window size in rows
            smi   2                 ; subtract 1 for status line            
            str   r2                ; save rows in M(X)
            glo   r8                ; get low byte oftop line
            sm                      ; subtract row size from from top row
            plo   r8
            ghi   r8                ; adjust high byte for borrow
            smbi  0                 ; subtract borrow from hi byte
            phi   r8          
            lbdf  pup_ok            ; if positive, then top row is valid

            ldi   0                 ; if negative, set top row to zero
            phi   r8
            plo   r8 
pup_ok:     call  setcurln          ; save the current line
            call  find_line         ; get the current line
            ldn   ra                ; get size of current line
            smi   2                 ; adjust for one past last character
            lbdf  pup_size          ; if positive, set length
            ldi   0                 ; if negative, set length to zero
pup_size:   phi   rb                ; set rb.1 to new size
            call  put_line_buffer   ; put current line in line buffer
            call  scroll_up         ; set top row to new value
pup_skip:   return                  ; top row is new current row
            endp

            ;-------------------------------------------------------
            ; Name: do_pgdn
            ;
            ; Handle the action when the Page Down key is pressed
            ; Parameters: 
            ; Uses:
            ;   r9 - window size
            ;   r8 - current line
            ; Returns:
            ;   r8 - current line 
            ;-------------------------------------------------------                                  
            proc do_pgdn
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   pdwn_rdy        ; if no change in line, ready to scroll
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


pdwn_rdy:   call  getcurln        ; get the current line
            call  window_size     ; get the window dimensions
            ghi   r9              ; get the window size in rows
            smi   2               ; subtract one for status line, another for index
            str   r2              ; save rows in M(X)
            glo   r8              ; get low byte of top line
            add                   ; add row size from to top row
            plo   r8
            ghi   r8              ; adjust high byte for carry
            adci  0               ; add carry to hi byte
            phi   r8
            call  find_line       ; check to see if line is valid
            lbnf  pdwn_ok         ; r8 is valid, so we are okay

            ;-------------------------------------------------------                                  
            ; If bottom of buffer, move to next buffer  
            ;-------------------------------------------------------
            
            load  rf, spill_cnt   ; get the spill count
            ldn   rf        
            lbz   pdwn_last       ; if no spill files, move to end
            
            call  next_spill      ; otherwise move to next spill file
            lbdf  pdwn_last       ; if no more spill files, move to end

            call  clear_screen    ; clear display  
            load  rf, e_state     ; get status byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to show status msg after clear
            str   rf            
            lbr   pdwn_ok         ; continue to set cursor to top of next buffer
            
pdwn_last:  call  find_eob        ; otherwise find the end of current buffer
            dec   r8              ; go back to last text line
            call  find_line       ; get the last line
            lbdf  pdwn_exit       ; if not found, just exit            
            
pdwn_ok:    call  setcurln        ; set the new currentline
            call  find_line       ; get the last line
            ldn   ra              ; get the line size of new current line
            smi   2               ; subtract CRLF
            lbdf  pdwn_size       
            ldi   0               ; if less than zero, set to zero
pdwn_size:  phi   rb              ; set line size for new line
            call  put_line_buffer ; put current line in line buffer
            call  scroll_down     ; calculate new row offset 
pdwn_exit:  return
            endp

            ;-------------------------------------------------------
            ; Name: do_up
            ;
            ; Handle the action when the Up Arrow key is pressed
            ; Parameters:
            ;   r8 - current line number
            ; Uses: (None)
            ; Returns:
            ;   r8 - updated line number
            ;   rb.1 - new line size
            ;-------------------------------------------------------                                  
            proc  do_up
            load  rf, line_buf      ; set pointer to line buffer
            lda   rf                ; check dirty byte, rf points to string
            lbz   up_rdy            ; if no change in line, ready to move cursor
            call  update_line       ; update line in txt buffer
            dec   rf                ; clear dirty byte
            ldi   0                 ; in line buffer
            str   rf                ; after update


up_rdy:     glo   r8                ; check for top of file
            lbnz  up_cont           ; if r8 is non-zero, continue
            ghi   r8          
            lbnz  up_cont           ; if r8 is non-zero, continue

            ;-------------------------------------------------------                                  
            ; If at top of buffer, move to previous buffer  
            ;-------------------------------------------------------                                  
            call  prev_spill 
            lbdf  up_skip           ; if no more buffers just skip
  
            call  clear_screen      ; clear the screen
            load  rf, e_state     ; get status byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to show status msg after clear
            str   rf
            
            call  find_eob          ; find the end of previous buffer                      
              
up_cont:    dec   r8                ; move current line up one
            call  setcurln          ; save current line in memory
            call  find_line         ; point ra to new line
            ldn   ra                ; get size of new line (including CRLF)
            smi   2                 ; adjust for one past last character
            lbdf  up_size           ; if positive, set the length
            ldi   0                 ; if negative, set length to zero
up_size:    phi   rb                ; set rb.1 to new size
            call  put_line_buffer   ; put current line in line buffer
            call  scroll_up         ; update row offset
up_skip:    return
            endp
            
            ;-------------------------------------------------------
            ; Name: do_down
            ;
            ; Handle the action when the Down Arrow key is pressed
            ; Parameters:
            ;   r8 - current line number
            ; Uses:
            ;   r9 - number of rows in text buffer
            ; Returns:
            ;   r8 - updated line number
            ;-------------------------------------------------------                                  
            proc  do_down
            push  r9                  ; save scratch register
            
            load  rf, line_buf        ; set pointer to line buffer
            lda   rf                  ; check dirty byte, rf points to string
            lbz   dwn_rdy             ; if no change, ready to move cursor
            call  update_line         ; update line in txt buffer
            dec   rf                  ; clear dirty byte
            ldi   0                   ; in line buffer
            str   rf                  ; after update

            
dwn_rdy:    call  get_num_lines       ; get the maximum lines in r9
            load  rf, spill_cnt       ; get the spill count
            ldn   rf
            lbz   dwn_chk             ; if no buffers, allow for one past limit
            str   r2                  ; else spill count in in M(X)

            load  rf, fbuf_idx        ; get the current buffer index
            ldn   rf                  ; to check against current spill count
            sm                        ; Ae already at the last buffer?
            lbdf  dwn_chk             ; then allow down to go one past limit

            dec   r9                  ; otherwise, line limit is one less 
dwn_chk:    call  getcurln            ; get current line index
            sub16 r8,r9               ; check current line against limit
            lbnf  dwn_move            ; if current line < number lines, move down                
              
            ;-------------------------------------------------------                                  
            ; If bottom of buffer, move to next buffer  
            ;-------------------------------------------------------                        

            load  rf, spill_cnt       ; get the spill count
            ldn   rf        
            lbz   dwn_skip            ; if no spill files, don't move
                                  
            call  next_spill          ; otherwise move to next spill file 
            lbdf  dwn_skip            ; if no more spill files, don't move

            call  clear_screen        ; clear display      
            load  rf, e_state         ; get status byte
            ldn   rf
            ori   STATUS_BIT          ; set bit to show status msg after clear
            str   rf                    
            lbr   dwn_set             ; set cursor to top line of next buffer 

dwn_move:   call  getcurln
            inc   r8                  ; move current line down one
            call  setcurln            ; save current line in memory
            call  find_line           ; point ra to new line
dwn_set:    ldn   ra                  ; get size of new line (including CRLF)
            smi   2                   ; adjust for one past last character
            lbdf  dwn_size            ; if positive set the length      
            ldi   0                   ; if negative, set length to zero
dwn_size:   phi   rb                  ; set rb.1 to new size
            call  put_line_buffer     ; put current line in line buffer
            call  scroll_down         ; update row offset
            
dwn_end:    pop   r9                  ; restore current line
            return

dwn_skip:   call  getcurln            ; restore r8 
            ldi   0                   
            phi   rb                  ; set length to zero
            plo   rb                  ; set current char position to zero
            lbr   dwn_end             ; and exit            
            endp

            ;-------------------------------------------------------
            ; Name: do_left
            ;
            ; Handle the action when the Left Arrow key is pressed
            ;
            ; Parameters:
            ;   rb.0 - current character position
            ; Uses: (None)
            ; Returns:
            ;   rb.0 - updated character position
            ;-------------------------------------------------------                                  
            proc  do_left
            glo   rb            ; get current character column
            lbz   lft_up        ; move up if at left-most column
            dec   rb            ; update character column
            call  scroll_left   ; scroll if needed, update cursor position
            lbr   lft_exit

lft_up:     glo   r8            ; check for top of file
            lbnz  lft_up2       ; if r8 is non-zero, continue
            ghi   r8          
            lbz   lft_exit      ; if r8 = 0, then don't move up

lft_up2:    ldi   MAX_LINE      ; set to one past maximum column position
            plo   rb            ; set char position to maximum
            call do_up          ; move up to end of previous line
lft_exit:   return
            endp
            
            ;-------------------------------------------------------
            ; Name: do_rght
            ;
            ; Handle the action when the Right Arrow key is pressed
            ;
            ; Parameters:
            ;   rb.1 - line size
            ;   rb.0 - current character position
            ; Uses:
            ; Returns:
            ;   rb.0 - updated character position
            ;-------------------------------------------------------                                                
            proc do_rght
            ghi   rb            ; get the line size
            lbz   rght_exit     ; do nothing if empty line
            str   r2            ; save line size in M(X)
            glo   rb            ; get the current position
            sm                  ; subtract line size from char position
            lbdf  rght_dwn      ; move to beginning of next line
            glo   rb
            smi   MAX_LINE      ; if at maximum column, move down
            lbdf  rght_dwn
            inc   rb            ; otherwise increment char position
            call  scroll_right  ; scroll if needed, and adjust cursor              
rght_exit:  return
rght_dwn:   ldi   0             ; move to beginning column
            plo   rb
            call  do_down       ; move down to next line
            return              ; and exit
            endp

            ;-------------------------------------------------------
            ; Name: do_top
            ;
            ; Move to the top of current buffer or previous buffer
            ;-------------------------------------------------------                                                
            proc  do_top
            push  rf              ; save register used

            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   top_rdy         ; if no change in line, ready to move to top
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


top_rdy:    load  rf, e_state     ; set refresh bit
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     
            str   rf

            call  getcurln
            glo   r8                ; check for top of file
            lbnz  top_cont          ; if r8 is non-zero, continue
            ghi   r8          
            lbnz  top_cont          ; if r8 is non-zero, continue

            ;-------------------------------------------------------                                  
            ; If at top of buffer, move to previous buffer  
            ;-------------------------------------------------------                                  
            call  prev_spill 
            lbdf  top_skip          ; if no more buffers just skip
  
            call  clear_screen      ; clear the screen
            load  rf, e_state     ; get status byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to show status msg after clear
            str   rf
            
top_cont:   ldi   0                 ; set top row to zero
            phi   r8
            plo   r8 
            call  set_row_offset    ; set row offset for the top of screen            
            call  setcurln          ; save the current line
            call  find_line         ; get the current line
            ldn   ra                ; get size of current line
            smi   2                 ; adjust for one past last character
            lbdf  top_size          ; if positive, set length
            ldi   0                 ; if negative, set length to zero
top_size:   phi   rb                ; set rb.1 to new size
            call  put_line_buffer   ; put current line in line buffer
            call  scroll_up         ; set top row to new value
top_skip:   ldi   0                 ; set char position to far left
            plo   rb     
            call  scroll_left       
            call  home_cursor       ; set cursor position for home
            pop   rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_bottom
            ;
            ; Move to bottom of current buffer or next buffer
            ;-------------------------------------------------------                                                
            proc  do_bottom
            push  rf                ; save register used
          
            load  rf, line_buf      ; set pointer to line buffer
            lda   rf                ; check dirty byte, rf points to string
            lbz   db_rdy            ; if no change in line, ready to move to bottom
            call  update_line       ; update line in txt buffer
            dec   rf                ; clear dirty byte
            ldi   0                 ; in line buffer
            str   rf                ; after update

db_rdy:     load  rf, e_state       ; set refresh bit
            ldn   rf                ; get editor state byte
            ori   REFRESH_BIT     
            str   rf
            
            call  get_num_lines     ; get the maximum lines
            dec   r9                ; line index is one less than number of lines
            call  getcurln          ; get current line
            sub16 r8,r9             ; check current line against limit
            lbnf  db_move           ; if current line < number lines, just move down        
            
            ;-------------------------------------------------------                                  
            ; If bottom of buffer, move to next spill file  
            ;-------------------------------------------------------                                  
            call  next_spill 
            lbdf  db_exit           ; if no more spill files, don't move
            
            call  clear_screen      ; clear display

            load  rf, e_state       ; get status byte
            ldn   rf
            ori   STATUS_BIT        ; set status bit to redraw after clear
            str   rf  
            
db_move:    call  get_num_lines     ; get total number of lines in r8
            dec   r9                ; line index is one less than number of lines
            copy  r9,r8             ; set current line to last line
            call  setcurln          ; save the current line
            call  find_line         ; get the current line
db_set:     ldn   ra                ; get size of current line
            smi   2                 ; adjust for one past last character
            lbdf  db_size           ; if positive, set length
            ldi   0                 ; if negative, set length to zero
db_size:    phi   rb                ; set rb.1 to new size
            call  put_line_buffer   ; put current line in line buffer
            ghi   rb                ; set char position to end of last line
            plo   rb  
            call  scroll_down       ; set top row to new value

db_exit:    pop   rf
            return 
            endp
