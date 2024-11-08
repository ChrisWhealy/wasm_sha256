# Step 9: Close the File

We could omit this step and let WASI clean up any open files when it terminates; however, its better to play by the rules and close the file when we know we no longer need to keep it open.

Closing a file using WASI is simply a matter of passing the open file descriptor to `fd_close`.

```wat
(call $wasi_fd_close (local.get $fd_file))
```

