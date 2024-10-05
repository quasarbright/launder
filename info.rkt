#lang info
(define collection "launder")
(define deps '("base"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/launder.scrbl" ())))
(define pkg-desc "A little DSL for tracking work hours and payments")
(define version "0.0")
(define pkg-authors '("Mike Delmonaco"))
(define license '(Apache-2.0 OR MIT))
