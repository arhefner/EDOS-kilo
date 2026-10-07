; -------------------------------------------------------------------
; Circular key buffer for the kilo editor
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
;                       Circular Key Buffer                       ***
; *******************************************************************

            ;-------------------------------------------------------
            ; Name: get_key
            ;
            ; Read a key from either directly from the bit-banged
            ; serial interface or from the hardware UART using a
            ; circular buffer.  
            ; 
            ; Parameters: 
            ; Uses: 
            ;   rf - buffer pointer
            ; Returns:
            ;   D - character read
            ;-------------------------------------------------------       
.link  .align 128             
            proc  get_key
            
            ; ******************************************************************
            ; ***              Check if circular buffer in use               ***
            ; ******************************************************************
            load  rf, e_state     ; check key buffer bit in state byte
            ldn   rf
            ani   KBIO_BIT        ; zero out all but kbio bit
            lbz   o_readkey       ; delegate to kernel function if no buffer
            
            ; ******************************************************************
            ; ***  Read characters from the hardware serial UART port using  ***
            ; **   a circular buffer.  This routine is based on code written ***
            ; ***  by David Madole in his studio serial driver.  Available   ***
            ; ***  on GitHub: https://github.com/dmadole/Elfos-studio
            ; ******************************************************************            

gk_read:    call  f_utest         ; check for incoming serial character
            bnf  gk_get           ; if no more keys available, get key from buffer 
                     
            call  f_uread         ; get character
            plo   re              ; save key in scratch register
            
            ; ******************************************************************
            ; ***             Put character in circular buffer               ***
            ; ******************************************************************

            load  rf, keytail     ; set rf to tail pointer            
            lda   rf              ; get tail, move to head 
            adi   1               ; increment tail porter
            
            sdi   keypast.0       ; check if we went past end of the buffer
            bnz   gk_put          ; if we haven't reached the end we are good 
                                  
            ldi   KEY_BUF_SIZE    ; wrap around, keybuf.0 = keypast.0 - size                                            
                        
gk_put:     sdi   keypast.0       ; recover tail+1 value
            sex   rf              ; compare tail+1 to head
            sd                    ; if tail = head, then buffer is full
            bz    gk_get          ; if full, don't add any more 
            
            sd                    ; recover tail value
            sex   r2              ; make sure x = 2 for Elf/OS
            
            dec   rf              ; move back to tail ptr
            str   rf              ; store new value in tail
            plo   rf              ; set pointer to tail of buffer
            glo   re              ; get character read from serial
            str   rf              ; save in buffer
            
            call  f_utest         ; check for more serial character
            bdf   gk_read         ; if another came in, read into buffer
                        

            ; ******************************************************************
            ; ***            Get character from circular buffer              ***
            ; ******************************************************************
gk_get:     load  rf, keytail     ; set rf to tail pointer
            sex   rf              ; set x = rf for comparisons
            lda   rf              ; if head pointer is same as tail,
            xor                   ; then buffer is empty
            sex   r2              ; set x back to r2 
            bz    gk_read         ; if empty, read from serial
            
            ldn   rf              ; get head ptr
            adi   1               ; increment head pointer

            sdi   keypast.0       ; check if we went past the buffer
            bnz   gk_good         ; if we haven't reached the end we are good 
                      
            ldi   KEY_BUF_SIZE    ; wrap around, keybuf.0 = keypast.0 - size             
           
gk_good:    sdi   keypast.0       ; recover head value
            str   rf              ; update head pointer, then read
            plo   rf              ; the data byte the head pointer
            ldn   rf              ; points to as the character
            return
            
keytail:      db keybuf.0           ; end of circular buffer
keyhead:      db keybuf.0           ; beginning of circular buffer
keybuf:       db 0                  ; circular buffer starts here
              ds KEY_BUF_SIZE - 1   ; padding for rest of buffer entries
keypast:      db 0                  ; one byte past buffer end
              public  keytail
              public  keybuf
            endp   

            ;-------------------------------------------------------
            ; Name: flush_keys
            ;
            ; Read any keys available on the hardware UART and clear
            ; the circular buffer.  
            ; 
            ; Parameters: 
            ; Uses: 
            ;   rf - buffer pointer
            ; Returns: (none)
            ;   character read
            ;-------------------------------------------------------       
            proc  flush_keys
            load  rf, e_state     ; check if key buffer in use
            ldn   rf
            ani   KBIO_BIT        ; zero out all but key buffer io bit
            lbz   fk_exit         ; exit if no key buffer in use
            
fk_chk:     call  f_utest         ; check for incoming serial character
            bnf   fk_reset        ; if no more keys available, reset buffer 
                                 
            call  f_uread         ; get character
            lbr   fk_chk          ; keep going until no more incoming characters
                                    
fk_reset:   load  rf, keytail
            ldi   keybuf.0        ; reset head and tail to buffer beginning
            str   rf              ; reset keytail
            inc   rf
            str   rf              ; reset keyhead
            inc   rf
            ldi   0
            str   rf              ; reset key buffer data
            
fk_exit:    return            
            endp
