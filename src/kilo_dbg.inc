
; -------------------------------------------------------------------
; Debug functions for the kilo editor
; -------------------------------------------------------------------
; Copyright 2025 by Gaston Williams
; -------------------------------------------------------------------


; *******************************************************************
; ***                    Debug Utilities                         ***
; *******************************************************************

#ifdef KILO_DEBUG
            ;-------------------------------------------------------
            ; Name: prt_status_dbg
            ;
            ; Print a debug message at the bottom of the screen.
            ;-------------------------------------------------------                        
            proc  prt_status_dbg
            push  r9
            push  r8              ; save current line
          
            load  rf, status_cmd  ; move cursor down to status line
            call  o_msg
                          
            copy  rb, rd          ; copy current line for conversion           
            load  rf, rb_hex
            call  f_hexout4

            call  get_col_offset  ; get cursor value in memory
            ldi   0               ; get cursor variable
            phi   rd
            ghi   rc              ; get cursor y position
            plo   rd
            load  rf, col_nmbr
            call  f_uintout
            ldi   0               ; make sure null at end of string
            str   rf    
                    
            call  getcurln        ; get text buffer current line
            copy  r8, rd          ; copy text line for conversion           
            load  rf, line_nmbr
            call  f_uintout
            ldi   0               ; make sure null at end of string
            str   rf    

            call  get_row_offset  ; get the row offset
            copy  r8, rd          ; copy row offset for conversion           
            load  rf, off_nmbr
            call  f_uintout
            ldi   0               ; make sure null at end of string
            str   rf    
            
            call  get_num_lines   ; get the max number of lines
            copy  r9, rd          ; copy max lines for conversion           
            load  rf, lmt_nmbr
            call  f_uintout
            ldi   0               ; make sure null at end of string
            str   rf    
            
            call  get_cursor      ; get cursor value in memory
            ldi   0               ; get cursor variable
            phi   rd
            ghi   r7              ; get cursor y position
            plo   rd
            load  rf, cy_nmbr
            call  f_uintout
            ldi   0               ; make sure null at end of string
            str   rf    
            

            ldi   0               ; get cursor variable
            phi   rd
            glo   r7              ; get cursor x position
            plo   rd
            load  rf, cx_nmbr
            call  f_uintout
            ldi   0               ; make sure null at end of string
            str   rf    

            load  rf, e_state     ; get the editor state byte
            ldn   rf
            plo   rd              ; copy state byte for conversion           
            load  rf, state_hex
            call  f_hexout2
            
            load  rf, stat_begin
            call  o_msg

            load  rf, rb_hex
            call  o_msg
            
            load  rf, line_lbl
            call  o_msg

            load  rf, line_nmbr
            call  o_msg

            load  rf, off_lbl
            call  o_msg

            load  rf, off_nmbr
            call  o_msg

            load  rf, col_lbl
            call  o_msg

            load  rf, col_nmbr
            call  o_msg

            load  rf, cy_lbl
            call  o_msg

            load  rf, cy_nmbr
            call  o_msg
            
            load  rf, cx_lbl
            call  o_msg

            load  rf, cx_nmbr
            call  o_msg

            load  rf, lmt_lbl
            call  o_msg

            load  rf, lmt_nmbr
            call  o_msg

            load  rf, state_lbl
            call  o_msg

            load  rf, state_hex
            call  o_msg

            load  rf, stat_end
            call  o_msg
            pop   r8
            pop   r9
            return
            
             
stat_begin:   db 27,'[37;44m^X=Exit *RB: ',0
rb_hex:       db 0,0,0,0,0
line_lbl:     db ' Ln: ',0
line_nmbr:    db 0,0,0,0,0,0 
off_lbl:      db ' Roff: ',0           
off_nmbr:     db 0,0,0,0,0,0
col_lbl:      db ' Coff: ',0
col_nmbr:     db 0,0,0,0,0,0
cy_lbl:       db ' cy: ',0            
cy_nmbr:      db 0,0,0,0,0,0 
cx_lbl:       db ' cx: ',0 
cx_nmbr:      db 0,0,0,0,0,0
lmt_lbl:      db ' #Ln: ',0 
lmt_nmbr:     db 0,0,0,0,0,0
state_lbl:    db ' E: ',0
state_hex:    db 0,0,0
stat_end:     db  27,'*',27,'[0m',0            

            endp  

            ;-------------------------------------------------------
            ; Name: prt_find_dbg
            ;
            ; Print a debug message at the bottom of the screen.
            ;-------------------------------------------------------                        
            proc  prt_find_dbg
            push  rf
            push  rd
            push  r8              ; save current line
          
            call  o_inmsg
              db 27,'[25;1H',0    ; set cursor for status line
                        
            copy  r8, rd          ; copy line index for conversion           
            load  rf, idx_hex
            call  f_hexout4

            ldi   0               ; get cursor variable
            phi   rd
            glo   rb              ; get column index
            plo   rd
            load  rf, clmn_nmbr
            call  f_uintout
            ldi   0               ; make sure null at end of string
            str   rf    
                    
;            call  get_row_offset  ; get the row offset
;            copy  r8, rd          ; copy row offset for conversion           
;            load  rf, off_nmbr
;            call  f_uintout
;            ldi   0               ; make sure null at end of string
;            str   rf    
            
;            call  get_num_lines   ; get the max number of lines
;            copy  r9, rd          ; copy max lines for conversion           
;            load  rf, lmt_nmbr
;            call  f_uintout
;            ldi   0               ; make sure null at end of string
;            str   rf    
            
            call  get_cursor      ; get cursor value in memory
            ldi   0               ; get cursor variable
            phi   rd
            ghi   r7              ; get cursor y position
            plo   rd
            load  rf, y_nmbr
            call  f_uintout
            ldi   0               ; make sure null at end of string
            str   rf    
            

            ldi   0               ; get cursor variable
            phi   rd
            glo   r7              ; get cursor x position
            plo   rd
            load  rf, x_nmbr
            call  f_uintout
            ldi   0               ; make sure null at end of string
            str   rf    

;            load  rf, e_state     ; get the editor state byte
;            ldn   rf
;            plo   rd              ; copy state byte for conversion           
;            load  rf, state_hex
;            call  f_hexout2
            
            load  rf, dbg_begin
            call  o_msg

            load  rf, idx_hex
            call  o_msg
            
            load  rf, clmn_lbl
            call  o_msg

            load  rf, clmn_nmbr
            call  o_msg

  ;          load  rf, off_lbl
  ;          call  o_msg

  ;          load  rf, off_nmbr
  ;          call  o_msg

  ;          load  rf, col_lbl
  ;          call  o_msg

  ;          load  rf, col_nmbr
  ;          call  o_msg

            load  rf, y_lbl
            call  o_msg

            load  rf, y_nmbr
            call  o_msg
            
            load  rf, x_lbl
            call  o_msg

            load  rf, x_nmbr
            call  o_msg

;            load  rf, lmt_lbl
;            load  rf, state_hex
;            call  o_msg

;            load  rf, lmt_nmbr
;            call  o_msg

;            load  rf, state_lbl
;            call  o_msg

;            call  o_msg

            load  rf, dbg_end
            call  o_msg
            pop   r8
            pop   rd
            pop   rf
            return
            
             
dbg_begin:    db 27,'[37;44m *Found at Index: ',0
idx_hex:      db 0,0,0,0,0
clmn_lbl:     db ' Col: ',0
clmn_nmbr:    db 0,0,0,0,0,0 
;off_lbl:      db ' Roff: ',0           
;off_nmbr:     db 0,0,0,0,0,0
;col_lbl:      db ' Coff: ',0
;col_nmbr:     db 0,0,0,0,0,0
y_lbl:       db ' cy: ',0            
y_nmbr:      db 0,0,0,0,0,0 
x_lbl:       db ' cx: ',0 
x_nmbr:      db 0,0,0,0,0,0
;lmt_lbl:      db ' #Ln: ',0 
;lmt_nmbr:     db 0,0,0,0,0,0
;state_lbl:    db ' E: ',0
;state_hex:    db 0,0,0
dbg_end:     db  27,'*',27,'[0m',0            

            endp  
#endif
