# ———————————————————————————————————————————————
# Initialization
# ———————————————————————————————————————————————
nop

# 1. Set Paddles (Static positions)
addi $1, $0, 100        # Left Paddle Y = 100 (Higher up)
sw   $1, 3002($0)       # WRITE to VGA Address 3002 (Paddle L)

addi $2, $0, 300        # Right Paddle Y = 300 (Lower down)
sw   $2, 3003($0)       # WRITE to VGA Address 3003 (Paddle R)

# 2. Setup Ball
addi $3, $0, 10         # Ball X position
addi $4, $0, 240        # Ball Y position
addi $5, $0, 1          # Ball Velocity (Speed)

# ———————————————————————————————————————————————
# Main Game Loop
# ———————————————————————————————————————————————
loop:
# 3. Update Ball Position in Registers
add  $3, $3, $5         # Ball X = Ball X + Velocity

# 4. SEND TO VGA (The missing step!)
sw   $3, 3000($0)       # Write Ball X to Address 3000
sw   $4, 3001($0)       # Write Ball Y to Address 3001

# 5. Delay Loop (So the ball doesn't fly off screen instantly)
addi $6, $0, 0          # Reset counter
addi $7, $0, 65000       # Delay amount (Adjust this if too fast/slow)

delay:
addi $6, $6, 1          # Increment counter
bne  $6, $7, delay      # Loop until counter == 1000

# 6. Repeat
j    loop