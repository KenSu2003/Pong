# ——————————————————————————————————————————————————————————————————————
# PONG GAME - FINAL VERSION
# ——————————————————————————————————————————————————————————————————————
# MEMORY MAP:
# 2000 : Keyboard Input (Read Only)
# 3000 : VGA Ball X     (Write)
# 3001 : VGA Ball Y     (Write)
# 3002 : VGA Paddle L   (Write)
# 3003 : VGA Paddle R   (Write)
# ——————————————————————————————————————————————————————————————————————

init:
# 1. Setup Base Addresses
addi    $20, $0, 2000       # Keyboard Address
addi    $21, $0, 3000       # VGA Base Address

# 2. Setup Constants
addi    $22, $0, 640        # Screen Width
addi    $23, $0, 480        # Screen Height
addi    $24, $0, 40         # Paddle Height
addi    $25, $0, 3          # Paddle Speed
addi    $29, $0, 440        # Paddle Max Y (480 - 40)

# 3. Initialize Game State
addi    $1, $0, 320         # Ball X
addi    $2, $0, 240         # Ball Y
addi    $3, $0, 1           # Ball Vel X (Start moving right)
addi    $4, $0, 1           # Ball Vel Y (Start moving down)
addi    $5, $0, 200         # Left Paddle Y
addi    $6, $0, 200         # Right Paddle Y

# ——————————————————————————————————————————————————————————————————————
# MAIN LOOP
# ——————————————————————————————————————————————————————————————————————
game_loop:

# ——— INPUT HANDLING ———
# Note: Your hardware holds the last key pressed. 
# To stop moving, press SPACE (which sends 32/0x20).

lw      $27, 0($20)         # Read Keyboard from Address 2000

# 1. Check 'W' (Up Left) - 0x57 (Decimal 87)
addi    $26, $0, 87
bne     $27, $26, check_s
sub     $5, $5, $25         # Paddle L Move Up
j       clamp_paddles

check_s:
# 2. Check 'S' (Down Left) - 0x53 (Decimal 83)
addi    $26, $0, 83
bne     $27, $26, check_o
add     $5, $5, $25         # Paddle L Move Down
j       clamp_paddles

check_o:
# 3. Check 'O' (Up Right) - 0x4F (Decimal 79)
addi    $26, $0, 79
bne     $27, $26, check_k
sub     $6, $6, $25         # Paddle R Move Up
j       clamp_paddles

check_k:
# 4. Check 'K' (Down Right) - 0x4B (Decimal 75)
# Your hardware maps 0x4B, not 'L'
addi    $26, $0, 75
bne     $27, $26, clamp_paddles
add     $6, $6, $25         # Paddle R Move Down

# ——— PADDLE CLAMPING (Top & Bottom) ———
clamp_paddles:
# Clamp Left Top
blt     $5, $0, fix_l_top
j       check_l_bot
fix_l_top:
addi    $5, $0, 0
j       check_r_top

check_l_bot:
# Clamp Left Bottom (Y > 440)
blt     $29, $5, fix_l_bot
j       check_r_top
fix_l_bot:
addi    $5, $0, 440

check_r_top:
# Clamp Right Top
blt     $6, $0, fix_r_top
j       check_r_bot
fix_r_top:
addi    $6, $0, 0
j       physics

check_r_bot:
# Clamp Right Bottom (Y > 440)
blt     $29, $6, fix_r_bot
j       physics
fix_r_bot:
addi    $6, $0, 440

# ——— PHYSICS UPDATE ———
physics:
add     $1, $1, $3          # Ball X += Vel X
add     $2, $2, $4          # Ball Y += Vel Y

# Y Collision (Top/Bottom Walls)
blt     $2, $0, invert_y    # Top Wall
blt     $23, $2, invert_y   # Bottom Wall (480)
j       check_x_col

invert_y:
sub     $4, $0, $4          # Negate Y Velocity

check_x_col:
# X Collision (Paddles)

# Left Zone (Ball X < 30)
addi    $26, $0, 30
blt     $1, $26, check_hit_left

# Right Zone (Ball X > 610)
addi    $26, $0, 610
blt     $26, $1, check_hit_right

j       check_reset         # Middle of screen

check_hit_left:
# Check if Ball Y is between PaddleY and PaddleY+40
blt     $2, $5, check_reset      # Missed (Too high)

addi    $26, $5, 40
blt     $26, $2, check_reset     # Missed (Too low)

# HIT LEFT: Force Vel X Positive (1)
addi    $3, $0, 1
j       render

check_hit_right:
# Check if Ball Y is between PaddleY and PaddleY+40
blt     $2, $6, check_reset      # Missed (Too high)

addi    $26, $6, 40
blt     $26, $2, check_reset     # Missed (Too low)

# HIT RIGHT: Force Vel X Negative (-1)
addi    $3, $0, -1
j       render

# ——— RESET LOGIC ———
check_reset:
# If Ball X < 0 or Ball X > 640, Reset
blt     $1, $0, reset_ball
blt     $22, $1, reset_ball
j       render

reset_ball:
addi    $1, $0, 320
addi    $2, $0, 240
# Optional: Reset angle? For now keep velocity.

# ——— RENDER ———
render:
sw      $1, 0($21)          # 3000: Ball X
sw      $2, 1($21)          # 3001: Ball Y
sw      $5, 2($21)          # 3002: Paddle L
sw      $6, 3($21)          # 3003: Paddle R

# ——— DELAY LOOP ———
# Delay to approx 60 FPS (Depends on CPU Clock)
addi    $26, $0, 1
sll     $26, $26, 11        # Shift left to create large number (~2048)

delay:
addi    $26, $26, -1
bne     $26, $0, delay

j       game_loop