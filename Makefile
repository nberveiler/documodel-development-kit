.NOTPARALLEL:

SHELL = /bin/bash

# Speed up Go module downloads
export GOPROXY ?= https://proxy.golang.org

# Generate a Makefile from Ruby and include it
include $(shell rake dmdk-config.mk)

documodel_clone_dir = documodel

quiet_bundle_flag = $(shell ${dmdk_quiet} && echo " | egrep -v '^Using '")
bundle_install_cmd = bundle install --jobs 4 --without production ${quiet_bundle_flag}

# Borrowed from https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Makefile#n87
#
ifeq ($(dmdk_debug),true)
	Q =
	QQ =
else
	Q = @
	QQ = > /dev/null
endif

ifeq ($(shallow_clone),true)
git_depth_param = --depth=1
endif

# This is used by `dmdk install` and `dmdk reconfigure`
#
all: preflight-checks \
documodel-setup \
support-setup \
prom-setup \
object-storage-setup

# This is used by `dmdk update`
#
# Pull documodel directory first since dependencies are linked from there.
update: ensure-databases-running \
unlock-dependency-installers \
documodel/.git/pull \
documodel-update \
show-updated-at

# This is used by `dmdk reconfigure`
#
reconfigure: touch-examples \
unlock-dependency-installers \
postgresql-sensible-defaults \
all \
show-reconfigured-at

self-update: unlock-dependency-installers
	@echo
	@echo "------------------------------------------------------------"
	@echo "Running self-update on DMDK"
	@echo "------------------------------------------------------------"
	$(Q)cd ${documodel_development_root} && \
		git stash ${QQ} && \
		git checkout master ${QQ} && \
		git fetch ${QQ} && \
		support/self-update-git-worktree ${QQ}

clean-config:
	$(Q)rm -rf \
	documodel/config/documodel.yml \
	documodel/config/database.yml \
	documodel/config/unicorn.rb \
	documodel/config/puma.rb \
	documodel/config/puma_actioncable.rb \
	documodel/config/cable.yml \
	documodel/config/resque.yml \
	redis/redis.conf \
	.ruby-version \
	Procfile \
	nginx/conf/nginx.conf \
	registry_host.crt \
	registry_host.key \
	localhost.crt \
	localhost.key \
	registry/config.yml \
	jaeger

touch-examples:
	$(Q)touch \
	Procfile.erb \
	documodel/config/puma.example.development.rb \
	documodel/config/puma_actioncable.example.development.rb \
	documodel/config/unicorn.rb.example.development \
	grafana/grafana.ini.example \
	support/templates/*.erb

unlock-dependency-installers:
	$(Q)rm -f \
	.documodel-bundle \
	.documodel-yarn \
	.gettext \

dmdk.yml:
	$(Q)touch $@

.PHONY: Procfile
Procfile:
	$(Q)rake $@

.PHONY: preflight-checks
preflight-checks: rake
	$(Q)rake $@

.PHONY: rake
rake:
	$(Q)command -v $@ ${QQ} || gem install $@

.PHONY: ensure-databases-running
ensure-databases-running: Procfile postgresql/data
	$(Q)dmdk start rails-migration-dependencies

##############################################################
# DocuModel
##############################################################

documodel-setup: documodel/.git .ruby-version documodel-config .documodel-bundle .documodel-yarn .gettext

documodel-update: ensure-databases-running postgresql documodel/.git/pull documodel-setup documodel-db-migrate

documodel/.git/pull:
	@echo
	@echo "------------------------------------------------------------"
	@echo "Updating documodel-org/documodel to current master"
	@echo "------------------------------------------------------------"
	$(Q)cd ${documodel_development_root}/documodel && \
		git checkout -- Gemfile.lock $$(git ls-tree HEAD --name-only db/structure.sql db/schema.rb) ${QQ} && \
		git stash ${QQ} && \
		git checkout master ${QQ} && \
		git pull --ff-only ${QQ}

documodel-db-migrate:
	@echo
	@echo "------------------------------------------------------------"
	@echo "Processing documodel-org/documodel Rails DB migrations"
	@echo "------------------------------------------------------------"
	$(Q)cd ${documodel_development_root}/documodel && \
		bundle exec rake db:migrate db:test:prepare

.ruby-version:
	$(Q)ln -s ${documodel_development_root}/documodel/.ruby-version ${documodel_development_root}/$@

documodel/.git:
	$(Q)git clone ${git_depth_param} ${documodel_repo} ${documodel_clone_dir} $(if $(realpath ${documodel_repo}),--shared)

documodel-config: documodel/config/documodel.yml documodel/config/database.yml documodel/config/unicorn.rb documodel/config/cable.yml documodel/config/resque.yml documodel/public/uploads documodel/config/puma.rb documodel/config/puma_actioncable.rb

.PHONY: documodel/config/documodel.yml
documodel/config/documodel.yml:
	$(Q)rake documodel/config/documodel.yml

.PHONY: documodel/config/database.yml
documodel/config/database.yml:
	$(Q)rake $@

# Versions older than DocuModel 11.5 won't have this file
documodel/config/puma.example.development.rb:
	$(Q)touch $@

documodel/config/puma.rb: documodel/config/puma.example.development.rb
	$(Q)bin/safe-sed "$@" \
		-e "s|/home/git|${documodel_development_root}|g" \
		"$<"

# Versions older than DocuModel 12.9 won't have this file
documodel/config/puma_actioncable.example.development.rb:
	$(Q)touch $@

documodel/config/puma_actioncable.rb: documodel/config/puma_actioncable.example.development.rb
	$(Q)bin/safe-sed "$@" \
		-e "s|/home/git|${documodel_development_root}|g" \
		"$<"

documodel/config/unicorn.rb: documodel/config/unicorn.rb.example.development
	$(Q)bin/safe-sed "$@" \
		-e "s|/home/git|${documodel_development_root}|g" \
		"$<"

.PHONY: documodel/config/cable.yml
documodel/config/cable.yml:
	$(Q)rake $@

.PHONY: documodel/config/resque.yml
documodel/config/resque.yml:
	$(Q)rake $@

documodel/public/uploads:
	$(Q)mkdir $@

.documodel-bundle:
	@echo
	@echo "------------------------------------------------------------"
	@echo "Installing documodel-org/documodel Ruby gems"
	@echo "------------------------------------------------------------"
	$(Q)cd ${documodel_development_root}/documodel && $(bundle_install_cmd)
	$(Q)touch $@

.documodel-yarn:
	@echo
	@echo "------------------------------------------------------------"
	@echo "Installing documodel-org/documodel Node.js packages"
	@echo "------------------------------------------------------------"
	$(Q)cd ${documodel_development_root}/documodel && yarn install --pure-lockfile ${QQ}
	$(Q)touch $@

.gettext:
	@echo
	@echo "------------------------------------------------------------"
	@echo "Generating documodel-org/documodel Rails translations"
	@echo "------------------------------------------------------------"
	$(Q)cd ${documodel_development_root}/documodel && bundle exec rake gettext:compile > ${documodel_development_root}/documodel/log/gettext.log
	$(Q)git -C ${documodel_development_root}/documodel checkout locale/*/documodel.po
	$(Q)touch $@

##############################################################
# documodel-docs
##############################################################

documodel-docs-setup: documodel-docs/.git documodel-docs-bundle documodel-docs/nanoc.yaml symlink-documodel-docs

documodel-docs/.git:
	$(Q)git clone ${git_depth_param} ${documodel_docs_repo} documodel-docs

documodel-docs/.git/pull:
	@echo
	@echo "------------------------------------------------------------"
	@echo "Updating documodel-org/documodel-docs to master"
	@echo "------------------------------------------------------------"
	$(Q)cd documodel-docs && \
		git stash ${QQ} && \
		git checkout master ${QQ} &&\
		git pull --ff-only ${QQ}

# We need to force delete since there's already a nanoc.yaml file
# in the docs folder which we need to overwrite.
documodel-docs/rm-nanoc.yaml:
	$(Q)rm -f documodel-docs/nanoc.yaml

documodel-docs/nanoc.yaml: documodel-docs/rm-nanoc.yaml
	$(Q)cp nanoc.yaml.example $@

documodel-docs-bundle:
	$(Q)cd ${documodel_development_root}/documodel-docs && $(bundle_install_cmd)

symlink-documodel-docs:
	$(Q)support/symlink ${documodel_development_root}/documodel-docs/content/ee ${documodel_development_root}/documodel/doc

documodel-docs-update: documodel-docs/.git/pull documodel-docs-bundle documodel-docs/nanoc.yaml

##############################################################
# documodel performance metrics
##############################################################

performance-metrics-setup: Procfile grafana-setup

##############################################################
# documodel support setup
##############################################################

support-setup: Procfile redis jaeger-setup postgresql openssh-setup nginx-setup registry-setup
ifeq ($(auto_devops_enabled),true)
	@echo
	@echo "------------------------------------------------------------"
	@echo "Tunnel URLs"
	@echo
	@echo "DocuModel: https://${hostname}"
	@echo "Registry: https://${registry_host}"
	@echo "------------------------------------------------------------"
endif

##############################################################
# redis
##############################################################

redis: redis/redis.conf

.PHONY: redis/redis.conf
redis/redis.conf:
	$(Q)rake $@

##############################################################
# postgresql
##############################################################

postgresql: postgresql/data postgresql/port postgresql-seed-rails

postgresql/data:
	$(Q)${postgresql_bin_dir}/initdb --locale=C -E utf-8 ${postgresql_data_dir}

.PHONY: postgresql-seed-rails
postgresql-seed-rails: ensure-databases-running
	$(Q)support/bootstrap-rails

postgresql/port:
	$(Q)support/postgres-port ${postgresql_dir} ${postgresql_port}

postgresql-sensible-defaults:
	$(Q)support/postgresql-sensible-defaults ${postgresql_dir}

##############################################################
# postgresql replication
##############################################################

postgresql-replication-primary: postgresql-replication/access postgresql-replication/role postgresql-replication/config

postgresql-replication-secondary: postgresql-replication/data postgresql-replication/access postgresql-replication/backup postgresql-replication/config

postgresql-replication-primary-create-slot: postgresql-replication/slot

postgresql-replication/data:
	${postgresql_bin_dir}/initdb --locale=C -E utf-8 ${postgresql_data_dir}

postgresql-replication/access:
	$(Q)cat support/pg_hba.conf.add >> ${postgresql_data_dir}/pg_hba.conf

postgresql-replication/role:
	$(Q)${postgresql_bin_dir}/psql -h ${postgresql_host} -p ${postgresql_port} -d postgres -c "CREATE ROLE ${postgresql_replication_user} WITH REPLICATION LOGIN;"

postgresql-replication/backup:
	$(Q)$(eval postgresql_primary_dir := $(realpath postgresql-primary))
	$(Q)$(eval postgresql_primary_host := $(shell cd ${postgresql_primary_dir}/../ && dmdk config get postgresql.host 2>/dev/null))
	$(Q)$(eval postgresql_primary_port := $(shell cd ${postgresql_primary_dir}/../ && dmdk config get postgresql.port 2>/dev/null))

	$(Q)psql -h ${postgresql_primary_host} -p ${postgresql_primary_port} -d postgres -c "select pg_start_backup('base backup for streaming rep')"
	$(Q)rsync -cva --inplace --exclude="*pg_xlog*" --exclude="*.pid" ${postgresql_primary_dir}/data postgresql
	$(Q)psql -h ${postgresql_primary_host} -p ${postgresql_primary_port} -d postgres -c "select pg_stop_backup(), current_timestamp"
	$(Q)./support/recovery.conf ${postgresql_primary_host} ${postgresql_primary_port} > ${postgresql_data_dir}/recovery.conf
	$(Q)$(MAKE) postgresql/port ${QQ}

postgresql-replication/slot:
	$(Q)${postgresql_bin_dir}/psql -h ${postgresql_host} -p ${postgresql_port} -d postgres -c "SELECT * FROM pg_create_physical_replication_slot('documodel_dmdk_replication_slot');"

postgresql-replication/list-slots:
	$(Q)${postgresql_bin_dir}/psql -h ${postgresql_host} -p ${postgresql_port} -d postgres -c "SELECT * FROM pg_replication_slots;"

postgresql-replication/drop-slot:
	$(Q)${postgresql_bin_dir}/psql -h ${postgresql_host} -p ${postgresql_port} -d postgres -c "SELECT * FROM pg_drop_replication_slot('documodel_dmdk_replication_slot');"

postgresql-replication/config:
	$(Q)./support/postgres-replication ${postgresql_dir}

##############################################################
# influxdb
##############################################################

influxdb-setup:
	$(Q)echo "INFO: InfluxDB was removed from the DMDK by https://documodel.com/documodel-org/documodel-development-kit/-/issues/927"

##############################################################
# minio / object storage
##############################################################

object-storage-setup: minio/data/lfs-objects minio/data/artifacts minio/data/uploads minio/data/packages

minio/data/%:
	$(Q)mkdir -p $@

##############################################################
# prometheus
##############################################################

prom-setup:
	$(Q)[ "$(uname -s)" = "Linux" ] && sed -i -e 's/docker\.for\.mac\.localhost/localhost/g' ${documodel_development_root}/prometheus/prometheus.yml || true

##############################################################
# grafana
##############################################################

grafana-setup: grafana/grafana.ini grafana/bin/grafana-server grafana/dmdk-pg-created grafana/dmdk-data-source-created

grafana/bin/grafana-server:
	$(Q)cd grafana && ${MAKE} ${QQ}

grafana/grafana.ini: grafana/grafana.ini.example
	$(Q)bin/safe-sed "$@" \
		-e "s|/home/git|${documodel_development_root}|g" \
		-e "s/DMDK_USERNAME/${username}/g" \
		"$<"

grafana/dmdk-pg-created:
	$(Q)support/create-grafana-db
	$(Q)touch $@

grafana/dmdk-data-source-created:
	$(Q)grep '^grafana:' Procfile || (printf ',s/^#grafana/grafana/\nwq\n' | ed -s Procfile)
	$(Q)touch $@

##############################################################
# openssh
##############################################################

openssh-setup: openssh/sshd_config openssh/ssh_host_rsa_key

openssh/ssh_host_rsa_key:
	$(Q)ssh-keygen -f $@ -N '' -t rsa

nginx-setup: nginx/conf/nginx.conf nginx/logs nginx/tmp

.PHONY: nginx/conf/nginx.conf
nginx/conf/nginx.conf:
	$(Q)rake $@

.PHONY: openssh/sshd_config
openssh/sshd_config:
	$(Q)rake $@

##############################################################
# nginx
##############################################################

nginx/logs:
	$(Q)mkdir -p $@

nginx/tmp:
	$(Q)mkdir -p $@

##############################################################
# registry
##############################################################

registry-setup: registry/storage registry/config.yml localhost.crt

localhost.crt: localhost.key

localhost.key:
	$(Q)openssl req -new -subj "/CN=${registry_host}/" -x509 -days 365 -newkey rsa:2048 -nodes -keyout "localhost.key" -out "localhost.crt"
	$(Q)chmod 600 $@

registry_host.crt: registry_host.key

registry_host.key:
	$(Q)openssl req -new -subj "/CN=${registry_host}/" -x509 -days 365 -newkey rsa:2048 -nodes -keyout "registry_host.key" -out "registry_host.crt"
	$(Q)chmod 600 $@

registry/storage:
	$(Q)mkdir -p $@

.PHONY: registry/config.yml
registry/config.yml: registry_host.crt
	$(Q)rake $@

.PHONY: trust-docker-registry
trust-docker-registry: registry_host.crt
	$(Q)mkdir -p "${HOME}/.docker/certs.d/${registry_host}:${registry_port}"
	$(Q)rm -f "${HOME}/.docker/certs.d/${registry_host}:${registry_port}/ca.crt"
	$(Q)cp registry_host.crt "${HOME}/.docker/certs.d/${registry_host}:${registry_port}/ca.crt"
	$(Q)echo "Certificates have been copied to ~/.docker/certs.d/"
	$(Q)echo "Don't forget to restart Docker!"

##############################################################
# jaeger
##############################################################

ifeq ($(jaeger_server_enabled),true)
.PHONY: jaeger-setup
jaeger-setup: jaeger/jaeger-${jaeger_version}/jaeger-all-in-one
else
.PHONY: jaeger-setup
jaeger-setup:
	@true
endif

jaeger-artifacts/jaeger-${jaeger_version}.tar.gz:
	$(Q)mkdir -p $(@D)
	$(Q)./bin/download-jaeger "${jaeger_version}" "$@"
	# To save disk space, delete old versions of the download,
	# but to save bandwidth keep the current version....
	$(Q)find jaeger-artifacts ! -path "$@" -type f -exec rm -f {} + -print

jaeger/jaeger-${jaeger_version}/jaeger-all-in-one: jaeger-artifacts/jaeger-${jaeger_version}.tar.gz
	@echo
	@echo "------------------------------------------------------------"
	@echo "Installing jaeger ${jaeger_version}"
	@echo "------------------------------------------------------------"

	$(Q)mkdir -p "jaeger/jaeger-${jaeger_version}"
	$(Q)tar -xf "$<" -C "jaeger/jaeger-${jaeger_version}" --strip-components 1

##############################################################
# Tests
##############################################################

.PHONY: test
test: lint rubocop rspec

.PHONY: rubocop
rubocop:
	$(Q)bundle exec rubocop --config .rubocop-dmdk.yml --parallel

.PHONY: rspec
rspec:
	$(Q)bundle exec rspec

.PHONY: eclint
eclint: install-eclint
	$(Q)eclint check $$(git ls-files) || (echo "editorconfig check failed. Please run \`make correct\`" && exit 1)

.PHONY: correct
correct: correct-editorconfig

.PHONY: correct-editorconfig
correct-editorconfig: install-eclint
	$(Q)eclint fix $$(git ls-files)

.PHONY: install-eclint
install-eclint:
	$(Q)(command -v eclint > /dev/null) || \
	((command -v npm > /dev/null) && npm install -g eclint) || \
	((command -v yarn > /dev/null) && yarn global add eclint)

.PHONY: lint
lint: eclint lint-vale lint-markdown

.PHONY: install-vale
install-vale:
	$(Q)(command -v vale > /dev/null) || go get github.com/errata-ai/vale

.PHONY: lint-vale
lint-vale: install-vale
	$(Q)vale --minAlertLevel error *.md doc

.PHONY: install-markdownlint
install-markdownlint:
	$(Q)(command -v markdownlint > /dev/null) || \
	((command -v npm > /dev/null) && npm install -g markdownlint-cli) || \
	((command -v yarn > /dev/null) && yarn global add markdownlint-cli)

.PHONY: lint-markdown
lint-markdown: install-markdownlint
	$(Q)markdownlint --config .markdownlint.json 'doc/**/*.md'

##############################################################
# Misc
##############################################################

.PHONY: ask-to-restart
ask-to-restart:
	@echo
	$(Q)support/ask-to-restart
	@echo

.PHONY: show-updated-at
show-updated-at:
	@echo
	@echo "> Updated as of $$(date +"%Y-%m-%d %T")"

.PHONY: show-reconfigured-at
show-reconfigured-at:
	@echo
	@echo "> Reconfigured as of $$(date +"%Y-%m-%d %T")"
