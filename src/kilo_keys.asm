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


; *******************************************************************
; ***         Main Key Handler for Kilo Editor                    ***
; *******************************************************************
                  
            ;-------------------------------------------------------
            ; Name: do_kilo
            ;
            ; Read a key and dispatch it to the appropriate 
            ; key handler until Ctrl+Q is pressed.
            ;-------------------------------------------------------       
            proc  do_kilo
      
            ; read characters until ctrl+q is typed  
c_loop:     call  get_key         ; get a keyvalue             
            str   r2              ; save character at M(Xs)

            ; Check for printable or control char
            ; values (0-31 or 127) control
        
chk_c:      ldi   27              ; check for escape char immediately
            sd                    ; if c = <esc>
            lbz   c_esc           ; process escape sequence
            ldi   ' '             ; check for bottom of printable char
            sd                    ; DF = 1, means space or higher
            lbnf  c_ctrl          ; jump if not printable
            smi   95              ; check for DEL
            lbz   c_ctrl          ; 127 is a control char

            load  rf, c_rpt       ; get repeated character
            ldn   rf          
            sm                    ; check for match with repeat 
            lbz   c_rptd          ; if match, repeated char
            ldi   0               ; otherwise clear repeated char
            str   rf            
                        
c_prt:      ldx                   ; get printable character at M(X)
            plo   r9
            
            push  rf              ; save rf
            push  r9              ; save r9 with character to type
            
            call  get_num_lines   ; set r9 to maximum line value

            sub16 r9, r8          ; is the current line in r8 at maximum?
            ghi   r9
            lbnz  cprt_mode       ; if r9 is not zero, continue on
            glo   r9
            lbnz  cprt_mode       ; if zero, current line is at maximum
            
            call  do_insline      ; insert a new line before typing
            call  put_line_buffer ; put new line in line buffer
            ldi   0               ; move to beginning column
            plo   rb
            
cprt_mode:  pop   r9              ; restore r9 with character to type
            load  rf, e_state     ; get editor state byte  
            ldn   rf
            ani   ERROR_BIT       ; check for error
            lbnz   c_error        ; if error, exit with message    
            
            ldn   rf              ; get editor state byte again
            ani   MODE_BIT        ; toggle input mode bit
            lbz   cprt_ins        ; default is insert mode
             
cprt_ovr:   call  do_typeover     ; overwrite printable character            
            lbr   cprt_done       
            
cprt_ins:   glo   rb              ; get current line position
            smi   MAX_COL         ; check if at maximum
            lbdf  cprt_ovr        ; if at maximum, type over 
            call  do_typein       ; insert printable character            
cprt_done:  pop   rf              ; restore buffer register when done
            lbr   c_line          ; update line

c_rptd:     ldx                   ; get character and check for repeated arrows
            smi   'A'             ; check for ^[AAAA repeated sequence
            lbnf  c_unkn          ; anything below 'A' is unknown
            lbz   c_up            ; process Up Arrow key            
            smi   1               ; check for ^[BBBB
            lbz   c_dwn           ; process Down Arrow key
            smi   1               ; check for ^[CCCC
            lbz   c_rght          ; process Right Arrow key  
            smi   1               ; check for ^[DDDD
            lbz   c_left          ; process Left Arrow key
            lbnz  c_unkn          ; Anything else is an unknown sequence
                
c_esc:      load  rf, c_rpt       ; clear repeated character
            ldi   0               ; for control sequence
            str   rf
            call  get_key         ; get control sequence introducer character
           
            str   r2              ; save character at M(X)  
            smi   '['             ; check for csi escape sequence
            lbz   sq_csi          ; <Esc>[ is a valid ANSI sequence

            ldx                   ; get character and check for VT-52 sequences
            lbr   sq_vt52 
        
sq_csi:     call  get_key         ; get csi character
            
sq_vt52:    stxd                  ; save character on stack
            smi   'A'             ; check for 3 character sequence
            lbdf  sq_ok           ; A and above are 3 character sequences

            call  get_key         ; get closing ~ for 4 char sequence
            
            smi   '~'
            lbz   sq_ok           ; properly closed continue

            irx                   ; pop char from stack into D
            ldx 
            lbr   c_unkn          ; print unknown escape seq message
        
sq_ok:      irx                   ; get character from stack 
            ldx
            smi   49              ; check for <Esc>[1~ sequence
            lbz   c_home          ; process Home key
            smi   1               ; check for <Esc>[2~ sequence
            lbz   c_mode          ; process Insert key
            smi   1               ; check for <Esc>[3~ sequence
            lbz   c_del           ; process Delete key
            smi   1               ; check for <Esc>[4~ sequence
            lbz   c_end           ; process End key
            smi   1               ; check for <Esc>[5~ sequence
            lbz   c_pgup          ; process PgUp key
            smi   1               ; check for <Esc>[6~ sequence
            lbz   c_pgdn          ; process PgDn key
            smi   11              ; check for <Esc>[A
            lbnf  c_unkn          ; Unknown sequence
            lbz   c_up            ; process Up Arrow key
            smi   1               ; check for <Esc>[B
            lbz   c_dwn           ; process Down Arrow key
            smi   1               ; check for <Esc>[C
            lbz   c_rght          ; process Right Arrow key  
            smi   1               ; check for <Esc>[D
            lbz   c_left          ; process Left Arrow key
            smi   22              ; check for <Esc>[Z
            lbz   c_bktab         ; process Shift-Tab 
            lbr   c_unkn          ; Anything else is unknown
                
c_ctrl:     load  rf, c_rpt       ; clear repeated character
            ldi   0               ; for control sequence
            str    rf
            ldx                   ; get control character at M(X)
            smi   2               ; check for Ctrl-B (Home)
            lbz   c_home
            lbnf  c_unkn          ; Ctrl-A (minicom), Ctrl-@ (null) are not used
            smi   1               ; check for Ctrl-C (Cursor Functions)
            lbz   c_cursor
            smi   1               ; check for Ctrl-D (Delete)
            lbz   c_del  
            smi   2               ; check for Ctrl-F (File Functions)
            lbnf  c_unkn          ; Ctrl-E not used
            lbz   c_file
            smi   2               ; check for Ctrl-H (Backspace)
            lbnf  c_unkn          ; Ctrl-E not used
            lbz   c_bs
            smi   1               ; check for Ctrl-I (Tab)
            lbz   c_tab
            smi   1               ; check for Ctrl-J (Left)
            lbz   c_left
            smi   1               ; check for Ctrl-K (Right)
            lbz   c_rght
            smi   1               ; check for Ctrl-L (Line Functions)
            lbz   c_linef
            smi   1               ; check for Ctrl-M (Enter)
            lbz   c_enter
            smi   1               ; check for Ctrl-N (Down)
            lbz   c_dwn
            smi   2               ; check for Ctrl-P (Page Functions)
            lbnf  c_unkn          ; Ctrl-O is ignored
            lbz   c_page
            smi   5               ; check for Ctrl-U (Up Arrow)
            lbnf  c_unkn          ; Ctrl-Q,R,S,T not used
            lbz   c_up
            smi   3               ; check for Ctrl-X (Exit)
            lbnf  c_unkn          ; Ctrl-V,W not used
            lbz   c_quit        
            smi   5               ; check for Ctrl-] (Back Tab)
            lbnf  c_unkn          ; Ctrl-Y,Z,[,\ not used (Ctrl-[ is escape)
            lbz   c_bktab
            smi   2               ; check for Ctrl-? (Ctrl-/)
            lbnf  c_help          ; Ctrl-^ is also Help 
            lbz   c_help          ; check for Ctrl-? 
            smi   96              ; check for DEL (Delete)            
            lbz   c_del

            lbr   c_loop          ; ignore any unknown chracters  

            ;----- Control key actions
c_bs:       call  do_backspace
            lbr   c_line
            
c_tab:      call  do_tab
            lbr   c_line
            
c_enter:    call  do_enter
            lbr   c_update

c_file:     call  do_file         ; prompt and do file functions
            lbdf  c_quit          ; DF=1 means quit program
            lbr   c_loop          ; show message until key pressed

c_page:     call  do_page         ; prompt and do page functions 
            lbdf  c_move          ; if nothing was done, update the prompt
            lbr   c_update        ; update screen after page function
            
c_linef:    call  do_line
            lbdf  c_loop          ; show message until key pressed
            lbr   c_update        ; update screen after line function

c_cursor:   call  do_cursor
            lbdf  c_loop          ; show message until key pressed
            lbr   c_update        ; update screen after page function

c_quit:     call  do_quit         ; check dirty flag and prompt before quitting
            lbdf  c_loop          ; DF = 1, means don't quit 
            lbr   c_exit

            ;----- 4 character CSI escape sequences
c_home:     call  do_home
            lbr   c_update

c_mode:     call  do_mode          ; toggle the editor mode
            lbr   c_loop
 
c_del:      call  do_del
            lbdf  c_update        ; if we deleted a line then update display
            lbr   c_line          ; otherwise just update line
             
c_end:      call  do_end
            lbr   c_update

c_pgup:     call  do_pgup

            load  rf, e_state     ; check for key buffer
            ldn   rf
            ani   KBIO_BIT        ; zero all but kbio bit
            lbz   cpup_nobuf      ; skip flush if no buffer in use
            call  flush_keys      ; flush the key buffer            

cpup_nobuf: lbr   c_update      

c_pgdn:     call  do_pgdn
            
            load  rf, e_state     ; check for key buffer
            ldn   rf
            ani   KBIO_BIT        ; zero all but kbio bit
            lbz   cpdn_nobuf       ; skip flush if no buffer in use
            call  flush_keys      ; flush the key buffer            
            
cpdn_nobuf: lbr   c_update

c_unkn:     lbr   c_loop          ; continue processing                   

c_help:     call  do_help         ; show help information
            lbr   c_update        ; refresh screen after help text
            
;-----  3 character csi escape sequences
c_up:       call  do_up
            load  rf, c_rpt       ; set repeated character
            ldi   'A'             ; for up arrow ^[AAAA
            str    rf
            lbr   c_update
            
c_dwn:      call  do_down  
            load  rf, c_rpt       ; set repeated character
            ldi   'B'             ; for down arrow ^[BBBB
            str    rf
            lbr   c_update

c_rght:     call  do_rght
            load  rf, c_rpt       ; set repeated character
            ldi   'C'             ; for right arrow ^[CCCC
            str    rf
            lbr   c_update

c_left:     call  do_left
            load  rf, c_rpt       ; set repeated character
            ldi   'D'             ; for left arrow ^[DDDD
            str    rf
            lbr   c_update

c_bktab:    call  do_bktab
            lbr   c_update

            ;---- check refresh flag and update screen or move cursor
c_update:   load  rf, e_state     ; get state byte
            ldn   rf               
            ani   ERROR_BIT       ; check for error
            lbnz   c_error        ; if error, show message and exit       

            ldn   rf              ; get state byte again
            ani   REFRESH_BIT     ; check for refresh
            lbz   c_move          ; if no refrsh, just move cursor                        

            call  refresh_screen  ; refresh screen

            ;----- clear refresh bit
            load  rf, e_state     ; get state byte
            ldn   rf              
            ani   REFRESH_MASK    ; clear the refresh bit
            str   rf              ; update state byte            

c_move:     call  o_inmsg
              db 27,'[?25l',0     ; hide cursor
            call  o_inmsg         ; reset cursor for move
              db 27,'[H',0

#ifdef KILO_DEBUG                  
            call  prt_status_dbg  ; always update debug status line              
#else    
            load  rf, e_state     ; check refresh bit
            ldn   rf
            ani   STATUS_BIT      ; zero out all other bits, but status
            lbz   c_rdy           ; if no status update, ready to process character
            
            call  kilo_status     ; update the status message
            call  prt_status      ; update the status line

            load  rf, e_state     ; clear status bit after update
            ldn   rf
            ani   STATUS_MASK     ; clear bit
            str   rf              ; save updated editor state byte
c_rdy:                         
#endif

            call  get_cursor
            call  move_cursor     ; move to new position
            call  o_inmsg
              db 27,'[?25h',0     ; show cursor        
            lbr   c_loop

c_line:     call  refresh_line    ; update line on screen
            lbr   c_update

c_error:    load  rf, msg_err     ; show error message before exit
            call  do_confirm      ; wait until key pressed and exit
              
c_exit:     return
c_rpt:        db 0                ; repeated character
msg_err:      db '*** An Error Occurred ***',0
              public msg_err
            endp               

            ; ******************************************************************
            ; ***              Save function for Kilo Editor                 ***
            ; ******************************************************************

            
            ;-------------------------------------------------------
            ; Name: do_save
            ;
            ; Save a file to the disk, if the file has changed.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   DF = 0, success (File saved or no changes to save)
            ;   DF = 1, an error occurred when saving the file
            ;-------------------------------------------------------                                                
            proc  do_save
            push  rf              ; save register

            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   ds_rdy          ; if no change in line, ready to save file
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


ds_rdy:     load  rf, saving_msg  ; show initial message
            call  set_status      ; show message set previously
            call  prt_status      
                        
            load  rf, e_state     ; get editor state byte  
            ldn   rf
            ani   DIRTY_BIT       ; check the dirty bit
            lbz   ds_none         ; no changes to save
            
            call  save_file       ; save file to disk
            lbdf  ds_error        ; DF = 1, means an error occurred
            load  rf, saved_msg   ; show file was saved 
            ldi   0               ; save DF result on stack
            stxd    
            lbr   ds_show
            
ds_error:   load  rf, saved_err   ; show an error message
            ldi   1               ; save DF result on stack
            stxd
            lbr   ds_show

ds_none:    load  rf, clean_msg   ; set the status for unchanged file
            ldi   0
            stxd                  ; save DF result on stack
            
ds_show:    call  set_status      ; show message set previously
            call  prt_status      
            call  get_cursor      ; restore cursor after message
            call  move_cursor     ; position cursor 
            
            load  rf, e_state     ; set status bit
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after file msg
            str   rf

            irx                   ; get DF value from stack
            ldx 
            shr                   ; Set DF 
            
            pop   rf              ; restore register 
            return
clean_msg:    db 'No file changes to save.',0
saved_msg:    db '* File Saved. *',0
saved_err:    db '* ERROR Saving File. *',0
saving_msg:   db 'Saving...',0
            endp
                        
