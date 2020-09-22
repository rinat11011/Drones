section .text
	align 16
	extern printf
	extern main
    extern resume

    extern drones_N 		  ; <N>
    extern sched_cycle        ; <R>
    extern steps_between      ; <K>

    extern drones_array
    extern drone_size

    extern drones_co_routine_array
    extern printer_struct
    extern num_active_drones

    extern endCo
    extern coroutine_size
    extern curr_drone_ID

    global scheduler_co_routine
    
section	.rodata						; we define (global) read-only variables in .rodata section
    print_winner:      db "The Winner is drone: <%d>",10,0

section .data
    iter_index:          dd 0                
    dividend:       dd 0
    mod_dividend:   dd 0
    min_hits:       dd 0
    min_iter_index:      dd 0


section .text


scheduler_co_routine:
    push ebp
	mov ebp, esp	
    mov dword[iter_index], 0             ; starting iter_index

    while_drones_left:
        mov ebx, dword[drones_co_routine_array]
        mov ecx, dword[num_active_drones]
        cmp ecx, 1
        je find_winner
        mov ecx, 0

        ; ------ calc iter_index%N -------
        mov edx, 0
        mov eax, dword[iter_index]              ; eax = curr iter_index
        mov ecx, dword[drones_N]                ; ecx = N
        div ecx                                 ; edx = eax % ecx - (i % N) , eax = eax / ecx (i / N)
        ;inc edx                                ; edx = (i%N)
        
        mov dword[dividend], eax                ; dividend = i / N
        mov dword[mod_dividend], edx            ; mod_dividend = i % N

        ; --------- check if the i'th drone is active -------
        mov eax, edx                            ; eax = wanted iter_index (i % N)
        mul dword[drone_size]                   ; eax = (i % N)*drone size
        mov edx, dword[drones_array]
        add edx, eax                            ; edx = wanted drone
        mov edx, dword[edx + 40]                ; edx = wanted drones num of hits
        cmp edx, 0
        jl next_drone                           ; if edx < 0 - then the drone is not active
        ;jl check_K_rounds
        ; --------- if active resume drones co - routine --------    
        mov eax, dword[mod_dividend]                    ; eax = i % N
        mov dword[curr_drone_ID], eax                   ; update current drone id
        mul dword[coroutine_size]                       ; eax = (i % N) * 12

        add ebx, eax
        push ebx
        call resume
        pop ebx

        ; ----------- check if <K> rounds have passed - if so print the board game --------
        check_K_rounds:
            mov edx, 0
            mov eax, dword[iter_index]              ; eax = curr iter_index
            inc eax
            mov ecx, dword[steps_between]           ; ecx = K
            div ecx                                 ; edx = eax % ecx - (i % K)
            cmp edx, 0
            jne check_R_rounds                      ; if K rounds have passed - print board
            mov ebx, printer_struct                 ; ebx = printers co-routine  
            push ebx
            call resume
            pop ebx

        ; ------------- check if <R> cycles have passed - if so eliminate -------
        check_R_rounds:
            
            ; ---------- calc new div and mod ----------
            mov edx, 0
            mov eax, dword[iter_index]              ; eax = curr iter_index
            inc eax
            mov ecx, dword[drones_N]                ; ecx = N
            div ecx                                 ; edx = eax % ecx - (i % N) , eax = eax / ecx (i / N)
        
            mov dword[dividend], eax                ; dividend = i / N
            mov dword[mod_dividend], edx            ; mod_dividend = i % N
            
            mov edx, 0
            mov eax, dword[dividend]                ; eax = i / N
            mov ecx, dword[sched_cycle]             ; ecx = R
            div ecx                                 ; edx = eax % ecx - (i / N) % R
            cmp edx, 0
            jne next_drone

            mov edx, dword[mod_dividend]            ; edx = i % N
            cmp edx, 0
            jne next_drone
            call eliminate

        next_drone:
            inc dword[iter_index]
            jmp while_drones_left



    find_winner:
        mov ebx, dword[drones_array]                ; eax = ptr to the drones array
        mov ecx, 0
        
        find_loop:
            mov eax,ecx
            mul dword[drone_size]
            add ebx, eax
            mov edx, ebx 

            inc ecx                                 ; i++
            mov edx, dword[edx + 40]                ; edx = curr num of hits
            cmp edx, 0
            jge found_winner                        ; found the winner
            jmp find_loop  


    found_winner:
    ; drone -> [x,y,alpha,speed,num]
        mov ecx, dword[min_iter_index]
        inc ecx
        push ecx
        push print_winner
        call printf
        add esp, 8
        call endCo

    mov esp, ebp	
    pop ebp
ret


eliminate:
    push ebp
	mov ebp, esp

    mov ecx, 0                  ; ecx will be the first active drones index
    ; drones_array = ptr-> [x,y,alpha,speed,num_hits]
    

    find_first_active:
        mov ebx, dword[drones_array]                ; eax = ptr to the drones array

        mov eax,0                         ; initialize min hits
        mov eax, ecx

        mov dword[min_iter_index], ecx 
        inc ecx
        mul dword[drone_size]
        add ebx, eax
        mov edx, ebx  
        ;mov edx, dword[drones_array + eax]      ; edx = curr drone
        mov edx, dword[edx + 40]                ; edx = curr num of hits
        ;inc ecx
        cmp edx, -1
        je find_first_active
        ;jmp find_first_active
    
    mov dword[min_hits], edx                             
    ;dec ecx
    ;mov dword[min_iter_index], ecx                   
    ;inc ecx                                     ; ecx points to the next drone

    ; --- edx = min hits ----

    find_min_hits:
        mov eax, dword[drones_N]                ; eax = droneArray.length
        cmp ecx, eax                            ; done iterating over the drone array
        je eliminate_first_min          
        
        mov eax, ecx                            ; eax = curr iter_index
        mul dword[drone_size] 

        ;mov ebx, dword[drones_array + eax]      ; ebx = curr drone
        ;mov ebx, dword[ebx + 40]                ; ebx = curr num of hits
        
        add ebx, eax
        mov edx, ebx  
        ;mov edx, dword[drones_array + eax]      ; edx = curr drone
        mov edx, dword[edx + 40]   

        inc ecx                                 ; ecx = next drone
        cmp edx,-1                              ; 
        je eliminate_first_min                        ; found the winner
        
        mov eax, dword[min_hits]
        cmp edx, eax                            ; edx = curr min
        jge find_min_hits 
        mov dword[min_hits], edx 
        dec ecx
        mov dword[min_iter_index], ecx
        inc ecx
        jmp find_min_hits


    eliminate_first_min:
        mov ebx, dword[drones_array]                ; eax = ptr to the drones array
        mov eax, dword[min_iter_index]                            ; eax = curr iter_index
        mul dword[drone_size]                   
        add ebx, eax                            ; ebx = curr drone
        ;mov ebx, 0
        mov dword[ebx+40], -1                   ; eliminiate the min hits drone by changing drone's num of hits to -1 
        dec dword[num_active_drones]
    mov esp, ebp	
    pop ebp
ret	