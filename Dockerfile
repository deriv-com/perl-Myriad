FROM deriv/dzil
ARG HTTP_PROXY
RUN dzil install \
 && dzil clean \
 && git clean -fd \
 && apt purge --autoremove -y \
 && rm -rf .git .circleci
ENTRYPOINT "myriad.pl"
