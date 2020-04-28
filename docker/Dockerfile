FROM debian:10.1
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y  \
    procps htop \
    autoconf \
    automake \
    bzip2 \
    g++ \
    git \
    gstreamer1.0-plugins-good \
    gstreamer1.0-tools \
    gstreamer1.0-pulseaudio \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-ugly  \
    libatlas-base-dev \
    libatlas3-base \
    libgstreamer1.0-dev \
    libtool-bin \
    make \
    python2.7 \
    python3 \
    build-essential \
    python-pip \
    python3-pip \
    python-yaml \
    python3-yaml \
    python-simplejson \
    python3-simplejson \ 
    python-requests \
    python-pyasn1 \
    python3-pyasn1 \
    python-gi \
    python3-gi \
    sox \
    subversion \
    wget \
    vim \
    cifs-utils \
    unzip \
    apt-utils \
    python-dateutil \
    zlib1g-dev && \
    apt-get clean autoclean && \
    apt-get autoremove -y

RUN python -m pip install --upgrade pip setuptools wheel pyasn1
RUN python3 -m pip install --upgrade pip setuptools wheel pyasn1

RUN pip install futures requests pyasn1 schedule==0.6.0 setuptools
RUN pip3 install futures requests pyasn1 schedule==0.6.0 setuptools python-dateutil

RUN wget http://www.digip.org/jansson/releases/jansson-2.7.tar.bz2 && \
    bunzip2 -c jansson-2.7.tar.bz2 | tar xf -  && \
    cd jansson-2.7 && \
    ./configure && make -j 4 && make -j 4 check &&  make -j 4 install && \
    echo "/usr/local/lib" >> /etc/ld.so.conf.d/jansson.conf && ldconfig && \
    rm /jansson-2.7.tar.bz2 && rm -rf /jansson-2.7

RUN git clone --recursive https://github.com/kubernetes-client/python.git && \
    cd /python && \
    python3 setup.py install && \
    python setup.py install && \
    rm -rf /python

RUN useradd --create-home appuser
#RUN mkdir -p /home/appuser/opt && chown -R appuser:appuser /home/appuser/opt
# map to the model directory dynamically, so that no need to edit the model files
RUN ln -s /home/appuser/opt/models /opt/models 
USER appuser

RUN python -m pip install --user tornado==5.1.1 ws4py==0.5.1 futures requests pyasn1 schedule==0.6.0 prometheus_client setuptools
RUN python3 -m pip install --user tornado==5.1.1 ws4py==0.5.1 futures requests pyasn1 schedule==0.6.0 prometheus_client setuptools

RUN mkdir -p /home/appuser/opt
WORKDIR /home/appuser/opt
#Commit on May 15, 2019 
ENV KALDI_SHA1 35f96db7082559a57dcc222218db3f0be6dd7983
RUN git clone https://github.com/kaldi-asr/kaldi && \
    cd /home/appuser/opt/kaldi && \
    git reset --hard $KALDI_SHA1 && \
    cd /home/appuser/opt/kaldi/tools && \
    make -j 2 && \
    ./install_portaudio.sh

RUN cd /home/appuser/opt/kaldi/src && ./configure --shared --mathlib=ATLAS && \
    sed -i '/-g # -O0 -DKALDI_PARANOID/c\-O3 -DNDEBUG' kaldi.mk && \
    make -j 4 depend && make -j 4 && \
    cd /home/appuser/opt/kaldi/src/online && make -j 4 depend && make -j 4 && \
    cd /home/appuser/opt/kaldi/src/gst-plugin && make -j 4 depend && make -j 4

ENV KALDI_NNET2_ONLINE_SHA1 617e43e73c7cc45eb9119028c02bd4178f738c4a
# https://github.com/alumae/gst-kaldi-nnet2-online/commit/617e43e73c7cc45eb9119028c02bd4178f738c4a

RUN cd /home/appuser/opt && \
    git clone https://github.com/alumae/gst-kaldi-nnet2-online.git && \
    cd /home/appuser/opt/gst-kaldi-nnet2-online && \
    git reset --hard $KALDI_NNET2_ONLINE_SHA1 && \
    cd /home/appuser/opt/gst-kaldi-nnet2-online/src && \
    sed -i '/KALDI_ROOT?=\/home\/tanel\/tools\/kaldi-trunk/c\KALDI_ROOT?=\/home/appuser/opt\/kaldi' Makefile && \
    make -j 4 depend && make -j 4 && \
    rm -rf /home/appuser/opt/gst-kaldi-nnet2-online/.git/ && \
    find /home/appuser/opt/gst-kaldi-nnet2-online/src/ -type f -not -name '*.so' -delete && \
    rm -rf /home/appuser/opt/kaldi/.git && \
    rm -rf /home/appuser/opt/kaldi/egs/ /home/appuser/opt/kaldi/windows/ /home/appuser/opt/kaldi/misc/ && \
    find /home/appuser/opt/kaldi/src/ -type f -not -name '*.so' -delete && \
    find /home/appuser/opt/kaldi/tools/ -type f \( -not -name '*.so' -and -not -name '*.so*' \) -delete

ENV KALDI_GSTRAMER_SERVER_SHA1 9ce1ccc39fb734ca997982dd47197fc9b951b70f
#https://github.com/alumae/kaldi-gstreamer-server/commit/9ce1ccc39fb734ca997982dd47197fc9b951b70f

RUN cd /home/appuser/opt && git clone https://github.com/alumae/kaldi-gstreamer-server.git && \
    cd /home/appuser/opt/kaldi-gstreamer-server && \
    git reset --hard $KALDI_GSTRAMER_SERVER_SHA1 && \
    rm -rf /home/appuser/opt/kaldi-gstreamer-server/.git/ && \
    rm -rf /home/appuser/opt/kaldi-gstreamer-server/test/

COPY --chown=appuser:appuser scripts/start_master.sh scripts/start_worker.sh scripts/stop.sh scripts/engine_template.yaml /home/appuser/opt/

RUN chmod +x /home/appuser/opt/start_master.sh && \
    chmod +x /home/appuser/opt/start_worker.sh && \
    chmod +x /home/appuser/opt/stop.sh

COPY scripts/worker_addon.py scripts/master_server_addon.py scripts/master_server.py scripts/worker.py /home/appuser/opt/kaldi-gstreamer-server/kaldigstserver/

# Add Tini
ENV TINI_VERSION v0.18.0
RUN wget https://github.com/krallin/tini/releases/download/v0.18.0/tini
RUN chmod +x /home/appuser/opt/tini


# copy kube config
RUN mkdir -p /home/appuser/.kube
COPY --chown=appuser:appuser secret/config /home/appuser/.kube/config


# install kubectl command for delete completed jobs
RUN wget https://storage.googleapis.com/kubernetes-release/release/v1.15.1/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl


COPY --chown=appuser:appuser scripts/cronjob.py scripts/cronjob_delete_kubernetes_jobs.sh /home/appuser/opt/

COPY --chown=appuser:appuser ssl /home/appuser/opt/ssl

