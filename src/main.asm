format MS64 COFF

public start as 'main'
extrn SDL_Init
extrn SDL_CreateWindow
extrn SDL_DestroyWindow
extrn SDL_Quit
extrn SDL_PollEvent
extrn SDL_Log
extrn SDL_GetError
extrn printf

width = 1280
height = 720
SDL_INIT_VIDEO = 0x20
SDL_WINDOW_VULKAN = 0x0000000010000000

; first var at rbp + 0x8

section '.text' code readable executable

start:
    push rbp
    mov rbp, rsp
    sub rsp, 0x40 + 0x80 ;0x80 -> SDL_Event

    ; SDL_Init
    mov rcx, SDL_INIT_VIDEO
    call SDL_Init
    call check_sdl_error
    test eax, eax
    jz .L_quit

    ; SDL_CreateWindow
    lea rcx, [window_title]
    mov rdx, width
    mov r8, height
    mov r9, SDL_WINDOW_VULKAN
    call SDL_CreateWindow
    mov [sdl_window], rax
    call check_sdl_error
    test eax, eax
    jz .L_quit

.L_event_loop:

.L_poll_event:
    lea rcx, [rbp - 0x8] ; first var on the stack, SDL_Event
    call SDL_PollEvent
    mov edx, [rbp - 0x8] ; event.type
    cmp edx, 0x100 ; SDL_EVENT_QUIT
    je .L_quit
    test rax, rax
    jnz .L_poll_event

    jmp .L_event_loop


.L_quit:
    mov rcx, [sdl_window]
    test rcx, rcx
    jz .L_quit1
    call SDL_DestroyWindow
.L_quit1:
    call SDL_Quit

    add rsp, 0x40 + 0x80
    pop rbp
    ret

check_sdl_error:
    sub rsp, 0x28 ; 0x20 shadow space, 0x8 alignment to 16 bytes
    test rax, rax
    jz .L_sdl_error
    mov rax, 1
    jmp .L_check_sdl_error_end
.L_sdl_error:
    call SDL_GetError
    lea rcx, [log_sdl_error]
    mov rdx, rax
    mov r8, rax
    call SDL_Log
    mov rax, 0
.L_check_sdl_error_end:
    add rsp, 0x28
    ret


section '.data' data readable writeable
    sdl_window       dq 0

    window_title     db "ASM SDL Window!", 0
    log_sdl_success  db "Function executed successfully", 0
    log_return       db "Function returned %d", 0
    log_sdl_error    db "SDL Error occured: %s (0x%llX)", 0

    
