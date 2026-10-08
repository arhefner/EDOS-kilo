; -------------------------------------------------------------------
; ELF-DOS file functions for the kilo editor
; -------------------------------------------------------------------
; The ELF-DOS kernel file calls only preserve the registers named in
; their own descriptions, while the editor keeps its state in r7-rb
; across file operations.  These routines call the kernel on behalf 
; of the editor and restore the registers the kernel may have used.
; -------------------------------------------------------------------

#include include/opcodes.def
#include include/bios.inc
#include include/kernel_api.inc
#include include/kilo_def.inc

            ;-------------------------------------------------------
            ; Name: dos_open
            ;
            ; Open a file.  The file control block must be followed
            ; immediately by its 512 byte sector buffer.
            ;
            ; Parameters: 
            ;   rf - pointer to file name
            ;   rd - pointer to file control block
            ;   D  - mode, 0 = read, 1 = write (create and truncate)
            ; Uses:
            ;   re.0 - scratch register
            ; Returns:
            ;   DF = 0, file opened
            ;   DF = 1, file not opened
            ;-------------------------------------------------------                       
            proc  dos_open
            plo   re            ; save mode in scratch register
            push  rf            ; save registers used by kernel
            push  rd
            push  rc
            push  rb
            push  ra
            push  r9
            push  r8
            push  r7

            glo   rd            ; sector buffer follows control block
            adi   FCB_LEN
            plo   ra
            ghi   rd
            adci  0
            phi   ra
            glo   re            ; get mode for open
            call  K_FILE_OPEN

            pop   r7            ; restore registers
            pop   r8
            pop   r9
            pop   ra
            pop   rb
            pop   rc
            pop   rd
            pop   rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: dos_close
            ;
            ; Close an open file.
            ;
            ; Parameters: 
            ;   rd - pointer to file control block
            ; Returns:
            ;   DF = 0, file closed
            ;   DF = 1, an error occurred when closing file
            ;-------------------------------------------------------                       
            proc  dos_close
            push  rf            ; save registers used by kernel
            push  rd
            push  rc
            push  rb
            push  ra
            push  r9
            push  r8
            push  r7

            call  K_FILE_CLOSE

            pop   r7            ; restore registers
            pop   r8
            pop   r9
            pop   ra
            pop   rb
            pop   rc
            pop   rd
            pop   rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: dos_read
            ;
            ; Read bytes from an open file.
            ;
            ; Parameters: 
            ;   rd - pointer to file control block
            ;   rf - pointer to buffer for bytes
            ;   rc - number of bytes to read
            ; Returns:
            ;   rc - number of bytes read (zero at end of file)
            ;   DF = 0, bytes read
            ;   DF = 1, an error occurred when reading file
            ;-------------------------------------------------------                       
            proc  dos_read
            push  rf            ; save registers used by kernel
            push  rd
            push  rb
            push  ra
            push  r9
            push  r8
            push  r7

            call  K_FILE_READ
            lbnf  dr_done       ; DF = 0, count in rc is good

            ldi   0             ; no bytes read after an error
            phi   rc
            plo   rc

dr_done:    pop   r7            ; restore registers
            pop   r8
            pop   r9
            pop   ra
            pop   rb
            pop   rd
            pop   rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: dos_write
            ;
            ; Write bytes to an open file.
            ;
            ; Parameters: 
            ;   rd - pointer to file control block
            ;   rf - pointer to bytes to write
            ;   rc - number of bytes to write
            ; Returns:
            ;   DF = 0, bytes written
            ;   DF = 1, an error occurred when writing file
            ;-------------------------------------------------------                       
            proc  dos_write
            push  rf            ; save registers used by kernel
            push  rd
            push  rc
            push  rb
            push  ra
            push  r9
            push  r8
            push  r7

            call  K_FILE_WRITE

            pop   r7            ; restore registers
            pop   r8
            pop   r9
            pop   ra
            pop   rb
            pop   rc
            pop   rd
            pop   rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: dos_delete
            ;
            ; Delete a file.
            ;
            ; Parameters: 
            ;   rf - pointer to file name
            ; Returns:
            ;   DF = 0, file deleted
            ;   DF = 1, file not deleted
            ;-------------------------------------------------------                       
            proc  dos_delete
            push  rf            ; save registers used by kernel
            push  rd
            push  rc
            push  rb
            push  ra
            push  r9
            push  r8
            push  r7

            call  K_FILE_DELETE

            pop   r7            ; restore registers
            pop   r8
            pop   r9
            pop   ra
            pop   rb
            pop   rc
            pop   rd
            pop   rf
            return
            endp
