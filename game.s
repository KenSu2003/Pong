# =========================================================
# PONG GAME - for your custom ISA CPU
# Uses MMIO:
#   2000 : PS2 last key (8-bit, 'W','S','O','K' or 0)
#   2010 : ball_x (10-bit)
#   2011 : ball_y (9-bit)
#   2012 : paddle_left_y
#   2013 : paddle_right_y
#   2014 : score (8-bit visible, but we store full in r10)
# =========================================================

        # r1  = ball_x
        # r2  = ball_y
        # r3  = vel_x
        # r4  = vel_y
        # r5  = left paddle y
        # r6  = right paddle y
        # r7  = last key
        # r8  = TOP_Y (0)
        # r9  = BOTTOM_Y (439)
        # r10 = score
        # r11 = temp address
        # r12,r13,r14 = temps

        # ===== INIT =====
        addi  r1, r0, 315      # ball_x center
        addi  r2, r0, 235      # ball_y center
        addi  r3, r0, 1        # vel_x = +1
        addi  r4, r0, 1        # vel_y = +1

        addi  r5, r0, 220      # left paddle y
        addi  r6, r0, 220      # right paddle y

        addi  r8, r0, 0        # TOP_Y
        addi  r9, r0, 439      # BOTTOM_Y (479-40)

        addi  r10, r0, 0       # score

main_loop:
        # ===== 1. Read keyboard =====
        addi  r11, r0, 2000
        lw    r7, 0(r11)       # r7 = key or 0

        # ===== 2. Move left paddle with W/S =====
        # if (r7 == 'W') r5 -= 3
        addi  r12, r0, 0x57    # 'W'
        bne   r7, r12, check_S
        addi  r5, r5, -3
        j     after_keys

check_S:
        # if (r7 == 'S') r5 += 3
        addi  r12, r0, 0x53    # 'S'
        bne   r7, r12, check_O
        addi  r5, r5, 3
        j     after_keys

        # ===== 3. Move right paddle with 'O'/'K' (Arrow Up/Down) =====
check_O:
        addi  r12, r0, 0x4F    # 'O' (or Up arrow)
        bne   r7, r12, check_K
        addi  r6, r6, -3
        j     after_keys

check_K:
        addi  r12, r0, 0x4B    # 'K' (or Down arrow)
        bne   r7, r12, after_keys
        addi  r6, r6, 3

after_keys:
        # (Optional) clamp paddles between 0 and 439 - not strictly necessary

        # ===== 4. Update ball position =====
        add   r1, r1, r3       # ball_x += vel_x
        add   r2, r2, r4       # ball_y += vel_y

        # ===== 5. Vertical walls =====
        # if (ball_y < TOP_Y) || (ball_y > BOTTOM_Y) => flip vel_y

        # if (ball_y < TOP_Y)
        blt   r2, r8, flip_vy

        # if (ball_y > BOTTOM_Y)
        addi  r12, r9, 1
        blt   r2, r12, no_vflip
        j     flip_vy

flip_vy:
        sub   r4, r0, r4       # vel_y = -vel_y

no_vflip:

        # ===== 6. Scoring (left or right side) =====
        # if (ball_x < 0) OR (ball_x >= 630) => score++

        addi  r12, r0, 0
        blt   r1, r12, score_and_reset

        addi  r12, r0, 630     # right side threshold
        blt   r1, r12, no_score
        # here: ball_x >= 630
        j     score_and_reset

score_and_reset:
        addi  r10, r10, 1      # score++

        # reset ball center, flip x direction
        addi  r1, r0, 315
        addi  r2, r0, 235
        sub   r3, r0, r3       # vel_x = -vel_x
        addi  r4, r0, 1        # vel_y = +1
        j     no_score

no_score:
        # ===== 7. (Optional) Paddle collisions can be added here =====
        # For now, ball just bounces off walls and resets at edges.

        # ===== 8. Write positions & score to MMIO =====
        # ball_x
        addi  r11, r0, 2010
        sw    r1, 0(r11)

        # ball_y
        addi  r11, r0, 2011
        sw    r2, 0(r11)

        # left paddle y
        addi  r11, r0, 2012
        sw    r5, 0(r11)

        # right paddle y
        addi  r11, r0, 2013
        sw    r6, 0(r11)

        # score
        addi  r11, r0, 2014
        sw    r10, 0(r11)

        # ===== 9. Frame delay =====
        addi  r13, r0, 50000   # tweak this constant for speed

delay_loop:
        addi  r13, r13, -1
        bne   r13, r0, delay_loop

        j     main_loop
