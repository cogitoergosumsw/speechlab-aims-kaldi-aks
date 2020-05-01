from kubernetes import client, config
import logging
from kubernetes.client.rest import ApiException
import random
import string
import os
import sys


import logging

# TODO: remember to change this field to the name of Docker image used
IMAGE = "heyhujiao/kaldi-speechlab"
MASTER = os.getenv("MASTER", False)
NAMESPACE = os.getenv("NAMESPACE", False)

if (NAMESPACE == False or
    MASTER == False or
    NAMESPACE == False):
    sys.exit("No values for NAMESPACE="
             + str(NAMESPACE)
             + " MASTER="+str(MASTER)
             + " NAMESPACE="+str(NAMESPACE))

config.load_kube_config()


def spawn_worker(model):
    """
    Spawn a new worker with the model specified if all the workers are in use.
    Call this function before pop()
    Will not spawn new worker when running as docker-compose up, check 'master:8080'

    model : str
        The name of model
    """
    if MASTER == 'master:8080':
        return

    logging.info("start to spawn a new worker with model="+model)
    create_job(model)


def id_generator(size=6, chars=string.ascii_lowercase + string.digits):
    return ''.join(random.choice(chars) for _ in range(size))


def create_job(MODEL):

    assert MODEL is not None, "model name is None, cannot spawn a new worker"

    api = client.BatchV1Api()

    body = client.V1Job(api_version="batch/v1", kind="Job")
    name = 'speechlab-worker-job-{}-{}'.format(
        MODEL.lower().replace("_", "-"), id_generator())
    body.metadata = client.V1ObjectMeta(namespace=NAMESPACE, name=name)
    body.status = client.V1JobStatus()
    template = client.V1PodTemplate()
    template.template = client.V1PodTemplateSpec()
    template.template.metadata = client.V1ObjectMeta(
        annotations={
            "prometheus.io/scrape": "true",
            "prometheus.io/port": "8081"
        }
    )
    volume = client.V1Volume(
        # change these values to the same names you used in deployment.yaml
        name="local-models",
        persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(
            claim_name="local-models-pvc"
        )
    )
    env_vars = {
        "MASTER": MASTER,
        "NAMESPACE": NAMESPACE,
        "RUN_FREQ": "ONCE",
        "MODEL_DIR": MODEL,  # important
    }

    env_list = []
    if env_vars:
        for env_name, env_value in env_vars.items():
            env_list.append(client.V1EnvVar(name=env_name, value=env_value))

    container = client.V1Container(name='{}-c'.format(name),
                                   image=IMAGE,
                                   image_pull_policy="IfNotPresent",
                                   command=["/home/appuser/opt/tini", "--",
                                            "/home/appuser/opt/start_worker.sh"],
                                   env=env_list,
                                   ports=[client.V1ContainerPort(
                                       container_port=8081,
                                       name="prometheus"
                                   )],
                                   security_context=client.V1SecurityContext(
                                       privileged=True, capabilities=client.V1Capabilities(add=["SYS_ADMIN"])),
                                   resources=client.V1ResourceRequirements(
                                       limits={"memory": "5G", "cpu": "1"}, 
                                       requests={"memory": "5G", "cpu": "1"}
                                       ),
                                   volume_mounts=[client.V1VolumeMount(
                                        # change these values to the same names you used in deployment.yaml
                                        mount_path="/home/appuser/opt/models",
                                        name="local-models",
                                        read_only=True
                                    )]
    )
    template.template.spec = client.V1PodSpec(containers=[container],
                                              image_pull_secrets=[
                                                  {"name": "azure-cr-secret"}],
                                              # reason to use OnFailure https://github.com/kubernetes/kubernetes/issues/20255
                                              restart_policy="OnFailure",
                                              volumes=[volume]
                                              )

    # And finaly we can create our V1JobSpec!
    body.spec = client.V1JobSpec(
        ttl_seconds_after_finished=100, template=template.template)

    try:
        api_response = api.create_namespaced_job(NAMESPACE, body)
        print("api_response="+ str(api_response))
        return True
    except ApiException as e:
        logging.exception('error spawning new job')
        print("Exception when creating a job: %s\n" % e)
