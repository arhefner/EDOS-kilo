; -------------------------------------------------------------------
; Configuration functions for the kilo editor
; -------------------------------------------------------------------
; Copyright 2025 by Gaston Williams
; -------------------------------------------------------------------

#include include/opcodes.def
#include include/bios.inc
#include include/kernel_api.inc
#include include/kilo_def.inc
            
            extrn   size_h
            extrn   size_w
            extrn   c_pos
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


; ******************************************************************************
; ***                           Window Utilities                             ***
; ******************************************************************************

            ;-------------------------------------------------------
            ; Name: set_window_size
            ;
            ; Get the screen size from ELF-DOS and set the size_h and
            ; size_w byte values.  The size is the one TERMSIZE gave
            ; the kernel.  A dimension the kernel does not know keeps
            ; its default, 24 rows or 80 columns, and a screen wider
            ; than MAX_WIDTH is treated as MAX_WIDTH columns wide.
            ;
            ; The editor does not query the terminal itself.  The
            ; reply to a cursor position query arrives back to back,
            ; and a bit-banged console drops a digit of it unless
            ; the read loop is very short.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   DF = 0, no error
            ;-------------------------------------------------------
            proc    set_window_size
            push    rf            ; save register used
            
            load    rf, TERM_ROWS ; kernel's rows, zero if unknown
            ldn     rf
            lbz     sz_cols       ; if unknown, keep the default height
            str     r2            ; save rows in M(X), load changes D
            load    rf, size_h    ; save the height in memory
            ldn     r2
            str     rf

sz_cols:    load    rf, TERM_COLS ; kernel's columns, zero if unknown
            ldn     rf
            lbz     sz_exit       ; if unknown, keep the default width
            str     r2            ; save columns in M(X)
            smi     MAX_WIDTH+1   ; check for a screen that is too wide
            lbnf    sz_width      ; if columns <= maximum, use them
            ldi     MAX_WIDTH     ; otherwise, use the maximum width
            str     r2            
sz_width:   load    rf, size_w    ; save the width in memory
            ldn     r2
            str     rf
            
sz_exit:    pop     rf            ; restore register used
            clc                   ; clear DF to indicate success 
            return
            endp


            ;-------------------------------------------------------
            ; Name: window_height
            ;
            ; Get the screen window height as a value in RC.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   rc.0 - height of screen 
            ;-------------------------------------------------------            
            proc    window_height
            push    rf
            
            load    rf, size_h    ; window height value
            ldn     rf            ; get byte value
            plo     rc            ; return value in rc.0
            
            pop     rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: window_width
            ;
            ; Get the screen window width as a value in RC.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   rc.0 - width of screen 
            ;-------------------------------------------------------            
            proc    window_width
            push    rf
            
            load    rf, size_w    ; window width value
            ldn     rf            ; get byte value
            plo     rc            ; return x value in rc.0
            
            pop     rf
            return
            endp
            
            ;-------------------------------------------------------
            ; Name: window_size
            ;
            ; Get the screen window height and width in r9
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   r9.1 - height of screen
            ;   r9.0 - width of screen 
            ;-------------------------------------------------------            
            proc    window_size
            push    rf

            load    rf, size_h    ; height value
            ldn     rf            ; get byte value
            phi     r9            ; return height in r9.1
            
            load    rf, size_w    ; width value
            ldn     rf            ; get byte value
            plo     r9            ; return width in r9.0
            
            pop     rf
            return
            endp

            
; ******************************************************************************
; ***                          Cursor Utilities                              ***
; ******************************************************************************

            ;-------------------------------------------------------
            ; Name: get_cursor
            ;
            ; Get the cursor position
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   r7.1 - cursor y position (row)
            ;   r7.0 - cursor x position (column) 
            ;-------------------------------------------------------            
            proc    get_cursor
            push    rf

            load    rf, c_pos     ; cursor position value
            lda     rf            ; get y byte value
            phi     r7            ; return c_y in r9.1
            
            ldn     rf            ; get x byte value
            plo     r7            ; return c_x in r9.0
            
            pop     rf
            return
            endp
            
            ;-------------------------------------------------------
            ; Name: home_cursor
            ;
            ; Set the cursor position to home at row 1, column 1.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   r7 - cursor position set to row 1, column 1 (home)
            ;-------------------------------------------------------            
            proc    home_cursor
            push    rf

            load    rf, c_pos     ; cursor position value
            ldi     1             ; c_y home value is 1
            str     rf            ; save as cursor y position
            inc     rf            ; point to cursor x value
            str     rf            ; c_x home value is 1
            phi     r7            ; set R7.1 for home cursor position
            plo     r7            ; set R7.1 for home cursor position

            pop     rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: set_cursor   
            ;
            ; Set the cursor position in memory after the 
            ; current line has been moved.
            ; 
            ; Parameters: 
            ;   rb.0 - current character position
            ;   r8 - current line
            ; Uses:
            ;   rf - buffer pointer
            ;   r9 - row offset
            ; Returns:
            ;   r7.1 - updated cursor y position (row)
            ;   r7.0 - updated cursor x position (column) 
            ;-------------------------------------------------------            
            proc  set_cursor
            push  rf              ; save registers used
            push  r9
            push  r8              ; save current line
          
            call  getcurln        ; set r8 to current line
            
            load  rf, row_offset  ; top line index
            lda   rf              ; get high index byte
            phi   r9            
            lda   rf              ; get low index byte
            plo   r9              ; r8 has the row offset
            
            sub16 r8, r9          ; subtract row offset from current line
            glo   r8              ; r8.0 =  current line - row offset
            adi    1              ; cursor values begin at 1, not 0
            phi   r7              ; set cursor y position
            
            load  rf, col_offset  ; horizontal index
            ldn   rf              ; get col offset 
            str   r2              ; save offset in M(X)
            glo   rb              ; get character position value
            sm                    ; subtract offset from char position
            adi   1               ; cursor values begin at 1, not 0
            plo   r7              ; set cursor x position
            
            load    rf, c_pos     ; cursor position value
            ghi     r7            ; get c_y value in r7.1
            str     rf            ; save as cursor y position
            inc     rf            ; point to cursor x value
            glo     r7            ; get c_x value in r7.0
            str     rf            ; save as cursor x position

            pop     r8
            pop     r9
            pop     rf
            return
            endp


            ;-------------------------------------------------------
            ; Name: move_cursor
            ;
            ; Move the cursor on screen
            ; 
            ; Parameters: (None)
            ;   r7 - cursor position
            ; Uses:
            ;   rf - buffer pointer
            ;   rd - hex value to convert
            ; Returns: (None)
            ;-------------------------------------------------------            
            proc    move_cursor
            push    rf
            push    rd
            
            ldi     0             ; set up rd for int to ASCII conversion
            phi     rd
            ghi     r7            ; get the cursor y value 
            plo     rd            ; save for conversion to integer
            load    rf, pos_y
            call    f_uintout
            ldi     0             ; make sure ASCII value terminated as string
            str     rf

            ldi     0             ; set up rd for int to ASCII conversion
            phi     rd
            glo     r7            ; get the cursor x value 
            plo     rd            ; save for conversion to integer
            load    rf, pos_x
            call    f_uintout
            ldi     0             ; make sure ASCII value terminated as string
            str     rf
            
            call    K_INMSG       ; send CSI for ANSI command
              db 27,'[',0
            
            load    rf, pos_y     ; send ASCII y value
            call    K_MSG

            call    K_INMSG       ; send ANSI value separator
              db ';',0

            load    rf, pos_x     ; send ASCII x value
            call    K_MSG

            call    K_INMSG       ; send end of ANSI command to move cursor
              db 'H',0

            pop     rd
            pop     rf
            return
pos_x:        db 0,0,0,0,0
pos_y:        db 0,0,0,0,0              
            endp


;*******************************************************************************
;***                         Editor State Utilities                          ***
;*******************************************************************************

            ;-------------------------------------------------------
            ; Name: set_dirty
            ;
            ; Set the dirty bit and buffer change in the editor state.
            ; 
            ; Parameters: (None) 
            ; Uses:
            ;   rf - buffer pointer 
            ; Returns: (None)
            ;-------------------------------------------------------            
            proc  set_dirty
            push  rf              ; save rf
            load  rf, e_state     ; get editor state byte  
            ldn   rf
            ori   BUFFER_DIRTY    ; set the dirty and buffer changed bits
            str   rf
            pop   rf
            return
            endp

;*******************************************************************************
;***                     Editor Configuration Variables                      ***
;*******************************************************************************
                                              
            ;-------------------------------------------------------
            ; Name: rf_top
            ;
            ; First row for refresh_screen to refresh, zero for all rows. 
            ;-------------------------------------------------------            
            proc    rf_top
              db 0
            endp

            ;-------------------------------------------------------
            ; Name: size_h
            ;
            ; Height of screen as byte value. 
            ;-------------------------------------------------------            
            proc    size_h
              db DEF_LINES
            endp
            
            ;-------------------------------------------------------
            ; Name: size_w
            ;
            ; Width of screen as byte value. 
            ;-------------------------------------------------------            
            proc    size_w
              db DEF_COLS
            endp

            ;-------------------------------------------------------
            ; Name: c_pos
            ;
            ; Cursor position: y (column) and x (row) 
            ; Note: These values are one based for ANSI
            ;-------------------------------------------------------            
            proc    c_pos
c_y:          db 1              ; 1 to Height (size_h)
c_x:          db 1              ; 1 to Width (size_w) 
            endp

            ;-------------------------------------------------------
            ; Name: col_max
            ;
            ; Maximum size of columns displayed on screen
            ;-------------------------------------------------------            
            proc    col_max
cl_max:       db 0               ; Max line length
            endp
            
            ;-------------------------------------------------------
            ; Name: num_lines
            ;
            ; Number of lines in text buffer
            ;-------------------------------------------------------            
            proc    num_lines
ln_max:      dw 0               ; Number of rows 
            endp
            
            
            ;-------------------------------------------------------
            ; Name: row_offset
            ;
            ; Represents the index for the text line at the top of
            ; the current screen.  This value is zero based like
            ; the text buffer line index.
            ;-------------------------------------------------------                        
            proc    row_offset 
top_ln_idx:   dw    0           ; row index for top line of screen            
            endp  


            ;-------------------------------------------------------
            ; Name: col_offset
            ;
            ; Represents the index for the text column from the 
            ; left of the current screen.  This value is zero based.
            ;-------------------------------------------------------                        
            proc    col_offset 
col_idx:      db    0           ; row index for top line of screen            
            endp  


            ;-------------------------------------------------------
            ; Name: e_state
            ;
            ; Represents the state of the editor.
            ;-------------------------------------------------------                        
            proc    e_state 
ed_state:    db     0           ; editor state bits            
            endp  

; *******************************************************************
; ***                   Strings and Buffers                       ***
; *******************************************************************

;-------------------------------------------------------
; Name: spill_msg
;
; Status message when buffering spill files. 
;-------------------------------------------------------            
proc  spill_msg
buf_txt:     db  'Buffering...',0
endp

;-------------------------------------------------------
; Name: status_msg
;
; Buffer for editing the current status message.  It holds
; one character for each screen column, up to MAX_WIDTH, 
; plus the 5 byte ANSI reset sequence and null that ends 
; the message.
;-------------------------------------------------------            
proc  status_msg
status_txt:   ds  MAX_WIDTH+5
endp


;-------------------------------------------------------
; Name: line_buf
;
; Buffer for editing the current line of text
;-------------------------------------------------------            
proc  line_buf
ln_buf:       ds  128
endp

;-------------------------------------------------------
; Name: work_buf
;
; Buffer for utility routines
;-------------------------------------------------------            
proc  work_buf
wrk_buf:      ds  255
endp

;-------------------------------------------------------
; Name: clip_brd
;
; Buffer for copying a line of text
;-------------------------------------------------------            
proc  clip_brd
clp_brd:       ds  128
endp

;-------------------------------------------------------
; Name: num_buf
;
; Buffer for number conversions
;-------------------------------------------------------            
proc  num_buf
nmbr_buf:     db 0,0,0,0,0,0
endp

;-------------------------------------------------------
; Name: status_cmd
;
; Buffer for ANSI status cursor command
;-------------------------------------------------------            
proc  status_cmd
stat_cmd:     ds 10
endp

;-------------------------------------------------------
; Name: fbuf_idx
;
; Current buffer in use to browse a large file
;-------------------------------------------------------            
proc  fbuf_idx
fb_idx:       db  0
endp

;-------------------------------------------------------
; Name: spill_cnt
;
; Spill count
;-------------------------------------------------------            
proc  spill_cnt
sp_cnt:       db  0
endp


;-------------------------------------------------------
; Name: sname
;
; Name of spill file
;-------------------------------------------------------            
proc  sname
  db '__kilo.'
spl_idx:      db '00',0           ;default is zero

  public    spl_idx
endp
