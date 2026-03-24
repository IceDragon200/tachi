# Commands

Commands take the form of `cmd.NAME.EXTENSION`, at the moment, tachi will only consider commands that have an extension present in the context's `allowed_extensions`

Tachi will scan the context's `root_path` for all `cmd.*.{allowed_extension[@]}` files and build out the command list.

Take the following context structure:

```
env/
  prod/
    apps/
      loki/
        cmd.upgrade.sh
  staging/
    apps/
      loki/
        cmd.upgrade.sh
```

Tachi will provide the following commands:

```
env.prod.apps.loki.upgrade
env.staging.apps.loki.upgrade
# or more easily expressed
env.{prod,staging}.apps.loki.upgrade
```

You can execute the individual commands via:

```shell
tachi run "env.prod.apps.loki.upgrade"
tachi run "env.staging.apps.loki.upgrade"
```

Or

```shell
tachi run "env.{prod,staging}.apps.loki.upgrade"
```

Or

```shell
tachi run "*.loki.upgrade"
```

Tachi just executes the item(s) as-is.

## Environment Variables

But just executing scripts, applications or what-not would be quite boring if you couldn't configure the environment.

Tachi's contexts allow setting the environment variable via its config entry, or by creating an [Environment File](./environment_file.md) within the file tree.

Let's take the original example again, but add some production and staging environment variables:

```
env/
  prod/
    environment
    apps/
      loki/
        cmd.upgrade.sh
  staging/
    environment
    apps/
      loki/
        cmd.upgrade.sh
```

`env/prod/environment`

```
DEPLOY_ENV=prod
FLYTRAP_API_KEY=prod-XYZ1233456789
```

`env/staging/environment`

```
DEPLOY_ENV=staging
FLYTRAP_API_KEY=staging-XYZ1233456789
```

Now if you executed the respective commands again, they would have access to those respective environment variables.

`environment` files may be created in any and all sub-directories and will only apply to commands within that sub-directory and its children.

Tachi will NOT leave the context's `root_path` so `env/../environment` is not evaluated.
