FROM rockylinux:9

RUN dnf install -y vim git ruby jq
RUN gem install ruby-openai dotenv

RUN dnf install -y @development cmake
RUN curl -L -o /tmp/opencv.zip https://github.com/opencv/opencv/archive/4.7.0.zip \
 && cd /tmp \
 && unzip opencv.zip \
 && cd opencv-4.7.0 \
 && mkdir build \
 && cd build \
 && cmake .. && make && make install
RUN dnf install -y epel-release
RUN dnf install -y ImageMagick
