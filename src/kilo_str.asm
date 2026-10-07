; -------------------------------------------------------------------
; String and message functions for the kilo editor
; -------------------------------------------------------------------
; Copyright 2025 by Gaston Williams
; -------------------------------------------------------------------


#include include/ops.inc
#include include/bios.inc
#include include/kernel.inc
#include include/kilo_def.inc
            
            extrn   status_msg
            extrn   status_cmd

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
; ***          String and Status Message Utilities                ***
; *******************************************************************

            ;-------------------------------------------------------
            ; Name: prt_status
            ;
            ; Print a status message at the bottom of the screen.
            ;-------------------------------------------------------                        
            proc  prt_status
            push  rf
          
            load  rf, status_cmd  ; move cursor to status line
            call  o_msg

;            call  o_inmsg         ; set cursor for status line
;              db 27,'[25;1H',0

            call  o_inmsg         ; set text colors to white on blue
              db 27,'[37;44m',0

            load  rf, status_msg  ; print the status message
            call  o_msg
              
            pop   rf
            return 
            endp

            ;-------------------------------------------------------
            ; Name: set_status
            ;
            ; Set the status message text at the bottom of 
            ; the screen.
            ;
            ; Parameters: 
            ;   rF - source msg text
            ; Uses:
            ;   rd - destination pointer
            ;   rc - character counter
            ; Returns: (None)
            ;-------------------------------------------------------                        
            proc  set_status
            push  rd
            push  rc
            
            call  window_width    ; get width in rc.0
            load  rd, status_msg  ; point to destination buffer
             
ps_copy:    lda   rf              ; get a character from message source string
            lbz   ps_fill         ; if reach end of string, pad with spaces
            str   rd
            inc   rd
            dec   rc              ; count down
            glo   rc              ; check counter if at eol
            lbz   ps_end          ; if we reach window length, stop adding characters
            lbr   ps_copy         ; keep going until end of string or window length
                     
ps_fill:    ldi   ' '             ; pad rest of buffer with spaces
            str   rd
            inc   rd
            dec   rc
            glo  rc  
            lbnz ps_fill          ; keep going to end of window length
            
ps_end:     ldi   27              ; end message with 27,'[0m',0
            str   rd
            inc   rd
            ldi   '['
            str   rd
            inc   rd
            ldi   '0'
            str   rd
            inc   rd
            ldi   'm'
            str   rd
            inc   rd
            ldi   0
            str   rd 
            
            pop   rc
            pop   rd
            return
            endp  
  
            ;-------------------------------------------------------
            ; Name: set_input
            ;
            ; Set the status message text with the current input
            ; string at the bottom of the screen.
            ;
            ; Parameters: 
            ;   rF - source msg text
            ; Uses:
            ;   rd - destination pointer
            ;   rc - character counter
            ; Returns: (None)
            ;-------------------------------------------------------                        
            proc  set_input
            push  rf
            push  rd
            push  rc
            
            call  window_width    ; get width in rc.0
            load  rd, status_msg  ; point to destination buffer
             
si_copy:    lda   rf              ; get a character from message source string
            lbz   si_pad          ; if reach end of string, pad with space
            str   rd
            inc   rd
            dec   rc              ; count down
            glo   rc              ; check counter if at eol
            lbz   si_end          ; if we reach window length, stop adding characters
            lbr   si_copy         ; keep going until end of string or window length
            
si_pad:     ldi   ' '             ; add one space 
            str   rd
            inc   rd
            dec   rc              ; count down
            glo   rc              ; check counter if at eol
            lbz   si_end          ; if we reach window length, stop adding characters
            
            load  rf, work_buf    ; point to current input string
si_inp:     lda   rf              ; get a character from input string
            lbz   si_fill         ; if reach end of string, fill with spaces
            str   rd
            inc   rd
            dec   rc              ; count down
            glo   rc              ; check counter if at eol
            lbz   si_end          ; if we reach window length, stop adding characters
            lbr   si_inp          ; keep going until end of input or window length
                     
si_fill:    ldi   ' '             ; pad rest of buffer with spaces
            str   rd
            inc   rd
            dec   rc
            glo   rc  
            lbnz  si_fill          ; keep going to end of window length
            
si_end:     ldi   27              ; end message with 27,'[0m',0
            str   rd
            inc   rd
            ldi   '['
            str   rd
            inc   rd
            ldi   '0'
            str   rd
            inc   rd
            ldi   'm'
            str   rd
            inc   rd
            ldi   0
            str   rd 
            
            pop   rc
            pop   rd
            pop   rf
            return
            endp  

            ;-------------------------------------------------------
            ; Name: pad_line
            ;
            ; Pad the text in the line buffer with spaces.
            ; 
            ; Parameters: 
            ;   D  - count of spaces to add to string
            ;   rb.1 - current line length
            ; Uses:
            ;   rf - buffer pointer
            ;   rc.0 - counter for bytes
            ; Returns: 
            ;   rb.1 - updated line length
            ;-------------------------------------------------------            
            proc  pad_line
            plo   re              ; save count in Elf/OS scratch register
            push  rf              ; save registers used
            push  rc
            
            glo   re              ; set low byte to space count
            plo   rc
            phi   rc              ; save count in high byte for later
            
            load  rf, line_buf    ; set buffer pointer
            ldi   $FF             ; set dirty flag to true
            str   rf
            inc   rf              ; rf now points to buffer string

pad_find:   lda   rf              ; find the null at end of buffer
            lbnz  pad_find
            dec   rf              ; back up to null 
            dec   rf              ; back up to CR                    
            dec   rf              ; back up to LF at end of buffer strign
            
pad_str:    glo   rc              ; get count value and check
            lbz   pad_done
            ldi   ' '             ; pad string with n spaces
            str   rf
            inc   rf
            dec   rc              ; count down
            lbr   pad_str

            ; write 10,13,0 after last padded space          
pad_done:   ldi   13            ; write CR (10)
            str   rf
            inc   rf
            ldi   10            ; write LF (13)
            str   rf
            inc   rf
            ldi   0             ; write NULL
            str   rf
            
            ghi   rc            ; get count  
            str   r2            ; save count at M(X) 
            ghi   rb            ; add count to line length
            add
            phi   rb            ; save updated length  
        
            pop   rc            ; restore registers
            pop   rf            
            return
            endp

            ;-------------------------------------------------------
            ; Name: kilo_status
            ;
            ; Set up a default status message.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ;   rd - integer value
            ;   rc - length of file name
            ; Returns:
            ;-------------------------------------------------------
            proc  kilo_status
            push  rf
            push  rd
            push  rc 
            
            ;------ default prompt comes first
            load  rf, ds_default
            load  rd, work_buf
ds_prompt:  lda   rf 
            lbz   ds_state        ; copy save prompt into buffer
            str   rd
            inc   rd
            lbr   ds_prompt
            
ds_state:   load  rf, e_state     ; check input mode bit
            ldn   rf              ; get editor state byte
            ani   MODE_BIT
            lbz   ds_insmode      ; default is insert mode
            load  rf, ds_over     ; set over-write message
            lbr   ds_mode
            
ds_insmode: load  rf, ds_insert   ; set insert message 
            
ds_mode:    lda   rf 
            lbz   ds_fname      
            str   rd              ; copy input mode msg into buffer
            inc   rd
            lbr   ds_mode
                            
ds_fname:   load  rf, fname       ; copy filename into status message 
            ldi   20
            plo   rc              ; limit to 20 characters
ds_fnloop:  lda   rf        
            lbz   ds_newfile      ; quit if end of string
            str   rd              ; put character in string
            inc   rd
            dec   rc              ; count down
            glo   rc
            lbnz  ds_fnloop       ; keep going until count exhausted
              
            
ds_newfile: load  rf, e_state     ; check new file bit
            ldn   rf              ; get editor state byte
            ani   NEWFILE_BIT     ; zero out all but new file bit
            lbz   ds_done         ; if bit is zero, skip new file message       
            
            load  rf, ds_newmsg   ; show new file message
ds_newloop: lda   rf 
            lbz   ds_done      
            str   rd              ; copy new file msg into buffer
            inc   rd
            lbr   ds_newloop
            
ds_done:    ldi   0
            str   rd              ; make sure string ends in null

            load  rf, work_buf    ; set status message to default message  
            call  set_status      ; set the status message
       
            pop   rc              ; restore registers
            pop   rd
            pop   rf 
            return 
ds_insert:    db '[Ins] ',0
ds_over:      db '<Over> ',0
ds_newmsg:    db ' (New)',0
ds_default:   db  '^X=exit, ^?=Help ',0
            endp
            
; *******************************************************************
; ***                    String Utilities                         ***
; *******************************************************************

            ;-------------------------------------------------------
            ; Name: strstr
            ;
            ; Find a target string within a source string.
            ;
            ; Parameters: 
            ;   rf - pointer to source string (haystack)
            ;   rd - pointer to target string (needle)
            ; Uses:
            ;   rf - source string pointer
            ;   rd - target string pointer
            ;   rc - offset value
            ;   rb - scratch register for target
            ;   r9 - scratch register for source
            ; Returns:
            ;   DF = 0, string not found (rf = 0, rc = 0) 
            ;   DF = 1, string found
            ;   rf - points to target string within source string
            ;   rc - offset to target string within source string
            ;-------------------------------------------------------            
            proc  strstr
            push  rd          ; save registers used
            push  rb          
            push  r9 

            ldi   0           ; set index to zero
            plo   rc
            phi   rc
            copy  rf, r9      ; save original source pointer  
            copy  rd, rb      ; save original target pointer
            lda   rd          ; get first character of target
            lbz   ss_found    ; if first target character is null, consider found
            str   r2          ; save target character in M(X) for comparison
            
ss_firstc:  lda   rf          ; get first character from source
            lbz   ss_notfnd   ; if no more source characters, not found
            sm                ; compare target character with source chracter 
            lbz   ss_match    ; if match look for rest of target string
            inc   rc          ; bump index for next source character
            lbr   ss_firstc   ; repeat to check next source character
            
ss_match:   lda   rd          ; get next character of target
            lbz   ss_found    ; if we no more target characters, we found it
            str   r2          ; save target character in M(X) for comparison         

            lda   rf          ; get second character in source
            lbz   ss_notfnd   ; if we run out of source characters, not found
            sm                ; compare source character to target
            lbz   ss_match    ; if matched, keep checking
            
            copy  r9, rf      ; if no match, restore source pointer 
            inc   rc          ; move index to next character location
            add16 rf, rc      ; move source pointer to next location
            
            copy  rb, rd      ; if no match, restore target pointer
            lda   rd          ; get first target character
            str   r2          ; save in M(X) for comparison
            lbr   ss_firstc   ; repeat to check next source character
            
ss_found:   copy  rb, rd      ; restore target pointer
            copy  r9, rf      ; restore source pointer
            add16 rf, rc      ; move source pointer to matching location
            stc               ; DF = 1, means target found in source
            lbr   ss_exit   

ss_notfnd:  ldi   0           ; set rf to NULL
            plo   rf
            phi   rf
            plo   rc          ; set index to 0
            phi   rc
            clc               ; DF = 0, means not found
ss_exit:    pop   r9          ; restore sratch registers
            pop   rb
            pop   rd  
            return 
            endp

            ;-------------------------------------------------------
            ; Name: isfnchar
            ;
            ; Check if character is valid character for an
            ; Elf/OS filename.
            ;
            ; Parameters: 
            ;   D - char to check
            ; Returns:
            ;   DF = 1, if valid filename character
            ;   DF = 0, if not valid
            ;-------------------------------------------------------
            ; Note: Only the uppercase letters A-Z, lowercase 
            ;   letters a-z, numbers 0-9, period, underscore and
            ;   forward slash are valid.
            ;-------------------------------------------------------
            proc  is_fnchar
            stxd                  ; save character on stack
            smi   '.'             ; period is first valid character
            lbnf  cfn_bad         ; characters before period are invalid
            lbz   cfn_ok          ; period is valid character
            
            smi   12              ; next invalid character is the colon
            lbnf  cfn_ok          ; forward slash and numbers 0 to 9 are valid
            lbz   cfn_bad         ; colon is invalid
            
            smi   7               ; next valid character is uppercase A
            lbnf  cfn_bad         ; punctuation characters before A are invalid
            lbz   cfn_ok          ; Capital A is valid
            
            smi   26              ; Left bracket is next invalid character           
            lbnf  cfn_ok          ; characters A to Z before left bracket are okay
            lbz   cfn_bad         ; Left brack is invalid
            smi   4               ; underscore is next valid character
            lbnf  cfn_bad         ; [, \, ] are invalid
            lbz   cfn_ok          ; underscore is valid
            
            smi   2               ; next valid character is a
            lbnf  cfn_bad         ; backtick is invalid
            lbz   cfn_ok          ; lowercase a is valid
            
            smi   26              ; left brace is next invalid character 
            lbnf  cfn_ok          ; lower case b-z are valid characters
            lbr   cfn_bad         ; left brace and everything else is not valid
            
cfn_ok:     ldi   1               ; valid character
            lskp
cfn_bad:    ldi   0               ; signal not valid
            shr                   ; shift result into DF
            irx                   ; recover original value
            ldx
            return                ; and return to caller
            endp           

            ;-------------------------------------------------------
            ; Name: set_status_cmd
            ;
            ; Set the ANSI status line cursor command in the buffer
            ;
            ; Parameters:
            ; Uses:
            ;   rd - number to convert 
            ;   r9 - screen height and width
            ;   rf - buffer pointer
            ;-------------------------------------------------------            
            proc  set_status_cmd
            push  rf                  ; save registers
            push  rd
            push  r9
            
            call  window_size         ; get window size values in r9
            
            load  rf, status_cmd      ; write to status command buffer
            ldi   27                  ; write escape to ANSI command
            str   rf                  
            inc   rf
            ldi   '['                 ; write CSI character to ANSI command
            str   rf
            inc   rf
            ldi   0                   ; set up for integer conversion
            phi   rd                  ; height is single byte value
            ghi   r9                  ; get window height value
            adi   01                  ; ANSI is one based, adjust for last line
            plo   rd                  ; rd now has integer value for status line
            call  f_uintout           ; convert height to ASCII string
            
            ldi   ';'                 ; print rest of ANSI command string
            str   rf
            inc   rf
            ldi   '1'                 ; cursor at column one of status line
            str   rf
            inc   rf
            ldi   'H'                 ; H ends the ANSI cursor command
            str   rf
            inc   rf
            ldi   0                   ; print null at end of command string
            str   rf            
             
            pop   r9                  ; restore registers
            pop   rd
            pop   rf
            return 
            endp
