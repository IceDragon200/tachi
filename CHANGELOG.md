# 0.4.0

* Added support for `{segment,segment2,segmentN}` in command paths
  * Example: `env.prod.component.{api,worker}.upgrade` will expand the command to run upgrade for both api and worker
