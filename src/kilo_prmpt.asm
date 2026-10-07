; -------------------------------------------------------------------
; Prompt functions and Help Information for the kilo editor
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

            
; ******************************************************************************
; ***                           Help Information                             ***
; ******************************************************************************
            
            ;-------------------------------------------------------
            ; Name: do_help
            ;
            ; Show help information on screen
            ; Parameters: (None)
            ; Uses: 
            ;  rf - buffer pointer
            ; Returns: (None)
            ;-------------------------------------------------------                       
            proc  do_help
            push  rf              ; save register

            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dh_rdy          ; if no change in line, ready to show help
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


dh_rdy:     load  rf, e_state     ; get editor state byte
            ldn   rf              
            ori   REFRESH_BIT     ; set refresh bit
            str   rf              ; refresh after showing help text

            call  o_inmsg
              db 27,'[?25l',0     ; hide cursor        

            call  o_inmsg         ; position cursor at 4,4
              db 27,'[4;0H',0
              
            call  o_inmsg
              db 27,'[30;43m',0   ; set colors to black on yellow text

            load  rf, hlp_div     ; print division line
            call  o_msg  
              
            load  rf, hlp_txt1    ; print first block of text
            call  o_msg  

            load  rf, hlp_txt2    ; print next block of text
            call  o_msg  

            load  rf, hlp_div     ; print division line
            call  o_msg  

            load  rf, hlp_txt3    ; print next line of text
            call  o_msg  

            load  rf, hlp_div     ; print division line
            call  o_msg  

            load  rf, hlp_txt4    ; print next line of text
            call  o_msg  

            load  rf, hlp_div     ; print division line
            call  o_msg  

            load  rf, hlp_begin   ; print start of function line
            call  o_msg  

            load  rf, hlp_file    ; print file functions text
            call  o_msg  

            load  rf, hlp_end     ; print end function line
            call  o_msg  

            load  rf, hlp_begin   ; print start of function line
            call  o_msg  

            load  rf, hlp_page    ; print page functions text
            call  o_msg  

            load  rf, hlp_end     ; print end function line
            call  o_msg  

            load  rf, hlp_begin   ; print start of function line
            call  o_msg  

            load  rf, hlp_line    ; print line functions text
            call  o_msg  

            load  rf, hlp_end     ; print end function line
            call  o_msg  
            
            load  rf, hlp_begin   ; print start of function line
            call  o_msg  

            load  rf, hlp_curs    ; print cursor functions text
            call  o_msg  

            load  rf, hlp_end     ; print end function line
            call  o_msg  

            load  rf, hlp_div     ; print division line
            call  o_msg  
            
            load  rf, hlp_prmpt

            call  do_confirm      ; prompt to dismiss
            clc                   ; clear DF after prompt
            
            call  o_inmsg
              db  27,'[0m',0      ; set text back to normal     
            call  o_inmsg
            db 27,'[?25h',0     ; show cursor        

            call  clear_screen     
            call  refresh_screen  ; redraw screen
            call  kilo_status     ; update the status message
            call  prt_status      ; update the status line  
            pop   rf              ; restore register  
            return


hlp_div:      db '+--------------------------------+--------------------------------------+',13,10,0
hlp_txt1:     db '| ^J, Left   move cursor left    | ^K, Right   move cursor Right        |',13,10
              db '| ^U, Up     move cursor up      | ^N, Down    move cursor Down         |',13,10,0
hlp_txt2:     db '| ^D, Del    delete character    | ^H, BS         Backspace             |',13,10     
              db '| ^I, Tab    move to next tab    | ^], Shift+Tab  move to prevous tab   |',13,10
              db '| ^X   exit, if changed confirm  | ^?, ^_         Show this help screen |',13,10,0
              
hlp_txt3:     db '| ^M, Enter  Insert: new line or split, Overwrite: move to next line    |',13,10,0
hlp_txt4:     db '| Functions: ^F = File, ^P = Page, ^L = Line, ^C = Cursor               |',13,10,0
  
hlp_begin:    db '| ',0               
hlp_file:     db 'File: S=Save, R=Rename, Q=Quit+save, X=exit (no save)                 ',0
hlp_end:      db '|',13,10,0
hlp_page:     db 'Page: U=Up, D=Down, B=Bottom, T=Top, R=Redraw                         ',0
hlp_line:     db 'Line: C=Copy, X=cut, V=paste, D=Delete, J=Join, S=Split               ',0
hlp_curs:     db 'Cursor: H=Home, E=End, W=Where, G=Goto, F=Find, I=Insert/overwrite    ',0

hlp_prmpt:    db ' Press any key',0                        
            public hlp_file
            public hlp_page
            public hlp_line
            public hlp_curs
            endp

; ******************************************************************************
; ***                          Function Set Prompts                          ***
; ******************************************************************************
            
            ;-------------------------------------------------------
            ; Name: do_file
            ;
            ; Show the function prompt, and get a input character
            ; from the user and do the function selected.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   DF = 0, continue after return
            ;   DF = 1, quit after return
            ;-------------------------------------------------------                                                
            proc  do_file
            load  rf, e_state     ; get editor state byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after prompt
            str   rf

            load  rf, hlp_file    ; set prompt to enter search string
                
            ldi   01              ; set for 1 character
            plo   rc            
            call  do_input        ; prompt user to enter string
            lbnf  dfl_skip        ; if nothing entered, don't save
            
            smi   'Q'             ; Q = save & quit
            lbnf  dfl_skip        ; anything below is ignored          
            lbz   dfl_quit
            
            smi   1               ; R = rename and save
            lbz   dfl_chng
            
            smi   1               ; S = save
            lbz   dfl_save
            
            smi   5               
            lbnf  dfl_skip        ; ignore T,U,V and W
            lbz   dfl_exit        ; X = exit (no save)
            
            smi   25              ; check for lowercase q
            lbnf  dfl_skip        ; ignore anything else
            lbz   dfl_quit        ; 'q' = save & quit
            
            smi   1               ; 'r' = rename & save
            lbz   dfl_chng 

            smi   1               ; 's' = save
            lbz   dfl_save

            smi   5               
            lbnf  dfl_skip        ; ignore t,u,v and w
            lbz   dfl_exit        ; x = exit (no save)
            
            lbr   dfl_skip        ; everything else is ignored
                
dfl_quit:   call  do_save
dfl_exit:   stc                   ; set DF to quit after save
            return 
            
dfl_chng:   call do_change
            lbdf dfl_skip
dfl_save:   call do_save                        
dfl_skip:   clc                   ; clear DF to continue after save
            return 
            endp

            ;-------------------------------------------------------
            ; Name: do_page
            ;
            ; Show the function prompt, and get a input character
            ; from the user and do the function selected.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   DF = 0, page function executed  
            ;   DF = 1, error (no update)
            ;-------------------------------------------------------                                                
            proc  do_page
            load  rf, e_state     ; get editor state byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after prompt
            str   rf

            load  rf, hlp_page    ; set prompt to enter search string
                
            ldi   01              ; set for 1 character
            plo   rc            
            call  do_input        ; prompt user to enter string
            lbnf  dpg_skip        ; if nothing entered, don't save
            
            smi   'B'             ; B = bottom/next buffer
            lbnf  dpg_skip        ; anything below is ignored          
            lbz   dpg_bot
            
            smi   2               ; 'D' = page down
            lbnf  dpg_skip        ; 'C' is ignored          
            lbz   dpg_down

            smi   14              ; 'R' = redraw page 
            lbnf  dpg_skip        ; anything below is ignored
            lbz   dpg_rdrw         
            
            smi   2               ; 'T' = top
            lbnf  dpg_skip        ; 'S' is ignored
            lbz   dpg_top         

            smi   1               ; 'U' = page up
            lbz   dpg_up
            
            smi   13              ; check for lowercase b
            lbnf  dpg_skip        ; ignore anything else
            lbz   dpg_bot         ; 'b' = bottom
            
            smi   2               ; 'd' = page down
            lbnf  dpg_skip        ; 'c' is ignored          
            lbz   dpg_down
            
            smi   14              ; 'r' = redraw page 
            lbnf  dpg_skip        ; anything below is ignored
            lbz   dpg_rdrw        

            smi   2               ; 't' = top
            lbnf  dpg_skip        ; 's' is ignored
            lbz   dpg_top         

            smi   1               ; 'u' = page up
            lbz   dpg_up
            
            lbr   dpg_skip        ; everything else is ignored

dpg_bot:    call  do_bottom       ; move to bottom
            lbr   dpg_done        ; no need to flush buffer (done by next_spill)
            
dpg_top:    call  do_top          ; move to top 
            lbr   dpg_done        ; no need to flush buffer (done by prev_spill)

dpg_down:   call  do_pgdn         ; scroll down    
            lbr   dpg_flush       ; flush key buffer if needed
 
dpg_up:     call  do_pgup         ; scroll up
            lbr   dpg_flush       ; flush key buffer if needed

dpg_rdrw:   load  rf, e_state     ; get editor state byte
            ldn   rf 
            ori   REFRESH_BIT     ; set refresh bit to redraw page 
            str   rf              ; update editor state byte   
            
dpg_flush:  load  rf, e_state     ; check for key buffer
            ldn   rf
            ani   KBIO_BIT        ; zero all but kbio bit
            lbz   dpg_done        ; just exit, if no buffer in use
            call  flush_keys      ; flush the key buffer            

dpg_done:   clc                   ; clear DF to indicate success
            return
            
dpg_skip:   stc                   ; set DF to indicate error
            return 

            endp

            ;-------------------------------------------------------
            ; Name: do_line
            ;
            ; Show the function prompt, and get a input character
            ; from the user and do the function selected.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   DF = 0, update after line function
            ;   DF = 1, no update required
            ;-------------------------------------------------------                                                
            proc  do_line
            load  rf, e_state     ; get editor state byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after prompt
            str   rf

            load  rf, hlp_line    ; set prompt to enter search string
                
            ldi   01              ; set for 1 character
            plo   rc            
            call  do_input        ; prompt user to enter string
            lbnf  dln_skip        ; if nothing entered, exit without update
            
            smi   'C'             ; 'C' = copy line
            lbnf  dln_skip        ; anything below is ignored          
            lbz   dln_copy
            
            smi   1               ; 'D' = delete (kill) line
            lbz   dln_kill
            
            smi   6               
            lbnf  dln_skip        ; anything below is ignored
            lbz   dln_join        ; 'J' = join lines

            smi   9               ; 'S' = split line
            lbnf  dln_skip        ; anything below is ignored
            lbz   dln_split
            
            smi   3               ; 'V' = paste line
            lbnf  dln_skip        ; ignore anything else
            lbz   dln_paste         ; 'b' = bottom
            
            smi   2               ; 'X' = cut line
            lbnf  dln_skip        ; ignore anything else
            lbz   dln_cut         ; 'b' = bottom
            
            ;----- check for lowercase letters            
            smi   11              ; 'c' = copy line
            lbnf  dln_skip        ; ignore anything below          
            lbz   dln_copy

            smi   1               ; 'D' = delete (kill) line 
            lbz   dln_kill
            
            smi   6               
            lbnf  dln_skip        ; anything below is ignored
            lbz   dln_join        ; 'J' = join lines

            smi   9               ; 'S' = split line
            lbnf  dln_skip        ; anything below is ignored
            lbz   dln_split
            
            smi   3               ; 'V' = paste line
            lbnf  dln_skip        ; ignore anything else
            lbz   dln_paste      
            
            smi   2               ; 'X' = cut line
            lbnf  dln_skip        ; ignore anything else
            lbz   dln_cut         
            
            lbr   dln_skip        ; everything else is ignored
            
dln_copy:   call  do_copy         ; copy line to buffer
            lbr   dln_show        ; show message after copy        
            
dln_cut:    call  do_copy         ; copy line into buffer            
dln_kill:   call  do_kill         ; delete line
            lbr   dln_done        ; update after cut or delete
            
dln_paste:  call  do_paste        ; paste line from buffer
            lbr   dln_done        ; update after paste
            
dln_join:   call  do_join         ; join lines
            lbdf  dln_show        ; show eror message
            lbr   dln_done        ; update after join
            
dln_split:  call  do_split        ; split line            
dln_done:   clc                   ; clear DF to indicate update required
            return
            
dln_skip:   call  kilo_status     ; update the status message
            call  prt_status      ; update the status line
dln_show:   stc                   ; set DF to indicate no update
            return 
            endp
            
            ;-------------------------------------------------------
            ; Name: do_cursor
            ;
            ; Show the function prompt, and get a input character
            ; from the user and do the function selected.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   DF = 0, update after line function
            ;   DF = 1, no update required
            ;-------------------------------------------------------                                                
            proc  do_cursor
            load  rf, e_state     ; get editor state byte
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after prompt
            str   rf

            load  rf, hlp_curs    ; set prompt to enter search string
                
            ldi   01              ; set for 1 character
            plo   rc            
            call  do_input        ; prompt user to enter string
            lbnf  dcu_skip        ; if nothing entered, exit without update
            
            smi   'E'             ; 'E' = end of line
            lbnf  dcu_skip        ; anything below is ignored          
            lbz   dcu_end
            
            smi   1               ; 'F' = find text
            lbz   dcu_find

            smi   1               ; 'G' = goto line
            lbz   dcu_goto
            
            smi   1               ; 'H' = home
            lbz   dcu_home
            
            smi   1               ; 'I' = insert/overwrite mode
            lbz   dcu_mode

            smi   14               
            lbnf  dcu_skip        ; anything below is ignored
            lbz   dcu_where        ; 'W' = where
            
            ;----- check for lowercase letters            
            smi   14              ; 'e' = end
            lbnf  dcu_skip        ; ignore anything below          
            lbz   dcu_end

            smi   1               ; 'f' = find text
            lbz   dcu_find

            smi   1               ; 'g' = goto line
            lbz   dcu_goto
            
            smi   1               ; 'h' = home
            lbz   dcu_home
            
            smi   1               ; 'i' = insert/overwrite mode
            lbz   dcu_mode

            smi   14               
            lbnf  dcu_skip        ; anything below is ignored
            lbz   dcu_where       ; 'w' = where

            lbr   dcu_skip        ; everything else is ignored
            

dcu_find:   call  do_find         ; find text string
            lbdf  dcu_done        ; if found, update
            lbr   dcu_show        ; if not found, show message
             
dcu_mode:   call  do_mode         ; change insert/overwrite mode
            lbr   dcu_show        ; and show it

dcu_where:  call  do_where
            lbr   dcu_show        ; show message

dcu_goto:   call  do_goto         ; show message
            lbr   dcu_show
            
dcu_home:   call  do_home         ; move cursor to beginning of line
            lbr   dcu_done        ; and update
            
dcu_end:    call  do_end          ; move cursor to end of line (and update)
            
dcu_done:   clc                   ; clear DF to indicate update required
            return

dcu_skip:   call  kilo_status     ; update the status message
            call  prt_status      ; update the status line
        
dcu_show:   stc                   ; set DF to indicate no update
            return 
            endp            
