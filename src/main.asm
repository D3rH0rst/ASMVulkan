format MS64 COFF

public start as 'main'
extrn SDL_Init
extrn SDL_CreateWindow
extrn SDL_DestroyWindow
extrn SDL_CreateRenderer
extrn SDL_DestroyRenderer
extrn SDL_Quit
extrn SDL_SetWindowTitle
extrn SDL_PollEvent
extrn SDL_Log
extrn SDL_GetError
extrn SDL_Vulkan_CreateSurface
extrn SDL_Vulkan_DestroySurface
extrn SDL_Vulkan_GetInstanceExtensions
extrn vkCreateInstance
extrn vkDestroyInstance
extrn vkCreateDevice
extrn vkDestroyDevice
extrn vkGetDeviceQueue
extrn vkEnumeratePhysicalDevices
extrn vkGetPhysicalDeviceProperties
extrn vkGetPhysicalDeviceQueueFamilyProperties
extrn vkGetPhysicalDeviceSurfaceSupportKHR
extrn vkEnumerateDeviceExtensionProperties
extrn malloc
extrn free
extrn memset

width = 1280
height = 720
SDL_INIT_VIDEO = 0x20
SDL_WINDOW_VULKAN = 0x0000000010000000

SHADOW_SPACE = 0x20

f1_0 = 0x3f800000

;struc Environment {
;    .window           dq 0
;    .surface          dq 0
;    .vk_instance      dq 0
;    .vk_pysicaldevice dq 0
;    .vk_device        dq 0
;    .vk_graphicsQueue dq 0
;    .vk_presentQueue  dq 0
;}
ENV_SZ = 0x40

;struc SDL_Event {
;    .reserved rb 0x80 ; size of the SDL_Event struct in C
;}
EVENT_SZ = 0x80

section '.text' code readable executable

start:
    push rbp
    mov rbp, rsp
    sub rsp, ENV_SZ + EVENT_SZ + SHADOW_SPACE ;0x40 -> Environment, 0x80 -> SDL_Event, 0x20 -> Shadow Space

    lea rcx, [rbp - ENV_SZ] ; Environment
    call init
    test eax, eax
    jz .L_quit

.L_event_loop:

.L_poll_event:
    lea rcx, [rbp - ENV_SZ - EVENT_SZ] ; first var on the stack, SDL_Event
    call SDL_PollEvent
    mov edx, [rbp - ENV_SZ - EVENT_SZ + 0x00] ; (SDL_Event - 0x0) = event.type
    cmp edx, 0x100 ; SDL_EVENT_QUIT
    je .L_quit
    test rax, rax
    jnz .L_poll_event

    ;render everything here

    jmp .L_event_loop


.L_quit:
    mov rcx, [rbp - ENV_SZ + 0x10] ; environmen.instance
    mov rdx, [rbp - ENV_SZ + 0x08] ; environment.surface
    mov r8,  0
    test rcx, rcx
    jz .L_quit3
    test rdx, rdx
    jz .L_quit1
    call SDL_Vulkan_DestroySurface

.L_quit1:
    mov rcx, [rbp - ENV_SZ + 0x20] ; environment.device
    mov rdx, 0
    test rcx, rcx
    jz .L_quit2
    call vkDestroyDevice

.L_quit2:
    mov rcx, [rbp - ENV_SZ + 0x10] ; environment.instance
    mov rdx, 0
    test rcx, rcx
    jz .L_quit3
    call vkDestroyInstance

.L_quit3:
    mov rcx, [rbp - ENV_SZ + 0x00] ; environment.window
    test rcx, rcx
    jz .L_quit4
    call SDL_DestroyWindow

.L_quit4:
    call SDL_Quit

    add rsp, ENV_SZ + EVENT_SZ + SHADOW_SPACE
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

; rcx -> Environment*
init_sdl:
    push rbp
    mov rbp, rsp
    sub rsp, SHADOW_SPACE

    ; move Environment* to shadow space
    mov [rbp + 0x10], rcx

    ; SDL_Init
    mov rcx, SDL_INIT_VIDEO
    call SDL_Init
    call check_sdl_error
    test eax, eax
    jz .L_sdl_init_fail

    ; SDL_CreateWindow
    lea rcx, [window_title]
    mov rdx, width
    mov r8, height
    mov r9, SDL_WINDOW_VULKAN
    call SDL_CreateWindow
    mov rcx, [rbp + 0x10]
    mov [rcx + 0x00], rax ; Environment->window = window
    call check_sdl_error
    test eax, eax
    jz .L_sdl_init_fail
    mov rax, 1
    jmp .L_sdl_init_end

.L_sdl_init_fail:
    mov rax, 0

.L_sdl_init_end:
    add rsp, SHADOW_SPACE
    pop rbp
    ret

; rcx -> Environment*
create_vk_instance:
    push rbp
    mov rbp, rsp
    sub rsp, 0x30 + 0x40 + 0x10 + SHADOW_SPACE ; VkApplicationInfo + VkInstanceCreateInfo + uint32

    mov [rbp + 0x10], rcx

    ; set up VkApplicationInfo
    mov DWORD [rbp - 0x30 + 0x00], 0x0       ; .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
    mov QWORD [rbp - 0x30 + 0x08], 0x0       ; .pNext = NULL
    
    lea rax,  [vk_app_name]
    mov       [rbp - 0x30 + 0x10], rax       ; .pApplicationName = "Vulkan App"
    
    mov DWORD [rbp - 0x30 + 0x18], 0x400000  ; .applicationVersion = VK_MAKE_VERSION(1, 0, 0)
    
    lea rax,  [vk_engine_name]
    mov       [rbp - 0x30 + 0x20], rax       ; .pEngineName = "No Engine"

    mov DWORD [rbp - 0x30 + 0x28], 0x400000  ; .engineVersion = VK_MAKE_VERSION(1, 0, 0)
    mov DWORD [rbp - 0x30 + 0x2C], 0x403000  ; .apiVersion = VK_API_VERSION_1_3

    ; set up VkInstanceCreateInfo
    mov DWORD [rbp - 0x70 + 0x00], 0x1       ; .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
    mov QWORD [rbp - 0x70 + 0x08], 0x0       ; .pNext = NULL
    mov DWORD [rbp - 0x70 + 0x10], 0x0       ; .flags = 0

    lea rax,  [rbp - 0x30]
    mov       [rbp - 0x70 + 0x18], rax       ; .pApplicationInfo = &applicationInfo (rbp - 0x30)

    mov DWORD [rbp - 0x70 + 0x20], 0x0       ; .enabledLayerCount = 0
    mov QWORD [rbp - 0x70 + 0x28], 0x0       ; .ppEnabledLayerNames = NULL

    lea rcx,  [rbp - 0x74]                   ; &count
    call SDL_Vulkan_GetInstanceExtensions
    mov ecx,  [rbp - 0x74]
    mov       [rbp - 0x70 + 0x30], ecx       ; .enabledExtensionCount = enabled_extension_count
    mov       [rbp - 0x70 + 0x38], rax       ; .ppEnabledExtensionNames = extension_names

    ; call vkCreateInstance
    lea rcx,  [rbp - 0x70]                   ; createInfo = &createInfo
    mov rdx, 0                               ; Allocator = NULL
    mov r9,   [rbp + 0x10]
    lea r8,   [r9 + 0x10]                    ; instance = &instance
    call vkCreateInstance
    call check_vulkan_error
    test rax, rax
    jz .L_create_vk_instance_fail

    ; sucess
    mov rax, 1
    jmp .L_create_vk_instance_end

.L_create_vk_instance_fail:
    mov rax, 0

.L_create_vk_instance_end:
    add rsp, 0x30 + 0x40 + 0x10 + SHADOW_SPACE
    pop rbp
    ret

; rcx -> Environment*
create_vk_surface:
    push rbp
    mov rbp, rsp
    sub rsp, SHADOW_SPACE

    ; create surface
    mov rax, rcx          ; Environment*
    mov rcx, [rax + 0x00] ; a1 = Environment->window
    mov rdx, [rax + 0x10] ; a2 = Environment->instance
    mov r8,  0            ; a3 = NULL
    lea r9,  [rax + 0x08] ; a4 = &Environment->surface
    call SDL_Vulkan_CreateSurface
    call check_sdl_error
    test eax, eax
    jz .L_create_vk_surface_fail

    ;success
    mov rax, 1
    jmp .L_create_vk_surface_end

.L_create_vk_surface_fail:
    mov rax, 0

.L_create_vk_surface_end:
    add rsp, SHADOW_SPACE
    pop rbp
    ret

; rcx -> Environment*
pick_vk_physical_device:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10 + SHADOW_SPACE ; uint32 + uint64

    mov [rbp + 0x10], rcx

    ; call vkEnumeratePhysicalDevices to count devices
    mov rax, rcx
    mov rcx, [rax + 0x10] ; Environment->instance
    lea rdx, [rbp - 0x04] ; &device_count
    mov r8, 0x0
    call vkEnumeratePhysicalDevices
    call check_vulkan_error
    test rax, rax
    jz .L_pick_physical_device_fail

    ; malloc space for devices amount
    mov ecx, [rbp - 0x04] 
    shl ecx, 0x03 ; device_count << 3 (same as device_count * 8)
    call malloc
    test rax, rax
    jz .L_pick_physical_device_malloc_fail
    mov [rbp - 0x10], rax

    ; read in devices
    mov r8,  [rbp + 0x10]
    mov rcx, [r8 + 0x10]  ; Environment->instance
    lea rdx, [rbp - 0x04] ; &device_count
    mov r8, rax           ; ptr to devices from malloc
    call vkEnumeratePhysicalDevices
    call check_vulkan_error
    test rax, rax
    jz .L_pick_physical_device_fail

    push rsi ; push nonvolatile registers into the stack for restoring
    push rdi
    sub rsp, 0x20 ; shadow space because we pushed registers onto the stack
    mov esi, 0    ; i = 0
    mov rdi, [rbp - 0x10] ; malloc device ptr
.L_device_loop:
    cmp esi, [rbp - 0x04] ; device_count
    jge .L_device_loop_end

    ;call print_device_info

    ;mov rcx, [rdi + rsi * 0x8]
    mov rcx, [rbp + 0x10]      ; environment
    mov rdx, [rdi + rsi * 0x8] ; device
    call is_device_suitable
    test rax, rax
    jnz .L_device_found
    inc esi
    jmp .L_device_loop

.L_device_loop_end:
    add rsp, 0x20 ; restore shadow space from push rsi and rdi
    pop rdi
    pop rsi
    lea rcx, [no_suitable_dev]
    call SDL_Log
    jmp .L_pick_physical_device_fail

.L_device_found:
    mov rax, [rbp + 0x10]      ; Environment*
    mov rcx, [rdi + rsi * 0x8] ; ptr to suitable physical device
    add rsp, 0x20 ; restore shadow space from push rsi and rdi
    pop rdi
    pop rsi       ; restore nonvolatile register values

    mov [rax + 0x18], rcx ; Environment->physicalDevice = physicalDevices[i]

    ;sucess
    mov rcx, [rbp - 0x10] ; no need to test, if malloc failed we wouldnt be here
    call free
    mov rax, 1
    jmp .L_pick_vk_physical_device_end

.L_pick_physical_device_fail:
    mov rcx, [rbp - 0x10]
    call free
.L_pick_physical_device_malloc_fail:    
    mov rax, 0

.L_pick_vk_physical_device_end:
    add rsp, 0x10 + SHADOW_SPACE
    pop rbp
    ret

; rcx -> Environment*
create_vk_device:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10 + 0x50 + 0xE0 + 0x50 + SHADOW_SPACE ; QueueFamilyIndices + 2 * VkDeviceQueueCreateInfo + VkPhysicalDeviceFeatures + VkDeviceCreateInfo

    mov [rbp + 0x10], rcx

    ; create logical device
    mov rcx, [rbp + 0x10] ; a1 = Environment
    mov rdx, [rcx + 0x18] ; a2 = Environment->physicalDevice
    lea r8,  [rbp - 0x10] ; a3 = &indices
    call find_queue_families

    mov DWORD [rbp - 0x04], 1   ; assume both indices are equal
    ; check if the indices are equal
    mov eax, [rbp - 0x10 + 0x00] ; indices->graphicsFamily
    cmp eax, [rbp - 0x10 + 0x04] ; indices->presentFamily
    setne cl                     ; cl = i->gf != i->pf
    movzx eax, cl                ; extend register
    add DWORD [rbp - 0x04], eax  ; add 0 or one  to the count



    ; set up VkDeviceQueueCreateInfo 
    mov DWORD [rbp - 0x60 + 0x00], 0x02 ; .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    mov QWORD [rbp - 0x60 + 0x08], 0    ; .pNext = NULL
    mov DWORD [rbp - 0x60 + 0x10], 0    ; .flags = 0

    mov eax,  [rbp - 0x10 + 0x00]       ; indices->graphicsFamily
    mov DWORD [rbp - 0x60 + 0x14], eax  ; .queueFamilyIndex = indices->graphicsFamily

    mov DWORD [rbp - 0x60 + 0x18], 1    ; .queueCount = 1
    
    mov DWORD [rbp - 0x08], f1_0        ; move float 1.0 to a free stack space
    lea rax,  [rbp - 0x08]              ; rax = &f1_0
    mov QWORD [rbp - 0x60 + 0x20], rax  ; .pQueuePriorities = rax

    mov eax, [rbp - 0x04]
    cmp eax, 1
    je .L_create_vk_device_after_queue_create_info
    ; set up the second structure if the indices are not the same
    mov DWORD [rbp - 0x38 + 0x00], 0x02 ; .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    mov QWORD [rbp - 0x38 + 0x08], 0    ; .pNext = NULL
    mov DWORD [rbp - 0x38 + 0x10], 0    ; .flags = 0

    mov eax,  [rbp - 0x10 + 0x04]       ; indices->presentFamily
    mov DWORD [rbp - 0x38 + 0x14], eax  ; .queueFamilyIndex = indices->presentFamily

    mov DWORD [rbp - 0x38 + 0x18], 1    ; .queueCount = 1
    
    lea rax,  [rbp - 0x08]              ; rax = &f1_0
    mov QWORD [rbp - 0x38 + 0x20], rax  ; .pQueuePriorities = rax

.L_create_vk_device_after_queue_create_info:
    ; set up VkPhysicalDeviceFeatures
    lea rcx, [rbp - 0x140] ; &deviceFeatures
    mov edx, 0             ; value
    mov r8, 0xDC           ; sizeof(VkPhysicalDeviceFeatures)
    call memset

    ; set up VkDeviceCreateInfo
    mov DWORD [rbp - 0x190 + 0x00], 0x3 ; .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
    mov QWORD [rbp - 0x190 + 0x08], 0   ; .pNext = NULL
    mov DWORD [rbp - 0x190 + 0x10], 0   ; .flags = 0
    mov eax,  [rbp - 0x004 + 0x00]      ;  count
    mov DWORD [rbp - 0x190 + 0x14], eax ; .queueCreateInfoCount = count
    lea rax,  [rbp - 0x060 + 0x00]      ;  &queueCreateInfos
    mov       [rbp - 0x190 + 0x18], rax ; .pQueueCreateInfos = &queueCreateInfos
    mov DWORD [rbp - 0x190 + 0x20], 0   ; .enabledLayerCount = 0
    mov QWORD [rbp - 0x190 + 0x28], 0   ; .ppEnabledLayerNames = NULL
    mov DWORD [rbp - 0x190 + 0x30], 0   ; .enabledExtensionCount = 0
    mov QWORD [rbp - 0x190 + 0x38], 0   ; .ppEnabledExtensionNames = NULL
    lea rax,  [rbp - 0x140 + 0x00]      ;  &deviceFeatures
    mov QWORD [rbp - 0x190 + 0x40], rax ; .pEnabledFeatures = &deviceFeatures

    ; call vkCreateDevice
    mov rax, [rbp + 0x010]
    mov rcx, [rax + 0x018] ; a1 = Environment->physicalDevice
    lea rdx, [rbp - 0x190] ; a2 = &createInfo
    mov r8,  0             ; a3 = NULL
    lea r9,  [rax + 0x020] ; a4 = &device
    call vkCreateDevice
    call check_vulkan_error
    test eax, eax
    jz .L_create_vk_device_fail

    ; get the graphicsQueue
    mov rax, [rbp + 0x10]
    mov rcx, [rax + 0x20]        ; a1 = Environment->device
    mov edx, [rbp - 0x10 + 0x00] ; a2 = indices->graphicsFamily
    mov r8, 0                    ; a3 = 0
    lea r9, [rax + 0x28]         ; a4 = &graphicsQueue
    call vkGetDeviceQueue
    
    ; get the presentQueue
    mov rax, [rbp + 0x10]
    mov rcx, [rax + 0x20]        ; a1 = Environment->device
    mov edx, [rbp - 0x10 + 0x04] ; a2 = indices->presentFamily
    mov r8, 0                    ; a3 = 0
    lea r9, [rax + 0x30]         ; a4 = &presentQueue
    call vkGetDeviceQueue

    ; success:
    mov rax, 1
    jmp .L_create_vk_device_end

.L_create_vk_device_fail:
    mov rax, 0

.L_create_vk_device_end:
    add rsp, 0x10 + 0x50 + 0xE0 + 0x50 + SHADOW_SPACE
    pop rbp
    ret

init:
    push rbp
    mov rbp, rsp
    sub rsp, SHADOW_SPACE ; VkApplicationInfo + VkInstanceCreateInfo + uint32 + uint32 + VkDeviceQueueCreateInfo + VkPhysicalDeviceFeatures + VkDeviceCreateInfo + SHADOW_SPACE
    
    ; move arg (Environment*) to shadow space
    mov [rbp + 0x10], rcx
    
    ;mov rcx, [rbp + 0x10] its already in rcx
    call init_sdl
    test rax, rax
    jz .L_init_fail
    
    lea rcx, [init_sdl_success]
    call SDL_Log

    mov rcx, [rbp + 0x10]
    call create_vk_instance
    test rax, rax
    jz .L_init_fail

    lea rcx, [create_vki_success]
    call SDL_Log

    mov rcx, [rbp + 0x10]
    call create_vk_surface
    test rax, rax
    jz .L_init_fail
 
    lea rcx, [create_vks_success]
    call SDL_Log

    mov rcx, [rbp + 0x10]
    call pick_vk_physical_device
    test rax, rax
    jz .L_init_fail

    lea rcx, [pick_phd_success]
    call SDL_Log

    mov rcx, [rbp + 0x10]
    call create_vk_device
    test rax, rax
    jz .L_init_fail

    lea rcx, [create_vkd_success]
    call SDL_Log

    jmp .L_init_success

.L_init_fail:
    mov eax, 0
    jmp .L_init_end

.L_init_success:
    mov eax, 1

.L_init_end:
    add rsp, SHADOW_SPACE
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

; rcx -> Environment ; rdx -> VkPhysicalDevice
is_device_suitable:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10 + SHADOW_SPACE ; QueueFamilyIndices
    
    mov [rbp + 0x10], rcx ; Environment*
    mov [rbp + 0x18], rdx ; VkPhsyicalDevice*

    ;rcx has Environment
    ;rdx has VkPhysicalDevice
    lea r8, [rbp - 0x10] ; &indices
    call find_queue_families
    test rax, rax
    jz .L_device_suitable_false
    ; check here if both families have valid (!= -1) indices, if yes, return true
    mov ecx, [rbp - 0x10 + 0x00] ; indices->graphicsFamily
    mov edx, [rbp - 0x10 + 0x04] ; indices->presentFamily
    or ecx, edx           ; is either -1?
    cmp ecx, -1
    je .L_device_suitable_false

    mov rcx, [rbp + 0x18] ; VkPhsyicalDevice*
    call check_device_extension_support
    test rax, rax
    jz .L_device_suitable_false
.L_device_suitable_true:
    mov rax, 1
    jmp .L_device_suitable_end

.L_device_suitable_false:
    mov rax, 0

.L_device_suitable_end:
    add rsp, 0x10 + SHADOW_SPACE
    pop rbp
    ret

; rcx -> Environment*, rdx -> VkPhysicalDevice, r8 -> QueueFamilyIndices*
find_queue_families:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10 + SHADOW_SPACE ; uint32 + uint64 + SHADOW_SPACE

    mov [rbp + 0x10], rcx ; Environment*
    mov [rbp + 0x18], rdx ; VkPhysicalDevice
    mov [rbp + 0x20], r8  ; QueueFamilyIndices

    mov rcx, [rbp + 0x18] ; VkPhsyicalDevice
    lea rdx, [rbp - 0x04] ; &count
    mov r8, 0x0
    call vkGetPhysicalDeviceQueueFamilyProperties

    ; allocate space for queuefamilies
    mov ecx, [rbp - 0x04] ; count
    imul ecx, 0x18 ; size of queuefamilyproperties
    call malloc
    test rax, rax
    jz .L_find_queue_families_malloc_fail
    mov [rbp - 0x10], rax
    
    ; read in the queue families
    mov rcx, [rbp + 0x18]
    lea rdx, [rbp - 0x04]
    mov r8, rax
    call vkGetPhysicalDeviceQueueFamilyProperties

    ;mov DWORD [rbp - 0x08], -1 ; -1 as default return value
    ; initialize indices to sentinel value
    mov rax,  [rbp + 0x20] ; QueueFamilyIndices*
    mov DWORD [rax + 0x00], -1  ; indices->graphicsFamily = -1
    mov DWORD [rax + 0x04], -1  ; indices->presentFamily  = -1
    
    ; save old registers and allocate shadow space
    push rdi
    push rsi
    sub rsp, 0x20

    mov esi, 0
    mov rdi, [rbp - 0x10]

.L_family_loop:
    cmp esi, [rbp - 0x04]
    jge .L_family_loop_end
    ; check if (queueFamily.queueFlags & VK_QUEUE_GRAPHICS_BIT)
    mov rcx, rsi
    imul rcx, 0x18
    add rcx, rdi
    ;lea rcx, [rdi + rsi * 0x18]
    mov edx, [rcx + 0x0] ; edx contains .queueFlags
    and edx, 0x1         ; .queueFlags & VK_QUEUE_GRAPHICS_BIT
    test edx, edx
    jz .L_check_present_family
    mov rax, [rbp + 0x20] ; QueueFamilyIndices*
    mov DWORD [rax + 0x00], esi  ; indices->graphicsFamily = i
.L_check_present_family:
    mov rcx, [rbp + 0x18] ; a1 = device
    mov edx, esi          ; a2 = i
    mov rax, [rbp + 0x10] ; Environment
    mov r8,  [rax + 0x08] ; a3 = Environment->surface
    lea r9,  [rbp - 0x08]
    call vkGetPhysicalDeviceSurfaceSupportKHR
    mov eax, [rbp - 0x08]
    test eax, eax
    jz .L_family_loop_check
    mov rax, [rbp + 0x20] ; QueueFamilyIndices*
    mov DWORD [rax + 0x04], esi  ; indices->presentFamily = i

.L_family_loop_check:
    ; check here if both families have valid (!= -1) indices, if yes, break
    mov rax, [rbp + 0x18] ; QueueFamilyIndices*
    mov ecx, [rax + 0x00] ; indices->graphicsFamily
    mov edx, [rax + 0x04] ; indices->presentFamily
    or ecx, edx           ; is either -1?
    cmp ecx, -1
    je .L_family_loop_inc
    jmp .L_family_loop_end

.L_family_loop_inc:
    inc rsi
    jmp .L_family_loop

.L_family_loop_end:
    add rsp, 0x20 ; restore nonvolatile registers
    pop rsi
    pop rdi
    
    ;sucess:
    mov rcx, [rbp - 0x10] ; malloc'd memory
    call free
    mov rax, 1
    jmp .L_find_queue_families_end

.L_find_queue_families_fail:
    call free
.L_find_queue_families_malloc_fail:
    mov rax, 0

.L_find_queue_families_end:
    add rsp, 0x10 + SHADOW_SPACE
    pop rbp
    ret

check_device_extension_support:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10 + SHADOW_SPACE ; uint32, uint64

    mov [rbp + 0x10], rcx

    ; call vkEnumerateDeviceExtensionProperties
    ; rcx has the device ; a1 = device
    mov rdx, 0           ; a2 = NULL
    lea r8,  [rbp - 0x04]; a3 = &extensionCount
    mov r9,  0           ; a4 = NULL
    call vkEnumerateDeviceExtensionProperties
    call check_vulkan_error
    test rax, rax
    jz .L_check_device_extension_support_false

    mov ecx, [rbp - 0x04] ; extensionCount
    imul ecx, 0x104       ; sizeof(VkExtensionProperties)
    call malloc
    test rax, rax
    jz .L_check_device_extension_support_false
    mov [rbp - 0x10], rax

    mov rcx, [rbp + 0x10] ; a1 = device
    mov rdx, 0            ; a2 = NULL
    lea r8,  [rbp - 0x04] ; a3 = &extensionCount
    mov r9,  [rbp - 0x10] ; a4 = malloc'd ptr
    call vkEnumerateDeviceExtensionProperties
    call check_vulkan_error
    test rax, rax
    jz .L_check_device_extension_support_error

    push rsi
    push rdi
    sub rsp, SHADOW_SPACE

    mov rsi, 0              ; i = 0
    mov rdi, [rbp - 0x10]   ; baseptr
    mov DWORD [rbp - 0x08], device_extensions_size ; required_extensions_size
.L_extension_loop:
    cmp esi, [rbp - 0x04] ; count
    jge .L_extension_loop_end
    
    mov rdx, rsi
    imul rdx, 0x104
    add rdx, rdi ; rdx now contains a char* to the extension name

    

    inc rsi
    jmp .L_extension_loop
.L_extension_loop_end:
    add rsp, SHADOW_SPACE
    pop rdi
    pop rsi


    mov rcx, [rbp - 0x10]
    call free
    

.L_check_device_extension_support_true:
    mov rax, 1
    jmp .L_check_device_extension_support_end

.L_check_device_extension_support_error:
    mov rcx, [rbp - 0x10]
    call free
.L_check_device_extension_support_false:
    mov rax, 0

.L_check_device_extension_support_end:
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
    no_suitable_dev  db "No suitable physical device found", 0
    print_sep        db "-------------------------------", 0
    log_int          db "%d", 0
    log_ptr          db "0x%llX", 0
    log_ext_name     db "Device Extension: %s", 0

    init_sdl_success db "Succesfully initialized SDL", 0
    create_vki_success db "Successfully created vulkan instance", 0
    create_vks_success db "Successfully created vulkan surface", 0
    pick_phd_success db "Successfully picked a physical device", 0
    create_vkd_success db "Successfully created vulkan device", 0

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
    quefam_index     db "queueFamily index: %d", 0

    device_ext1      db "VK_KHR_swapchain", 0
    device_extensions dq device_ext1
    device_extensions_size = ($ - device_extensions) / 8



    

