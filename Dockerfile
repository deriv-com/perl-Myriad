FROM deriv/dzil
ARG HTTP_PROXY
RUN dzil install \
 && dzil clean \
 && rm -rf .git .circleci
ENTRYPOINT "myriad.pl"
