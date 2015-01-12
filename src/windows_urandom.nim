# Copyright (c) 2014 Oleh Prypin <blaxpirit@gmail.com>
# License: MIT


import winlean

type ULONG_PTR = int
type HCRYPTPROV = ULONG_PTR
var PROV_RSA_FULL {.importc, header: "<windows.h>".}: DWORD
var CRYPT_VERIFYCONTEXT {.importc, header: "<windows.h>".}: DWORD

when useWinUnicode:
  proc CryptAcquireContext(
    phProv: ptr HCRYPTPROV,
    pszContainer: WideCString,
    pszProvider: WideCString,
    dwProvType: DWORD,
    dwFlags: DWORD
  ): WinBool {.stdcall, dynlib: "Advapi32.dll", importc: "CryptAcquireContextW".}
else:
  proc CryptAcquireContext(
    phProv: ptr HCRYPTPROV,
    pszContainer: cstring,
    pszProvider: cstring,
    dwProvType: DWORD,
    dwFlags: DWORD
  ): WinBool {.stdcall, dynlib: "Advapi32.dll", importc: "CryptAcquireContextA".}

proc CryptGenRandom(
  hProv: HCRYPTPROV,
  dwLen: DWORD,
  pbBuffer: pointer
): WinBool {.stdcall, dynlib: "Advapi32.dll", importc: "CryptGenRandom".}


var cryptProv: HCRYPTPROV = 0

proc urandomInit() {.raises: [OSError].} =
  let success = CryptAcquireContext(
    cast[ptr HCRYPTPROV](addr cryptProv),
    nil, nil, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT
  )
  if success == 0:
    raise newException(OSError, "Call to CryptAcquireContext failed")

proc urandom*(size: Natural): seq[uint8] {.raises: [OSError].} =
  ## Returns ``size`` bytes obtained by calling ``CryptGenRandom``.
  ## Initialization is done before the first call with
  ## ``CryptAcquireContext(..., PROV_RSA_FULL, CRYPT_VERIFYCONTEXT)``.
  ## Raises ``OSError`` on failure.
  newSeq(result, size)
    
  if cryptProv == 0:
    urandomInit()
    
  let success = CryptGenRandom(cryptProv, DWORD(size), addr result[0])
  if success == 0:
    raise newException(OSError, "Call to CryptGenRandom failed")
