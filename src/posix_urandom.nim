# Copyright (c) 2014 Oleh Prypin <blaxpirit@gmail.com>
# License: MIT


proc urandom*(size: Natural): seq[uint8] {.raises: [OSError].} =
    ## Reads and returns ``size`` bytes from the file ``/dev/urandom``.
    ## Raises ``OSError`` on failure.
    new_seq(result, size)
    
    var file: File
    if not file.open("/dev/urandom"):
        raise new_exception(OSError, "/dev/urandom is not available")
    
    var index = 0
    while index < size:
        let bytes_read = file.read_buffer(addr result[index], size-index)
        if bytes_read <= 0:
            raise new_exception(OSError, "Can't read enough bytes from /dev/urandom")
        index += bytes_read
