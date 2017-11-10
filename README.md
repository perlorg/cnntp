# Colobus NNTP Web interface

This code runs the [www.nntp.perl.org](http://www.nntp.perl.org/) web
service.

To run it locally, copy cnntp.env.sample to cnntp.env and edit as
appropriate.

    docker run -p 8246:8246 --rm -it \
      -v `pwd`:/cnntp \
      --env-file cnntp.env \
      quay.io/perl/cnntp:latest

In production this runs under kubernetes.

## Database

To use this you need a [colobus](https://github.com/abh/colobus)
database with indexed headers. Open [an
issue](https://github.com/perlorg/cnntp/issues/new) and tell what you
are going to fix or improve and we can provide a partial dump of the
perl.org archive.

The actual email data comes from the NNTP server.
