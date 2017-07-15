SCC = "nlknguyen/alpine-shellcheck:latest"
all: test

test: .bats
# start with some docker shellcheck
	docker pull $(SCC)
	for file in *.sh ; do \
		docker run --rm -v $(CURDIR):/mnt $(SCC) /mnt/$$file || exit ; \
	done
	sleep 299

.bats-git:
	git clone --depth=1 https://github.com/sstephenson/bats.git .bats-git

.bats: .bats-git
	cd $(CURDIR)/.bats-git && ./install.sh $(CURDIR)/.bats && cd $(CURDIR)

distclean:
	rm -rf .bats-git .bats
