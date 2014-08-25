# Copyright (c) 2014 Oleh Prypin <blaxpirit@gmail.com>
# License: MIT


import winlean

type HCRYPTPROV = PULONG
var PROV_RSA_FULL {.importc, header: "<windows.h>".}: DWORD
var CRYPT_VERIFYCONTEXT {.importc, header: "<windows.h>".}: DWORD

when use_win_unicode:
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
        pszContainer: CString,
        pszProvider: CString,
        dwProvType: DWORD,
        dwFlags: DWORD
    ): WinBool {.stdcall, dynlib: "Advapi32.dll", importc: "CryptAcquireContextA".}

proc CryptGenRandom(
    hProv: HCRYPTPROV,
    dwLen: DWORD,
    pbBuffer: pointer
): WINBOOL {.stdcall, dynlib: "Advapi32.dll", importc: "CryptGenRandom".}

var crypt_prov: HCRYPTPROV = nil

proc urandom_init() {.raises: [EOS].} =
    var success = CryptAcquireContext(cast[ptr HCRYPTPROV](addr crypt_prov), nil, nil, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT)
    if success == 0:
        raise newException(EOS, "Call to CryptAcquireContext failed")

proc urandom*(size: Natural): seq[uint8] {.raises: [EOS].} =
    ## Returns ``size`` bytes obtained by calling ``CryptGenRandom``.
    ## Initialization is done before the first call with ``CryptAcquireContext(..., PROV_RSA_FULL, CRYPT_VERIFYCONTEXT)``.
    ## Raises ``EOS`` on failure.
    new_seq(result, size)
    
    if crypt_prov == nil:
        urandom_init()
    
    var success = CryptGenRandom(crypt_prov, DWORD(size), addr result[0])
    if success == 0:
        raise newException(EOS, "Call to CryptGenRandom failed")