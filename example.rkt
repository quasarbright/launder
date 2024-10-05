#lang racket

(require launder)

(new! #:rate 40)
(add-period! (yesterday) (hours 1) "dilly dallying")
(clock-in! (time-ago (hours 2)) "started working")
(clock-out! (now) "done working")
(money-owed)
(add-payment! (today) 50)
(money-owed)
(undo!)
(money-owed)
(redo!)
(money-owed)
(save-as! (home-path "research.ldr"))
(open! (home-path "research.ldr"))
(print-timesheet)
