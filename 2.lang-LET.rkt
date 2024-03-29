#lang eopl

;language-LET : concrete & abstract syntax tree
;----------------------------------------------------
;concrete syntax tree:

;Program :: = Expression

;Expression :: = Number
;              | -(Expression, Expression)
;              | zero? (Expression)
;              | if Expression then Expression else Expression
;              | Identifer
;              | let Identifer = Expression in Expression


; abstract syntax tree
(define-datatype program program?
  (a-program (exp expression?)))

(define-datatype expression expression?
  (const-exp (num number?))
  (diff-exp (exp1 expression?)
            (exp2 expression?))
  (zero?-exp (exp expression?))
  (if-exp (exp1 expression?)
          (exp2 expression?)
          (exp3 expression?))
  (var-exp (exp symbol?))
  (let-exp (var symbol?)
           (exp expression?)
           (body expression?)))


; scan&parse
;----------------------------------------------------
(define scanner-spec
  '((whitespace (whitespace) skip)
    (comment (";" (arbno (not #\newline))) skip)
    (identifer (letter (arbno (or letter digit "-" "_" "?"))) symbol)
    (number (digit (arbno digit)) number)
    (number ("-" digit (arbno digit)) number)))
;   (class (regexp) action)
; string (keyword) from parser-spec (eg: "-","if","let","=",...) has a higher priority than regexp in scanner-spec.


(define parser-spec
 '((program (expression) a-program)
   (expression (number) const-exp)
   (expression ("-" "(" expression "," expression ")") diff-exp)
   (expression ("zero?" "(" expression ")") zero?-exp)
   (expression ("if" expression "then" expression "else" expression) if-exp)
   (expression (identifer) var-exp)
   (expression ("let" identifer "=" expression "in" expression) let-exp)))
;  (algebric-data-type (concrete-syntax-with-class/string/ADT) constructor)
; class/string : terminator
; ADT : nonterminator


; scan&parse : string -> program
(define scan&parse
  (sllgen:make-string-parser scanner-spec parser-spec))


; expressed valus <-> denoted value
;----------------------------------------------------
(define-datatype expval expval?
  (num-val (num number?))
  (bool-val (bool boolean?)))


(define expval->num
  (lambda (val)
    (cases expval val
      (num-val (num) num)
      (else (eopl:error "expval extract error in expval->num: ~s" val)))))

(define expval->bool
  (lambda (val)
    (cases expval val
      (bool-val (bool) bool)
      (else (eopl:error "expval extract error in expval->bool: ~s" val)))))


; environment
;----------------------------------------------------
(define-datatype env env?
  (empty-env)
  (extend-env (var symbol?)
              (val expval?) ; !!! env store expression value instead of denoted value
              (e env?)))

; init-env
(define init-env
  (extend-env
   'i (num-val 1)
   (extend-env
    'v (num-val 5)
    (extend-env
     'x (num-val 10)
     (empty-env)))))


; apply-env : symbol -> expval
(define apply-env
  (lambda (var en)
    (cases env en
      (empty-env () (eopl:error "Unbound variable : ~s" var))
      (extend-env (v val e)
                  (if (equal? v var)
                      val
                      (apply-env var e))))))


; eval
;----------------------------------------------------

; value-of : Exp * Env -> ExpVal
(define value-of
  (lambda (exp env)
    (cases expression exp
      (const-exp (num) (num-val num))
      (var-exp (var) (apply-env var env))
      (diff-exp (exp1 exp2) (num-val
                             (- (expval->num (value-of exp1 env))
                                (expval->num (value-of exp2 env)))))
      (zero?-exp (exp)
                 (let ((val (expval->num (value-of exp env))))
                   (if (= val 0)
                       (bool-val #t)
                       (bool-val #f))))
      (if-exp (exp1 exp2 exp3)
              (let ((condi (expval->bool (value-of exp1 env))))
                (if condi
                    (value-of exp2 env)
                    (value-of exp3 env))))
      (let-exp (var exp body) (value-of body
                                        (extend-env var
                                                    (value-of exp env)
                                                    env))))))


; value-of-program : Program -> Expval
(define value-of-program
  (lambda (pgm)
    (cases program pgm
      (a-program (exp) (value-of exp init-env)))))


; run : String -> Expval
(define run
  (lambda (str)
    (value-of-program (scan&parse str))))



; test
;----------------------------------------------------
;> (run "-(2,5)")
;  #(struct:num-val -3)

;> (run "let x = 3 in -(x,1)")
;  #(struct:num-val 2)

;> (run "let x = 3 in let y = 2 in -(x,y)")
;  #(struct:num-val 1)

;> (run "let x = 3 in let y = 2 in -(y,x)")
;  #(struct:num-val -1)
