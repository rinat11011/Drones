section	.rodata						; we define (global) read-only variables in .rodata section
	format_target:     db "%f,%f",10, 0       
    format_drone:      db "%d,%f,%f,%f,%f,%u",10,0      ; id, x , y , angle, speed, num of hits

section .text
	align 16

	extern printf

	extern main
    extern drones_N 		  ; <N>
    extern target_x
    extern target_y
    extern drones_array
    extern drone_size
    extern sched_struct
    extern resume

    global print_drones
    global print_target
    global print_co_routine


; drones_array = ptr-> [x,y,alpha,speed,num_hits]

print_co_routine:
    call print_target
    call print_drones

    mov ebx, sched_struct
    push ebx
    call resume
    pop ebx
    jmp print_co_routine

print_drones:
    push ebp
	mov ebp, esp
    mov ecx, dword[drones_N]        
    mov ebx, dword[drones_array]    ; eax = ptr to the drones array
    mov edx, 1                      ; id counter

    finit

    print_drones_loop:
        pushad
        
        finit
        cmp dword[ebx+40], -1                      ; if drone is eliminated - step over
        je cont

        fld tword[ebx]                          ; st(0) = x
        add ebx, 10
        
        fld tword[ebx]                          ; st(0) = y , st(1) = x
        add ebx, 10
        
        fld tword[ebx]                          ; st(0) = angle , st(1) = y, st(2) = x
        add ebx, 10
        
        fld tword[ebx]                          ; st(0) = speed ,....
        add ebx, 10

        push dword[ebx]                         ; num of hits
        add ebx, 4
        sub esp, 8
        fstp qword[esp]                 ; push st(0) to the stack - speed
        
        sub esp, 8
        fstp qword[esp]                 ; push st(0) to the stack - alpha
        
        sub esp, 8        
        fstp qword[esp]                 ; push st(0) to the stack - y
        
        sub esp, 8
        fstp qword[esp]                 ; push st(0) to the stack - x

        push edx
        push format_drone              
        call printf
        add esp, 44
        popad

        cont:

            inc edx
            add ebx, dword[drone_size]
    loop print_drones_loop, ecx

    mov esp, ebp	
    pop ebp
    ret

print_target:
	push ebp
	mov ebp, esp	

    finit
    fld tword[target_x]             ; st(0) = x 
    fld tword[target_y]             ; st(1) = x , st(0) = y
    sub esp, 8
    fstp qword[esp]                 ; push st(0) to the stack
    sub esp, 8
    fstp qword[esp]                 ; push st(0) to the stack
    push format_target              
    call printf
    add esp, 20

    mov esp, ebp	
    pop ebp
    ret