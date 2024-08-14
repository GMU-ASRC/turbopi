__includes ["Extra_Procedures.nls"]

;;
;; Runtime Procedures
;;
to go

  background_procedures


  ask robots
    [
      ifelse group_type = 0 ; loop for robots with group_type = 0 (i.e. just the Evader)
      [
        if evader-control = "manual_drive"
        [manual_drive]
        if evader-control =  "straight_to_goal"
        [straight-to-goal]
      ]
      [

        if group_type = 1
        [
          Mode-A-procedure  ;if group_type = 1 it does "Mode-A-procedure"
        ]

        if group_type = 2
        [
          Mode-B-procedure  ; if group_type = 2 it does "Mode-B-procedure"
        ]

        if group_type = 3
        [
          Mode-C-procedure  ; if group_type = 3 it does "Mode-C-procedure"
        ]
      ]
      ]


   measure_results

  if end_flag = 1
  [ stop]

  tick-advance 1
end

to Mode-A-procedure
  set_actuating_and_extra_variables
  do_sensing

  ifelse not distinguish_between_types? ;if switch is off (meaning it doesn't see difference between hunters and evader) it treats them the same
   [
      ifelse sum detection_list >= (filter-val / 2) ; if agent or target is detected do whats within first set of brackets
        [
          set color blue
          set inputs (list (10 * random-normal (forward_speed2 ) noise-actuating-speed) body_direction2 (random-normal turning-rate2  noise-actuating-turning))

        ]
        [
          set color red
          set inputs (list (10 * random-normal (forward_speed1 ) noise-actuating-speed) body_direction1 (random-normal turning-rate1  noise-actuating-turning))
        ]
   ]
   [
      ifelse sum detection_list_evader >= (filter-val / 2) ; if evader is detected, do whats within first set of brackets
        [
          set color green
          set inputs (list (10 * random-normal (forward_speed3 ) noise-actuating-speed) body_direction3 (random-normal turning-rate3  noise-actuating-turning))

        ]
        [
          ifelse sum detection_list_hunters >= (filter-val / 2) ; if hunter(s) is detected, do whats within first set of brackets
          [
            set color blue
            set inputs (list (10 * random-normal (forward_speed2 ) noise-actuating-speed) body_direction2 (random-normal turning-rate2  noise-actuating-turning))
          ]
          [
            ;else if nothing is detected
            set color red
            select_alg_mecanum
          ]
        ]
   ]
  update_agent_state_mecanum2
end


to Mode-B-procedure
  set_actuating_and_extra_variables
  do_sensing

  ifelse not distinguish_between_types? ;if switch is off (meaning it doesn't see difference between hunters and evader) it treats them the same
   [
      ifelse sum detection_list >= (filter-val / 2) ; if agent or target is detected do whats within first set of brackets
        [
          set color blue
          set inputs (list (10 * random-normal (forward_speed2_B ) noise-actuating-speed) body_direction2_B (random-normal turning-rate2_B  noise-actuating-turning))

        ]
        [
          set color red
          set inputs (list (10 * random-normal (forward_speed1_B ) noise-actuating-speed) body_direction1_B (random-normal turning-rate1_B  noise-actuating-turning))
        ]
   ]
   [
      ifelse sum detection_list_evader >= (filter-val / 2) ; if evader is detected, do whats within first set of brackets
        [
          set color green
          set inputs (list (10 * random-normal (forward_speed3_B ) noise-actuating-speed) body_direction3_B (random-normal turning-rate3_B  noise-actuating-turning))

        ]
        [
          ifelse sum detection_list_hunters >= (filter-val / 2) ; if hunter(s) is detected, do whats within first set of brackets
          [
            set color blue
            set inputs (list (10 * random-normal (forward_speed2_B ) noise-actuating-speed) body_direction2_B (random-normal turning-rate2_B  noise-actuating-turning))
          ]
          [
            ;else if nothing is detected
            set color red
            select_alg_mecanum
          ]
        ]
   ]

  update_agent_state_mecanum2
end

to Mode-C-procedure
  set_actuating_and_extra_variables
  do_sensing

  ifelse not distinguish_between_types? ;if switch is off (meaning it doesn't see difference between hunters and evader) it treats them the same
   [
      ifelse sum detection_list >= (filter-val / 2) ; if agent or target is detected do whats within first set of brackets
        [
          set color blue
          set inputs (list (10 * random-normal (forward_speed2_C ) noise-actuating-speed) body_direction2_C (random-normal turning-rate2_C  noise-actuating-turning))

        ]
        [
          set color red
          set inputs (list (10 * random-normal (forward_speed1_C ) noise-actuating-speed) body_direction1_C (random-normal turning-rate1_C  noise-actuating-turning))
        ]
   ]
   [
      ifelse sum detection_list_evader >= (filter-val / 2) ; if evader is detected, do whats within first set of brackets
        [
          set color green
          set inputs (list (10 * random-normal (forward_speed3_C ) noise-actuating-speed) body_direction3_C (random-normal turning-rate3_C  noise-actuating-turning))

        ]
        [
          ifelse sum detection_list_hunters >= (filter-val / 2) ; if hunter(s) is detected, do whats within first set of brackets
          [
            set color blue
            set inputs (list (10 * random-normal (forward_speed2_C ) noise-actuating-speed) body_direction2_C (random-normal turning-rate2_C  noise-actuating-turning))
          ]
          [
            ;else if nothing is detected
            set color red
            select_alg_mecanum
          ]
        ]
   ]

  update_agent_state_mecanum2
end
@#$#@#$#@
GRAPHICS-WINDOW
1127
33
1916
823
-1
-1
9.65
1
10
1
1
1
0
0
0
1
-40
40
-40
40
1
1
1
ticks
10.0

SLIDER
28
63
200
96
number-of-robots
number-of-robots
0
30
12.0
1
1
NIL
HORIZONTAL

SLIDER
250
67
342
100
seed-no
seed-no
1
100
4.0
1
1
NIL
HORIZONTAL

SLIDER
29
105
201
138
vision-distance
vision-distance
0
1.1
1.1
0.1
1
m
HORIZONTAL

SLIDER
28
143
200
176
vision-cone
vision-cone
0
360
50.0
1
1
deg
HORIZONTAL

SLIDER
28
318
237
351
forward_speed1
forward_speed1
0
0.3
0.0
0.05
1
m/s
HORIZONTAL

SLIDER
27
399
230
432
turning-rate1
turning-rate1
-150
150
150.0
5
1
deg/s
HORIZONTAL

SLIDER
2963
718
3135
751
state-disturbance
state-disturbance
0
3
0.0
0.05
1
NIL
HORIZONTAL

SWITCH
2968
443
3146
476
spawn_semi_randomly?
spawn_semi_randomly?
0
1
-1000

SWITCH
2492
204
2607
237
walls_on?
walls_on?
0
1
-1000

SLIDER
2933
1293
3105
1326
mode
mode
-1
1
0.0
1
1
NIL
HORIZONTAL

BUTTON
260
20
340
60
NIL
setup
NIL
1
T
OBSERVER
NIL
P
NIL
NIL
1

BUTTON
347
20
414
60
NIL
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

BUTTON
823
83
921
118
NIL
add_robot
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
129
185
251
220
NIL
remove_robot
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
580
159
786
192
noise-actuating-speed
noise-actuating-speed
0
0.5
0.0
0.01
1
m/s
HORIZONTAL

SLIDER
589
113
783
146
noise-actuating-turning
noise-actuating-turning
0
20
0.0
1
1
deg/s
HORIZONTAL

SWITCH
460
30
580
63
paint_fov?
paint_fov?
1
1
-1000

SWITCH
460
68
581
101
draw_path?
draw_path?
1
1
-1000

BUTTON
582
68
685
101
clear-paths
clear-drawing
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
582
25
682
58
NIL
clear-paint
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
2712
264
2832
297
see_walls?
see_walls?
1
1
-1000

SWITCH
85
1170
188
1203
delay?
delay?
0
1
-1000

SLIDER
198
1170
290
1203
delay-length
delay-length
0
30
2.0
1
1
NIL
HORIZONTAL

SLIDER
2933
1238
3101
1271
vision-cone-offset
vision-cone-offset
-90
90
0.0
10
1
NIL
HORIZONTAL

SLIDER
600
199
772
232
false_negative_rate
false_negative_rate
0
100
0.0
1
1
NIL
HORIZONTAL

SWITCH
2958
683
3107
716
collision_stop?
collision_stop?
0
1
-1000

SLIDER
599
235
771
268
false_positive_rate
false_positive_rate
0
100
0.0
1
1
NIL
HORIZONTAL

SWITCH
2968
863
3131
896
mode_switching?
mode_switching?
1
1
-1000

SLIDER
717
414
889
447
number-of-group1
number-of-group1
0
300
1.0
1
1
NIL
HORIZONTAL

SLIDER
2958
908
3130
941
rand_count_prob
rand_count_prob
0
100
25.0
1
1
NIL
HORIZONTAL

SWITCH
2968
763
3111
796
wrap_around?
wrap_around?
1
1
-1000

SLIDER
3148
863
3323
896
mode_switching_type
mode_switching_type
0
3
0.0
1
1
NIL
HORIZONTAL

SWITCH
3143
718
3291
751
start_in_circle?
start_in_circle?
1
1
-1000

SWITCH
2578
269
2697
302
collisions?
collisions?
0
1
-1000

SLIDER
2943
1498
3116
1531
c
c
0
5
0.5
.25
1
NIL
HORIZONTAL

SWITCH
2608
204
2780
237
circular_environment?
circular_environment?
1
1
-1000

SLIDER
2203
18
2359
51
environment_size
environment_size
0
max-pxcor - min-pxcor
80.0
1
1
NIL
HORIZONTAL

SWITCH
3118
678
3281
711
elastic_collisions?
elastic_collisions?
1
1
-1000

SLIDER
3148
908
3321
941
temp
temp
0
100
0.0
1
1
NIL
HORIZONTAL

TEXTBOX
2953
1478
3168
1504
For Levy Distribution
11
0.0
1

TEXTBOX
469
15
684
41
Turn off to speed up sim\n
11
0.0
1

TEXTBOX
3338
868
3553
940
Type 1 switches randomly with probability \"rand_count_prob\"\n\nType 2 switches when agent detects something \"temp\" times\n
11
0.0
1

SLIDER
3086
1026
3262
1059
vision-distance2
vision-distance2
0
10
1.5
.1
1
m
HORIZONTAL

SLIDER
3083
1066
3256
1099
vision-cone2
vision-cone2
0
360
100.0
1
1
deg
HORIZONTAL

SLIDER
3098
1106
3271
1139
mode2
mode2
-1
1
0.0
1
1
NIL
HORIZONTAL

SLIDER
3296
1186
3481
1219
vision-cone-offset2
vision-cone-offset2
-90
90
0.0
10
1
deg
HORIZONTAL

SWITCH
2953
1353
3166
1386
Goal_Searching_Mission?
Goal_Searching_Mission?
1
1
-1000

SLIDER
3173
1353
3322
1386
number-of-goals
number-of-goals
0
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
3323
1353
3471
1386
goal-region-size
goal-region-size
0
100
10.0
5
1
NIL
HORIZONTAL

SWITCH
2948
1393
3146
1426
random_goal_position?
random_goal_position?
1
1
-1000

SLIDER
3168
1398
3371
1431
false_negative_rate_for_goal
false_negative_rate_for_goal
0
100
0.0
1
1
NIL
HORIZONTAL

SLIDER
3383
1393
3579
1426
false_positive_rate_for_goal
false_positive_rate_for_goal
0
100
0.0
1
1
NIL
HORIZONTAL

SLIDER
3168
1433
3341
1466
see_goal_response
see_goal_response
0
3
0.0
1
1
NIL
HORIZONTAL

MONITOR
2693
1363
2859
1408
Time of first goal detection
time-to-first-see
17
1
11

SWITCH
3503
1048
3691
1081
start_in_outward_circle?
start_in_outward_circle?
1
1
-1000

SLIDER
3373
1458
3546
1491
number-of-trials
number-of-trials
0
20
0.0
1
1
NIL
HORIZONTAL

SLIDER
3193
1298
3366
1331
number-of-levys
number-of-levys
0
100
0.0
1
1
NIL
HORIZONTAL

SLIDER
2638
601
2863
634
percent-of-second-species
percent-of-second-species
0
100
0.0
5
1
NIL
HORIZONTAL

SWITCH
2773
943
2963
976
random_start_region?
random_start_region?
0
1
-1000

SLIDER
3128
1498
3275
1531
max_levy_time
max_levy_time
0
100
15.0
1
1
sec
HORIZONTAL

TEXTBOX
3143
1263
3331
1291
off for now, to do levy, switch number-of-group1\n
11
0.0
1

SWITCH
2906
1026
3043
1059
species_levy?
species_levy?
1
1
-1000

SWITCH
3121
856
3278
889
show_detection?
show_detection?
1
1
-1000

PLOT
2052
2156
2766
2605
Number of Agents Detecting Target
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"number_on_green" 1.0 0 -16777216 true "" ""

SWITCH
2538
848
2666
881
static_area?
static_area?
1
1
-1000

SWITCH
2948
558
3141
591
custom_environment?
custom_environment?
1
1
-1000

SLIDER
3153
558
3326
591
gap_width
gap_width
0
100
18.0
1
1
NIL
HORIZONTAL

SLIDER
3153
593
3326
626
gap_length
gap_length
0
100
18.0
1
1
NIL
HORIZONTAL

SLIDER
2948
593
3121
626
custom_env
custom_env
0
3
0.0
1
1
NIL
HORIZONTAL

SWITCH
3488
876
3681
909
non-target-detection?
non-target-detection?
0
1
-1000

TEXTBOX
2733
1323
2862
1351
Time of First Detection
11
0.0
1

CHOOSER
2401
573
2557
618
selected_algorithm1
selected_algorithm1
"Mill" "Dispersal" "Levy" "VNQ" "VQN" "Standard Random" "RRR"
3

CHOOSER
2678
471
2864
516
distribution_for_direction
distribution_for_direction
"uniform" "gaussian" "triangle"
0

CHOOSER
3308
1098
3464
1143
selected_algorithm2
selected_algorithm2
"Mill" "Dispersal" "Levy" "VNQ" "VQN" "Standard Random" "RRR"
6

TEXTBOX
2678
446
2893
472
for random walk algorithms
11
0.0
1

CHOOSER
3483
918
3705
963
non-target-detection-response
non-target-detection-response
"turn-away-in-place" "reverse" "flight"
1

BUTTON
848
463
931
497
Forward
ask robots with [group_type = 2][ set inputs (list (10 * leader_speed) 90 0)]
NIL
1
T
OBSERVER
NIL
W
NIL
NIL
1

BUTTON
854
515
934
549
Reverse
ask robots with [group_type = 2][ set inputs (list (10 * leader_speed) 270 0)]
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
938
515
1042
549
Strafe Right
ask robots with [group_type = 2][ set inputs (list (10 * leader_speed) 0 0)]
NIL
1
T
OBSERVER
NIL
D
NIL
NIL
1

BUTTON
748
515
843
549
Strafe Left
ask robots with [group_type = 2][ set inputs (list (10 * leader_speed) 180 0)]
NIL
1
T
OBSERVER
NIL
A
NIL
NIL
1

BUTTON
940
468
1062
502
Diagonal Right
ask robots with [group_type = 2][ set inputs (list (10 * leader_speed) 45 0)]
NIL
1
T
OBSERVER
NIL
E
NIL
NIL
1

BUTTON
725
468
838
502
Diagonal Left
ask robots with [group_type = 2][ set inputs (list (10 * leader_speed) 135 0)]
NIL
1
T
OBSERVER
NIL
Q
NIL
NIL
1

BUTTON
569
1469
673
1503
Rotate CCW
ask robots with [group_type = 1][ set inputs (list -1 1 -1 1 )]
NIL
1
T
OBSERVER
NIL
T
NIL
NIL
1

BUTTON
709
1476
804
1510
Rotate CW
ask robots with [group_type = 1][ set inputs (list 1 -1 1 -1 )]
NIL
1
T
OBSERVER
NIL
R
NIL
NIL
1

CHOOSER
882
1223
1039
1268
mecanum_procedure
mecanum_procedure
"manual" "Sliders_1" "Levy" "VNQ" "VQN" "Standard Random"
1

BUTTON
873
607
937
641
stop
ask robots with [group_type = 2][ set inputs (list (0) 90 0)]
NIL
1
T
OBSERVER
NIL
X
NIL
NIL
1

BUTTON
869
1573
982
1607
normal circle
ask robots [set inputs (list  1.5 1 1.5 1)]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
2743
828
2896
862
CW away from pivot
ask robots [set inputs (list 1.75 -1.75 -1.25 1.25)]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
2948
828
3081
862
CW toward pivot
ask robots [set inputs (list  -1.25 1.25 1.75 -1.75)]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
26
356
229
389
body_direction1
body_direction1
0
360
90.0
10
1
deg
HORIZONTAL

SLIDER
274
316
469
349
forward_speed2
forward_speed2
0
0.3
0.25
0.05
1
m/s
HORIZONTAL

SLIDER
260
360
458
393
body_direction2
body_direction2
0
360
270.0
10
1
deg
HORIZONTAL

SLIDER
262
404
450
437
turning-rate2
turning-rate2
-150
150
0.0
5
1
deg/s
HORIZONTAL

SWITCH
3094
264
3243
297
start_in_circle?
start_in_circle?
1
1
-1000

SLIDER
2666
701
2838
734
sound_range
sound_range
0
2
0.7
0.1
1
m
HORIZONTAL

CHOOSER
2628
368
2766
413
sensing_type
sensing_type
"sound" "visual"
1

TEXTBOX
722
392
972
422
Controllable Agents using controls below
11
0.0
1

TEXTBOX
37
281
225
309
Inputs for when nothing is detected
11
0.0
1

TEXTBOX
284
284
472
312
Inputs for when something is detected
11
0.0
1

MONITOR
1886
1678
2028
1723
Average velocity
precision avg-speeds 4
17
1
11

MONITOR
1886
1740
2030
1785
Group Rotation
precision group-rot 4
17
1
11

MONITOR
1884
1854
2034
1899
Scatter
precision scatter 4
17
1
11

MONITOR
1886
1910
2038
1955
Radial Variance
precision rad_var 4
17
1
11

MONITOR
1886
1798
2033
1843
Angular Momentum
precision ang-momentum 4
17
1
11

MONITOR
1890
1968
2043
2013
Circliness
precision circliness 4
17
1
11

MONITOR
1890
2028
2043
2073
Algebraic Connectivity
precision alg-con 4
17
1
11

PLOT
2220
1842
2789
2127
Detection (post filter) Flag of Robot 0
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"detect_flag" 1.0 0 -16777216 true "" ""

MONITOR
2050
2068
2218
2113
Auto-Classified Behavior
behave_name
17
1
11

TEXTBOX
210
129
425
158
Keep vision-distance and vision-cone the same for now
11
0.0
1

TEXTBOX
315
1173
465
1229
this is \"sampling period\" - (30 would mean that it takes 30 ticks (0.5 seconds) to take a new measurement)
11
0.0
1

SLIDER
192
1269
297
1302
filter-val
filter-val
0
50
10.0
1
1
NIL
HORIZONTAL

TEXTBOX
329
1266
479
1350
this is the \"window length\" of the filter - (10 means that it saves 10 values and then decides what to do for the next actuation period based on the majority vote)
11
0.0
1

PLOT
2208
1566
2693
1818
Circliness
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"circliness_pen" 1.0 0 -16777216 true "" ""

SLIDER
2515
22
2688
55
number-of-group2
number-of-group2
0
20
0.0
1
1
NIL
HORIZONTAL

SLIDER
232
512
432
545
forward_speed2_B
forward_speed2_B
0
0.3
0.3
0.05
1
m/s
HORIZONTAL

SLIDER
22
514
222
547
forward_speed1_B
forward_speed1_B
0
0.3
0.3
0.05
1
m/s
HORIZONTAL

SLIDER
232
607
432
640
turning-rate2_B
turning-rate2_B
-150
150
-50.0
5
1
deg/s
HORIZONTAL

SLIDER
17
597
217
630
turning-rate1_B
turning-rate1_B
-150
150
50.0
5
1
deg/s
HORIZONTAL

SLIDER
22
564
220
597
body_direction1_B
body_direction1_B
0
359
90.0
10
1
deg
HORIZONTAL

SLIDER
242
564
438
597
body_direction2_B
body_direction2_B
0
359
90.0
10
1
deg
HORIZONTAL

SLIDER
912
417
1085
450
leader_speed
leader_speed
0
0.5
0.3
0.05
1
m/s
HORIZONTAL

BUTTON
284
193
362
226
Mode A
ask robots with [group_type != 0] [set group_type 1]
NIL
1
T
OBSERVER
NIL
8
NIL
NIL
1

BUTTON
364
194
439
227
Mode B
ask robots with [group_type != 0][set group_type 2]
NIL
1
T
OBSERVER
NIL
9
NIL
NIL
1

SWITCH
229
242
454
275
distinguish_between_types?
distinguish_between_types?
0
1
-1000

SLIDER
489
349
677
382
forward_speed3
forward_speed3
0
0.3
0.3
0.05
1
m/s
HORIZONTAL

SLIDER
487
392
669
425
body_direction3
body_direction3
0
360
90.0
10
1
deg
HORIZONTAL

SLIDER
487
437
675
470
turning-rate3
turning-rate3
-150
150
0.0
10
1
deg/s
HORIZONTAL

TEXTBOX
485
312
700
341
Inputs for when Evader is detected (if switch to distinguish is on)
11
0.0
1

SLIDER
878
1324
1078
1357
turning-rate_range
turning-rate_range
0
150
150.0
10
1
deg
HORIZONTAL

TEXTBOX
879
1189
1094
1218
Selects what hunters do when nothing is detected
11
0.0
1

TEXTBOX
903
1294
1118
1323
Turning-Rate range specific to random walk alg
11
0.0
1

MONITOR
1500
22
1606
67
Time of Escape
time-of-escape
17
1
11

MONITOR
1613
22
1726
67
Time of Capture
time-of-capture
17
1
11

MONITOR
1253
25
1433
70
Result
chosen_winner
17
1
11

TEXTBOX
43
473
107
492
Mode B
11
0.0
1

TEXTBOX
49
254
299
284
Mode A
11
0.0
1

CHOOSER
812
278
957
323
evader-control
evader-control
"manual_drive" "straight_to_goal"
0

SLIDER
880
1403
1053
1437
fixed_walk_step
fixed_walk_step
0
600
120.0
60
1
NIL
HORIZONTAL

SLIDER
879
1360
1091
1394
random-walk-speed
random-walk-speed
0
0.30
0.3
0.05
1
m/s
HORIZONTAL

BUTTON
948
559
1111
593
Diagonal Right - Reverse
ask robots with [group_type = 2][ set inputs (list (10 * leader_speed) 315 0)]
NIL
1
T
OBSERVER
NIL
C
NIL
NIL
1

BUTTON
705
560
852
594
Diagonal Left Reverse
ask robots with [group_type = 2][ set inputs (list (10 * leader_speed) 225 0)]
NIL
1
T
OBSERVER
NIL
Z
NIL
NIL
1

BUTTON
442
195
521
229
Mode C
ask robots with [group_type != 0][set group_type 3]
NIL
1
T
OBSERVER
NIL
0
NIL
NIL
1

SLIDER
17
679
216
713
forward_speed1_C
forward_speed1_C
0
0.30
0.3
0.05
1
m/s
HORIZONTAL

SLIDER
15
722
213
756
body_direction1_C
body_direction1_C
0
360
90.0
10
1
deg
HORIZONTAL

SLIDER
13
765
216
799
turning-rate1_C
turning-rate1_C
-150
150
30.0
5
1
deg/s
HORIZONTAL

SLIDER
257
680
460
714
forward_speed2_C
forward_speed2_C
0
0.30
0.3
0.05
1
m/s
HORIZONTAL

SLIDER
254
727
452
761
body_direction2_C
body_direction2_C
0
360
90.0
10
1
deg
HORIZONTAL

SLIDER
253
770
456
804
turning-rate2_C
turning-rate2_C
-150
150
0.0
5
1
deg/s
HORIZONTAL

TEXTBOX
24
653
212
676
Mode C
11
0.0
1

SLIDER
475
680
678
714
forward_speed3_C
forward_speed3_C
0
0.3
0.3
0.05
1
m/s
HORIZONTAL

SLIDER
477
727
675
761
body_direction3_C
body_direction3_C
0
360
90.0
10
1
deg
HORIZONTAL

SLIDER
477
775
680
809
turning-rate3_C
turning-rate3_C
-150
150
0.0
5
1
deg/s
HORIZONTAL

SLIDER
474
514
674
548
forward_speed3_B
forward_speed3_B
0
0.3
0.3
0.05
1
m/s
HORIZONTAL

SLIDER
475
554
670
588
body_direction3_B
body_direction3_B
0
360
90.0
10
1
deg
HORIZONTAL

SLIDER
478
600
678
634
turning-rate3_B
turning-rate3_B
-150
150
0.0
5
1
deg/s
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

boat
true
0
Polygon -7500403 true true 150 0 120 15 105 30 90 105 90 165 90 195 90 240 105 270 105 270 120 285 150 300 180 285 210 270 210 255 210 240 210 210 210 165 210 105 195 30 180 15
Line -1 false 150 60 120 135
Line -1 false 150 60 180 135
Polygon -1 false false 150 60 120 135 180 135 150 60 150 165

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
true
0
Line -7500403 true 135 135 135 30
Circle -7500403 true true 0 0 300
Polygon -16777216 true false 150 -75 105 60 180 60 150 -75

circle 2
true
0
Circle -16777216 true false 0 0 300
Circle -7500403 true true 0 0 300
Polygon -1 true false 150 0 105 135 195 135 150 0

circle 3
true
0
Circle -16777216 true false 0 0 300
Circle -7500403 true true 0 0 300
Polygon -1 true false 150 0 105 135 195 135 150 0
Rectangle -1 true false 55 171 250 246

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

levy
true
0
Polygon -7500403 true true 150 15 120 0 75 60 60 135 15 180 15 210 120 195 90 255 105 285 120 300 150 270 180 300 195 285 210 255 180 195 285 210 285 180 240 135 225 60 180 0
Polygon -1 true false 120 60 120 165 135 165 135 60
Polygon -1 true false 135 150 180 150 180 165 135 165

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

mecanum
true
0
Rectangle -7500403 true true 60 30 240 270
Polygon -7500403 true true 60 30 60 30 90 15 210 15 240 30
Circle -16777216 true false 99 24 42
Circle -16777216 true false 159 24 42
Rectangle -16777216 true false 60 45 60 90
Rectangle -955883 true false 30 45 60 90
Rectangle -955883 true false 30 210 60 255
Rectangle -955883 true false 240 210 270 255
Rectangle -955883 true false 240 45 270 90
Polygon -955883 true false 46 216 62 228

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 0 0 300 300

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 219 240 248 246 269 228 281 215 267 193 225
Polygon -10899396 true false 225 90 255 75 275 75 290 89 299 108 291 124 270 105 255 105 240 105
Polygon -10899396 true false 75 90 45 75 25 75 10 89 1 108 9 124 30 105 45 105 60 105
Polygon -10899396 true false 132 70 134 49 107 36 108 2 150 -13 192 3 192 37 169 50 172 72
Polygon -10899396 true false 85 219 60 248 54 269 72 281 85 267 107 225
Polygon -7500403 true true 75 30 225 30 270 75 270 195 255 240 180 300 135 300 45 240 30 195 30 75

turtle2
true
0
Polygon -10899396 true false 215 219 240 248 246 269 228 281 215 267 193 225
Polygon -10899396 true false 225 90 255 75 275 75 290 89 299 108 291 124 270 105 255 105 240 105
Polygon -10899396 true false 75 90 45 75 25 75 10 89 1 108 9 124 30 105 45 105 60 105
Polygon -10899396 true false 132 70 134 49 107 36 108 2 150 -13 192 3 192 37 169 50 172 72
Polygon -10899396 true false 85 219 60 248 54 269 72 281 85 267 107 225
Polygon -7500403 true true 75 30 225 30 270 75 270 195 255 240 180 300 135 300 45 240 30 195 30 75

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="first-to-see-goal1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="53001"/>
    <exitCondition>time-to-first-see &gt; 0</exitCondition>
    <metric>time-to-first-see</metric>
    <enumeratedValueSet variable="selected_algorithm1">
      <value value="&quot;VNQ&quot;"/>
      <value value="&quot;VQN&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distribution_for_direction">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;gaussian&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-robots">
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="speed1" first="0.1" step="0.1" last="1"/>
    <steppedValueSet variable="seed-no" first="1" step="1" last="25"/>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
