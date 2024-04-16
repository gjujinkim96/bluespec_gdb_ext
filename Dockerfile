# syntax=docker/dockerfile:1

FROM ubuntu:focal-20240410
WORKDIR /build

# Installing Haskell libraries(for bsc)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    python3 \
    gcc \
    build-essential \
    libffi-dev \
    libffi7 \
    libgmp-dev \
    libgmp10 \
    libncurses-dev \
    libncurses5 \
    libtinfo5 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN bash -c "curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh"
ENV PATH="/root/.ghcup/bin:$PATH"
RUN ghcup install ghc --set recommended
RUN cabal update && cabal v1-install regex-compat syb old-time split


# Installing bsc
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    autoconf \
    build-essential \
    bison \
    flex \
    gperf \
    ninja-build \
    tcl-dev \
    pkg-config \
    iverilog \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --recursive https://github.com/B-Lang-org/bsc
WORKDIR /build/bsc
RUN make install-src && mv inst /opt/bsc
ENV PATH="/opt/bsc/bin:$PATH"

# Installing riscv-gnu-toolchain
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    autoconf \
    automake \
    autotools-dev \
    curl \
    python3 \ 
    python3-pip \
    libmpc-dev \
    libmpfr-dev \
    libgmp-dev \
    gawk \
    build-essential \
    bison \
    flex \
    texinfo \
    gperf \
    libtool \
    patchutils \
    bc \
    zlib1g-dev \
    libexpat-dev \
    ninja-build \
    git \
    cmake \
    libglib2.0-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone https://github.com/riscv/riscv-gnu-toolchain
WORKDIR /build/riscv-gnu-toolchain
RUN git submodule update --init --recursive

ENV PATH="/opt/riscv/bin:$PATH"
RUN ./configure --prefix=/opt/riscv
RUN make



# Installing necessary package for gdb extension
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3.9 \
    libelf-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# For debugging purpose
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    vim \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Build gdbstub
WORKDIR /home
COPY gdbstub gdbstub
ENV GDBSTUB=/home/gdbstub

WORKDIR /home/gdbstub
RUN make XLEN=32 exe_gdbstub_tcp_tcp_RV32

WORKDIR /home
COPY labs labs
COPY types_helper types_helper
ENV TYPES_HELPER=/home/types_helper

# For auto_complete
COPY setup_auto_complete.sh .
ENV PROGRAMS_DIR=/home/labs/pb_lab5/lib/programs
RUN echo ' \n\
. setup_auto_complete.sh \n\
'  >> ~/.bashrc


ENTRYPOINT ["tail", "-f", "/dev/null"]



