; -------------------------------------------------------------------
; Spill buffer functions for the kilo editor
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
            
            ;-------------------------------------------------------
            ; Name: next_buf
            ;
            ; Set the next buffer index to one past current index 
            ;
            ; Parameters: 
            ;    (None)
            ; Uses:
            ;   rf - destination pointer
            ;   rd - buffer index for spill file name
            ; Returns: 
            ;   DF = 0 - buffer index incremented
            ;   DF = 1 - buffer index at maximum (spill count)
            ;-------------------------------------------------------                        
            proc  next_buf
            push  rf
            push  rd
            
            load  rf, spill_cnt       ; get the spill count
            ldn   rf
            str   r2                  ; save in M(X)
            
            load  rf, fbuf_idx        ; get the current buffer
            ldn   rf                  ; get index for current buffer
            sm                        ; if we are already at the spill index
            lbdf  nb_max              ; don't move if fbuf_idx equals spill count
            
            ldn   rf                  ; get the buffer index
            adi   1                   ; add one to index
            plo   re                  ; save in scratch register
            str   rf                  ; save next value in memory
            
            load  rf, spl_idx         ; update index in spill file name
            glo   re                  ; get new index
            plo   rd                  ; put in rd.0 for conversion
            
            call  f_hexout2           ; put hex value of index in sname
            
            clc                       ; clear DF for success
nb_max:     pop   rd
            pop   rf  
            return 
            endp

            ;-------------------------------------------------------
            ; Name: prev_buf
            ;
            ; Set buffer index to one less than the current index.
            ;
            ; Parameters: 
            ;    (None)
            ; Uses:
            ;   rf - destination pointer
            ;   rd - buffer index for spill file name
            ; Returns: 
            ;   DF = 0 - buffer index decremented
            ;   DF = 1 - buffer at minimum (zero)
            ;-------------------------------------------------------                        
            proc  prev_buf
            push  rf
            push  rd
                        
            load  rf, fbuf_idx        ; get the current buffer
            ldn   rf                  ; get index for current buffer
            lbz   pb_min              ; don't move if already at zero
            
            ldn   rf                  ; get the buffer index
            smi   1                   ; subtract one from index
            plo   re                  ; save in scratch register
            str   rf                  ; save next value in memory
            
            load  rf, spl_idx         ; update index in spill file name
            glo   re                  ; get new index
            plo   rd                  ; put in rd.0 for conversion
            
            call  f_hexout2           ; put hex value of index in sname
            clc                       ; clear DF for success  
            
pb_done:    pop   rd
            pop   rf  
            return 
pb_min:     stc                       ; set DF to indicate not decremented
            lbr   pb_done             ; and exit
            endp

            ;-------------------------------------------------------
            ; Name: reset_buf
            ;
            ; Reset the buffer index to zero and set spill file name 
            ;
            ; Parameters: 
            ;   (None)
            ; Uses:
            ;   rf - destination pointer
            ; Returns: 
            ;   D = 0 (initial buffer index)
            ;-------------------------------------------------------                        
            proc  reset_buf
            push  rf
            
            load  rf, fbuf_idx        ; reset the current buffer
            ldi   0                   ; set to zero
            str   rf                  
            
            load  rf, spl_idx         ; set spill file name to __kilo.$00
            ldi   '0'                 ; ascii zero character
            str   rf                  ; set last two characters to ascii zero
            inc   rf
            str   rf
            
            pop   rf
            ldi   0                   ; set D to zero (buffer index)  
            return 
            endp
            
            ;-------------------------------------------------------
            ; Name: set_buf
            ;
            ; Set the buffer index to particular value 
            ;
            ; Parameters: 
            ;   rc.0 - new buffer index
            ; Uses:
            ;   rf - destination pointer
            ;   rd - buffer index for spill file name
            ; Returns: 
            ;   DF = 0 - buffer index changed
            ;   DF = 1 - buffer index not changed
            ;-------------------------------------------------------                        
            proc  set_buf
            push  rf
            push  rd
            
            load  rf, fbuf_idx        ; get the current buffer
            ldn   rf                  
            str   r2                  ; save in M(X)
            glo   rc                  ; get the new buffer index
            sm                        ; check for match
            lbz   sb_err              ; no change if match
            glo   rc                  ; else, get new index 
            str   rf                  ; save new value in memory
            
            load  rf, spl_idx         ; update index in spill file name
            glo   rc                  ; get new index
            plo   rd                  ; put in rd.0 for conversion
            
            call  f_hexout2           ; put hex value of index in sname
            
            clc                       ; clear DF for success
sb_exit:    pop   rd
            pop   rf  
            return 
sb_err:     stc
            lbr   sb_exit
            endp
            
            
            ;-------------------------------------------------------
            ; Name: next_spill
            ;
            ; Set index to the next spill file and load into the 
            ; text buffer.
            ;
            ; Parameters: 
            ;    (None)
            ; Uses:
            ;   rf - destination pointer
            ;   ra - line count
            ; Returns:
            ;    rb.0 - current character position
            ;    r8 - current line 
            ;    DF = 1 if error (no more buffers)
            ;    DF = 0 if no error (next buffer)
            ;-------------------------------------------------------                        

            proc  next_spill
            push  rf                  ; save registers used
            push  ra
            push  r9
                        
            load  rf, e_state         ; get editor state byte  
            ldn   rf            
            ani   BUFFER_CHG          ; check buffer changed bit
            lbz   nsp_cont            ; if no change, no need to save
              
            call  save_buffer         ; save current buffer to spill file
                        
nsp_cont:   call  next_buf            ; advance to next spill file buffer
            lbdf  nsp_last            ; if already at last buffer, just exit
            
nsp_load:   load  rf, spill_msg       ; show a message 
            call  set_status          
            call  prt_status          
            
            call  load_buffer         ; load new buffer
            copy  ra, r8              ; copy number of lines in buffer 
            call  set_num_lines       ; set the maximum line value in memory     
            ldi   0                   ; set line counter to first line
            phi   r8
            plo   r8

            call  setcurln            ; set the current line in text buffer
            call  find_line           ; get the current line

            ldn   ra                  ; get size of current line
            smi   2                   ; adjust for one past last character
            lbdf  nsp_size            ; if positive, set length
            ldi   0                   ; if negative, set length to zero
nsp_size:   phi   rb                  ; set rb.1 to new size
            call  put_line_buffer     ; put current line in line buffer

            call  set_row_offset      ; set row offset for the top of screen
            call  set_cursor

            call  flush_keys          ; flush the key buffer                                           
                        
            clc                       ; clear DF flag for return
            lbr   nsp_done
            
nsp_last:   stc
nsp_done:   pop   r9
            pop   ra
            pop   rf
            return                    
            endp
            
            ;-------------------------------------------------------
            ; Name: prev_spill
            ;
            ; Set index to the previous spill file and load into 
            ; the text buffer.
            ;
            ; Parameters: 
            ;    (None)
            ; Uses:
            ;   rf - destination pointer
            ;   ra - line count
            ; Returns:
            ;    rb.0 - current character position
            ;    r8 - current line 
            ;    DF = 1 if error (no more buffers)
            ;    DF = 0 if no error (next buffer)
            ;-------------------------------------------------------                        

            proc  prev_spill
            push  rf                  ; save registers used
            push  ra
            push  r9
            
            load  rf, e_state         ; get editor state byte  
            ldn   rf            
            ani   BUFFER_CHG          ; check buffer changed bit
            lbz   psp_cont            ; if no change, no need to save
              
            call  save_buffer         ; save current buffer to spill file
                        
psp_cont:   call  prev_buf            ; back up to previous spill file buffer
            lbdf  psp_first           ; if already at first buffer, just exit
            
psp_load:   load  rf, spill_msg       ; show a message 
            call  set_status          
            call  prt_status          
            
            call  load_buffer         ; load new buffer
            copy  ra, r8              ; copy number of lines in buffer 
            call  set_num_lines       ; set the maximum line value in memory 
                
                
            call  get_num_lines     ; get total number of lines in r8
            dec   r9                ; line index is one less than number of lines
            copy  r9,r8             ; set current line to last line
            call  setcurln          ; save the current line
            call  find_line         ; get the current line
            
            ldn   ra                ; get size of current line
            smi   2                 ; adjust for one past last character
            lbdf  psp_size          ; if positive, set length
            ldi   0                 ; if negative, set length to zero
psp_size:   phi   rb                ; set rb.1 to new size
            call  put_line_buffer   ; put current line in line buffer
            call  scroll_down       ; set top row to new value
    
            call  flush_keys        ; flush the key buffer                                           

            clc                     ; clear DF flag for return
            lbr   psp_done          ; exit routine
            
psp_first:  stc
psp_done:   pop   r9
            pop   ra
            pop   rf
            return                    
            endp

            ;-------------------------------------------------------
            ; Name: reset_spill
            ;
            ; Set index to the first spill file and load into the 
            ; text buffer.
            ;
            ; Parameters: 
            ;    (None)
            ; Uses:
            ;   rf - destination pointer
            ;   ra - line count
            ; Returns:
            ;    rb.0 - current character position
            ;    r8 - current line 
            ;    DF = 1 if error 
            ;    DF = 0 if no error
            ;-------------------------------------------------------                        

            proc  reset_spill
            push  rf                  ; save registers used
            push  ra
            push  r9
            
            load  rf, e_state         ; get editor state byte  
            ldn   rf            
            ani   BUFFER_CHG          ; check buffer changed bit
            lbz   rsp_cont            ; if no change, no need to save
              
            call  save_buffer         ; save current buffer to spill file
                        
rsp_cont:   call  reset_buf            ; advance to next spill file buffer
            
            load  rf, spill_msg       ; show a message 
            call  set_status          
            call  prt_status          
            
            call  load_buffer         ; load new buffer
            copy  ra, r8              ; copy number of lines in buffer 
            call  set_num_lines       ; set the maximum line value in memory     
            ldi   0                   ; set line counter to first line
            phi   r8
            plo   r8
            phi   rb                  ; clear out line length and character position
            plo   rb

            call  setcurln            ; set the current line in text buffer
            call  set_row_offset      ; set row offset for the top of screen
            call  set_cursor
            clc                       ; clear DF flag for return

            pop   r9
            pop   ra
            pop   rf
            return                    
            endp



            ;-------------------------------------------------------
            ; Name: set_spill
            ;
            ; Set index for a desired spill file and load into the 
            ; text buffer.
            ;
            ; Parameters: 
            ;   rc.0 - new buffer index
            ; Uses:
            ;   rf - destination pointer
            ;   ra - line count
            ;   r9 - scratch register
            ; Returns:
            ;   (None, spill file loaded into text buffer)
            ;-------------------------------------------------------                        

            proc  set_spill
            push  rf                  ; save registers used
            push  rd
            push  ra
            push  r9
            
            load  rf, e_state         ; get editor state byte  
            ldn   rf            
            ani   BUFFER_CHG          ; check buffer changed bit
            lbz   ssp_cont            ; if no change, no need to save
              
            call  save_buffer         ; save current buffer to spill file
                        
ssp_cont:   call  set_buf             ; set to desired spill file buffer
            lbdf  ssp_loaded          ; if already at last buffer, just exit
            
ssp_load:   copy  r8, r9              ; save row value to scratch register

            call  load_buffer         ; load new buffer
            copy  ra, r8              ; copy number of lines in buffer 
            call  set_num_lines       ; set the maximum line value in memory
            copy  r9, r8              ; restore row value     
                        
ssp_loaded: clc                       ; clear DF flag for return
            pop   r9
            pop   ra
            pop   rd
            pop   rf
            return                    
            endp
            
            ;-------------------------------------------------------
            ; Name: get_buf_line
            ;
            ; Get the line number of a line in a buffer
            ;
            ; Parameters: 
            ;   r9 - current line number
            ; Uses:
            ;   rf - destination pointer
            ;   rc - counter
            ;   
            ; Returns: 
            ;   r9 - absolute line number
            ;-------------------------------------------------------                        
            proc  get_buf_line
            push  rf                  ; save registers used
            push  rc
            
            
            load  rf, fbuf_idx        ; adjust line number for full buffers
            ldn   rf                  ; get buffer index from memory
            lbz   gbl_done            ; buffer zero is           
            plo   rc                  ; put in counter                                  
            
gbl_lp:     dec   rc                  ; count down buffer index
            ADD16 r9, BUF_LINES       ; add number of lines in full buffer
            glo   rc                  ; check the count
            lbnz  gbl_lp              ; keep going until out of buffers

gbl_done:   pop   rc                  ; restore registers used
            pop   rf  
            return                    
            endp
            
            
            
            ;-------------------------------------------------------
            ; Name: seek_buf_line
            ;
            ; If needed, load the buffer that contains the line.
            ;
            ; Parameters: 
            ;   rd - new line number
            ;   r8 - current row number
            ; Uses:
            ;   rf - destination pointer
            ;   rc - copy of current row
            ;   r9 - starting line of buffer
            ;   
            ; Returns: 
            ;   DF = 1, error
            ;   DF = 0, buffer loaded
            ;   r8 - updated row number in buffer
            ;-------------------------------------------------------                        
            proc  seek_buf_line
            push  rf                  ; save registers used
            push  rd
            push  rc            
            push  r9

            ldi   0                   ; clear out counter
            phi   rc
            plo   rc                  ; start buffer index at 0
            
sbl_lp:     copy  rd, r9              ; save current value as remainder            
            SUB16 rd, BUF_LINES       ; convert line number to buffer, row
            lbnf  sbl_conv            ; if negative, we went over
            
            inc   rc                  ; increment new buffer index
            lbr   sbl_lp              ; keep going until converted
            
sbl_conv:   load  rf, spill_cnt       ; get the spill count
            ldn   rf
            str   r2                  ; save in M(X)
            
            glo   rc                  ; get index for new buffer
            sd                        ; check for valid new index
            lbnf  sbl_err             ; error if new index > spill count
            
            copy  r9, r8              ; set remainder as new row                
            call  set_spill           ; rc.0 has new buffer index
            
            clc                       ; clear DF for success
sbl_exit:   pop   r9                  ; restore registers used
            pop   rc                  
            pop   rd
            pop   rf              
            return  
            
sbl_err:    stc                       ; clear DF for error
            lbr   sbl_exit
            endp
