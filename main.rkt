#lang racket

; A DSL for working with timesheets.
; includes functionality for tracking worked hours and payments.

(module+ test (require rackunit))
(provide
 (contract-out
  ; timesheet interface

  ; files

  ; load a timesheet from a file
  [load-timesheet! (-> path-string? void?)]
  ; save the current timesheet to a file
  [save-timesheet! (-> path-string? void?)]
  ; like (home-path "foo.txt") for "~/foo.txt"
  [home-path (-> string? path?)]

  ; timesheet operations

  ; create an empty timesheet with an optional hourly rate
  [create-timesheet! (->* () (#:rate real?) void?)]
  ; undo last edit
  [undo! (-> void?)]
  ; redo last edit
  [redo! (-> void?)]
  ; clock in at that time, with optional description and hourly rate (defaults to timesheet hourly rate)
  [clock-in! (->* (date?) (string? #:rate real?) void?)]
  ; clock out at that time, with optional description and hourly rate (defaults to timesheet hourly rate)
  [clock-out! (->* (date?) (string? #:rate real?) void?)]
  ; add a duration of work with no start or end, with optional description and hourly rate (defaults to timesheet hourly rate).
  ; recommended to use date utilities like (today) which clear the date's time.
  ; time is in seconds. recommended to use time utilities like (hours 2)
  [add-period! (->* (date? natural?) (string? #:rate real?) void?)]
  ; set the current hourly rate for work
  [set-hourly-rate! (-> real? void?)]
  ; add a payment in dollars with optional description.
  [add-payment! (->* (date? real?) (string?) void?)]
  ; how many hours in between the two dates
  [hours-between (-> date? date? number?)]
  ; total hours in the whole timesheet
  [total-hours (-> real?)]
  ; the amount of hours of work you haven't been paid for yet
  [unpaid-hours (-> real?)]
  ; the amount of money you are owed for your work
  [money-owed (-> real?)]
  ; the total amount of money you've been paid. does not include money owed but not yet paid.
  [money-earned (-> real?)]
  ; prints the timesheet out
  [print-timesheet (-> void?)]

  ; date/time utilities

  ; the current date
  [now (-> date?)]
  ; (seconds n) gives the number of seconds in n seconds (identity function)
  [seconds (-> natural? natural?)]
  ; (minutes n) gives the number of seconds in n minutes
  [minutes (-> natural? natural?)]
  ; (minutes n) gives the number of seconds in n hours
  [hours (-> natural? natural?)]
  ; cleared time
  [days-ago (-> natural? date?)]
  ; (time-ago n) is n seconds ago
  [time-ago (-> natural? date?)]
  ; cleared time (time set to midnight)
  [today (-> date?)]
  ; cleared time
  [yesterday (-> date?)]
  ; cleared time
  [tomorrow (-> date?)]
  ; subtracts seconds from date
  [-/date (-> date? natural? date?)]
  ; adds seconds to date
  [+/date (-> date? natural? date?)]))
(require racket/date
         racket/serialize
         racket/pretty)

; data definitions

; a Timesheet is a
(struct timesheet [intervals periods payments rate clock-in] #:prefab)
; intervals is a (listof Interval)
; periods is a (listof Period)
; payments is a (listof Payment)
; rate is a number? representing $/hr for work.
; clockin is a (or/c #f Event)

; an Interval is a
(struct interval [start end] #:prefab)
; start and end are Events

; an Event is a
(struct event [date description rate] #:prefab)
; date is a date?
; description is a (or/c #f string?)
; rate is a number? in $/hr

; a Period is a
(struct period [date duration description rate] #:prefab)
; date is a date?. the time is not necessarily accurate
; duration is an integer representing seconds
; description is a (or/c #f string?)
; rate is a number? in $/hr

; A Payment is a
(struct payment [date description amount] #:prefab)
; date is a date? the time is not necessarily accurate
; description is a (or/c #f string?)
; amount is a number? in $

; timesheet operations

(define empty-timesheet (timesheet (list) (list) (list) 0 #f))

; Timesheet date? (or/c #f string?) -> Timesheet
(define (timesheet-do-clock-in sheet dat [description #f] #:rate [rate #f])
  (when (timesheet-clock-in sheet)
    (raise-user-error "already clocked in"))
  (struct-copy timesheet sheet [clock-in (event dat description (or rate (timesheet-rate sheet)))]))

(module+ test
  (test-case "clock-in"
    (define dat (current-date))
    (check-equal? (timesheet-do-clock-in empty-timesheet dat "working")
                  (timesheet (list) (list) (list) 0 (event dat "working" 0)))
    (check-exn
     #rx"already clocked in"
     (lambda ()
       (timesheet-do-clock-in (timesheet (list) (list) (list) 0 (event dat #f 0)) dat)))))

; Timesheet date? (or/c #f string?) -> Timesheet
(define (timesheet-do-clock-out sheet dat [description #f] #:rate [rate #f])
  (unless (timesheet-clock-in sheet)
    (raise-user-error "not clocked in"))
  (struct-copy timesheet sheet
               [clock-in #f]
               [intervals (cons (interval (timesheet-clock-in sheet) (event dat description (or rate (timesheet-rate sheet))))
                                (timesheet-intervals sheet))]))

(module+ test
  (test-case "clock-out"
    (define dat1 (current-date))
    (define dat2 (current-date))
    (define clocked-in (timesheet-do-clock-in empty-timesheet dat1 "working"))
    (define clocked-out (timesheet-do-clock-out clocked-in dat2))
    (check-equal? (timesheet-intervals clocked-out) (list (interval (event dat1 "working" 0) (event dat2 #f 0))))
    (check-equal? (timesheet-clock-in clocked-out) #f)))

; Timesheet date? natural? (or/c #f string/) -> Timesheet
; duration in seconds
(define (timesheet-add-period sheet dat duration [description #f] #:rate [rate #f])
  (struct-copy timesheet sheet
               [periods (cons (period dat duration description (or rate (timesheet-rate sheet)))
                              (timesheet-periods sheet))]))

(define SECONDS_PER_HOUR (* 60 60))

; Timesheet date? date? -> number?
(define (timesheet-hours-between sheet start end)
  (timesheet-total-hours (timesheet-select-between sheet start end)))

; Timesheet -> natural?
; excludes time related to clockin
(define (timesheet-total-hours sheet)
  (seconds->hours
   (+ (for/sum ([int (timesheet-intervals sheet)])
        (match int
          [(interval (event start _ _) (event end _ _))
           (- (date->seconds end)
              (date->seconds start))]))
      (for/sum ([prd (timesheet-periods sheet)])
        (period-duration prd)))))

; Timesheet date? date? -> Timesheet
; selects intervals and periods that are fully contained between start and end.
; range is inclusive.
; erases clockin.
(define (timesheet-select-between sheet start end)
  (match sheet
    [(timesheet ints prds payments rate _)
     (define ints^
       (filter (lambda (int)
                 (and (date<=? start (event-date (interval-start int)))
                      (date<=? (event-date (interval-end int)) end)))
               ints))
     (define prds^
       (filter (lambda (prd)
                 (and (date<=? start (period-date prd))
                      (date<=? (period-date prd) end)))
               prds))
     (define payments^
       (filter (lambda (pmt)
                 (and (date<=? start (payment-date pmt))
                      (date<=? (payment-date pmt) end)))
               payments))
     (timesheet ints^ prds^ payments^ rate #f)]))

; date? date? -> boolean?
(define (date<=? d1 d2)
  (<= (date->seconds d1)
      (date->seconds d2)))

(define (timesheet-unpaid-hours sheet)
  (/ (timesheet-money-owed sheet) (timesheet-rate sheet)))

(module+ test
  (let ([now (now)])
    (check-equal? (timesheet-unpaid-hours (timesheet (list (interval (event now "" 10) (event (+/date now (hours 2)) "" 40)))
                                                     (list (period (today) (hours 3) "" 50))
                                                     ; should be ignored
                                                     (list (payment (yesterday) "" 50) (payment (today) "" 100))
                                                     ; should be ignored
                                                     23
                                                     ; should be ignored
                                                     (event (today) "" 70)))
                  (/ (- (+ (* 2 40)
                           (* 3 50))
                        (+ 100 50))
                     23))))

(define (timesheet-money-owed sheet)
  (- (timesheet-total-work-value sheet) (timesheet-money-earned sheet)))

(module+ test
  (let ([now (now)])
    (check-equal? (timesheet-money-owed (timesheet (list (interval (event now "" 10) (event (+/date now (hours 2)) "" 40)))
                                                   (list (period (today) (hours 3) "" 50))
                                                   ; should be ignored
                                                   (list (payment (yesterday) "" 50) (payment (today) "" 100))
                                                   ; should be ignored
                                                   60
                                                   ; should be ignored
                                                   (event (today) "" 70)))
                  (- (+ (* 2 40)
                        (* 3 50))
                     (+ 100 50)))))

; sum of all work * hours. ignores payment.
(define (timesheet-total-work-value sheet)
  (+ (for/sum ([int (timesheet-intervals sheet)])
       ; use the end event's rate since it's probably more up to date if different
       (define $/hr (event-rate (interval-end int)))
       (define hours (seconds->hours (interval-duration int)))
       (* $/hr hours))
     (for/sum ([prd (timesheet-periods sheet)])
       (define $/hr (period-rate prd))
       (define hours (seconds->hours (period-duration prd)))
       (* $/hr hours))))

(module+ test
  (let ([now (now)])
    (check-equal? (timesheet-total-work-value (timesheet (list (interval (event now "" 10) (event (+/date now (hours 2)) "" 40)))
                                                         (list (period (today) (hours 3) "" 50))
                                                         ; should be ignored
                                                         (list (payment (today) "" 1000))
                                                         ; should be ignored
                                                         60
                                                         ; should be ignored
                                                         (event (today) "" 70)))
                  (+ (* 2 40)
                     (* 3 50)))))

(define (timesheet-money-earned sheet)
  (for/sum ([pmt (timesheet-payments sheet)])
    (payment-amount pmt)))

(module+ test
  (check-equal? (timesheet-money-earned (timesheet (list) (list) (list (payment (now) "" 20) (payment (now) "" 30)) 30 #f))
                50))

(define (seconds->hours seconds) (/ seconds SECONDS_PER_HOUR))

(module+ test
  (check-equal? (seconds->hours 3600) 1)
  (check-equal? (seconds->hours 7200) 2))

; in seconds
(define (interval-duration int)
  (- (date->seconds (event-date (interval-end int)))
     (date->seconds (event-date (interval-start int)))))

(module+ test
  (check-equal? (interval-duration (interval (event (seconds->date 1000) "" 0) (event (seconds->date 3000) "" 0)))
                2000))

(define (timesheet-set-hourly-rate sheet rate)
  (struct-copy timesheet sheet [rate rate]))

(define (timesheet-add-payment sheet dat amt [desc #f])
  (struct-copy timesheet sheet [payments (cons (payment dat desc amt) (timesheet-payments sheet))]))

; date utilities

(define (now) (current-date))
(define (seconds n) n)
(define (minutes n) (* n 60))
(define (hours n) (* n 60 60))
(define SECONDS_PER_DAY (* SECONDS_PER_HOUR 24))
; with time cleared
(define (days-ago n) (-/date (today) (* n SECONDS_PER_DAY)))
(define (time-ago seconds) (-/date (now) seconds))
; with time cleared
(define (today) (clear-time (now)))
; with time cleared
(define (yesterday) (days-ago 1))
(define (tomorrow) (days-ago -1))
; sets seconds, minutes, hours to zero
(define (clear-time d) (struct-copy date (now) [second 0] [minute 0] [hour 0]))
(define (-/date dat change-in-seconds) (+/date dat (- change-in-seconds)))
(define (+/date dat change-in-seconds)
  (seconds->date (+ (date->seconds dat) change-in-seconds)))
(define (mdy month day year) (seconds->date (find-seconds 0 0 0 day month year)))

; user timesheet operations

(define current-timesheet (make-parameter #f))
; most recent first. in other words, undo gives the first
(define previous-timesheets (make-parameter '()))
; next first. in other words, redo gives the first.
(define next-timesheets (make-parameter '()))
; undo/redo via a zipper

(define (assert-current-timesheet!)
  (unless (current-timesheet)
    (raise-user-error "no timesheet active!")))
(define (create-timesheet! #:rate [rate #f])
  (unless rate
    (warn "created a timesheet without an hourly rate. assuming this work will be unpaid. otherwise, use set-hourly-rate!"))
  (current-timesheet (timesheet-set-hourly-rate empty-timesheet (or rate 0))))

(define (warn str)
  (displayln str (current-error-port)))

; files

(define (load-timesheet! path)
  ; TODO dynamic wind to definitely close port, or use with-input-from-file
  (define prt (open-input-file path))
  (read-timesheet! prt)
  (close-input-port prt))
(define (read-timesheet! prt)
  (with-edit (current-timesheet (deserialize (read prt)))))
(define (save-timesheet! path)
  ; TODO dynamic wind to definitely close port, or use with-output-from-file
  (define prt (open-output-file path #:exists 'replace))
  (write-timesheet! prt)
  (close-output-port prt))
(define (write-timesheet! prt)
  (assert-current-timesheet!)
  (writeln (serialize (current-timesheet)) prt))
; like (home-path "Documents/file.txt")
(define (home-path str)
  (build-path (find-system-path 'home-dir) str))

(module+ test
  (test-case "serialization round trip"
    (define sheet (timesheet-total-work-value (timesheet (list (interval (event (now) "" 10) (event (+/date (now) (hours 2)) "" 40)))
                                                         (list (period (today) (hours 3) "" 50))
                                                         ; should be ignored
                                                         (list (payment (today) "" 1000))
                                                         ; should be ignored
                                                         60
                                                         ; should be ignored
                                                         (event (today) "" 70))))
    (current-timesheet sheet)
    (define-values (in out) (make-pipe))
    (write-timesheet! out)
    (read-timesheet! in)
    (check-equal? (current-timesheet) sheet)))

; parameterized operations

(define-syntax-rule (with-edit body ...)
  (wrap-edit (lambda () body ...)))
(define (wrap-edit thnk)
  (dynamic-wind (lambda () (save-current!))
                thnk
                (lambda () (void))))

; undo/redo

; TODO make this a context handler to handle modification failure.
; adds the current timesheet to the previous timesheets
; empties the next timesheets
(define (save-current!)
  (assert-current-timesheet!)
  (previous-timesheets (cons (current-timesheet) (previous-timesheets)))
  (next-timesheets '()))
(define (undo!)
  (assert-current-timesheet!)
  (when (null? (previous-timesheets))
    (raise-user-error "no undo history"))
  (define curr (current-timesheet))
  (define prev (first (previous-timesheets)))
  (previous-timesheets (rest (previous-timesheets)))
  (current-timesheet prev)
  (next-timesheets (cons curr (next-timesheets))))
(define (redo!)
  (assert-current-timesheet!)
  (when (null? (next-timesheets))
    (raise-user-error "no redo history"))
  (define curr (current-timesheet))
  (define next (first (next-timesheets)))
  (next-timesheets (rest (next-timesheets)))
  (current-timesheet next)
  (previous-timesheets (cons curr (previous-timesheets))))

(define (clock-in! dat [description #f] #:rate [rate #f])
  (assert-current-timesheet!)
  (with-edit
    (current-timesheet (timesheet-do-clock-in (current-timesheet) dat description #:rate rate))))

(define (clock-out! dat [description #f] #:rate [rate #f])
  (assert-current-timesheet!)
  (with-edit
    (current-timesheet (timesheet-do-clock-out (current-timesheet) dat description #:rate rate))))

(define (add-period! dat duration [description #f] #:rate [rate #f])
  (assert-current-timesheet!)
  (with-edit
    (current-timesheet (timesheet-add-period (current-timesheet) dat duration description #:rate rate))))

(define (set-hourly-rate! rate)
  (assert-current-timesheet!)
  (with-edit
    (current-timesheet (timesheet-set-hourly-rate (current-timesheet) rate))))

(define (add-payment! dat amt [desc #f])
  (assert-current-timesheet!)
  (with-edit
    (current-timesheet (timesheet-add-payment (current-timesheet) dat amt desc))))

(define (hours-between start end)
  (assert-current-timesheet!)
  (round-to-tenth (timesheet-hours-between (current-timesheet) start end)))

(define (total-hours)
  (assert-current-timesheet!)
  (timesheet-total-hours (current-timesheet)))

(define (unpaid-hours)
  (assert-current-timesheet!)
  (timesheet-unpaid-hours (current-timesheet)))

(define (money-owed)
  (assert-current-timesheet!)
  (timesheet-money-owed (current-timesheet)))

(define (money-earned)
  (assert-current-timesheet!)
  (timesheet-money-earned (current-timesheet)))

(define (print-timesheet)
  (pretty-print (timesheet->datum (current-timesheet))))

(define (timesheet->datum sheet)
  `(timesheet
    (clock-in ,@(if (timesheet-clock-in sheet)
                    (match (timesheet-clock-in sheet)
                      [(event dat desc rate)
                       `(,(date->string dat #t) ,desc ,(rate->datum rate))])
                    '(#f)))
    (hourly-rate ,(rate->datum (timesheet-rate sheet)))
    (intervals
     ,@(for/list ([int (timesheet-intervals sheet)])
         (match int
           [(interval (event start desc-start rate-start) (event end desc-end rate-end))
            `(interval [start ,(date->string start #t) ,desc-start ,(rate->datum rate-start)] [end ,(date->string end #t) ,desc-end ,(rate->datum rate-end)])])))
    (periods
     ,@(for/list ([prd (timesheet-periods sheet)])
         (match prd
           [(period dat duration desc rate)
            `(period ,(date->string dat) ,(round-to-tenth (seconds->hours duration)) ,desc ,(rate->datum rate))])))
    (payments
     ,@(for/list ([pmt (timesheet-payments sheet)])
         (match pmt
           [(payment dat desc amount)
            `(payment ,(date->string dat) ,desc amount)])))))

(define (rate->datum rate)
  (format "$~a/hr" rate))

(define (round-to-tenth x) (/ (round (* 10 (exact->inexact x))) 10))
