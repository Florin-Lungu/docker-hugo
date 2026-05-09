FROM scratch as image

COPY --from=base--files--busybox / /
COPY --from=base--hugo--standard / /
COPY --from=base--certs / /



FROM base--image--busybox AS main

IMPORT ../_imports/version_arg

ENV HUGO_BIND="0.0.0.0" \
    HUGO_DESTINATION="public" \
    HUGO_ENV="DEV" \
    HUGO_EDITION="standard" \
    HOME="/home/hugo"

COPY --from=image / /

IMPORT ../_imports/default_nonroot_user_alpine.df

RUN mkdir -p /src /target /builds \
 && chown hugo:hugo /src /target /builds \
 && chown -R hugo:hugo /home/hugo \
 && chmod a+wrx /src /target /builds

VOLUME [ "/src", "/target", "/builds" ]

EXPOSE 1313

WORKDIR /src

ENTRYPOINT ["hugo"]

IMPORT ../_imports/ci.df

USER hugo

IMPORT ../_imports/onbuild.df

USER hugo

FROM main

USER hugo