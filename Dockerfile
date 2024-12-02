FROM harbor.ntppool.org/perlorg/base-os:3.20.2

LABEL org.opencontainers.image.description="Colobus NNTP / ezmlm Web Archive publisher"

USER root
ENV CBCONFIG=

RUN apk update; apk upgrade apk-tools; apk upgrade; apk add libxml2-dev

ENV CBROOTLOCAL=/cnntp/
ENV CBROOT=/cnntp/combust
WORKDIR /cnntp

EXPOSE 8299
CMD ["./run"]

RUN addgroup cnntp && adduser -D -G cnntp cnntp

# - Alpine is missing some locale stuff so Number::Format fails some
# tests.
# - XML::Atom doesn't like newer XML-LibXML:
# https://github.com/miyagawa/xml-atom/issues/18
# - POSIX::strftime::compiler has weird time zone issues on Alpine 3.12
RUN cpanm --notest \
          Number::Format \
          XML::Atom \
          POSIX::strftime::Compiler

RUN cpanm Email::MIME Captcha::reCAPTCHA \
  XML::RSS XML::Atom::Feed XML::Atom::Entry \
  Email::Address Net::NNTP Email::Abstract \
  DateTime::Locale Template::Plugin::Number::Format \
  Starman Plack::Middleware::XForwardedFor \
  Plack::Middleware::Options \
  Plack::Middleware::AccessLog

# This makes OpenTelemetry::Exporter::OTLP fail tests
# https://github.com/docker/setup-buildx-action/issues/356
ENV OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=""

RUN cpanm -v OpenTelemetry OpenTelemetry::SDK OpenTelemetry::Exporter::OTLP Plack::Middleware::OpenTelemetry

RUN cpanm https://tmp.askask.com/2024/02/Net-Async-HTTP-Server-0.14bis2.tar.gz

ADD . /cnntp

RUN mkdir -p logs; chown cnntp logs

RUN apk add go

# because quay.io sets timestamps to 1980 for some reason ...
RUN find ./docs -type f -print0 | xargs -0 touch

USER cnntp

