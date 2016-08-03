# Project Background
This project is a modularized software framework for use with humanoid robot development and research. The modularized platform separates low level components that vary from robot to robot from the high level logic that does not vary across robots. The low level components include processes to communicate with motors and sensors on the robot, including the camera. The high level components include the state machines that control how the humanoids move around and process sensor data. By separating into these levels, we achieve a more adaptable system that is easily ported to different humanoids.

The project began with the University of Pennsylvania RoboCup code base from the 2011 RoboCup season and is continuing to evolve into an ever more generalized and versatile robot software framework.  The DARPA Robotics Challenge also pushed development

## Copyright and License

All code sources associated with this project are:

* (c) 2013 Stephen McGill, Seung-Joon Yi, Daniel D. Lee, Yida Zhang, Spyridon Karachalios, Qin He, Jordan Brindza.

* (c) 2014 Stephen McGill, Seung-Joon Yi, Daniel D. Lee, Yida Zhang, Qin He, Larry Vadakedathu

* (c) 2015 Stephen McGill, Seung-Joon Yi, Daniel D. Lee, Bhoram Lee

* (c) 2016 Stephen McGill, Seung-Joon Yi, Daniel D. Lee, Jinwook Huh

* Exceptions are noted on a per file basis.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


### Contact Information

* UPenn E-mail:     upennalizers@gmail.com
* UPenn Website:    https://fling.seas.upenn.edu/~robocup/wiki/index.php

# Mac Setup
```
brew install lua boost png libusb jpeg-turbo msgpack zeromq swig
brew link --force jpeg-turbo
```

# Ubuntu Setup

Install the server from [Ubuntu](http://www.ubuntu.com/download/server) with OpennSSH and user of `thor`.

## Required Packages

```
cd ~/
mkdir -p src
cd src
sudo chown -R thor /usr/local
sudo usermod -a -G dialout thor
sudo usermod -a -G video thor
sudo apt-get install git htop build-essential automake gfortran pkg-config \
libtool libudev-dev zlib1g-dev libpcre3-dev liblzma-dev libreadline-dev \
libpng12-dev libjpeg-dev libncurses5-dev uvcdynctrl libsodium-dev
#libglfw3-dev libglew-dev libglewmx-dev
```

### Speaker
```
speaker-test -c1 -Dsysdefault:Device
pulseaudio -k; and sudo alsa force-reload
```

## General Packages
You can install via Ubuntu or Mac (bewar of OSX Homebrew duplicates).

### SSH Keys
[Generate SSH Keys](https://help.github.com/articles/generating-ssh-keys/) for simpler pushing

### LuaJIT
```
git clone http://luajit.org/git/luajit-2.0.git
cd luajit-2.0
git checkout v2.1
make
make install
ln -sf luajit-2.1.0-alpha /usr/local/bin/luajit
```

### Boost Libraries from Shared Memory
```
cd ~/src
wget http://downloads.sourceforge.net/project/boost/boost/1.58.0/boost_1_58_0.tar.bz2
tar xvvf boost_1_58_0.tar.bz2
cd /usr/local
ln -s ~/src/boost_1_58_0/boost .
```

### libusb for Kinect2
```
cd ~/src
git clone https://github.com/libusb/libusb.git
cd libusb
git checkout 51b10191033ca3a3819dcf46e1da2465b99497c2
./autogen.sh
make
make install
```

### MessagePack
```
cd ~/src
git clone https://github.com/msgpack/msgpack-c.git
cd msgpack-c
./bootstrap
./configure
make
make install PREFIX=/usr/local
```

### ZeroMQ
```
cd ~/src
wget http://download.zeromq.org/zeromq-3.2.5.tar.gz
tar xvvf zeromq-3.2.5.tar.gz
cd zeromq-3.2.5
./configure
make
make install PREFIX=/usr/local
```

### OpenBLAS
```
cd ~/src
git clone https://github.com/xianyi/OpenBLAS.git
cd OpenBLAS
make
make install PREFIX=/usr/local
```

### Torch7
```
cd ~/src
git clone https://github.com/smcgill3/torch7.git
cd torch7
git checkout build-fixes
make prep
make
make install
```

### Beignet

This is for OpenCL for the kinect2

```
http://www.freedesktop.org/wiki/Software/Beignet/
```

### Ag Search
```
cd ~/src
git clone https://github.com/ggreer/the_silver_searcher.git
cd the_silver_searcher
./build.sh
make install
```

### Fish
```
cd ~/src
git clone https://github.com/fish-shell/fish-shell.git
cd fish-shell
autoconf
./configure
make
make install
sudo -s
echo `which fish` >> /etc/shells
exit
chsh -s /usr/local/bin/fish
```

### Update the libraries
```
sudo ldconfig
```

### USB Device Rules
```
sudo nano /etc/udev/rules.d/55-thor-usb.rules
```

Add the following lines:

```
SUBSYSTEM=="usb", ATTR{idProduct}=="02d8", ATTR{idVendor}=="045e", MODE:="0666", OWNER:="thor", GROUP:="video"
SUBSYSTEM=="usb", ATTR{idProduct}=="02d9", ATTR{idVendor}=="045e", MODE:="0666", OWNER:="thor", GROUP:="video"
```

## Install Framework
```
cd ~/
git clone git@github.com:UPenn-RoboCup/UPennDev2.git UPennDev
cd UPennDev
make -j8
make THOROP
```

## Configurations

vim colors:

```
cd ~/
ln -s UPennDev/Scripts/vimrc .vimrc
```

nano colors:

```
sudo nano /usr/share/nano/lua.nanorc
```

Get from here:
```
https://github.com/scopatz/nanorc/raw/master/lua.nanorc
```

```
sudo nano /etc/nanorc
```

Add:

```
include "/usr/share/nano/lua.nanorc"
```
