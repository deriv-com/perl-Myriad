FROM deriv/dzil
ARG HTTP_PROXY

WORKDIR /app
ONBUILD COPY aptfile cpanfile dist.ini /app/
ONBUILD RUN prepare-apt-cpan.sh \
 && dzil authordeps | cpanm -n
ONBUILD COPY . /app/
ONBUILD RUN if [ -f /app/app.pl ]; then perl -I /app/lib -c /app/app.pl; fi

RUN dzil install \
 && dzil clean \
 && git clean -fd \
 && apt purge --autoremove -y \
 && rm -rf .git .circleci

ENTRYPOINT [ "bin/myriad-start.sh" ]

