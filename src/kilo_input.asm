; -------------------------------------------------------------------
; Input and Confirmation functions for the kilo editor
; -------------------------------------------------------------------
; Copyright 2025 by Gaston Williams
; -------------------------------------------------------------------

#include include/ops.inc
#include include/bios.inc
#include include/kernel.inc
#include include/kilo_def.inc

            extrn   hlp_file
            extrn   hlp_page
            extrn   hlp_line
            extrn   hlp_curs

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
; ***                  Input Fuctions                             ***
; *******************************************************************

            ;-------------------------------------------------------
            ; Name: do_confirm
            ;
            ; Display a prompt and then read a key to check if 
            ; y or Y for a yes response was pressed.
            ; Parameters: (None) 
            ; Uses: 
            ;   rf - pointer to prompt string
            ; Returns: 
            ;   DF = 1, a 'Y' or 'y' was pressed
            ;   DF = 0, any other key was pressed      
            ;-------------------------------------------------------       
            proc  do_confirm        
            call  set_status
            call  prt_status      
                        
            call  get_key       ; get a keyvalue response
            
            stxd                ; save char on stack
            call  kilo_status   ; restore status message
            call  prt_status    ; update status message
            call  get_cursor    ; restore cursor after questions
            call  move_cursor   ; position cursor
            irx                 ; get response from stack
            ldx 
            smi   'Y'           ; check for positive response
            lbz   dc_yes
            smi   $20           ; lower case letters are 32 characters from upper case
            lbz   dc_yes
            ldx                 ; get character again from M(X)
            smi   27            ; check for escape character (ANSI sequence)
            lbnz  dc_no 
            
            call  get_key       ; eat ansi sequences
            
            smi   '['           ; check for csi escape sequence
            lbnz  dc_no         ; Anything but <Esc>[ is not ANSI, so done
                    
            call  get_key       ; eat next character
            
            smi   'A'           ; check for 3 character sequence (arrows)
            lbdf  dc_no         ; A and above are 3 character, so we are done
            
            call  get_key       ; eat closing ~ for 4 char sequence (PgUp, PgDn, Home, End)

dc_no:      clc                 ; DF = 0, means No response
            lbr   dc_exit
dc_yes:     stc                 ; DF = 1, means Yes response
dc_exit:    return
            endp
            
            
            ;-------------------------------------------------------
            ; Name: do_input
            ;
            ; Display a prompt and read keys for user input 
            ; until a non-printable key or a limit is reached.
            ;
            ; Parameters: 
            ;   rf - pointer to prompt string
            ;   rc.0 - number of keys to read
            ; Uses: 
            ;   rd - destination buffer
            ; Returns: 
            ;   DF = 1, input entered
            ;   DF = 0, no input
            ;   D  = last character entered, (null for none)
            ;-------------------------------------------------------  
            proc  do_input                                
            push  rd            ; save registers
            push  rb
            
            copy  rf, rb        ; save copy of pointer to input message
            load  rd, work_buf  ; set destination to working buffer
            ldi   0
            str   rd            ; set buffer to empty string
            
di_read:    copy  rb, rf        ; restore input prompt from copy
            call  set_input     ; show prompt with current input
            call  prt_status      

            call  get_key       ; get a key value response

            str   r2            ; save at M(X) 
            smi   32            ; check for control character (below space)
            lbnf  di_ctrl       ; check for ANSI seq to prevent stray characters
            
            ldx                 ; get character
            smi   127           ; check for DEL or non-ascii (above DEL)
            lbdf  di_end
            ldx                 ; get character
            str   rd            ; save in buffer
            inc   rd            ; save in buffer
            ldi   0             ; put null at end of input
            str   rd
            dec   rc            ; count down 
            glo   rc
            lbnz  di_read       ; keep going until count exhausted
            lbr   di_end        

di_ctrl:    ldx                 ; get character
            smi   27            ; check for escape sequence
            lbnz  di_end        ; any other control char is fine
            call  get_key       ; get next character in escape seqence
            smi   '['           ; check for ANSI csi sequence
            lbnz  di_end        ; anything else is two chracter escape
            call  get_key       ; get next character of ANSI sequence
            smi   'A'           ; check for 3 character sequence
            lbdf  di_end        ; A and above are 3 character sequences
            call  get_key       ; else, get closing ~ for 4 char sequence
            
di_end:     call  get_cursor    ; restore cursor after questions
            call  move_cursor   ; position cursor
                
            load  rd, work_buf  ; set buffer back to work buffer               
            ldn   rd            ; get first character
            plo   re            ; save character in scratch register
            lbz   di_none       ; if null, no input
            stc                 ; DF = 1, for input
            lbr   di_exit
            
di_none:    load  rf, e_state   ; restore status msg after no input
            ldn   rf
            ori   STATUS_BIT    ; set bit for status msg update
            str   rf
            clc                 ; DF = 0, for no input
di_exit:    pop   rb            ; restore registers
            pop   rd
            glo   re            ; put last character in D
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_quit
            ;
            ; Quit, check the dirty flag and confirm before exit.
            ; Parameters: (None) 
            ; Uses: 
            ;   rf - buffer pointer
            ; Returns: 
            ;   DF = 1, don't exit
            ;   DF = 0, exit the program      
            ;-------------------------------------------------------
            proc  do_quit
            push  rf              ; save register used

            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dq_rdy          ; if no change in line, ready to quit
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


dq_rdy:     load  rf, e_state     ; get editor state byte  
            ldn   rf
            ani   DIRTY_BIT       ; check the dirty bit
            lbnz  dq_ask          ; if changes, ask before exit

            clc                   ; if not dirty, just exit  
            lbr   dq_exit
            
dq_ask:     load  rf, warn_str    ; set the status to the save file warning
            call  do_confirm      
            lbdf  dq_sure
            ldi   1               ; if no quit, exit with DF = 1
            stxd                  ; save No Quit DF value on stack
            lbr   dq_setdf        ; restore cursor after prompt

dq_sure:    load  rf, sure_str    ; make sure to quit without saving
            call  do_confirm
            lbdf  dq_yesquit      ; if confirmed twice, quit without saving     
            ldi   1               ; save No Quit DF Value on stack             
            stxd 
            lbr   dq_setdf
            
dq_yesquit: ldi   0               ; save Quit DF value on stack
            stxd 
dq_setdf:   irx                   ; get DF from stack
            ldx 
            shr                   ; shift value into DF
dq_exit:    pop   rf
            return

warn_str:     db 'Unsaved Changes!  Exit without Saving (Y/N)?', 0
sure_str:     db 'Are you sure (Y/N)?',0
            endp
            
            ;-------------------------------------------------------
            ; Name: do_change
            ; Change the filename to a new name entered by the user.
            ;
            ; Parameters:
            ; Uses:
            ;  rf - buffer pointer
            ;  rd - destination ptr
            ;  rc.0 - character limit
            ;  r9 - scratch register
            ; Returns:
            ;  DF = 0, name changed
            ;  DF = 1, name not changed
            ;-------------------------------------------------------                                                
            proc  do_change
            push  rf              ; save registers
            push  rd
            push  rc
            push  r9               
            
            ldi   0               ; set up character count
            phi   rc
            ldi   MAX_FNAME       ; up to 19 characters in filename
            plo   rc
            load  rf, dc_prmpt    ; set prompt to enter new file name
            load  rd, work_buf  ; point to working buffer for input            
            call  do_input        ; prompt user for line number
            lbnf  dc_badfn        ; if nothing entered, bad name
            
            load  rf, work_buf    ; validate name in working buffer
cd_chkfn:   lda   rf              ; get next character 
            lbz   dc_change       ; if reach end of string, valid name
            call  is_fnchar       ; is this a valid filename character?
            lbdf  cd_chkfn        ; DF =1, means valid, keep checking
            lbr   dc_badfn        ; otherwise, bad character in filename
            
dc_change:  load  rf, work_buf    ; source is new filename in work buffer 
            load  rd, fname       ; destination is fname buffer in kilo_file
            call  f_strcpy        ; copy new file name into fname buffer
            call  set_dirty       ; set the dirty flag to save with name change
            call  get_cursor      ; restore cursor after prompt message
            call  move_cursor
            clc                   ; Set DF = 0 for success
            lbr   dc_exit         ; and exit

dc_badfn:   load  rf, dc_invalid  ; show invalid file name message
            call  set_status      ; in the status bar
            call  prt_status      
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor
            stc                   ; DF = 1, means error

dc_exit:    pop   r9
            pop   rc
            pop   rd
            pop   rf
            return 
dc_prmpt:     db 'Enter new file name: ',0
dc_invalid:   db 'Invalid file name. File not saved.',0            
            endp 

            ;-------------------------------------------------------            
            ; Name: do_find
            ; Find a string of text entered by the user.
            ;
            ; Parameters:
            ;  rb.0 - current character position
            ;  r8 -   current row
            ; Uses:
            ;  rc.0 - character limit
            ;  r9 - scratch register
            ; Returns:
            ;  DF = 1, string found
            ;  DF = 0, not found
            ;  r8   - updated line position
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                                                
            proc  do_find
            push  rf              ; save registers
            push  rd
            push  rc
            push  r9               

            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   df_rdy          ; if no change in line, ready to find string
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


df_rdy:     ldi   0               ; set up character count
            phi   rc
            ldi   MAX_TARGET      ; up to 40 characters in target
            plo   rc
            load  rf, df_prmpt    ; set prompt to enter search string
            call  do_input        ; prompt user to enter string
            lbnf  df_nosrch       ; if nothing entered, don't do search
            
            load  rf, work_buf    ; set source string to input
            load  rd, df_target   ; point destination to target buffer            
            call  f_strcpy        ; copy string into target buffer
              
            copy  r8, r9          ; save current line in case not found
            glo   rb              ; get character position in case not found
            phi   rc              ; save character position in rc.1
            
            load  rd, df_target   ; make sure rd points to target

df_next:    call  find_string     ; find the string in buffer
            lbdf  df_found 

            load  rf, spill_cnt   ; get the spill count
            ldn   rf
            lbnz  df_ask2        

df_ask:     load  rf, df_redo     ; set prompt to try again
            call  do_confirm
            lbnf  df_none         ; if negative, don't search again
            ldi   0
            phi   r8              ; set current line to zero
            plo   r8
            plo   rb              ; set cursor position to Zero
            call  find_string     ; search from the top
            lbdf  df_found
            lbr   df_ask          ; show not found message
            
            
df_ask2:    load  rf, df_nbuff    ; set prompt to try next buffer
            call  do_confirm
            lbnf  df_none         ; if negative, don't search again
            
            call  next_spill
            lbnf  df_nbsrch       ; if next buffer available, search it
            
            load  rf, df_redo     ; ask if we want to reset to top
            call  do_confirm
            lbnf  df_none         ; if negative, don't search again
            
            call  reset_spill     ; reset to first spill file
            
df_nbsrch:  ldi   0               
            phi   r8              ; set current line to zero
            plo   r8
            plo   rb              ; set cursor position to Zero
            plo   r9              ; clear saved position
            phi   r9
            phi   rc
            call  clear_screen    ; clear screen
            call  refresh_screen  ; r8, and rb.0 are reset
            
            call  find_string     ; search from the top
            lbdf  df_found
            lbr   df_ask2         ; show not found message
            
df_found:   load  rd, df_target   ; set destination to target string            
            call  found_screen    ; recalculate row and column offsets
                        
            call  o_inmsg
               db 27,'[2J',0      ; erase display and show found string        
            call  refresh_screen  ; r8, and rb.0 are set found string
            call  get_cursor      ; get the cursor
            call  move_cursor     ; position cursor at found string
            call  o_inmsg
              db 27,'[30;43m',0   ; set colors to black on yellow text
            load  rf, df_target   ; print target string over found text 
            call  o_msg           ; to highlight found string
            call  o_inmsg
              db  27,'[0m',0      ; set text back to normal     
            load  rf, df_again    ; set prompt to search again
            call  do_confirm
            lbnf  df_done         ; if negative, don't search again

            inc   rb              ; otherwise, move to next character position
            lbr   df_next         ; and search for next string occurence
                          
df_done:    load  rf, e_state     ; get editor state byte
            ldn   rf              
            ori   REFRESH_BIT     ; set refresh bit
            str   rf

            stc
            lbr   df_exit

df_none:    copy  r9, r8          ; restore current line
            ghi   rc              ; restore character position
            plo   rb
df_nosrch:  clc                   ; DF = 0, not found 
df_exit:    pop   r9
            pop   rc
            pop   rd
            pop   rf
            return 
df_prmpt:     db 'Enter text to find: ',0
df_again:     db 'Found. Search again (Y/N)?',0
df_redo:      db 'Not Found. Search again from the top (Y/N)?',0            
df_nbuff:     db 'Not Found. Search next buffer (Y/N)?',0            
df_target:    ds MAX_TARGET+1    
              db 0
            endp 
            

            ;-------------------------------------------------------
            ; Name: do_where
            ; Show the character position in the file
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current character position
            ;  r8 -   current row
            ; Uses: 
            ;  r9 -   total number of lines
            ; Returns:
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                                                
            proc  do_where
            push  rf              ; save registers
            push  rd
            push  r9
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dw_rdy          ; if no change in line, ready to show location
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


            
dw_rdy:     ldi   0               ; set up rd for converting column index
            phi   rd
            glo   rb              ; copy column index for conversion
            plo   rd
            inc   rd              ; add one to index
            load  rf, num_buf     ; put result in number buffer
            call  f_uintout       ; convert to integer ascii string
            ldi   0               ; make sure null terminated
            str   rf              
            
            load  rd, work_buf    ; set destination pointer to work buffer 
            load  rf, dw_coltxt    
dw_hdr:     lda   rf              ; copy column header into msg buffer
            lbz   dw_cnumbr         
            str   rd
            inc   rd
            lbr   dw_hdr

dw_cnumbr:  load  rf, num_buf
dw_cnum:    lda   rf              ; copy column number into msg buffer
            lbz   dw_sp_1         ; check for spill buffers
            str   rd
            inc   rd
            lbr   dw_cnum
            
dw_sp_1:    load  rf, spill_cnt   ; get the spill count
            ldn   rf        
            lbz   dw_ln_sp        ; if no spill files, line separator

dw_row:     load  rf, dw_rwtxt      
dw_row2:    lda   rf              ; copy row label into msg buffer
            lbz   dw_rnumbr       ; then add row number
            str   rd
            inc   rd
            lbr   dw_row2

dw_rnumbr:  push  rd              ; save msg buffer pointer
            call  getcurln        ; get current line index
            copy  r8, rd          ; copy row index for conversion to ascii        
            inc   rd              ; add one to index to get 1 based number
            load  rf, num_buf     
            call  f_uintout       ; convert to integer ascii string
            ldi   0               ; make sure null terminated
            str   rf              
            pop   rd              ; restore msg buffer pointer
            
            load  rf, num_buf     
dw_rnum:    lda   rf              ; copy row number into msg buffer
            lbz   dw_buffer       ; show spill buffer message next      
            str   rd
            inc   rd
            lbr   dw_rnum   

            
dw_buffer:  load  rf, dw_bftxt      
dw_buf:     lda   rf              ; copy spill buffer label into msg buffer
            lbz   dw_bnumbr       ; then add buffer number
            str   rd
            inc   rd
            lbr   dw_buf

dw_bnumbr:  push  rd              ; save msg buffer pointer
            ldi   0               ; clear rd
            phi   rd
            load  rf, fbuf_idx    ; get the current spill buffer index
            ldn   rf                  
            plo   rd
            inc   rd              ; add one to index to get 1 based number
            load  rf, num_buf     
            call  f_uintout       ; convert to integer ascii string
            ldi   0               ; make sure null terminated
            str   rf              
            pop   rd              ; restore msg buffer pointer
           
            load  rf, num_buf     
dw_bnum:    lda   rf              ; copy buffer number into msg buffer
            lbz   dw_ln_sp2       ; add line after to row message        
            str   rd
            inc   rd
            lbr   dw_bnum   

dw_ln_sp:   ldi   ','             ; if no spill buffers, separate with comma
            str   rd
            inc   rd
            ldi   ' '
            str   rd
            inc   rd 
            lbr   dw_ln           ; print the line number
            
dw_ln_sp2:  ldi   ' '             ; put space after spill buffer number
            str   rd
            inc   rd
            ldi   '('             ; and parenthesis to indicate computed line
            str   rd
            inc   rd

dw_ln:      load  rf, dw_lntxt      
dw_line:    lda   rf              ; copy line label into msg buffer
            lbz   dw_lnumbr       ; then add line number
            str   rd
            inc   rd
            lbr   dw_line

dw_lnumbr:  push  rd              ; save msg buffer pointer
            call  getcurln        ; get current line index
            copy  r8, r9          ; copy current line to convert to buffer value
            call  get_buf_line    ; convert to line value in buffer
            copy  r9, rd          ; copy index for conversion to ask        
            inc   rd              ; add one to index to get 1 based number
            load  rf, num_buf     
            call  f_uintout       ; convert to integer ascii string
            ldi   0               ; make sure null terminated
            str   rf              
            pop   rd              ; restore msg buffer pointer
            
            load  rf, num_buf     
dw_lnum:    lda   rf              ; copy line number into msg buffer
            lbz   dw_sp_2         ; check for spill buffera again        
            str   rd
            inc   rd
            lbr   dw_lnum   

dw_sp_2:    load  rf, spill_cnt   ; get the spill count
            ldn   rf        
            lbz   dw_show         ; if no spill files, we are done

            
dw_bend:    ldi   ')'             ; close parenthesis after computed line number
            str   rd
            inc   rd
        
dw_show:    ldi   0               ; make sure message ends in null
            str   rd
            load  rf, work_buf    ; show the location message
            call  set_status      ; in the status bar
            call  prt_status      
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor

            load  rf, e_state     ; get editor state byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status after showing msg
            str   rf
            
            pop   r9              ; restore registers
            pop   rd
            pop   rf
            return
dw_coltxt:    db 'Column ',0
dw_lntxt:     db 'Line ',0
dw_bftxt:     db ', Buffer ',0
dw_rwtxt:     db ', Row ',0
            endp

            ;-------------------------------------------------------
            ; Name: do_goto
            ; Go to the line number entered by the user.
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current character position
            ;  r8 -   current row
            ; Uses:
            ;  rc.0 - character limit
            ;  r9 - scratch register
            ; Returns:
            ;  rb.0 - updated cursor position
            ;  DF = 0, success
            ;  DF = 1, error - invalid line number
            ;-------------------------------------------------------                                                
            proc  do_goto
            push  rf              ; save registers
            push  rd
            push  rc
            push  r9               
            
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dg_rdy          ; if no change in line, ready to goto location
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update

dg_rdy:     ldi   0               ; set up character count
            phi   rc
            ldi   MAX_INTSTR      ; up to 5 characters in integer (0 to 65536)
            plo   rc
            load  rf, dg_prmpt    ; set prompt to enter line number
            load  rd, work_buf    ; point to working buffer for input            
            call  do_input        ; prompt user for line number
            lbnf  dg_exit         ; if nothing entered, just exit
            
            copy  r8, r9          ; save original line index in r9
            load  rf, work_buf    ; convert string in work buffer to integer  
            call  f_atoi          ; convert ASCII string to integer in rd
            lbdf  dg_notfnd       ; DF = 1, means non-numeric string
            ghi   rd
            lbnz  dg_find
            glo   rd
            lbz   dg_notfnd       ; Zero is not a valid line number 
                        
dg_find:    dec   rd              ; line index is one less than line number

            load  rf, spill_msg   ; show a message 
            call  set_status          
            call  prt_status          
            
            load  rf, spill_cnt   ; get the spill count
            ldn   rf        
            lbz   dg_text         ; if no spill files, search text buffer
            
            call  seek_buf_line   ; load buffer for line, set r8 to new line
            lbdf  dg_notfnd       ; DF = 1, means buffer index invalid
            lbr   dg_srch         ; find line in buffer
            
dg_text:    copy  rd, r8          ; set line index to new value

dg_srch:    call  find_line
            lbdf  dg_notfnd       ; DF = 1, means line not found in text buffer

            call  setcurln        ; save the current line
            ldn   ra              ; get size of new line (including CRLF)
            smi   2               ; adjust for one past last character
            lbdf  dg_size         ; if positive set the length      
            ldi   0               ; if negative, set length to zero
dg_size:    phi   rb              ; set rb.1 to new size
            call  put_line_buffer ; put current line in line buffer
            
            ldi   0               ; move to beginning column
            plo   rb

            sub16 r8, r9          ; did we move up or down?            
            lbdf  dg_down         ; if new line > old line index, we went down
            
            call  getcurln        ; otherwise we went up, restore r8
            call  scroll_up       ; update row offset
            lbr   dg_done         
            
dg_down:    call  getcurln        ; restore r8
            call  scroll_down     ; update row offset 
            lbr   dg_done        
            
dg_done:    call  clear_screen    ; clear screen
            call  refresh_screen  ; refresh screen
            call  kilo_status     ; set default status msg
            call  prt_status      ; restore status
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor
            clc                   ; set success 
            lbr   dg_exit         ; and exit
            
dg_notfnd:  copy  r9, r8          ; restore r8 to original value
            load  rf, dg_noline   ; show not found message
            call  set_status      ; in the status bar
            call  prt_status      
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor

            load  rf, e_state     ; get editor state byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status after showing msg
            str   rf                                    
            stc                   ; set error
            
dg_exit:    pop   r9
            pop   rc
            pop   rd
            pop   rf
            return 
dg_prmpt:     db 'Enter line number to go to: ',0
dg_noline:    db 'Line number not found.',0            
            endp 
            
