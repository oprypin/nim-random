# Copyright (c) 2014 Oleh Prypin <blaxpirit@gmail.com>
# License: MIT


proc urandom*(size: Natural): seq[uint8] {.raises: [OSError].} =
  ## Reads and returns ``size`` bytes from the file ``/dev/urandom``.
  ## Raises ``OSError`` on failure.
  newSeq(result, size)
    
  var file: File
  if not file.open("/dev/urandom"):
    raise newException(OSError, "/dev/urandom is not available")
    
  var index = 0
  while index < size:
    let bytesRead = file.readBuffer(addr result[index], size-index)
    if bytesRead <= 0:
      raise newException(OSError, "Can't read enough bytes from /dev/urandom")
    index += bytesRead
