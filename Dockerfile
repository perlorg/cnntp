FROM quay.io/perl/base-os:v3.3

USER root
ENV CBCONFIG=

RUN apk update; apk upgrade apk-tools; apk upgrade; apk add libxml2-dev

ENV CBROOTLOCAL=/cnntp/
ENV CBROOT=/cnntp/combust
WORKDIR /cnntp

EXPOSE 8299
CMD ./run

RUN addgroup cnntp && adduser -D -G cnntp cnntp

RUN cpanm Email::MIME Captcha::reCAPTCHA \
  XML::RSS XML::Atom::Feed XML::Atom::Entry \
  Email::Address Net::NNTP Email::Abstract \
  DateTime::Locale

ADD . /cnntp

RUN mkdir -p logs; chown cnntp logs

# because quay.io sets timestamps to 1980 for some reason ...
RUN find ./docs -type f -print0 | xargs -0 touch

USER cnntp

