IMAGE = ../image/debian.img

ARTIFACTS = \
  _init.ok \
  _instance.ok \
  _transfer.ok \
  _snapshot.ok \
  _sshkey \
  _sshkey.pub \
  _known_hosts \
  terraform.tfstate \
  terraform.tfstate.backup

SSHFLAGS = \
  -o IdentitiesOnly=yes \
  -o UserKnownHostsFile=_known_hosts


.PHONY: all clean destroy

all: _snapshot.ok
	@:

clean: destroy
	rm -f $(ARTIFACTS)

destroy:
	terraform destroy -auto-approve
	rm -f _instance.ok

_sshkey:
	ssh-keygen -t ed25519 -N "" -f $@

_init.ok:
	terraform init
	@touch $@

_instance.ok: _init.ok _sshkey
	terraform apply -auto-approve
	@touch $@

_transfer.ok: _instance.ok _sshkey
	gzip -c $(IMAGE) | ssh $(SSHFLAGS) -i _sshkey root@$$(terraform output -raw ip) "gzip -cd > /dev/sda"
	@touch $@

_snapshot.ok: _transfer.ok
	./snapshot.sh $$(terraform output -raw server_id)
	@touch $@
