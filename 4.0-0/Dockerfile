# vim:set ft=dockerfile:
FROM ucs-stem-amd64:4.0-0

COPY setup-ucs-role-image.sh /

RUN setup-ucs-role-image.sh member

PORT 80

## Run the /sbin/init wrapper from univention-docker-container-mode
ENTRYPOINT ["/sbin/init"]
