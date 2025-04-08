FROM scalingo/scalingo-22
ADD . buildpack

ADD .env /env/.env
RUN buildpack/bin/env.sh /env/.env /env
RUN buildpack/bin/compile /build /cache /env
RUN rm -rf /app/soc
RUN cp -rf /build/soc /app/soc
EXPOSE 8080

RUN sed -i "/esac/a export PATH=\$PATH:\/app\/java\/bin" "/app/soc/bin/kc.sh"

ENTRYPOINT [ "/app/soc/bin/kc.sh", "--verbose",  "start", "--hostname-strict-https=false" ]