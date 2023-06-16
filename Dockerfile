FROM ubuntu:22.04

ARG DOCKER_HOME="/opt/ucare"
ARG DOCKER_CODE="/opt/ucare/code"
ARG DOCKER_USER="ucare"
ARG DOCKER_UID=5000
ARG PYTHON_VER=3.10.8

RUN apt-get upgrade -y
RUN apt-get dist-upgrade -y
RUN apt-get update --fix-missing

ARG BUILD_DEPS="wget build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev"

RUN apt-get install -y $BUILD_DEPS

RUN apt-get install -y libpq-dev libbz2-dev openssh-client git

# Install Python
RUN wget https://www.python.org/ftp/python/$PYTHON_VER/Python-$PYTHON_VER.tgz && \
    tar xzf Python-$PYTHON_VER.tgz && cd Python-$PYTHON_VER && \
    ./configure --enable-optimizations && \
    make altinstall && \
    ln -sf /usr/local/bin/python3.10 /usr/local/bin/python && \
    rm -rf /Python-$PYTHON_VER.tgz /Python-$PYTHON_VER
RUN wget https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && rm get-pip.py

RUN useradd -d ${DOCKER_HOME} -m -U -u ${DOCKER_UID} ${DOCKER_USER}

RUN pip install poetry

COPY requirements.txt requirements.txt

RUN --mount=type=ssh,id=bitbucket \
    mkdir -p /root/.ssh && \
    ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts && \
    poetry install --without dev && \
    rm requirements.txt

RUN apt-get purge -y $BUILD_DEPS

USER ${DOCKER_USER}

WORKDIR ${DOCKER_CODE}

ENV PYTHONPATH=.
ENV PORT=8000
ENV HOST=0.0.0.0
ENV WORKER_NUM=3

COPY --chown=${DOCKER_USER} . .

CMD gunicorn -w $WORKER_NUM -k gevent -b $HOST:$PORT --log-level info app.patched:app