#!/bin/bash

## source
source "/opt/ros/$ROS_DISTRO/setup.bash"
if [ -f ~/ros2_ws/install-rolling-registry/local_setup.bash ]; then
    source ~/ros2_ws/install-rolling-registry/local_setup.bash
fi

# Colcon shortcuts
source /usr/share/colcon_cd/function/colcon_cd.sh
export _colcon_cd_root=/opt/ros/$ROS_DISTRO/
source /usr/share/colcon_cd/function/colcon_cd-argcomplete.bash

source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash

alias cb="colcon build --symlink-install"
alias cc="colcon clean workspace"
