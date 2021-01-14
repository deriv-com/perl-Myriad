FROM deriv/dzil
ARG HTTP_PROXY

ONBUILD COPY . /opt/app/
ONBUILD WORKDIR /opt/app/
ONBUILD RUN /microservice_install.sh

ONBUILD RUN apt-get purge -y -q $(perl -le'@seen{split " ", "" . do { local ($/, @ARGV) = (undef, "aptfile"); <> }} = () if -r "aptfile"; print for grep { !exists $seen{$_} } qw(build-essential make gcc git openssh-client wget)')
ONBUILD WORKDIR /app

COPY ./microservice_install.sh /
RUN dzil install \
 && dzil clean \
 && git clean -fd \
 && apt purge --autoremove -y \
 && rm -rf .git .circleci
ENTRYPOINT [ "myriad.pl" ]
