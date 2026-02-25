![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Tiny Tapeout Canright Substitution-Box

This a design for [TinyTapeout] IHP 26a. It includes two Advanced Encryption
Standard (AES) SBOXes. The first SBOX is unmasked and follows the original
Canright paper[^1]. The second SBOX is binary masked and follows the follow-up
Canright paper[^2].

These designs are manually adapted from the implementation in [OpenTitan].
The design is (hopefully) functional but mostly to test out the TinyTapeout
workflow.

- [Read the documentation for project](docs/info.md)

[^1]: A very compact Rijndael S-box (David Canright)
[^2]: A Very Compact "Perfectly Masked" S-Box for AES (David Canright and Lejla Batina)
[TinyTapeout]: https://tinytapeout.com
[OpenTitan]: https://github.com/lowRISC/opentitan
