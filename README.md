This is a draft and disorganised install script for arweave. It is built from source based on a submodule reference, and a systemd service and sysctl configuration are installed.

#### usage
```
make && sudo make install
```

#### notes

The most pressing issue is to correctly tune the systemd service located at confs/arweave.service.in .

I didn't find information on the json configuration format, so the default configuration file is generated with a language model. This is present in the repository in confs/config.json.in but can be regenerated with make.
