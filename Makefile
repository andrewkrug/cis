ROOT_DIR	:= $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
STAGE			:= ${STAGE}
STAGE			:= $(if $(STAGE),$(STAGE),testing)

all:
	@echo 'Available make targets:'
	@grep '^[^#[:space:]^\.PHONY.*].*:' Makefile

docker-build:
	docker build -t mozillaiam/cis-dev-preview:latest .

docker-run:
	@echo "Starting Docker..."
	@echo "/!\ Creating a fake database of users WILL TAKE SOME TIME."
	@echo "/!\ Wait a bit before querying the service!"
	docker run -p 80:80 \
	  -e AWS_ACCESS_KEY_ID="fake" \
	  -e AWS_SECRET_ACCESS_KEY="fake" \
	  -e AWS_DEFAULT_REGION="us-west-2" \
	  -ti mozillaiam/cis-dev-preview:latest supervisord -c /opt/cis/conf/supervisor.conf

preview-shell:
	docker run -ti mozillaiam/cis-dev-preview:latest /bin/bash

.PHONY: login-to-ecr
login-to-ecr:
	aws ecr get-login --no-include-email | bash

.PHONY: deploy-shell
deploy-shell: login-to-ecr
	docker pull 320464205386.dkr.ecr.us-west-2.amazonaws.com/custom-codebuild-cis-ci:latest
	docker run -ti -v ~/.aws:/root/.aws -v ${PWD}:/var/task 320464205386.dkr.ecr.us-west-2.amazonaws.com/custom-codebuild-cis-ci:latest /bin/bash

.PHONY: build
build:
	$(MAKE) -C serverless-functions layer-codebuild STAGE=$(STAGE)

.PHONY: release
release:
	$(MAKE) -C serverless-functions deploy-change-service STAGE=$(STAGE)
	$(MAKE) -C serverless-functions deploy-ldap-publisher STAGE=$(STAGE)
	$(MAKE) -C serverless-functions deploy-person-api STAGE=$(STAGE)
	$(MAKE) -C serverless-functions deploy-notifications STAGE=$(STAGE)
	$(MAKE) -C serverless-functions deploy-curator STAGE=$(STAGE)
	$(MAKE) -C serverless-functions deploy-hris-publisher STAGE=$(STAGE)

.PHONY: build-ci-container
build-ci-container:
	cd ci && docker build . -t 320464205386.dkr.ecr.us-west-2.amazonaws.com/custom-codebuild-cis-ci

.PHONY: login-to-ecr upload-ci-container
push-ci-container:
	docker push 320464205386.dkr.ecr.us-west-2.amazonaws.com/custom-codebuild-cis-ci

.PHONY: test
test:
	docker-compose build
	docker-compose run tester bash -c '/root/utils/fake-creds.sh && source /root/.bashrc && make -j4 test-tox'

.PHONY: developer-shell
developer-shell:
	@echo 'launching docker compose environment with all the bells and whistles'
	docker-compose run tester