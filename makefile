PREFIX ?= /usr/local

INST_USER ?= $(shell id -un $$SUDO_USER)
INST_GROUP ?= $(shell id -gn $$SUDO_USER)
CONFIG_PATH ?= $(PREFIX)/etc/arweave.json
ARWEAVE_DIR ?= $(PREFIX)/lib/arweave
DATA_DIR ?= $(PREFIX)/var/lib/arweave
#DOC_DIR ?= $(PREFIX)/share/doc/arweave
LOG_DIR ?= /var/log/arweave
SYSCTL_CONF_DIR ?= /etc/sysctl.d
SYSTEMD_UNIT_DIR ?= $(PREFIX)/lib/systemd/system

LOCAL_ARWEAVE_DIR = submodules/arweave/_build/prod/rel/arweave

$(LOCAL_ARWEAVE_DIR)/bin/arweave: submodules/arweave/rebar.config submodules/arweave/apps/arweave/lib/RandomX/CMakeLists.txt
	# build arweave
	cd submodules/arweave && ./rebar3 as prod release
	@echo "Now run make install. Optionally specify INST_USER= and INST_GROUP= to set the user arweave will run as."

install: $(LOCAL_ARWEAVE_DIR)/bin/arweave confs/config.json.in confs/config.json confs/arweave.service ai/config.json.doc
	mkdir -p "$(ARWEAVE_DIR)"
	mkdir -p "$(LOG_DIR)"
	#mkdir -p "$(DOC_DIR)"
	cp -va "$(LOCAL_ARWEAVE_DIR)"/. "$(ARWEAVE_DIR)"/.
	-chown $(USER):$(GROUP) -R "$(ARWEAVE_DIR)" "$(DATA_DIR)" "$(LOG_DIR)"
	-cp --no-clobber -v confs/config.json "$(CONFIG_PATH)" 
	cp -v confs/arweave.service "$(SYSTEMD_UNIT_DIR)"
	#cp -v ai/config.json.doc "$(DOC_DIR)"/
	cp -v confs/99-arweave-sysctl.conf "$(SYSCTL_CONF_DIR)"/
	systemctl daemon-reload

uninstall:
	-rm -vrf "$(ARWEAVE_DIR)" "$(SYSTEMD_UNIT_DIR)"/arweave.service "$(SYSCTL_CONF_DIR)"/99-arweave-sysctl.conf
	#-rm -vrf "$(DOC_DIR)"
	@echo "You may delete $(DATA_DIR), $(LOG_DIR), and/or $(CONFIG_PATH) manually."

$(DATA_DIR)/wallets: $(LOCAL_ARWEAVE_DIR)/bin/arweave
	mkdir -p "$(DATA_DIR)"
ifeq (,$(wildcard $(DATA_DIR)/wallets/arweave_keyfile_*.json))
	"$(LOCAL_ARWEAVE_DIR)"/bin/create-wallet "$(DATA_DIR)"
endif

# it performs better with more content from files, but this service provides only short completions, so sed is used to trim the context
CONFIG_JSON_CTX = ai/mining-guide.md.sed_trusted_peers ai/ar.erl.sed_show_help ai/ar_config.hrl.sed_config ai/ar_config.erl.sed_parse_opts
ai/mining-guide.md.sed_trusted_peers: submodules/docs.arweave.org-info/mining/mining-guide.md
	sed -n '/nodes that can be used as trusted peers:/{:1;p;n;/^$$/!b1}' < $^ > $@
ai/ar.erl.sed_show_help: submodules/arweave/apps/arweave/src/ar.erl
	sed -n '/^show_help() ->/{:1;p;n;/erlang:halt/!b1}' < $^ > $@
ai/ar_config.hrl.sed_config: submodules/arweave/apps/arweave/include/ar_config.hrl
	sed -n '/^%% @doc Startup options with default values./{:1;p;n;/})./!b1}' < $^ > $@
ai/ar_config.erl.sed_parse_opts: submodules/arweave/apps/arweave/src/ar_config.erl
	sed -n '/^%% @doc Parse the configuration options./{:1;p;n;/^[a-oq-z]/!b1}' < $^ > $@
confs/config.json.in: ai/llm.py $(CONFIG_JSON_CTX)
	python3 ai/llm.py --prompt "Generate the content for $(CONFIG_PATH) to install on a user's system. Make use of the template variables @CFG_DATA_DIR@, @CFG_LOG_DIR@, @CFG_MINING_ADDR@, and optionally @CFG_ARWEAVE_DIR@. Do not provide any extra formatting or commentary. Do not place backticks around your reply. The config file must have all needed values provided to run the node, such as trusted peers, but where harmless it should also contain default values to help the user see what to provide. storage_modules should be an empty list as the user must configure these manually. If one value depends on or is tightly associated with another value, do not include it unless its dependency is also included." --files $(CONFIG_JSON_CTX) | tee $@
#ai/config.json.doc.in: ai/llm.py $(CONFIG_JSON_CTX) confs/config.json.in
#	python3 ai/llm.py --max-tokens 2048 --prompt "Generate the content for basic documentation of the $(CONFIG_PATH) or @CFG_CONFIG_PATH@ file. The autogenerated template for this file is in your system prompt. This file is the only configuration provided to the node. Make it clear the documentation (as well as the default-installed config file) is auto-generated via a language model. Any use of the template variables @CFG_DATA_DIR@, @CFG_MINING_ADDR@, @CFG_ARWEAVE_DIR@, @CFG_LOG_DIR@, or @CFG_CONFIG_PATH@ will be automatically replaced with correct values. The documentation should simply describe what the user needs to change or add from the autogenerated file to optimize their system. Do not describe extra bells and whistles." --files $(CONFIG_JSON_CTX) confs/config.json.in | tee $@

%: %.in $(DATA_DIR)/wallets
	MINING_ADDR="$$(ls $(DATA_DIR)/wallets/arweave_keyfile_*.json | sed -ne '1,1 s/arweave_keyfile_\(.*\)\.json/\1/p')" sed -e 's!@CFG_USER@!$(INST_USER)!g; s!@CFG_GROUP@!$(INST_GROUP)!g; s!@CFG_ARWEAVE_DIR@!$(ARWEAVE_DIR)!g; s!@CFG_DATA_DIR@!$(DATA_DIR)!g; s!@CFG_CONFIG_PATH@!$(CONFIG_PATH)!g; s!@CFG_LOG_DIR@!$(LOG_DIR)!g; s!@CFG_MINING_ADDR@!$$MINING_ADDR!g' < "$<" > "$@"

submodules/arweave/rebar.config submodules/arweave/apps/arweave/lib/RandomX/CMakeLists.txt submodules/docs.arweave.org-info/mining/mining-guide.md:
	git submodule update --init --recursive --progress --filter=blob:none
