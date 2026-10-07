# ros2log_dev_environment

[![ROS2 Distro: Rolling](https://img.shields.io/badge/ROS2-Rolling-green.svg)](https://docs.ros.org/en/rolling/index.html) [![Docker](https://img.shields.io/badge/Docker-blue.svg)](https://www.docker.com/)

A **Docker-based environment** for developing ros2log (**ROS2 Rolling**).

## Assumptions

- Docker & Docker Compose for creating the virtual environment  
- [Task](https://taskfile.dev/docs/installation) for command management  
- (Optional) Nvidia GPU with `nvidia-container-toolkit` if GPU is available  

To install Task on Ubuntu:

```shell
sudo sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
```

## Installation
1. **Clone this repository**

```shell
git clone --recursive git@github.com:Decwest/ros2log_dev_environment.git
```

2. **Build the docker image**

```shell
task build.rolling
```

1. **Run the container**

- With GPU:
```shell
task run.rolling.gpu
```

- CPU only:
```shell
task run.rolling.cpu
```

## Logger registry development

The `feature/logger-registry` branch adds process-local logger-name registration
and enumeration in `rcutils`, with automatic registration in `rclcpp` and `rclpy`.
It uses ROS 2 Rolling on Ubuntu 26.04 (Resolute). The source revisions are pinned
by the `rcutils`, `rclcpp`, and `rclpy` submodules.
See [validation and reproducibility](docs/logger_registry_validation.md) for
the source commits, image digests, test results, and runtime library checks.

### Build and test

Run these commands from the repository root:

```bash
git submodule update --init --recursive
task build.rolling
task registry.build
task registry.test
```

The image build pulls the current `rolling-desktop-full-resolute` base and installs
the test dependencies. Source builds use `build-rolling-registry`,
`install-rolling-registry`, and `log-rolling-registry` inside `docker/ros2_ws`, so
the previous workspace's build artifacts are not reused. Both CPU and GPU
services mount the same source repositories and overlay.

`registry.test` runs the logging-related tests of the three libraries and the
ros2log functional regression suite (pytest's `linter` marker is excluded).
The existing ros2log checkout has an unrelated flake8 F841 warning at
`ros2log/verb/watch.py:110` (`watcher` is assigned but never used); it is preserved.
Tests use domain 217 and local discovery. A new
interactive container sources the registry overlay if it has been built:

```bash
task run.rolling.cpu
python3 - <<'PY'
from rclpy.logging import get_logger, get_logger_names

logger = get_logger('example')
child = logger.get_child('vision')
del child
print(get_logger_names('example'))
# ['example', 'example.vision'] -- no log message needs to be emitted
PY
```

### API contract

The C API in `rcutils/logging.h` provides:

```c
rcutils_ret_t rcutils_logging_register_logger(const char * name);

rcutils_ret_t rcutils_logging_get_logger_names(
  const char * base_logger_name,
  rcutils_allocator_t allocator,
  rcutils_string_array_t * logger_names);
```

Pass `NULL` as the base to enumerate all registered names in the process. A
nonempty base selects an exact match and dot-separated descendants: `foo`
matches `foo.bar` but not `foobar`. This filter does not establish node ownership.
The result is a sorted, unique snapshot. Initialize the output with
`rcutils_get_zero_initialized_string_array()` and release it with
`rcutils_string_array_fini()`. Failures leave the output unchanged.

C++ `rclcpp::get_logger()` and `Logger::get_child()` register names automatically;
use the C API above for enumeration. Python exposes
`rclpy.logging.get_logger_names(base_logger_name=None)` and registers names when
`RcutilsLogger` objects are created, including through `get_logger()` and
`get_child()`. Registration failures raise exceptions.

Names remain registered after logger objects, nodes, or ROS contexts are destroyed.
They are cleared by `rcutils_logging_shutdown()` or Python
`rclpy.logging.shutdown()` / `clear_config()`. Reusing an old object after this
reset does not register it again; newly created loggers do. Registry memory grows
with the number of distinct registered names.

Registration does not set a severity, publish a message, or require rosout or
logger services. Merely configuring a severity or using a named rcutils logging
macro does not register a name. Empty-name default loggers are excluded;
registering an empty name is a no-op, while an empty enumeration filter is invalid.
Registration and enumeration synchronize with each other; callers must serialize
logging initialization/shutdown and configuration against these operations.

`ListLoggers.srv`, node attribution, effective-level services, and
`ros2 log describe` are not included in this stage.
