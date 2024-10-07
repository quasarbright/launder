#lang scribble/manual

@require[
  scribble/example
  @for-label[racket racket/date launder]]
@(define eval (make-base-eval '(require racket racket/date)))
@(define-syntax-rule (repl body ...) (examples #:eval eval #:label #f body ...))

@title{launder}
@author{Mike Delmonaco}

@defmodule[launder]

A DSL for tracking hours worked and how much you've been paid for them.

Launder is used to manage @deftech{timesheets}. A timesheet contains information about your work hours and how much you've been paid for them. You can log hours, log payments, query information like how much money you are owed, save to a file, load from a file, etc.

@examples[#:eval eval
(require launder)
(new! #:rate 40)
(add-period! (yesterday) (hours 1) "dilly dallying")
(clock-in! (hours-ago 2) "started working")
(clock-out! (now) "done working")
(money-owed)
(add-payment! (today) 50)
(money-owed)
(print-timesheet)
]

@defproc[(timesheet? [v any/c]) boolean?]

Returns @racket[#t] if @racket[v] is a @tech{timesheet}, @racket[#f] otherwise.

@defparam[current-timesheet sheet timesheet?]

The current timesheet. Defaults to an empty timesheet.

@defproc[(help) void?]

Opens this documentation.

@section{File Operations}

@defproc[(open! [path (or/c #f path-string?) #f]) void?]

Loads a timesheet from a file. If @racket[path] is not specified, then a GUI file picker is used.

@defproc[(save-as! [path (or/c #f path-string?) #f]) void?]

Saves the current timesheet to a file. If @racket[path] is not specified, then a GUI file picker is used.

@defproc[(save!) void?]

Save the current timesheet to the current file (last file specified by @racket[open!] or @racket[save-as!]).

If there is no current file, then a GUI file picker is opened to select one.

@defproc[(home-path [path string?]) path-string?]

Helper for creating paths relative to the user's home directory.

For example, @racket[(home-path "foo.txt")] behaves like @racket["~/foo.txt"].

@section{Timesheet Operations}

The operations in this section manipulate the current timesheet (except for @racket[new!]).

@defproc[(new! [#:rate rate real? 0]) void?]

Create a new timesheet, optionally specifying the hourly pay rate for work.

@examples[#:eval eval
(new! #:rate 40)
(print-timesheet)
]

This creates a timesheet where the pay rate is $40/hour.

@defproc[(undo!) void?]

Undoes the most recent edit.

@defproc[(redo!) void?]

Redoes an edit undone by @racket[undo!].

@examples[#:eval eval
(new! #:rate 40)
(print-timesheet)
(add-period! (today) (hours 1) "working")
(print-timesheet)
(undo!)
(print-timesheet)
(redo!)
(print-timesheet)
]

@defproc[(clock-in! [date date?]
                    [description (or/c #f string?) #f]
                    [#:rate rate (or/c #f real?) #f])
         void?]

@defproc[(clock-out! [date date?]
                     [description (or/c #f string?) #f]
                     [#:rate rate (or/c #f real?) #f])
         void?]

Clock in and out of work. Optionally provide a description for the work being done and specify an hourly pay rate.

If no hourly rate is specified, uses current timesheet's hourly rate.

@examples[#:eval eval
(new! #:rate 40)
(clock-in! (hours-ago 2))
(clock-out! (now))
(print-timesheet)
]

Usually, you'd just use @racket[(now)] for clocking in and out when you begin and end working respectively.

@defproc[(add-period! [date date?]
                      [duration natural?]
                      [description (or/c #f string?) #f]
                      [#:rate rate (or/c #f real?) #f])
         void?]

Adds a period of work. Useful if you know how long you worked for, but not when you started or ended.

It is recommended to use date utilities like @racket[today] which exclude time information.

@racket[duration] is in seconds. It is recommended to use date utilities like @racket[hours] for this.

@examples[#:eval eval
(new! #:rate 40)
(add-period! (today) (hours 1) "working")
(print-timesheet)
]

@defproc[(set-hourly-rate! [rate real?]) void?]

Sets the current hourly pay rate for work (in dollars per hour).

@examples[#:eval eval
(new! #:rate 40)
(set-hourly-rate! 60)
(add-period! (today) (hours 2) "working")
(money-owed)
]

@defproc[(add-payment! [date date?] [amount real?] [description (or/c #f string?) #f]) void?]

Record a payment.

@examples[#:eval eval
(new! #:rate 40)
(add-period! (today) (hours 2) "working")
(money-owed)
(add-payment! (today) 30)
(money-owed)
]

@defproc[(hours-between [start date?] [end date?]) void?]

The number of hours worked between @racket[start] and @racket[end], inclusive. Only considers intervals of work that fall entirely within the range.

@examples[#:eval eval
(new! #:rate 40)
(add-period! (days-ago 2) (hours 2))
(add-period! (yesterday) (hours 2))
(clock-in! (hours-ago 1))
(clock-out! (now))
(hours-between (days-ago 2) (yesterday))
(hours-between (yesterday) (now))
]

@defproc[(total-hours) real?]

The total number of hours worked.

@defproc[(unpaid-hours) real?]

The number of hours of work you haven't been paid for. Calculated based on money owed and hourly rate.

@examples[#:eval eval
(new! #:rate 40)
(add-period! (yesterday) (hours 3))
(add-payment! (today) 40)
(unpaid-hours)
]

@defproc[(money-owed) real?]

The amount of money owed for your work. Calculated based on hours worked and hourly rates of each work interval/period and the total amount you've been paid.


@examples[#:eval eval
(new! #:rate 40)
(add-period! (yesterday) (hours 3))
(add-payment! (today) 40)
(money-owed)
]

@defproc[(money-paid) real?]

The total amount of money you've been paid.

@examples[#:eval eval
(new! #:rate 40)
(add-period! (yesterday) (hours 3))
(add-payment! (today) 20)
(add-payment! (today) 20)
(money-paid)
]

@defproc[(print-timesheet) void?]

Displays the current timesheet in a human-readable format.

@examples[#:eval eval
(new! #:rate 40)
(add-period! (yesterday) (hours 3))
(add-payment! (today) 20)
(add-payment! (today) 20)
(print-timesheet)
]

@section{Date and time utilities}

These functions are useful for specifying dates, times, and durations in the context of timesheets.

@defproc[(now) date?]

The current date/time.

@defproc[(seconds [n natural?]) natural?]

The number of seconds in @racket[n] seconds (this is an identity function)

@examples[#:eval eval
(seconds 10)
]

@defproc[(minutes [n natural?]) natural?]

The number of seconds in @racket[n] minutes.

@examples[#:eval eval
(minutes 2)
]

@defproc[(hours [n natural?]) natural?]

The number of seconds in @racket[n] hours.

@examples[#:eval eval
(hours 2)
]

@defproc[(today) date?]

Today's date, at midnight. This is used when you want to specify a date, but no time, like for a period. This operation @deftech{clears time}.

@examples[#:eval eval
(date->string (now))
(date->string (today))
]

@defproc[(yesterday) date?]

Yesterday's date. @tech{clears time}.

@examples[#:eval eval
(date->string (now))
(date->string (yesterday))
]

@defproc[(days-ago [n natural?]) date?]

@racket[n] days ago. clears time.

@examples[#:eval eval
(date->string (today))
(date->string (days-ago 2))
]

@defproc[(hours-ago [n natural?]) date?]

The time @racket[n] hours ago. Does not clear time.

@examples[#:eval eval
(date->string (now) #t)
(date->string (hours-ago 2) #t)
]

@defproc[(time-ago [n natural?]) date?]

The time @racket[n] seconds ago. Does not clear time.

@examples[#:eval eval
(date->string (now) #t)
(date->string (time-ago (minutes 10)) #t)
]
