# Parameters for the cluster, don't edit these directly, put your changes in
# local-settings.mk.

GCE_REGION:=us-central1-f
GCE_PROJECT:=unique-caldron-775
SERVER_IMAGE_NAME:=centos-6-v20161027
CLIENT_IMAGE_NAME:=coreos-stable-1185-3-0-v20161101
NUM_CLIENTS:=1
PYINSTALLER_URL:=https://github.com/projectcalico/felix/releases/download/2.0.0-beta.3/calico-felix-2.0.0b3-git-4a1fa71.tgz
PREFIX:=memcache-test
SERVER_INSTANCE_TYPE:=n1-highcpu-8  # memcached seems to use up to 4 CPUs.
CLIENT_INSTANCE_TYPE:=n1-highcpu-16

NODE_NUMBERS := $(shell seq -f '%02.0f' 1 $(NUM_CLIENTS))
NODE_NAMES := $(addprefix $(PREFIX)-,$(NODE_NUMBERS))

-include local-settings.mk

gce-create:
	$(MAKE) --no-print-directory deploy-server
	$(MAKE) --no-print-directory deploy-clients

server-install.sh:
	cat "server-install-template.sh" | \
	  sed "s~__PYINSTALLER_URL__~$(PYINSTALLER_URL)~g" > $@;

client-config.yaml:
	cat "client-config-template.yaml" | \
	  sed "s~__PREFIX__~$(PREFIX)~g" > $@;

deploy-server: server-install.sh
	-gcloud compute instances create \
	  $(PREFIX)-server \
	  --zone $(GCE_REGION) \
	  --image-project centos-cloud \
	  --image $(SERVER_IMAGE_NAME) \
	  --machine-type $(SERVER_INSTANCE_TYPE) \
	  --local-ssd interface=scsi \
	  --metadata-from-file startup-script=server-install.sh & \
	  echo "Waiting for creation of server node to finish..." && \
	  wait && \
	  echo "server node started."

deploy-clients: client-config.yaml
	echo $(NODE_NAMES) | xargs -n250 | xargs -I{} sh -c 'gcloud compute instances create \
	  {} \
	  --zone $(GCE_REGION) \
	  --image-project coreos-cloud \
	  --image $(CLIENT_IMAGE_NAME) \
	  --machine-type $(CLIENT_INSTANCE_TYPE) \
	  --metadata-from-file user-data=client-config.yaml; \
	  echo "Waiting for creation of worker nodes to finish..." && \
		wait && \
		echo "Worker nodes created.";'

gce-cleanup:
	gcloud compute instances list --zones $(GCE_REGION) -r '$(PREFIX).*' | \
	  tail -n +2 | cut -f1 -d' ' | xargs gcloud compute instances delete --zone $(GCE_REGION)

clean:
	$(MAKE) --no-print-directory gce-cleanup
	rm -f server-install.sh client-config.yaml
