# Artbot

Deploys an artbot npm/pm2 service installation.

Every time this role is run, if there's a new commit in the relevant repository, this will rebuild artbot and redeploy it in a new directory named after the commit hash. The `latest` symlink will then always point the the currently used deploy directory.

```
drwxr-xr-x 6 artbot artbot 4096 Jul 27 15:09 8471904452c9ac344adcfb6ba0b858df0aa6e3a9
lrwxrwxrwx 1 root   root     60 Jul 27 15:11 latest -> /home/artbot/builds/8471904452c9ac344adcfb6ba0b858df0aa6e3a9
```

# Instructions

1. Make a playbook to call the relevant roles. An example `examples/artbot.yml` playbook has been provided where you can adjust only what's needed to run an artbot and revproxy together.
1. Create an ansible inventory `inventory.yml` with your host address. An example has been provided in `examples/inventory.yml` which you can copy and modify
1. Run the ansible-playbook

```bash
ansible-playbook artbot.yml -i inventory.yml
```

# Updating

A tag `update` has been provided which will run only the steps needed to release a new version.

```bash
ansible-playbook artbot.yml -i inventory.yml -t update
```

The expectation is to run this as part of a CI/CD workflow.
