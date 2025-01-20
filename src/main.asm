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
extrn SDL_GetWindowSizeInPixels
extrn vkCreateInstance
extrn vkDestroyInstance
extrn vkCreateDevice
extrn vkDestroyDevice
extrn vkGetDeviceQueue
extrn vkEnumerateDeviceExtensionProperties
extrn vkEnumeratePhysicalDevices
extrn vkGetPhysicalDeviceProperties
extrn vkGetPhysicalDeviceQueueFamilyProperties
extrn vkGetPhysicalDeviceSurfaceSupportKHR
extrn vkGetPhysicalDeviceSurfaceCapabilitiesKHR
extrn vkGetPhysicalDeviceSurfaceFormatsKHR
extrn vkGetPhysicalDeviceSurfacePresentModesKHR
extrn vkCreateSwapchainKHR
extrn vkDestroySwapchainKHR
extrn vkGetSwapchainImagesKHR
extrn malloc
extrn free
extrn memset
extrn strcmp

width = 1280
height = 720
SDL_INIT_VIDEO = 0x20
SDL_WINDOW_VULKAN = 0x0000000010000000

VK_FORMAT_B8G8R8A8_SRGB = 50
VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0
VK_PRESENT_MODE_IMMEDIATE_KHR = 0
VK_PRESENT_MODE_MAILBOX_KHR = 1
VK_PRESENT_MODE_FIFO_KHR = 2

VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000
VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010
VK_SHARING_MODE_EXCLUSIVE = 0
VK_SHARING_MODE_CONCURRENT = 1
VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001


TRUE = 1
FALSE = 0

SHADOW_SPACE = 0x20

f1_0 = 0x3f800000

;struc Environment {
;    .window               dq 0
;    .surface              dq 0
;    .vk_instance          dq 0
;    .vk_pysicaldevice     dq 0
;    .vk_device            dq 0
;    .vk_graphicsQueue     dq 0
;    .vk_presentQueue      dq 0
;    .vk_swapChain         dq 0
;    .vk_swapChainImages   dq 0
;    .swapChainImageCount  dq 0
;    .swapChainImageFormat dq 0
;    .swapChainExtent      dq 0
;}
ENV_SZ                      = 0x60
; members
ENV_WINDOW                  = 0x00
ENV_SURFACE                 = 0x08
ENV_VK_INSTANCE             = 0x10
ENV_VK_PHDEVICE             = 0x18
ENV_VK_DEVICE               = 0x20
ENV_VK_GRAPHICSQUEUE        = 0x28
ENV_VK_PRESENTQUEUE         = 0x30
ENV_VK_SWAPCHAIN            = 0x38
ENV_VK_SWAPCHAINIMAGES      = 0x40
ENV_VK_SWAPCHAINIMAGECOUNT  = 0x48
ENV_VK_SWAPCHAINIMAGEFORMAT = 0x50
ENV_VK_SWAPCHAINEXTENT      = 0x58
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


;struc SwapChainSupportDetails {
;    .capabilities     rb 0x38
;    .formats          dq 0
;    .formatsSize      dq 0
;    .presentModes     dq 0
;    .presentModesSize dq 0
;}
SCSD_SZ = 0x60
;members
SCSD_CAPABILITIES       = 0x00
SCSD_FORMATS            = 0x38
SCSD_FORMATS_SIZE       = 0x40
SCSD_PRESENT_MODES      = 0x48
SCSD_PRESENT_MODES_SIZE = 0x50
;members end

section '.text' code readable executable

;=========================================== main ==============================================
start:
    push          rbp
    mov           rbp, rsp
    sub           rsp, ENV_SZ + 0x10 + SHADOW_SPACE ; ENV_SZ(0x40) -> Environment, 0x10 -> return value, 0x20 -> Shadow Space

    mov           DWORD [rbp - ENV_SZ - 0x04], 1 ; store default return value

    lea           rcx, [rbp - ENV_SZ] ; Environment
    call          init
    test          eax, eax
    jz            .L_cleanup

    lea           rcx, [rbp - ENV_SZ]
    call          main_loop
    mov           [rbp - ENV_SZ - 0x04], eax ; store return value

    .L_cleanup:
    lea           rcx, [rbp - ENV_SZ]
    call          cleanup

    mov           eax, [rbp - ENV_SZ - 0x04] ; get stored return value
    add           rsp, ENV_SZ + 0x10 + SHADOW_SPACE
    pop           rbp
    ret
;========================================= END main ============================================

;=========================== init - arg1: Environment* - ret: bool =============================
init:
    push          rbp
    mov           rbp, rsp
    sub           rsp, SHADOW_SPACE ; 0x20 SHADOW_SPACE

    ; move arg (Environment*) to shadow space
    mov           [rbp + 0x10], rcx

    ; initialize SDL
    ;mov rcx, [rbp + 0x10] its already in rcx
    call          init_sdl
    test          rax, rax
    jz            .L_init_fail

    ; initialize Vulkan
    mov           rcx, [rbp + 0x10]
    call          init_vulkan
    test          rax, rax
    jz            .L_init_fail

    mov           rcx, is_everything
    call          SDL_Log

    ; success
    mov           rax, 1
    jmp           .L_init_end

    .L_init_fail:
    mov           rax, 0
    jmp           .L_init_end

    .L_init_end:
    add           rsp, SHADOW_SPACE
    pop           rbp
    ret
;======================================== END init =============================================

;========================= main_loop - arg1: Environment* - ret: int ===========================
main_loop:
    push          rbp
    mov           rbp, rsp
    sub           rsp, EVENT_SZ + SHADOW_SPACE

    mov           [rbp + 0x10], rcx ; mov Env* to shadow space

    .L_main_loop_poll_event:
    lea           rcx, [rbp - EVENT_SZ] ; first var on the stack, SDL_Event
    call          SDL_PollEvent
    mov           edx, [rbp - EVENT_SZ + EVENT_TYPE] ; (SDL_Event + 0x0) = event.type
    cmp           edx, SDL_EVENT_QUIT
    je            .L_main_loop_end
    test          rax, rax
    jnz           .L_main_loop_poll_event

    ;render everything here

    jmp           .L_main_loop_poll_event

    .L_main_loop_end:
    mov           rax, 0 ; zero indicates success here, return nonzero on failure
    add           rsp, EVENT_SZ + SHADOW_SPACE
    pop           rbp
    ret
;===================================== END main_loop ===========================================

;========================== cleanup - arg1: Environment* - ret: bool ===========================
cleanup:
    push          rbp
    mov           rbp, rsp
    sub           rsp, SHADOW_SPACE

    mov           [rbp + 0x10], rcx ; mov Env* to shadow space


    mov rax, [rbp + 0x10]
    mov rcx, [rax + ENV_VK_SWAPCHAINIMAGES]
    test rcx, rcx
    jz .L_cleanup_surface
    call free

    .L_cleanup_surface:
    ; SDL_Vulkan_DestroySurface
    mov           rax, [rbp + 0x10] ; load Env* pointer
    mov           rcx, [rax + ENV_VK_INSTANCE] ; environment.instance
    mov           rdx, [rax + ENV_SURFACE] ; environment.surface
    mov           r8,  0            ; NULL
    test          rcx, rcx         ; if vk_instance is NULL, skip over vulkan cleanup as the other vulkan resources will be invalid too
    jz            .L_cleanup_window
    test          rdx, rdx         ; if vk_surface is NULL, go to vkDestroyDevice
    jz            .L_cleanup_swapchain
    call          SDL_Vulkan_DestroySurface

    .L_cleanup_swapchain:
    mov rax, [rbp + 0x10]
    mov rcx, [rax + ENV_VK_DEVICE]
    mov rdx, [rax + ENV_VK_SWAPCHAIN]
    mov r8,  0
    test rcx, rcx
    jz .L_cleanup_instance
    test rdx, rdx
    jz .L_cleanup_device
    call vkDestroySwapchainKHR

    .L_cleanup_device:
    mov           rax, [rbp + 0x10] ; load Env* pointer
    mov           rcx, [rax + ENV_VK_DEVICE] ; environment.device
    mov           rdx, 0            ; NULL
    mov           r8, 0
    test          rcx, rcx
    jz            .L_cleanup_instance
    call          vkDestroyDevice

    .L_cleanup_instance:
    mov           rax, [rbp + 0x10] ; load Env* pointer
    mov           rcx, [rax + ENV_VK_INSTANCE] ; environment.instance
    mov           rdx, 0
    mov           r8, 0
    test          rcx, rcx
    jz            .L_cleanup_window
    call          vkDestroyInstance

    .L_cleanup_window:
    mov           rax, [rbp + 0x10] ; load Env* pointer
    mov           rcx, [rax + ENV_WINDOW] ; environment.window
    test          rcx, rcx
    jz            .L_cleanup_SDL
    call          SDL_DestroyWindow

    .L_cleanup_SDL:
    call          SDL_Quit
    mov           rax, 1
    add           rsp, SHADOW_SPACE
    pop           rbp
    ret
;======================================== END cleanup ==========================================

;========================== init_sdl - arg1: Environment* - ret: bool ==========================
init_sdl:
    push          rbp
    mov           rbp, rsp
    sub           rsp, SHADOW_SPACE

    ; move Environment* to shadow space
    mov           [rbp + 0x10], rcx

    ; SDL_Init
    mov           rcx, SDL_INIT_VIDEO
    call          SDL_Init
    call          check_sdl_error
    test          eax, eax
    jz            .L_sdl_init_fail

    mov           rcx, is_sdl
    call          SDL_Log


    ; SDL_CreateWindow
    lea           rcx, [window_title]
    mov           rdx, width
    mov           r8, height
    mov           r9, SDL_WINDOW_VULKAN
    call          SDL_CreateWindow
    mov           rcx, [rbp + 0x10]
    mov           [rcx + 0x00], rax ; Environment->window = window
    call          check_sdl_error
    test          eax, eax
    jz            .L_sdl_init_fail

    mov           rcx, is_window
    mov           rdx, [rbp + 0x10]
    mov           rdx, [rdx + ENV_WINDOW]
    call          SDL_Log

    ; success:
    mov           rax, 1
    jmp           .L_sdl_init_end

    .L_sdl_init_fail:
    mov           rax, 0

    .L_sdl_init_end:
    add           rsp, SHADOW_SPACE
    pop           rbp
    ret
;======================================= END init_sdl ==========================================

;======================== init_vulkan - arg1: Environment* - ret: bool =========================
init_vulkan:
    push          rbp
    mov           rbp, rsp
    sub           rsp, SHADOW_SPACE

    mov           [rbp + 0x10], rcx ; move arg1 to shadow space

    ; rcx already contains Env* ptr
    call          create_vk_instance
    test          rax, rax
    jz            .L_init_vulkan_fail

    mov           rcx, is_vki
    mov           rdx, [rbp + 0x10]
    mov           rdx, [rdx + ENV_VK_INSTANCE]
    call          SDL_Log


    mov           rcx, [rbp + 0x10] ; arg1 - Env*
    call          create_vk_surface
    test          rax, rax
    jz            .L_init_vulkan_fail

    mov           rcx, is_vks
    mov           rdx, [rbp + 0x10]
    mov           rdx, [rdx + ENV_SURFACE]
    call          SDL_Log


    mov           rcx, [rbp + 0x10] ; arg1 - Env*
    call          select_vk_physical_device
    test          rax, rax
    jz            .L_init_vulkan_fail

    mov           rcx, is_phd
    mov           rdx, [rbp + 0x10]
    mov           rdx, [rdx + ENV_VK_PHDEVICE]
    call          SDL_Log


    mov           rcx, [rbp + 0x10] ; arg1 - Env*
    call          create_vk_device
    test          rax, rax
    jz            .L_init_vulkan_fail

    mov           rcx, is_vkd
    mov           rdx, [rbp + 0x10]
    mov           rdx, [rdx + ENV_VK_DEVICE]
    call          SDL_Log


    mov rcx, [rbp + 0x10]
    call create_swap_chain
    test rax, rax
    jz .L_init_vulkan_fail

    mov           rcx, is_sc
    mov           rdx, [rbp + 0x10]
    mov           rdx, [rdx + ENV_VK_SWAPCHAIN]
    call          SDL_Log

    ; success
    mov           rax, 1
    jmp           .L_init_vulkan_end

    .L_init_vulkan_fail:
    mov           rax, 0
    .L_init_vulkan_end:
    add           rsp, SHADOW_SPACE
    pop           rbp
    ret
;====================================== END init_vulkan ========================================

;==================== create_vk_instance - arg1: Environment* - ret: bool ======================
create_vk_instance:
    push          rbp
    mov           rbp, rsp
    sub           rsp, 0x30 + 0x40 + 0x10 + SHADOW_SPACE ; VkApplicationInfo + VkInstanceCreateInfo + uint32

    mov           [rbp + 0x10], rcx ; save Environment* ptr

    ; zeroinit applicationInfo
    lea           rcx, [rbp - 0x30]  ; a1 = &applicationInfo
    mov           edx, 0             ; a2 = 0
    mov           r8,  0x30          ; a3 = sizeof(VkApplicationInfo)
    call          memset

    ; set up VkApplicationInfo
    ; VK_STRUCTURE_TYPE_APPLICATION_INFO is already 0 so no need to set .sType
    mov           DWORD [rbp - 0x30 + 0x2C], 0x403000  ; .apiVersion = VK_API_VERSION_1_3

    ; zeroinit createInfo
    lea           rcx, [rbp - 0x70]  ; a1 = &createInfo
    mov           edx, 0             ; a2 = 0
    mov           r8,  0x70          ; a3 = sizeof(VkInstanceCreateInfo)
    call          memset

    ; set up VkInstanceCreateInfo
    mov           DWORD [rbp - 0x70 + 0x00], 0x1       ; .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO

    lea           rax,  [rbp - 0x30]
    mov           [rbp - 0x70 + 0x18], rax       ; .pApplicationInfo = &applicationInfo (rbp - 0x30)

    ; could use at some point to enable debug layers
    ;mov DWORD [rbp - 0x70 + 0x20], 0x0       ; .enabledLayerCount = 0
    ;mov QWORD [rbp - 0x70 + 0x28], 0x0       ; .ppEnabledLayerNames = NULL

    ; get the instance extensions needed
    lea           rcx,  [rbp - 0x74]                   ; &count
    call          SDL_Vulkan_GetInstanceExtensions
    mov           ecx,  [rbp - 0x74]
    mov           [rbp - 0x70 + 0x30], ecx       ; .enabledExtensionCount = enabled_extension_count
    mov           [rbp - 0x70 + 0x38], rax       ; .ppEnabledExtensionNames = extension_names

    ; call vkCreateInstance
    lea           rcx,  [rbp - 0x70]                   ; createInfo = &createInfo
    mov           rdx, 0                               ; Allocator = NULL
    mov           r9,   [rbp + 0x10]                   ; env* ptr
    lea           r8,   [r9  + 0x10]                   ; instance = &instance
    call          vkCreateInstance
    call          check_vulkan_error
    test          rax, rax
    jz            .L_create_vk_instance_fail

    ; sucess
    mov           rax, 1
    jmp           .L_create_vk_instance_end

    .L_create_vk_instance_fail:
    mov           rax, 0

    .L_create_vk_instance_end:
    add           rsp, 0x30 + 0x40 + 0x10 + SHADOW_SPACE
    pop           rbp
    ret
;================================== END create_vk_instance =====================================

;===================== create_vk_surface - arg1: Environment* - ret: bool ======================
create_vk_surface:
    push          rbp
    mov           rbp, rsp
    sub           rsp, SHADOW_SPACE

    ; create surface
    mov           rax, rcx                     ; Environment*
    mov           rcx, [rax + ENV_WINDOW]      ; a1 = Environment->window
    mov           rdx, [rax + ENV_VK_INSTANCE] ; a2 = Environment->instance
    mov           r8,  0                       ; a3 = NULL
    lea           r9,  [rax + ENV_SURFACE]     ; a4 = &Environment->surface
    call          SDL_Vulkan_CreateSurface
    call          check_sdl_error
    test          eax, eax
    jz            .L_create_vk_surface_fail

    ;success
    mov           rax, 1
    jmp           .L_create_vk_surface_end

    .L_create_vk_surface_fail:
    mov           rax, 0

    .L_create_vk_surface_end:
    add           rsp, SHADOW_SPACE
    pop           rbp
    ret
;=================================== END create_vk_surface =====================================

;================= select_vk_physical_device - arg1: Environment* - ret: bool ==================
select_vk_physical_device:
    push          rbp
    mov           rbp, rsp
    push          rsi    ; for loop, pop at the end
    push          rdi    ; need to offset by - 0x10 for stack vars
    sub           rsp, 0x10 + SHADOW_SPACE ; uint32 count

    mov           [rbp + 0x10], rcx ; save Environment* ptr

    mov           rcx, [rcx + ENV_VK_INSTANCE] ; arg1: VkInstance
    lea           rdx, [rbp - 0x10 - 0x04]            ; arg2: &count
    mov           r8,  0                       ; arg3: NULL
    call          vkEnumeratePhysicalDevices
    call          check_vulkan_error
    test          rax, rax
    jz            .L_select_vk_physical_device_fail_no_free

    mov           ecx, [rbp - 0x10 - 0x04]            ; load count
    test          ecx, ecx                    ; if count == 0 -> no GPU found
    jz            .L_select_vk_physical_device_fail_no_free

    shl           ecx, 3                       ; arg1: count << 3 (count * 8),
    call          malloc
    test          rax, rax
    jz            .L_select_vk_physical_device_fail
    mov           rdi, rax                     ; save the malloc'd ptr in rdi

    mov           rax, [rbp + 0x10]
    mov           rcx, [rax + ENV_VK_INSTANCE] ; arg1: VkInstance
    lea           rdx, [rbp - 0x10 - 0x04]            ; arg2: &count
    mov           r8,  rdi                     ; arg3: malloc'd ptr
    call          vkEnumeratePhysicalDevices
    call          check_vulkan_error
    test          rax, rax
    jz            .L_select_vk_physical_device_fail

    mov           rsi, 0                       ; malloc'd ptr
    .L_select_vk_physical_device_loop_begin:
    ; count already checked for 0, no need to check at the beginning
    mov           rcx, [rbp + 0x10]            ; arg1: Env* ptr
    mov           rdx, [rdi + rsi * 0x8]       ; arg2: i'th device
    call          is_device_suitable
    test          rax, rax                    ; if (is_device_suitable(env, device)) break;
    jnz           .L_select_vk_physical_device_loop_end

    inc           rsi
    cmp           esi, [rbp - 0x10 - 0x4]             ; if (i >= count) goto fail (looped through all and not found)
    jge           .L_select_vk_physical_device_fail
    jmp           .L_select_vk_physical_device_loop_begin

    .L_select_vk_physical_device_loop_end:
    mov           rdx, [rdi + rsi * 0x8]      ; device
    mov           rax, [rbp + 0x10]           ; env* ptr
    mov           [rax + ENV_VK_PHDEVICE], rdx; env->phdevice = phdevices[i]
    mov           rcx, rdi                    ; ptr to malloc'd memory
    call          free

    ; success:
    mov           rax, 1
    jmp           .L_select_vk_physical_device_end

    .L_select_vk_physical_device_fail:
    mov           rcx, rdi                    ; ptr to malloc'd memory
    call          free

    .L_select_vk_physical_device_fail_no_free:
    mov           rax, 0

    .L_select_vk_physical_device_end:
    add           rsp, 0x10 + SHADOW_SPACE
    pop           rdi
    pop           rsi
    pop           rbp
    ret
;=============================== END select_vk_physical_device =================================

;===================== create_vk_device - arg1: Environment* - ret: bool =======================
create_vk_device:
    push          rbp
    mov           rbp, rsp
    sub           rsp, 0x10 + 0x50 + 0x50 + 0xE0 + SHADOW_SPACE  ; indices + VkDeviceQueueCreateInfo[2] + VkDeviceCreateInfo + VkPhysicalDeviceFeatures

    mov           [rbp + 0x10], rcx                ; save env* ptr

    mov           DWORD [rbp - 0x0C], f1_0         ; v1 = 1.0f

    ;rcx already has env*
    mov           rdx, [rcx + ENV_VK_PHDEVICE]
    lea           r8, [rbp - 0x08]                 ; &indices
    call          find_queue_families
    test          rax, rax
    jz            .L_create_vk_device_fail

    ; check if either index is unassigned (-1)
    mov           eax, [rbp - 0x08 + 0x00]          ; indices->graphicsFamily
    mov           ecx, [rbp - 0x08 + 0x04]          ; indices->presentFamily
    test          eax, ecx
    js            .L_create_vk_device_fail           ; js -> jump if sign bit is set (indicates -1)
    xor           eax, ecx                          ; sets ZF (zeroflag) if both indices are equal
    setz          al
    movzx         eax, al
    mov           DWORD [rbp - 0x10], eax           ; sets [rbp - 0x10] to 1 if both indices are equal

    ; memset both VkDeviceQueueCreateInfo structs to 0
    lea           rcx, [rbp - 0x60]                 ; &VkDeviceQueueCreateInfo[0]
    mov           rdx, 0                            ; 0
    mov           r8,  0x50                         ; sizeof(VkDeviceQueueCreateInfo) * 2
    call          memset

    ; fill the struct (graphicsFamily)
    mov           DWORD [rbp - 0x60 + 0x00], 0x2    ; .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    mov           eax,  [rbp - 0x08 + 0x00]         ; indices->graphicsFamily
    mov           DWORD [rbp - 0x60 + 0x14], eax    ; .queueFamilyIndex = indices->graphicsFamily
    mov           DWORD [rbp - 0x60 + 0x18], 1      ; .queueCount = 1
    lea           rax,  [rbp - 0x0C]                ; &v1 (1.0f)
    mov           QWORD [rbp - 0x60 + 0x20], rax    ; .pQueuePriorities = &v1

    ; check if we need to create another struct (only if the indices differ)
    mov           eax, [rbp - 0x10]
    test          eax, eax
    jnz           .L_create_vk_device_after_queue_create_info

    ; fill the struct (presentFamily)
    mov           DWORD [rbp - 0x38 + 0x00], 0x2    ; .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    mov           eax,  [rbp - 0x08 + 0x04]         ; indices->presentFamily
    mov           DWORD [rbp - 0x38 + 0x14], eax    ; .queueFamilyIndex = indices->presentFamily
    mov           DWORD [rbp - 0x38 + 0x18], 1      ; .queueCount = 1
    lea           rax,  [rbp - 0x0C]                ; &v1 (1.0f)
    mov           QWORD [rbp - 0x38 + 0x20], rax    ; .pQueuePriorities = &v1

    .L_create_vk_device_after_queue_create_info:

    ; zero out deviceFeatures
    lea           rcx, [rbp - 0x190]; &deviceFeatures
    mov           rdx, 0            ; 0
    mov           r8,  0xE0         ; sizeof(VkDeviceFeatures)
    call          memset

    ; zero out deviceCreateInfo
    lea           rcx, [rbp - 0xB0] ; &deviceCreateInfo
    mov           rdx, 0            ; 0
    mov           r8,  0x50         ; sizeof(VkDeviceCreateInfo)
    call          memset

    ; fill deviceCreateInfo struct
    mov           DWORD [rbp - 0xB0 + 0x00], 0x3    ; .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
    mov           eax,  0x1
    add           eax,  [rbp - 0x10]                ; count = 1 + indices_equal
    mov           DWORD [rbp - 0xB0 + 0x14], eax    ; .queueCreateInfoCount = count
    lea           rax,  [rbp - 0x60]                ; &queueCreateInfos
    mov           QWORD [rbp - 0xB0 + 0x18], rax    ; .pQueueCreateInfos = &queueCreateInfos
    mov           DWORD [rbp - 0xB0 + 0x30], required_extensions_size    ; .enabledExtensionCount = required_extensions_size
    lea           rax,  [required_extensions]       ; required_extensions
    mov           QWORD [rbp - 0xB0 + 0x38], rax    ; .ppEnabledExtensionNames = required_extensions
    lea           rax,  [rbp - 0x190]               ; &deviceFeatures
    mov           QWORD [rbp - 0xB0 + 0x40], rax    ; .pEnabledFeatures = &deviceFeatures

    ; call vkCreateDevice
    mov           rax, [rbp + 0x10]                 ; load env ptr
    mov           rcx, [rax + ENV_VK_PHDEVICE]      ; arg1: VkPhysicalDevice
    lea           rdx, [rbp - 0xB0]                 ; arg2: &deviceCreateInfo
    mov           r8,  0                            ; arg3: NULL
    lea           r9,  [rax + ENV_VK_DEVICE]        ; arg4: &device
    call          vkCreateDevice
    call          check_vulkan_error
    test          rax, rax
    jz            .L_create_vk_device_fail

    ; get graphicsQueue
    mov           rax, [rbp + 0x10]                 ; load env ptr
    mov           rcx, [rax + ENV_VK_DEVICE]        ; arg1: env->device
    mov           edx, [rbp - 0x08 + 0x00]          ; arg2: indices->graphicsFamily
    mov           r8d, 0                            ; arg3: 0
    lea           r9,  [rax + ENV_VK_GRAPHICSQUEUE] ; arg4: &env->graphicsQueue
    call          vkGetDeviceQueue

    ; get presentQueue
    mov           rax, [rbp + 0x10]                 ; load env ptr
    mov           rcx, [rax + ENV_VK_DEVICE]        ; arg1: env->device
    mov           edx, [rbp - 0x08 + 0x04]          ; arg2: indices->presentFamily
    mov           r8d, 0                            ; arg3: 0
    lea           r9,  [rax + ENV_VK_PRESENTQUEUE]  ; arg4: &env->presentQueue
    call          vkGetDeviceQueue

    ; success:
    mov           rax, TRUE
    jmp           .L_create_vk_device_end

    .L_create_vk_device_fail:
    mov           rax, FALSE
    .L_create_vk_device_end:
    add           rsp, 0x10 + 0x50 + 0x50 + 0xE0 + SHADOW_SPACE
    pop           rbp
    ret
;=================================== END create_vk_device ======================================

;===================== create_swap_chain - arg1: Environment* - ret: bool ======================
create_swap_chain:
    push rbp
    mov rbp, rsp
    sub rsp, SCSD_SZ + 0x20 + 0x70 + 0x10 + SHADOW_SPACE

    mov [rbp + 0x10], rcx

    ; rcx already has Env*
    mov rdx, [rcx + ENV_VK_PHDEVICE]
    lea r8, [rbp - SCSD_SZ]
    call query_swap_chain_support

    ; choose the best SurfaceFormat
    mov rcx, [rbp - SCSD_SZ + SCSD_FORMATS]
    mov edx, [rbp - SCSD_SZ + SCSD_FORMATS_SIZE]
    call choose_swap_chain_format
    mov [rbp - SCSD_SZ - 0x20], rax ; VkSurfaceFormatKHR

    ; choose the best PresentMode
    mov rcx, [rbp - SCSD_SZ + SCSD_PRESENT_MODES]
    mov edx, [rbp - SCSD_SZ + SCSD_PRESENT_MODES_SIZE]
    call choose_swap_present_mode
    mov [rbp - SCSD_SZ - 0x18], eax ; VkPresentModeKHR

    ; choose the correct SwapExtent
    mov rcx, [rbp + 0x10] ; env
    lea rdx, [rbp - SCSD_SZ + SCSD_CAPABILITIES]
    call choose_swap_extent
    mov [rbp - SCSD_SZ - 0x10], rax ; VkExtent2D

    ; free malloc'd ptr in query_swap_chain_support
    mov rcx, [rbp - SCSD_SZ + SCSD_FORMATS]
    call free
    mov rcx, [rbp - SCSD_SZ + SCSD_PRESENT_MODES]
    call free

    ; get the imageCount, preferably as minImageCount + 1
    mov eax, [rbp - SCSD_SZ + SCSD_CAPABILITIES + 0x00] ; minImageCount
    inc eax ; + 1
    mov [rbp - SCSD_SZ - 0x14], eax           ; imageCount = minImageCount + 1
    mov ecx, [rbp - SCSD_SZ + SCSD_CAPABILITIES + 0x04]
    test ecx, ecx ; maxImageCount == 0, skip
    jz .L_create_swap_chain_skip_image_clamp
    cmp eax, ecx 
    jle .L_create_swap_chain_skip_image_clamp ; imageCount <= maxImageCount, skip
    mov [rbp - SCSD_SZ - 0x14], ecx          ; imageCount = maxImageCount
    mov eax, ecx ; move it into eax so we have the endresult in eax in any scenario
    .L_create_swap_chain_skip_image_clamp:
    mov r10d, eax
    mov rax, [rbp + 0x10] ; load env ptr

    mov [rax + ENV_VK_SWAPCHAINIMAGECOUNT], r10d ; save the imageCount for the array

    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x00], VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR ; .sType
    mov QWORD [rbp - SCSD_SZ - 0x90 + 0x08], 0x0 ; .pNext
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x10], 0x0 ; .flags
    mov rcx,  [rax + ENV_SURFACE]
    mov QWORD [rbp - SCSD_SZ - 0x90 + 0x18], rcx ; .surface
    mov ecx,  [rbp - SCSD_SZ - 0x14]             ;  imageCount
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x20], ecx ; .minImageCount
    mov ecx,  [rbp - SCSD_SZ - 0x20 + 0x00]      ;  surfaceFormat.format
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x24], ecx ; .imageFormat
    mov ecx,  [rbp - SCSD_SZ - 0x20 + 0x04]      ;  surfaceFormat.colorSpace
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x28], ecx ; .imageColorSpace
    mov rcx,  [rbp - SCSD_SZ - 0x10]             ;  extent
    mov QWORD [rbp - SCSD_SZ - 0x90 + 0x2C], rcx ; .imageExtent
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x34], 0x1 ; .imageArrayLayers
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x38], VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT ; .imageUsage

    mov rcx, rax
    mov rdx, [rax + ENV_VK_PHDEVICE]
    lea r8,  [rbp - SCSD_SZ - 0xA0] ; &indices
    call find_queue_families

    mov ecx, [rbp - SCSD_SZ - 0xA0 + 0x00] ; indices->graphicsFamily
    cmp ecx, [rbp - SCSD_SZ - 0xA0 + 0x04] ; indices->presentFamily
    je .L_create_swap_chain_indices_equal  ; if equal, use VK_SHARING_MODE_EXCLUSIVE otherwise VK_SHARING_MODE_CONCURRENT
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x3C], VK_SHARING_MODE_CONCURRENT ; .imageSharingMode
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x40], 0x2 ; .queueFamilyIndexCount
    lea rcx,  [rbp - SCSD_SZ - 0xA0]             ; &indices
    mov QWORD [rbp - SCSD_SZ - 0x90 + 0x48], rcx ; .pQueueFamilyIndices
    jmp .L_create_swap_chain_after_indices

    .L_create_swap_chain_indices_equal:
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x3C], VK_SHARING_MODE_EXCLUSIVE ; .imageSharingMode
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x40], 0x0 ; .queueFamilyIndexCount
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x48], 0x0 ; .pQueueFamilyIndices
    
    .L_create_swap_chain_after_indices:
    mov ecx,  [rbp - SCSD_SZ + 0x00 + 0x28]      ; swapchainSupportDetails.capabilities.currentTransform
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x50], ecx ; .preTransform
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x54], VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR ; .compositeAlpha
    mov ecx,  [rbp - SCSD_SZ - 0x18]             ;  presentMode
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x58], ecx ; .presentMode
    mov DWORD [rbp - SCSD_SZ - 0x90 + 0x5C], TRUE; .clipped
    mov QWORD [rbp - SCSD_SZ - 0x90 + 0x60], 0x0 ; .oldSwapchain

    ; create the swap chain
    mov rax, [rbp + 0x10]
    mov rcx, [rax + ENV_VK_DEVICE]    ; device
    lea rdx, [rbp - SCSD_SZ - 0x90]   ; &createInfo
    mov r8,  0                        ; NULL
    lea r9,  [rax + ENV_VK_SWAPCHAIN] ; &swapChain
    call vkCreateSwapchainKHR
    call check_vulkan_error
    test rax, rax
    jz .L_create_swap_chain_fail

    mov rax, [rbp + 0x10]
    mov rcx, [rax + ENV_VK_DEVICE]
    mov rdx, [rax + ENV_VK_SWAPCHAIN]
    lea r8,  [rbp - SCSD_SZ - 0x14]
    mov r9,  0
    call vkGetSwapchainImagesKHR
    call check_vulkan_error
    test rax, rax
    jz .L_create_swap_chain_fail
    
    mov ecx, [rbp - SCSD_SZ - 0x14]
    shl ecx, 3  ; imageCount << 3 (imageCount * sizeof(VkImage))
    call malloc
    mov r10, [rbp + 0x10]
    mov [r10 + ENV_VK_SWAPCHAINIMAGES], rax ; move malloc'd ptr into env*, free later on cleanup
    test rax, rax
    jz .L_create_swap_chain_fail

    mov rcx, [r10 + ENV_VK_DEVICE]    ; device
    mov rdx, [r10 + ENV_VK_SWAPCHAIN] ; swapChain
    lea r8,  [rbp - SCSD_SZ - 0x14]   ; &imageCount
    mov r9,  rax                      ; swapChainImages ptr to fill
    call vkGetSwapchainImagesKHR

    mov rax, [rbp + 0x10]
    mov ecx, [rbp - SCSD_SZ - 0x20 + 0x00] ; surfaceFormat.format
    mov [rax + ENV_VK_SWAPCHAINIMAGEFORMAT], ecx ; save the format in env

    mov rcx, [rbp - SCSD_SZ - 0x10]         ; swapChainExtent
    mov [rax + ENV_VK_SWAPCHAINEXTENT], rcx ; save the extent in env

    ; success:
    mov rax, TRUE
    jmp .L_create_swap_chain_end

    .L_create_swap_chain_fail:
    mov rax, FALSE
    
    .L_create_swap_chain_end:
    add rsp, SCSD_SZ + 0x20 + 0x70 + 0x10 + SHADOW_SPACE
    pop rbp
    ret
;=================================== END create_swap_chain =====================================

;======== is_device_suitable - arg1: Environment* - arg2: VkPhysicalDevice - ret: bool =========
is_device_suitable:
    push          rbp
    mov           rbp, rsp
    sub           rsp, 0x10 + SCSD_SZ + SHADOW_SPACE ; indices, SwapChainSupportDetails

    mov           [rbp + 0x10], rcx                 ; save arg1
    mov           [rbp + 0x18], rdx                 ; save arg2

    ; rcx already has env*
    ; rdx already has VkDevice
    lea           r8, [rbp - 0x08]                  ; &indices
    call          find_queue_families
    test          rax, rax
    jz            .L_is_device_suitable_false

    ; check if either index is unassigned (-1)
    mov           eax, [rbp - 0x08 + 0x00]          ; graphicsFamily
    or            eax, [rbp - 0x08 + 0x04]          ; eax = graphicsFamily | presentFamily
    js            .L_is_device_suitable_false        ; js -> jump if sign bit is set (indicates -1)

    mov           rcx, [rbp + 0x18]                 ; load VkDevice
    call          check_device_extension_support
    test          rax, rax
    jz            .L_is_device_suitable_false

    mov rcx, [rbp + 0x10]
    mov rdx, [rbp + 0x18]
    lea r8, [rbp - 0x10 - SCSD_SZ]
    call query_swap_chain_support

    mov rcx, [rbp - 0x10 - SCSD_SZ + SCSD_FORMATS]
    test rcx, rcx
    jz .L_is_device_suitable_false_skip_format_free
    call free ; free malloc'd ptr

    mov rcx, [rbp - 0x10 - SCSD_SZ + SCSD_PRESENT_MODES]
    test rcx, rcx
    jz .L_is_device_suitable_false
    call free ; free malloc'd ptr

    ; true:
    mov           rax, TRUE
    jmp           .L_is_device_suitable_end


    .L_is_device_suitable_false_skip_format_free:
    mov rcx, [rbp - 0x10 - SCSD_SZ + SCSD_PRESENT_MODES]
    test rcx, rcx
    jz .L_is_device_suitable_false
    call free
    .L_is_device_suitable_false:
    mov           rax, FALSE
    
    .L_is_device_suitable_end:
    add           rsp, 0x10 + SCSD_SZ + SHADOW_SPACE
    pop           rbp
    ret
;================================== END is_device_suitable =====================================

;======== find_queue_families - arg1: Environment* - arg2: VkPhysicalDevice - arg3: QueueFamilyIndices* - ret: bool ========
find_queue_families:
    push          rbp
    mov           rbp, rsp
    push          rsi   ; loop vars, popped at the end of the function
    push          r12   ; due to this, - 0x20 is needed for stack acces
    push          rdi
    sub           rsp, 0x08 + 0x10 + SHADOW_SPACE ; 0x8 alignment

    mov           [rbp + 0x10], rcx        ; save env* ptr
    mov           [rbp + 0x18], rdx        ; save VkPhysicalDevice
    mov           [rbp + 0x20], r8         ; save QueueFamilyIndices* ptr#

    mov           QWORD [r8], -1           ; set both QueueFamilyIndices to -1
    mov           DWORD [rbp - 0x20 - 0x08], FALSE; presentSupport = 0

    ; call vkGetPhysicalDeviceQueueFamilyProperties to get the count
    mov           rcx, rdx                 ; arg1: VkPhysicalDevice
    lea           rdx, [rbp - 0x20 - 0x04] ; arg2: &queueFamilyCount
    mov           r8,  0                   ; arg3: NULL
    call          vkGetPhysicalDeviceQueueFamilyProperties
    mov           eax, [rbp - 0x20 - 0x04]
    test          eax, eax                ; if queueFamilyCount == 0 -> fail
    jz            .L_find_queue_families_fail_no_free

    mov           ecx, 0x18
    imul          ecx, eax                ; arg1: sizeof(VkQueueFamilyProperties) * queueFamilyCount
    call          malloc
    test          rax, rax
    jz            .L_find_queue_families_fail_no_free
    mov           rdi, rax                 ; rdi has the base ptr to VkQueueFamilyProperties

    ; call vkGetPhysicalDeviceQueueFamilyProperties to fill the ptr
    mov           rcx, [rbp + 0x18]        ; arg1: VkPhysicalDevice
    lea           rdx, [rbp - 0x20 - 0x04] ; arg2: &queueFamilyCount
    mov           r8,  rdi                 ; arg3: mallocd ptr
    call          vkGetPhysicalDeviceQueueFamilyProperties

    mov           rsi, 0                   ; rsi <- loop counter (i)
    mov           r12, [rbp + 0x20]        ; load indices* into r12

    .L_find_queue_families_loop_begin:
    mov           rax, rsi
    imul          rax, 0x18               ; i * sizeof(VkQueueFamilyProperties) (mul implicitly uses rax as the source operand -> mul rax, 0x18)
    add           rax, rdi                 ; rax = baseptr + i * sizeof(VkQueueFamilyProperties)

    test          DWORD [rax + 0x00], 0x1 ; .queueFlags & VK_QUEUE_GRAPHICS_BIT
    jz            .L_find_queue_families_skip_graphics_family
    mov           DWORD [r12 + 0x00], esi  ; indices->graphicsFamily = i

    .L_find_queue_families_skip_graphics_family:
    mov           rcx, [rbp + 0x18]        ; arg1: VkPhsyicalDevice
    mov           edx, esi                 ; arg2: i
    mov           r9,  [rbp + 0x10]
    mov           r8,  [r9  + ENV_SURFACE] ; arg3: env->VkSurface
    lea           r9,  [rbp - 0x20 - 0x08] ; arg4: &presentSupport
    call          vkGetPhysicalDeviceSurfaceSupportKHR

    mov           eax, [rbp - 0x20 - 0x08]
    test          eax, eax                ; if (!presentSupport) skip to complete check
    jz            .L_find_queue_families_skip_present_family
    mov           DWORD [r12 + 0x04], esi  ; indices->presentFamily = i

    .L_find_queue_families_skip_present_family:
    mov           eax, [r12 + 0x00]        ; graphicsFamily
    or            eax, [r12 + 0x04]        ; eax = graphicsFamily | presentFamily
    jns           .L_find_queue_families_loop_end ; jmp not sign bit -> jump if the sign bit on either index is not set

    inc           rsi
    cmp           rsi, [rbp - 0x20 - 0x04]
    jl            .L_find_queue_families_loop_begin

    .L_find_queue_families_loop_end:
    mov           rcx, rdi                 ; rdi <- ptr to malloc'd memory
    call          free

    ; success:
    mov           rax, TRUE
    jmp           .L_find_queue_families_end

    .L_find_queue_families_fail:
    mov           rcx, rdi                  ; rdi <- ptr to malloc'd memory
    call          free
    .L_find_queue_families_fail_no_free:
    mov           rax, FALSE

    .L_find_queue_families_end:
    add           rsp, 0x08 + 0x10 + SHADOW_SPACE; <- alignment
    pop           rdi
    pop           r12
    pop           rsi
    pop           rbp
    ret
;================================================ END find_queue_families ==================================================

;======== query_swap_chain_support - arg1: Environment* - arg2: VkPhysicalDevice - arg3: SwapChainSupportDetails* - ret: bool ========
query_swap_chain_support:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10 + SHADOW_SPACE

    mov [rbp + 0x10], rcx
    mov [rbp + 0x18], rdx
    mov [rbp + 0x20], r8 

    mov rcx, rdx          ; VkPhysicalDevice
    mov rax, [rbp + 0x10]
    mov rdx, [rax + ENV_SURFACE] ; surface
    ; r8 already contains pointer to details->capabilities
    call vkGetPhysicalDeviceSurfaceCapabilitiesKHR
    call check_vulkan_error
    test rax, rax
    jz .L_query_swap_chain_support_fail_no_free_formats

    mov rcx, [rbp + 0x18] ; VkPhysicalDevice
    mov rax, [rbp + 0x10]
    mov rdx, [rax + ENV_SURFACE] ; surface
    lea r8,  [rbp - 0x04] ; &formatCount
    mov r9,  0            ; NULL
    call vkGetPhysicalDeviceSurfaceFormatsKHR
    call check_vulkan_error
    test rax, rax
    jz .L_query_swap_chain_support_fail_no_free_formats
    cmp DWORD [rbp - 0x04], 0 ; if (formatCount == 0)
    je .L_query_swap_chain_support_skip_formats

    mov ecx, [rbp - 0x04] ; formatCount
    shl rcx, 3                  ; formatCount << 3 (*8 which is sizeof(VkSurfaceFormatKHR))
    call malloc
    mov rcx, [rbp + 0x20]       ; SwapChainSupportDetails*
    mov [rcx + SCSD_FORMATS], rax       ; SwapChainSupportDetails->formats = malloc(...)
    mov edx, [rbp - 0x04]       ; formatCount
    mov [rcx + SCSD_FORMATS_SIZE], edx       ; SwapChainSupportDetails->formatCount = formatCount
    test rax, rax
    jz .L_query_swap_chain_support_fail_no_free_formats
    
    mov rcx, [rbp + 0x18]       ; arg1: VkPhysicalDevice
    mov r8,  [rbp + 0x10]
    mov rdx, [r8 + ENV_SURFACE] ; surface
    lea r8,  [rbp - 0x04]       ; &formatCount
    mov r9, rax                 ; arg4: mallocd' ptr
    call vkGetPhysicalDeviceSurfaceFormatsKHR

    .L_query_swap_chain_support_skip_formats:
    mov rcx, [rbp + 0x18] ; VkPhysicalDevice
    mov rax, [rbp + 0x10] ; Env*
    mov rdx, [rax + ENV_SURFACE] ; Env->surface
    lea r8,  [rbp - 0x08] ; &presentModeCount
    mov r9,  0            ; NULL
    call vkGetPhysicalDeviceSurfacePresentModesKHR
    call check_vulkan_error
    test rax, rax
    jz .L_query_swap_chain_support_fail
    cmp DWORD [rbp - 0x08], 0 ; if (presentModeCount == 0)
    je .L_query_swap_chain_support_success

    mov ecx, [rbp - 0x08] ; presentModeCount
    shl rcx, 2            ; formatCount << 2 (*4 which is sizeof(VkPresentModeKHR))
    call malloc
    mov rcx, [rbp + 0x20]       ; SwapChainSupportDetails*
    mov [rcx + SCSD_PRESENT_MODES], rax       ; SwapChainSupportDetails->presentModes = malloc(...)
    mov edx, [rbp - 0x08]       ; presentModeCount
    mov [rcx + SCSD_PRESENT_MODES_SIZE], edx       ; SwapChainSupportDetails->presentModeCount = presentModeCount
    test rax, rax               ; malloc returned nullptr
    jz .L_query_swap_chain_support_fail

    mov rcx, [rbp + 0x18]       ; arg1: VkPhysicalDevice
    mov r8,  [rbp + 0x10]
    mov rdx, [r8 + ENV_SURFACE] ; surface
    lea r8,  [rbp - 0x08]       ; &presentModeCount
    mov r9, rax                 ; arg4: mallocd' ptr
    call vkGetPhysicalDeviceSurfacePresentModesKHR

    .L_query_swap_chain_support_success:
    mov rax, TRUE
    jmp .L_query_swap_chain_support_end

    .L_query_swap_chain_support_fail:
    mov rdx, [rbp + 0x20]
    mov rcx, [rdx + 0x38]       ; mallocd formats ptr
    call free
    .L_query_swap_chain_support_fail_no_free_formats:
    mov rax, FALSE
    .L_query_swap_chain_support_end:
    add rsp, 0x10 + SHADOW_SPACE
    pop rbp
    ret
;================================================== END query_swap_chain_support =====================================================

;============= check_device_extension_support - arg1: VkPhysicalDevice - ret: bool =============
check_device_extension_support:
    push          rbp
    mov           rbp, rsp
    push rdi
    push rsi
    push r12
    push r13
    sub rsp, 0x10 + required_extensions_size_aligned + SHADOW_SPACE ; uint64 + uint32
    ; - 0x20 is for all the pushed registers
    ; [rbp - 0x20 - 0x04] -> uint32 extensionCount
    ; [rbp - 0x20 - 0x08] -> uint32 checkCount
    ; [rbp - 0x20 - 0x10] -> malloc'd ptr
    ; [rbp - 0x20 - 0x10 - required_extensions_size_aligned] -> checkedArray

    mov [rbp + 0x10], rcx ; save VkPhysicalDevice
    
    mov DWORD [rbp - 0x20 - 0x08], required_extensions_size ; keep track of how many we still need to check
    cmp DWORD [rbp - 0x20 - 0x08], 0
    je .L_check_device_extension_support_true               ; if 0 extensions required, its true

    ; rcx already contains VkPhysicalDevice
    mov rdx, 0                   ; NULL
    lea r8, [rbp - 0x20 - 0x04]  ; &extensionCount
    mov r9, 0                    ; NULL
    call vkEnumerateDeviceExtensionProperties
    
    lea rcx, [rbp - 0x20 - 0x10 - required_extensions_size_aligned]
    mov rdx, 0
    mov r8, required_extensions_size_aligned
    call memset                 ; set checked array to 0

    mov ecx, 0x104
    imul ecx, [rbp - 0x20 - 0x04]
    call malloc
    test rax, rax
    jz .L_check_device_extension_support_false_no_free
    mov rdi, rax

    mov rcx, [rbp + 0x10]
    mov rdx, 0
    lea r8, [rbp - 0x20 - 0x04]
    mov r9, rax                 ; malloc'd ptr
    call vkEnumerateDeviceExtensionProperties
    
    mov r12, required_extensions ; base of inner loop
    mov rsi, 0 ; i = 0

    .L_check_device_extension_support_outer_loop_begin:
    cmp esi, [rbp - 0x20 - 0x04]               ; if the outer loop ends, return false, not all found
    jge .L_check_device_extension_support_false
    mov r13, 0 ; j = 0
    
    .L_check_device_extension_support_inner_loop_begin:
    cmp r13, required_extensions_size
    jge .L_check_device_extension_support_inner_loop_end
    cmp BYTE [rbp - 0x20 - 0x10 - required_extensions_size_aligned + r13], 1
    je .L_check_device_extension_support_inner_loop_skip
    mov rcx, rsi
    imul rcx, 0x104
    add rcx, rdi ; rcx now contains a char* to the extension name (available_extensions[i])
 
    mov rdx, [r12 + r13 * 0x08] ; rdx is not the jth required string (required_extensions[j])

    call strcmp
    test rax, rax
    jnz .L_check_device_extension_support_inner_loop_skip
    dec DWORD [rbp - 0x20 - 0x08]
    jz .L_check_device_extension_support_true
    mov BYTE [rbp - 0x20 - 0x10 - required_extensions_size_aligned + r13], 1

    .L_check_device_extension_support_inner_loop_skip:
    inc r13
    jmp .L_check_device_extension_support_inner_loop_begin

    .L_check_device_extension_support_inner_loop_end:
    inc rsi
    jmp .L_check_device_extension_support_outer_loop_begin

    .L_check_device_extension_support_true:
    mov rcx, rdi
    call free
    mov rax, TRUE
    jmp .L_check_device_extension_support_end

    .L_check_device_extension_support_false:
    mov rcx, rdi
    call free

    .L_check_device_extension_support_false_no_free:
    mov rax, FALSE

    .L_check_device_extension_support_end:
    add rsp, 0x10 + required_extensions_size_aligned + SHADOW_SPACE
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rbp
    ret
;============================ END check_device_extension_support ===============================

;============= choose_swap_chain_format - arg1: VkSurfaceFormatKHR* - arg2: count - ret: VkSurfaceFormatKHR (uint64) =============
choose_swap_chain_format:
    ; no need for new stack frame
    ; rcx contains base ptr, rdx count, r8 i
    mov r8, 0
    .L_choose_swap_chain_format_loop_begin:
    lea rax, [rcx + r8 * 0x08] ; availableFormats[i]
    cmp DWORD [rax + 0x00], VK_FORMAT_B8G8R8A8_SRGB           ; .format
    jne .L_choose_swap_chain_format_loop_end
    cmp DWORD [rax + 0x04], VK_COLOR_SPACE_SRGB_NONLINEAR_KHR ; .colorSpace
    jne .L_choose_swap_chain_format_loop_end           ; if both are equal, return the current
    mov rax, [rax] ; deref the pointer
    jmp .L_choose_swap_chain_format_end
    .L_choose_swap_chain_format_loop_end:
    inc r8
    cmp r8, rdx
    jl .L_choose_swap_chain_format_loop_begin

    ; default return 
    mov rax, [rcx + 0x00] ; availableFormats[0]

    .L_choose_swap_chain_format_end:
    ret
;=============================================== END choose_swap_chain_format ====================================================

;============= choose_swap_present_mode - arg1: VkPresentModeKHR* - arg2: count - ret: VkPresentModeKHR (uint32) =============
choose_swap_present_mode:
    ; no need for new stack frame
    ; rcx contains base ptr, rdx count, r8 i
    mov r8, 0

    .L_choose_swap_present_mode_loop_begin:
    lea rax, [rcx + r8 * 0x04] ; availablePresentModes[i]
    cmp DWORD [rax + 0x00], VK_PRESENT_MODE_MAILBOX_KHR
    jne .L_choose_swap_present_mode_loop_end
    mov rax, [rax] ; deref the ptr
    jmp .L_choose_swap_present_mode_end
    .L_choose_swap_present_mode_loop_end:
    inc r8
    cmp r8, rdx
    jl .L_choose_swap_present_mode_loop_begin

    .L_choose_swap_present_mode_end_default:
    mov rax, [rcx + 0x00] ; availableFormats[0]
    .L_choose_swap_present_mode_end:
    ret
;============================================= END choose_swap_present_mode ==================================================

;============= choose_swap_extent - arg1: Environment* - arg2: VkSurfaceCapabilitiesKHR* - ret: VkExtent2D (uint64) =============
choose_swap_extent:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10 + SHADOW_SPACE

    mov [rbp + 0x10], rcx
    mov [rbp + 0x18], rdx

    cmp DWORD [rdx + 0x08 + 0x00], 0xFFFFFFFF ; .currentExtent.width == uint32_max
    je .L_choose_swap_extent_get_extent
    mov rax, [rdx + 0x08] ; .currentExtent just return the current extent if one is already chosen
    jmp .L_choose_swap_extent_end
    .L_choose_swap_extent_get_extent:
    mov rcx, [rcx + 0x00] ; window
    lea rdx, [rbp - 0x08] ; &width
    lea r8,  [rbp - 0x04] ; &height
    call SDL_GetWindowSizeInPixels
    
    mov rax, [rbp + 0x18] ; get capabilities
    
    ; clamp width
    mov ecx, [rax + 0x10 + 0x00] ; minImageExtent.width
    cmp [rbp - 0x08], ecx
    jge .L_choose_swap_extent_clamp_width_max
    mov [rbp - 0x08], ecx  ; if (width < minImageExtent.width) width = minImageExtent.width
    
    .L_choose_swap_extent_clamp_width_max:
    mov ecx, [rax + 0x18 + 0x00] ; maxImageExtent.width
    cmp [rbp - 0x08], ecx
    jle .L_choose_swap_extent_clamp_height_min
    mov [rbp - 0x08], ecx  ; if (width > maxImageExtent.width) width = maxImageExtent.width

    ; clamp height
    .L_choose_swap_extent_clamp_height_min:
    mov ecx, [rax + 0x10 + 0x04] ; minImageExtent.height
    cmp [rbp - 0x04], ecx
    jge .L_choose_swap_extent_clamp_height_max
    mov [rbp - 0x04], ecx  ; if (height < minImageExtent.height) height = minImageExtent.height

    .L_choose_swap_extent_clamp_height_max:
    mov ecx, [rax + 0x18 + 0x04] ; maxImageExtent.height
    cmp [rbp - 0x04], ecx
    jle .L_choose_swap_extent_skip_clamp
    mov [rbp - 0x04], ecx  ; if (height > maxImageExtent.height) height = maxImageExtent.height

    .L_choose_swap_extent_skip_clamp:
    mov rax, [rbp - 0x08] ; get qword of width (width + height) into rax

    .L_choose_swap_extent_end:
    add rsp, 0x10 + SHADOW_SPACE
    pop rbp
    ret
;================================================== END choose_swap_extent ======================================================

;================ check_sdl_error - takes result from last SDL call - ret: bool ================
check_sdl_error:
    sub           rsp, 0x8 + SHADOW_SPACE ; 0x20 shadow space, 0x8 alignment to 16 bytes
    test          rax, rax
    jz            .L_sdl_error
    mov           eax, 1                  ; no error
    jmp           .L_check_sdl_error_end

    .L_sdl_error:
    call          SDL_GetError
    lea           rcx, [log_sdl_error]
    mov           rdx, rax
    call          SDL_Log
    mov           eax, 0                  ; error

    .L_check_sdl_error_end:
    add           rsp, 0x8 + SHADOW_SPACE
    ret
;=================================== END check_sdl_error =======================================

;============= check_vulkan_error - takes result from last Vulkan call - ret: bool =============
check_vulkan_error:
    sub           rsp, 0x8 + SHADOW_SPACE ; 0x20 shadow space, 0x8 alignment to 16 bytes
    test          rax, rax
    jnz           .L_vulkan_error
    mov           eax, 1                  ; no error
    jmp           .L_check_vulkan_error_end

    .L_vulkan_error:
    lea           rcx, [log_vulkan_error]
    mov           rdx, rax
    call          SDL_Log
    mov           eax, 0                  ; error

    .L_check_vulkan_error_end:
    add           rsp, 0x28
    ret
;================================= END check_vulkan_error ======================================

section '.data' data readable writeable
    window_title         db "ASM SDL Window!", 0
    log_sdl_error        db "SDL Error occured: %s", 0
    log_vulkan_error     db "Vulkan Error occured: 0x%X", 0
    vk_app_name          db "Vulkan App", 0
    vk_engine_name       db "No Engine", 0
    no_suitable_dev      db "No suitable physical device found", 0
    print_sep            db "-------------------------------", 0
    log_int              db "%d", 0
    log_ptr              db "0x%llX", 0
    log_ext_name         db "Device Extension: %s", 0
    log_debug            db "Here", 0
    log_indices          db "graphicsFamily: %d presentFamily: %d", 0
    log_str              db "string: %s", 0
    log_2str             db "str1: [%s] str2: [%s]", 0

    is_sdl               db "Initialized SDL...", 0
    is_window            db "Initialized SDL window [0x%llX]...", 0
    is_vki               db "Initialized Vulkan instance [0x%llX]...", 0
    is_vks               db "Initialized Vulkan surface [0x%llX]...", 0
    is_phd               db "Initialized Vulkan physical device [0x%llX]...", 0
    is_vkd               db "Initialized Vulkan device [0x%llX]...", 0
    is_sc                db "Initialized Vulkan swap chain [0x%llX]", 0
    is_everything        db "Successfully initialized everything", 0

    devprops_api         db "devprops apiVersion: 0x%X", 0
    devprops_driver      db "devprops driverVersion: 0x%X", 0
    devprops_vendor      db "devprops vendorID: 0x%X", 0
    devprops_deviceI     db "devprops deviceID: 0x%X", 0
    devprops_deviceT     db "devprops deviceType: 0x%X", 0
    devprops_deviceN     db "devprops deviceName: %s", 0


    quefam_amount        db "QueFamily deviceCount: %d", 0
    quefam_flags         db "queueFamily flags: 0x%X", 0
    quefam_count         db "queueFamily count: 0x%X", 0
    quefam_tsvb          db "queueFamily timestampValidBits: 0x%X", 0
    quefam_index         db "queueFamily index: %d", 0

    required_ext1        db "VK_KHR_swapchain", 0
    required_extensions  dq required_ext1
    required_extensions_size = ($ - required_extensions) / 8
    required_extensions_size_aligned = ((required_extensions_size + 15) / 16) * 16





