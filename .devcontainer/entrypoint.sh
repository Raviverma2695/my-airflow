#!/bin/bash
echo "Starting entrypoint.sh"
#echo print ls -la /workspace   
echo "ls -la /workspace"
ls -la /workspace
rm -rf /opt/airflow/dags /opt/airflow/logs /opt/airflow/plugins /opt/airflow/airflow.cfg /opt/airflow/*.py
ln -svf /workspace/dags /opt/airflow/
ln -svf /workspace/logs /opt/airflow/
ln -svf /workspace/plugins /opt/airflow/
ln -svf /workspace/config/airflow.cfg /opt/airflow/airflow.cfg
mkdir -p /opt/airflow/config
# ln -svf /workspace/config/airflow_local_settings.py /opt/airflow/config/airflow_local_settings.py

if [ ! -f /workspace/config/fernet.key ]; then
    echo "Generating fernet key"
    python -c 'from cryptography.fernet import Fernet;fernet_key = Fernet.generate_key();print(fernet_key.decode())' >/workspace/config/fernet.key
fi
export AIRFLOW__CORE__FERNET_KEY=$(cat /workspace/config/fernet.key)

airflow db check -v
airflow db migrate

airflow scheduler &
airflow triggerer &

airflow users create --role Admin --username admin \
    --email admin@example.com \
    --firstname admin --lastname user \
    --password admin

if [ "$SYNC_LOCALHOST_KUBECONFIG" = "true" ]; then
    airflow connections add 'kubernetes_default' \
        --conn-json '{
        "conn_type": "kubernetes",
        "in_cluster": false,
        "kube_config_path": "~/.kube/config",
        "cluster_context": "kind-airflow",
        "namespace": "default",
        "disable_tcp_keepalive": false,
        "disable_verify_ssl": false
    }'
fi

airflow webserver
