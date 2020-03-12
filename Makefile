# Make Redhook

STAGE?=dev

install:
	pipenv install

install-dev:
	pipenv install -d

test: install-dev
	pipenv run test

install-deploy-dependencies:
	npm install

create-domain: install-deploy-dependencies
	sls create_domain -s $(STAGE)

deploy: install-deploy-dependencies create-domain
	sls deploy -s $(STAGE)
