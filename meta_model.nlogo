__includes [
  "netlogo_source/io-tools.nls"
  "netlogo_source/social-network-holzhauer.nls"
  "netlogo_source/social-network-suslab.nls"
  "netlogo_source/social-network-scale-free.nls"
  "netlogo_source/assign-lifestyles-schwarz.nls"
  "netlogo_source/technology-diffusion-schwarz.nls"
  "netlogo_source/technology-diffusion-schwarz-alternative.nls"
  "netlogo_source/technology-effect.nls"
  "netlogo_source/behavior-diffusion.nls"
  "netlogo_source/pattern-technology-adoption.nls"
  "netlogo_source/pattern-exponential-take-off.nls"
  "netlogo_source/innovation-properties.nls"
  
  "netlogo_source/policy-seed-10-percent.nls"
  "netlogo_source/policy-seed-10-percent-opinion-leaders.nls"
  ]

turtles-own
[
  adopting-technology?  ;; true if turtles adopt technology
  adopting-behavior     ;; degree of adoption of 'efficient behavior' (0,1) - 0: no adoption, 1: full adoption

  aware-of-technology?  ;; if an agent is aware of a technology

  degree                ;; pre-defined degree of agent in social network in order to match given degree distribution
  lifestyle             ;; sociological lifestyle
]

globals[
  timeline
]  


;;; VISUALIZATION

;; visualize states of agents
to visualize

  if (not visualize?) [stop]

  if agent-visualization = "lifestyle" [
    ask turtles [
      set shape "circle"
      if lifestyle = "postmaterial" [ set color green ]
      if lifestyle = "leader"       [ set color blue  ]
      if lifestyle = "traditional"  [ set color brown ]
      if lifestyle = "mainstream"   [ set color grey  ]
      if lifestyle = "hedonistic"   [ set color pink  ]
    ]
  ]


  if agent-visualization = "technology-behavior" [
    ask turtles [
      ifelse adopting-technology?
        [ set shape "circle"   ]
        [ set shape "circle 2" ]
      set color (67 - (adopting-behavior * 5))
    ]
  ]

  if agent-visualization = "in-ego-network" or agent-visualization = "out-ego-network" [
    ;; by default, color all turtles grey and all links white
    ask turtles [ set color 7 ]
    ask links [ set hidden? true ]
    ask one-of turtles [
      set color red
      ; ask in-link-neighbors to change color accordingly
      if agent-visualization = "in-ego-network" [
        ask link-neighbors [ set color blue ]
        ask my-links [ set hidden? false ]
      ]
      ;; ask out-link-neighbors to change color accordingly
      if agent-visualization = "out-ego-network" [
        ask out-link-neighbors [ set color blue ]
        ask my-out-links [ set hidden? false ]
      ]
    ]
  ]

end


;;; SETUP

to setup
  setup-nodes
  
  read-network
  initialize-diffusion

  load-innovation-properties
end


;;; CREATE AGENTS

to setup-nodes

  if debug? [ print "setting up nodes..." ]

  clear-all
  ask patches [ set pcolor white ]
  set-default-shape turtles "circle"

  ;crt number-of-nodes [
  ;  setxy random-xcor random-ycor
  ;]
  ;assign-lifestyles-schwarz   ; assign lifestyles to turtles

  read-agents

  ask turtles [
    set adopting-technology? false
    set aware-of-technology? false
  ]

  reset-ticks
  visualize
end


to-report behavior-histogram

  let i 18
  let increment 0.1
  let histogram_list []

  while [i <= 21.1] [
    ; count frequence of turtles within interval
    let frequence count turtles with [lifestyle = "leader" and adopting-behavior >= i and adopting-behavior < (i + increment)]

    ; write frequence to list
    set histogram_list lput frequence histogram_list

    ; move to next interval
    set i (i + increment)
  ]

  report histogram_list
end




;;; SIMULATE

to simulate

  run-policy

  technology-diffusion
  ;technology-effect
  ;behavior-diffusion
  write-timeline
  visualize
  tick
end

to reset-simulation

  reset-ticks
  clear-all-plots
  reset-technology-diffusion
  reset-behavior-diffusion
end


to write-timeline
  if any? turtles [  
    ; track timeline
    let adoption (100 * (count turtles with [adopting-technology?] / count turtles))  
    set timeline sentence timeline adoption
  ]
end


;;; TECHNOLOGY DIFFUSION

to technology-diffusion
  
  ask-concurrent turtles [
  
    ; word-of-mouth
    ;if (any? in-link-neighbors with [ adopting-technology? ]) [ set aware-of-technology? true ]
    if (word-of-mouth? and (not aware-of-technology?))     [ stop ]
    
    ; choosing decision model
    if technology-diffusion-method = "schwarz"             [ technology-diffusion-schwarz             ]
    if technology-diffusion-method = "schwarz_alternative" [ technology-diffusion-schwarz-alternative ]
  ] 
  
end

to reset-technology-diffusion
  ask turtles [ set adopting-technology? false ]
  visualize
  reset-ticks
end

to initialize-diffusion
  ask turtles with [lifestyle = "leader" or lifestyle = "postmaterial"] [
    if random-float 1 < (technology-adoption / 100) [
      set adopting-technology? true
      set aware-of-technology? true
    ]
  ]
  
  ask turtles [
    if random-float 1 < (technology-awareness / 100) [
      set adopting-technology? false
      set aware-of-technology? true
    ]
  ]

  visualize
end


;;; TECHNOLOGY EFFECT

to technology-effect
  if technology-effect-method = "direct"      [ technology-effect-direct      ]
  if technology-effect-method = "incremental" [ technology-effect-incremental ]
  if technology-effect-method = "asymptotic"  [ technology-effect-asymptotic  ]
end


;;; BEHAVIOR DIFFUSION

to behavior-diffusion

  if behavior-diffusion-method = "anderson" [ behavior-diffusion-anderson ]
  if behavior-diffusion-method = "azar"     [ behavior-diffusion-azar     ]

end

to reset-behavior-diffusion
  if behavior-init-dist = "uniform" [
    ask turtles [ set adopting-behavior random-float 1 ]
  ]

  if behavior-init-dist = "empirical" [

    let behavior-diffusion-social-backup behavior-diffusion-social
    set behavior-diffusion-social 0.09

    if dissonance-threshold > 0 [
      ask turtles [
        while [(adopting-behavior < 13.1) or (adopting-behavior > 17.9)] [
          set adopting-behavior random-normal 21.1 behavior-init-sd
        ]
      ]
      stabilize-behavior
    ]

    ;; 'stabilize-behavior' would not converge for dissonance threshold of 0
    if dissonance-threshold = 0 [
      ask turtles [
        set adopting-behavior 21.1
      ]
    ]

    set behavior-diffusion-social behavior-diffusion-social-backup
  ]

  if behavior-init-dist = "generic" [
    ask turtles [ set adopting-behavior 21.1 ]
  ]
  visualize
  reset-ticks
end

to stabilize-behavior
  loop [
    if debug? [ print "stabilizing behavior..." ]

    let sum-old sum ([adopting-behavior] of turtles)
    behavior-diffusion
    let sum-new sum ([adopting-behavior] of turtles)
    if sum-old = sum-new [
      ;; HERE: behavior is stable

      ;; correct mean of behavior to 21.1 - based on Shipworth2010
      let temp-diff (mean [adopting-behavior] of turtles) - 21.1
      ask turtles [ set adopting-behavior (adopting-behavior - temp-diff) ]

      reset-ticks
      stop ]
  ]
end


;;; POLICY

to run-policy
  if policy = "off"                             [                                        ]  ; do nothing
  if policy = "seed_10_percent"                 [ policy-seed-10-percent                 ]
  if policy = "seed-10-percent-opinion-leaders" [ policy-seed-10-percent-opinion-leaders ]
end


@#$#@#$#@
GRAPHICS-WINDOW
409
10
779
401
-1
-1
3.57
1
10
1
1
1
0
0
0
1
0
100
0
100
1
1
1
ticks
30.0

BUTTON
17
99
99
132
NIL
setup-nodes
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
21
192
179
220
Longest local link:
11
0.0
1

TEXTBOX
21
80
171
98
SETUP AGENTS
11
0.0
1

TEXTBOX
215
143
324
161
VISUALIZATION
11
0.0
1

BUTTON
219
257
361
290
update visualization
visualize
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
218
206
360
251
agent-visualization
agent-visualization
"lifestyle" "technology-behavior" "in-ego-network" "out-ego-network"
1

TEXTBOX
220
578
370
596
TECHNOLOGY DIFFUSION
11
0.0
1

CHOOSER
218
597
392
642
technology-diffusion-method
technology-diffusion-method
"schwarz" "schwarz_alternative" "off"
1

PLOT
787
191
1069
341
Technology adoption (%)
NIL
NIL
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"leader" 1.0 0 -13345367 true "" "let plot-lifestyle \"leader\"\nlet lifestyle-turtles count turtles with [lifestyle = plot-lifestyle]\nlet adopting-lifestyle-turtles count turtles with [lifestyle = plot-lifestyle and adopting-technology? = true]\nif lifestyle-turtles != 0 [ plot 100 * (adopting-lifestyle-turtles / lifestyle-turtles)]"
"postmaterial" 1.0 0 -10899396 true "" "let plot-lifestyle \"postmaterial\"\nlet lifestyle-turtles count turtles with [lifestyle = plot-lifestyle]\nlet adopting-lifestyle-turtles count turtles with [lifestyle = plot-lifestyle and adopting-technology? = true]\nif lifestyle-turtles != 0 [ plot 100 * (adopting-lifestyle-turtles / lifestyle-turtles)]"
"hedonistic" 1.0 0 -2064490 true "" "let plot-lifestyle \"hedonistic\"\nlet lifestyle-turtles count turtles with [lifestyle = plot-lifestyle]\nlet adopting-lifestyle-turtles count turtles with [lifestyle = plot-lifestyle and adopting-technology? = true]\nif lifestyle-turtles != 0 [ plot 100 * (adopting-lifestyle-turtles / lifestyle-turtles)]"
"traditional" 1.0 0 -6459832 true "" "let plot-lifestyle \"traditional\"\nlet lifestyle-turtles count turtles with [lifestyle = plot-lifestyle]\nlet adopting-lifestyle-turtles count turtles with [lifestyle = plot-lifestyle and adopting-technology? = true]\nif lifestyle-turtles != 0 [ plot 100 * (adopting-lifestyle-turtles / lifestyle-turtles)]"
"mainstream" 1.0 0 -7500403 true "" "let plot-lifestyle \"mainstream\"\nlet lifestyle-turtles count turtles with [lifestyle = plot-lifestyle]\nlet adopting-lifestyle-turtles count turtles with [lifestyle = plot-lifestyle and adopting-technology? = true]\nif lifestyle-turtles != 0 [ plot 100 * (adopting-lifestyle-turtles / lifestyle-turtles)]"
"average" 1.0 0 -16777216 true "" "if any? turtles [ plot 100 * (count turtles with [adopting-technology?] / count turtles)]"

TEXTBOX
411
578
561
596
TECHNOLOGY EFFECT
11
0.0
1

CHOOSER
409
597
581
642
technology-effect-method
technology-effect-method
"direct" "incremental" "asymptotic" "off"
3

BUTTON
409
649
581
682
NIL
technology-effect
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
209
17
359
35
SIMULATE
11
0.0
1

BUTTON
213
37
366
70
NIL
repeat 180 [simulate]\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
618
577
768
595
BEHAVIOR DIFFUSION
11
0.0
1

CHOOSER
616
596
800
641
behavior-diffusion-method
behavior-diffusion-method
"anderson" "azar" "off"
2

BUTTON
18
471
180
504
NIL
reset-behavior-diffusion
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
410
686
560
704
Incremental:
11
0.0
1

SLIDER
408
701
583
734
technology-effect-decrement
technology-effect-decrement
0
1
0.201
0.001
1
NIL
HORIZONTAL

TEXTBOX
617
644
767
662
Anderson:
11
0.0
1

SLIDER
616
659
800
692
behavior-diffusion-social
behavior-diffusion-social
0
1
1
0.01
1
NIL
HORIZONTAL

SLIDER
616
710
800
743
adopting-behavior-var
adopting-behavior-var
0
0.5
0.05
0.05
1
NIL
HORIZONTAL

TEXTBOX
618
696
768
714
Azar:
11
0.0
1

BUTTON
213
78
363
111
NIL
reset-simulation
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
218
650
390
683
word-of-mouth?
word-of-mouth?
1
1
-1000

SLIDER
21
281
181
314
technology-adoption
technology-adoption
0
100
0
1
1
%
HORIZONTAL

TEXTBOX
408
737
558
755
asmyptotic:
11
0.0
1

SLIDER
407
754
582
787
technology-effect-rate
technology-effect-rate
0
1
1
0.1
1
NIL
HORIZONTAL

SWITCH
220
295
361
328
debug?
debug?
1
1
-1000

TEXTBOX
786
170
936
188
Aggregated adoptions:
11
0.0
1

TEXTBOX
23
264
173
282
INITIALIZATION
11
0.0
1

CHOOSER
18
421
180
466
behavior-init-dist
behavior-init-dist
"uniform" "empirical" "generic"
0

SLIDER
617
751
802
784
dissonance-threshold
dissonance-threshold
0
4
0
0.1
1
NIL
HORIZONTAL

SLIDER
408
794
580
827
effect-temperature
effect-temperature
0
25
0
1
1
NIL
HORIZONTAL

SLIDER
18
507
181
540
behavior-init-sd
behavior-init-sd
0
10
2.5
0.1
1
NIL
HORIZONTAL

SLIDER
617
795
802
828
behavior-noise
behavior-noise
0
1
0.77
0.01
1
NIL
HORIZONTAL

SLIDER
20
208
182
241
max-distance
max-distance
0
100
20
1
1
NIL
HORIZONTAL

SLIDER
218
788
392
821
p_mainstream_social
p_mainstream_social
0
1
0.91
0.01
1
NIL
HORIZONTAL

SLIDER
218
827
390
860
p_hedonistic_social
p_hedonistic_social
0
1
0.9
0.1
1
NIL
HORIZONTAL

SLIDER
218
752
391
785
p_leader_social
p_leader_social
0
1
0.88
0.01
1
NIL
HORIZONTAL

TEXTBOX
219
729
391
757
Schwarz parameters:\n
11
0.0
1

BUTTON
17
36
83
69
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
21
577
171
595
INNOVATION
11
0.0
1

CHOOSER
21
596
174
641
innovation
innovation
"showerhead"
0

TEXTBOX
221
868
358
886
Schwarz alterantive:
11
0.0
1

SLIDER
219
887
392
920
leader_w_social
leader_w_social
0
1
0
.05
1
NIL
HORIZONTAL

SLIDER
219
922
393
955
main_w_social
main_w_social
0
1
0
.05
1
NIL
HORIZONTAL

SLIDER
219
958
392
991
hed_w_social
hed_w_social
0
1
0
.1
1
NIL
HORIZONTAL

SLIDER
218
687
390
720
deliberation_rate
deliberation_rate
0.004
0.04
0.037
0.0005
1
NIL
HORIZONTAL

TEXTBOX
21
404
171
422
INITIAL BEHAVIOR
11
0.0
1

TEXTBOX
18
17
168
35
SETUP
11
0.0
1

BUTTON
1132
534
1519
567
NIL
repeat 180 [\n  simulate\n  print pattern-exponential-take-off\n]
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
219
167
361
200
visualize?
visualize?
1
1
-1000

TEXTBOX
817
573
967
591
POLICY
11
0.0
1

CHOOSER
818
596
1036
641
policy
policy
"off" "seed_10_percent" "seed-10-percent-opinion-leaders"
0

SLIDER
22
328
181
361
technology-awareness
technology-awareness
0
100
5
1
1
%
HORIZONTAL

@#$#@#$#@
## COPYRIGHT AND LICENSE

Copyright 2014 Thorben Jensen.

![CC BY-NC-SA 3.0](http://i.creativecommons.org/l/by-nc-sa/3.0/88x31.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Thorben Jensen @ jensen.thorben@gmail.com.
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
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -1 true false 45 45 210

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

square
false
0
Rectangle -7500403 true true 30 30 270 270

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
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="policy" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>simulate</go>
    <timeLimit steps="181"/>
    <metric>(count turtles with [adopting-technology?]) / (count turtles)</metric>
    <metric>(count turtles with [(lifestyle = "leader" or lifestyle = "postmaterial") and adopting-technology?]) / (count turtles with [(lifestyle = "leader" or lifestyle = "postmaterial")])</metric>
    <metric>(count turtles with [(lifestyle = "mainstream" or lifestyle = "traditional") and adopting-technology?]) / (count turtles with [(lifestyle = "mainstream" or lifestyle = "traditional")])</metric>
    <metric>(count turtles with [lifestyle = "hedonistic" and adopting-technology?]) / (count turtles with [lifestyle = "hedonistic"])</metric>
    <enumeratedValueSet variable="effect-temperature">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="visualize?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behavior-diffusion-method">
      <value value="&quot;off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="technology-effect-method">
      <value value="&quot;off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="innovation">
      <value value="&quot;showerhead&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p_leader_social">
      <value value="0.41"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p_mainstream_social">
      <value value="0.83"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p_hedonistic_social">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="technology-diffusion-method">
      <value value="&quot;schwarz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="leader_w_social">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="main_w_social">
      <value value="0.45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hed_w_social">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="word-of-mouth?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deliberation_rate">
      <value value="0.031"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="policy">
      <value value="&quot;off&quot;"/>
      <value value="&quot;seed 10 percent&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seeding-percentage">
      <value value="2"/>
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
