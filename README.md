sypper
-------------------------------------

sypper is intended to be used for server-side testing and benchmarking of download servers and mirror infrastructure.
But it can be used for downloading packages e.g. when zypper is slow.
It uses repositories description in .repo files, the same way as zypper does.

## Syntax

`sypper download` - download packages required for system update.

`sypper download <package>` - download a package and required dependencies.

`sypper refresh` - update local repositories metadata if needed.

Use the following flags after `sypper download`:
-v increase verbosity (may be specified multiple times);
-c followed by number: set concurrency;
-n do not ask input for problems, automatically choose solution;
-f force refresh of repositories and overwrite cached files.

## Use case 1 - regular user

run sypper as a regular user: It will create a directory cache/packages in the current directory.
You can copy the content of that folder to /var/cache/zypp/packages, so zypper will pick them up instead of downloading.

## Use case 2 - root (not recommended)

run sypper as root, then it will download packages to /var/cache/zypp/packages, so zypper will pick them up on the next run.

## Credits

The initial implementation was taken from libsolv/examples/p5solv.
