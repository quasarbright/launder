launder
=======

A little dsl for tracking work hours and payments.

The UI is the Racket repl.

## dependencies

- [Racket](https://racket-lang.org/)

## installation

```sh
raco pkg install
```

## usage

Open a Racket repl from the terminal.

```sh
racket
```

Require the library and run commands.

```racket
> (require launder)
> (create-timesheet! #:rate 40)
> (add-period! (yesterday) (hours 1) "dilly dallying")
> (clock-in! (time-ago (hours 2)) "started working")
> (clock-out! (now) "done working")
> (money-owed)
120
> (add-payment! (today) 50)
> (money-owed)
70
> (save-timesheet! "research.hours")
> (load-timesheet! "research.hours")
> (print-timesheet)
'(timesheet
  (clock-in #f)
  (hourly-rate "$40/hr")
  (intervals
   (interval
    (start "Friday, October 4th, 2024 9:16:20pm" "started working" "$40/hr")
    (end "Friday, October 4th, 2024 11:16:20pm" "done working" "$40/hr")))
  (periods
   (period "Thursday, October 3rd, 2024" 1.0 "dilly dallying" "$40/hr"))
  (payments (payment "Friday, October 4th, 2024" #f amount)))
```
