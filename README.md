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
