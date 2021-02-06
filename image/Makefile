ARTIFACTS = \
  debian.img \
  packer_cache \
  output-debian


.PHONY: all clean

all: debian.img
	@:

clean:
	rm -rf $(ARTIFACTS)

debian.img: output-debian/debian.vmdk
	vbox-img convert --srcfilename $< --dstformat RAW --dstfilename $@

output-debian/debian.vmdk:
	packer build build.pkr.hcl
	ln output-debian/debian-*.vmdk $@
