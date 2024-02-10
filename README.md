<!-- This is a brief version of docs/en/api-guides/tools/idf-docker-image.rst
     intended to be displayed on the Docker Hub page: https://hub.docker.com/r/espressif/idf.
     When changing this page, please keep idf-docker-image.rst in sync.
     (Keep the differences between Markdown and restructuredText in mind.)
 -->

# ESP-IDF Docker Image

This is a Docker image for the [Espressif IoT Development Framework (ESP-IDF)](https://github.com/espressif/esp-idf). It is intended for building applications and libraries with specific versions of ESP-IDF, when doing automated builds.

This image contains a copy of ESP-IDF and all the tools necessary to build ESP-IDF projects.

## Build

This build will create a user to work with. If you do not specify the username it will
default to esp32_user, You can set the username by building with --build-arg USERNAME=username
this user will be UID 1000. This is so that if you mount directories on ubuntu it will
get UID 1000 which is usually a real user (The first user created)

In order to build some of the things I build you will need the /home/USERNAME directory,
so I usually do a docker volume create volume_name_home_username and then use that to 
mount the docker home directory.

```bash
docker build . --build-arg USERNAME=username -t esp-idf:v5.1.2
```

## Basic Usage

I usually run bash and then cd to a source directory and do my build.
I mount /dev/bus/usb so I can use the /dev/ttyUSBx devices to program te ESP32.

here is the basic command I use:

```bash
docker run --rm --privileged  -v /dev/bus/usb:/dev/bus/usb \
-v esp32_home_dir_username:/home/username -v ~/src:/home/mlw/src \
-it esp-idf:v5.1.2 bash
```
If you need to be root you can change bash to 
```bash
docker run --rm --privileged  -v /dev/bus/usb:/dev/bus/usb \
-v esp32_home_dir_username:/home/username -v ~/src:/home/mlw/src \
-it esp-idf:v5.1.2 sudo bash
```

This should work, I have not tested it.
Build a project located in the current directory using `idf.py build` command:

```bash
docker run --rm -v $PWD:/project -w /project esp-idf:v5.1.2 idf.py build
```
