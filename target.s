section .text
	align 16

	extern main
    extern target_x
    extern target_y
    extern random_num

    global target_co_routine

%macro get_random 3         ; set random number between %3 to %2 - store it in %1
    pushad
    push %1
    push %2
    push %3
    call random_num
    add esp,12
    popad
%endmacro


target_co_routine:
    push ebp
	mov ebp, esp	
    
    call createTarget

    mov esp, ebp	
    pop ebp
ret

createTarget:
    push ebp
	mov ebp, esp	

    get_random target_x, 100, 0
    get_random target_y, 100, 0

    mov esp, ebp	
    pop ebp
ret
