# syntax=docker/dockerfile:1.4
ARG EL_VERSION="8"
FROM registry.access.redhat.com/ubi${EL_VERSION}/ubi-minimal:latest
# Pick args from .env file
ARG PY_VERSION
ARG AIRFLOW_VERSION
ARG AIRFLOW_EXTRAS

ARG AIRFLOW_HOME="/opt/airflow"
ARG AIRFLOW_UID="50000"
ARG AIRFLOW_USER_HOME_DIR="/home/airflow"
# See https://dev.mysql.com/downloads/repo/yum/ for version info
ARG MYSQL_RPM_REPO_VERSION="el8-9"
SHELL ["/bin/bash", "-o", "pipefail", "-o", "errexit", "-o", "nounset", "-o", "nolog", "-c"]

USER root
ENV AIRFLOW_VERSION=${AIRFLOW_VERSION} \
    AIRFLOW_HOME=${AIRFLOW_HOME}
ENV AIRFLOW__CORE__ALLOWED_DESERIALIZATION_CLASSES_REGEXP="models\.resource\.*"


RUN mkdir -pv $AIRFLOW_HOME

RUN mkdir -pv ${AIRFLOW_HOME}/logs && \
    mkdir -pv ${AIRFLOW_HOME}/dags && \
    mkdir -pv ${AIRFLOW_HOME}/plugins && \
    mkdir -pv ${AIRFLOW_HOME}/config && \
    mkdir -pv ${AIRFLOW_HOME}/requirements

RUN microdnf install -y make mesa-libGL

RUN rpm -i https://dev.mysql.com/get/mysql80-community-release-${MYSQL_RPM_REPO_VERSION}.noarch.rpm
RUN microdnf install -y nc git shadow-utils pkgconfig gcc-c++ libffi libffi-devel findutils wget ca-certificates curl openssh tar \
    mysql-devel \
    python${PY_VERSION} python${PY_VERSION}-devel python${PY_VERSION}-setuptools python${PY_VERSION}-pip && \
    microdnf clean all && \
    rm -rf /var/cache/yum

RUN useradd -ms /bin/bash -u ${AIRFLOW_UID} -d ${AIRFLOW_USER_HOME_DIR} -g 0 airflow

RUN \
    python${PY_VERSION} -m venv ${AIRFLOW_HOME} && \
    echo "unset BASH_ENV PROMPT_COMMAND ENV" >> ${AIRFLOW_HOME}/bin/activate

ENV BASH_ENV="${AIRFLOW_HOME}/bin/activate" \
    ENV="${AIRFLOW_HOME}/bin/activate" \
    PROMPT_COMMAND=". ${AIRFLOW_HOME}/bin/activate"

COPY .devcontainer/entrypoint.sh ${AIRFLOW_HOME}/entrypoint.sh
COPY config/webserver_config.py ${AIRFLOW_HOME}/webserver_config.py
# COPY config/airflow_local_settings.py ${AIRFLOW_HOME}/config/airflow_local_settings.py
COPY plugins ${AIRFLOW_HOME}/plugins
COPY requirements ${AIRFLOW_HOME}/requirements

RUN chmod +x ${AIRFLOW_HOME}/entrypoint.sh

RUN \
    chown -R airflow:root ${AIRFLOW_USER_HOME_DIR} && \
    chown -R airflow:root ${AIRFLOW_HOME}

USER airflow
ENV ENV_TYPE="local"

ENV PATH="${AIRFLOW_HOME}/bin:${PATH}" \
    AIRFLOW__CORE__LOAD_EXAMPLES="false" \
    GUNICORN_CMD_ARGS="--worker-tmp-dir /dev/shm"

ENV PYTHONPATH="${AIRFLOW_HOME}:${PYTHONPATH:-}"

RUN pip${PY_VERSION} install --no-cache-dir "apache-airflow[${AIRFLOW_EXTRAS}]==${AIRFLOW_VERSION}" \
    --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PY_VERSION}.txt"
RUN pip${PY_VERSION} install --no-cache-dir -r ${AIRFLOW_HOME}/requirements/local.txt

WORKDIR ${AIRFLOW_HOME}
ENTRYPOINT ${AIRFLOW_HOME}/entrypoint.sh
