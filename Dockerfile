ARG ALPINE_VERSION=3.16
FROM python:3.10.5-alpine${ALPINE_VERSION} as builder


ARG AWS_CLI_VERSION=2.7.20
RUN apk add --no-cache git unzip groff build-base libffi-dev cmake
RUN git clone --single-branch --depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git


WORKDIR aws-cli
RUN sed -i'' 's/PyInstaller.*/PyInstaller==5.2/g' requirements-build.txt
RUN python -m venv venv
RUN . venv/bin/activate
RUN scripts/installers/make-exe
RUN unzip -q dist/awscli-exe.zip
RUN aws/install --bin-dir /aws-cli-bin
RUN /aws-cli-bin/aws --version


# reduce image size: remove autocomplete and examples
RUN rm -rf /usr/local/aws-cli/v2/current/dist/aws_completer /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index /usr/local/aws-cli/v2/current/dist/awscli/examples
RUN find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete


# build the final image
FROM alpine:${ALPINE_VERSION}
COPY --from=builder /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=builder /aws-cli-bin/ /usr/local/bin/

# Install OS dependencies.
RUN echo "System dependencies" && \
  apk add --update \
  bash \
  curl \
  git \
  tini \
  make \
  ca-certificates && \
  echo "MongoDB dependencies" && \
  apk add \
  mongodb-tools && \
  echo "Install migrate util" && \
  wget https://github.com/instoll/alpine-mongoshell/releases/download/0.1.0/migrate && \
  chmod 0755 migrate && \
  mv migrate /usr/bin

ENV CRON_TIME="0 3 * * *" \
  TZ=US/Eastern \
  CRON_TZ=US/Eastern

ADD run.sh /run.sh
CMD [ "/bin/bash", "/run.sh" ]