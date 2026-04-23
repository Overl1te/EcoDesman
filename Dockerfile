FROM python:3.12-slim-bookworm AS python-runtime

FROM postgres:16-bookworm

ARG PIP_INDEX_URL=https://pypi.org/simple
ARG PIP_EXTRA_INDEX_URL=
ARG PIP_TRUSTED_HOST=
ARG PIP_DEFAULT_TIMEOUT=120
ARG PIP_RETRIES=15

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_ROOT_USER_ACTION=ignore
ENV PIP_INDEX_URL=${PIP_INDEX_URL}
ENV PIP_EXTRA_INDEX_URL=${PIP_EXTRA_INDEX_URL}
ENV PIP_TRUSTED_HOST=${PIP_TRUSTED_HOST}
ENV PIP_DEFAULT_TIMEOUT=${PIP_DEFAULT_TIMEOUT}
ENV PIP_RETRIES=${PIP_RETRIES}

WORKDIR /app

# Reuse the official Python runtime on top of the PostgreSQL image so the
# container has both Python and pg_dump/pg_restore without apt-get at build time.
COPY --from=python-runtime /usr/local /usr/local

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements ./requirements
RUN python -m pip install --no-cache-dir -r requirements/base.txt

COPY . .

EXPOSE 8000

CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--timeout", "60"]
