#!/usr/bin/env bash
set -eo pipefail

source /opt/ros/rolling/setup.bash
cd /home/ubuntu/ros2_ws

case "${1:-}" in
  build)
    export CMAKE_BUILD_PARALLEL_LEVEL=4
    colcon --log-base log-rolling-registry build \
      --build-base build-rolling-registry --install-base install-rolling-registry \
      --symlink-install --parallel-workers 2 \
      --packages-up-to rcutils rclcpp rclpy ros2log \
      --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=ON
    ;;
  test)
    source install-rolling-registry/setup.bash
    export ROS_DOMAIN_ID=217
    export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
    colcon --log-base log-rolling-registry test \
      --build-base build-rolling-registry --install-base install-rolling-registry \
      --packages-select rcutils rclcpp rclpy ros2log \
      --executor sequential --return-code-on-test-failure \
      --pytest-args -m 'not linter' \
      --ctest-args -R 'test_log|test_rosout' --output-on-failure
    colcon test-result --test-result-base build-rolling-registry --verbose
    ;;
  *)
    echo 'Usage: registry_workspace.bash {build|test}' >&2
    exit 2
    ;;
esac
