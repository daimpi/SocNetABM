# UNDER CONSTRUCTION  

# SocNetABM
NetLogo iteration of Zollman's (2010) ABM with critical interaction.  



## HOW IT WORKS

Beliefs of the researchers are modeled via a beta distribution: The mean of the beta distribution is their current belief.  



## NETLOGO FEATURES

The binomial distribution is approximated by the normal distribution with the same mean and variance. This approximation is highly accurate for all parameter values from the interface.  
B/c the normal distribution is a continuous distribution the outcome is rounded and there is a safety check which constrains the distribution to the interval [0, pulls] to prevent negative- or higher than pulls numbers of successes.  

## Variables

Default-values have been set to mirror Zollman's (2010) model. The slider ranges are mostly set to mirror the ranges considered by Rosenstock et al. (2016) ( pulls correspond to `n` in Rosenstock et al.(2016)). The exceptions are:

  * The signal ranges have a larger interval
 

### Globals

#### th-i-signal

* type: float-list
* example: [0.5 0.499]  

The average objective probability of success (ops)for [theory-1 theory-2].
  
#### indiff-count

* type: integer
* example: 1003  

The sum of number of rounds each scientist was indifferent between the two theories.
  
#### crit-interactions-th1(2)

* type: integer
* example: 56  

The sum of critical interactions scientists on theory 1(2) encountered.

#### confidence-cutoff

* type: integer
* example: 0.9999  

The global-confidence `g-confidence` must be higher than this value for the run to be terminated.


#### converged-ticks

* type: integer
* example: 114  

The number of ticks which have passed since the researchers converged for the last time.

#### last-converged-th

* type: integer
* example: 0  

The theory the researchers converged on the last time they converged: 0 = th1, 1 = th2

#### max-ticks

* type: integer
* example: 10000  

The maximal number of rounds before a run is terminated by the exit condition.

#### converge-reporters

* type: anonymous reporters list
* example: [(anonymous reporter: [ average-belief 0 true ]) (anonymous reporter: [ average-cum-successes 0 true ]) (anonymous reporter: [ average-confidence true ]) (anonymous reporter: [ average-signal 0 true ])]  

Reporters which have to be collected in the round when researchers converge. The values for those reporters is then stored in the global `converge-reporters-values` and retrieved by BehaviourSpace at the end of the run.  

#### converge-reporters-values

* type: list
* example: [["avgbelief" 0.4997690253321044 0.49127250748536755] ["avgsuc" 110667.02991226684 21169.651936606337] ["avgconfidence" 0.7645093577413972] ["avgsignal" 0.5 0.499]]  
  
The values from the anonymous reporters in `converge-reporters`, recorded at the last time researchers converged.  

#### run-start-scientists-save

* type: integer-list
* example: [5 5]  

The number of scientists on [th1 th2] at the beginning of the run.  

#### rndseed

* format: integer
* example: -2147452934  

Stores the random-seed of the current run.  

#### g-confidence

* format: float
* example: 0.9993  

Global-confidence: the probability that not a single researcher will switch theories i.e. the probability that this convergence is final. Range: [0,1]  

#### g-depressed-confidence

* format: boolean
* example: false  

If there is a researcher for whom, if given sufficient time for her belief to converge to the average signal of her and her link-neighbors, this would this be enough to abandon her current theory, her confidence will always be zero and therefore `g-confidence` will also be zero. In this case `g-depressed-confidence` will be set to true in order to avoid redundant confidence calculations.  

#### g-fast-sharing-enabled

* format: boolean
* example: true  

When the network is a de facto complete network, scientists might be able to utilize a more performant sharing procedure (the second condition is that they have to be converged): `share-fast`. This variable signals whether or not such a de-facto complete network is present in the current run.  


### Turtles-own

#### cur-best-th
* type: integer-list
* example: [0 1] or [0]  

The theories the researcher currently considers best: 0 = theory 1, 1 = theory 2. Can be a singleton.  

#### current-theory-info

* type: float-list
* example: [0.44945 0.594994]  

Contains the researchers current evaluation of the two theories. Entry 1 is the evaluation for the first theory and entry 2 for second.  

#### mytheory

* type: integer
* example: 0  

The theory the researcher is currently working on i.e. the theory she pulls from: 0 = theory 1, 1 = theory 2

#### successes

* type: integer-list
* example: [512 0] or [0 483]  

The number of successes from her pulls this round: first entry successes for th1, 2nd: th2. One entry is always 0 b/c the researcher is pulling only from one theory at a time.

#### a

* type: float-list
* example [4501.309490 208.489044]  

The alpha of the researchers memory in the beta distribution, i.e. the accumulated number of successes (including the prior). The first entry is the alpha for theory 1 the 2nd for theory 2.

#### b 

* type: float-list
* example [9788.309490 500.489044]  

Each entry: the alpha + beta of the researchers memory in the beta distribution, i.e. the accumulated number of pulls (including the prior). The first entry is the pulls for theory 1 the 2nd for theory 2.

#### theory-jump

* type: integer
* example: 0  

How often the researcher considered jumping to another theory since the last jump.

#### times-jumped

* type: integer
* example: 42  

How often the researcher switched theories.

#### subj-th-i-signal

* type: float-list
* example: [0.5 0.499]  

The current objective probability of success (ops) the researcher has for [theory-1 theory-2].  

#### crit-interact-lock

* type: integer
* example: 3  

For how many more rounds the researcher is blocked from pursuing strategies (i.e. consider jumping / jump) b/c of critical interaction. 

#### confidence

* type: float
* example 1337.94038  

How confident the researcher is in the fact that her current best theory is actually the best theory (i.e. how unlikely it is that she will change her mind). Only calculated once all researchers have converged to one theory.  

#### avg-neighbor-signal

* type: float
* example: 0.499  

Only set once all researchers converged. This is the average signal the researcher and her link-neighbors currently observe for the theory they converged on.

#### share-group

* type: turtle-set
* example: (agentset, 3 turtles)  

Contains all the scientists this scientist will share information with, including herself. This exists for performance reasons and will be set during `setup`.


## CREDITS AND REFERENCES

The numerical approximation for the error function is taken from:  
Numerical Recipes in Fortran 77: The Art of Scientific Computing (ISBN 0-521-43064-X), 1992, page 214, Cambridge University Press.  
via WIKIPEDIA. (2017) URL: https://en.wikipedia.org/wiki/Error_function#Numerical_approximations. Accessed: 2017-04-06.  

Rosenstock, S., Bruner, J. P., & O'Connor, C. (2016). In Epistemic Networks, Is Less Really More?.  
Zollman, K. J. (2010). The epistemic benefit of transient diversity. Erkenntnis, 72(1), 17.