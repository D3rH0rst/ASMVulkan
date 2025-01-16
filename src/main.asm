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

TRUE = 1
FALSE = 0

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
ENV_SZ               = 0x40
; members
ENV_WINDOW           = 0x00
ENV_SURFACE          = 0x08
ENV_VK_INSTANCE      = 0x10
ENV_VK_PHDEVICE      = 0x18
ENV_VK_DEVICE        = 0x20
ENV_VK_GRAPHICSQUEUE = 0x28
ENV_VK_PRESENTQUEUE  = 0x30
; members end

;struc SDL_Event {
;    .reserved rb 0x80 ; size of the SDL_Event struct in C
;}
EVENT_SZ = 0x80
; members
EVENT_TYPE = 0x0
; members end

; event types
SDL_EVENT_QUIT = 0x100
;event types end

section '.text' code readable executable

;=========================================== main ==============================================
start:
    push rbp
    mov rbp, rsp
    sub rsp, ENV_SZ + 0x10 + SHADOW_SPACE ; ENV_SZ(0x40) -> Environment, 0x10 -> return value, 0x20 -> Shadow Space

    mov DWORD [rbp - ENV_SZ - 0x04], 1 ; store default return value

    lea rcx, [rbp - ENV_SZ] ; Environment
    call init
    test eax, eax
    jz .L_cleanup

    lea rcx, [rbp - ENV_SZ]
    call main_loop
    mov [rbp - ENV_SZ - 0x04], eax ; store return value

    .L_cleanup:
    lea rcx, [rbp - ENV_SZ]
    call cleanup

    mov eax, [rbp - ENV_SZ - 0x04] ; get stored return value
    add rsp, ENV_SZ + 0x10 + SHADOW_SPACE
    pop rbp
    ret
;========================================= END main ============================================

;=========================== init - arg1: Environment* - ret: bool =============================
init:
    push rbp
    mov rbp, rsp
    sub rsp, SHADOW_SPACE ; 0x20 SHADOW_SPACE
    
    ; move arg (Environment*) to shadow space
    mov [rbp + 0x10], rcx
    
    ; initialize SDL
    ;mov rcx, [rbp + 0x10] its already in rcx
    call init_sdl
    test rax, rax
    jz .L_init_fail

    ; initialize Vulkan
    mov rcx, [rbp + 0x10]
    call init_vulkan
    test rax, rax
    jz .L_init_fail

    mov rcx, is_everything
    call SDL_Log

    ; success
    mov rax, 1
    jmp .L_init_end

    .L_init_fail:
    mov rax, 0
    jmp .L_init_end    

    .L_init_end:
    add rsp, SHADOW_SPACE
    pop rbp
    ret
;======================================== END init =============================================

;========================= main_loop - arg1: Environment* - ret: int ===========================
main_loop:
    push rbp
    mov rbp, rsp
    sub rsp, EVENT_SZ + SHADOW_SPACE

    mov [rbp + 0x10], rcx ; mov Env* to shadow space

    .L_main_loop_poll_event:
    lea rcx, [rbp - EVENT_SZ] ; first var on the stack, SDL_Event
    call SDL_PollEvent
    mov edx, [rbp - EVENT_SZ + EVENT_TYPE] ; (SDL_Event + 0x0) = event.type
    cmp edx, SDL_EVENT_QUIT
    je .L_main_loop_end
    test rax, rax
    jnz .L_main_loop_poll_event

    ;render everything here

    jmp .L_main_loop_poll_event

    .L_main_loop_end:
    mov rax, 0 ; zero indicates success here, return nonzero on failure
    add rsp, EVENT_SZ + SHADOW_SPACE
    pop rbp
    ret
;===================================== END main_loop ===========================================

;========================== cleanup - arg1: Environment* - ret: bool ===========================
cleanup:
    push rbp
    mov rbp, rsp
    sub rsp, SHADOW_SPACE
    
    mov [rbp + 0x10], rcx ; mov Env* to shadow space

    ; SDL_Vulkan_DestroySurface
    mov rax, [rbp + 0x10] ; load Env* pointer
    mov rcx, [rax + ENV_VK_INSTANCE] ; environment.instance
    mov rdx, [rax + ENV_SURFACE] ; environment.surface
    mov r8,  0            ; NULL
    test rcx, rcx         ; if vk_instance is NULL, skip over vulkan cleanup as the other vulkan resources will be invalid too
    jz .L_cleanup_window
    test rdx, rdx         ; if vk_surface is NULL, go to vkDestroyDevice
    jz .L_cleanup_device           
    call SDL_Vulkan_DestroySurface

    .L_cleanup_device:
    mov rax, [rbp + 0x10] ; load Env* pointer
    mov rcx, [rax + ENV_VK_DEVICE] ; environment.device
    mov rdx, 0            ; NULL
    mov r8, 0
    test rcx, rcx
    jz .L_cleanup_instance
    call vkDestroyDevice

    .L_cleanup_instance:
    mov rax, [rbp + 0x10] ; load Env* pointer
    mov rcx, [rax + ENV_VK_INSTANCE] ; environment.instance
    mov rdx, 0
    mov r8, 0
    test rcx, rcx
    jz .L_cleanup_window
    call vkDestroyInstance

    .L_cleanup_window:
    mov rax, [rbp + 0x10] ; load Env* pointer
    mov rcx, [rax + ENV_WINDOW] ; environment.window
    test rcx, rcx
    jz .L_cleanup_SDL
    call SDL_DestroyWindow

    .L_cleanup_SDL:
    call SDL_Quit
    mov rax, 1
    add rsp, SHADOW_SPACE
    pop rbp
    ret
;======================================== END cleanup ==========================================

;========================== init_sdl - arg1: Environment* - ret: bool ==========================
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

    mov rcx, is_sdl
    call SDL_Log


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

    mov rcx, is_window
    mov rdx, [rbp + 0x10]
    mov rdx, [rdx + ENV_WINDOW]
    call SDL_Log

    ; success:
    mov rax, 1
    jmp .L_sdl_init_end

    .L_sdl_init_fail:
    mov rax, 0

    .L_sdl_init_end:
    add rsp, SHADOW_SPACE
    pop rbp
    ret
;======================================= END init_sdl ==========================================

;======================== init_vulkan - arg1: Environment* - ret: bool =========================
init_vulkan:
    push rbp
    mov rbp, rsp
    sub rsp, SHADOW_SPACE

    mov [rbp + 0x10], rcx ; move arg1 to shadow space

    ; rcx already contains Env* ptr
    call create_vk_instance
    test rax, rax
    jz .L_init_vulkan_fail

    mov rcx, is_vki
    mov rdx, [rbp + 0x10]
    mov rdx, [rdx + ENV_VK_INSTANCE]
    call SDL_Log


    mov rcx, [rbp + 0x10] ; arg1 - Env*
    call create_vk_surface
    test rax, rax
    jz .L_init_vulkan_fail

    mov rcx, is_vks
    mov rdx, [rbp + 0x10]
    mov rdx, [rdx + ENV_SURFACE]
    call SDL_Log


    mov rcx, [rbp + 0x10] ; arg1 - Env*
    call select_vk_physical_device
    test rax, rax
    jz .L_init_vulkan_fail

    mov rcx, is_phd
    mov rdx, [rbp + 0x10]
    mov rdx, [rdx + ENV_VK_PHDEVICE]
    call SDL_Log


    mov rcx, [rbp + 0x10] ; arg1 - Env*
    call create_vk_device
    test rax, rax
    jz .L_init_vulkan_fail

    mov rcx, is_vkd
    mov rdx, [rbp + 0x10]
    mov rdx, [rdx + ENV_VK_DEVICE]
    call SDL_Log


    ; success
    mov rax, 1
    jmp .L_init_vulkan_end

    .L_init_vulkan_fail:
    mov rax, 0
    .L_init_vulkan_end:
    add rsp, SHADOW_SPACE
    pop rbp
    ret
;====================================== END init_vulkan ======================================== 

;==================== create_vk_instance - arg1: Environment* - ret: bool ======================
create_vk_instance:
    push rbp
    mov rbp, rsp
    sub rsp, 0x30 + 0x40 + 0x10 + SHADOW_SPACE ; VkApplicationInfo + VkInstanceCreateInfo + uint32

    mov [rbp + 0x10], rcx ; save Environment* ptr

    ; zeroinit applicationInfo
    lea rcx, [rbp - 0x30]  ; a1 = &applicationInfo
    mov edx, 0             ; a2 = 0
    mov r8,  0x30          ; a3 = sizeof(VkApplicationInfo)
    call memset

    ; set up VkApplicationInfo
    ; VK_STRUCTURE_TYPE_APPLICATION_INFO is already 0 so no need to set .sType
    mov DWORD [rbp - 0x30 + 0x2C], 0x403000  ; .apiVersion = VK_API_VERSION_1_3

    ; zeroinit createInfo
    lea rcx, [rbp - 0x70]  ; a1 = &createInfo
    mov edx, 0             ; a2 = 0
    mov r8,  0x70          ; a3 = sizeof(VkInstanceCreateInfo)
    call memset

    ; set up VkInstanceCreateInfo
    mov DWORD [rbp - 0x70 + 0x00], 0x1       ; .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO

    lea rax,  [rbp - 0x30]
    mov       [rbp - 0x70 + 0x18], rax       ; .pApplicationInfo = &applicationInfo (rbp - 0x30)

    ; could use at some point to enable debug layers
    ;mov DWORD [rbp - 0x70 + 0x20], 0x0       ; .enabledLayerCount = 0
    ;mov QWORD [rbp - 0x70 + 0x28], 0x0       ; .ppEnabledLayerNames = NULL

    ; get the instance extensions needed
    lea rcx,  [rbp - 0x74]                   ; &count
    call SDL_Vulkan_GetInstanceExtensions
    mov ecx,  [rbp - 0x74]
    mov       [rbp - 0x70 + 0x30], ecx       ; .enabledExtensionCount = enabled_extension_count
    mov       [rbp - 0x70 + 0x38], rax       ; .ppEnabledExtensionNames = extension_names

    ; call vkCreateInstance
    lea rcx,  [rbp - 0x70]                   ; createInfo = &createInfo
    mov rdx, 0                               ; Allocator = NULL
    mov r9,   [rbp + 0x10]                   ; env* ptr
    lea r8,   [r9  + 0x10]                   ; instance = &instance
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
;================================== END create_vk_instance =====================================

;===================== create_vk_surface - arg1: Environment* - ret: bool ======================
create_vk_surface:
    push rbp
    mov rbp, rsp
    sub rsp, SHADOW_SPACE

    ; create surface
    mov rax, rcx                     ; Environment*
    mov rcx, [rax + ENV_WINDOW]      ; a1 = Environment->window
    mov rdx, [rax + ENV_VK_INSTANCE] ; a2 = Environment->instance
    mov r8,  0                       ; a3 = NULL
    lea r9,  [rax + ENV_SURFACE]     ; a4 = &Environment->surface
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
;=================================== END create_vk_surface =====================================

;================= select_vk_physical_device - arg1: Environment* - ret: bool ==================
select_vk_physical_device:
    push rbp
    mov rbp, rsp
    push rsi    ; for loop, pop at the end
    push rdi 
    sub rsp, 0x10 + SHADOW_SPACE ; uint32 count

    mov [rbp + 0x10], rcx ; save Environment* ptr

    mov rcx, [rcx + ENV_VK_INSTANCE] ; arg1: VkInstance
    lea rdx, [rbp - 0x04]            ; arg2: &count
    mov r8,  0                       ; arg3: NULL
    call vkEnumeratePhysicalDevices
    call check_vulkan_error
    test rax, rax
    jz .L_select_vk_physical_device_fail_no_free

    mov ecx, [rbp - 0x04]            ; load count
    test ecx, ecx                    ; if count == 0 -> no GPU found
    jz .L_select_vk_physical_device_fail_no_free

    shl ecx, 3                       ; arg1: count << 3 (count * 8), 
    call malloc
    test rax, rax
    jz .L_select_vk_physical_device_fail
    mov rdi, rax                     ; save the malloc'd ptr in rdi

    mov rax, [rbp + 0x10]
    mov rcx, [rax + ENV_VK_INSTANCE] ; arg1: VkInstance
    lea rdx, [rbp - 0x04]            ; arg2: &count
    mov r8,  rdi                     ; arg3: malloc'd ptr
    call vkEnumeratePhysicalDevices
    call check_vulkan_error
    test rax, rax
    jz .L_select_vk_physical_device_fail

    mov rsi, 0                       ; malloc'd ptr     
    .L_select_vk_physical_device_loop_begin:
    ; count already checked for 0, no need to check at the beginning
    mov rcx, [rbp + 0x10]            ; arg1: Env* ptr
    mov rdx, [rdi + rsi * 0x8]       ; arg2: i'th device
    call is_device_suitable
    test rax, rax                    ; if (is_device_suitable(env, device)) break;
    jnz .L_select_vk_physical_device_loop_end

    inc rsi
    cmp esi, [rbp - 0x4]             ; if (i >= count) goto fail (looped through all and not found)
    jge .L_select_vk_physical_device_fail
    jmp .L_select_vk_physical_device_loop_begin

    .L_select_vk_physical_device_loop_end:
    mov rdx, [rdi + rsi * 0x8]      ; device
    mov rax, [rbp + 0x10]           ; env* ptr
    mov [rax + ENV_VK_PHDEVICE], rdx; env->phdevice = phdevices[i]
    mov rcx, rdi                    ; ptr to malloc'd memory
    call free

    ; success:
    mov rax, 1
    jmp .L_select_vk_physical_device_end

    .L_select_vk_physical_device_fail:
    mov rcx, rdi                    ; ptr to malloc'd memory
    call free

    .L_select_vk_physical_device_fail_no_free:
    mov rax, 0

    .L_select_vk_physical_device_end:
    add rsp, 0x10 + SHADOW_SPACE
    pop rdi
    pop rsi
    pop rbp
    ret
;=============================== END select_vk_physical_device =================================

;===================== create_vk_device - arg1: Environment* - ret: bool =======================
create_vk_device:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10 + 0x50 + 0x50 + 0xE0 + SHADOW_SPACE  ; indices + VkDeviceQueueCreateInfo[2] + VkDeviceCreateInfo + VkPhysicalDeviceFeatures

    mov [rbp + 0x10], rcx                ; save env* ptr

    mov DWORD [rbp - 0x0C], f1_0         ; v1 = 1.0f

    ;rcx already has env*
    mov rdx, [rcx + ENV_VK_PHDEVICE]
    lea r8, [rbp - 0x08]                 ; &indices
    call find_queue_families
    test rax, rax
    jz .L_create_vk_device_fail

    ; check if either index is unassigned (-1)
    mov eax, [rbp - 0x08 + 0x00]          ; indices->graphicsFamily
    mov ecx, [rbp - 0x08 + 0x04]          ; indices->presentFamily
    test eax, ecx                         
    js .L_create_vk_device_fail           ; js -> jump if sign bit is set (indicates -1)
    xor eax, ecx                          ; sets ZF (zeroflag) if both indices are equal
    setz al        
    movzx eax, al
    mov DWORD [rbp - 0x10], eax           ; sets [rbp - 0x10] to 1 if both indices are equal

    ; memset both VkDeviceQueueCreateInfo structs to 0
    lea rcx, [rbp - 0x60]                 ; &VkDeviceQueueCreateInfo[0]
    mov rdx, 0                            ; 0
    mov r8,  0x50                         ; sizeof(VkDeviceQueueCreateInfo) * 2
    call memset

    ; fill the struct (graphicsFamily)
    mov DWORD [rbp - 0x60 + 0x00], 0x2    ; .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    mov eax,  [rbp - 0x08 + 0x00]         ; indices->graphicsFamily
    mov DWORD [rbp - 0x60 + 0x14], eax    ; .queueFamilyIndex = indices->graphicsFamily
    mov DWORD [rbp - 0x60 + 0x18], 1      ; .queueCount = 1
    lea rax,  [rbp - 0x0C]                ; &v1 (1.0f)
    mov QWORD [rbp - 0x60 + 0x20], rax    ; .pQueuePriorities = &v1

    ; check if we need to create another struct (only if the indices differ)
    mov eax, [rbp - 0x10]
    test eax, eax
    jnz .L_create_vk_device_after_queue_create_info

    ; fill the struct (presentFamily)
    mov DWORD [rbp - 0x38 + 0x00], 0x2    ; .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    mov eax,  [rbp - 0x08 + 0x04]         ; indices->presentFamily
    mov DWORD [rbp - 0x38 + 0x14], eax    ; .queueFamilyIndex = indices->presentFamily
    mov DWORD [rbp - 0x38 + 0x18], 1      ; .queueCount = 1
    lea rax,  [rbp - 0x0C]                ; &v1 (1.0f)
    mov QWORD [rbp - 0x38 + 0x20], rax    ; .pQueuePriorities = &v1

    .L_create_vk_device_after_queue_create_info:

    ; zero out deviceFeatures
    lea rcx, [rbp - 0x190]; &deviceFeatures
    mov rdx, 0            ; 0
    mov r8,  0xE0         ; sizeof(VkDeviceFeatures)
    call memset

    ; zero out deviceCreateInfo
    lea rcx, [rbp - 0xB0] ; &deviceCreateInfo
    mov rdx, 0            ; 0
    mov r8,  0x50         ; sizeof(VkDeviceCreateInfo)
    call memset

    ; fill deviceCreateInfo struct
    mov DWORD [rbp - 0xB0 + 0x00], 0x3    ; .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
    mov eax,  0x1                          
    add eax,  [rbp - 0x10]                ; count = 1 + indices_equal
    mov DWORD [rbp - 0xB0 + 0x14], eax    ; .queueCreateInfoCount = count
    lea rax,  [rbp - 0x60]                ; &queueCreateInfos
    mov QWORD [rbp - 0xB0 + 0x18], rax    ; .pQueueCreateInfos = &queueCreateInfos
    ; mov DWORD [rbp - 0xB0 + 0x30], 0    ; .enabledExtensionCount = 0
    ; mov QWORD [rbp - 0xB0 + 0x38], 0    ; .ppEnabledExtensionNames = NULL <- TODO: set these later when we get extensions
    lea rax,  [rbp - 0x190]               ; &deviceFeatures
    mov QWORD [rbp - 0xB0 + 0x40], rax    ; .pEnabledFeatures = &deviceFeatures

    ; call vkCreateDevice
    mov rax, [rbp + 0x10]                 ; load env ptr
    mov rcx, [rax + ENV_VK_PHDEVICE]      ; arg1: VkPhysicalDevice
    lea rdx, [rbp - 0xB0]                 ; arg2: &deviceCreateInfo
    mov r8,  0                            ; arg3: NULL
    lea r9,  [rax + ENV_VK_DEVICE]        ; arg4: &device
    call vkCreateDevice
    call check_vulkan_error
    test rax, rax
    jz .L_create_vk_device_fail

    ; get graphicsQueue
    mov rax, [rbp + 0x10]                 ; load env ptr
    mov rcx, [rax + ENV_VK_DEVICE]        ; arg1: env->device
    mov edx, [rbp - 0x08 + 0x00]          ; arg2: indices->graphicsFamily
    mov r8d, 0                            ; arg3: 0
    lea r9,  [rax + ENV_VK_GRAPHICSQUEUE] ; arg4: &env->graphicsQueue
    call vkGetDeviceQueue

    ; get presentQueue
    mov rax, [rbp + 0x10]                 ; load env ptr
    mov rcx, [rax + ENV_VK_DEVICE]        ; arg1: env->device
    mov edx, [rbp - 0x08 + 0x04]          ; arg2: indices->presentFamily
    mov r8d, 0                            ; arg3: 0
    lea r9,  [rax + ENV_VK_PRESENTQUEUE]  ; arg4: &env->presentQueue
    call vkGetDeviceQueue

    ; success:
    mov rax, TRUE
    jmp .L_create_vk_device_end

    .L_create_vk_device_fail:
    mov rax, FALSE
    .L_create_vk_device_end:
    add rsp, 0x10 + 0x50 + 0x50 + 0xE0 + SHADOW_SPACE
    pop rbp
    ret
;=================================== END create_vk_device ======================================

;======== is_device_suitable - arg1: Environment* - arg2: VkPhysicalDevice - ret: bool =========
is_device_suitable:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10 + SHADOW_SPACE ; indices

    mov [rbp + 0x10], rcx                 ; save arg1
    mov [rbp + 0x18], rdx                 ; save arg2

    ; rcx already has env*
    ; rdx already has VkDevice
    lea r8, [rbp - 0x08]                  ; &indices
    call find_queue_families
    test rax, rax
    jz .L_is_device_suitable_false

    ; check if either index is unassigned (-1)
    mov eax, [rbp - 0x08 + 0x00]          ; graphicsFamily
    or  eax, [rbp - 0x08 + 0x04]          ; eax = graphicsFamily | presentFamily
    test eax, eax  ; or already sets flags, not needed                       
    js .L_is_device_suitable_false        ; js -> jump if sign bit is set (indicates -1)

    mov rcx, [rbp + 0x18]                 ; load VkDevice
    call check_device_extension_support
    test rax, rax
    jz .L_is_device_suitable_false

    ; true:
    mov rax, TRUE
    jmp .L_is_device_suitable_end

    .L_is_device_suitable_false:
    mov rax, FALSE
    .L_is_device_suitable_end:
    add rsp, 0x10 + SHADOW_SPACE
    pop rbp
    ret
;================================== END is_device_suitable =====================================

;======== find_queue_families - arg1: Environment* - arg2: VkPhysicalDevice - arg3: QueueFamilyIndices* - ret: bool ========
find_queue_families:
    push rbp
    mov rbp, rsp
    push rsi   ; loop vars, popped at the end of the function
    push rdi
    push r12
    sub rsp, 0x10 + SHADOW_SPACE + 0x08 ; 0x8 alignment

    mov [rbp + 0x10], rcx        ; save env* ptr
    mov [rbp + 0x18], rdx        ; save VkPhysicalDevice
    mov [rbp + 0x20], r8         ; save QueueFamilyIndices* ptr#

    mov QWORD [r8], -1           ; set both QueueFamilyIndices to -1
    mov DWORD [rbp - 0x08], FALSE; presentSupport = 0

    ; call vkGetPhysicalDeviceQueueFamilyProperties to get the count
    mov rcx, rdx                 ; arg1: VkPhysicalDevice
    lea rdx, [rbp - 0x10]        ; arg2: &queueFamilyCount
    mov r8,  0                   ; arg3: NULL
    call vkGetPhysicalDeviceQueueFamilyProperties
    mov eax, [rbp - 0x010]       
    test eax, eax                ; if queueFamilyCount == 0 -> fail
    jz .L_find_queue_families_fail_no_free

    mov ecx, 0x18        
    imul ecx, eax                ; arg1: sizeof(VkQueueFamilyProperties) * queueFamilyCount
    call malloc
    test rax, rax
    jz .L_find_queue_families_fail_no_free
    mov rdi, rax                 ; rdi has the base ptr to VkQueueFamilyProperties

    ; call vkGetPhysicalDeviceQueueFamilyProperties to fill the ptr
    mov rcx, [rbp + 0x18]        ; arg1: VkPhysicalDevice
    lea rdx, [rbp - 0x10]        ; arg2: &queueFamilyCount
    mov r8,  rdi                 ; arg3: mallocd ptr
    call vkGetPhysicalDeviceQueueFamilyProperties

    mov rsi, 0                   ; rsi <- loop counter (i)
    mov r12, [rbp + 0x20]        ; load indices* into r12

    .L_find_queue_families_loop_begin:
    mov rax, rsi
    imul rax, 0x18               ; i * sizeof(VkQueueFamilyProperties) (mul implicitly uses rax as the source operand -> mul rax, 0x18)
    add rax, rdi                 ; rax = baseptr + i * sizeof(VkQueueFamilyProperties)

    test DWORD [rax + 0x00], 0x1 ; .queueFlags & VK_QUEUE_GRAPHICS_BIT
    jz .L_find_queue_families_skip_graphics_family
    mov DWORD [r12 + 0x00], esi  ; indices->graphicsFamily = i

    .L_find_queue_families_skip_graphics_family:
    mov rcx, [rbp + 0x18]        ; arg1: VkPhsyicalDevice
    mov edx, esi                 ; arg2: i 
    mov r9,  [rbp + 0x10]
    mov r8,  [r9  + ENV_SURFACE] ; arg3: env->VkSurface
    lea r9,  [rbp - 0x08]        ; arg4: &presentSupport
    call vkGetPhysicalDeviceSurfaceSupportKHR

    mov eax, [rbp - 0x08]
    test eax, eax                ; if (!presentSupport) skip to complete check
    jz .L_find_queue_families_skip_present_family
    mov DWORD [r12 + 0x04], esi  ; indices->presentFamily = i

    .L_find_queue_families_skip_present_family:
    mov eax, [r12 + 0x00]        ; graphicsFamily
    or  eax, [r12 + 0x04]        ; eax = graphicsFamily | presentFamily
    test eax, eax                ; restart loop if sign bit is set (js -> jump sign)
    jns .L_find_queue_families_loop_end

    inc rsi
    cmp rsi, [rbp - 0x10]
    jl .L_find_queue_families_loop_begin

    .L_find_queue_families_loop_end:
    mov rcx, rdi                 ; rdi <- ptr to malloc'd memory
    call free

    ; success:
    mov rax, TRUE
    jmp .L_find_queue_families_end

    .L_find_queue_families_fail:
    mov rcx, rdi                  ; rdi <- ptr to malloc'd memory
    call free
    .L_find_queue_families_fail_no_free:
    mov rax, FALSE

    .L_find_queue_families_end:
    add rsp, 0x10 + SHADOW_SPACE + 0x08 ; <- alignment
    pop r12
    pop rdi
    pop rsi
    pop rbp
    ret
;================================================ END find_queue_families ==================================================


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

; rcx -> Environment*, rdx -> VkPhysicalDevice, r8 -> QueueFamilyIndices*
;find_queue_families:
;    push rbp
;    mov rbp, rsp
;    sub rsp, 0x10 + SHADOW_SPACE ; uint32 + uint64 + SHADOW_SPACE
;
;    mov [rbp + 0x10], rcx ; Environment*
;    mov [rbp + 0x18], rdx ; VkPhysicalDevice
;    mov [rbp + 0x20], r8  ; QueueFamilyIndices
;
;    mov rcx, [rbp + 0x18] ; VkPhsyicalDevice
;    lea rdx, [rbp - 0x04] ; &count
;    mov r8, 0x0
;    call vkGetPhysicalDeviceQueueFamilyProperties
;
;    ; allocate space for queuefamilies
;    mov ecx, [rbp - 0x04] ; count
;    imul ecx, 0x18 ; size of queuefamilyproperties
;    call malloc
;    test rax, rax
;    jz .L_find_queue_families_malloc_fail
;    mov [rbp - 0x10], rax
;    
;    ; read in the queue families
;    mov rcx, [rbp + 0x18]
;    lea rdx, [rbp - 0x04]
;    mov r8, rax
;    call vkGetPhysicalDeviceQueueFamilyProperties
;
;    ;mov DWORD [rbp - 0x08], -1 ; -1 as default return value
;    ; initialize indices to sentinel value
;    mov rax,  [rbp + 0x20] ; QueueFamilyIndices*
;    mov DWORD [rax + 0x00], -1  ; indices->graphicsFamily = -1
;    mov DWORD [rax + 0x04], -1  ; indices->presentFamily  = -1
;    
;    ; save old registers and allocate shadow space
;    push rdi
;    push rsi
;    sub rsp, 0x20
;
;    mov esi, 0
;    mov rdi, [rbp - 0x10]
;
;.L_family_loop:
;    cmp esi, [rbp - 0x04]
;    jge .L_family_loop_end
;    ; check if (queueFamily.queueFlags & VK_QUEUE_GRAPHICS_BIT)
;    mov rcx, rsi
;    imul rcx, 0x18
;    add rcx, rdi
;
;    ;lea rcx, [rdi + rsi * 0x18]
;    mov edx, [rcx + 0x0] ; edx contains .queueFlags
;    and edx, 0x1         ; .queueFlags & VK_QUEUE_GRAPHICS_BIT
;    test edx, edx
;    jz .L_check_present_family
;    mov rax, [rbp + 0x20] ; QueueFamilyIndices*
;    mov DWORD [rax + 0x00], esi  ; indices->graphicsFamily = i
;.L_check_present_family:
;    mov rcx, [rbp + 0x18] ; a1 = device
;    mov edx, esi          ; a2 = i
;    mov rax, [rbp + 0x10] ; Environment
;    mov r8,  [rax + 0x08] ; a3 = Environment->surface
;    lea r9,  [rbp - 0x08]
;    call vkGetPhysicalDeviceSurfaceSupportKHR
;    mov eax, [rbp - 0x08]
;    test eax, eax
;    jz .L_family_loop_check
;    mov rax, [rbp + 0x20] ; QueueFamilyIndices*
;    mov DWORD [rax + 0x04], esi  ; indices->presentFamily = i
;
;.L_family_loop_check:
;    ; check here if both families have valid (!= -1) indices, if yes, break
;    mov rax, [rbp + 0x18] ; QueueFamilyIndices*
;    mov ecx, [rax + 0x00] ; indices->graphicsFamily
;    mov edx, [rax + 0x04] ; indices->presentFamily
;    or ecx, edx           ; is either -1?
;    cmp ecx, -1
;    je .L_family_loop_inc
;    jmp .L_family_loop_end
;
;.L_family_loop_inc:
;    inc rsi
;    jmp .L_family_loop
;
;.L_family_loop_end:
;    add rsp, 0x20 ; restore nonvolatile registers
;    pop rsi
;    pop rdi
;    
;    ;sucess:
;    mov rcx, [rbp - 0x10] ; malloc'd memory
;    call free
;    mov rax, 1
;    jmp .L_find_queue_families_end
;
;.L_find_queue_families_fail:
;    call free
;.L_find_queue_families_malloc_fail:
;    mov rax, 0
;
;.L_find_queue_families_end:
;    add rsp, 0x10 + SHADOW_SPACE
;    pop rbp
;    ret

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

;================ check_sdl_error - takes result from last SDL call - ret: bool ================
check_sdl_error:
    sub rsp, 0x8 + SHADOW_SPACE ; 0x20 shadow space, 0x8 alignment to 16 bytes
    test rax, rax
    jz .L_sdl_error
    mov eax, 1                  ; no error
    jmp .L_check_sdl_error_end
    
    .L_sdl_error:
    call SDL_GetError
    lea rcx, [log_sdl_error]
    mov rdx, rax
    call SDL_Log
    mov eax, 0                  ; error

    .L_check_sdl_error_end:
    add rsp, 0x8 + SHADOW_SPACE
    ret
;=================================== END check_sdl_error =======================================

;============= check_vulkan_error - takes result from last Vulkan call - ret: bool =============
check_vulkan_error:
    sub rsp, 0x8 + SHADOW_SPACE ; 0x20 shadow space, 0x8 alignment to 16 bytes
    test rax, rax
    jnz .L_vulkan_error
    mov eax, 1                  ; no error
    jmp .L_check_vulkan_error_end
    
    .L_vulkan_error:
    lea rcx, [log_vulkan_error]
    mov rdx, rax
    call SDL_Log
    mov eax, 0                  ; error
    
    .L_check_vulkan_error_end:
    add rsp, 0x28
    ret
;================================= END check_vulkan_error ====================================== 


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
    log_debug        db "Here", 0
    log_indices      db "graphicsFamily: %d presentFamily: %d", 0

    init_sdl_success db "Succesfully initialized SDL", 0
    create_vki_success db "Successfully created vulkan instance", 0
    create_vks_success db "Successfully created vulkan surface", 0
    pick_phd_success db "Successfully picked a physical device", 0
    create_vkd_success db "Successfully created vulkan device", 0

    is_sdl           db "Initialized SDL...", 0
    is_window        db "Initialized SDL window [0x%llX]...", 0
    is_vki           db "Initialized Vulkan instance [0x%llX]...", 0
    is_vks           db "Initialized Vulkan surface [0x%llX]...", 0
    is_phd           db "Initialized Vulkan physical device [0x%llX]...", 0
    is_vkd           db "Initialized Vulkan device [0x%llX]...", 0
    is_everything    db "Successfully initialized everything", 0

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



    

