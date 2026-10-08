# EDOS-kilo
A full screen editor for [ELF-DOS](https://github.com/arhefner/ELF-DOS), written in 1802 Assembly language. It is a port of the [Elf/OS kilo editor](https://github.com/fourstix/Elfos-kilo) by Gaston Williams, which is based loosely on the [Kilo editor](https://github.com/antirez/kilo) by Salvatore Sanfilippo aka antirez and the [Elfos-Edit editor](https://github.com/rileym65/Elf-Elfos-edit) by Mike Riley.

Platform
--------
The ELF-DOS kilo editor runs on an 1802 based Microcomputer running the ELF-DOS operating system, with an ANSI (VT100 style) terminal as the console. ELF-DOS runs on the same hardware as Elf/OS, such as the [Pico/Elf](http://www.elf-emulation.com/picoelf.html) by Mike Riley or the [1802-Mini](https://github.com/dmadole/1802-Mini) by David Madole.

Usage
-----
```
kilo filename
```
The file name may include a drive letter and a path, such as `D:/src/hello.asm`. If the file does not exist, the editor starts with an empty buffer and creates the file when it is saved. The exit code is 0, or 1 if the editor could not start.

Building
--------
The editor is assembled and linked with the [Asm/02](https://github.com/arhefner/Asm-02) assembler and [Link/02](https://github.com/arhefner/Link-02) linker, the same versions used to build ELF-DOS. The Makefile expects them in `/opt/elfc`; set `ASM` and `LINK` to use them from somewhere else.
```
make          # assemble src/*.asm and link ./kilo
make clean
```
Copy the `kilo` file that this produces into the `/bin` directory of an ELF-DOS volume.

`elfdos-sdk/` is a copy of the ELF-DOS SDK that the editor is built against; see `elfdos-sdk/MANIFEST.txt` for the ELF-DOS version it came from, and `elfdos-sdk/DEVELOPER_GUIDE.md` for the program interface. Rebuild the editor against a newer SDK if the ELF-DOS kernel's minor version changes.

Differences from the Elf/OS version
-----------------------------------
* File names can be a path of up to 79 characters on the command line. A new name entered with the Rename function can have up to 19 characters, and may contain a drive letter, a path and hyphens.
* Keys are always read through the ELF-DOS kernel, so the editor works with whatever console ELF-DOS is using. The circular key buffer for the hardware UART has been removed.
* Spill files are created in the current directory of the current drive.
* A save that fails part way through a large file is reported as an error.


Kilo Key Commands
-----------------
<table>
<tr><th>Keys</th><th>Command</th></tr>
<tr><td>Ctrl+J, Left</td><td>Move cursor Left</td></tr>
<tr><td>Ctrl+K, Right</td><td>Move cursor Right</td></tr>
<tr><td>Ctrl+U, Up</td><td>Move cursor Up</td></tr>
<tr><td>Ctrl+N, Down</td><td>Move cursor Down</td></tr>
<tr><td>Home</td><td>Move cursor to the beginning of line</td></tr>
<tr><td>End</td><td>Move to End of line</td></tr>
<tr><td>PgUp</td><td>Page up to previous screen</td></tr>
<tr><td>PgDn</td><td>Page down to next screen</td></tr>
<tr><td>Insert</td><td>Toggle insert/overwrite mode</td></tr>
<tr><td>Ctrl+D, Delete</td><td>Delete character</td></tr>
<tr><td>Ctrl+H, Backspace</td><td>Move back and delete character</td></tr>
<tr><td>Ctrl+I, Tab</td><td>Move forward to next tab stop</td></tr>
<tr><td>Ctrl+], Shift+Tab</td><td>Move back to previous tab stop</td></tr>
<tr><td>Ctrl+X</td><td>Exit, confirm if file changed</td></tr>
<tr><td rowspan="2">Ctrl+M, Enter</td><td>Insert Mode: insert new line or split at cursor</td></tr>
<tr><td>Overwrite Mode: Move down to the next line.</td></tr>
<tr><td>Ctrl+?, Ctrl-^ (See Note)</td><td>Show help information</td></tr>
<tr><th>Keys</th><th>Function Set</th></tr>
<tr><td>Ctrl+F</td><td>File Functions</td></tr>
<tr><td>Ctrl+P</td><td>Page Functions</td></tr>
<tr><td>Ctrl+L</td><td>Line Functions</td></tr>
<tr><td>Ctrl+C</td><td>Cursor Functions</td></tr>
</table>

Note:  On some older terminals the Ctrl+_ key combination replaces the Ctrl+? combination key for help.  Some emulators may support one key combination, or the other, or both.


Kilo File Functions
--------------------
<table>
<tr><th rowspan="5">Ctrl-F</th><th>Keys</th><th>Function</th></tr>
<tr><td>S</td><td>Save file</td></tr>
<tr><td>R</td><td>Rename and save file</td></tr>
<tr><td>Q</td><td>Save file and quit</td></tr>
<tr><td>X</td><td>Exit, confirm if file changed</td></tr>
</table>


Kilo Page Functions
-------------------
<table>
<tr><th rowspan="6">Ctrl-P</th><th>Keys</th><th>Function</th></tr>
<tr><td>U</td><td>page Up to previous screen</td></tr>
<tr><td>D</td><td>page Down to next screen</td></tr>
<tr><td>B</td><td>Move to Bottom of buffer</td></tr>
<tr><td>T</td><td>Move to Top of buffer</td></tr>
<tr><td>R</td><td>Refresh page on screen</td></tr>
</table>

Kilo Line Functions
-------------------
<table>
<tr><th rowspan="7">Ctrl-L</th><th>Keys</th><th>Function</th></tr>
<tr><td>C</td><td>Copy line to clip board</td></tr>
<tr><td>X</td><td>Cut line into clip board</td></tr>
<tr><td>V</td><td>Paste line from clip board</td></tr>
<tr><td>D</td><td>Delete line</td></tr>
<tr><td>J</td><td>Join lines</td></tr>
<tr><td>S</td><td>Split line at cursor</td></tr>
</table>

Kilo Cursor Functions
---------------------
<table>
<tr><th rowspan="7">Ctrl-L</th><th>Keys</th><th>Function</th></tr>
<tr><td>H</td><td>Move cursor to the beginning of line (Home)</td></tr>
<tr><td>E</td><td>Move to End of line</td></tr>
<tr><td>W</td><td>show Where cursor is located in file (See Note)</td></tr>
<tr><td>G</td><td>Go to line number (See Note)</td></tr
<tr><td>F</td><td>Find text</td></tr>
<tr><td>I</td><td>Toggle insert/overwrite mode</td></tr>
</table>

Note: The line numbers are calculated based on 96 rows per buffer.  If a buffer
has lines added or deleted, so that its number of rows is not 96, then calculated line number in following buffers will be off by the difference.


Kilo Text Modes
---------------
* **Insert Mode**
  * Characters are inserted into the text
  * Tab inserts spaces into the text
  * Enter inserts a new line at the beginning or end of a line
  * Enter splits a line at the cursor inside a line
  * Delete at the end of a line joins the current line with next line 
  * Backspace at the beginning of an empty line deletes the line
  * Line Split (Ctrl-L,S) will also insert lines or split a line
  * Line Join (Ctrl-L,J) will join lines
   
* **Overwrite Mode** 
  * Characters overwrite existing characters in the text
  * Tab moves the cursor to the next tab stop position
  * Enter moves down to the beginning of the next line
  * Delete and backspace do not delete empty lines automatically 
  * Line Split (Ctrl-L,S) at the beginning or end of a line will insert an empty line
  * Line Split (Ctrl-L,S) will split a line at the cursor inside a line
  * Line Join (Ctrl-L,J) will join lines
  * Line Delete (Ctrl-L,D) will delete a line

Copy, Cut & Paste
-----------------
* Line Copy (Ctrl-L,C) will copy a line into the clip board 
* Line Cut (Ctrl-L,X) will delete a line and copy into the clip board 
* Line Paste (Ctrl-L,V) will paste a line from the clip board and insert it above the current line

Text Limits
-----------
* Lines can have up to 124 characters per line
* Tabs are defined as 4 character tab stops (1, 5, 9, etc.)
  
File Limits
-----------
* Buffers are used to edit files larger than 96 lines 
* Each buffer has up to 96 lines
* A file can have up to 255 buffers
* Buffers are saved to temporary spill files, while the file is edited
* Spill files are created automatically when a large file is loaded 
* Spill files are named *__kilo.nn*, where nn is the 2 digit hex value of their index
* Spill files are deleted automatically when the application ends

Key Character Sequences
-----------------------
These key character sequences follow the VT102 terminal specification.  In the table below,
{ESC} is the Escape control character, ASCII 27, hex value $1B.  Should one of these keys not
behave as expected, you may need to configure your terminal program to return the expected
key character sequence. Note that the Delete key can have either one of two possible sequences.

<table>
<tr><th>Key</th><th>Character Sequence</th></tr>
<tr><td rowspan="2">Up (Arrow)</td><td>{ESC}[A</td></tr>
<tr><td>{ESC}A (See Note)</td></tr>
<tr><td rowspan="2">Down (Arrow)</td><td>{ESC}[B</td></tr>
<tr><td>{ESC}B (See Note)</td></tr>
<tr><td rowspan="2">Right (Arrow)</td><td>{ESC}[C</td></tr>
<tr><td>{ESC}C (See Note)</td></tr>
<tr><td rowspan="2">Left (Arrow)</td><td>{ESC}[D</td></tr>
<tr><td>{ESC}D (See Note)</td></tr>
<tr><td>Home</td><td>{ESC}[1~</td></tr>
<tr><td>Insert</td><td>{ESC}[2~</td></tr>
<tr><td rowspan="2">Delete</td><td>{ESC}[3~</td></tr>
<tr><td>DEL ($7F)</td></tr>
<tr><td>End</td><td>{ESC}[4~</td></tr>
<tr><td>PgUp</td><td>{ESC}[5~</td></tr>
<tr><td>PgDn</td><td>{ESC}[6~</td></tr>
<tr><td>Backspace</td><td>Ctrl+H ($08)</td></tr>
<tr><td>Tab</td><td>Ctrl+I ($09)</td></tr>
<tr><td>Shift+Tab</td><td>{ESC}[Z</td></tr>
<tr><td>Enter</td><td>Ctrl+M ($0D)</td></tr>
</table>

Note:  On some older DEC video terminals, the arrow keys send {ESC}A through 
{ESC}D instead of the ANSI sequences {ESC}[A through {ESC}[D.

Repository Contents
-------------------
* **/src/**  -- Source files for the ELF-DOS kilo editor.
  * kilo.asm - Main assembly source file.
  * kilo_file.asm - Assembly source file for file routines.
  * kilo_spill.asm - Assembly source file for spill file routines.
  * kilo_dos.asm - Assembly source file for calls to the ELF-DOS kernel file functions.
  * kilo_data.asm - Assembly source file data and buffers.
  * kilo_util.asm - Assembly source file for utility routines.
  * kilo_buf.asm - Assembly source file for buffer utility routines.
  * kilo_cfg.asm - Assembly source file for configuration utility routines.
  * kilo_prmpt.asm - Assembly source file for prompt and functions and help information.
  * kilo_str.asm - Assembly source file for string and message functions.
  * kilo_keys.asm - Assembly source file for main key handler and save routines.
  * kilo_text.asm - Assembly source file for text key handler routines.
  * kilo_edit.asm - Assembly source file for text editing key handler routines.
  * kilo_line.asm - Assembly source file for line editing key handler routines.
  * kilo_move.asm - Assembly source file for cursor movement key handler routines.
  * kilo_input.asm - Assembly source file for input and confirmation functions.
  * kilo_dbg.inc - Assembly source file for optionally included debug functions.
* **/src/include/**  -- Include files for the editor.  
  * kilo_def.inc - Definitions for the kilo source files.
* **/elfdos-sdk/**  -- The ELF-DOS SDK: kernel, BIOS and opcode definitions, library modules and the Developer's Guide.
* **Makefile** -- Builds the editor.

References
----------
* [ANSI Escape Sequences](https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797)
* [Wikipedia ANSI escape code](https://en.wikipedia.org/wiki/ANSI_escape_code)
* [VT102 User Guide](https://vt100.net/docs/vt102-ug/)
* [VT102, VT100 and other DEC Video Terminals](https://vt100.net/)
* [Build Your Own Text Editor](https://viewsourcecode.org/snaptoken/kilo/index.html)
* [Antirez Kilo Editor](http://antirez.com/news/108)

License Information
-------------------
This code is public domain under the MIT License, but please buy me a beverage
if you use this and we meet someday (Beerware).

References to any products, programs or services do not imply
that they will be available in all countries in which their respective owner operates.

Any company, product, or services names may be trademarks or services marks of others.

All libraries used in this code are copyright their respective authors.

This code is based on a Elf/OS kernel written by Mike Riley and created with the Asm/02 assembler and Link/02 linker also written by Mike Riley.

Elf/OS kilo editor 
Copyright (c) 2025 by Gaston Williams

ELF-DOS 
Copyright (c) 2026 by Tony Hefner

Elf/OS 
Copyright (c) 2004-2025 by Mike Riley

Mini/DOS 
Copyright (c) 2024-2025 by David Madole

Kilo Editor 
Copyright (c) 2016-2025 by Salvatore Sanfilippo

Elf-Elfos-Edit 
Copyright (c) 2004-2025 by Mike Riley

Asm/02 1802 Assembler 
Copyright (c) 2004-2025 by Mike Riley

Link/02 1802 Linker 
Copyright (c) 2004-2025 by Mike Riley

VT102 User Guide 
Copyright (c) 1982 by Digital Equipment Corporation

Many thanks to the original authors for making their designs and code available as open source.
 
This code, firmware, and software is released under the [MIT License](http://opensource.org/licenses/MIT).

The MIT License (MIT)

Copyright (c) 2025 by Gaston Williams

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

**THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.**
