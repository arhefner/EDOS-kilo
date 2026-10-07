; -------------------------------------------------------------------
; Spill file functions for the kilo editor
; -------------------------------------------------------------------
; Copyright 2025 by Gaston Williams
; -------------------------------------------------------------------

#include include/ops.inc
#include include/bios.inc
#include include/kernel.inc
#include include/kilo_def.inc

            extrn   textbuf
            extrn   curline
            extrn   fildes
            extrn   k_dta
            extrn   readln
            extrn   readbyte
            extrn   k_char
            extrn   sfldes
            extrn   s_dta
            
            ;-------------------------------------------------------
            ; Name: load_buffer
            ;
            ; Open a spill file and read it into the text buffer
            ;
            ; Parameters: (file name in fname buffer) 
            ; Uses:
            ;   rf - pointer to text bytes
            ;   rd - pointer to file descripter
            ;   ra - line count
            ;   rc.0 - byte count
            ;   r7.0 - flags register
            ; Returns:
            ;   ra.0 = count of lines
            ;   DF = 1 - not loaded (new file or error)
            ;   DF = 0 - file loaded into buffer
            ;-------------------------------------------------------                       
            proc  load_buffer
            push  rf            ; save registers used    
            push  rd
            push  rc
            push  rb
            push  r7  

            load  rf, sname     ; spill file name
            load  rd, sfldes    ; point to spill file descriptor     
            ldi   0             ; flags
            plo   r7
            call  o_open        ; attempt to open the file
            lbdf  lb_none       ; exit immediately, if file does not exist
                        
            load  rf, textbuf   ; point to text buffer
            ldi   0             ; load entire buffer
            plo   rb            ; set limit to read all lines in buffer
            call  load_text     ; load spill file into text buffer

            call  o_close       ; close the file
            clc                 ; clear the DF flag
lb_none:    pop   r7            ; restore registers
            pop   rb
            pop   rc
            pop   rd
            pop   rf
            return
            endp
          
            ;-------------------------------------------------------
            ; Name: setup_spill
            ;
            ; Create spill files for editing a large file
            ;   
            ; Parameters:
            ;   (None) 
            ; Uses:
            ;   rf - destination pointer
            ;   rd - File descripter
            ;   rc - flags for open and write
            ;   rc - counter for reading and writing data 
            ;   r7 - flags register
            ;
            ; Returns: 
            ;    DF = 1 if error, 0 if no error
            ;-------------------------------------------------------                        
            proc  setup_spill
            push  rf            ; save registers used
            push  rd
            push  rc
            push  rb
            push  r7


            load  rf, spill_cnt ; reset spill count
            ldn   rf
            ldi   0
            str   rf  
            
            call  reset_buf     ; reset buffer index and spill file name

            call  save_buffer   ; save the initial buffer as spill file 0
            lbnf  susp_lp       ; if saved okay, keep going           

            load  rf, e_state   ; get editor state byte  
            ldn   rf            
            ori   ERROR_BIT     ; set error bit
            str   rf            ; update editor state byte           
            lbr   susp_exit     ; exit immediately, with error
            
susp_lp:    load  rf, spill_cnt ; increment the spill count
            ldn   rf
            adi   1
            str   rf  

            load  rf, spill_msg ; show message when inializing
            call  o_msg
            
            call  o_inmsg       ; print crlf
              db 10,13,0
              
            call  next_buf      ; create next buffer

            load  rf, spl_idx   ; show spill index when inializing
            call  o_msg
            
            call  o_inmsg       ; print crlf
              db 10,13,0
            
            load  rf, textbuf   ; point to text buffer
            load  rd, fildes    ; point to file descriptor
            ldi   BUF_LINES     ; default buffer size
            plo   rb            ; set limit to read up to maximum lines               
            call  load_text 
            lbnf  susp_done     ; if we finished reading, we're done
                      
            call  save_buffer   ; save the buffer as spill file
                        
            lbnf  susp_lp       ; loop back if no errors


susp_done:  call  save_buffer   ; save last spill
            call  reset_buf     ; set back to spill file zero
            call  load_buffer   ; load spill file zero into text buffer
susp_ok:    clc 
            
susp_exit:  pop   r7
            pop   rb
            pop   rc
            pop   rd
            pop   rf  
            return                    
            endp

            ;-------------------------------------------------------
            ; Name: teardown_spill
            ;
            ; Delete spill files after editing a large file
            ;   
            ; Parameters:
            ;   (None) 
            ; Uses:
            ;   rf - destination pointer
            ;
            ; Returns: 
            ;    DF = 1 if error, 0 if no error
            ;-------------------------------------------------------                        
            proc  teardown_spill
            push  rf            ; save registers used

            call  reset_buf     ; reset buffer index and spill file name

tdsp_lp:    load  rf, sname     ; point to filename
            call  o_delete      ; delete the file
            lbdf  tdsp_exit     ; exit if error
            call  next_buf      ; increment buffer index and set spill file name
            lbnf  tdsp_lp       ; keep going until index at spill count 
                       
            clc                 ; clear DF for success  
tdsp_exit:  pop   rf
            return                    
            endp

            ;-------------------------------------------------------
            ; Name: copy_buffer
            ;
            ; Copy a spill file to a file.

            ; Parameters: (file name in fname buffer) 
            ; Uses:
            ;   rf - pointer to text bytes
            ;   rd - pointer to file descripter
            ;   rc - byte count
            ;   r7.0 - flags register
            ; Returns: 
            ;   DF = 0, buffer saved successfully
            ;   DF = 1, an error occurred when saving buffer
            ;-------------------------------------------------------                       
            proc  copy_buffer    
            push  rf            ; save registers used in save
            push  rd
            push  rc
            push  r7

            load  rf, sname     ; point to filename
            load  rd, sfldes    ; point to file descriptor
            ldi   0             ; flags for read, don't create
            plo   r7
            call  o_open        ; open the spill file
            lbdf  cb_exit       ; if we can't open file exit with error

cb_lp:      load  rc, 255       ; want to read 255 bytes
            load  rf, work_buf  ; buffer to retrieve data
            load  rd, sfldes    ; set descriptor
          
            call  o_read        ; read the block
            lbdf  cb_err        ; if can't read, exit with error
          
            glo   rc            ; check for zero bytes read
            lbz   cb_done       ; jump if so
          
            load  rf, work_buf  ; buffer to rettrieve data
            load  rd, fildes    ; set file descriptor

            call  o_write       ; write to destination file
            lbnf  cb_lp         ; loop back if no errors
         

cb_err:     call  o_close       ; attempt to close open file
            stc                 ; set DF=1 for error
            lbr   cb_exit       ; exit with error
            
cb_done:    call  o_close       ; close the file
            
            load  rf, e_state   ; get editor state byte  
            ldn   rf            
            ani   BUFFER_MASK   ; clear buffer changed bit
            str   rf            ; update editor state byte            
            clc                 ; clear DF flag for successful return
            
cb_exit:    pop   r7            ; restore registers used
            pop   rc
            pop   rd
            pop   rf 
            return 
            endp
  
            ;-------------------------------------------------------
            ; Name: save_buffer
            ;
            ; Save the text buffer to a file.

            ; Parameters: (file name in fname buffer) 
            ; Uses:
            ;   rf - pointer to text bytes
            ;   rd - pointer to file descripter
            ;   rc - byte count
            ;   r7.0 - flags register
            ; Returns: 
            ;   DF = 0, buffer saved successfully
            ;   DF = 1, an error occurred when saving buffer
            ;-------------------------------------------------------                       
            proc  save_buffer    
            push  rf            ; save registers used in save
            push  rd
            push  rc
            push  r7

            load  rf, sname     ; point to filename
            load  rd, sfldes    ; point to file descriptor
            ldi   3             ; flags for open, create, truncate
            plo   r7
            call  o_open        ; open the file
            lbdf  sb_exit       ; if we can't open file exit with error
            
            load  rf, textbuf   ; point to text buffer
            load  rd, sfldes    ; point to file descriptor
            call  save_text     ; save buffer text to file
            lbdf  sb_err        
            
sb_dn:      call  o_close       ; close the file
            
            load  rf, e_state   ; get editor state byte  
            ldn   rf            
            ani   BUFFER_MASK   ; clear buffer changed bit
            str   rf            ; update editor state byte            
            clc                 ; clear DF flag for successful return
sb_exit:    pop   r7            ; restore registers used
            pop   rc
            pop   rd
            pop   rf 
            return 
            
sb_err:     call  o_close       ; attempt to close open file
            stc                 ; set DF=1 for error
            lbr   sb_exit       ; exit with error
            endp
