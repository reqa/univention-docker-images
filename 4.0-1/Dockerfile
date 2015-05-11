# vim:set ft=dockerfile:
FROM ucs-member-amd64:4.0-0

COPY update-ucs-role-image.sh /

RUN update-ucs-role-image.sh

PORT 80

## Run the /sbin/init wrapper from univention-docker-container-mode
ENTRYPOINT ["/sbin/init"]
