#!/usr/bin/env python3
# Jose Riguera (c) 2024
# GNU Lesser General Public License v3 or later (LGPLv3+)
# Based on https://gitlab.com/devolive/pypi-packages/checksum-calculator

from enum import Enum
from typing import *
from textwrap import wrap
import sys

def compute_checksum8_xor(data: str) -> str:
    """
    :return:  The checksum computed with the method of 'or exclusive'.
    """
    xor = 0
    for value in wrap(data, 2):
        xor ^= int(value, base=16)
    return '%02X' % xor


def compute_checksum_odd_xor(data: str) -> str:
    """
    :return:  The checksum computed with the method of 'or exclusive'.
    """
    xor = 0
    for value in wrap(data, 4):
        xor ^= int(value[:2], base=16)
    return '%02X' % xor


def compute_checksum_even_xor(data: str) -> str:
    """
    :return:  The checksum computed with the method of 'or exclusive'.
    """
    xor = 0
    for value in wrap(data, 4):
        xor ^= int(value[2:], base=16)
    return '%02X' % xor


def compute_checksum_gaitek(h, v: str) -> str:
    even = int(compute_checksum_even_xor(h+v), 16)
    #print("hex: {0:x};  bin: {0:0>8b}".format(int(even, 16)))
    odd = int(compute_checksum_odd_xor(h+v), 16)
    #print("hex: {0:x};  bin: {0:0>8b}".format(int(odd, 16)))
    #print("{0:x} {1:x}".format(even, odd))
    even = even << 8
    return '%04X' % (even+odd)


def _sum_data(data: str) -> int:
    sum_ = 0
    for value in wrap(data, 2):
        sum_ += int(value, base=16)
    return sum_


def hex_switch_lsb_msb(hex: str) -> str:
    """
    :return:  hex string in msb mode
    """
    def reverse_bits(byte):
        return format(int(byte, 2), '08b')[::-1]
    
    reversed = ""
    for value in wrap(hex, 2):
        byte = "{0:0>8b}".format(int(value, 16))
        byte = reverse_bits(byte)
        #print("{0:0>8b}".format(int(value, 16)))
        #print("{0:0>8b}".format(int(byte, 2)))
        #print(format( int(byte, 2), "02X"))
        #reversed += format(int(byte, 2), "02X")
        reversed += '%02X' % int(byte, 2)
    return reversed


def compute_checksum8_mod256(data: str) -> str:
    """
    :return:  The checksum computed with the method of 'sum and modulo 256'.
    """
    return '%02X' % ((_sum_data(data) % 256))


def compute_checksum8_2s_complement(data: str) -> str:
    """
    :return:  The checksum computed with the method of '2s complement'.
    """
    return '%02X' % (-(_sum_data(data) % 256) & 0xFF)


def main() -> int:
    h = "BD"

    # Status msg

    v = "011021171D351E0000"
    r = "238F"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "011021171C351E0000"
    r = "228F"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0110211711351E0000"
    r = "2F8F"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0110231719341E0000"
    r = "258E"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "011023171934320000"
    r = "098E"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0110231719352D0000"
    r = "168F"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0010261719351E0000"
    r = "218F"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0410261719351E0000"
    r = "258F"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0410261719351E0300"
    r = "258C"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0110361719351E0000"
    r = "308F"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0110211719351E0000"
    r = "278F"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0010211719371E0000"
    r = "268D"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))


    ## Commands

    v = "FFFF000000"
    r = "FF42"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0A03000000"
    r = "0ABE"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0001000000"
    r = "00BC"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0A02000000"
    r = "0ABF"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "081C000000"
    r = "08A1"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "081E000000"
    r = "08A3"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))

    v = "0603000000"
    r = "06BE"
    ck = compute_checksum_gaitek(h, v)
    print("{0:s}  >> {1:04X} == {2:s}    {1:0>8b}, {3}".format(h+v, int(ck, 16), r, ck == r))


    #r1 = hex_switch_lsb_msb(h+v)
    #r2 = hex_switch_lsb_msb(r1)
    #print("%s" % h+v)
    #print("%s" % r2)
    return 0

if __name__ == '__main__':
    sys.exit(main())