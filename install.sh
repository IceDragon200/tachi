#!/usr/bin/env bash
root_dir=$(dirname "$(readlink -f "$0")")

if ! [[ -z $1 ]]; then
cat <<__EOF__ > $1
#!/usr/bin/env bash
cd "${root_dir}"
exec ./bin/tachi "\$@"
__EOF__
chmod +x $1
echo "Installed Tachi shim at: $1"
else
  echo "Install path required"
fi
