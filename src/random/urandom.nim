# Copyright (C) 2014-2015 Oleh Prypin <blaxpirit@gmail.com>
# 
# This file is part of nim-random.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


import common
export common


when defined(windows):
  import winlean

  type ULONG_PTR = int
  type HCRYPTPROV = ULONG_PTR
  var PROV_RSA_FULL {.importc, header: "<windows.h>".}: DWORD
  var CRYPT_VERIFYCONTEXT {.importc, header: "<windows.h>".}: DWORD

  when useWinUnicode:
    proc CryptAcquireContext(
      phProv: ptr HCRYPTPROV, pszContainer: WideCString, pszProvider: WideCString,
      dwProvType: DWORD, dwFlags: DWORD
    ): WinBool {.stdcall, dynlib: "Advapi32.dll", importc: "CryptAcquireContextW".}
  else:
    proc CryptAcquireContext(
      phProv: ptr HCRYPTPROV, pszContainer: cstring, pszProvider: cstring,
      dwProvType: DWORD, dwFlags: DWORD
    ): WinBool {.stdcall, dynlib: "Advapi32.dll", importc: "CryptAcquireContextA".}

  proc CryptGenRandom(
    hProv: HCRYPTPROV, dwLen: DWORD, pbBuffer: pointer
  ): WinBool {.stdcall, dynlib: "Advapi32.dll", importc: "CryptGenRandom".}

  var cryptProv: HCRYPTPROV = 0

  proc urandomInit() {.raises: [OSError].} =
    let success = CryptAcquireContext(
      addr cryptProv, nil, nil, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT
    )
    if success == 0:
      raise newException(OSError, "Call to CryptAcquireContext failed")


proc urandom*(size: Natural): seq[uint8] {.raises: [OSError].} =
  ## Returns a ``seq`` of random integers ``0 <= n < 256`` provided by
  ## the operating system's cryptographic source (see ``posix_urandom``, ``windows_urandom``)
  ##
  ## POSIX: Reads and returns ``size`` bytes from the file ``/dev/urandom``.
  ##
  ## Windows: Returns ``size`` bytes obtained by calling ``CryptGenRandom``.
  ## Initialization is done before the first call with
  ## ``CryptAcquireContext(..., PROV_RSA_FULL, CRYPT_VERIFYCONTEXT)``.
  ##
  ## Raises ``OSError`` on failure.
  newSeq(result, size)

  when defined(windows):
    if cryptProv == 0:
      urandomInit()
    
    let success = CryptGenRandom(cryptProv, DWORD(size), addr result[0])
    if success == 0:
      raise newException(OSError, "Call to CryptGenRandom failed")
  
  else:
    var file: File
    if not file.open("/dev/urandom"):
      raise newException(OSError, "/dev/urandom is not available")
    
    var index = 0
    while index < size:
      let bytesRead = file.readBuffer(addr result[index], size-index)
      if bytesRead <= 0:
        raise newException(OSError, "Can't read enough bytes from /dev/urandom")
      index += bytesRead


type SystemRandom* = object
  ## Random number generator based on bytes provided by
  ## the operating system's cryptographic source (see ``urandom``)
  bytesIt: iterator (self: var SystemRandom): uint8 {.closure.}

iterator sysRandomBytes(self: var SystemRandom): uint8 {.closure.} =
  # Get bytes in chunks so we don't need to ask the OS for them
  # multiple times per generated random number...
  while true:
    for b in urandom(128):
      yield b

proc randomByte*(self: var SystemRandom): uint8 {.inline.} =
  self.bytesIt(self)

proc initSystemRandom*(): SystemRandom =
  ## Initializes and returns a new ``SystemRandom``
  result.bytesIt = sysRandomBytes


{.deprecated: [TSystemRandom: SystemRandom].}
