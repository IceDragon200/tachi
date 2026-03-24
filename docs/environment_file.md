# Environment File

`environment` files allow you to add additional environment variables to commands in the a context's path.

The file has a relatively simple structure:

```
# This is a comment
KEY=VALUE

# Empty lines are allowed
# You can have a key have an empty value
KEY=

# However you cannot have an empty key
=VALUE
# Or just the key itself
KEY
# You also cannot inline comments, it will be treated as part of the value
KEY=VALUE # Something something
```
