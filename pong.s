# PONG GAME - FIXED SPEED
# ============================
# $1 = Ball X
# $2 = Ball Y
# $3 = Ball Vel X
# $4 = Ball Vel Y
# $5 = Paddle L Y
# $6 = Paddle R Y
# $20 = Base Address for MMIO (2000)

init:
# Setup MMIO Base
addi    $20, $0, 2000       # Keyboard Address = 2000

# Init Positions
addi    $1, $0, 320         # Ball X Center
addi    $2, $0, 240         # Ball Y Center
addi    $3, $0, 1           # Ball Vel X = 1
addi    $4, $0, 1           # Ball Vel Y = 1
addi    $5, $0, 200         # Pad L Y
addi    $6, $0, 200         # Pad R Y

main_loop:
# —————————————————————————————————
# 1. READ KEYBOARD (Addr 2000)
# —————————————————————————————————
lw      $10, 0($20)         # Load Key Code

# CHECK 'W' (Up Left) - 119
addi    $11, $0, 119
bne     $10, $11, check_s
addi    $5, $5, -3          # Move Up
j       clamp_paddles

check_s:
# CHECK 'S' (Down Left) - 115
addi    $11, $0, 115
bne     $10, $11, check_o
addi    $5, $5, 3           # Move Down
j       clamp_paddles

check_o:
# CHECK 'O' (Up Right) - 111 (0x6F)
addi    $11, $0, 111
bne     $10, $11, check_l
addi    $6, $6, -3
j       clamp_paddles

check_l:
# CHECK 'L' (Down Right) - 108 (0x6C)
addi    $11, $0, 108
bne     $10, $11, clamp_paddles
addi    $6, $6, 3

clamp_paddles:
# Keep Paddles on screen (0 to 440)
blt     $5, $0, fix_l_top
addi    $11, $0, 440
blt     $11, $5, fix_l_bot
j       check_r
fix_l_top:
addi    $5, $0, 0
j       check_r
fix_l_bot:
addi    $5, $0, 440

check_r:
blt     $6, $0, fix_r_top
addi    $11, $0, 440
blt     $11, $6, fix_r_bot
j       physics
fix_r_top:
addi    $6, $0, 0
j       physics
fix_r_bot:
addi    $6, $0, 440

# —————————————————————————————————
# 2. PHYSICS (Ball Movement)
# —————————————————————————————————
physics:
add     $1, $1, $3          # X += VX
add     $2, $2, $4          # Y += VY

# Y Collision (Top/Bottom)
blt     $2, $0, bounce_y
addi    $11, $0, 470
blt     $11, $2, bounce_y
j       check_x

bounce_y:
sub     $4, $0, $4          # VY = -VY

check_x:
# Simply bounce off walls for now (Testing Mode)
# Later we add paddle checks here
blt     $1, $0, bounce_x
addi    $11, $0, 630
blt     $11, $1, bounce_x
j       update_vga

bounce_x:
sub     $3, $0, $3          # VX = -VX

# —————————————————————————————————
# 3. UPDATE VGA (Addr 3000+)
# —————————————————————————————————
update_vga:
sw      $1, 1000($20)       # 3000: Ball X
sw      $2, 1001($20)       # 3001: Ball Y
sw      $5, 1002($20)       # 3002: Pad L
sw      $6, 1003($20)       # 3003: Pad R

# —————————————————————————————————
# 4. HUGE DELAY LOOP
# —————————————————————————————————
# We use a nested loop to burn cycles
addi    $30, $0, 100        # Outer Loop
outer_delay:
addi    $31, $0, 2000       # Inner Loop
inner_delay:
addi    $31, $31, -1
bne     $31, $0, inner_delay # Spin inner

addi    $30, $30, -1
bne     $30, $0, outer_delay # Spin outer

j       main_loop