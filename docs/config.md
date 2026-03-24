# Config

`~/.tachi/config`

```yaml
# The name of the context that should be used by default, this is optional.
default_context: default
# An array of contexts that define the root path and base environment variables for all commands within that context
contexts:
  # The name of the context, should be unique
- name: default
  # Where are the scripts for this context?
  root_path: /path/to/scripts
  # All file extensions that are allowed to be treated as commands by tachi
  # note the list below is the default list and this can be omitted from your own
  # configs if you don't wish to be specific.
  allowed_extensions:
  - "" # a special extension which means, allow files without extensions
  - .sh
  - .pl
  - .rb
  - .py
  # Fixed environment variables that act as a base for ALL commands in the root path
  env:
    MY_ENV: my_value_for_ENV
  # Calculated or evaluated environment variables, Tachi will replace:
  # * `ROOT_PATH` - the root_path of the context itself
  # * `WD` - the working directory of the command being executed
  calc_env:
    CONFIG_ROOT: ${ROOT_PATH}/.config
    WORKING_TMP: ${WD}/tmp
```

See [Commands](./commands.md) for creating tachi commands.
