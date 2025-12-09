# PONG GAME - FIXED ADDRESSING
# ------------------------------------------------------------------
# MEMORY MAP (Decimal):
# 2000 : Keyboard Input (Read)
# 3000 : VGA Ball X     (Write)
# 3001 : VGA Ball Y     (Write)
# 3002 : VGA Paddle L   (Write)
# 3003 : VGA Paddle R   (Write)
# ------------------------------------------------------------------

# === INITIALIZATION BLOCK ===

init:
# 1. Setup MMIO Pointers (USING DECIMAL, NOT HEX SHIFTS)
addi $20, $0, 2000       # Keyboard Address
addi $21, $0, 3000       # VGA Base Address

# 2. Setup Constants
addi $22, $0, 640        # Screen Width
addi $23, $0, 480        # Screen Height
addi $24, $0, 40         # Paddle Height
addi $25, $0, 3          # Paddle Speed

# 3. Setup Game State (Start in Middle)
addi $1, $0, 320         # Ball X = 320
addi $2, $0, 240         # Ball Y = 240
addi $3, $0, 1           # Vel X = 1
addi $4, $0, 1           # Vel Y = 1
addi $5, $0, 200         # Left Pad Y = 200
addi $6, $0, 200         # Right Pad Y = 200

# === MAIN GAME LOOP ===
game_loop:

# ---------------------------------------------------------
# 1. INPUT HANDLING (Polling Address 2000)
# ---------------------------------------------------------
lw   $27, 0($20)         # Read Keyboard from 2000

# Check 'w' (Up Left) - ASCII 119 (0x77)
addi $26, $0, 119
bne  $27, $26, check_s
sub  $5,  $5,  $25       # Paddle L = Paddle L - Speed
j    input_done

check_s:
# Check 's' (Down Left) - ASCII 115 (0x73)
addi $26, $0, 115
bne  $27, $26, check_o
add  $5,  $5,  $25       # Paddle L = Paddle L + Speed
j    input_done

check_o:
# Check 'o' (Up Right) - ASCII 111 (0x6F)
addi $26, $0, 111
bne  $27, $26, check_l
sub  $6,  $6,  $25       # Paddle R = Paddle R - Speed
j    input_done

check_l:
# Check 'l' (Down Right) - ASCII 108 (0x6C)
addi $26, $0, 108
bne  $27, $26, input_done
add  $6,  $6,  $25       # Paddle R = Paddle R + Speed

input_done:
# Clamp Paddles to Top (0)
blt  $5, $0, clamp_l_top
j    check_r_top
clamp_l_top:
addi $5, $0, 0

check_r_top:
blt  $6, $0, clamp_r_top
j    physics
clamp_r_top:
addi $6, $0, 0

# ---------------------------------------------------------
# 2. PHYSICS UPDATE (Ball Movement)
# ---------------------------------------------------------
physics:
add  $1, $1, $3          # Ball X += Vel X
add  $2, $2, $4          # Ball Y += Vel Y

# --- Y-Axis Wall Collision (Top/Bottom) ---

# Check Top (Ball Y < 0)
blt  $2, $0, invert_y

# Check Bottom (Ball Y > 480)
blt  $23, $2, invert_y
j    check_paddles       # No Y collision

invert_y:
sub  $4, $0, $4          # Vel Y = 0 - Vel Y (Negate)

# ---------------------------------------------------------
# 3. PADDLE COLLISION LOGIC
# ---------------------------------------------------------
check_paddles:
# Check Left Paddle Area (Ball X < 30)
addi $26, $0, 30
blt  $1, $26, check_hit_left

# Check Right Paddle Area (Ball X > 610)
addi $26, $0, 610
blt  $26, $1, check_hit_right

j    update_screen       # Ball is in middle of screen

check_hit_left:
# Hit Logic: If (BallY >= PaddleY) AND (BallY <= PaddleY + 40)

# Check 1: Is PaddleY > BallY? (Missed Top)
blt  $2, $5, check_score_l 

# Check 2: Is BallY > PaddleY + Height? (Missed Bottom)
add  $26, $5, $24        # $26 = PaddleY + 40
blt  $26, $2, check_score_l

# Hit! Bounce X (Force Positive)
addi $26, $0, 1
blt  $3, $26, do_bounce_l # Only bounce if moving left
j    update_screen
do_bounce_l:
addi $3, $0, 1           
j    update_screen

check_hit_right:
# Check 1: Is PaddleY > BallY? (Missed Top)
blt  $2, $6, check_score_r

# Check 2: Is BallY > PaddleY + Height? (Missed Bottom)
add  $26, $6, $24        # $26 = PaddleY + 40
blt  $26, $2, check_score_r

# Hit! Bounce X (Force Negative)
addi $26, $0, 0
blt  $3, $26, update_screen # Only bounce if moving right
addi $3, $0, -1          
j    update_screen

# ---------------------------------------------------------
# 4. SCORING (Reset Ball)
# ---------------------------------------------------------
check_score_l:
# Ball went past left paddle. Reset if X < 0.
blt  $1, $0, reset_ball
j    update_screen

check_score_r:
# Ball went past right paddle. Reset if X > 640.
blt  $22, $1, reset_ball
j    update_screen

reset_ball:
addi $1, $0, 320         # Reset X
addi $2, $0, 240         # Reset Y

# ---------------------------------------------------------
# 5. RENDER (Write to VGA MMIO)
# ---------------------------------------------------------
update_screen:
sw   $1, 0($21)          # Write Ball X to 3000
sw   $2, 1($21)          # Write Ball Y to 3001
sw   $5, 2($21)          # Write Left Pad to 3002
sw   $6, 3($21)          # Write Right Pad to 3003

# ---------------------------------------------------------
# 6. DELAY LOOP
# ---------------------------------------------------------
# Without this, the ball teleports.
addi $26, $0, 1
sll  $26, $26, 16        # ~65,000 cycles delay

delay_loop:
addi $26, $26, -1        # Decrement
bne  $26, $0, delay_loop # Loop until 0

j    game_loop           # Repeat everything