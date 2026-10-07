; -------------------------------------------------------------------
; Utility fucntions for a simple full screen editor based on the Kilo 
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
            
            extrn   size_h
            extrn   size_w
            extrn   num_lines
            extrn   row_offset
            extrn   col_offset

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


          ;-------------------------------------------------------
          ; Name: begin_kilo
          ;
          ; Initialize the screen and setup the application.
          ;
          ; Parameters: (None) 
          ; Uses:
          ;   rf - buffer pointer
          ;   re.1 - Elf/OS serial byte
          ;   fname - should be set by caller
          ; Returns: 
          ;   re.1 - serial echo bit off
          ;   r8 - current line number
          ;   r7 - cursor set to home position 
          ;-------------------------------------------------------

            proc  begin_kilo
                 
            ;------ Enable raw mode
            ghi   re              ; get Elf/OS serial byte
            ani   $fe             ; clear the echo bit
            phi   re              ; restore serial byte with echo off

            ;----- set the key buffer I/O bit
            ghi   re              ; re.1 = 0 means hardware uart
            lbnz  bk_cont         ; don't buffer, bit-banged serial I/O
            
            load  rf, o_readkey+1 ; check kernel vector for readkey function
            smi   $F8             ; $F800 and higher are BIOS ROM
            lbnf  bk_cont         ; don't buffer, if vector has been redirected
            
            load  rf, e_state     ; otherwise, set bit in state byte
            ldn   rf              ; get current state byte
            ori   KBIO_BIT        ; set bit to buffer serial I/O
            str   rf              ; save updated byte

            ;------ Load file to edit
bk_cont:    call  load_file       ; file text buffer
            lbnf  old_file        ; if file exists no new file message
                          
            ldn   rf              ; otherwise, set new file bit
            ori   NEWFILE_BIT     
            str   rf              ; save editor state in memory            
            
old_file:   load  rf, e_state     
            ldn   rf              ; get editor state byte
            ani   ERROR_BIT       ; check for spill error
            lbnz  bk_err          ; exit with error message

            call  find_eob        ; get the number of lines into r8
            call  set_num_lines   ; set the maximum line value in memory     
              
            ldi   0               ; set line counter to first line
            phi   r8
            plo   r8
            phi   rb              ; clear out line length and character position
            plo   rb
            phi   rc              ; set column offset to zero

            ;------ initialize screen window height and width
            call  set_window_size            
            call  set_status_cmd  ; set the ANSI command for status location

            call  setcurln        ; set the current line in text buffer
            call  set_row_offset  ; set row offset for the top of screen
            call  put_line_buffer
            call  set_col_offset  ; set column offset in memory
            
            ;------ Set up default status msg
            call  kilo_status     ; set up initial sttus message 

            call  clear_screen    ; clear the screen
            call  refresh_screen  ; print buffer to screen

            call  o_inmsg
            db 27,'[?25l',0       ; hide cursor        

#ifdef KILO_DEBUG                  
            call  prt_status_dbg  ; always show debug status line              
#else                         
            call  prt_status      ; print status line
#endif          

            call  home_cursor     ; set cursor position in memory
              
            call  o_inmsg
              db 27,'[H',0        ; home cursor on screen
            call  o_inmsg
              db 27,'[?25h',0     ; show cursor        
              
            clc                   ; return without error              
            return
            
bk_err:     stc                   ; return with error 
            return
            endp



            ;-------------------------------------------------------
            ; Name: end_kilo
            ;
            ; Set the serial echo bit on to disable the raw mode, 
            ; and clear the screen before exiting the application.
            ;            
            ; Parameters: (None)
            ; Uses:
            ;   re.1 - Elf/OS serial byte
            ; Returns: 
            ;   re.1 - serial echo bit on
            ;-------------------------------------------------------
            proc  end_kilo 
            load  rf, spill_cnt ; get the spill count
            ldn   rf        
            lbz   ek_exit         ; if no spill files, just exit

            load  rf, spill_msg
            call  set_status
            call  prt_status
            
            call  teardown_spill  ; delete spill files

            ;------ Disable raw mode     
ek_exit:    ghi   re              ; get Elf/OS serial byte
            ori   $01             ; set the echo bit
            phi   re              ; restore serial byte with echo on

            call  clear_screen    ; clear the screen
            return
            endp


            
            ;*******************************************************************
            ;***                    Screen Utilities                         ***
            ;*******************************************************************
                    
            ;-------------------------------------------------------
            ; Name: set_row_offset
            ;
            ; Save the text buffer line index for the top row of  
            ; the current screen in memory.
            ; 
            ; Parameters:
            ;   r8 - text buffer line index for top row
            ; Uses:
            ;   rf - buffer pointer
            ; Returns: (None)
            ;-------------------------------------------------------            
            proc  set_row_offset
            push  rf
          
            load  rf, row_offset  ; top line index
            ghi   r8              ; get high index byte
            str   rf            
            inc   rf              ; point to next byte
            glo   r8              ; get low index byte
            str   rf              ; save as top line index

            load  rf, e_state     ; set refresh bit
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     
            str   rf

            pop   rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: get_row_offset
            ;
            ; Get the text buffer line index for the top row of
            ; the current screen display.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns: (None)
            ;   r8 - text buffer line index for top row
            ;-------------------------------------------------------            
            proc  get_row_offset
            push  rf

            load  rf, row_offset  ; top line index
            lda   rf              ; get high index byte
            phi   r8            
            lda   rf              ; get low index byte
            plo   r8              ; r8 has line index for top row

            pop   rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: set_col_offset
            ;
            ; Save the column offset index from the left of the 
            ; the current screen in memory.
            ; 
            ; Parameters:
            ;   rb.0 - character position
            ;   rc.1 - column offset index
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   rc.1 - column offset index
            ;-------------------------------------------------------            
            proc  set_col_offset
            push  rf

            load  rf, size_w      ; window width value
            ldn   rf              ; get width
            smi   1               ; subtract one for one based index  
            str   r2              ; save at M(X)
            glo   rb              ; get char position
            sm                    ; subract width from character position 
            lbdf  set_off         ; if positive, new offset is difference
            ldi   0               ; if negative, set to 0
set_off:    str   r2              ; save in M(X)            
            load  rf, col_offset  ; top line index
            ghi   rc              ; get current offset
            sm                    ; did it change?
            lbz   so_exit         ; if no change, just exit   
            ldx                   ; get offset
            phi   rc              ; set col offset
            str   rf              ; save in memory
            load  rf, e_state     ; set refresh bit
            ldn   rf
            ori   REFRESH_BIT
            str   rf
so_exit:    pop   rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: get_col_offset
            ;
            ; Get the text buffer line index for the top row of
            ; the current screen display.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns: (None)
            ;   rc.1 - column offset for current screen
            ;-------------------------------------------------------            
            proc  get_col_offset
            push  rf

            load  rf, col_offset  ; column offset index
            lda   rf              ; get column byte
            phi   rc            

            pop   rf
            return
            endp
                          
            
            ;-------------------------------------------------------
            ; Name: set_num_lines
            ;
            ; Set the number of rows to the number of lines 
            ; in the text buffer
            ; 
            ; Parameters: 
            ;   r8 - line maximum number from find_eob
            ; Uses:
            ;   rf - buffer pointer
            ; Returns: (None)
            ;-------------------------------------------------------            
            proc  set_num_lines
            push  rf

            load  rf, num_lines   ; point to maximum line value
            ghi   r8
            str   rf
            inc   rf
            glo   r8
            str   rf  
            pop   rf
            return
            endp


            ;-------------------------------------------------------
            ; Name: get_num_lines
            ;
            ; Get the maximum number of lines from memory
            ; 
            ; Parameters: (None) 
            ; Uses:
            ;   rf - buffer pointer
            ; Returns: 
            ;   r9 - current line maximum (line limit)
            ;-------------------------------------------------------            
            proc  get_num_lines
            push  rf

            load  rf, num_lines   ; point to maximum line value
            lda   rf
            phi   r9
            ldn   rf
            plo   r9
            pop   rf
            return
            endp
            
            ;-------------------------------------------------------
            ; Name: inc_num_lines
            ;
            ; Increment the maximum number of lines in memory
            ; 
            ; Parameters: (None) 
            ; Uses:
            ;   rf - buffer pointer
            ; Returns: 
            ;   r9 - maximum number of lines (incremented)
            ;-------------------------------------------------------            
            proc  inc_num_lines
            push  rf

            load  rf, num_lines   ; point to maximum line value
            lda   rf
            phi   r9
            ldn   rf
            plo   r9
            inc   r9              ; increase count
            glo   r9              ; save low byte of new count
            str   rf
            dec   rf              ; back up rf to high byte
            ghi   r9  
            str   rf              ; save high byte of new count

            pop   rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: dec_num_lines
            ;
            ; Decrement the maximum number of lines in memory
            ; 
            ; Parameters: (None) 
            ; Uses:
            ;   rf - buffer pointer
            ; Returns: 
            ;   r9 - maximum number of lines (decremented)
            ;-------------------------------------------------------            
            proc  dec_num_lines
            push  rf

            load  rf, num_lines   ; point to maximum line value
            lda   rf
            phi   r9
            ldn   rf
            plo   r9
            
            ghi   r9              ; check for zero
            lbnz  dnl_cont        ; if non zero continue
            glo   r9
            lbz   dnl_exit        ; if zero, don't decrement further
            
dnl_cont:   dec   r9              ; decrease count
            glo   r9              ; save low byte of new count
            str   rf
            dec   rf              ; back up rf to high byte
            ghi   r9  
            str   rf              ; save high byte of new count

dnl_exit:   pop   rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: is_eof
            ;
            ; Determine if line index points to the end of file
            ; 
            ; Parameters:
            ;   r8 - current line index
            ; Uses:
            ;   rf - buffer pointer
            ; Returns: 
            ;   DF = 1, current line at end of file
            ;   DF = 0, current line within file
            ;   r9 - number of lines above eof
            ;-------------------------------------------------------            
            proc  is_eof
            push  rf
            load  rf, num_lines   ; point to maximum line value

            lda   rf              ; get high byte of maximum line value
            phi   r9
            lda   rf              ; get low byte of maximum line value
            plo   r9              ; r9 has maximum line value (eof)
            
            sub16 r9,r8           ; subtract current line from maximum number 
            lbnf  eof_true        ; if negative, somehow went beyond eof
            ghi   r9              ; check difference for zero
            lbnz  eof_false       ; non-zero means current line within file
            glo   r9
            lbnz  eof_false
eof_true:   stc                   ; if zero, current line at the end of file 
            lbr   eof_exit 
            
eof_false:  clc 
eof_exit:   pop   rf
            return
            endp
            
            ;-------------------------------------------------------
            ; Name: clear_screen
            ;
            ; Send the ANSI sequences to clear the screen and 
            ; home the cursor
            ; 
            ; Parameters: (None)
            ; Uses: (None)
            ; Returns: (None)
            ;-------------------------------------------------------            
            proc  clear_screen
            call  o_inmsg
              db 27,'[2J',0           ; erase display
            call  o_inmsg
              db 27,'[H',0            ; home cursor
            return
            endp 

            ;-------------------------------------------------------
            ; Name: found_screen
            ;
            ; Calculate the row offset and column offset for 
            ; the screen after a string is found.
            ; 
            ; Parameters: 
            ;   rd - target string found
            ;   r8 - current row
            ; Uses:
            ;   rf - buffer pointer
            ;   r9 - row offset value
            ;   rc - screen rows
            ;   rc.0 - counter
            ; Returns: 
            ;   rc.1 - column offset
            ;   rb.1 - line size 
            ;   rb.0 - character position 
            ;   r7.1 - updated cursor y position
            ;   r7.0 - updated cursor x position 
            ;-------------------------------------------------------            
            proc  found_screen
            push  rf              ; save registers used
            push  rd
            push  r9

            load  rf, size_w      ; screen width 
            ldn   rf              ; get byte value
            smi   1               ; subtract one for zero index
            plo   rc              ; save width
            phi   r9              ; also save width in r9.1 as default 

ms_subt:    lda   rd              ; subtract length of target string
            lbz   ms_clmn         ; calculate column offset when done
            dec   rc              ; subtract length from width
            lbr   ms_subt  
            
ms_clmn:    glo   rb              ; get current character position
            str   r2              ; save in M(X) for arithmetic
            plo   r9              ; save in r9.0 to restore

            glo   rc              ; get remaining size of line
            sm                    ; check character position
            lbdf  ms_nocoff       ; if remaining len >= char position, no offset
            ghi   r9              ; get remaining length
            plo   rd              ; set column offset to remaining length
            lbr   ms_coff

ms_nocoff:  ldi   0
            plo   rd
ms_coff:    load  rf, col_offset  ; top line index
            glo   rd              ; get calculated column offset
            str   rf              ; save as new column offset
                  
            ldi   0               ; set row offset to zero initially
            phi   r9            
            plo   r9

            ldi   0               ; set high byte of counter to zero
            phi   rc
              
            load  rf, size_h      ; height value
            ldn   rf              ; get byte value
            smi   1               ; subtract one for zero index
            plo   rc              ; save bottom line index
  
            
            copy  r8, rd          ; copy current line to remaining line 
ms_subrow:  sub16 rd, rc          ; compare remaining line to screen width
            lbnf  ms_done         ; if remaining line < screen height, we are done
            add16 r9, rc          ; adjust row offset by screen height
            lbr   ms_subrow       ; keep going until done
            
ms_done:    load  rf, row_offset  ; save new row offset in r9
            ghi   r9              ; get high row offset byte
            str   rf            
            inc   rf              ; point to next byte
            glo   r9              ; get low row offset byte
            str   rf              ; save as top line index

            load  rf, col_offset  
            ldn   rf              ; get calculated column offset
            phi   rc              ; set rc.1 to new column offset
            
            call  find_line       ; get the current line
            ldn   ra              ; get size of current line
            smi   2               ; adjust for one past last character
            lbdf  ms_size         ; if positive, set length
            ldi   0               ; if negative, set length to zero
ms_size:    phi   rb              ; set rb.1 to new size
            call  put_line_buffer ; put current line in line buffer
            
            call  set_cursor      ; adjust the cursor position
            pop   r9              ; restore registers used
            pop   rd
            pop   rf
            return
            endp
            
            ;-------------------------------------------------------
            ; Name: refresh_screen
            ;
            ; Send the ANSI sequences and text to refresh the screen
            ; 
            ; Parameters: (None)
            ; Uses: 
            ;   rd - line pointer
            ;   rc.0 - line counter
            ; Returns: (None)
            ;-------------------------------------------------------            
            proc  refresh_screen
            push  rf
            push  rd

            ldi   0               ; clear out char counter
            phi   rd
            plo   rd                          
            
            call  o_inmsg
              db 27,'[?25l',0     ; hide cursor        

            call  o_inmsg
              db 27,'[H',0        ; home cursor

            call  getcurln          
            push  r8              ; save current line for later
            
            call  get_row_offset  ; set the current line for the top row
            call  find_line       ; set r8 and ra for top row line in text buffer    

            call  window_height   ; set up counter for lines
            dec   rc              ; skip one line for status

            call  get_col_offset  ; get the column offset into rc.1
            
prt_lines:  call  o_inmsg
              db 27,'[2K',0       ; erase line

            ghi   rc              ; get column offset
            adi   2               ; add two for the CRLF at eol
            str   r2              ; save column offset +2  into M(X)
            ldn   ra              ; get size of line
            lbz   rf_done         ; if we hit the end of buffer we are done
            sm                    ; subtract column offset +2 from line size
            lbnf  ln_skp          ; if line size - (column offset +2) < 0, skip line
            
            ghi   rc              ; get column offset
            str   r2              ; save column offset into M(X)                        
            lda   ra              ; get size again
            sm                    ; calculate difference, line size - column offset            
            plo   rd              ; set up character counter with difference
            ghi   rc              ; get column offset
            str   r2              ; save column offset in M(X)
            glo   ra              ; adjust line buffer ptr by offset
            add
            plo   ra              ; save adjust low byte
            ghi   ra              ; add carry flag into high byte
            adci  0
            phi   ra              ; ra now points to first character on-screen
              
ln_lp:      lda   ra              ; get character
            call  o_type          ; print on screen
            dec   rd              ; count down characters in line
            glo   rd              ; check counter for end of line
            lbnz  ln_lp           ; keep going for all characters on screen  
            
            lbr   ln_cont         ; continue  on
            
ln_skp:     lda   ra              ; ra points to size, so get size
            str   r2              ; save in M(X)
            glo   ra              ; add size to ra to advance to next line
            add
            plo   ra              ; update low byte
            ghi   ra              ; add carry into high byte
            adci  0
            phi   ra              ; update high byte
            
            call  o_inmsg         ; output CRLF to skip line
              db 10,13,0

ln_cont:    inc   r8              ; add one to current line value

            dec   rc              ; count down
            glo   rc              ; check counter
            lbnz  prt_lines       ; if zero done with text buffer  

rf_done:    call  get_cursor      ; restore cursor
            call  move_cursor     ; position cursor
                
            call  o_inmsg
              db 27,'[?25h',0     ; show cursor        

            pop   r8              ; restore current line
            call  setcurln
            call  find_line       ; point ra to current line in buffer 
            lbdf  rf_err          ; if not found, set to zero 
            ldn   ra              ; get line size
            smi   2               ; subtract 2 for CRLF
            lbdf  rf_size         ; if positive, set length
rf_err:     ldi   0               ; if negative, set length to zero
rf_size:    phi   rb              ; save line size in rb.1
            load  rf, e_state     ; get editor state and clear refresh flag
            ldn   rf
            ani   REFRESH_MASK    ; clear refresh bit and status bit
            str   rf              ; save back in memory 

            pop   rd              ; restore registers used
            pop   rf
            return
            endp 

#ifdef KILO_DEBUG
#include kilo_dbg.inc 
#endif
