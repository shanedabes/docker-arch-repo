FROM archlinux:base-devel-20201115.0.9067

ENV AURUTILS_GPG="6BC26A17B9B7018A"
ENV AURUTILS_VERSION="3.1.2"

RUN pacman -Syyu --noconfirm --asdeps --needed base-devel git jq pacutils curl pacman-contrib \
 && rm -rf /var/cache/pacman/pkg/* \
 && useradd builduser -m \
 && passwd -d builduser \
 && echo -e "builduser ALL=(ALL) NOPASSWD: /usr/bin/pacman\n" | tee -a /etc/sudoers \
 && curl -L "https://github.com/AladW/aurutils/releases/download/${AURUTILS_VERSION}/aurutils-${AURUTILS_VERSION}.tar.gz" | tar -xvzf - \
 && cd "aurutils-${AURUTILS_VERSION}" \
 && make install \
 && cd \
 && rm -rf "aurutils-${AURUTILS_VERSION}" \
 && mkdir /app /repo /git \
 && chown builduser /app /repo /git \
 && echo -e "\n[repo]\nSigLevel = Optional TrustAll\nServer = file:///repo" >> /etc/pacman.conf

WORKDIR "/git"
USER builduser

VOLUME "/repo"

COPY repo-builder.sh /app
CMD /app/repo-builder.sh
