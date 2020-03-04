FROM regentmarkets/async-perl
ADD cpanfile /opt/cpanfile
RUN cpanm --installdeps -n /opt
ADD . /opt
CMD [ "/bin/bash" ]
