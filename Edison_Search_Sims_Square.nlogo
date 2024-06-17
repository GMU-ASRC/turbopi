;
; Variables
;
breed [ robots robot]
breed [ walls wall]
breed [ goals goal]
breed[ place-holders place-holder]

globals [ tick-delta
          n
          i
          ii
          iii
          j
          time-to-first-see
          time-to-first-see-list
          time-to-25
          time-to-50
          time-to-75
          time-to-95
          rand-xcor
          rand-ycor
          static_area
          sr_patches
          dynamic_area
          calculated_left_speed
          calculated_right_speed
         ]

robots-own [
           velocity
           angular-velocity   ;; angular velocity of heading/yaw
           inputs             ;; input forces
           visible-turtles    ;; what target can I see nearby?
           closest-target     ;; closest target
           impact-x
           impact-y
           angle
           impact-angle
           rand-x
           rand-y
           chance
           turn-r
           speed-w-noise
           turning-w-noise
           robots-in-new-fov
           fov-list
           visible-goals
           speed
           seen_flag
           real-bearing
           fov-list-walls
           visible-walls
           fov-list-patches
           sensor-var
           speed_2
           speed-w-noise2
           turning-w-noise2
           turn-r2
           goal_flag
           group_type
           levy_time
           seen_count
           seen_threshold
           rand_count
           goal_seen_flag
           fov-list-goals
           mass
           wait_ticks
           wall_wait_ticks
           levy_tick_counter
           rand_turn
           rand_velocity
           step_count
           flight_count
           pre_flight_count
           step_time
           flight_time
           pre_flight_time
           max_time
           wall_crash_angle
           wall_bear
           body_direction
           frame_direction
           body_direction2
           detect_step_count

          ]

patches-own [
            real-bearing-patch
          ]

 walls-own [
           velocity
           angular-velocity   ;; angular velocity of heading/yaw
           mass
          ]
;;
;; Setup Procedures
;;
to setup

  clear-all
  random-seed seed-no

  ; sets time step of sim
  set tick-delta 0.1 ; 10 ticks in one second


  ; sets random coordinates for intilization region of robots (when "random_start_region?" is set to on)
  set rand-xcor (random max-pxcor * 0.75) - (random max-pxcor * 0.75)
  set rand-ycor (random max-pycor * 0.75) - (random max-pycor * 0.75)


  ; intializes variables and creates empty lists
  set time-to-first-see-list (list )
  set time-to-first-see 10000
  set time-to-25 10000
  set time-to-50 10000
  set time-to-75 10000
  set time-to-95 10000

  ; sets color of patches/background/floor to white
  ask patches
    [
      set pcolor white
    ]

  ; if switch is on, it adds a goal
  if Goal_Searching_Mission?
    [
      add_goal
    ]

  ;creates robots of either species 1 or 2
  set n number-of-robots
  set number-of-group1 round (percent-of-second-species * 0.01 * number-of-robots)
  while [n > (number-of-group1)]
  [
   make_robot0
   set n (n - 1)
  ]

  while [n > 0]
  [
   make_robot1
   set n (n - 1)
  ]



  ; adds extra "ghost" turtles that make adding and removing agents during simulation a bit easier
  create-place-holders 20
  [
    setxy max-pxcor max-pycor
    ht
  ]

  if walls_on?
     [
       ifelse custom_environment? ;default to off
       [
         ifelse custom_env = 0
         [add_walls_custom0]
         [add_walls_custom1]
       ]
       [
         ifelse circular_environment? ; default to off --> rectangular environment is default
         [add_walls_circular]
         [add_walls]
       ]
     ]
  reset-ticks
end


;;
;; Runtime Procedures
;;
to go

  ifelse static_area? ; displays area that robots have been to
  [
     ask robots with [pcolor != green]
     [set pcolor yellow]
  ]
  [clear-paint]

  ask goals ; moves goal turtle to corner of environment to get it out the way (we only want the green area it initially creates around it)
     [
       setxy max-pxcor max-pycor
       ht
     ]


  ask walls
  [
    set pcolor black
  ]



  ask robots
    [

      ifelse group_type = 0
        [select_alg_procedure1] ; chooses algorithm for agents of species 1
        [select_alg_procedure2] ; chooses algorithm for agents of species 2


        ifelse draw_path?
        [
          pd ; pen down
        ]
        [
          pu ; pen up
        ]

        if paint_fov? ; displays detection region of all robots
          [
            ask robots
              [
                paint-patches-in-new-FOV
              ]
          ]
      ]

      do-plots ; updates plots


      ; updates metrics
      if time-to-first-see = 10000
      [
        if count robots with [pcolor = green] > 0
        [set time-to-first-see ticks]
      ]

      if time-to-25 = 10000
      [
        if static_area > 0.25
        [set time-to-25 ticks]
      ]

      if time-to-50 = 10000
      [
        if static_area > 0.50
        [set time-to-50 ticks]
      ]

      if time-to-75 = 10000
      [
        if static_area > 0.75
        [set time-to-75 ticks]
      ]

      if time-to-95 = 10000
      [
        if static_area > 0.95
        [set time-to-95 ticks]
      ]



  tick-advance 1
end

to select_alg_procedure1
  if selected_algorithm1 = "Mill"
  [mill]

  if selected_algorithm1 = "Dispersal"
  [dispersal]

  if selected_algorithm1 = "VNQ"
  [vnq]

  if selected_algorithm1 = "VQN"
  [vqn]

  if selected_algorithm1 = "Standard Random"
  [standard_random_walk]

  if selected_algorithm1 = "Levy"
  [real_levy]

end

to select_alg_procedure2
  if selected_algorithm2 = "Mill"
  [mill]

  if selected_algorithm2 = "Dispersal"
  [dispersal]

  if selected_algorithm2 = "VNQ"
  [vnq]

  if selected_algorithm2 = "VQN"
  [vqn]

  if selected_algorithm2 = "Standard Random"
  [standard_random_walk]

  if selected_algorithm2 = "Levy"
  [real_levy]

end


to mill  ;; robot procedure for milling
  set_actuating_and_extra_variables
  do_sensing

    ifelse goal_seen_flag = 1
      [
       goal_detected_procedure
      ]
      [
        ifelse seen_flag = 1
         [
           set color blue
           set inputs (list (1 * speed-w-noise) ( -1  * turning-w-noise))
         ]
         [
           set color red
           set inputs (list (1 * speed-w-noise) ( 1  * turning-w-noise))
         ]
     ]

  update_agent_state

  if mode_switching?
    [
     do_mode_switching
    ]
end

to dispersal ; dispersal algorithm (if something is detected, turns right twice as fast)
  set_actuating_and_extra_variables
  do_sensing

    ifelse goal_seen_flag = 1
      [
       goal_detected_procedure
      ]
      [
        ifelse seen_flag = 1
         [
           set color blue
           set inputs (list (1 * speed-w-noise) ( 2  * turning-w-noise))
         ]
         [
           set color red
           set inputs (list (1 * speed-w-noise) ( 1  * turning-w-noise))
         ]
     ]

  update_agent_state

  if mode_switching?
    [
     do_mode_switching
    ]
end


to standard_random_walk ;
  ; separate procedures
  set_actuating_and_extra_variables
  do_sensing

    ifelse goal_seen_flag = 1
      [
       goal_detected_procedure ; if goal is detected, do the goal_detected_procedure
      ]
      [
        ifelse detect_step_count > 0 ; if agent is detected, it stops everything and executes the desired algorithm
          [
            non_target_detection_procedure
            set detect_step_count (detect_step_count - 1) ; counts down
          ]
          [
              ifelse step_count < step_length_fixed ; while step count is less than the set step_length, it should either be turning in place or going straight
              [

                ifelse step_count < (1 / tick-delta) ; for the first 10 ticks of the "step", turn in place at a rate of rand_turn
                 [
                   set color blue
                   set inputs (list (0) rand_turn)
                 ]
                 [
                   ifelse seen_flag = 1
                   [
                     set detect_step_count (1 / tick-delta) ; if something is detected, resets detect_step_count to 10
                   ]
                   [
                     set color red
                     set inputs (list speed-w-noise 0) ; if nothing is detected, goes straight forward at a speed of speed-w-noise
                   ]
                 ]

                set step_count step_count + 1 ;counts up
              ]
              [
                 choose_rand_turn ; at the end of the step, choose random turning rate
                 set step_count 0 ; reset turning rate to zero
              ]

          ]

      ]

  update_agent_state ; updates states of agents (i.e. position and heading)

  ; switches through modes if "mode_switching?" switch is on
  if mode_switching?
    [
     do_mode_switching
    ]
end


to real_levy  ;; classic levy that chooses direction at beginning of step and moves straight in that line. Step lengths are chosen from levy distribution
  set_actuating_and_extra_variables
  do_sensing

    ifelse goal_seen_flag = 1
      [
       goal_detected_procedure ; if goal is detected, do the goal_detected_procedure
      ]
      [
            ifelse detect_step_count > 0 ; if agent is detected, it stops everything and executes the desired algorithm
          [
            non_target_detection_procedure
            set detect_step_count (detect_step_count - 1) ; counts down
          ]

          [
            ifelse step_count < step_time; while step count is less than the the randomly chosen step_length, it should either be turning in place or going straight
            [

              ifelse step_count < (1 / tick-delta) ; for the first 10 ticks of the "step", turn in place at a rate of rand_turn
               [
                 set color blue
                  set inputs (list (0) rand_turn)
               ]
               [
                 ifelse seen_flag = 1
                 [
                   set detect_step_count (1 / tick-delta) ; if something is detected, resets detect_step_count to 10
                 ]
                 [
                   set color red
                   set inputs (list speed-w-noise 0) ; if nothing is detected, goes straight forward at a speed of speed-w-noise
                 ]
               ]

              set step_count step_count + 1 ;increment step count
            ]
            [
                ; at the end of the step, choose a new step length from levy distribution and choose random turning rate
                 set step_time round (100 * (1 / (random-gamma 0.5 (c / 2  ))))
                 while [step_time > round (max_levy_time / tick-delta)]
                   [set step_time round (100 * (1 / (random-gamma 0.5 (c / 2 ))))]

                 choose_rand_turn
                 set step_count 0
            ]
         ]
     ]

  update_agent_state; updates states of agents (i.e. position and heading)

   ; switches through modes if "mode_switching?" switch is on
  if mode_switching?
    [
     do_mode_switching
    ]
end

to vnq  ;; robot procedure for Q's algorithm. Forces agents to take long flights as well as forces them to search locally for a certain amount
        ;; of time (can't take two flights back to back)
  set_actuating_and_extra_variables
  do_sensing

    ifelse goal_seen_flag = 1
      [
       goal_detected_procedure ; if goal is detected, do the goal_detected_procedure
      ]
      [
        ifelse detect_step_count > 0
          [
            non_target_detection_procedure ; if agent is detected, it stops everything and executes the desired algorithm
            set detect_step_count (detect_step_count - 1) ;counts down
          ]

          [
           ifelse pre_flight_count < pre_flight_time  ; the "pre-flight" mode just means the duration of when it is doing the smaller steps before it takes the one large step (aka "flight").
                                                      ; pre_flight_time is chosen randomly at the end of each "flight"
             [
               ifelse seen_flag = 1
                [
                   set detect_step_count (1 / tick-delta) ; if something is detected, resets detect_step_count to 10
                ]
                [
                   ifelse step_count < step_time;  while step count is less than the the randomly chosen step_length, it should either be turning in place or going straight
                     [

                       ifelse step_count < (1 / tick-delta); for the first 10 ticks of the "step", turn in place at a rate of rand_turn
                        [
                          set color orange
                          set inputs (list (0) rand_turn)
                        ]
                        [
                          set color red
                          set inputs (list speed-w-noise 0) ; if nothing is detected, goes straight forward at a speed of speed-w-noise

                        ]
                     set step_count step_count + 1 ; increment count for steps
                   ]
                   [
                     ; at the end of the step, choose a new step length from normal distribution and choose random turning rate
                     set step_time round (random-normal step_time_average step_time_stdev) + 10
                     while [step_time <= 0]
                       [set step_time round (random-normal step_time_average step_time_stdev) + 10]

                     choose_rand_turn
                     set step_count 0
                   ]
                 ]
             set pre_flight_count pre_flight_count + 1
           ]
           [
             ifelse flight_count < flight_time ; once pre_flight is concluded, it does the "flight" for a duration of "flight_time"
             [
               set inputs (list speed-w-noise 0) ; moves straight forward
               set flight_count flight_count + 1
               set color green
             ]
             [
               ; choose random values for all the time variables and chooses a new random turning rate
               set pre_flight_time round (random-normal pre_flight_time_average pre_flight_time_stdev) + 10

               set flight_time round (random-normal flight_time_average flight_time_stdev) + 10
               while [pre_flight_time <= 0]
               [set pre_flight_time round (random-normal pre_flight_time_average pre_flight_time_stdev) + 10]

               set flight_count 0

               choose_rand_turn
               set pre_flight_count 0
             ]
           ]

        ]
     ]

  update_agent_state; updates states of agents (i.e. position and heading)

   ; switches through modes if "mode_switching?" switch is on
  if mode_switching?
    [
     do_mode_switching
    ]
end

to vqn    ;; robot procedure for cameron's algorithm. Forces agents to take long flights (where they move in an arc rather than a straight line)
          ;; as well as forces them to search locally for a certain amount of time (can't take two flights back to back)
  set_actuating_and_extra_variables
  do_sensing

    ifelse goal_seen_flag = 1
      [
       goal_detected_procedure ; if goal is detected, do the goal_detected_procedure
      ]
      [

        ifelse detect_step_count > 0
          [
            non_target_detection_procedure; if agent is detected, it stops everything and executes the desired algorithm
            set detect_step_count (detect_step_count - 1)
          ]

          [
            ifelse pre_flight_count < pre_flight_time; the "pre-flight" mode just means the duration of when it is doing the smaller steps before it takes the one large step (aka "flight").
                                                      ; pre_flight_time is chosen randomly at the end of each "flight"
              [
                ifelse seen_flag = 1
                 [
                    set detect_step_count (1 / tick-delta); if something is detected, resets detect_step_count to 10
                 ]
                 [
                    ifelse step_count < step_time;  while step count is less than the the randomly chosen step_length, it should either be turning in place or going straight
                      [

                        ifelse step_count < (1 / tick-delta); for the first 10 ticks of the "step", turn in place at a rate of rand_turn
                         [
                           set color orange
                           set inputs (list (0) rand_turn)
                         ]
                         [
                           set color red
                           set inputs (list speed-w-noise 0) ; if nothing is detected, goes straight forward at a speed of speed-w-noise

                         ]
                      set step_count step_count + 1
                    ]
                    [
                      ; at the end of the step, choose a new step length from normal distribution and choose random turning rate
                      set step_time round (random-normal 20 5) + 10
                      while [step_time <= 0]
                        [set step_time round (random-normal 20 5) + 10]

                      choose_rand_turn
                      set step_count 0
                    ]
                  ]
              set pre_flight_count pre_flight_count + 1
            ]
            [

              ifelse flight_count < flight_time; once pre_flight is concluded, it does the "flight" for a duration of "flight_time"
                [
                  set inputs (list speed-w-noise ((rand_turn ) / 25)) ;instead of going straight, it moves in an arc
                  set flight_count flight_count + 1
                  set color green
                ]
                [
                 ; choose random values for all the time variables and chooses a new random turning rate
                  while [pre_flight_time <= 0]
                  [set pre_flight_time round (random-normal 400 10) + 10]
                  ;[set pre_flight_time round (random-normal 200 10) + 10]
                  set flight_time round (random-normal 200 10) + 10

                  set flight_count 0

                  choose_rand_turn
                  set pre_flight_count 0
                ]
            ]
        ]
     ]

  update_agent_state; updates states of agents (i.e. position and heading)

   ; switches through modes if "mode_switching?" switch is on
  if mode_switching?
    [
     do_mode_switching
    ]
end



;
;
;-------------- Nested functions and Setup Procedures below--------------
;
;

to non_target_detection_procedure
  set color blue

  if non-target-detection-response = "turn-away-in-place"
    [
      set inputs (list (0) rand_turn)
    ]

    if non-target-detection-response = "reverse"
    [
      set inputs (list (- speed-w-noise) rand_turn)
    ]

    if non-target-detection-response = "flight"
    [
      ;set inputs (list (- speed-w-noise) rand_turn)
      set pre_flight_time 0
    ]


end

to choose_rand_turn
  if distribution_for_direction = "uniform"
  ;[set rand_turn ((- turning_rate_average / 2)) + ((random (turning_rate_average / 2)) * 2) ]
  [set rand_turn ((- turning_rate_val)) + ((random (turning_rate_val) * 2)) ]

  if distribution_for_direction = "gaussian"
  [ set rand_turn round (random-normal 0 (turning_rate_val / 3))]

;  if distribution_for_direction = "triangle"
;  [set rand_turn (random (turning_rate_average) - (random turning_rate_average)) ]
end


to set_actuating_and_extra_variables
  find-chance

  set rand-x random-normal 0 state-disturbance
  set rand-y random-normal 0 state-disturbance

  ifelse group_type = 0
  [
    set speed-w-noise (speed1 * 10) + random-normal 0 noise-actuating-speed
    set turning-w-noise (turning-rate1) + random-normal 0 noise-actuating-turning
  ]
  [
    set speed-w-noise (speed2 * 10) + random-normal 0 noise-actuating-speed
    set turning-w-noise (turning-rate2) + random-normal 0 noise-actuating-turning
  ]
end

to do_sensing

  ifelse see_walls?
    [find-walls-in-new-FOV]
    [set fov-list-walls (list)]
  find-goals-in-new-FOV
  find-robots-in-new-FOV

  ifelse delay?
  [
    if ticks mod delay-length = 0
      [
          ifelse length fov-list > 0 or length fov-list-walls > 0
            [
              ifelse chance < false_negative_rate
                [
                  set seen_flag 0
                ]
                [
                  set seen_flag 1
                ]
            ]
            [

               ifelse chance < false_positive_rate
               [ set seen_flag 1]
               [set seen_flag 0]
            ]

          ifelse length fov-list-goals > 0
            [
              ifelse chance < false_negative_rate_for_goal
                [
                  set goal_seen_flag 0
                ]
                [
                  set goal_seen_flag 1
                ]
            ]
            [
               ifelse chance < false_positive_rate_for_goal
               [ set goal_seen_flag 1]
               [set goal_seen_flag 0]
            ]
        ]
    ]
    [
      ifelse non-target-detection?
      [
      ifelse length fov-list > 0 or length fov-list-walls > 0
        [
          ifelse chance < false_negative_rate
            [
              set seen_flag 0
            ]
            [
              set seen_flag 1
              set seen_count (seen_count + 1)
            ]
         ]
         [
           ifelse chance < false_positive_rate
             [
               set seen_flag 1
             ]
             [
               set seen_flag 0
             ]
         ]

         ]
         [
           set seen_flag 0
         ]
      ifelse length fov-list-goals > 0
            [
              ifelse chance < false_negative_rate_for_goal
                [
                  set goal_seen_flag 0
                ]
                [
                  set goal_seen_flag 1
                ]
            ]
            [
               ifelse chance < false_positive_rate_for_goal
               [ set goal_seen_flag  1]
               [set goal_seen_flag 0]
            ]
    ]
end

to goal_detected_procedure
  ifelse see_goal_response = 0
            [
              set inputs (list (0) ( 0))
            ]
            [

              ifelse see_goal_response = 1
                [
                  set inputs (list (speed-w-noise) ( 1.5 * turning-w-noise) (0))
                ]
              [
                ifelse distance min-one-of visible-goals [distance myself] > 1
                  [
                    set heading towards min-one-of visible-goals [distance myself]
                    set inputs (list (1  * speed-w-noise) (turning-w-noise) (0))
                  ]
                  [
                    set inputs (list 0 0)
                  ]
              ]
              ]
             set color orange
end

to update_agent_state
  agent_dynamics


    if collisions?
    [
      do_collisions
    ]

  let nxcor xcor + ( item 0 velocity * tick-delta  ) + (impact-x * tick-delta  ) + (rand-x * tick-delta  )
  let nycor ycor + ( item 1 velocity * tick-delta  ) + (impact-y * tick-delta  ) + (rand-y * tick-delta  )

  setxy nxcor nycor

  let nheading heading + (angular-velocity * tick-delta  ) + (impact-angle * tick-delta )
  set heading nheading

;  if collisions?
;    [
;      do_collisions
;    ]


  if not wrap_around?
    [
    if (distance (patch min-pxcor ycor ) < 0.5) [let nxcor1 xcor + 0.63
    setxy nxcor1 ycor]
    if (distance (patch max-pxcor ycor) < 0.5) [let nxcor1 xcor - 0.63
    setxy nxcor1 ycor]
    if (distance (patch xcor min-pycor) < 0.5) [let nycor1 ycor + 0.63
    setxy xcor nycor1]
    if (distance (patch xcor max-pycor) < 0.5) [let nycor1 ycor - 0.63
    setxy xcor nycor1]
    ]

end

to do_mode_switching
  ifelse mode_switching_type = 0
      [
        if  ticks mod 100 = 0 and chance < rand_count_prob
          [
           set group_type 1
           set shape "turtle2"
          ]
      ]
      [
        if seen_count > (seen_threshold)
          [
            set group_type 1
            set seen_count 0
            set seen_threshold temp;round random-normal temp 10
          ]
     ]
end


to add_robot
  ask place-holder ((count goals + count robots))
  [  set breed robots
      st

      setxy 0.3 0

      ifelse Goal_Searching_Mission?
      [
        set sr_patches patches with [(distancexy (max-pxcor * -0.75) (max-pycor * -0.75) < (number-of-robots * ([size] of robot (count goals)) / pi)) and pxcor != 0 and pycor != 0]
      ]
      [
        set sr_patches patches with [(distancexy 0 0 < (number-of-robots * ([size] of robot (count goals)) / pi)) and pxcor != 0 and pycor != 0]
      ]

      move-to one-of sr_patches with [(not any? other robots in-radius ([size] of robot (count goals)))]
          setxy (xcor + .01) (ycor + .01)

      set velocity [ 0 0 ]
      set angular-velocity 0
      set inputs [0 0]



      set shape "circle 2"
      set color red
      set size 1 ; sets size to 0.1m

      set mass size

      set speed speed1
      set speed2 speed2

      set turn-r turning-rate1
      set turn-r2 turning-rate2

     set levy_time 200

     set group_type 0
     set color red
    ]

    set number-of-robots (number-of-robots + 1)
end

to remove_robot
ask robot (number-of-robots - 1)
  [
    set breed place-holders
    ht
  ]
  set number-of-robots (number-of-robots - 1)

end

to add_walls
  create-walls ((4 * (max-pxcor - min-pxcor)) + 1) * 2 ;environment_size
      [

             set size 0.5; 0.05m
       set color pink
       set shape "circle 2"

       set mass 1000
       set velocity (list 0 0 )

       set iii (-0.5 * environment_size)
       set ii 0
       while [ii < 2 * environment_size ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii )
           [setxy iii ( (environment_size * -0.5) + 0.49)
           set heading 90]
         set iii (iii + 0.5)
         set ii (ii + 1)

         ]

       set iii (-0.5 * environment_size)
       while [ii < environment_size * 4]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy iii ((0.5 * environment_size) - 0.49 )
           set heading 90]
         set iii (iii + 0.5)
         set ii (ii + 1)

         ]

       set iii (-0.5 * environment_size)
       while [ii < environment_size * 6]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy ((-0.5 * environment_size) + 0.49) iii
           set heading 0]
         set iii (iii + 0.5)
         set ii (ii + 1)
         ]

      set iii (-0.5 * environment_size)
      while [ii < (environment_size * 8) + 1 ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy ((0.5 * environment_size) - 0.49) iii
           set heading 0]
         set iii (iii + 0.5)
         set ii (ii + 1)

         ]

      while [ii < 8 * (max-pxcor - min-pycor) + 2]
      [ask wall (ii + (count goals + count robots) + count place-holders)
        [
          ;set heading (j * heading_num) ;+ (random 20 + random -20)
          setxy max-pxcor max-pycor
          set heading 0

        ]
        set ii ii + 1
        ]

        set pcolor black

  ]

end

to add_walls_custom2
  create-walls ((4 * (max-pxcor - min-pxcor)) + 1 + 107) * 2 ;environment_size
      [

             set size 0.5; 0.05m
       set color pink
       set shape "circle 2"

       set mass 1000
       set velocity (list 0 0 )

       set iii (-0.5 * environment_size)
       set ii 0
       while [ii < 2 * environment_size ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii )
           [setxy iii ( environment_size * -0.5)
           set heading 90]
         set iii (iii + 0.5)
         set ii (ii + 1)

         ]

       set iii (-0.5 * environment_size)
       while [ii < environment_size * 4]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy iii (0.5 * environment_size)
           set heading 90]
         set iii (iii + 0.5)
         set ii (ii + 1)

         ]

       set iii (-0.5 * environment_size)
       while [ii < environment_size * 6]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy (-0.5 * environment_size) iii
           set heading 0]
         set iii (iii + 0.5)
         set ii (ii + 1)
         ]

      set iii (-0.5 * environment_size)
      while [ii < (environment_size * 8) + 1 ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy (0.5 * environment_size) iii
           set heading 0]
         set iii (iii + 0.5)
         set ii (ii + 1)

         ]

      ;mine

      let wall_count 19
      let wall_count_2 (wall_count * 2)
      set iii (0)
      while [ii < ((environment_size * 4) + 1) * 2 + wall_count_2 ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy (-18.69) iii
           set heading 180]
         set iii (iii - 0.5)
         set ii (ii + 1)

         ]


      set wall_count (wall_count + 13)
     set wall_count_2 (wall_count * 2)
      set iii (-18.75)
      while [ii < ((environment_size * 4) + 1) * 2 + wall_count_2 ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy iii (-18.75)
           set heading 0]
         set iii (iii + 0.5)
         set ii (ii + 1)

         ]

      set wall_count (wall_count + 19)
      set wall_count_2 (wall_count * 2)
      set iii (-24)
      while [ii < ((environment_size * 4) + 1) * 2 + wall_count_2 ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy (0) iii
           set heading 0]
         set iii (iii + 0.5)
         set ii (ii + 1)

         ]

      set wall_count (wall_count + 6)
      set wall_count_2 (wall_count * 2)
      set iii (-18.75)
      while [ii < ((environment_size * 4) + 1) * 2 + wall_count_2 ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy (-6.25) iii
           set heading 0]
         set iii (iii + 0.5)
         set ii (ii + 1)

         ]

      set wall_count (wall_count + 6)
      set wall_count_2 (wall_count * 2)
      set iii (-6.25)
      while [ii < ((environment_size * 4) + 1) * 2 + wall_count_2 ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy iii (-12.5)
           set heading 0]
         set iii (iii - 0.5)
         set ii (ii + 1)

         ]

      set wall_count (wall_count + 19)
      set wall_count_2 (wall_count * 2)
      set iii (-12.5)
      while [ii < ((environment_size * 4) + 1) * 2 + wall_count_2 ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy (-12.5) iii
           set heading 180]
         set iii (iii + 0.5)
         set ii (ii + 1)

         ]

      set wall_count (wall_count + 6)
      set wall_count_2 (wall_count * 2)
      set iii (-1)
      while [ii < ((environment_size * 4) + 1) * 2 + wall_count_2 ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy iii (-6.25)
           set heading 0]
         set iii (iii - 0.5)
         set ii (ii + 1)

         ]

      set wall_count (wall_count + 6)
      set wall_count_2 (wall_count * 2)
      set iii (-24)
      while [ii < ((environment_size * 4) + 1) * 2 + wall_count_2 ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy iii (0)
           set heading 0]
         set iii (iii + 0.5)
         set ii (ii + 1)

         ]

      set wall_count (wall_count + 13)
      set wall_count_2 (wall_count * 2)
      print wall_count
      set iii (-6.25)
      while [ii < ((environment_size * 4) + 1) * 2 + wall_count_2 ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy (-6.25) iii
           set heading 0]
         set iii (iii + 0.5)
         set ii (ii + 1)

         ]

;      while [ii < 4 * (max-pxcor - min-pycor)]
;      [ask wall (ii + (count goals + count robots) + count place-holders)
;        [
;          ;set heading (j * heading_num) ;+ (random 20 + random -20)
;          setxy max-pxcor max-pycor
;          set heading 0
;
;        ]
;        set ii ii + 1
;        ]

       ]
end

to add_walls_circular
  create-walls (4 * (max-pxcor - min-pxcor)) + 1;(round environment_size * pi * 0.75)
      [

      let irr environment_size / (2)
      set j 0
      let heading_num 360 / (round environment_size * pi * 0.75)


      while [j < (round environment_size * pi * 0.75) - 1]
      [ask wall (j + (count goals + count robots) + count place-holders)
        [
          ;set heading (j * heading_num) ;+ (random 20 + random -20)
          setxy (irr * -1 * cos(j * heading_num)) (irr * sin(j * heading_num))
          set heading j * heading_num

        ]

        set j j + 1
    ]

    while [j < 4 * (max-pxcor - min-pycor)]
    [ask wall (j + (count goals + count robots) + count place-holders)
        [
          ;set heading (j * heading_num) ;+ (random 20 + random -20)
          setxy max-pxcor max-pycor
          set heading 0

        ]

        set j j + 1
    ]


       set size 1
       set color pink
       set shape "circle 2"
       set heading 0
       set mass size
       set velocity (list 0 0 )
      ]
end

to add_walls_custom0
  create-walls (4 * (max-pxcor - min-pxcor)) + (2 * (environment_size)) + 3 ;environment_size
      [

             set size 1
       set color pink
       set shape "circle 2"

       set mass 1000
       set velocity (list 0 0 )

       set iii (-0.5 * environment_size)
       set ii 0
       while [ii < environment_size ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy iii ( environment_size * -0.5)
           set heading 90]
         set iii (iii + 1)
         set ii (ii + 1)

         ]

       set iii (-0.5 * environment_size)
       while [ii < environment_size * 2]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy iii (0.5 * environment_size)
           set heading 90]
         set iii (iii + 1)
         set ii (ii + 1)

         ]

       set iii (-0.5 * environment_size)
       while [ii < (environment_size * 2) + ((environment_size - gap_length) / 2)]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy (-0.5 * environment_size) iii
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]

       set iii (0.5 * environment_size) ;+ (environment_size / 2 + gap_length)
       while [ii < (environment_size * 2) + (environment_size - gap_length)]
       [
         ask wall ((count goals + count robots) + count place-holders + ii)
           [setxy (-0.5 * environment_size) iii
           set heading 0]
         set iii (iii - 1)
         set ii (ii + 1)
         ]

       set iii (-0.5 * environment_size)
       while [ii < (environment_size * 2) + (3 * (environment_size - gap_length) / 2)]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy (0.5 * environment_size) iii
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]

       set iii (0.5 * environment_size) ;+ (environment_size / 2 + gap_length)
       while [ii < (environment_size * 2) + 2 * (environment_size - gap_length)]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy (0.5 * environment_size) iii
           set heading 0]
         set iii (iii - 1)
         set ii (ii + 1)
         ]

       set iii (-0.5 * environment_size)
       while [ii < (environment_size * 2) + (2 * (environment_size - gap_length)) + ((environment_size - gap_width) / 2)]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy iii (gap_length / 2)
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]

       set iii (-0.5 * environment_size)
       while [ii < (environment_size * 2) + (2 * (environment_size - gap_length)) + ((environment_size - gap_width))]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy iii (- gap_length / 2)
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]

       set iii (0.5 * environment_size)
       while [ii < (environment_size * 2) + (2 * (environment_size - gap_length)) + (3 * (environment_size - gap_width) / 2)]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy iii (gap_length / 2)
           set heading 0]
         set iii (iii - 1)
         set ii (ii + 1)
         ]

       set iii (0.5 * environment_size)
       while [ii < (environment_size * 2) + (2 * (environment_size - gap_length)) + (2 * (environment_size - gap_width))]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy iii (- gap_length / 2)
           set heading 0]
         set iii (iii - 1)
         set ii (ii + 1)
         ]

       set iii (gap_length / -2)
       while [ii < (environment_size * 2) + (2 * (environment_size - gap_length)) + (2 * (environment_size - gap_width)) + gap_length + 1]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy (gap_width / 2) iii
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]

       set iii (gap_length / -2)
       while [ii < (environment_size * 2) + (2 * (environment_size - gap_length)) + (2 * (environment_size - gap_width)) + (2 * gap_length) + 2]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy (- gap_width / 2) iii
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]


       while [ii < (4 * (max-pxcor - min-pxcor)) + (2 * (environment_size)) + 3]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy max-pxcor max-pycor
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]
       ]

       ask patches with [(abs(pycor) < (gap_length / 2))  and (abs(pxcor) > (gap_width / 2))]
       [ set pcolor black]
end

to add_walls_custom1
  create-walls (6 * (max-pxcor - min-pxcor)) + 1;(round environment_size * pi * 0.75)
      [

      let irr environment_size / (2)
      set j 0
      let heading_num 360 / (round environment_size * pi * 0.75)


      while [j < (round environment_size * pi * 0.75) - 1]
      [ask wall (j + (count goals + count robots) + count place-holders  )
        [
          ;set heading (j * heading_num) ;+ (random 20 + random -20)
          setxy (irr * -1 * cos(j * heading_num)) (irr * sin(j * heading_num))
          set heading j * heading_num

        ]

        set j j + 1
    ]

    set iii (0.5 * environment_size)
       while [j < ((round environment_size * pi * 0.75) - 1)  + ((environment_size - gap_length))]
       [
         ask wall (j + (count goals + count robots) + count place-holders  )
           [setxy  (- gap_width / 2) iii
           set heading 0]
         set iii (iii - 1)
         set j (j + 1)
         ]

    set iii (0.5 * environment_size)
       while [j < ((round environment_size * pi * 0.75) - 1)  + 2 * ((environment_size - gap_length))]
       [
         ask wall (j + (count goals + count robots) + count place-holders  )
           [setxy  ( gap_width / 2) iii
           set heading 0]
         set iii (iii - 1)
         set j (j + 1)
         ]

     set iii (gap_width / -2)
       while [j < ((round environment_size * pi * 0.75) - 1)  + 2 * ((environment_size - gap_length)) + gap_width + 1]
       [
         ask wall (j + (count goals + count robots) + count place-holders  )
           [setxy iii ( (-0.5 * environment_size)  + ( gap_length) )
           set heading 0]
         set iii (iii + 1)
         set j (j + 1)
         ]



    while [j < 4 * (max-pxcor - min-pycor)]
    [ask wall (j + (count goals + count robots) + count place-holders   )
        [
          ;set heading (j * heading_num) ;+ (random 20 + random -20)
          setxy max-pxcor max-pycor
          set heading 0

        ]

        set j j + 1
    ]


       set size 1
       set color pink
       set shape "circle 2"
       set heading 0
       set mass size
       set velocity (list 0 0 )
      ]

      ask patches with [pycor > ( (-0.5 * environment_size)  + ( gap_length) )  and (abs(pxcor) <(gap_width / 2))]
       [ set pcolor black]
      ask patches with [distance patch 0 0 > environment_size / (2)]
       [ set pcolor black]
end



to add_goal
  create-goals number-of-goals
  [
    set shape "circle"
    set size 1
    set color violet

    ifelse random_goal_position?
      [
        ;let gr (range  (goal-region-size) (max-pxcor - goal-region-size) 1)
        let gr (range  (min-pxcor + goal-region-size) (max-pxcor - goal-region-size) 1)
        setxy (one-of gr) (one-of gr)
      ]
      [
        ;setxy (max-pxcor - ( goal-region-size + 10)) (max-pycor - (goal-region-size + 10))
        setxy (-10) 10
      ]

    ask patches in-radius goal-region-size
    [set pcolor green]
  ]
end


to move_walls_square


       set iii (-0.5 * environment_size)
       set ii 0
       while [ii < environment_size ]
       [
         ask wall ((count goals + count robots) + count place-holders  + ii  )
           [setxy iii ( environment_size * -0.5)
           set heading 90]
         set iii (iii + 1)
         set ii (ii + 1)

         ]

       set iii (-0.5 * environment_size)
       while [ii < environment_size * 2]
       [
         ask wall ((count goals + count robots) + count place-holders  + ii   )
           [setxy iii (0.5 * environment_size)
           set heading 90]
         set iii (iii + 1)
         set ii (ii + 1)

         ]

       set iii (-0.5 * environment_size)
       while [ii < environment_size * 3]
       [
         ask wall ((count goals + count robots) + count place-holders  + ii   )
           [setxy (-0.5 * environment_size) iii
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]
      set iii (-0.5 * environment_size)
      while [ii < (environment_size * 4)  + 1]
       [
         ask wall ((count goals + count robots) + count place-holders  + ii   )
           [setxy (0.5 * environment_size) iii
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)

         ]
      while [ii < (4 * (max-pxcor - min-pxcor)) + 1]
      [ask wall (ii + (count goals + count robots) + count place-holders   )
        [
          ;set heading (j * heading_num) ;+ (random 20 + random -20)
          setxy max-pxcor max-pycor
          set heading 0
        ]
        set ii ii + 1
        ]
end

to move_walls_circular
  let irr environment_size / (2)
      set j 0
      let heading_num 360 / (round environment_size * pi * 0.75)

      while [j < (round environment_size * pi * 0.75) - 1]
      [ask wall (j + (count goals + count robots) + count place-holders   )
        [
          ;set heading (j * heading_num) ;+ (random 20 + random -20)
          setxy (irr * 1 * cos(j * heading_num)) (irr * sin(j * heading_num))
          set heading ( - j * heading_num )

        ]
        set j j + 1
  ]

  while [j < (4 * (max-pxcor - min-pxcor)) + 1]
    [ask wall (j + (count goals + count robots) + count place-holders   )
        [
          ;set heading (j * heading_num) ;+ (random 20 + random -20)
          setxy max-pxcor max-pycor
          set heading 0
        ]
        set j j + 1
    ]
end

to move_walls_custom0

           set iii (-0.5 * environment_size)
       set ii 0
       while [ii < environment_size ]
       [
         ask wall ((count goals + count robots) + count place-holders + ii  )
           [setxy iii ( environment_size * -0.5)
           set heading 90]
         set iii (iii + 1)
         set ii (ii + 1)

         ]

       set iii (-0.5 * environment_size)
       while [ii < environment_size * 2]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy iii (0.5 * environment_size)
           set heading 90]
         set iii (iii + 1)
         set ii (ii + 1)

         ]

       set iii (-0.5 * environment_size)
       while [ii < (environment_size * 2) + ((environment_size - gap_length) / 2)]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy (-0.5 * environment_size) iii
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]

       set iii (0.5 * environment_size) ;+ (environment_size / 2 + gap_length)
       while [ii < (environment_size * 2) + (environment_size - gap_length)]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy (-0.5 * environment_size) iii
           set heading 0]
         set iii (iii - 1)
         set ii (ii + 1)
         ]

       set iii (-0.5 * environment_size)
       while [ii < (environment_size * 2) + (3 * (environment_size - gap_length) / 2)]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy (0.5 * environment_size) iii
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]

       set iii (0.5 * environment_size) ;+ (environment_size / 2 + gap_length)
       while [ii < (environment_size * 2) + 2 * (environment_size - gap_length)]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy (0.5 * environment_size) iii
           set heading 0]
         set iii (iii - 1)
         set ii (ii + 1)
         ]

       set iii (-0.5 * environment_size)
       while [ii < (environment_size * 2) + (2 * (environment_size - gap_length)) + ((environment_size - gap_width) / 2)]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy iii (gap_length / 2)
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]

       set iii (-0.5 * environment_size)
       while [ii < (environment_size * 2) + (2 * (environment_size - gap_length)) + ((environment_size - gap_width))]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy iii (- gap_length / 2)
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]

       set iii (0.5 * environment_size)
       while [ii < (environment_size * 2) + (2 * (environment_size - gap_length)) + (3 * (environment_size - gap_width) / 2)]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy iii (gap_length / 2)
           set heading 0]
         set iii (iii - 1)
         set ii (ii + 1)
         ]

       set iii (0.5 * environment_size)
       while [ii < (environment_size * 2) + (2 * (environment_size - gap_length)) + (2 * (environment_size - gap_width))]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy iii (- gap_length / 2)
           set heading 0]
         set iii (iii - 1)
         set ii (ii + 1)
         ]

       set iii (gap_length / -2)
       while [ii < (environment_size * 2) + (2 * (environment_size - gap_length)) + (2 * (environment_size - gap_width)) + gap_length + 1]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy (gap_width / 2) iii
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]

       set iii (gap_length / -2)
       while [ii < (environment_size * 2) + (2 * (environment_size - gap_length)) + (2 * (environment_size - gap_width)) + (2 * gap_length) + 2]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy (- gap_width / 2) iii
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]

       while [ii < (4 * (max-pxcor - min-pxcor)) + (2 * (environment_size)) + 3]
       [
         ask wall ((count goals + count robots) + count place-holders + ii   )
           [setxy max-pxcor max-pycor
           set heading 0]
         set iii (iii + 1)
         set ii (ii + 1)
         ]


       ask patches with [(abs(pycor) < (gap_length / 2))  and (abs(pxcor) > (gap_width / 2))]
       [ set pcolor black]

       ask patches with [pcolor = black]
       [
         if (abs(pycor) >= (gap_length / 2))  or (abs(pxcor) <= (gap_width / 2))
         [set pcolor white]
       ]



end

to move_walls_custom1
      let irr environment_size / (2)
      set j 0
      let heading_num 360 / (round environment_size * pi * 0.75)


      while [j < (round environment_size * pi * 0.75) - 1]
      [ask wall (j + (count goals + count robots) + count place-holders  )
        [
          ;set heading (j * heading_num) ;+ (random 20 + random -20)
          setxy (irr * -1 * cos(j * heading_num)) (irr * sin(j * heading_num))
          set heading j * heading_num

        ]

        set j j + 1
    ]

    set iii (0.5 * environment_size)
       while [j < ((round environment_size * pi * 0.75) - 1)  + ((environment_size - gap_length))]
       [
         ask wall (j + (count goals + count robots) + count place-holders  )
           [setxy  (- gap_width / 2) iii
           set heading 0]
         set iii (iii - 1)
         set j (j + 1)
         ]

    set iii (0.5 * environment_size)
       while [j < ((round environment_size * pi * 0.75) - 1)  + 2 * ((environment_size - gap_length))]
       [
         ask wall (j + (count goals + count robots) + count place-holders  )
           [setxy  ( gap_width / 2) iii
           set heading 0]
         set iii (iii - 1)
         set j (j + 1)
         ]

     set iii (gap_width / -2)
       while [j < ((round environment_size * pi * 0.75) - 1)  + 2 * ((environment_size - gap_length)) + gap_width + 1]
       [
         ask wall (j + (count goals + count robots) + count place-holders  )
           [setxy iii ( (-0.5 * environment_size)  + ( gap_length) )
           set heading 0]
         set iii (iii + 1)
         set j (j + 1)
         ]



    while [j < 6 * (max-pxcor - min-pycor) + 1]
    [ask wall (j + (count goals + count robots) + count place-holders   )
        [
          ;set heading (j * heading_num) ;+ (random 20 + random -20)
          setxy max-pxcor max-pycor
          set heading 0

        ]

        set j j + 1
    ]


      ask patches with [pycor > ( (-0.5 * environment_size)  + ( gap_length) )  and (abs(pxcor) <(gap_width / 2))]
       [ set pcolor black]
      ask patches with [distance patch 0 0 > environment_size / (2)]
       [ set pcolor black]

      ask patches with [pcolor = black and distance patch 0 0 < environment_size / (2)]
       [
         if (pycor <=  (-0.5 * environment_size)  + ( gap_length) )  or (abs(pxcor) > (gap_width / 2))
         [set pcolor white]
       ]
end


to make_robot0
  create-robots 1
    [
      set velocity [ 0 0]
      set angular-velocity 0
      set inputs [0 0]
      set size 0.8 ; 0.08m

      let sr (range ((150  )) ((- 150 )) -.5)
      let pr (range ((max-pxcor * .35 )) ((- (max-pxcor * .35)  )) -.5)
      setxy (one-of pr) (one-of pr)

      ifelse Goal_Searching_Mission?
      [
        ifelse random_start_region?
          [
            set sr_patches patches with [(distancexy rand-xcor rand-ycor < (1.2 * number-of-robots * ([size] of robot (count goals)) / (2 * pi) ) + 1) and pxcor != 0 and pycor != 0]
          ]
          [
            ;set sr_patches patches with [(distancexy (max-pxcor * -0.55) (max-pycor * -0.55) < (34 * ([size] of robot (count goals)) / (2 * pi) ) + 1) and pxcor != 0 and pycor != 0]
            set sr_patches patches with [(distancexy (-22) (-4) < (10 * ([size] of robot (count goals)) / (2 * pi) ) + 1) and pxcor != 0 and pycor != 0]
            ;set sr_patches patches with [(distancexy (max-pxcor * -0.55) (max-pycor * -0.55) < 4.54) and pxcor != 0 and pycor != 0]
          ]
      ]
      [
        set sr_patches patches with [(distancexy 0 0 < ((0.9 * number-of-robots * ([size] of robot (count goals)) / pi) + 2)) and pxcor != 0 and pycor != 0]
      ]

      if spawn_semi_randomly?
        [
          move-to one-of sr_patches with [(not any? other robots in-radius ([size] of robot (count goals)))]
          setxy (xcor + .01) (ycor + .01)
        ]

      set shape "edison"
      set color red
      set mass size

      set speed speed1
      set speed_2 speed2

      set turn-r turning-rate1
      set turn-r2 turning-rate2

     set levy_time round (100 * (1 / (random-gamma 0.5 (c / 2  ))))
     while [levy_time > (max_levy_time / tick-delta)]
     [set levy_time round (100 * (1 / (random-gamma 0.5 (.5))))]
     set pre_flight_time round (random-normal pre_flight_time_average pre_flight_time_stdev) + 10
     ;set pre_flight_time round (random-normal 200 10) + 10

     set flight_time round (random-normal flight_time_average flight_time_stdev) + 10

     set group_type 0
     set color red


    ]
end

to make_robot1
  create-robots 1
    [
      set velocity [ 0 0]
      set angular-velocity 0
      set inputs [0 0]
      set size 0.5; 0.1m

      let sr (range ((150  )) ((- 150 )) -.5)
      let pr (range ((max-pxcor * .35 )) ((- (max-pxcor * .35)  )) -.5)
      setxy (one-of pr) (one-of pr)

      ifelse Goal_Searching_Mission?
      [
        ifelse random_start_region?
          [
            set sr_patches patches with [(distancexy rand-xcor rand-ycor < (34 * ([size] of robot (count goals)) / (2 * pi) ) + 1) and pxcor != 0 and pycor != 0]
          ]
          [
            set sr_patches patches with [(distancexy (max-pxcor * -0.55) (max-pycor * -0.55) < (34 * ([size] of robot (count goals)) / (2 * pi) ) + 1) and pxcor != 0 and pycor != 0]
          ]
      ]
      [
        set sr_patches patches with [(distancexy 0 0 < ((0.9 * number-of-robots * ([size] of robot (count goals)) / pi) + 2)) and pxcor != 0 and pycor != 0]
      ]

      if spawn_semi_randomly?
        [
          move-to one-of sr_patches with [(not any? other robots in-radius ([size] of robot (count goals)))]
          setxy (xcor + .01) (ycor + .01)
        ]

      set shape "circle 3"
      set color red
      set mass size

      set speed speed1
      set speed_2 speed2

      set turn-r turning-rate1
      set turn-r2 turning-rate2

     set levy_time round (100 * (1 / (random-gamma 0.5 (c / 2  ))))
     while [levy_time > (max_levy_time / tick-delta)]
     [set levy_time round (100 * (1 / (random-gamma 0.5 (.5  ))))]
     set pre_flight_time round (random-normal 400 10) + 10

     set flight_time round (random-normal 200 10) + 10

     set group_type 1
     set color red
    ]
end


to clear-paint
ask patches
      [
        ifelse static_area?
        [
          if pcolor = orange
          [
            set pcolor yellow
          ]
          if pcolor != green or pcolor != yellow
          [
            set pcolor white
          ]
        ]
        [
           if pcolor != green
          [
            set pcolor white
          ]
        ]
      ]
end



to do-plots
;  set-current-plot "Percentage of Agents Detecting Target"
;  set-current-plot-pen "number_on_green"
;  plot (count robots with [goal_seen_flag = 1]) / count robots

  set-current-plot "Percentage of Agents at Target"
  set-current-plot-pen "number_on_green"
  plot (count robots with [pcolor = green]) / count robots


  find-metrics

  set-current-plot "Static Area Covered"
  set-current-plot-pen "static_area"
  plot static_area
;
;  set-current-plot "Dynamic Area Covered"
;  set-current-plot-pen "dynamic_area"
;  plot dynamic_area
end

to find-metrics
  set static_area (count patches with [pcolor = yellow]) / (count patches with [pcolor != black and pcolor != green])
  set dynamic_area (count patches with [pcolor = orange]) / (count patches with [pcolor != black])
end


to find-chance
     set chance random-float  99
end


to agent_dynamics

  let wheel_radius 0.1905;1.905 cm
  let body_width 0.8
  let wheel_speed_coefficient_v 0.331
  let wheel_speed_coefficient_turn 0.131

;  ifelse (Left_Wheel_Speed = 0) or (Right_Wheel_Speed = 0)
;  [
;    set wheel_speed_coefficient_v 0.256
;    set wheel_speed_coefficient_turn 0.295
;  ]
;  [
;    set wheel_speed_coefficient_v 0.331
;    set wheel_speed_coefficient_turn 0.131
;  ]



  let v_x item 0 inputs * sin(heading)
  let v_y item 0 inputs * cos(heading)
  let theta_dot item 1 inputs

  ;let v_x wheel_speed_coefficient_v * (wheel_radius / 2) * (Left_Wheel_Speed + Right_Wheel_Speed) * sin(heading)
  ;let v_y wheel_speed_coefficient_v  * (wheel_radius / 2) * (Left_Wheel_Speed + Right_Wheel_Speed) * cos(heading)
  ;let theta_dot  ((wheel_radius / (body_width))* wheel_speed_coefficient_turn  * (Left_Wheel_Speed - Right_Wheel_Speed)) * 180 / pi




  set velocity (list (v_x) (v_y) 0)
  set angular-velocity theta_dot
end

to translate_speeds
  let wheel_radius 0.1905;1.905 cm
  let body_width 0.8
  let wheel_speed_coefficient_v 0.331
  let wheel_speed_coefficient_turn 0.131

  set calculated_left_speed 0
  set calculated_right_speed 0


end



to do_collisions
if count other turtles > 0
      [
        let closest-target1 (max-one-of place-holders [distance myself])

        if count robots > 1
        [set closest-target1 (min-one-of other robots [distance myself])]


        ifelse walls_on?
          [
            let closest-target2 (min-one-of walls [distance myself])

            ifelse distance closest-target1 > distance closest-target2
              [set closest-target closest-target2]
              [set closest-target closest-target1]
          ]
          [
            set closest-target closest-target1
          ]

        ifelse (distance closest-target ) < (size + ([size] of closest-target)) / 2
           [
              let xdiff item 0 target-diff
              let ydiff item 1 target-diff
              set body_direction2 (360 - heading)
              let coll_angle (rel-bearing - (body_direction2))

;              if body_direction2 > 180
;              [
;                set body_direction2 (body_direction2 - 360)
;              ]
;
;              ifelse coll_angle < -180
;              [
;                set coll_angle coll_angle + 360
;               ]
;              [
;                ifelse coll_angle > 180
;                [set coll_angle coll_angle - 360]
;                [set coll_angle coll_angle]
;              ]

              ifelse (item 0 inputs) >= 0
              [
                ifelse member? closest-target walls
                  [

                    ifelse abs(rel-bearing) < 90
                    [
                      set impact-x  (-1 * item 0 velocity)
                      set impact-y  (-1 * item 1 velocity)
                      ;set impact-angle (- angular-velocity)
                    ]
                    [
                     set impact-x 0
                     set impact-y 0
                     set impact-angle 0
                    ]
                  ]

                  [
                    ifelse abs(rel-bearing) < 90
                    [
                      set impact-x  (-1 * item 0 velocity)
                      set impact-y  (-1 * item 1 velocity)
                      ;set impact-angle (- angular-velocity)
                    ]
                    [
                     set impact-x 0
                     set impact-y 0
                     set impact-angle 0
                    ]
                   ]
               ]
               [
                ifelse member? closest-target walls
                  [

                    ifelse abs(rel-bearing) > 90
                    [
                      set impact-x  (-1 * item 0 velocity)
                      set impact-y  (-1 * item 1 velocity)
                      ;set impact-angle (- angular-velocity)
                    ]
                    [
                     set impact-x 0
                     set impact-y 0
                     set impact-angle 0
                    ]
                  ]

                  [
                    ifelse abs(rel-bearing) > 90
                    [
                      set impact-x  (-1 * item 0 velocity)
                      set impact-y  (-1 * item 1 velocity)
                      ;set impact-angle (- angular-velocity)
                    ]
                    [
                     set impact-x 0
                     set impact-y 0
                     set impact-angle 0
                    ]
                   ]
               ]



                ]
          [
            set wait_ticks 0
            set impact-angle 0
            set impact-x 0
            set impact-y 0
          ]
      ]

end



to find-closest-walls  ;; turtle procedure
  let vision-dd vision-distance
  ifelse wrap_around?
   [set visible-walls (walls in-cone (vision-distance * 10) (vision-cone )) with [distancexy ([xcor] of myself) ([ycor] of myself) <= (vision-dd * 10)]]
   [set visible-walls (walls in-cone (vision-distance * 10) (vision-cone )) with [distancexy-nowrap ([xcor] of myself) ([ycor] of myself) <= (vision-dd * 10)]]
end

to find-closest-robots  ;; turtle procedure
   let vision-dd vision-distance
   ifelse wrap_around?
   [set visible-turtles (other robots in-cone (vision-distance * 10) (vision-cone)) with [distancexy ([xcor] of myself) ([ycor] of myself) <= (vision-dd * 10)]]
   [set visible-turtles (other robots in-cone (vision-distance * 10) (vision-cone)) with [distancexy-nowrap ([xcor] of myself) ([ycor] of myself) <= (vision-dd * 10)]]

end

to find-closest-goals  ;; turtle procedure
   let vision-dd vision-distance
   ifelse wrap_around?
   [set visible-goals (goals in-cone (vision-distance * 10) (vision-cone)) with [distancexy ([xcor] of myself) ([ycor] of myself) <= (vision-dd * 10)]]
   [set visible-goals (goals in-cone (vision-distance * 10) (vision-cone)) with [distancexy-nowrap ([xcor] of myself) ([ycor] of myself) <= (vision-dd * 10)]]

end


to find-robots-in-new-FOV
  find-closest-robots
  let vision-dd vision-distance
  set fov-list (list )
  set i (count goals)

  while [i < (count goals + count robots)]
    [
      if self != robot ((i )  )
        [
          let sub-heading towards robot (i ) - heading
          set real-bearing sub-heading

          if sub-heading < 0
            [set real-bearing sub-heading + 360]

          if sub-heading > 180
            [set real-bearing sub-heading - 360]

          if real-bearing > 180
            [set real-bearing real-bearing - 360]


          if (real-bearing < ((vision-cone / 2) + vision-cone-offset) and real-bearing > ((vision-cone / -2) + vision-cone-offset)) and (distance-nowrap (robot (i )) < (vision-dd * 10));
          [
            set fov-list fput (robot (i)) fov-list
          ]
        ]
     set i (i + 1)
    ]
end

to find-walls-in-new-FOV
  let vision-dd vision-distance
  set fov-list-walls (list )
  set i 0

  while [i < count walls]
  [
    let sub-heading towards wall (i + (count goals + count robots) + count place-holders  ) - heading

   set real-bearing sub-heading

   if sub-heading < 0
    [set real-bearing sub-heading + 360]


  if sub-heading > 180
    [set real-bearing sub-heading - 360]

  if real-bearing > 180
    [set real-bearing real-bearing - 360]


    if (real-bearing < ((vision-cone / 2) + vision-cone-offset) and real-bearing > ((vision-cone / -2) + vision-cone-offset)) and (distance-nowrap (wall (i + (count goals + count robots) + count place-holders  )) < (vision-dd * 10))
    [ set fov-list-walls fput (wall (i + (count goals + count robots) + count place-holders  )) fov-list-walls]

    set i (i + 1)
   ]


end

to find-goals-in-new-FOV
find-closest-goals
  let vision-dd vision-distance
  set fov-list-goals (list )
  set i 0

  while [i < count goals]
  [
    let sub-heading towards goal (i) - heading

   set real-bearing sub-heading

   if sub-heading < 0
    [set real-bearing sub-heading + 360]


  if sub-heading > 180
    [set real-bearing sub-heading - 360]

  if real-bearing > 180
    [set real-bearing real-bearing - 360]


    if (real-bearing < ((vision-cone / 2) + vision-cone-offset) and real-bearing > ((vision-cone / -2) + vision-cone-offset)) and (distance-nowrap (goal (i )) < (vision-dd * 10))
    [ set fov-list-goals fput (goal (i)) fov-list-goals]

    set i (i + 1)
   ]


end

to paint-patches-in-new-FOV
  ifelse group_type = 0
    [
      let half-fov vision-cone / 2
    ]
    [
      let half-fov vision-cone2 / 2
    ]


  set fov-list-patches (list )
  set i 0


  ifelse group_type = 0
    [
      set fov-list-patches patches in-cone (vision-distance * 10) (vision-cone + (2 * abs(vision-cone-offset))) with [(distancexy-nowrap ([xcor] of myself) ([ycor] of myself) <= (vision-distance * 10))  and pcolor != black]
    ]
    [
      set fov-list-patches patches in-cone (vision-distance2 * 10) (vision-cone2 + (2 * abs(vision-cone-offset2))) with [(distancexy-nowrap ([xcor] of myself) ([ycor] of myself) <= (vision-distance * 10)) and pcolor != black]
    ]


  ask fov-list-patches
  [
      ifelse towards myself  > 180
      [
        let sub-heading (towards myself - 180) - [heading] of myself
        set real-bearing-patch sub-heading
        if sub-heading < 0
          [set real-bearing-patch sub-heading + 360]

        if sub-heading > 180
          [set real-bearing-patch sub-heading - 360]

        if real-bearing-patch > 180
          [set real-bearing-patch real-bearing-patch - 360]
      ]
      [
        let sub-heading (towards myself + 180) - [heading] of myself
        set real-bearing-patch sub-heading

        if sub-heading < 0
          [set real-bearing-patch sub-heading + 360]

        if sub-heading > 180
          [set real-bearing-patch sub-heading - 360]

        if real-bearing-patch > 180
          [set real-bearing-patch real-bearing-patch - 360]
      ]



      ifelse [group_type] of myself = 0
      [
        if (real-bearing-patch < ((vision-cone / 2) + vision-cone-offset) and real-bearing-patch > ((-1 * (vision-cone / 2)) + vision-cone-offset ))
        [
          ifelse show_detection?
          [
            ifelse [color] of myself = red
              [set pcolor yellow]
              [set pcolor orange]
          ]
          [
            set pcolor orange
          ]
        ]
      ]
      [
        if (real-bearing-patch < ((vision-cone2 / 2) + vision-cone-offset2) and real-bearing-patch > ((-1 * (vision-cone2 / 2)) + vision-cone-offset2 ))
        [
          ifelse show_detection?
          [
            ifelse [color] of myself = red
              [set pcolor yellow]
              [set pcolor orange]
          ]
          [
            set pcolor orange
          ]
        ]
      ]
  ]

end







to-report target-diff  ;; robot reporter
     report
    (   map
        [ [a q] -> a - q]
        (list
          [xcor] of closest-target
          [ycor] of closest-target)
        (list
          xcor
          ycor))

end

to-report mean-target-diff  ;; robot reporter
     report
    (   map
        [ [a q] -> a - q]
        (list
          mean [xcor] of visible-turtles
          mean [ycor] of visible-turtles)
        (list
          xcor
          ycor))

end


to-report rel-bearing
  let xdiff item 0 target-diff
  let ydiff item 1 target-diff

  let cart-heading (90 - heading)

  ifelse cart-heading < 0
    [set cart-heading cart-heading + 360]
    [set cart-heading cart-heading]

  ifelse cart-heading > 180
    [set cart-heading cart-heading - 360]
    [set cart-heading cart-heading]

  if xdiff != 0 and ydiff != 0
    [set angle (atan ydiff xdiff)]


  let bearing cart-heading - angle
  if bearing < -180
    [set bearing bearing + 360]
  report( bearing )
end

to-report rel-bearing-mean
  let xdiff item 0 mean-target-diff
  let ydiff item 1 mean-target-diff

  let cart-heading (90 - heading)

  ifelse cart-heading < 0
    [set cart-heading cart-heading + 360]
    [set cart-heading cart-heading]

  ifelse cart-heading > 180
    [set cart-heading cart-heading - 360]
    [set cart-heading cart-heading]

  if xdiff != 0 and ydiff != 0
    [set angle (atan ydiff xdiff)]


  let bearing cart-heading - angle
  if bearing < -180
    [set bearing bearing + 360]

  report( bearing )
end


;;
;; vector operations
;;
to-report add [ v1 v2 ]
  report (map [ [a q] -> a + q ] v1 v2)
end

to-report scale [ scalar vector ]
  report map [ p -> scalar * p ] vector
end

to-report scale_angle [ scalar vector ]
  set vector vector * scalar
  report (vector)
end

to-report magnitude [ vector ]
  report sqrt sum map [ p -> p * p ] vector
end

to-report normalize [ vector ]
  let m magnitude vector
  if m = 0 [ report vector ]
  report map [ p -> p / m ] vector
end

to-report normalize_angle [ v1 ]
  let m abs(v1)
  if m = 0 [ report v1 ]
  ;report map [ n -> n / m ] v1
  set v1 v1 / m
  report (v1)
end
@#$#@#$#@
GRAPHICS-WINDOW
904
13
1482
592
-1
-1
18.4
1
10
1
1
1
0
1
1
1
-15
15
-15
15
1
1
1
ticks
10.0

SLIDER
542
20
714
53
number-of-robots
number-of-robots
0
12
12.0
1
1
NIL
HORIZONTAL

SLIDER
432
18
524
51
seed-no
seed-no
1
25
1.0
1
1
NIL
HORIZONTAL

SLIDER
13
79
187
112
vision-distance
vision-distance
0
0.12
0.12
0.1
1
m
HORIZONTAL

SLIDER
12
117
184
150
vision-cone
vision-cone
0
46
46.0
1
1
deg
HORIZONTAL

SLIDER
23
179
200
212
speed1
speed1
-0.36
0.36
0.36
0.01
1
m/s
HORIZONTAL

SLIDER
20
238
200
271
turning-rate1
turning-rate1
0
530
80.0
5
1
deg/s
HORIZONTAL

SLIDER
2478
605
2650
638
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
2483
328
2661
361
spawn_semi_randomly?
spawn_semi_randomly?
0
1
-1000

SWITCH
2507
225
2622
258
walls_on?
walls_on?
0
1
-1000

SLIDER
2450
1180
2622
1213
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
S
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
2943
393
3041
428
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
3044
394
3165
429
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
2630
690
2828
723
noise-actuating-speed
noise-actuating-speed
0
2
0.0
0.05
1
NIL
HORIZONTAL

SLIDER
2633
650
2829
683
noise-actuating-turning
noise-actuating-turning
0
20
0.0
1
1
NIL
HORIZONTAL

SWITCH
205
75
325
108
paint_fov?
paint_fov?
1
1
-1000

SWITCH
205
112
326
145
draw_path?
draw_path?
1
1
-1000

BUTTON
327
112
430
145
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
327
73
427
106
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
1159
1068
1279
1101
see_walls?
see_walls?
0
1
-1000

SWITCH
2478
835
2581
868
delay?
delay?
1
1
-1000

SLIDER
2590
835
2682
868
delay-length
delay-length
0
30
5.0
1
1
NIL
HORIZONTAL

SLIDER
2450
1125
2618
1158
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
2483
875
2655
908
false_negative_rate
false_negative_rate
0
100
0.0
1
1
NIL
HORIZONTAL

SLIDER
2658
875
2830
908
false_positive_rate
false_positive_rate
0
100
0.0
1
1
NIL
HORIZONTAL

SLIDER
2460
1045
2633
1078
speed2
speed2
0
2
0.4
0.1
1
m/s
HORIZONTAL

SLIDER
2458
1083
2646
1116
turning-rate2
turning-rate2
0
180
90.0
5
1
deg/s
HORIZONTAL

SWITCH
2483
750
2646
783
mode_switching?
mode_switching?
1
1
-1000

SLIDER
2460
963
2632
996
number-of-group1
number-of-group1
0
300
0.0
1
1
NIL
HORIZONTAL

SLIDER
2475
793
2647
826
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
2483
650
2626
683
wrap_around?
wrap_around?
1
1
-1000

SLIDER
2663
750
2838
783
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
2658
605
2806
638
start_in_circle?
start_in_circle?
1
1
-1000

SWITCH
2475
533
2594
566
collisions?
collisions?
0
1
-1000

SLIDER
389
498
562
531
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
2622
225
2794
258
circular_environment?
circular_environment?
1
1
-1000

SLIDER
2442
24
2598
57
environment_size
environment_size
0
max-pxcor - min-pxcor
30.0
1
1
NIL
HORIZONTAL

SLIDER
2663
793
2836
826
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
399
478
614
504
For Levy Distribution
11
0.0
1

TEXTBOX
215
60
430
86
Turn off to speed up sim\n
11
0.0
1

TEXTBOX
2194
1245
2409
1271
NIL
11
0.0
1

TEXTBOX
2854
753
3069
825
Type 1 switches randomly with probability \"rand_count_prob\"\n\nType 2 switches when agent detects something \"temp\" times\n
11
0.0
1

SLIDER
2653
1005
2829
1038
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
2650
1043
2823
1076
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
2665
1085
2838
1118
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
2840
1010
3025
1043
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
1382
1003
1595
1036
Goal_Searching_Mission?
Goal_Searching_Mission?
0
1
-1000

SLIDER
2688
1240
2837
1273
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
2840
1240
2988
1273
goal-region-size
goal-region-size
0
10
1.5
1
1
NIL
HORIZONTAL

SWITCH
1379
1043
1577
1076
random_goal_position?
random_goal_position?
1
1
-1000

SLIDER
2685
1283
2888
1316
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
2898
1280
3094
1313
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
2685
1320
2858
1353
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
37
577
203
622
Time of first arrival
time-to-first-see
17
1
11

SWITCH
2468
1320
2656
1353
start_in_outward_circle?
start_in_outward_circle?
1
1
-1000

SLIDER
2888
1345
3061
1378
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
2710
1183
2883
1216
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
2478
915
2703
948
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
1167
998
1357
1031
random_start_region?
random_start_region?
1
1
-1000

SLIDER
2643
1385
2790
1418
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
2660
1148
2848
1176
off for now, to do levy, switch number-of-group1\n
11
0.0
1

SWITCH
2473
1005
2610
1038
species_levy?
species_levy?
0
1
-1000

SWITCH
2441
67
2598
100
show_detection?
show_detection?
1
1
-1000

PLOT
1040
1318
1421
1551
Percentage of Agents at Target
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
1367
1090
1495
1123
static_area?
static_area?
0
1
-1000

SWITCH
2463
443
2656
476
custom_environment?
custom_environment?
1
1
-1000

SLIDER
2668
443
2841
476
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
2668
478
2841
511
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
2463
480
2636
513
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
1160
1028
1353
1061
non-target-detection?
non-target-detection?
1
1
-1000

CHOOSER
500
88
656
133
selected_algorithm1
selected_algorithm1
"Levy" "VNQ" "VQN" "Standard Random"
3

CHOOSER
274
228
427
273
distribution_for_direction
distribution_for_direction
"uniform" "gaussian"
1

CHOOSER
2874
1077
3030
1122
selected_algorithm2
selected_algorithm2
"Mill" "Dispersal" "Levy" "VNQ" "VQN" "Standard Random" "RRR"
6

TEXTBOX
584
298
799
324
for VNQ & VQN algorithms 
11
0.0
1

CHOOSER
1145
1130
1367
1175
non-target-detection-response
non-target-detection-response
"turn-away-in-place" "reverse"
1

SLIDER
480
320
668
353
pre_flight_time_average
pre_flight_time_average
100
500
500.0
50
1
NIL
HORIZONTAL

SLIDER
492
358
668
391
flight_time_average
flight_time_average
100
500
100.0
50
1
NIL
HORIZONTAL

SLIDER
493
394
669
427
step_time_average
step_time_average
0
100
20.0
10
1
NIL
HORIZONTAL

SLIDER
274
280
460
313
turning_rate_val
turning_rate_val
0
180
180.0
10
1
NIL
HORIZONTAL

SLIDER
680
320
850
353
pre_flight_time_stdev
pre_flight_time_stdev
0
50
50.0
5
1
NIL
HORIZONTAL

SLIDER
680
362
850
395
flight_time_stdev
flight_time_stdev
0
50
10.0
50
1
NIL
HORIZONTAL

SLIDER
679
399
848
432
step_time_stdev
step_time_stdev
0
50
5.0
5
1
NIL
HORIZONTAL

SLIDER
1412
977
1584
1010
turning_rate_stdev
turning_rate_stdev
0
50
50.0
5
1
NIL
HORIZONTAL

SLIDER
282
394
454
427
step_length_fixed
step_length_fixed
20
100
30.0
10
1
NIL
HORIZONTAL

TEXTBOX
20
55
170
73
Do Not Change
11
0.0
1

TEXTBOX
285
372
435
390
for standard random walk
11
0.0
1

TEXTBOX
278
195
428
223
for all random walk algorithms
11
0.0
1

PLOT
242
582
732
850
Static Area Covered
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
"static_area" 1.0 0 -16777216 true "" ""

MONITOR
35
627
202
672
Time of 25% Static Coverage
time-to-25
17
1
11

MONITOR
35
673
202
718
Time of 50% Static Coverage
time-to-50
17
1
11

MONITOR
35
722
204
767
Time of 75% Static Coverage
time-to-75
17
1
11

MONITOR
35
775
222
820
Time of 95% Static Coverage
time-to-95
17
1
11

MONITOR
607
1028
724
1073
Left Wheel Speed
calculated_left_speed
17
1
11

MONITOR
733
1028
858
1073
Right Wheel Speed
calculated_right_speed
17
1
11

BUTTON
663
985
800
1019
NIL
translate_speeds
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

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

edison
true
0
Rectangle -7500403 true true 60 30 240 270
Rectangle -16777216 true false 45 180 60 255
Rectangle -16777216 true false 240 180 255 255
Polygon -1 true false 150 30 150 30 120 105 180 105 150 30

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
  <experiment name="Score_test" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>time-to-95 != 10000</exitCondition>
    <metric>time-to-first-see</metric>
    <metric>time-to-25</metric>
    <metric>time-to-50</metric>
    <metric>time-to-75</metric>
    <metric>time-to-95</metric>
    <steppedValueSet variable="number-of-robots" first="1" step="1" last="12"/>
    <enumeratedValueSet variable="seed-no">
      <value value="1"/>
    </enumeratedValueSet>
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
