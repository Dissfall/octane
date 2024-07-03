FROM python:3.11-slim AS base

WORKDIR /

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl libxslt-dev libxcb-xinput0 libjpeg62-turbo-dev zlib1g-dev libblas-dev liblapack-dev libatlas-base-dev libopenjp2-7 libtiff-dev build-essential git gcc libffi-dev rsync libssl-dev libxml2-dev libxslt1-dev libxslt-dev libjpeg62-turbo-dev zlib1g-dev \
  && python -m venv /opt/venv

ENV CRYPTOGRAPHY_DONT_BUILD_RUST=1
ENV PATH="/opt/venv/bin:$PATH"

COPY . .

WORKDIR /octobot-packages

RUN pip install --upgrade setuptools wheel pip>=20.0.0 \
  && pip install --prefer-binary -r Async-Channel/requirements.txt -r OctoBot/requirements.txt -r OctoBot-Backtesting/requirements.txt -r OctoBot-Commons/requirements.txt -r OctoBot-evaluators/requirements.txt -r OctoBot-Services/requirements.txt -r OctoBot-Tentacles-Manager/requirements.txt -r OctoBot-Trading/requirements.txt -r trading-backend/requirements.txt \
  && cd OctoBot && python setup.py install

FROM python:3.11-slim AS final

WORKDIR /octobot

ARG TENTACLES_URL_TAG=""
ENV TENTACLES_URL_TAG=$TENTACLES_URL_TAG

COPY --from=base /root/.cache/pip /root/.cache/pip
COPY --from=base /opt/venv /opt/venv
COPY octobot-packages/OctoBot/octobot/config /octobot/octobot/config
COPY /octobot-packages /octobot-packages

RUN export PATH="/opt/venv/bin:$PATH"

RUN for directory in /octobot-packages/*/; do \
  cd $directory; \
  pip install ./; \
  cd -; \
  done

COPY /octobot-packages/OctoBot/docker-entrypoint.sh docker-entrypoint.sh
RUN ln -s /opt/venv/bin/Octane Octane && chmod +x docker-entrypoint.sh && chmod +x Octane && rm -rf /opt/efs

VOLUME /octobot/backtesting /octobot/logs /octobot/tentacles /octobot/user

EXPOSE 5001
HEALTHCHECK --interval=1m --timeout=30s --retries=3 CMD curl --fail http://localhost:5001 || exit 1
ENTRYPOINT ["sh","./docker-entrypoint.sh"]
