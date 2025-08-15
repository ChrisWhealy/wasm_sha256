# Step 9: Close the File

We could omit this step and let WASI clean up any open files when it terminates; however, its better to play by the rules and close the file as soon as we know it is no longer needed.

Closing a file in WASI is simply a matter of passing the open file descriptor to `$wasi.fd_close`.

```wat
(local.set $return_code (call $wasi.fd_close (local.get $file_fd)))
```

The return code is only collected for tracing and debugging purposes.
If you wish to ignore it, the above statement can be replaced with:

```wat
(call $wasi.fd_close (local.get $file_fd))
drop
```
