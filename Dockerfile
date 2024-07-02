FROM python:3.11-slim AS base

VOLUME /octobot/backtesting /octobot/logs /octobot/tentacles /octobot/user

RUN apt-get update && \
  apt-get install -y --no-install-recommends curl libxslt-dev libxcb-xinput0 libjpeg62-turbo-dev zlib1g-dev libblas-dev liblapack-dev libatlas-base-dev libopenjp2-7 libtiff-dev build-essential git gcc libffi-dev rsync libssl-dev libxml2-dev libxslt1-dev libxslt-dev libjpeg62-turbo-dev zlib1g-dev && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /octobot-requirements
COPY ./octobot-packages/OctoBot/requirements.txt ./OctoBot/requirements.txt
COPY ./octobot-packages/Async-Channel/requirements.txt ./Async-Channel/requirements.txt
COPY ./octobot-packages/OctoBot-Backtesting/requirements.txt ./OctoBot-Backtesting/requirements.txt
COPY ./octobot-packages/OctoBot-Commons/requirements.txt ./OctoBot-Commons/requirements.txt
COPY ./octobot-packages/OctoBot-evaluators/requirements.txt ./OctoBot-evaluators/requirements.txt
COPY ./octobot-packages/OctoBot-Services/requirements.txt ./OctoBot-Services/requirements.txt
COPY ./octobot-packages/OctoBot-Tentacles-Manager/requirements.txt ./OctoBot-Tentacles-Manager/requirements.txt
COPY ./octobot-packages/OctoBot-Trading/requirements.txt ./OctoBot-Trading/requirements.txt
COPY ./octobot-packages/trading-backend/requirements.txt ./trading-backend/requirements.txt

RUN python -m venv /opt/venv && \
  export CRYPTOGRAPHY_DONT_BUILD_RUST=1 && \
  export PATH="/opt/venv/bin:$PATH" && \
  pip install --upgrade setuptools wheel pip>=20.0.0 && \
  pip install --prefer-binary -r Async-Channel/requirements.txt -r OctoBot/requirements.txt -r OctoBot-Backtesting/requirements.txt -r OctoBot-Commons/requirements.txt -r OctoBot-evaluators/requirements.txt -r OctoBot-Services/requirements.txt -r OctoBot-Tentacles-Manager/requirements.txt -r OctoBot-Trading/requirements.txt -r trading-backend/requirements.txt

FROM python:3.11-slim AS final

WORKDIR /
COPY --from=base /root/.cache/pip /root/.cache/pip
COPY /octobot-packages /octobot-packages

RUN for directory in octobot-packages/*/; do \
  cd $directory; \
  pip install ./; \
  cd -; \
  done

WORKDIR /octobot-packages/OctoBot
RUN python setup.py install

COPY /octobot-packages/OctoBot/docker-entrypoint.sh docker-entrypoint.sh
RUN ln -s /opt/venv/bin/Octane Octane && chmod +x docker-entrypoint.sh && chmod +x Octane

EXPOSE 5001
HEALTHCHECK --interval=1m --timeout=30s --retries=3 CMD curl --fail http://localhost:5001 || exit 1
ENTRYPOINT ["sh","./docker-entrypoint.sh"]
