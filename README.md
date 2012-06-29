perl-url-shortener
==================

Simple and may be fast URL shortener

Perl, Twiggy and Redis used.

Fast?
Not scalable!
Memory limited!

For start: twiggy --listen :8080 shortener.psgi

For benchmarking: ab -n 10000 -c 500 -k http://localhost:8080/?url=$RANDOM

