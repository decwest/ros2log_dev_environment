# Logger registry validation

Validated on 2026-10-08 (JST), on Linux amd64, using the
`feature/logger-registry` branch.

## Source revisions

All three libraries start from the upstream `rolling` branch. The development
environment pins the implementation commits as Git submodules; each commit is
available on the corresponding fork's `feature/logger-registry` branch.

| Repository | Upstream snapshot | Implementation commit |
| --- | --- | --- |
| [rcutils](https://github.com/decwest/rcutils/tree/feature/logger-registry) | `e86e907834ab094cffeb38be573b9cdebc47948b` | `e4f4bbdcc81708f2e615aef0dc98d5e2c78ee461` |
| [rclcpp](https://github.com/decwest/rclcpp/tree/feature/logger-registry) | `e7363f1027d5ea391500359bc1a2b17cb9d8d66f` | `3811fcf0fe10fc0f8d2c78c774395d3d9707c523` |
| [rclpy](https://github.com/decwest/rclpy/tree/feature/logger-registry) | `81329af4ce2303c43ab1584288eb9b02b4642174` | `82893138278093171ac009b0db0f3e01edeb158b` |

The pre-existing ros2cli working checkout remained at
`ce95d35212bac4e9ee3f18d8cb2f12b46da1d944`, on `ros2log-rolling`. Its source was
not edited. The development environment's existing ros2cli gitlink remains
`55254c3ffbcda5ec061dafc3e02ddbbf742326dc`; the `ros2cli`, `ros2node`, and
`ros2log` package directories are identical between these two revisions.

## Image and build

- Base: `osrf/ros:rolling-desktop-full-resolute`.
- Base image index digest:
  `sha256:5c64235134056d32f9049a7552564af1d76aa595ecad0242e0e55bf9652c545e`.
- Base amd64 manifest digest:
  `sha256:97706a92267591772461051da6c1766747c7fb0dba29bf3528b25cbf4f44f466`.
- Local image: `decwest/ros2log_dev_rolling:latest`, image ID
  `sha256:ebe72088e82f43a22bc7baf3113cc303a8aa6833fbcc26e361e7781069cbe01c`.
- Container: Ubuntu 26.04.1 LTS, Python 3.14.4.
- Binary underlay: rcl 10.5.2, rcl_interfaces 2.5.1, rcutils 7.2.2,
  rclcpp 33.1.0, rclpy 11.0.3. The last three are overridden by the source build.
- Build: `RelWithDebInfo`, `BUILD_TESTING=ON`, two colcon workers and four
  compiler workers per package.

`task build.rolling` pulls the current base image. Rolling tags and apt packages
can advance; the digests above identify the base used for this validation.
The development image contains dependencies; the source repositories are bind
mounted and built in the workspace.

From a fresh checkout:

```bash
git clone --branch feature/logger-registry --recurse-submodules \
  git@github.com:Decwest/ros2log_dev_environment.git
cd ros2log_dev_environment
task build.rolling
task registry.build
task registry.test
```

The source build completed for `rcutils`, `rclcpp`, `rclpy`, `ros2cli`,
`ros2node`, and `ros2log`. It uses `docker/ros2_ws/build-rolling-registry`,
`install-rolling-registry`, and `log-rolling-registry`. The former distribution's
build and install directories are not used.

## Test results

`task registry.test` passed:

| Selection | Result |
| --- | --- |
| rcutils logging-related CTest entries | 13 passed, including 7 new registry cases |
| rclcpp logging-related CTest entries | 6 passed, including 4 new registry cases |
| rclpy logging/rosout CTest entries | 5 passed, including 7 new registry cases |
| ros2log functional regression suite | 46 passed, 4 linter cases deselected |

The new tests cover empty and duplicate registration, hierarchical filtering,
unset/inherited severity, independent snapshots, allocation failures and
cleanup, concurrent registration/enumeration, logging shutdown/reinitialization,
creation before ROS initialization, retention after object/node/context
destruction, rosout-disabled nodes, and registration failure before adding a
rosout child entry. Existing logging and logger-service tests also passed.

Additional checks passed: rcutils and rclcpp cpplint/uncrustify, rclpy
mypy/flake8/pep257, and uncrustify for the changed C/C++ files. A separate smoke
build of `logger.cpp` and `logging_mutex.cpp` with `RCLCPP_LOGGING_ENABLED=0`
confirmed that the dummy logger and its child leave the registry empty.

To repeat the package lint checks in the built container:

```bash
task run.rolling.cpu
cd /home/ubuntu/ros2_ws
ctest --test-dir build-rolling-registry/rcutils \
  -R '^(cpplint|uncrustify)$' --output-on-failure
ctest --test-dir build-rolling-registry/rclcpp \
  -R '^(cpplint|uncrustify)$' --output-on-failure
ctest --test-dir build-rolling-registry/rclpy \
  -R '^(mypy|flake8|pep257)$' --output-on-failure
```

The initial full ros2log run produced 49 passes and one existing flake8 failure:
`ros2log/verb/watch.py:110:17: F841 local variable 'watcher' is assigned to but never used`.
The functional regression Task excludes the `linter` marker and does not
modify or suppress this warning in the ros2cli repository.

## Runtime overlay verification

The C++ registry test executable resolved both `librclcpp.so` and `librcutils.so`
from `install-rolling-registry`. The Python logging module, extension module,
and the process's mapped `librcutils.so` also came from that overlay.

In a container started by `task run.rolling.cpu`:

```bash
ldd build-rolling-registry/rclcpp/test/rclcpp/test_logger_registry \
  | grep -E 'librclcpp|librcutils'
build-rolling-registry/rclcpp/test/rclcpp/test_logger_registry \
  --gtest_filter=TestLoggerRegistry.registers_unlogged_hierarchy_before_ros_init_and_retains_names
python3 - <<'PY'
from pathlib import Path
import rclpy
import rclpy.logging
from rclpy.impl.implementation_singleton import rclpy_implementation
from rclpy.logging import get_logger, get_logger_names

assert not rclpy.ok()
logger = get_logger('runtime_check')
child = logger.get_child('unlogged_child')
del child
names = get_logger_names('runtime_check')
assert names == ['runtime_check', 'runtime_check.unlogged_child']
print(names)
print(rclpy.logging.__file__)
print(rclpy_implementation.__file__)
paths = {line.split()[-1] for line in Path('/proc/self/maps').read_text().splitlines()
         if 'librcutils.so' in line}
assert paths
for path in sorted(paths):
    assert '/ros2_ws/install-rolling-registry/rcutils/' in path
    print(path)
PY
```

Neither enumeration example emits a log message. The C++ test also verifies
grandchild names and retention after logger objects leave scope.

POSIX mutex behavior was exercised on Linux. The Windows SRWLOCK implementation
was not built or run in this environment.
