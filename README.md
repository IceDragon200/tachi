# Tachi

The useful sidearm.

Tachi is a shell script runner, given a directory full of scripts that have the form: `cmd.NAME.sh`, it will allow you to execute them from anywhere using tachi.

The primary purpose of this utility was to turn a mountain of shell scripts into a single usable interface complete with environment variable handling and context switches.

## How to install

Either clone the repository (recommended) or download the project's archive and unpack it somewhere you'd like to keep tachi itself.

```shell
# In tachi's root, install the necessary gems, it's mostly standard library stuff unless ruby moves the gems out later.
bundle install
```

Then install the executable shim:
```shell
./install.sh path/to/tachi/shim

# Normally I keep a bin directory in my home for custom executables, such as tachi
./install.sh ~/bin/tachi
```

Once that's setup, and your install location is accessible you can execute `tachi`.

## How to update

### Via Git

Just pull like normal, or do any other git things you want with it.

```shell
git pull
```

### Via Archive

The same way you installed, just download the latest archive and replace your existing tachi installation, no need to reinstall the shim, but it doesn't hurt to do so again after an update.

## Configuration

See [Config](docs/config.md)

## How to use

The primary command is simply `run`:

```shell
tachi run "path.to.command"
```

Assuming you are using a default context, the command above would be in: `${ROOT_PATH}/path/to/cmd.command.sh`.

Tachi would execute the script in the command's original directory, allowing you to utilize relative paths.

The power of tachi is the ability to run multiple commands at once:

```shell
tachi run "env.*.apps.{api,workers}.upgrade"
```

The above example would execute every upgrade command for "api" and "workers" for all matching paths and sub paths below env.

Assuming env only contained `prod` or `staging`, that would execute:

```
env.prod.apps.api.upgrade
env.prod.apps.workers.upgrade
env.staging.apps.api.upgrade
env.staging.apps.workers.upgrade
```

As of Tachi 0.5, you can now run these commands in parallel:

```shell
tachi --jobs 4 run "env.*.apps.{api,workers}.upgrade"
```

Or if you need to group commands so that they will run serialized in the same thread:

```shell
tachi --group "env.{prod,staging}" --jobs 2 run "env.*.apps.{api,workers}.upgrade"
```

```
[EXEC:1] env.prod.apps.api.upgrade
[EXEC:1] env.prod.apps.workers.upgrade
[EXEC:2] env.staging.apps.api.upgrade
[EXEC:2] env.staging.apps.workers.upgrade
```

## How to run Tests

Simply run `./test.sh`.
