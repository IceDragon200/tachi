#!/usr/bin/env bash
VERSION=0.5.0
root_dir=$(dirname "$(readlink -f "$0")")

if ! [[ -z $1 ]]; then
cat <<__EOF__ > $1
#!/usr/bin/env bash
# Tachi Shim ${VERSION}
export EXEC_PATH=\$(pwd)
cd "${root_dir}"
exec ./bin/tachi "\$@"
__EOF__
chmod +x $1
echo "Installed Tachi ${VERSION} shim at: $1"
else
  echo "Install path required"
fi
