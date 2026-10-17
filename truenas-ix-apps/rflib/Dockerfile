# rflib from its GitHub release: the linux binary for the build's
# architecture, checked against the release's SHA256SUMS.
#
#   docker build --build-arg RFLIB_VERSION=v0.1.0 -t ${REGISTRY_HOST}/rflib:v0.1.0 rflib/
#   docker push ${REGISTRY_HOST}/rflib:v0.1.0

FROM alpine:3.20 AS fetch
ARG RFLIB_VERSION
ARG TARGETARCH=amd64
WORKDIR /tmp
RUN test -n "$RFLIB_VERSION" || (echo "set --build-arg RFLIB_VERSION, such as v0.1.0" >&2; exit 1)
RUN archive="rflib-${RFLIB_VERSION}-linux-${TARGETARCH}.tar.gz" \
 && base="https://github.com/rgeyer/rflib/releases/download/${RFLIB_VERSION}" \
 && wget -q "$base/$archive" "$base/SHA256SUMS" \
 && grep " ${archive}\$" SHA256SUMS | sha256sum -c - \
 && tar xzf "$archive" \
 && mv "rflib-${RFLIB_VERSION}-linux-${TARGETARCH}/rflib" /rflib

FROM alpine:3.20
# sqlite3, for online backups of the library (see README).
RUN apk add --no-cache sqlite
COPY --from=fetch /rflib /usr/local/bin/rflib
# The library lives in /data, a volume owned by the user the container runs
# as (compose sets it).
ENV RFLIB_DB=/data/library.db
VOLUME /data
EXPOSE 8080
ENTRYPOINT ["rflib"]
CMD ["serve", "--accounts", "--signup", "invite", "--behind-tls", "--addr", ":8080"]
