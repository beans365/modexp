#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#=======================================================================
#
# modexp.py
# ---------
# A python model for doing modular exponention.
#
#
# Author: Joachim Strömbergson
# Copyright (c) 2014, Secworks Sweden AB
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the
#    distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#=======================================================================

#-------------------------------------------------------------------
# Python module imports.
#-------------------------------------------------------------------
import sys


#-------------------------------------------------------------------
# Defines.
#-------------------------------------------------------------------
VERBOSE = False

#-------------------------------------------------------------------
# iter_mult()
#
# Attempt at builing an iterative multiplier i*j that are
# bitlen number of bits.
#-------------------------------------------------------------------
def iter_mult(i, j, bitlen):
    n = i
    r = 0
    for bit in range(bitlen):
        if (j & (1 << bit)):
            r = (r + n) % 2**bitlen
        n = (n + n) % 2**bitlen
    return r


#-------------------------------------------------------------------
# iter_exp()
#
# Iterative exponentiator.
#-------------------------------------------------------------------
def iter_exp(i, j, bitlength):
    n = i
    r = 1
    for bit in range(bitlength):
        if (j & (1 << bit)):
            r = iter_mult(r, n, bitlength)
        n = iter_mult(n, n, bitlength)
    return r


#-------------------------------------------------------------------
# gen_keypair()
#
# Generate a keypair (and exponent) with n bits in length.
#-------------------------------------------------------------------
def gen_keypair(bitlen):
    print("Generating keys with %d bits" % (bitlen))
    print("")

    e = 3
    pub = 2**bitlen - 1
    priv = pub - 2

    return (pub, priv, e)


#-------------------------------------------------------------------
# keytest()
#-------------------------------------------------------------------
def keytest():
    print("key encryption and decryption")
    print("-----------------------------")

    p = 11
    q = 13
    n = p * q
    tiotent = (p - 1) * (q - 1)

    print("p = %d, q = %d, n = %d, tiotent = %d" % (p, q, n, tiotent))

    e = 7
    d = 103

    print("e = %d, d = %d" % (e, d))

    print("Public key: e, n = %d, %d" % (e, n))
    print("private key: d = %d" % (d))

    m = 9
    cm = modexp(m, e, n)
    m2 = modexp(cm, d, n)
    print("Encryption of message m  = %d -> cm = %d" % (m, cm))
    print("Decryption of message cm = %d -> m  = %d" % (cm, m2))


#-------------------------------------------------------------------
# modtest()
#-------------------------------------------------------------------
def modtest():
    print("modular exponentition")
    print("---------------------")

    M = 12345
    e = 3
    N = 12347

    print("M = %d, e = %d, N = %d" % (M, e, N))
    print(modexp(M, e, N))
    print("")

    M = 2**8192 - 37
    e = 3
    N = 2**8192 - 1

    print("M = %d, e = %d, N = %d" % (M, e, N))
    print(modexp(M, e, N))
    print("")


#-------------------------------------------------------------------
# modexp()
#
# Perform generic modular exponention of the given message M
# using the exponent e and modulus N.
#-------------------------------------------------------------------
def modexp(M, e, N):
    return (M ** e) % N


#-------------------------------------------------------------------
# main()
#
# Parse any arguments and run the tests.
#-------------------------------------------------------------------
def main():
    my_keypair = gen_keypair(12)
    print(my_keypair)
    modtest()
    keytest()

    # test of iterative multiply and exponentiation
    print(iter_mult(8, 8, 4))
    print(iter_exp(8, 8, 4))


#-------------------------------------------------------------------
# __name__
# Python thingy which allows the file to be run standalone as
# well as parsed from within a Python interpreter.
#-------------------------------------------------------------------
if __name__=="__main__":
    # Run the main function.
    sys.exit(main())


#=======================================================================
# EOF modexp.py
#=======================================================================