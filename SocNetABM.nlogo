turtles-own [a b theory-jump times-jumped cur-best-th current-theory-info
  mytheory successes subj-th-i-signal crit-interact-lock confidence]

globals [th-i-signal indiff-count crit-interactions-th1 crit-interactions-th2
  confidence-cutoff converged-ticks last-converged-th max-confidence min-ticks
  max-ticks converge-reporters converge-reporters-values]

__includes ["protocol.nls"]



to setup
  clear-all
  init-hidden-variables
  init-converge-reporters
  set th-i-signal list th1-signal th2-signal
  set-default-shape turtles "person"
  create-turtles scientists [
    let a1 init-ab
    let b1 init-ab
    let a2 init-ab
    let b2 init-ab
    set a list a1 a2
    set b (list (a1 + b1) (a2 + b2))
    set current-theory-info [0 0]
    calc-posterior
    compute-strategies
    set mytheory one-of cur-best-th
    set-researcher-colors
    set subj-th-i-signal th-i-signal
  ]
  create-network
  reset-ticks
end





to go
  ask turtles [
    pull
    integrate-own-pull-info
    if critical-interaction [
      calc-posterior
    ]
  ]
  ask turtles [
    share
    calc-posterior
    compute-strategies
    if crit-interact-lock > 0 [
      set crit-interact-lock crit-interact-lock - 1
    ]
  ]
  ask turtles with [crit-interact-lock = 0
    and not member? mytheory cur-best-th] [
    act-on-strategies
  ]
  tick
end





; runs until the exit-condition is met
to go-stop
  while [not exit-condition][
    go
  ]
end





; initializes the hidden variables which (= not set in the interface)
to init-hidden-variables
  set confidence-cutoff 100
  set max-confidence 10000
  set min-ticks 10
  set max-ticks 10000
end





to init-converge-reporters
  set converge-reporters (list [ -> average-belief 0 true]
  [ -> average-cum-successes 0 true] [ -> average-confidence true])
end





to-report init-ab
  ; this formulation prevents drawing values of zero. It reports
  ; a random-float from the intervall (0 , max-prior]
  report (max-prior - random-float max-prior)
end





to create-network
  if network-structure = "cycle" [
    let turtle-list sort turtles
    create-network-cycle turtle-list
  ]
  if network-structure = "complete" [
    create-network-complete
  ]
  if network-structure = "wheel" [
    create-network-wheel
  ]
end





; not performance optimized
to create-network-complete
  ask turtles [ create-links-with other turtles ]
  layout-circle turtles (world-width / 2 - 1)
end





to create-network-cycle [turtle-list]
  let previous-turtle 0
    foreach turtle-list [ [cur-turtle] ->
      ask cur-turtle [
        ifelse previous-turtle != 0 [
          create-link-with previous-turtle
          set previous-turtle self
        ][
          create-link-with last turtle-list
          set previous-turtle self
        ]
      ]
    ]
  layout-circle turtle-list (world-width / 2 - 1)
end





to create-network-wheel
  ; first the cycle is created...
  let turtle-list sort turtles
  create-network-cycle but-first turtle-list
  ; and then the royal family connects to all other scientists
  ask first turtle-list [
    setxy 0 0
    create-links-with other turtles
  ]
end





; The binominal distribution is approximated by the normal distribution with
; the same mean and variance. This approximation is highly accurate for all
; parameter values from the interface.
; B/c the normal distribution is a continuous distribution the outcome is
; rounded and there is a safety check which costrains the distribution to the
; intervall [0, pulls] to prevent negative- or higher than pulls numbers of
; successes
to pull
  let mysignal item mytheory subj-th-i-signal
  set successes [0 0]
  let successes-normal round random-normal
  (pulls * mysignal) sqrt (pulls * mysignal * (1 - mysignal) )
  ifelse successes-normal > 0 and successes-normal <= pulls [
    set successes replace-item mytheory successes successes-normal
  ][
    if successes-normal > pulls [
      set successes replace-item mytheory successes pulls
    ]
  ]
end





; The information the scientist has obtained via her own pulls is integrated into her memory
to integrate-own-pull-info
  set a (map + a successes)
  set b replace-item mytheory b (item mytheory b + pulls)
end





; for high number of scientists in complete networks this should be optimized, but first integrate the critical interaction
to share
  let cur-turtle self
  ; first entry is th1 2nd is th2
  let successvec 0
  let pullcounter 0
  let pulls-th1 list pulls 0
  let pulls-th2 list 0 pulls
  let neighbor-theory 0
  ask link-neighbors [
    set successvec successes
    ifelse mytheory = 0 [
      set pullcounter pulls-th1
    ][
      set neighbor-theory 1
      set pullcounter pulls-th2
    ]
    ask cur-turtle [
      set a (map + a successvec)
      set b (map + b pullcounter)
      if critical-interaction and mytheory != neighbor-theory [
        evaluate-critically
      ]
    ]
  ]
end





to evaluate-critically
  let old-theory-info current-theory-info
  calc-posterior
  let diff-theory-info (map - current-theory-info old-theory-info)
  ifelse mytheory = 0 [
    if item 0 diff-theory-info < 0 or item 1 diff-theory-info > 0 [
      set crit-interactions-th1 crit-interactions-th1 + 1
      if crit-interact-lock = 0 [
        set crit-interact-lock crit-jump-threshold
      ]
      let old-th-1-signal item 0 subj-th-i-signal
      set subj-th-i-signal replace-item 0 subj-th-i-signal (old-th-1-signal
        + (1 - old-th-1-signal) * crit-strength)
    ]
  ][
    if item 0 diff-theory-info > 0 or item 1 diff-theory-info < 0 [
      if crit-interact-lock = 0 [
        set crit-interact-lock crit-jump-threshold
      ]
      set crit-interactions-th2 crit-interactions-th2 + 1
      let old-th-2-signal item 1 subj-th-i-signal
      set subj-th-i-signal replace-item 1 subj-th-i-signal (old-th-2-signal
        + (0 - old-th-2-signal) * crit-strength)
    ]
  ]
end





to calc-posterior
  set current-theory-info (map / a b)
end





to compute-strategies
  ; format: list example: [0]
  let max-score max current-theory-info
  let best-th-position position max-score current-theory-info
  ; set cur-best-th (list best-th-position)
  ; if the other entry is in the intervall for best theories it is also added
  let other-score item ((best-th-position + 1) mod 2) current-theory-info
  ifelse other-score >= max-score * strategy-threshold [
    set cur-best-th [0 1]
    set indiff-count indiff-count + 1
  ][
    set cur-best-th (list best-th-position)
  ]
end





to act-on-strategies
  set theory-jump theory-jump + 1
  if theory-jump = jump-threshold [
    ; set mytheory to the other theory
    set mytheory ((mytheory + 1) mod 2)
    set-researcher-colors
    set times-jumped times-jumped + 1
    set theory-jump 0
  ]
end





to set-researcher-colors
  ifelse mytheory = 0 [
    set color red
  ][
    set color turquoise
  ]
end





; this procedure makes only sense in case scientist have converged
to calc-confidence
  let worst-signal [item mytheory subj-th-i-signal] of min-one-of turtles [
    item mytheory subj-th-i-signal]
  ; experimental results for worst signal yielding mean - 1 standard deviation
  let experiment-floor floor (worst-signal * pulls - sqrt (pulls * worst-signal
    * (1 - worst-signal)))
  if experiment-floor < 0 [set experiment-floor 0]
  if experiment-floor > pulls [set experiment-floor pulls]
  ask turtles [
    let belief-to-beat item ((mytheory + 1) mod 2) current-theory-info
      * strategy-threshold
    ; if the scientist would be given sufficient time for her belief to
    ; converge to the average signal of her and her link-neighbors, would
    ; this be enough for her to abandon her current theory? If so, she's not
    ; confident enough.
    if worst-signal < belief-to-beat [
      let avg-neighbor-signal subj-th-i-signal
      ask link-neighbors [
        set avg-neighbor-signal (map + avg-neighbor-signal subj-th-i-signal)
      ]
      let my-cluster-size (count link-neighbors + 1)
      set avg-neighbor-signal map [avg-neigh-signal-th-i ->
        avg-neigh-signal-th-i / my-cluster-size] avg-neighbor-signal
      if item mytheory avg-neighbor-signal < belief-to-beat [
        set confidence 0
        stop
      ]
    ]
    ifelse (experiment-floor / pulls < belief-to-beat) [
      set confidence ((belief-to-beat * item mytheory b - item mytheory a)
        / (experiment-floor - belief-to-beat * pulls))
      if confidence > max-confidence [
        set confidence max-confidence
      ]
    ][
      set confidence max-confidence
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

SLIDER
13
160
185
193
th1-signal
th1-signal
0.1
0.9
0.5
0.001
1
NIL
HORIZONTAL

SLIDER
14
206
186
239
th2-signal
th2-signal
0.1
0.9
0.499
0.001
1
NIL
HORIZONTAL

SLIDER
14
255
186
288
pulls
pulls
100
6000
1000.0
100
1
NIL
HORIZONTAL

SLIDER
13
308
185
341
max-prior
max-prior
1
10000
4.0
1
1
NIL
HORIZONTAL

SLIDER
14
355
186
388
jump-threshold
jump-threshold
1
1000
1.0
1
1
NIL
HORIZONTAL

SLIDER
15
116
187
149
scientists
scientists
3
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
13
399
185
432
strategy-threshold
strategy-threshold
0
1
1.0
0.01
1
NIL
HORIZONTAL

BUTTON
21
14
84
47
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

BUTTON
101
15
164
48
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

CHOOSER
13
444
151
489
network-structure
network-structure
"cycle" "wheel" "complete"
0

PLOT
663
12
863
162
Popularity
Time steps
scientists
0.0
100.0
0.0
10.0
true
false
"" ""
PENS
"best theory" 1.0 0 -2674135 true "" "plot count turtles with [mytheory = 0]"
"not-best-theory" 1.0 0 -14835848 true "" "plot count turtles with [mytheory = 1]"

SWITCH
13
500
167
533
critical-interaction
critical-interaction
1
1
-1000

SLIDER
13
548
185
581
crit-strength
crit-strength
1 / 10000
1 / 10
0.001
1 / 10000
1
NIL
HORIZONTAL

SLIDER
14
592
198
625
crit-jump-threshold
crit-jump-threshold
1
1000
1.0
1
1
NIL
HORIZONTAL

BUTTON
50
64
124
97
NIL
go-stop
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)
### Variables

Turtles-own

  * current-theory-info
    * type: list
    * example: [0.44945 0.594994]
Contains the researchers current evaluation of the two theories. Entry 1 is the evaluation for the first theory and entry 2 for second.

  * mytheory
    * type: integer
    The theory the researcher is currently working on i.e. the theory she pulled this round from: 0 = theory1, 1 = theory 2
    
  * successes
    * type: float
    * The number of successes from her pulls this round
    
  * a
    * type: list
    * example [4501.309490 208.489044]
    The alpha of the researchers memory in the beta distribution, i.e. the accumulated number of successes. The first entry is the alpha for theory 1 the 2nd for theory 2.
    
  * b 
    * type: list
    * example [9788.309490 500.489044]
    The alpha + beta of the researchers memory in the beta distribution, i.e. the accumulated number of pulls/tries. The first entry is the pulls for theory 1 the 2nd for theory 2.
    

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

Default-values have been set to mirror zollmans (2010) model. The ranges for the values are mostly set to mirror the ranges by x (2015). The exceptions are:

  * The signal ranges which have a larger intervall
  * The pulls range which doesn't start at 1 but at 100 because of the normal distribution potentially not being that good for low pulls. ( pulls = n in (x 2015))

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

Fully connected Network Example

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
Circle -16777216 true false 30 30 240

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
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="zm-base-run" repetitions="10000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>exit-condition</exitCondition>
    <metric>successful-run</metric>
    <metric>average-jumps</metric>
    <metric>avg-indiff-time</metric>
    <metric>run-end-scientists "th1"</metric>
    <metric>run-end-scientists "th2"</metric>
    <metric>crit-interactions-th1</metric>
    <metric>crit-interactions-th2</metric>
    <metric>round-converged</metric>
    <metric>average-belief "th1" false</metric>
    <metric>average-belief "th2" false</metric>
    <metric>average-cum-successes "th1" false</metric>
    <metric>average-cum-successes "th2" false</metric>
    <metric>average-confidence false</metric>
    <steppedValueSet variable="scientists" first="3" step="1" last="11"/>
    <enumeratedValueSet variable="th1-signal">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="th2-signal">
      <value value="0.499"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pulls">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="jump-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-structure">
      <value value="&quot;cycle&quot;"/>
      <value value="&quot;wheel&quot;"/>
      <value value="&quot;complete&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-prior">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="critical-interaction">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="crit-strength">
      <value value="0.001"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="crit-interact-lock-default">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="crit-interact-base-run" repetitions="10000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>exit-condition</exitCondition>
    <metric>successful-run</metric>
    <metric>average-jumps</metric>
    <metric>avg-indiff-time</metric>
    <metric>run-end-scientists "th1"</metric>
    <metric>run-end-scientists "th2"</metric>
    <metric>crit-interactions-th1</metric>
    <metric>crit-interactions-th2</metric>
    <metric>round-converged</metric>
    <metric>average-signal "th1"</metric>
    <metric>average-signal "th2"</metric>
    <metric>average-belief "th1" false</metric>
    <metric>average-belief "th2" false</metric>
    <metric>average-cum-successes "th1" false</metric>
    <metric>average-cum-successes "th2" false</metric>
    <metric>average-confidence false</metric>
    <steppedValueSet variable="scientists" first="3" step="1" last="11"/>
    <enumeratedValueSet variable="th1-signal">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="th2-signal">
      <value value="0.499"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pulls">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="jump-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-structure">
      <value value="&quot;cycle&quot;"/>
      <value value="&quot;wheel&quot;"/>
      <value value="&quot;complete&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-prior">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="critical-interaction">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="crit-strength">
      <value value="0.001"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="crit-interact-lock-default">
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
