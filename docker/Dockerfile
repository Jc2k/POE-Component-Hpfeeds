FROM alpine:3.7 AS builder

RUN apk --no-cache add gcc g++ make git patch perl perl-dev wget

ENV PERL5LIB /app/lib/perl5
ENV PATH /app/bin/:$PATH

RUN wget https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm -O /root/cpanm && chmod +x /root/cpanm
RUN /root/cpanm App::cpanminus

COPY docker/requirements.txt /app/requirements.txt
RUN yes "" | cpanm -l /app --notest `sed 's/#.*//; /^[[:space:]]*$$/d' < /app/requirements.txt`


FROM alpine:3.7

ENV PERL5LIB /app/lib/perl5
ENV PATH /app/bin/:$PATH

RUN apk --no-cache add perl

COPY --from=builder /app /app

COPY lib/POE/Component/Hpfeeds.pm /app/lib/perl5/POE/Component/Hpfeeds.pm
COPY lib/POE/Filter/Hpfeeds.pm /app/lib/perl5/POE/Filter/Hpfeeds.pm
COPY test.pm /test.pm

CMD ["/usr/bin/perl", "-T", "-I/app/lib/perl5", "/test.pm"]
