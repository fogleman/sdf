# Dependencies of the graphical interface

## Windows

`TODO:` Current Windows installation instructions

## Unix

### Installation

Install the following packages with your package manager:

```
python3
python3-gi
python3-opengl
python3-yaml
python3-svg.path
gir1.2-gtk-3.0
```

On a Debian or Ubuntu system, you would just type the following:
```bash
sudo apt install python3-gi python3-opengl python3-yaml python3-svg.path gir1.2-gtk-3.0
```
Please note that you need to enable the `universe` repository in Ubuntu.

### Run with Docker

If you have difficulty with the installation, you can run the application from Docker.

The `docker run` command will mount your personal Documents folder to `/root/Documents` so that you
can access your files.

```bash
sudo docker build -t pycam/pycam .
sudo docker run -it \
    -v ~/Documents:/root/Documents \
    -v ~/.Xauthority:/root/.Xauthority \
    -e DISPLAY \
    --net=host \
    pycam/pycam
```

## macOS

### Installation

1\. Install Homebrew if it has not been installed:
```bash
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

2\. Install the dependencies (currently only for Python2):  
TODO: adjust for Python3
```bash
brew install gtk+3 pygobject3
pip install pygobject enum34
```

### Run with Docker

If you have difficulty with the installation, you can run the application from Docker.

1\. Make sure that Docker is installed, if not, you can install it with Homebrew.
You will also need XQuartz and socat.

```bash
brew cask install docker xquartz
brew install socat
```

2\. Start XQuartz from a terminal with `open -a XQuartz`. In the XQuartz Preferences,
go to the “Security” tab and make sure you’ve got “Allow connections from network
clients” ticked.

3a. Run the following in a terminal and leave it running:

```bash
socat TCP-LISTEN:6000,reuseaddr,fork UNIX-CLIENT:\"$DISPLAY\"
```

3b. Run the following in a separate terminal. Your ip address can be found by running `ifconfig`.

The `docker run` command will mount your personal Documents folder to `/root/Documents` so that you
can access your files.

```bash
docker build -t pycam/pycam .
export IP='<your local ip address>'
docker run -it \
    -v ~/Documents:/root/Documents \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY=$IP:0 \
    pycam/pycam
```

# Minimal requirements for non-GUI mode

If you plan to use PyCAM only in batch mode (without a graphical user interface),
then you just need to install Python.

See the manpage ( `man pycam` ) or the output of `pycam --help` for further defails.
