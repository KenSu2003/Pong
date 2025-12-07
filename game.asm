stack segment para stack
    db 64 dup (' ')
stack ends

data segment para 'data'
    windowWidth        dw 140h ; The width of the window (320 pixels)
    windowHeight       dw 0C8h ; The height of the window (200 pixels)
    windowBounds       dw 04h  ; 4 pixels around the window to check for collision early

    gameMode           db 0h   ; Current game mode:
                               ; - 0: Game Menu, 
                               ; - 1: Singleplayer, 
                               ; - 2: Multiplayer,
                               ; - 3: Game Over
                               ; - 4: Demo mode

    paddleLeftX        dw 0Ah  ; Current x position of the left paddle
    paddleLeftY        dw 40h  ; Current y position of the left paddle  

    paddleRightX       dw 130h ; Current x position of the right paddle
    paddleRightY       dw 40h  ; Current y position of the right paddle

    paddleWidth        dw 04h  ; Default paddle width
    paddleHeight       dw 25h  ; Default paddle height
    paddleVelocity     dw 10h  ; Default paddle velocity

    keyPressed         db 00h  ; Current pressed key  

    ballX              dw 0A0h ; Where the ball is located on a X-axis
    ballY              dw 64h  ; Where the ball is located on a Y-axis
    ballSize           dw 06h  ; The size of the ball X and Y
    ballVelocityX      dw 01h  ; How fast the ball moves sideways
    ballVelocityY      dw 01h  ; How fast the ball moves up and down
    ballBorderWidth    dw 04h  ; The buffer around the ball to be drawn black

    playerOnePoints    db 0    ; How many points player 1 has
    playerTwoPoints    db 0    ; How many points player 2 has

    playerScored       db 0h   ; Keeps track of who scored; 1 -> Player one, 2 -> Player two
    maxPointsToScore   db 5h   ; The maximum amount of points to be scored in a match

    playerOnePointsText db '0', '$' ; Points of player one to print to the screen
    playerTwoPointsText db '0', '$' ; Points of player two to print to the screen

    waitTimer          db 3         ; The timer for when the game resets or stars
    waitTimerText      db '3', '$'  ; The timer text that should be displayed

    ; UI-text
    mainMenuTitle      db 'PONG', '$'
    mainMenuSubtitle   db 'You will hate yourself :)', '$'
    menuGameModeOne    db '[1] - Singleplayer', '$'
    menuGameModeTwo    db '[2] - Multiplayer', '$'
    menuGameModeExit   db '[E] - Exit the game', '$' 

    menuPlayerOneCtlr  db 'Player 1: UP: W - DOWN: S', '$'
    menuPlayerTwoCtlr  db 'Player 2: UP: O - DOWN: L', '$'

    gameOverTitle      db 'GAME OVER! GG', '$'
    gameOverWinner     db 'Player 0 won', '$'
    gameOverPlayAgain  db 'Press M to go to the main menu', '$'
    gameOverExit       db 'Press E to exit the game', '$'
data ends

code segment para 'code'
main proc far
    assume cs:code, ds:data, ss:stack

    push    ds          ; Push the data segment to the stack
    sub     ax, ax      ; Clean the AX register
    push    ax          ; Push AX to the stack
    mov     ax, data    ; Save the contents of data in the AX register
    mov     ds, ax      ; Save the AX register contents on the data segment
    pop     ax          ; Release the top item from the stack to the AX register
    pop     ax          ; Release the second item from the stack to the AX register

    ; Initialize Graphics Mode 13 320x200 resolution with 256 colors
    call initializeVideoMode

    gameLoop:
        ; Listen for keypress
        call listenForKeyPress

        ; Check if we're in the main menu
        cmp  gameMode, 0h
        je   mainMenuGameMode
        
        ; Check if we're in the game over menu
        cmp  gameMode, 3h
        je   gameOverMenuMode

        ; Move left and right paddles
        call moveLeftPaddle
        call moveRightPaddle

        ; Draw the pixels for the paddles
        call drawPaddles

        ; Move and draw the pixels for the ball
        call drawBall
        call moveBall

        ; Load in the UI in the game
        call drawUI

        ; Repeat gameloop
        jmp gameLoop

        gameOverMenuMode:
            call drawGameOverMenu
            jmp  gameLoop

        mainMenuGameMode:
            call drawMainMenu
            jmp  gameLoop
main endp

listenForKeyPress proc near
    ; Check if any key is being pressed
    mov ah, 01h
    int 16h

    ; Jump if no key was pressed
    jz noKeyPressed

    ; Check which key is being pressed
    mov ah, 00h
    int 16h

    ; If key is '1' set singleplayer
    cmp al, 31h
    je  setSinglePlayer

    ; If key is '2' set multiplayer
    cmp al, 32h
    je  setMultiPlayer

     ; If key '4' set demo mode
    cmp al, 34h
    je  setDemoMode

    ; If key is 'E' exit the game
    cmp al, 45h
    je  startExitProcedure

    ; If key is 'e' exit the game
    cmp al, 65h
    je  startExitProcedure

    ; If key is 'M' go to the main menu
    cmp al, 4Dh
    je  setToMainMenu

    ; If key is 'm' go to the main menu
    cmp al, 6Dh
    je  setToMainMenu

    mov keyPressed, al
    jmp endListen

    noKeyPressed:
        mov  keyPressed, 00h
        jmp  endListen

    setToMainMenu:
        mov  gameMode, 0h
        call initializeVideoMode
        jmp  endListen

    setSinglePlayer:
        mov  gameMode, 1h
        jmp  clearGameStats

    setMultiPlayer:
        mov  gameMode, 2h
        jmp  clearGameStats
    
    setDemoMode:
        mov  gameMode, 4h

    clearGameStats:
        mov  playerScored, 0h
        call initializeVideoMode

        mov  playerOnePoints, 0h
        mov  playerTwoPoints, 0h

        mov  playerOnePointsText, 30h
        mov  playerTwoPointsText, 30h

        call resetGame
        jmp  endListen

    startExitProcedure:
        call  exitGame
    
    endListen:
        ret
listenForKeyPress endp

; Draw the main menu
drawMainMenu proc near
    ; Set player scores back to 0
    mov ah, 0
    mov playerOnePoints, ah
    mov playerTwoPoints, ah
    mov playerScored, ah

    ; Draw the main title
    mov  dh, 03h                    ; Set row
    mov  dl, 03h                    ; Set column
    lea  bp, mainMenuTitle          ; Load mainMenuTitle
    call drawText                   

    ; Draw the subtitle
    mov dh, 05h                     ; Set row
    mov dl, 03h                     ; Set colimn
    lea bp, mainMenuSubtitle        ; Load mainMenuSubtitle
    call drawText

    ; Draw the first game mode
    mov dh, 08h
    mov dl, 05h
    lea bp, menuGameModeOne
    call drawText

    ; Draw the second game mode
    mov dh, 0Ah
    mov dl, 05h
    lea bp, menuGameModeTwo
    call drawText

    ; Draw the exit game mode
    mov dh, 0Ch
    mov dl, 05h
    lea bp, menuGameModeExit
    call drawText

    ; Draw the Player One controls text
    mov dh, 14h
    mov dl, 03h
    lea bp, menuPlayerOneCtlr
    call drawText

    ; Draw the player two controls text
    mov dh, 16h
    mov dl, 03h
    lea bp, menuPlayerTwoCtlr
    call drawText

    ret
drawMainMenu endp

; Draw the game over menu
drawGameOverMenu proc near
    ; Set player scores back to 0
    mov ah, 0
    mov playerOnePoints, ah
    mov playerTwoPoints, ah

    ; Write the game over menu title
    mov dh, 04h
    mov dl, 04h
    lea bp, gameOverTitle
    call drawText

    mov al, playerScored        ; Retrieves who scored last
    add al, 30h                 ; Change number to ASCII
    mov [gameOverWinner+7], al  ; Update the winner text with the correct winner

    ; Show who won
    mov dh, 06h
    mov dl, 04h
    lea bp, gameOverWinner
    call drawText

    ; Show replay message
    mov dh, 0Ah
    mov dl, 04h
    lea bp, gameOverPlayAgain
    call drawText

    ; Show exit game message
    mov dh, 0Ch
    mov dl, 04h
    lea bp, gameOverExit
    call drawText

    ret
drawGameOverMenu endp

; Draw the left and right paddles
drawPaddles proc near
    ; FOR row FROM paddleY to paddleY + paddleHeight:
    ;   FOR col from paddleX to paddleX + paddleWidth:
    ;     DrawPixel(col, row, WHITE)

    ; Initialize coordinates (X,Y)
    mov dx, paddleLeftY
    sub dx, paddleVelocity    ; Y - offset

    mov cx, paddleLeftX
    jmp abovePaddleBlackCol

    abovePaddleBlackRow:
        mov cx, paddleLeftX
        inc dx

        abovePaddleBlackCol:
            mov ah, 0Ch             ; Set the configuration to writing a pixel
            mov al, 00h             ; Choose black as color
            mov bh, 00h             ; Set the page number
            int 10h                 ; Execute

            inc cx

            mov ax, cx
            sub ax, paddleLeftX
            cmp ax, paddleWidth
            jle abovePaddleBlackCol
        
        cmp dx, paddleLeftY
        jl abovePaddleBlackRow

    ; Initialize row index (Y-coordinate)
    mov cx, paddleLeftX             ; X
    mov dx, paddleLeftY             ; Y

    drawLeftRow:
        mov cx, paddleLeftX
        inc dx

        drawLeftCol: 
            mov ah, 0Ch             ; Set the configuration to writing a pixel
            mov al, 0Fh             ; Choose white as color
            mov bh, 00h             ; Set the page number
            int 10h                 ; Execute

            inc cx

            mov ax, cx
            sub ax, paddleLeftX
            cmp ax, paddleWidth
            jle drawLeftCol
        
        mov ax, dx
        sub ax, paddleLeftY
        cmp ax, paddleHeight
        jle drawLeftRow

    mov cx, paddleLeftY
    add cx, paddleHeight    ; Y + height
    jmp underLeftPaddleBlackCol

    underLefPaddleBlackRow:
        mov cx, paddleLeftX
        inc dx

        underLeftPaddleBlackCol:
            mov ah, 0Ch             ; Set the configuration to writing a pixel
            mov al, 00h             ; Choose black as color
            mov bh, 00h             ; Set the page number
            int 10h                 ; Execute

            inc cx

            mov ax, cx
            sub ax, paddleLeftX
            cmp ax, paddleWidth
            jle underLeftPaddleBlackCol
        
        mov ax, paddleLeftY
        add ax, paddleHeight
        add ax, paddleVelocity

        cmp dx, ax
        jle underLefPaddleBlackRow

    ; mov cx, paddleRightX            ; X
    ; mov dx, paddleRightY            ; Y
    mov dx, paddleRightY            ; Y
    sub dx, paddleVelocity        ; Y - offset

    mov cx, paddleRightX
    jmp aboveRightPaddleBlackCol
    
    aboveRightPaddleBlackRow:
        mov cx, paddleRightX
        inc dx

        aboveRightPaddleBlackCol:
            mov ah, 0Ch             ; Set the configuration to writing a pixel
            mov al, 00h             ; Choose black as color
            mov bh, 00h             ; Set the page number
            int 10h                 ; Execute

            inc cx

            mov ax, cx
            sub ax, paddleRightX
            cmp ax, paddleWidth
            jle aboveRightPaddleBlackCol

        cmp dx, paddleRightY
        jl aboveRightPaddleBlackRow

    mov cx, paddleRightX
    mov dx, paddleRightY
    jmp drawRightCol

    drawRightRow:
        mov cx, paddleRightX
        inc dx

        drawRightCol:
            mov ah, 0Ch             ; Set the configuration to writing a pixel
            mov al, 0Fh             ; Choose white as color
            mov bh, 00h             ; Set the page number
            int 10h                 ; Execute

            inc cx

            mov ax, cx
            sub ax, paddleRightX
            cmp ax, paddleWidth
            jle drawRightCol
        
        mov ax, dx
        sub ax, paddleRightY
        cmp ax, paddleHeight
        jle drawRightRow

    mov cx, paddleRightY
    add cx, paddleHeight
    jmp underRightPaddleBlackCol

    underRightPaddleBlackRow:
        mov cx, paddleRightX
        inc dx

        underRightPaddleBlackCol:
            mov ah, 0Ch             ; Set the configuration to writing a pixel
            mov al, 00h             ; Choose black as color
            mov bh, 00h             ; Set the page number
            int 10h                 ; Execute

            inc cx

            mov ax, cx
            sub ax, paddleRightX
            cmp ax, paddleWidth
            jle underRightPaddleBlackCol
        
        mov ax, paddleRightY
        add ax, paddleHeight
        add ax, paddleVelocity

        cmp dx, ax
        jle underRightPaddleBlackRow

    ret
drawPaddles endp

; Draw the ball
drawBall proc near
    mov cx, ballX       ; X
    mov dx, ballY       ; Y

    ; Start coordinates
    sub cx, ballBorderWidth          ; X - borderWidth
    sub dx, ballBorderWidth          ; Y - borderWidth

    jmp drawHorizontal

    ; from startY to (startY + ballSize + 2 * borderWidth - 1)
    drawVertical:
        mov cx, ballX
        sub cx, ballBorderWidth
        inc dx

        drawHorizontal:
            ; Check if inside the ball boundaries
            cmp dx, ballY
            jl  notInsideBall

            ; TODO: Add also a check to see if the not inside ball is colliding with a paddle

            mov ax, ballY
            add ax, ballSize
            cmp dx, ax
            jge notInsideBall

            cmp cx, ballX
            jl notInsideBall

            mov ax, ballX
            add ax, ballSize
            cmp cx, ax
            jge notInsideBall

            ; Inside the ball boundaries, choose white as color
            mov al, 0Fh             ; Choose white as color
            jmp insideBall

            notInsideBall:
                ; Outise the ball boundary, choose black as color
                mov al, 00h
            
            insideBall:
                mov ah, 0Ch             ; Set the configuration to writing a pixel
                mov bh, 00h             ; Set the page number
                int 10h                 ; Execute
            
                inc cx                  ; Increment the X-coordinate

                mov ax, cx
                sub ax, ballX
                sub ax, ballBorderWidth
                cmp ax, ballSize
                jle drawHorizontal
        
        mov ax, dx
        sub ax, ballY
        sub ax, ballBorderWidth
        cmp ax, ballSize
        jle drawVertical

    ret
drawBall endp

; Draw the UI
drawUI proc near
    cmp gameMode, 0h
    je endDraw

    cmp gameMode, 3h
    je  endDraw

    ; 29 columns -> 30th is back left
    ; 20th column is (sorta) middle

    ; Draw left player points
    mov dh, 01h
    mov dl, 12h
    lea bp, playerOnePointsText
    call drawText

    ; Draw right player points
    mov dh, 01h
    mov dl, 16h
    lea bp, playerTwoPointsText
    call drawText

    ; TODO: Add dashed center line
    endDraw:
        ret
drawUI endp

; Draw a string on the given coordinates
drawText proc near
    ; dh -> Row
    ; dl -> Column
    ; bp -> String location
    mov ah, 02h                 ; Set cursor position
    mov bh, 00h                 ; Set page number
    int 10h                     ; Execute

    mov ah, 09h                 ; Write string to the standard output
    mov dx, bp                  ; Load string into standard output
    int 21h                     ; Execute

    ret
drawText endp

; Move the left paddle with user input
moveLeftPaddle proc near
    cmp gameMode, 4h
    je  leftAiControlled

    cmp keyPressed, 57h ; W
    je  leftPaddleUp

    cmp keyPressed, 77h ; w
    je  leftPaddleUp

    cmp keyPressed, 53h ; S
    je  leftPaddleDown

    cmp keyPressed, 73h ; s
    je  leftPaddleDown

    jmp endLeftMove

    ; The paddle is controlled by AI
    leftAiControlled:
        ; Check if the ball is above the paddle (ballY + ballSize < paddleRightY)
        mov ax, ballY
        add ax, ballSize
        ; If true -> Move paddle up
        cmp ax, paddleLeftY
        jl  leftPaddleUp

        ; Check if the ball is below the paddle (ballY - paddleHeight > paddleRightY)
        mov ax, ballY
        sub ax, paddleHeight
        ; If true -> Move paddle down
        cmp ax, paddleLeftY
        jg  leftPaddleDown

        ; If none -> Do nothing
        jmp endLeftMove

    leftPaddleUp:
        mov ax, paddleLeftY
        
        cmp ax, windowBounds
        jle endLeftMove

        mov ax, paddleLeftY
        sub ax, paddleVelocity
        mov paddleLeftY, ax
        ret

    leftPaddleDown:
        mov ax, paddleLeftY
        add ax, paddleHeight
        add ax, windowBounds

        cmp ax, windowHeight
        jge endLeftMove

        mov ax, paddleLeftY
        add ax, paddleVelocity
        mov paddleLeftY, ax
        ret

    endLeftMove:
        ret
moveLeftPaddle endp

; Move the right paddle with user or ai input
moveRightPaddle proc near
    ; If gamemode is in singleplayer mode do ai control
    cmp gameMode, 1h
    je  rightAiControlled

    ; If gamemode is in demo mode do ai control
    cmp gameMode, 4h
    je  rightAiControlled
    
    cmp keyPressed, 4Fh ; O
    je  rightPaddleUp

    cmp keyPressed, 6Fh ; o
    je  rightPaddleUp

    cmp keyPressed, 4Ch ; L
    je  rightPaddleDown

    cmp keyPressed, 6Ch ; l
    je  rightPaddleDown

    jmp endRightMove

    ; The paddle is controlled by AI
    rightAiControlled:
        ; Check if the ball is above the paddle (ballY + ballSize < paddleRightY)
        mov ax, ballY
        add ax, ballSize
        ; If true -> Move paddle up
        cmp ax, paddleRightY
        jl rightPaddleUp

        ; Check if the ball is below the paddle (ballY - paddleHeight > paddleRightY)
        mov ax, ballY
        sub ax, paddleHeight
        ; If true -> Move paddle down
        cmp ax, paddleRightY
        jg rightPaddleDown

        ; If none -> Do nothing
        jmp endRightMove

    rightPaddleUp:
        mov ax, paddleRightY

        cmp ax, windowBounds
        jle endRightMove

        mov ax, paddleRightY
        sub ax, paddleVelocity
        mov paddleRightY, ax
        ret

    rightPaddleDown:
        mov ax, paddleRightY
        add ax, paddleHeight
        add ax, windowBounds

        cmp ax, windowHeight
        jge endRightMove

        mov ax, paddleRightY
        add ax, paddleVelocity
        mov paddleRightY, ax
        ret

    endRightMove:
        ret
moveRightPaddle endp

; Move the ball across the screen
moveBall proc near
    ; Move ball horizontal
    mov ax, ballVelocityX
    add ballX, ax

    ; ; Move ball vertical
    ; mov ax, ballVelocityY
    ; add ballY, ax

    ; Check if the ball has passed the left window boundary
    mov ax, windowBounds
    cmp ballX, ax
    jl  leftOutOfBounds

    ; Check if the ball has passed the right window boundary
    mov ax, windowWidth
    sub ax, ballSize
    sub ax, windowBounds
    cmp ballX, ax
    jg rightOutOfBounds

    jmp moveBallVertical

    leftOutOfBounds:
        call playerTwoScores
        ret

    rightOutOfBounds:
        call playerOneScores
        ret

    moveBallVertical:
        mov ax, ballVelocityY
        add ballY, ax

    ; Check if the ball has passed the top window boundary
    mov ax, windowBounds
    cmp ballY, ax
    jl  negateMovementVertical

    ; Check if the ball has passed the bottom boundary
    mov ax, windowHeight
    sub ax, ballSize
    sub ax, windowBounds
    cmp ballY, ax
    jg  negateMovementVertical

    ; Check if the ball is colliding with the right paddle
    mov ax, ballX
    add ax, ballSize
    cmp ax, paddleRightX
    jl  checkLeftPaddleCollision

    mov ax, paddleRightX
    add ax, paddleWidth
    cmp ballX, ax
    jg  checkLeftPaddleCollision

    mov ax, ballY
    add ax, ballSize
    cmp ax, paddleRightY
    jl  checkLeftPaddleCollision

    mov ax, paddleRightY
    add ax, paddleHeight
    cmp ballY, ax
    jg  checkLeftPaddleCollision

    jmp negateMovementHorizontal

    ; Check if the ball is colliding with the left paddle
    checkLeftPaddleCollision:
        mov ax, ballX
        add ax, ballSize
        cmp ax, paddleLeftX
        jl  noCollision

        mov ax, paddleLeftX
        add ax, paddleWidth
        cmp ballX, ax
        jg  noCollision

        mov ax, ballY
        add ax, ballSize
        cmp ax, paddleLeftY
        jl  noCollision

        mov ax, paddleLeftY
        add ax, paddleHeight
        cmp ballY, ax
        jg  noCollision

        ; If it reached this point it means that the ball collides with the left paddle
        jmp negateMovementHorizontal

    negateMovementVertical:
        neg ballVelocityY
        ret
    negateMovementHorizontal:
        neg ballVelocityX
        ret

    noCollision:
        ret
moveBall endp

; Reset the game and draw a timer with a 3 second timer
resetGame proc near
    call initializeVideoMode
    call initializeGame

    mov [waitTimerText], 33h    ; 3 seconds to wait in ASCII

    mov dh, 04h                 ; Set row for the timer text
    mov dl, 14h                 ; Set column for the timer text
    lea bp, waitTimerText       ; Load the address of the ASCII character
    call drawText

    call waitOneSecond          ; Wait one second

    mov [waitTimerText], 32h    ; 2 seconds to wait in ASCII

    mov dh, 04h                 ; Set row for the timer text
    mov dl, 14h                 ; Set column for the timer text
    lea bp, waitTimerText       ; Load the address of the ASCII character
    call drawText

    call waitOneSecond          ; Wait one second

    mov [waitTimerText], 31h    ; 1 second to wait in ASCII

    mov dh, 04h                 ; Set row for the timer text
    mov dl, 14h                 ; Set column for the timer text
    lea bp, waitTimerText       ; Load the address of the ASCII character
    call drawText

    call waitOneSecond          ; Wait one second

    mov [waitTimerText], 00h    ; Null character in ASCII

    mov dh, 04h                 ; Set row for the timer text
    mov dl, 14h                 ; Set column for the timer text
    lea bp, waitTimerText       ; Load the address of the ASCII character
    call drawText

    neg ballVelocityX           ; Switch the velocity of the ball to the other side
    call moveBall               ; Start the game by moving the ball

    ret
resetGame endp

; FIXME: On opening a new game after winning/losing a part of the score is still available. Remove this
playerOneScores proc near
    mov  playerScored, 1
    mov  ah, playerOnePoints
    inc  ah

    ; If player 1 scored the max amount of points the game will show a game over menu
    cmp  ah, maxPointsToScore
    je   showGameOverMenuPlayerOne

    mov  playerOnePoints, ah
    add  ah, 30h                     ; Adds 30 hex to get to  decimals in ASCII table
    mov  [playerOnePointsText], ah
    call resetGame

    ret

    showGameOverMenuPlayerOne:
        mov  gameMode, 3h
        call initializeVideoMode
        ret
playerOneScores endp

playerTwoScores proc near
    mov  playerScored, 2
    mov  ah, playerTwoPoints
    inc  ah

    ; If player 2 scored the max amount of points the game will show a game over menu
    cmp  ah, maxPointsToScore
    je   showGameOverMenuPlayerTwo

    mov  playerTwoPoints, ah
    add  ah, 30h                     ; Add 30 hext to get to decimals in ASCII table
    mov  [playerTwoPointsText], ah
    call resetGame

    ret

    showGameOverMenuPlayerTwo:
        mov  gameMode, 3h
        call initializeVideoMode
        ret

playerTwoScores endp

; Clear the screen by restarting the video mode
initializeVideoMode proc near
    mov ah, 00h         ; Set the configuration to video mode
    mov al, 13h         ; Select the video mode
    int 10h             ; Execute

    mov ah, 0Bh
    mov bh, 00h
    mov bl, 02h         ; Set black as background color
    int 10h             ; Execute

    ret
initializeVideoMode endp

; Move sthe paddles and ball in the correct position
initializeGame proc near
    mov paddleLeftY, 40h
    mov paddleRightY, 40h

    mov ballX, 0A0h
    mov ballY, 64h

    call drawPaddles
    call drawBall
    call drawUI

    ret
initializeGame endp

; 1 Second delay
waitOneSecond proc near
    ; [CX:DX] (combined) interval in microseconds
    mov cx, 0Fh         ; Interval high word (1)
    mov dx, 4240h       ; Interval low word  (000 000)
    mov ah, 86h         ; Delay function
    int 15h             ; Execite

    ret
waitOneSecond endp

; Gracefully exit the game by going back to text mode
exitGame proc near
    mov ah, 00h         ; Set the configuration to video mode
    mov al, 02h         ; Select the video mode
    int 10h             ; Execute

    mov ah, 4Ch         ; Terminate the program
    int 21h

    ret
exitGame endp

code ends
end