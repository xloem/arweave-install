PREFIX ?= /usr/local

INST_USER ?= $(shell id -un $$SUDO_USER)
INST_GROUP ?= $(shell id -gn $$SUDO_USER)
CONFIG_PATH ?= $(PREFIX)/etc/arweave.json
ARWEAVE_DIR ?= $(PREFIX)/lib/arweave
DATA_DIR ?= $(PREFIX)/var/lib/arweave
DOC_DIR ?= $(PREFIX)/share/doc/arweave
LOG_DIR ?= /var/log/arweave
SYSCTL_CONF_DIR ?= /etc/sysctl.d

LOCAL_ARWEAVE_DIR = submodules/arweave/_build/prod/rel/arweave

$(LOCAL_ARWEAVE_DIR)/bin/arweave: submodules/arweave/rebar.config submodules/arweave/apps/arweave/lib/RandomX/CMakeLists.txt
	# build arweave
	cd submodules/arweave && ./rebar3 as prod release
	echo "Now run make install. Optionally specify INST_USER= and INST_GROUP= to set the user arweave will run as."

install: $(LOCAL_ARWEAVE_DIR)/bin/arweave config.json arweave.service config.json.doc
	mkdir -p "$(ARWEAVE_DIR)"
	mkdir -p "$(LOG_DIR)"
	mkdir -p "$(DOC_DIR)"
	cp -va "$(LOCAL_ARWEAVE_DIR)"/. "$(ARWEAVE_DIR)"/.
	-chown $(USER):$(GROUP) -R "$(ARWEAVE_DIR)" "$(DATA_DIR)" "$(LOG_DIR)"
	-cp --no-clobber -v confs/config.json "$(CONFIG_PATH)" 
	cp -v confs/arweave.service "$(PREFIX)"/lib/systemd/system/
	cp -v ai/config.json.doc "$(DOC_DIR)"/
	cp -v confs/99-arweave-sysctl.conf "$(SYSCTL_CONF_DIR)"/

uninstall:
	-rm -vrf "$(ARWEAVE_DIR)" "$(DOC_DIR)"
	echo "You may delete $(DATA_DIR) and/or $(LOG_DIR) manually."

$(DATA_DIR)/wallets: $(LOCAL_ARWEAVE_DIR)/bin/arweave
	mkdir -p "$(DATA_DIR)"
ifeq (,$(wildcard $(DATA_DIR)/wallets/*))
	"$(LOCAL_ARWEAVE_DIR)"/bin/create-wallet "$(DATA_DIR)"
endif

CONFIG_JSON_CTX=submodules/docs.arweave.org-info/mining/mining-guide.md ai/ar.erl.sed_show_help submodules/arweave/apps/arweave/include/ar_config.hrl ai/ar_config.erl.sed_parse_opts
ai/ar.erl.sed_show_help: submodules/arweave/apps/arweave/src/ar.erl
	sed -n '/^show_help() ->/{:1;p;n;/erlang:halt/!b1}' < $^ > $@
ai/ar_config.erl.sed_parse_opts: submodules/arweave/apps/arweave/src/ar_config.erl
	sed -n '/^%% @doc Parse the configuration options./{:1;p;n;/^[^p]/!b1}' < $^ > $@
confs/config.json.in: llm.py $(CONFIG_JSON_CTX)
	python3 llm.py --prompt "Generate the content for $(CONFIG_PATH) to install on a user's system. Make use of the template variables @CFG_DATA_DIR@, @CFG_MINING_ADDR@, and optionally @CFG_ARWEAVE_DIR@ or @CFG_LOG_DIR@, but do not use any other template variables. Do not provide extra formatting or commentary. Note that this is a json file and has different options available than the show_help function lists on the command line. The node should run correctly using only this config file, but where harmless it should also contain default values to help the user see what to provide." --files $(CONFIG_JSON_CTX) | tee $@
ai/config.json.doc.in: llm.py $(CONFIG_JSON_CTX)
	python3 llm.py --max-tokens 3072 --prompt "Generate the content for basic documentation of the $(CONFIG_PATH) or @CFG_CONFIG_PATH@ file installed on a user's system. The node runs correctly using only this config file. Make it clear the documentation (as well as the default-installed config file) is auto-generated via a language model. You may make use of the template variables @CFG_DATA_DIR@, @CFG_MINING_ADDR@, @CFG_ARWEAVE_DIR@, @CFG_LOG_DIR@, or @CFG_CONFIG_PATH@ if helpful. These will be automatically replaced with correct values. The documentation need only describe what the user needs to change from the defaults." --files $(CONFIG_JSON_CTX) | tee $@

%: %.in $(DATA_DIR)/wallets/*
	MINING_ADDR="$$(ls $(DATA_DIR)/wallets | sed -ne '1,1 s/arweave_keyfile_\(.*\)\.json/\1/p')" sed -e 's!@CFG_USER@!$(INST_USER)!g; s!@CFG_GROUP@!$(INST_GROUP)!g; s!@CFG_ARWEAVE_DIR@!$(ARWEAVE_DIR)!g; s!@CFG_DATA_DIR@!$(DATA_DIR)!g; s!@CFG_CONFIG_PATH@!$(CONFIG_PATH)!g; s!@CFG_LOG_DIR@!$(LOG_DIR)!g; s!@CFG_MINING_ADDR@!$$MINING_ADDR!g' < "$^" > "$@"

submodules/arweave/rebar.config submodules/arweave/apps/arweave/lib/RandomX/CMakeLists.txt submodules/docs.arweave.org-info/mining/mining-guide.md:
	git submodule update --init --recursive --progress --filter=blob:none
