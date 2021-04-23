FROM deriv/dzil
ARG HTTP_PROXY

WORKDIR /app
ONBUILD COPY . /app/
ONBUILD RUN prepare-apt-cpan.sh \
 && dzil authordeps | cpanm -n

# Since we only support Docker on Linux here, we can enforce the `::linux` module
# installation and that'll give us the more efficient EPoll loop.
RUN cpanm IO::Async::Loop::linux \
 && dzil install \
 && dzil clean \
 && git clean -fd \
 && apt purge --autoremove -y \
 && rm -rf .git .circleci

ENTRYPOINT [ "bin/start.sh" ]

