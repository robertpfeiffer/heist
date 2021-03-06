; Basic test: no subpatterns or ellipses

(define-syntax while
  (syntax-rules ()
    [(while condition expression)
      (let loop ()
        (if condition
            (begin
              expression
              (loop))))]))

(define i 5)
(while (> i 0)
  (set! i (- i 1)))

(assert-equal 0 i)


; Test keywords

(define-syntax assign
  (syntax-rules (values to)
    [(assign values (value ...) to (name ...))
      (begin
        (define name value)
        ...)]))

(assign values (9 7 6) to (foo bar baz))
(assert-equal 9 foo)
(assert-equal 7 bar)
(assert-equal 6 baz)

(assert-raise SyntaxError (assign stuff (3 2) to (foo bar)))
(assert-equal 9 foo)
(assert-equal 7 bar)

(define-syntax dont-rename-else (syntax-rules ()
  [(foo test cons alt)
    (cond (test cons)
          (else alt))]))

(assert-equal 8 (dont-rename-else #f 6 8))


; Test scoping - example from R5RS

(assert-equal 'outer
  (let ((x 'outer))
    (let-syntax ((m (syntax-rules () [(m) x])))
      (let ((x 'inner))
        (m)))))


; Test literal matching

(define-syntax iffy
  (syntax-rules ()
    [(iffy x #t y) x]
    [(iffy x #f y) y]))

(assert-equal 7 (iffy 7 #t 3))
(assert-equal 3 (iffy 7 #f 3))


; Test input execution - example from R5RS

(define-syntax my-or
  (syntax-rules ()
    ((my-or) #f)
    ((my-or e) e)
    ((my-or e1 e2 ...)
     (let ((temp e1))
       (if temp
           temp
           (my-or e2 ...))))))

(define e 1)
(define (inc)
  (set! e (+ e 1))
  e)
(my-or (> 0 (inc))   ; false
       (> 0 (inc))   ; false
       (> 9 6)       ; true - should not evaluate further
       (> 0 (inc))
       (> 0 (inc)))

(assert-equal 3 e)


; Test ellipses

(define-syntax when
  (syntax-rules ()
    [(when test stmt1 stmt2 ...)
     (if test
         (begin stmt1
                stmt2 ...))]))

(assert-equal 'now
 (let ((if #t))
      (when if (set! if 'now))
      if))

(when true
  (set! i (+ i 1))
  (set! i (+ i 1))
  (set! i (+ i 1))
  (set! i (+ i 1)))

(assert-equal 4 i)


; Test that ellipses match ZERO or more inputs

(define-syntax one-or-more
  (syntax-rules ()
    [(one-or-more stmt1 stmt2 ...)
      (begin
        stmt1
        stmt2
        ...)]))

(assert-equal 6 (one-or-more (+ 2 4)))
(assert-equal 11 (one-or-more (+ 2 4) (+ 3 8)))
(assert-equal 13 (one-or-more (+ 2 4) (+ 3 8) (+ 7 6)))


; Test execution scope using (swap)
; Example from PLT docs

(define-syntax swap (syntax-rules ()
  [(swap x y)
    (let ([temp x])
      (set! x y)
      (set! y temp))]))

(define a 4)
(define b 7)
(swap a b)

(assert-equal 7 a)
(assert-equal 4 b)


; Test macro bound variable renaming

(let ([temp 5]
      [other 6])
  (swap temp other)
  (assert-equal 6 temp)
  (assert-equal 5 other))

(let ([set! 5]
      [other 6])
  (swap set! other)
  (assert-equal 6 set!)
  (assert-equal 5 other))


; More ellipsis tests from PLT docs

(define-syntax rotate
  (syntax-rules ()
    [(rotate a) a]
    [(rotate a b c ...) (begin
                          (swap a b)
                          (rotate b c ...))]))

(define a 1)  (define d 4)
(define b 2)  (define e 5)
(define c 3)
(rotate a b c d e)

(assert-equal 2 a)  (assert-equal 5 d)
(assert-equal 3 b)  (assert-equal 1 e)
(assert-equal 4 c)


; Check repeated macro use doesn't eat the parse tree
(letrec
  ([loop (lambda (count)
            (rotate a b c d e)
            (if (> count 1) (loop (- count 1))))])
  (loop 3))

(assert-equal 5 a)  (assert-equal 3 d)
(assert-equal 1 b)  (assert-equal 4 e)
(assert-equal 2 c)


; Test subpatterns

(define-syntax p-swap
  (syntax-rules ()
    [(swap (x y))
      (let ([temp x])
        (set! x y)
        (set! y temp))]))

(define m 3)
(define n 8)
(p-swap (m n))
(assert-equal 8 m)
(assert-equal 3 n)


(define-syntax parallel-set!
  (syntax-rules ()
    [(_ (symbol ...) (value ...))
      (begin
        (set! symbol value)
        ...)]))

(parallel-set! (a b c) (74 56 19))
(assert-equal 74 a)
(assert-equal 56 b)
(assert-equal 19 c)


; Test that ellipses are correctly matched
; to numbers of splices in subexpressions

(define-syntax p-let*
  (syntax-rules ()
    [(_ (name ...) (value ...) stmt ...)
      (let* ([name value] ...)
        stmt
        ...)]))

(define indicator #f)

(p-let* (k l m) (3 4 5)
  (assert-equal 5 m)
  (define temp m)
  (set! m (+ l k))
  (set! k (- l temp))
  (set! l (* 6 (+ k m)))
  (rotate k l m)
  (assert-equal 7 l)
  (assert-equal -1 m)
  (assert-equal 36 k)
  (set! indicator #t))

(assert indicator)


(define-syntax sum-lists
  (syntax-rules ()
    [(_ (value1 ...) (value2 ...))
      (+ value1 ... value2 ...)]))

(assert-equal 21 (sum-lists (1 2) (3 4 5 6)))
(assert-equal 21 (sum-lists (1 2 3 4 5) (6)))


(define-syntax do-this
  (syntax-rules (times)
    [(_ n times body ...)
      (letrec ([loop (lambda (count)
                        body ...
                        (if (> count 1)
                            (loop (- count 1))))])
        (loop n))]))

(define myvar 0)
(do-this 7 times
  (set! myvar (+ myvar 1)))
(assert-equal 7 myvar)


; Test that ellipsis expressions can be reused

(define-syntax weird-add
  (syntax-rules ()
    [(_ (name ...) (value ...))
      (let ([name value] ...)
        (+ name ...))]))

(assert-equal 15 (weird-add (a b c d e) (1 2 3 4 5)))

(define-syntax double-up
  (syntax-rules ()
    [(double-up value ...)
      '((value value) ...)]))

(assert-equal '((5 5)) (double-up 5))
(assert-equal '((3 3) (9 9) (2 2) (7 7)) (double-up 3 9 2 7))
(assert-equal '() (double-up))


; R5RS version of (let), uses ellipsis after lists in patterns

(define-syntax r5rs-let
  (syntax-rules ()
    ((let ((name val) ...) body1 body2 ...)
     ((lambda (name ...) body1 body2 ...)
      val ...))
    ((let tag ((name val) ...) body1 body2 ...)
     ((letrec ((tag (lambda (name ...)
                      body1 body2 ...)))
        tag)
      val ...))))

(define let-with-macro #f)

(r5rs-let ([x 45] [y 89])
  (assert-equal 45 x)
  (assert-equal 89 y)
  (set! let-with-macro #t))

(assert let-with-macro)


; Non-standard extension to R5RS, not quite R6RS
; Allow ellipses before the end of a list as long
; as, in the expression (A ... B), B is a less specific
; pattern than A
(define-syntax infix-ellip
  (syntax-rules ()
    [(_ (name value) ... fn)
      (let ([name value] ...)
        (fn name ...))]))

(assert-equal 24 (infix-ellip (a 1) (b 2) (c 3) (d 4) *))


; Test nested splicings

(define-syntax nest1
  (syntax-rules ()
    [(_ (value ...) ... name ...)
      '((name (value) ...) ...)]))

(assert-equal '((foo (1) (2)) (bar (3)) (baz) (whizz (4) (5) (6) (7)))
              (nest1 (1 2) (3) () (4 5 6 7) foo bar baz whizz))


(define-syntax triple-deep
  (syntax-rules ()
    [(_ (((name ...) ...) ...) ((value ...) ...) ...)
      '((((value (name)) ...) ...) ...)]))

(assert-equal '((((5 (foo)) (6 (bar))) ((2 (it)))) (((4 (wont))) ((8 (matter)) (7 (really)) (2 (anyway)))))
    (triple-deep (((foo bar) (it)) ((wont) (matter really anyway)))
                 ((5 6) (2)) ((4) (8 7 2))))

(define-syntax triple-deep2
  (syntax-rules ()
    [(_ (((name ...) ...) ...) ((value ...) ...) ...)
      '(((((value (name)) ...) ((value (name)) ...)) ...) ...)]))

(assert-equal '(((((5 (foo)) (6 (bar))) ((5 (foo)) (6 (bar)))))
               ((((4 (wont))) ((4 (wont))))
               (((8 (matter)) (7 (really)) (2 (anyway))) ((8 (matter)) (7 (really)) (2 (anyway))))))
    (triple-deep2 (((foo bar)) ((wont) (matter really anyway)))
                 ((5 6)) ((4) (8 7 2))))


; Really nasty nested repetition. PLT won't run this in its entirity
; due to overuse of infix ellipses, but comparison output for
; subsets of this macro can be seen in plt-macros.txt

(define-syntax convoluted
  (syntax-rules (with)
    [(_ (with (value ...) ...) ... thing ((name ...) ...) obj ...)
      '((obj ((value ...) (value value) ...) ... (obj obj)) ...
        (((name name) ... obj obj (obj (name ...))) ...))]))

(assert-equal '((foo ((a u) (a a) (u u)) ((j e n k l) (j j) (e e) (n n) (k k) (l l))
                     (()) ((q c y n) (q q) (c c) (y y) (n n)) (foo foo))
                (bar (bar bar))
                (baz ((b) (b b)) ((d f) (d d) (f f)) (baz baz))
                (what ((k l e) (k k) (l l) (e e)) ((s) (s s)) ((u n) (u u) (n n))
                      ((f i k w) (f f) (i i) (k k) (w w)) ((p) (p p)) (what what))
                      (((8 8) (3 3) (2 2) (9 9) foo foo (foo (8 3 2 9)))
                       ((2 2) (3 3) bar bar (bar (2 3)))
                       ((1 1) (0 0) (4 4) baz baz (baz (1 0 4)))
                       ((8 8) (3 3) (2 2) (1 1) (7 7) what what (what (8 3 2 1 7)))))
    (convoluted (with (a u) (j e n k l) () (q c y n)) (with)
                (with (b) (d f)) (with (k l e) (s) (u n) (f i k w) (p))
                thing ((8 3 2 9) (2 3) (1 0 4) (8 3 2 1 7))
                foo bar baz what))

(assert-raise MacroTemplateMismatch (convoluted (with (a)) (with (b)) thing () foo))
(assert-raise SyntaxError (convoluted nothing))

