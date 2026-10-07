; -------------------------------------------------------------------
; Text key handlers for the kilo editor
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
;                  Key Handlers for Basic Text Keys               ***
; *******************************************************************

            ;-------------------------------------------------------
            ; Name: do_del
            ; Handle the action when the Delete key is pressed
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current cursor position
            ; Uses:
            ;  rd - destination pointer
            ; Returns:
            ;  DF = 0, line updated (refresh line)
            ;  DF = 1, line deleted (refresh screen)
            ;  rb.1 - updated line length
            ;-------------------------------------------------------                                  
            proc  do_del
            push  rf
            push  rd
            
            ghi   rb              ; get the line size
            lbz   del_line        ; delete line, if empty
            str   r2              ; save line size in M(X)
            glo   rb              ; get the current position
            sm                    ; subtract line size from char position
            lbdf  del_join        ; delete at end joins next line

            load  rf, line_buf    ; set pointer to line buffer
            ldi   $FF             ; set dirty flag to true
            str   rf
            inc   rf              ; move to string

            glo   rb
            str   r2              ; save cursor position in M(X)
            glo   rf              ; get low byte of buffer pointer
            add                   ; add offset to buffer pointer
            plo   rf
            ghi   rf              ; get high byte of buffer
            adci   0              ; add carry into high byte
            phi   rf              ; rf points to character in buffer
            
            copy  rf, rd          ; set destination pointer to current location
            inc   rf              ; move buffer pointer to next byte

del_move:   lda   rf              ; get next character
            str   rd              ; copy into previous position in buffer
            inc   rd              ; move to next character
            lbnz  del_move        ; keep going until null copied
            
            ghi   rb              ; get the current line length
            smi   1               ; subtract one for deleted character
            phi   rb              ; update length

del_okay:   clc                   ; clear DF flag for line update
            lbr   del_exit
            
del_line:   load  rf, e_state     ; get editor state byte
            ldn   rf
            ani   MODE_BIT        ; check insert/overwrite mode
            lbnz  del_okay        ; in overwrite don't delete empty lines
            call  do_kill         ; delete the current line
            lbdf  del_okay        ; if no line deleted at end of file, just return
del_update: stc                   ; set DF flag for update
            lbr   del_exit
            
del_join:   load  rf, e_state     ; get editor state byte
            ldn   rf
            ani   MODE_BIT        ; check insert/overwrite mode
            lbnz  del_okay        ; in overwrite mode, don't join lines
            call  do_join
            lbr   del_update
               
del_exit:   pop   rd 
            pop   rf
            return
            endp
            
            ;-------------------------------------------------------
            ; Name: do_backspace
            ;
            ; Handle the action when the Backspace key is pressed
            ;-------------------------------------------------------                                                
            proc do_backspace
            glo   rb            ; get current character column
            lbz   bs_up         ; move up if at left-most column
            
            dec   rb            ; update character column
            call  do_del        ; delete character at new position
            call  scroll_left   ; scroll if needed, update cursor position
            lbr   bs_exit

bs_up:      glo   r8            ; check for top of file
            lbnz  bs_up2        ; if r8 is non-zero, continue
            ghi   r8          
            lbz   bs_exit       ; if r8 = 0, then don't move up

bs_up2:     ghi   rb            ; check line size
            lbnz  bs_up3        ; if non-zero, just move up to end of next line
            load  rf, e_state   ; get editor state
            ldn   rf    
            ani   MODE_BIT      ; check for insert or overwrite mode
            lbnz  bs_up3        ; in overwrite mode, don't delete the empty line
            call  do_kill       ; in insert mode, delete empty line
bs_up3:     ldi   MAX_LINE      ; set to one past maximum column position
            plo   rb            ; set char position to maximum
            call  do_up         ; move up to end of previous line

bs_exit:    return              ; for now do nothing at beginning of line
            endp


            ;-------------------------------------------------------
            ; Name: do_enter
            ;
            ; Handle the action when the Enter key is pressed
            ;-------------------------------------------------------                                                
            proc  do_enter
            push  rf            ; save register
            load  rf, e_state   ; get editor state
            ldn   rf    
            ani   MODE_BIT      ; check for insert or overwrite mode
            lbnz  ent_over      ; in overwrite mode, enter moves down to next line
            
            call  do_split      ; in insert mode, enter behaves like split line
            lbdf  ent_ins       ; if line was inserted, just exit
                        
ent_over:   call  do_down       ; move down to next line
ent_ins:    ldi   0             ; move to beginning column
            plo   rb
            pop   rf            ; restore registers
            return         
            endp

            ;-------------------------------------------------------
            ; Name: do_tab
            ; Handle the action when the Tab key is pressed
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current cursor position
            ; Uses:
            ;  rf - buffer pointer
            ;  rf.0 - character counter
            ;  r9 - scratch register
            ; Returns:
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                                                
            proc do_tab
            push  rf              ; save regsters used
            push  r9              
            glo   rb              ; get the current position
            adi   4               ; add 4 to move past current tab stop
            ani   $FC             ; mask sum to snap to next tab stop
            plo   r9              ; save in scratch register
            str   r2              ; save tab value in M(X)
            ldi   MAX_COL         ; check with the maximum column position
            sm
            lbnf  tab_exit        ; don't move past maximum line length
            
            load  rf, e_state     ; get editor state byte
            ldn   rf              
            ani   MODE_BIT        ; check insert/overwrite mode 
            lbnz  tab_over        ; in overwrite mode, don't insert spaces
            
            glo   rb              ; get current position
            str   r2              ; save at  M(X)
            glo   r9              ; get next tab stop
            sm                    ; calculate characters to next tab stop (n)
            lbz   tab_over        ; should never be zero, but check just in case 
            
            phi   r9              ; save n for inserting spaces
            ghi   rb              ; get line length
            str   r2              ; save at M(X) 
            ghi   r9              ; add n to line length
            add                   ; to get length after inserting tab
            sdi   MAX_COL         ; subtract new line length from column limit
            lbnf  tab_move        ; if new length goes past column limit, just move cursor
            
            ghi   r9              ; get characater count
            plo   rf              ; set rf as a counter
            ldi   ' '             ; set up space as character to insert
            plo   r9           
               
tab_ins:    call  do_typein       ; insert a spaces to move towards new tabstop
            dec   rf              ; count down
            glo   rf              ; check counter
            lbnz  tab_ins         ; get going until n spaces inserted
            lbr   tab_exit        ; and exit  
              
tab_over:   glo   r9              ; get next tab stop
            str   r2              ; save at M(X)
            ghi   rb              ; get line length
            sm                    ; subtract next tab stop from line length
            lbdf  tab_move        ; if (line length >= tab stop), just move cursor             
            ghi   rb              ; get line length
            sd                    ; get difference (tab stop - length)
            call  pad_line        ; pad line with spaces to tab stop
tab_move:   glo   r9              ; get next tab stop
            plo   rb              ; update cursor column
            call  scroll_right  
tab_exit:   pop   r9              ; restore registers
            pop   rf              
            return
            endp
            
            ;-------------------------------------------------------
            ; Name: do_bktab
            ; Handle the action when the Tab key is pressed
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current character position
            ; Uses: (None)
            ; Returns:
            ;  rb.0 - updated character position
            ;-------------------------------------------------------                                                
            proc do_bktab
            glo   rb            ; get the character column value
            smi   1             ; subtract 1 to move before current tab stop
            lbnf  btab_end      ; if negative, ignore back tab
            ani   $FC           ; mask sum to snap to previous tab stop
            plo   rb            ; update character position
            call  scroll_left   ; update position 
btab_end:   return
            endp

            ;-------------------------------------------------------
            ; Name: do_mode
            ;
            ; Toggle the editor mode, insert or overwrite
            ;
            ; Parameters: (None)
            ; Uses: 
            ;   rf - buffer pointer
            ; Returns: (None)
            ;-------------------------------------------------------                      
            proc  do_mode
            push  rf              ; save register
            load  rf, e_state     ; get editor state byte  
            ldn   rf            
            xri   MODE_BIT        ; toggle mode mode bit
            str   rf
            call  kilo_status     ; update status message for new mode
            call  prt_status
            call  get_cursor      ; restore cursor
            call  move_cursor     ; position cursor
            pop   rf              ; restore register
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_typeover
            ; Type a printable character overwriting the existing
            ; character in the line
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current cursor position
            ;  r9.0 - character to type
            ; Uses:
            ; Returns:
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                                                
            proc do_typeover
            push  rf
            glo   rb              ; check character position
            smi   MAX_LINE        ; check if one past max column
            lbdf  to_stay         ; if past, don't type anything

            load  rf, line_buf    ; set pointer to line buffer
            ldi   $FF             ; set dirty flag to true
            str   rf
            inc   rf 

            glo   rb
            str   r2              ; save cursor position in M(X)
            glo   rf              ; get low byte of buffer pointer
            add                   ; add offset to buffer pointer
            plo   rf
            ghi   rf              ; get high byte of buffer
            adci   0              ; add carry into high byte
            phi   rf              ; rf points to character in buffer
            glo   r9              ; get character from scratch register
            str   rf              ; update character in buffer
            
            ghi   rb              ; get the current line length
            str   r2              ; save in M(X)
            glo   rb              ; check current cursor < line length
            sm                    ; did we write over eol bytes? (DF = 1 means yes)
            lbnf  to_done         ; if not, we are okay
            
            inc   rf              ; write CRLF,0 after last character
            ldi   13              ; write CR (13)
            str   rf
            inc   rf
            ldi   10              ; write LF (10)
            str   rf
            inc   rf
            ldi   0               ; write NULL
            str   rf
            
            ghi   rb              ; check line length
            smi   MAX_LINE        ; for max length
            lbdf  to_done         ; don't go past maximum
            
            ghi   rb              ; otherwise add one to line length
            adi   1
            phi   rb  

to_done:    glo   rb              ; check character position
            smi   MAX_COL         ; maximum column position
            lbdf  to_stay         ; if >= max, don't increment or move cursor

            inc   rb              ; move to next char position in line            
            call  scroll_right    ; scroll if needed, and adjust cursor              
            lbr   to_exit         
            
to_stay:    load  rf, eol_msg     ; show max line size message
            call  set_status
            call  prt_status
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor

            load  rf, e_state    ; get editor state byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after eol msg
            str   rf

to_exit:    pop   rf
            return
              ; Warning message for when line length reaches limit 
eol_msg:      db  '* Maximum Line Length *',0
            public eol_msg
            endp  

            ;-------------------------------------------------------
            ; Name: do_typein
            ; Type a printable character inserting the character 
            ; into the line
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current cursor position
            ;  r9.0 - character to type
            ; Uses:
            ;  rf - buffer pointer
            ;  rd - destination pointer
            ; Returns:
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                                                
            proc  do_typein
            push  rf              ; save registers
            push  rd

            ghi   rb              ; check line length
            smi   MAX_LINE        ; with maximum line length
            lbdf  ti_skip         ; if at limit, don't insert more characters

            load  rf, line_buf    ; set pointer to line buffer
            ldi   $FF             ; set dirty flag to true
            str   rf
            inc   rf 
            
            ;---- move buffer pointer to character position            
            glo   rb              ; get character position 
            str   r2              ; save cursor position in M(X)
            glo   rf              ; get low byte of buffer pointer
            add                   ; add offset to buffer pointer
            plo   rf
            ghi   rf              ; get high byte of buffer
            adci   0              ; add carry into high byte
            phi   rf              ; rf points to character in buffer
            copy  rf, rd          ; copy rf into destination pointer
            
ti_fndend:  lda   rf              ; move rf to one past the end of string
            lbnz  ti_fndend

ti_shift:   str   rf              ; save value at one past original location
            dec   rf              ; move rf back to original location
            glo   rd              ; check if we moved last character
            str   r2              ; at rf = rd
            glo   rf
            sm                    ; if rf.0 != rd.0, continue moving characters
            lbnz  ti_cont
            
            ghi   rd              ; check high byte if low bytes are equal
            str   r2
            ghi   rf  
            sm
            lbz   ti_moved        ; if rd = rf, we are done moving characters
            
ti_cont:    dec   rf              ; back rf up to next character to move        
            lda   rf              ; load next character, and point to n+1
            lbr   ti_shift        ; continue shifting characters     
            
ti_moved:   glo   r9              ; get character from scratch register
            str   rd              ; insert character in buffer
                                  
            ghi   rb              ; add one to line length
            adi   1
            phi   rb  

            inc   rb              ; move to next char position in line            
            call  scroll_right    ; scroll if needed, and adjust cursor              
            lbr   ti_exit
            
            ;---- if at the max column position or max length don't insert 
ti_skip:    load  rf, eol_msg     ; show max line size warning message
            call  set_status
            call  prt_status
            call  get_cursor        ; restore cursor after status message update
            call  move_cursor

            load  rf, e_state     ; get editor state byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after eol msg
            str   rf
            
            call  do_typeover     ; instead type over 
            
ti_exit:    pop   rd              ; restore registers
            pop   rf
            return
            endp  
    
            
