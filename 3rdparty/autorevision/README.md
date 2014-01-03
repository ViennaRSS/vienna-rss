Autorevision
============

A program for extracting version information useful in release/build scripting from repositories. 

Supported repository types include `git`, `hg`, `bzr`, and `svn`. The record can be emitted in a ready-to-use form for `C`, `C++`, `Java`, `bash`, `Python`, `Perl`, `lua`, `php`, `ini` and others.

Emitted information includes the ID of the most recent commit, its branch, its date, and several other useful pieces of meta-information.

There is support for reading and writing a cache file so autorevision will remain useful during a build from an unpacked distribution tarball.

See the [manual page](https://github.com/Autorevision/autorevision/blob/master/autorevision.asciidoc), included in the distribution, for invocation details.
