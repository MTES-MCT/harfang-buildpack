FROM scalingo/scalingo-22
ADD . buildpack

ADD .env /env/.env
RUN buildpack/bin/detect /build
RUN buildpack/bin/env.sh /env/.env /env
RUN buildpack/bin/compile /build /cache /env
RUN /opt/hurukai-agent/bin/hurukai --fix