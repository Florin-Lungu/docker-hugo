FROM scratch AS image

COPY --from=base--hugo--standard / /
COPY --from=base--sass / /


FROM base-debian AS main

ENV HUGO_EDITION="standard"

COPY --from=image / /

IMPORT ../_imports/default_nonroot_user.df

IMPORT ../_imports/ci.df

IMPORT ../_imports/onbuild.df

FROM main

USER hugo
