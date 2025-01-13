format MS64 COFF

public start as 'main'
extrn SDL_Init
extrn SDL_CreateWindow
extrn SDL_DestroyWindow
extrn SDL_CreateRenderer
extrn SDL_DestroyRenderer
extrn SDL_Quit
extrn SDL_SetRenderDrawColor
extrn SDL_RenderClear
extrn SDL_RenderPresent
extrn SDL_SetWindowTitle
extrn SDL_PollEvent
extrn SDL_WaitEvent
extrn SDL_Log
extrn SDL_GetError
extrn SDL_Vulkan_CreateSurface
extrn SDL_Vulkan_DestroySurface
extrn SDL_Vulkan_GetInstanceExtensions
extrn vkCreateInstance
extrn vkDestroyInstance
extrn vkEnumeratePhysicalDevices
extrn vkGetPhysicalDeviceProperties
extrn vkGetPhysicalDeviceQueueFamilyProperties
extrn malloc
extrn free

width = 1280
height = 720
SDL_INIT_VIDEO = 0x20
SDL_WINDOW_VULKAN = 0x0000000010000000

SHADOW_SPACE = 0x20

;struc Environment {
;    .window dq 0
;    .surface dq 0
;    .vk_instance dq 0
;    .vk_pysicaldevice dq 0
;}

;struc SDL_Event {
;    .reserved rb 0x80 ; size of the SDL_Event struct in C
;}

section '.text' code readable executable

start:
    push rbp
    mov rbp, rsp
    sub rsp, 0x20 + 0x80 + SHADOW_SPACE ;0x20 -> Environment, 0x80 -> SDL_Event, 0x20 -> Shadow Space

    lea rcx, [rbp - 0x20] ; Environment
    call init
    test eax, eax
    jz .L_quit

.L_event_loop:

.L_poll_event:
    lea rcx, [rbp - 0xA0] ; first var on the stack, SDL_Event
    call SDL_PollEvent
    mov edx, [rbp - 0xA0] ; event.type
    cmp edx, 0x100 ; SDL_EVENT_QUIT
    je .L_quit
    test rax, rax
    jnz .L_poll_event

    ;render everything here

    jmp .L_event_loop


.L_quit:
    mov rcx, [rbp - 0x10] ; environment.instance
    mov rdx, 0
    test rcx, rcx
    jz .L_quit1
    call vkDestroyInstance

.L_quit1:
    mov rcx, [rbp - 0x20] ; environment.window
    test rcx, rcx
    jz .L_quit2
    call SDL_DestroyWindow

.L_quit2:
    call SDL_Quit

    add rsp, 0x20 + 0x80 + SHADOW_SPACE
    pop rbp
    ret

check_sdl_error:
    sub rsp, 0x28 ; 0x20 shadow space, 0x8 alignment to 16 bytes
    test rax, rax
    jz .L_sdl_error
    mov eax, 1
    jmp .L_check_sdl_error_end
.L_sdl_error:
    call SDL_GetError
    lea rcx, [log_sdl_error]
    mov rdx, rax
    call SDL_Log
    mov eax, 0
.L_check_sdl_error_end:
    add rsp, 0x28
    ret

check_vulkan_error:
    sub rsp, 0x28 ; 0x20 shadow space, 0x8 alignment to 16 bytes
    test rax, rax
    jnz .L_vulkan_error
    mov eax, 1
    jmp .L_check_vulkan_error_end
.L_vulkan_error:
    lea rcx, [log_vulkan_error]
    mov rdx, rax
    call SDL_Log
    mov eax, 0
.L_check_vulkan_error_end:
    add rsp, 0x28
    ret

init:
    push rbp
    mov rbp, rsp
    sub rsp, 0x30 + 0x40 + 0x10 + SHADOW_SPACE ; VkApplicationInfo + VkInstanceCreateInfo + uint32 + uint32 + SHADOW_SPACE
    
    ; move arg to shadow space
    mov [rbp + 0x10], rcx
    
    ; SDL_Init
    mov rcx, SDL_INIT_VIDEO
    call SDL_Init
    call check_sdl_error
    test eax, eax
    jz .L_init_fail

    ; SDL_CreateWindow
    lea rcx, [window_title]
    mov rdx, width
    mov r8, height
    mov r9, SDL_WINDOW_VULKAN
    call SDL_CreateWindow
    mov rcx, [rbp + 0x10]
    mov [rcx], rax
    call check_sdl_error
    test eax, eax
    jz .L_init_fail

    ; set up VkApplicationInfo
    mov DWORD [rbp - 0x30], 0x0              ; .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
    mov QWORD [rbp - 0x28], 0x0              ; .pNext = NULL
    
    lea rax, [vk_app_name]
    mov [rbp - 0x20], rax                    ; .pApplicationName = "Vulkan App"
    
    mov DWORD [rbp - 0x18], 0x400000         ; .applicationVersion = VK_MAKE_VERSION(1, 0, 0)
    
    lea rax, [vk_engine_name]
    mov [rbp - 0x10], rax                    ; .pEngineName = "No Engine"

    mov DWORD [rbp - 0x08], 0x400000         ; .engineVersion = VK_MAKE_VERSION(1, 0, 0)
    mov DWORD [rbp - 0x04], 0x403000         ; .apiVersion = VK_API_VERSION_1_3

    ; set up VkInstanceCreateInfo
    mov DWORD [rbp - 0x70], 0x1              ; .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
    mov QWORD [rbp - 0x68], 0x0              ; .pNext = NULL
    mov DWORD [rbp - 0x60], 0x0              ; .flags = 0

    lea rax, [rbp - 0x30]
    mov [rbp - 0x58], rax                    ; .pApplicationInfo = &applicationInfo (rbp - 0x30)

    mov DWORD [rbp - 0x50], 0x0              ; .enabledLayerCount = 0
    mov QWORD [rbp - 0x48], 0x0              ; .ppEnabledLayerNames = NULL

    lea rcx, [rbp - 0x74]                    ; &count
    call SDL_Vulkan_GetInstanceExtensions
    mov ecx, [rbp - 0x74]
    mov [rbp - 0x40], ecx                    ; .enabledExtensionCount = enabled_extension_count
    mov [rbp - 0x38], rax                    ; .ppEnabledExtensionNames = extension_names

    ; call vkCreateInstance
    lea rcx, [rbp - 0x70] ; createInfo = &createInfo
    mov rdx, 0            ; Allocator = NULL
    mov r9, [rbp + 0x10]
    lea r8, [r9 + 0x10]   ; instance = &instance
    call vkCreateInstance
    call check_vulkan_error
    test rax, rax
    jz .L_init_fail

    ; call vkEnumeratePhysicalDevices to count devices
    mov r9,  [rbp + 0x10]
    mov rcx, [r9 + 0x10] ; instance
    lea rdx, [rbp - 0x74] ; &device_count
    mov r8, 0x0
    call vkEnumeratePhysicalDevices

    ; malloc space for devices amount
    mov ecx, [rbp - 0x74] 
    shl ecx, 0x3 ; device_count << 3 (same as device_count * 8)
    call malloc
    test rax, rax
    jz .L_init_fail
    mov [rbp - 0x80], rax

    ; read in devices
    mov r9,  [rbp + 0x10]
    mov rcx, [r9 + 0x10] ; instance
    lea rdx, [rbp - 0x74] ; &device_count
    mov r8, rax
    call vkEnumeratePhysicalDevices
    
    push rsi
    push rdi
    sub rsp, 0x20 ; shadow space because we pushed registers onto the stack
    mov rsi, 0           ; i = 0
    mov rdi, [rbp - 0x80]
.L_device_loop:
    cmp rsi, [rbp - 0x74] ; device_count
    jge .L_device_loop_end

    mov rcx, [rdi + rsi * 0x8]
    call print_device_info

    mov rcx, [rdi + rsi * 0x8]
    call is_device_suitable
    test rax, rax
    jnz .L_device_found
    inc rdx
    jmp .L_device_loop

.L_device_loop_end:
    add rsp, 0x20 ; restore shadow space from push rsi and rdi
    pop rdi
    pop rsi
    lea rcx, [no_suitable_dev]
    call SDL_Log
    jmp .L_init_fail

.L_device_found:
    mov rax, [rbp + 0x10]
    mov rcx, [rdi + rsi * 0x8]
    add rsp, 0x20 ; restore shadow space from push rsi and rdi
    pop rdi
    pop rsi

    mov [rax + 0x18], rcx ; Environment->physicalDevice = physicalDevices[i]
    lea rcx, [suitable_dev]
    call SDL_Log

    jmp .L_init_success

.L_init_fail:
    mov eax, 0
    jmp .L_init_end

.L_init_success:
    mov eax, 1

.L_init_end:

    ; free devices buffer
    mov rcx, [rbp - 0x80]
    call free
    add rsp, 0x30 + 0x40 + 0x10 + SHADOW_SPACE
    pop rbp
    ret

print_device_info:
    push rbp
    mov rbp, rsp
    sub rsp, 0x340 + SHADOW_SPACE ; VkPhysicalDeviceProperties + 8 + SHADOW_SPACE

    lea rdx, [rbp - 0x338]
    call vkGetPhysicalDeviceProperties

    lea rcx, [devprops_api]
    mov rdx, [rbp - 0x338 + 0x00]
    call SDL_Log

    lea rcx, [devprops_driver]
    mov rdx, [rbp - 0x338 + 0x04]
    call SDL_Log

    lea rcx, [devprops_vendor]
    mov rdx, [rbp - 0x338 + 0x08]
    call SDL_Log

    lea rcx, [devprops_deviceI]
    mov rdx, [rbp - 0x338 + 0x0C]
    call SDL_Log

    lea rcx, [devprops_deviceT]
    mov rdx, [rbp - 0x338 + 0x10]
    call SDL_Log

    lea rcx, [devprops_deviceN]
    lea rdx, [rbp - 0x338 + 0x14]
    call SDL_Log
    
    add rsp, 0x340 + SHADOW_SPACE
    pop rbp
    ret

is_device_suitable:
    push rbp
    mov rbp, rsp
    sub rsp, SHADOW_SPACE
    
    call find_queue_families
    mov rax, 1 ; always return true
    
    add rsp, SHADOW_SPACE
    pop rbp
    ret

find_queue_families:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10 + SHADOW_SPACE ; uint32 + uint64 + SHADOW_SPACE
    mov [rbp + 0x10], rcx

    ;mov rcx, [rbp + 0x10] rcx already has the device
    lea rdx, [rbp - 0x04] ; &count
    mov r8, 0x0
    call vkGetPhysicalDeviceQueueFamilyProperties



    ; allocate space for queuefamilies
    mov ecx, [rbp - 0x04]
    imul ecx, 0x18 ; size of queuefamilyproperties
    call malloc
    mov [rbp - 0x10], rax
    
    ; read in the queue families
    mov rcx, [rbp + 0x10]
    lea rdx, [rbp - 0x04]
    mov r8, rax
    call vkGetPhysicalDeviceQueueFamilyProperties

    push rdi
    push rsi
    sub rsp, 0x20

    mov rsi, 0
    mov rdi, [rbp - 0x10]

.L_family_loop:
    cmp esi, [rbp - 0x04]
    jge .L_family_loop_end

    mov rcx, rsi
    imul rcx, 0x18
    add rcx, rdi
    ;lea rcx, [rdi + rsi * 0x18]
    call print_queue_family_info

    inc rsi
    jmp .L_family_loop
.L_family_loop_end:
    add rsp, 0x20 ; restore nonvolatile registers
    pop rsi
    pop rdi
    ; free the allocated space
    mov rcx, [rbp - 0x10]
    call free

    add rsp, 0x10 + SHADOW_SPACE
    pop rbp
    ret

print_queue_family_info:
    push rbp
    mov rbp, rsp
    sub rsp, SHADOW_SPACE

    mov [rbp + 0x10], rcx

    lea rcx, [print_sep]
    call SDL_Log

    lea rcx, [quefam_flags]
    mov rdx, [rbp + 0x10]
    mov rdx, [rdx + 0x00]
    call SDL_Log

    lea rcx, [quefam_count]
    mov rdx, [rbp + 0x10]
    mov rdx, [rdx + 0x04]
    call SDL_Log

    lea rcx, [quefam_tsvb]
    mov rdx, [rbp + 0x10]
    mov rdx, [rdx + 0x08]
    call SDL_Log

    add rsp, SHADOW_SPACE
    pop rbp
    ret


section '.data' data readable writeable
    window_title     db "ASM SDL Window!", 0
    log_sdl_error    db "SDL Error occured: %s", 0
    log_vulkan_error db "Vulkan Error occured: 0x%X", 0
    vk_app_name      db "Vulkan App", 0
    vk_engine_name   db "No Engine", 0
    num_devices      db "devicesCount: 0x%X", 0
    no_suitable_dev  db "No suitable physical device found", 0
    suitable_dev     db "Suitable device found", 0

    print_sep        db "-------------------------------", 0

    devprops_api     db "devprops apiVersion: 0x%X", 0
    devprops_driver  db "devprops driverVersion: 0x%X", 0
    devprops_vendor  db "devprops vendorID: 0x%X", 0
    devprops_deviceI db "devprops deviceID: 0x%X", 0
    devprops_deviceT db "devprops deviceType: 0x%X", 0
    devprops_deviceN db "devprops deviceName: %s", 0

    quefam_amount    db "QueFamily deviceCount: %d", 0
    quefam_flags     db "queueFamily flags: 0x%X", 0
    quefam_count     db "queueFamily count: 0x%X", 0
    quefam_tsvb      db "queueFamily timestampValidBits: 0x%X", 0




    

