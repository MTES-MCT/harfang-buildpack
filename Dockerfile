FROM scalingo/scalingo-22
ADD . buildpack
ARG USERNAME=scalingo
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN mkdir -p /build /env /cache
# Create the user with rights
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && chown ${USERNAME} /build \
    && chown ${USERNAME} /cache \
    && chown ${USERNAME} /env
USER $USERNAME
ADD .env /env/.env
RUN buildpack/bin/detect /build
RUN buildpack/bin/env.sh /env/.env /env
RUN buildpack/bin/compile /build /cache /env
RUN /opt/hurukai-agent/bin/hurukai --fix