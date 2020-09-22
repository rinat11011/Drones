section .text
	align 16

	extern printf
	extern fprintf 
	extern malloc 
	extern calloc 
	extern free 
	extern sscanf

    extern print_drones
    extern print_target
    extern print_co_routine
    extern drone_co_routine
    extern scheduler_co_routine
    extern target_co_routine


    global main
    global drones_N 		  ; <N>
    global sched_cycle        ; <R>
    global steps_between      ; <K>
    global max_dist           ; <d>
    global target_x
    global target_y
    global drones_array
    global lfsr
    global drone_size
    global coroutine_size
    global drones_co_routine_array
    global sched_struct
    global printer_struct
    global target_struct
    global random_num
    global curr
    global curr_drone_ID  
    global resume
    global num_active_drones
    global endCo

    STKSIZE EQU 16*1024
    SPP     EQU 4

section	.rodata						; we define (global) read-only variables in .rodata section
	scanf_int: 		   db "%d", 0
    scanf_float:       db "%f", 0
    
section .data
    xor_carry:          dd 0
    lfsr:               dd 0
    MAX_INT:            dd 0xffff
    drone_size:         dd 44
    drones_array:       dd 0
    low_bound:          dd 0  
    high_bound:         dd 0
    store_res:          dd 0
    drones_co_routine_array:    dd 0
    curr_drone_ID:      dd 0          ; ID of the current drone 



    coroutine_size:     dd 12

section .bss
	drones_N: 	        resd 1		  ;number of drones <N>
    sched_cycle:        resd 1          ;number of full scheduler cycles between each elimination  <R>
    steps_between:      resd 1          ; how many drone steps between game board printings <K>
    max_dist:           rest 1          ; maximum distance that allows to destroy a target <d>
    seed:               resd 1          ; seed for initialization of LFSR shift register <seed>
    target_x:           rest 1          
    target_y:           rest 1   
    stack_ptr:          resd 1          ; esp - ptr to the head of stack of each co routine
    stack_addr:         resd 1          ; ebp - ptr to the address of the stack 
    sched_struct:       resd 3          ; 
    printer_struct:     resd 3          ; -> coroutines are 3 pointers [FUNCI, ESP, EBP] - each 4bytes
    target_struct:      resd 3          ;
    spt:                resd 1          ; temp stack pointer
    spmain:             resd 1          ; stack pointer of main
    curr:               resd 1          ; current co-routine
    num_active_drones:  resd 1

section .text
    ;============================ MACROS ============================

%macro sscanf_func 2 		; get next argument from ecx to %1 with %2 variable format
    add ecx, 4
    push ecx
    push %1                 ; push the arg 
	push %2				    ; push the format
	push dword[ecx]				    ; push the target variable
	call sscanf
	add esp, 12
    pop ecx
%endmacro

%macro get_random 3         ; set random number between %3 to %2 - store it in %1
    pushad
    push %1
    push %2
    push %3
    call random_num
    add esp,12
    popad
%endmacro

%macro set_co_routines 2                        ;  %1 - FUNCI , %2 - drones_co_routine
    mov eax, %2
    mov dword[eax], %1                              ; eax = FUNCI
    add eax, 4

    pushad

    push dword 1                                    ;
    push dword STKSIZE                              ;
    call calloc                                     ;       ->  allocate memory of stack for each co routine 
    add esp, 8                                      ;

    mov dword[stack_addr], eax                     ; save the stack address - EBP
    add eax, STKSIZE                                ;
    mov dword[stack_ptr], eax                       ; save a pointer to the new allocated stack - ESP

    popad
    push ebx
    mov ebx, dword[stack_ptr]                ; eax = STACK_PTR
    mov dword[eax], ebx
    add eax, 4
    mov ebx, dword[stack_addr]               ; eax = STACK_ADDRESS
    mov dword[eax], ebx
    add eax, 4
    pop ebx
%endmacro

%macro init_co_routines 1           ; struct/array of co-routines to initialize
    mov eax, %1                     ; co routine to initialize 
    mov ebx, dword[eax]                  ; eax = FUNCI
    add eax, 4
    mov dword[spt], esp                  ; save esp in temp esp - to back up the register
    mov esp, dword[eax]            ; esp - points to the head of the stack of the curr co routine
    push ebx                        ; push funci to the stack
    pushfd
    pushad                          ; push regs and flags
    mov dword[eax] , esp           ; add the current position on the stack of the co routine to ebx
    mov esp, dword[spt]                  ; return esp to its previos state

%endmacro

%macro clean_co 1                   ; %1 is the current co routine to be freed
    mov eax, %1
    ;pushad
    add eax, 8                      ; ebx = ptr to the stack
    push eax
    mov eax, dword[eax]             ; eax = stack
    
    push eax                        ; push co routines stack to the free func
    call free
    add esp, 4
    pop eax

%endmacro


    ;======================= START PROGRAM =========================

main:
	push ebp
	mov ebp, esp
    mov ecx , dword[ebp+12]		;pointer to pointers of arguments (**)
    ; ====== floating point representation - x , y , angle , speed =====
    finit
    sscanf_func drones_N, scanf_int        ; get <N>
    mov eax, dword[drones_N]
    mov dword[num_active_drones] , eax
    sscanf_func sched_cycle, scanf_int     ; get <R>
    sscanf_func steps_between, scanf_int   ; get <K>
    sscanf_func max_dist , scanf_float     ; get <d>
    ;sscanf_func max_dist , scanf_int     ; get <d>
    sscanf_func seed, scanf_int            ; get <seed> 
    
    ; ===================== init ====================
    finit
    
    mov ebx, dword[seed]
    mov word[lfsr], bx

;----------- init target (x, y) -------------
    mov ecx, 0

    get_random target_x, 100, 0
    get_random target_y, 100, 0

; ----------- allocate drones array --------------

    push dword[drone_size]
    push dword[drones_N]
    call calloc
    add esp, 8
    mov dword[drones_array], eax            ; drones_array = ptr-> [x,y,alpha,speed,num_hits]

;------------ init drones array ------------------

    mov ecx, dword[drones_N]                ; ecx = number of loop iterations

    create_N_drones:

        get_random eax, 100, 0              ; random - x cordination
        add eax, 10                         ; move eax to the next variable
        get_random eax, 100, 0              ; random - y cordination
        add eax, 10
        get_random eax, 360, 0              ; random alpha 
        add eax, 10
        get_random eax, 100, 0              ; random speed 
        add eax, 10
        mov dword[eax], 0                   ; num of hits = 0   
        add eax, 4
    loop create_N_drones, ecx



;-------------- allocate co-routine array ---------
    ; each co-routine will be -> [funci, esp = stack_addr+stk_size (stack_ptr) , ebp = stack_addr]

    push dword[coroutine_size]
    push dword[drones_N]
    call calloc
    add esp, 8
    mov dword[drones_co_routine_array], eax   

;------ set all co-routines --------
; eax = coroutine array

    mov ecx, dword[drones_N]
    ;mov dword[eax], drones_co_routine_array 
    
    ; set drones coroutines 
    set_co_routines_loop:
        ;push ecx
        pushad
        set_co_routines drone_co_routine, eax
        popad
        ;pop ecx
        add eax, 12
    loop set_co_routines_loop, ecx


    set_co_routines print_co_routine, printer_struct     ; set printer coroutine
    set_co_routines scheduler_co_routine, sched_struct       ; set scheduler coroutine
    set_co_routines target_co_routine, target_struct      ; set target coroutine

;--------------- init all co-routines -----------

    mov ecx, dword[drones_N]
    mov eax, dword[drones_co_routine_array]
    mov edx, 0
    ; init drones coroutines 
    init_drones:
        ;mov eax, dword[drones_co_routine_array + edx * 12]
        pushad
        init_co_routines eax
        popad
        add eax, 12
    loop init_drones, ecx
    
    init_co_routines printer_struct     ; init printer coroutine
    init_co_routines sched_struct       ; init scheduler coroutine
    init_co_routines target_struct      ; init target coroutine


;--------------- start the game -----------
    startCo:
        pushad
        mov [spmain], esp               ; save main pointer
        mov ebx, sched_struct           ; ebx = ptr to a scheduler struct
        jmp do_resume                   ; resume a scheduler coroutine

    endCo:
        mov esp, [spmain]               ; restore esp of main
        popad

finish:
    call clean_all
    mov esp, ebp	
    pop ebp
    ret



random_num:                 ; random(lowBound, highBound, resLocation) -> returns a random number in float-rep according to the range
    push ebp
	mov ebp, esp

    mov ebx, [ebp+8]        ; lowBound 
    mov ecx, [ebp+12]       ; highBound
    mov edx, [ebp+16]
    mov dword[low_bound], ebx
    mov dword[high_bound], ecx
    mov dword[store_res], edx 

    mov ebx,0
    mov ecx, 0
    mov edx, 0
    mov ecx, 16

    loop_lfsr:
        push ecx
        mov dword[xor_carry], 0
        mov eax, 0
        mov edx, 0
        mov ebx, 0

        mov ecx, 6                      ; loop 6 times - to do xor for each tap
        mov eax, 45                     ; 45 = (101101)2 - taps 11 13 14 16
        mov ebx, [lfsr]                 ; mov to ecx the current lfsr
        and eax, ebx                    ; eax = (11) 0 (13) (14) 0 (16)
        
        xor_taps:                       ; shift eax 1 byte at a time, each time xor the carry flag with the last xor result
            shr eax, 1
            jnc next_iter_xor
            mov dl, byte[xor_carry]
            xor edx, 1
            mov byte[xor_carry], dl

        next_iter_xor:
            loop xor_taps, ecx
        


        mov edx, 0
        mov edx, dword[xor_carry]
        shl edx, 15                     ; edx = 0...0 - 16 times or 10...0
        shr ebx, 1
        or ebx, edx
        mov word[lfsr], bx
        pop ecx
    loop loop_lfsr, ecx

    finit
    fild dword[lfsr]        ; st(0) = [lfsr]
    fidiv dword[MAX_INT]    ; st(0) = lfsr/max int
    
    fild dword[high_bound]
    fisub dword[low_bound] 
    fmul                              ; lfsr/MAX_INT * range 
    fiadd dword[low_bound]            ; lfsr/MAX_INT * range + min
    

    mov eax, dword[store_res]
    fstp tword[eax]                     ; storing the result in argv[3]
    fild dword[store_res]        ; st(0) = [lfsr]

    mov esp, ebp
    pop ebp
    ret



clean_all:
    push ebp
	mov ebp, esp
    
    ; ---- free the drones allocates space -----
    ;mov eax, dword[drones_array]
    push dword[drones_array]
    call free
    add esp, 4

    ; ---- free drones co routines ------

    mov eax, dword[drones_co_routine_array]
    mov ecx, dword[drones_N]                    

    clean_co_drones:
        ;mov ebx, eax             ; ebx = ptr to the curr co routine
        push ecx
        clean_co eax
        pop ecx
        add eax, 4                      ; eax = next drones co routine
    loop clean_co_drones, ecx

    con_co:
    push dword[drones_co_routine_array]
    call free
    add esp, 4
    con_co2:
    clean_co printer_struct
    clean_co sched_struct
    clean_co target_struct


    mov esp, ebp
    pop ebp
    ret


resume:
    pushfd
    pushad
    mov edx, dword[curr]                 ; edx = struct of curr co routine
    mov [edx+SPP], esp              ; save current esp

do_resume:
    mov esp, dword[ebx+SPP]
    mov dword[curr], ebx
    popad
    popfd
    ret