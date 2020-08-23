FROM deriv/dzil
ARG HTTP_PROXY
RUN dzil install
ENTRYPOINT "myriad.pl"
