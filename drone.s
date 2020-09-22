
section .text
	align 16
	extern main
    extern max_dist             ; <d>
    extern target_x
    extern target_y
    extern drones_array
    extern drone_size
    extern random_num
    extern curr_drone_ID
    extern sched_struct
    extern target_struct
    extern resume

    global drone_co_routine

section .data
    current_x:      dt 0.0
    current_y:      dt 0.0
    delta_angle:    dt 0.0
    delta_speed:    dt 0.0
    current_angle:  dt 0.0
    current_speed:  dt 0.0
    radian_angle:   dt 0.0 
    max_board:      dd 100
    max_angle:      dd 360
    may_des:        db 0
    flat_angle:     dd 180

section .text
%macro get_random 3         ; set random number between %3 to %2 - store it in %1
    pushad
    push %1
    push %2
    push %3
    call random_num
    add esp,12
    popad
%endmacro

drone_co_routine:
    push ebp
	mov ebp, esp


    pushad  
    call calc_new_position
    popad

    ; ---------------------- Do forever -----------------------

    do_forever:
        pushad
        call may_destroy
        popad

        mov edx, 0
        mov dl, byte[may_des]              ;  res of may_destroy function
        cmp edx, 1
        jne resume_run

        mov ebx, target_struct
        push ebx
        call resume
        pop ebx

        resume_run:
            pushad
            call calc_new_position
            popad

            mov ebx, sched_struct
            push ebx
            call resume
            pop ebx
        jmp do_forever


    mov esp, ebp	
    pop ebp
    ret


may_destroy:
    push ebp
	mov ebp, esp	

    finit
    ; drone -> [x,y,alpha,speed,num]
    mov eax, dword[curr_drone_ID]
    mul dword[drone_size]
    mov edx, dword[drones_array]
    add edx , eax
    
    fld tword[edx]
    fstp tword[current_x]  
    fld tword[edx+10]
    fstp tword[current_y]

    ; ------ calc  (x_target - x_drone)^2 = A ---------
    finit
    fld tword[target_x]                     ; st(0) = x_target
    fld tword[current_x]                    ; st(1) = x_target , st(0) = x_drone
    fsubp                                   ; st(0) = x_target - x_drone
    fmul st0,st0                            ; st(0) = (x_target - x_drone)^2 = A

    ; ------ calc  (y_target - y_drone)^2 = B ---------

    fld tword[target_y]                     ; st(1) = A , st(0) = target_y
    fld tword[current_y]                    ; st(2) = A , st(1) = target_y , st(0) = y_drone
    fsubp                                   ; st(1) = A , st(0) = y_target - y_drone
    fmul st0,st0                            ; st(1) = A , st(0) = (y_target - y_drone)^2 = B

    ; ------ calc  sqrt(A + B) ---------

    faddp                                   ; st(0) = A+B
    fsqrt                                   ; st(0) = sqrt(A+B)

    ; ----- check if drone can destroy the target ----------
    ofek:
    fld tword[max_dist]                     ; st(1) = sqrt(A+B) , st(0) = <D>
    fcomi st0, st1                          ; if st(0) < st(1) - CF = 1
    jna  finish_check

    mov byte[may_des], 1                    ; can destroy
    inc dword[edx+40]                       ; inc the num_of_hits for this drone

    finish_check:
        mov esp, ebp	
        pop ebp
        ret


calc_new_position:
    push ebp
	mov ebp, esp	
    mov eax, dword[curr_drone_ID]
    mul dword[drone_size]
    ; drone -> [x,y,alpha,speed,num]

    mov edx, dword[drones_array]
    add edx, eax
    ;mov edx, dword[drones_array + eax]                  ; edx = current drone 
    finit 
    fld tword[edx]
    fstp tword[current_x]  
    fld tword[edx+10]
    fstp tword[current_y]
    fld tword[edx+20]
    fstp tword[current_angle]
    fld tword[edx+30]
    fstp tword[current_speed] 

        ; ---------------- Generate random heading change angle  ∆α and speed change ∆a------------

    mov dword[delta_angle], 0
    mov dword[delta_speed], 0
    finit
    get_random delta_angle,60, -60
    get_random delta_speed,10, -10
    
    ; ------------ Compute new position ---------------

    ; ---- convert alpha to radinas ------
    finit
    fld tword[current_angle] 
    fild word[flat_angle]
    fdiv                                ; st(0) = current_angle\180
    fldpi                               ; st(0) = pi, st(1) = current_angle\180
    fmul                                ; st(0) = pi * current_angle\180
    fstp tword[radian_angle]
    
    ; ----- new_x ------

    finit
    fld tword[radian_angle]             ; st(0) = alpha
    fcos                                ; st(0) = cos(alpha)
    fld tword[current_speed]            ; st(0) = distance , st(1) = cos(alpha)
    fmul                                ; st(0) = distance*cos(alpha)
    fld tword[current_x]                ; st(0) = curr x ...
    fadd                                ; st(0) = new_x
    fild dword[max_board]               ; st(1) = new x , st(0) = 100
    fcomi st0,st1                       ; if st(0) < st(1) (100 < x)
    jc dec_x
    
    fild dword[max_board]               ; st(2) = new x ,st(1) = 100 , st(0) = 100
    fsubp                               ; st(1) = new x , st(0) = 0
    fcomi st0, st1                      ; if st(1) < st(0) CF = 0 , ZF = 0
    ja inc_x
    fadd
    jmp continue_x
    

    dec_x:
        fsubp                           ; st(0) = new x - 100
        jmp continue_x
    inc_x: ; st(1) = new x , st(0) = 0
        fild dword[max_board]           ; st(2) = new x , st(1) = 0 , st(0) = 100
        fadd st0, st2                   ; st(2) = new x , st(1) = 0 , st(0) = 100 + new_x 
        jmp continue_x

    continue_x:
        fstp tword[edx]                 ; current_x = new x   

    ; ----- new_Y ------

    finit
    fld tword[radian_angle]             ; st(0) = alpha
    fcos                                ; st(0) = cos(alpha)
    fld tword[current_speed]            ; st(0) = distance , st(1) = cos(alpha)
    fmul                                ; st(0) = distance*cos(alpha)
    fld tword[current_y]                ; st(0) = current_y ...
    fadd                                ; st(0) = new_y
    fild dword[max_board]               ; st(1) = new y , st(0) = 100
    fcomi st0,st1                       ; if st(0) < st(1) (100 < y)
    jc dec_y
    
    fild dword[max_board]               ; st(2) = new y ,st(1) = 100 , st(0) = 100
    fsubp                               ; st(1) = new y , st(0) = 0
    fcomi st0, st1                      ; if st(1) < st(0) (y < 0)
    ja inc_y
    fadd
    jmp continue_y
    

    dec_y:
        fsubp                           ; st(0) = new y - 100
        jmp continue_y
    inc_y: 
        fild dword[max_board]           ; st(2) = new y , st(1) = 0 , st(0) = 100
        fadd st0, st2                   ; st(2) = new y , st(1) = 0 , st(0) = 100 + new_y
        jmp continue_y

    continue_y:
        fstp tword[edx+10]               ; current_y = new y   

    ; ---------------- update angle ---------------

    finit
    fld tword[current_angle]            ; st(0) = alpha
    fld tword[delta_angle]              ; st(1) = alpha , st(0) = ∆α
    fadd                                ; st(0) = α + ∆
    fild dword[max_angle]               ; st(1) = α + ∆ , st(0) = 360-fp
    fcomi st0,st1                       ; if st(0) < st(1) (360 <  α + ∆ )
    jc dec_alpha
    
    fild dword[max_angle]               ; st(2) = α + ∆  ,st(1) = 360 , st(0) = 360
    fsubp                               ; st(1) = α + ∆  , st(0) = 0
    fcomi st0, st1                      ; if st(1) < st(0) (new alpha < 0)
    ja inc_alpha
    fadd
    jmp continue_alpha
    
    dec_alpha:
        fsubp                           ; st(0) = new y - 100
        jmp continue_alpha
    inc_alpha: 
        fild dword[max_angle]           ; st(2) = new y , st(1) = 0 , st(0) = 100
        fadd st0, st2                   ; st(2) = new y , st(1) = 0 , st(0) = 100 + new_y
        jmp continue_alpha

    continue_alpha:
        fstp tword[edx+20]               ; current_angle = new alpha 


    ; ---------------- update speed ---------------

    finit
    fld tword[current_speed]            ; st(0) = speed
    fld tword[delta_speed]              ; st(1) = speed , st(0) = ∆speed
    fadd                                ; st(0) = speed + ∆speed = ns
    fild dword[max_board]               ; st(1) = ns , st(0) = 100(fp)
    fcomi st0,st1                       ; if st(0) < st(1) (100 <  ns )
    jc continue_speed
    
    fild dword[max_board]               ; st(2) = ns ,st(1) = 100 , st(0) = 100
    fsubp                               ; st(1) = ns  , st(0) = 0
    fcomi st0, st1                      ; if st(1) < st(0) (ns < 0)
    ja continue_speed
    
    fadd
    
    continue_speed:
        fstp tword[edx+30]               ; current_angle = new alpha 

    mov esp, ebp	
    pop ebp
    ret
