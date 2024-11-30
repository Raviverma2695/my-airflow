FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

ARG AIRFLOW_VERSION=2.10.3
ARG PYTHON_VERSION=3.12
ARG AIRFLOW_HOME=/opt/airflow
ARG AIRFLOW_UID="50000"
ARG AIRFLOW_USER_HOME_DIR="/home/airflow"
ARG AIRFLOW_EXTRAS="async,celery,cncf-kubernetes,docker,http,ssh,statsd,virtualenv,amazon,mysql"
ARG CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
ARG MYSQL_RPM_REPO_VERSION="el8-9"



USER root


ENV AIRFLOW_VERSION=${AIRFLOW_VERSION}
ENV AIRFLOW_HOME=${AIRFLOW_HOME}
ENV PYTHON_VERSION=${PYTHON_VERSION}
ENV CONSTRAINT_URL=${CONSTRAINT_URL}

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
    python${PYTHON_VERSION} python${PYTHON_VERSION}-devel python${PYTHON_VERSION}-setuptools python${PYTHON_VERSION}-pip && \
    microdnf clean all && \
    rm -rf /var/cache/yum

RUN useradd -ms /bin/bash -u ${AIRFLOW_UID} -d ${AIRFLOW_USER_HOME_DIR} -g 0 airflow    


RUN \
    python${PYTHON_VERSION} -m venv ${AIRFLOW_HOME} && \
    echo "unset BASH_ENV PROMPT_COMMAND ENV" >> ${AIRFLOW_HOME}/bin/activate


ENV BASH_ENV="${AIRFLOW_HOME}/bin/activate" \
    ENV="${AIRFLOW_HOME}/bin/activate" \
    PROMPT_COMMAND=". ${AIRFLOW_HOME}/bin/activate"


COPY .devcontainer/entrypoint.sh ${AIRFLOW_HOME}/entrypoint.sh
COPY config/webserver_config.py ${AIRFLOW_HOME}/webserver_config.py
COPY config/airflow_local_settings.py ${AIRFLOW_HOME}/config/airflow_local_settings.py
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

RUN pip${PYTHON_VERSION} install --no-cache-dir "apache-airflow[${AIRFLOW_EXTRAS}]==${AIRFLOW_VERSION}" \
    --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
RUN pip${PYTHON_VERSION} install --no-cache-dir -r ${AIRFLOW_HOME}/requirements/local.txt


WORKDIR ${AIRFLOW_HOME}
ENTRYPOINT ${AIRFLOW_HOME}/entrypoint.sh